using System.IO.Compression;
using System.Globalization;
using System.Text.Json;
using TerroirEngine.Data;
using TerroirEngine.Util;

namespace TerroirEngine.Weather;

public readonly record struct DailyWeather(
    DateOnly Date, double Tmin, double Tmax, double Tmean, double Precip, double RhMean, double RhMin, double RhMax,
    double DewPoint, double WindKmh, double WindMaxKmh, double SwRad, double Et0)
{
    public DailyWeather With(double dTmin, double dTmax, double precipFactor = 1) =>
        this with { Tmin = Tmin + dTmin, Tmax = Tmax + dTmax, Tmean = Tmean + (dTmin + dTmax) / 2, Precip = Precip * precipFactor };

    /// <summary>Hourly temperature reconstruction: sine rise from Tmin at 06:00 to Tmax at 15:00, decay back to the next Tmin.</summary>
    public double HourlyTemp(int hour)
    {
        if (hour >= 6 && hour <= 15) return Tmin + (Tmax - Tmin) * (1 - Math.Cos(Math.PI * (hour - 6) / 9.0)) / 2;
        double hrsSincePeak = hour > 15 ? hour - 15 : hour + 9;             // 15:00 → 06:00 next day (15 h)
        return Tmin + (Tmax - Tmin) * Math.Exp(-hrsSincePeak / 5.0) * (1 - hrsSincePeak / 15.0 * 0.15);
    }
    public int HoursBetween(double lo, double hi) { int n = 0; for (int h = 0; h < 24; h++) { var t = HourlyTemp(h); if (t >= lo && t <= hi) n++; } return n; }
    public double HoursAbove(double t) { int n = 0; for (int h = 0; h < 24; h++) if (HourlyTemp(h) > t) n++; return n; }

    /// <summary>Leaf-wetness hours proxy (disease.md §2.1): rain hours + hours at RH ≥ 90 %. Game simplification.</summary>
    public double LeafWetHours(double extraFogHours = 0)
    {
        double rainHours = Precip > 0.2 ? Math.Min(20, 2 + Precip * 0.9) : 0;
        double humidHours = RhMax >= 90 ? M.Clamp((RhMean - 65) / 30.0, 0, 1) * 16 + 2 : (RhMax >= 85 ? 2 : 0);
        return M.Clamp(Math.Max(rainHours, humidHours) + 0.5 * Math.Min(rainHours, humidHours) + extraFogHours, 0, 24);
    }
    /// <summary>Mean temperature during the wet period (wetness mostly at night and around dawn).</summary>
    public double WetTemp => Tmin + 0.35 * (Tmax - Tmin);
    /// <summary>Vapour pressure deficit (kPa) at Tmax with RhMin.</summary>
    public double VpdKpa
    {
        get { double es = 0.6108 * Math.Exp(17.27 * Tmax / (Tmax + 237.3)); return Math.Max(0, es * (1 - RhMin / 100.0)); }
    }
}

/// <summary>Historical daily weather per Region, from data/weather/*.csv.gz (Open-Meteo ERA5 seamless, CC BY 4.0).</summary>
public sealed class WeatherArchive
{
    public string RegionFile { get; }
    public double GridElevationM { get; }
    public DateOnly First { get; }
    public DateOnly Last { get; }
    private readonly Dictionary<DateOnly, DailyWeather> _days = new();

    public WeatherArchive(string dataRoot, string regionFile)
    {
        RegionFile = regionFile;
        var meta = JsonDocument.Parse(File.ReadAllText(Path.Combine(dataRoot, "weather", "meta.json")));
        GridElevationM = meta.RootElement.GetProperty("regions").GetProperty(regionFile).GetProperty("grid").GetProperty("elevation_m").GetDouble();
        using var fs = File.OpenRead(Path.Combine(dataRoot, "weather", regionFile + ".csv.gz"));
        using var gz = new GZipStream(fs, CompressionMode.Decompress);
        using var sr = new StreamReader(gz);
        var header = sr.ReadLine()!.Split(',');
        int Col(string n) => Array.IndexOf(header, n);
        int cD = Col("date"), cTmin = Col("tmin"), cTmax = Col("tmax"), cTmean = Col("tmean"), cP = Col("precip"), cRh = Col("rh_mean"),
            cRhMin = Col("rh_min"), cRhMax = Col("rh_max"), cDew = Col("dewpoint"), cW = Col("wind_mean"), cWx = Col("wind_max"), cSw = Col("sw_rad"), cEt = Col("et0");
        string? line;
        var ci = CultureInfo.InvariantCulture;
        while ((line = sr.ReadLine()) != null)
        {
            var f = line.Split(',');
            double D(int i) => i >= 0 && i < f.Length && f[i].Length > 0 ? double.Parse(f[i], ci) : 0;
            var date = DateOnly.ParseExact(f[cD], "yyyy-MM-dd", ci);
            _days[date] = new DailyWeather(date, D(cTmin), D(cTmax), D(cTmean), D(cP), D(cRh), D(cRhMin), D(cRhMax), D(cDew), D(cW), D(cWx), D(cSw), D(cEt));
        }
        First = _days.Keys.Min(); Last = _days.Keys.Max();
    }
    public bool Has(DateOnly d) => _days.ContainsKey(d);
    public DailyWeather Get(DateOnly d) => _days[d];
    public int LastCompleteYear => Last.Month == 12 && Last.Day == 31 ? Last.Year : Last.Year - 1;
}

/// <summary>Regional weather for any date on the Timeline: Historical weather while the archive covers it, then Synthetic weather
/// (seeded resampling of a recent archive year plus the warming trend; spec §3.4, ADR 0002).</summary>
public sealed class RegionWeather
{
    public WeatherArchive Archive { get; }
    private readonly ulong _seed;
    private readonly Dictionary<int, int> _syntheticSourceYear = new();
    public const double WarmingPerYear = 0.04;   // °C per year, from docs/science/weather-validation.md trend (+160…+305 GDD over ~25 y). Game simplification.

    public RegionWeather(WeatherArchive archive, ulong seed) { Archive = archive; _seed = seed; }
    public bool IsHistorical(DateOnly d) => d.Year <= Archive.LastCompleteYear;

    public int SyntheticSourceYear(int year)
    {
        if (!_syntheticSourceYear.TryGetValue(year, out var src))
        {
            var r = Rng.For(_seed, "synthetic-year", year);
            int last = Archive.LastCompleteYear;
            src = r.Int(last - 14, last + 1);
            _syntheticSourceYear[year] = src;
        }
        return src;
    }

    public DailyWeather Get(DateOnly d)
    {
        if (IsHistorical(d) && Archive.Has(d)) return Archive.Get(d);
        int srcYear = SyntheticSourceYear(d.Year);
        int day = Math.Min(d.Day, DateTime.DaysInMonth(srcYear, d.Month));
        var src = Archive.Get(new DateOnly(srcYear, d.Month, day));
        double warm = WarmingPerYear * (d.Year - srcYear);
        return src.With(warm, warm) with { Date = d };
    }
}

/// <summary>Solar geometry for slope/aspect radiation (weather-and-climate.md §3.2; Duffie &amp; Beckman; FAO-56 eq. 21–25).</summary>
public static class Solar
{
    public static double Declination(int doy) => 0.409 * Math.Sin(2 * Math.PI * doy / 365.0 - 1.39);
    /// <summary>Extraterrestrial radiation Ra (MJ m⁻² day⁻¹), FAO-56 eq. 21.</summary>
    public static double Ra(double latDeg, int doy)
    {
        double phi = latDeg * Math.PI / 180, dr = 1 + 0.033 * Math.Cos(2 * Math.PI * doy / 365.0), d = Declination(doy);
        double ws = Math.Acos(M.Clamp(-Math.Tan(phi) * Math.Tan(d), -1, 1));
        return 24 * 60 / Math.PI * 0.0820 * dr * (ws * Math.Sin(phi) * Math.Sin(d) + Math.Cos(phi) * Math.Cos(d) * Math.Sin(ws));
    }
    /// <summary>Daily beam ratio: direct beam on the tilted surface / on the horizontal, integrated in 15-minute steps.
    /// aspectDeg: compass bearing the slope faces (180 = south).</summary>
    public static double BeamRatio(double latDeg, int doy, double slopePct, double aspectDeg)
    {
        double beta = Math.Atan(slopePct / 100.0), gamma = (aspectDeg - 180) * Math.PI / 180, phi = latDeg * Math.PI / 180, d = Declination(doy);
        double sumT = 0, sumH = 0;
        for (int i = 0; i < 96; i++)
        {
            double w = (i / 4.0 - 12 + 0.125) * 15 * Math.PI / 180;
            double cosZ = Math.Sin(d) * Math.Sin(phi) + Math.Cos(d) * Math.Cos(phi) * Math.Cos(w);
            if (cosZ <= 0) continue;
            double cosT = Math.Sin(d) * Math.Sin(phi) * Math.Cos(beta) - Math.Sin(d) * Math.Cos(phi) * Math.Sin(beta) * Math.Cos(gamma)
                        + Math.Cos(d) * Math.Cos(phi) * Math.Cos(beta) * Math.Cos(w) + Math.Cos(d) * Math.Sin(phi) * Math.Sin(beta) * Math.Cos(gamma) * Math.Cos(w)
                        + Math.Cos(d) * Math.Sin(beta) * Math.Sin(gamma) * Math.Sin(w);
            double weight = w > 0 ? 1.2 : 1.0;                  // afternoon sun weighted (warmer air): weather-and-climate.md §3.2
            sumT += Math.Max(0, cosT) * weight; sumH += cosZ * weight;
        }
        return sumH > 0 ? sumT / sumH : 1;
    }
}

/// <summary>Turns regional weather into Block weather (weather-and-climate.md §3): lapse rate, slope/aspect heating,
/// radiation-night frost pockets and thermal belt, marine fog (Napa), plus the documented regional bias correction.</summary>
public sealed class BlockClimate
{
    public const double LapseRate = 0.0065;          // °C per m (FAO-56 eq. 7)
    public const double SlopeHeatCoeff = 11.5;       // a_T, calibrated: 30–35° south slope at 50° N ≈ +200–250 Huglin. UNVERIFIED fit
    public const double KPocket = 4.0;               // °C extra cooling in a full frost pocket on radiation nights; calibrated to Côte d'Or 7 Apr 2021. UNVERIFIED
    public const double KBelt = 1.5;                 // °C night warming in the thermal belt. UNVERIFIED
    private readonly double[] _beam = new double[367];
    private readonly double _lat, _dz, _pocket, _belt, _fogTmax, _radiative, _wind, _slopePct;
    private readonly double _regionTmin, _regionTmax, _regionRain;
    public double SkyView { get; }

    public BlockClimate(PlotData plot, BlockData block, double gridElevationM)
    {
        _lat = plot.Lat;
        _slopePct = block.Topography.SlopePct;
        _dz = block.Topography.ElevationM - gridElevationM;
        _pocket = block.Microclimate.FrostPocket;
        _wind = block.Microclimate.WindExposure;
        _belt = M.Clamp(_slopePct / 40.0, 0, 1) * (1 - _pocket) * 0.8;
        _radiative = block.Microclimate.RadiativeHeat;
        SkyView = (1 + Math.Cos(Math.Atan(_slopePct / 100.0))) / 2;
        for (int doy = 1; doy <= 366; doy++) _beam[doy] = Solar.BeamRatio(_lat, doy, _slopePct, block.Topography.AspectDeg);
        // Documented grid bias (docs/science/weather-validation.md): the Oakville ERA5 cell runs ≈ +2.4 °C warm on the daily mean
        // (+510 GDD vs the published ~1,736) because it misses the marine fog; rainfall ≈ 21 % low. Game simplification: fixed correction.
        if (plot.Region.Id == "napa") { _regionTmax = -3.2; _regionTmin = -1.6; _regionRain = 1.25; _fogTmax = -2.5 * block.Microclimate.FogFrequency; }
        else { _regionTmax = 0; _regionTmin = 0; _regionRain = 1.0; _fogTmax = 0; }
    }

    public double ClearFraction(DailyWeather w) => M.Clamp(w.SwRad / Math.Max(1, 0.75 * Solar.Ra(_lat, w.Date.DayOfYear)), 0, 1);

    public DailyWeather Adjust(DailyWeather w)
    {
        double lapse = -LapseRate * _dz;
        double clear = ClearFraction(w);
        double beamShare = M.Clamp(clear * 0.85, 0.15, 0.85);
        double rTotal = beamShare * _beam[w.Date.DayOfYear] + (1 - beamShare) * SkyView;
        double dTmax = SlopeHeatCoeff * (rTotal - 1) * clear * 0.5;
        double dTmin = 0.2 * dTmax + 0.6 * _radiative * clear;
        bool radiationNight = clear > 0.6 && w.WindKmh < 11;
        if (radiationNight) dTmin += -KPocket * _pocket * (1 - 0.5 * _wind) + KBelt * _belt;
        return w.With(lapse + dTmin + _regionTmin, lapse + dTmax + _regionTmax + _fogTmax, _regionRain);
    }

    /// <summary>Extra leaf-wetness hours from morning fog (river valleys, Carneros), used by the disease model.</summary>
    public double FogWetHours(DailyWeather w, double fogFrequency) =>
        w.RhMax >= 92 && w.Precip < 1 && ClearFraction(w) > 0.3 ? 4 * fogFrequency : 0;
}

/// <summary>What staff can know: a forecast with realistic, growing error. Never the real future (ADR 0002, spec §5.4).</summary>
public sealed class Forecaster
{
    private readonly RegionWeather _w;
    private readonly ulong _seed;
    public Forecaster(RegionWeather w, ulong seed) { _w = w; _seed = seed; }

    public sealed record ForecastDay(DateOnly Date, double Tmin, double Tmax, double RainMm, double RainProb, double RhMean, string Icon, double TminSpread);

    /// <summary>Forecast issued on <paramref name="today"/> for lead days 1..horizon. skill: 0.7 (Senior) … 1.3 (Junior) scales the error.</summary>
    public List<ForecastDay> Issue(DateOnly today, int horizon, double skill, Func<DailyWeather, DailyWeather>? adjust = null)
    {
        var list = new List<ForecastDay>();
        for (int lead = 1; lead <= horizon; lead++)
        {
            var d = today.AddDays(lead);
            var truth = _w.Get(d);
            if (adjust != null) truth = adjust(truth);
            var r = Rng.For(_seed, "forecast", today.DayNumber, lead);
            double sd = (0.7 + 0.32 * lead) * skill;
            double tmin = truth.Tmin + r.Gauss(0, sd), tmax = truth.Tmax + r.Gauss(0, sd);
            bool wet = truth.Precip >= 1;
            double pWet = wet ? M.Clamp(0.9 - 0.055 * lead * skill, 0.35, 0.95) : M.Clamp(0.05 + 0.045 * lead * skill, 0.03, 0.5);
            if (r.NextDouble() < 0.12 * lead / horizon * skill) pWet = 1 - pWet;        // occasional busts
            double rain = pWet >= 0.5 ? Math.Max(0.5, truth.Precip * r.Range(0.5, 1.5) + (wet ? 0 : r.Range(1, 5))) : (pWet > 0.3 ? r.Range(0, 1.5) : 0);
            string icon = pWet >= 0.55 ? "rain" : truth.RhMean > 88 && pWet < 0.3 ? "fog" : truth.SwRad > 14 ? "sun" : "cloud";
            list.Add(new ForecastDay(d, M.Round(tmin, 1), M.Round(tmax, 1), M.Round(rain, 1), M.Round(pWet, 2), truth.RhMean, icon, sd));
        }
        return list;
    }
}
