using System.Collections.Concurrent;
using TerroirEngine.Data;
using TerroirEngine.Weather;

namespace TerroirEngine.Tasting.Practice;

/// <summary>A vintage in numbers, from the Region's weather record (ERA5 grid cell, docs/science/weather-and-climate.md):
/// Winkler growing-degree days (Apr–Oct, base 10 °C), the mean summer maximum (Jun–Aug), autumn rain (Sep–Oct), hot days
/// (maximum ≥ 30 °C), the coldest spring night (Apr–May), and where the year's degree-days rank in the record (1 = warmest).
/// The grid cell is the Region's reference weather, not a particular slope (frost lies colder in low spots).</summary>
public sealed record VintageFacts(string RegionId, int Year, double Gdd, double SummerTmax, double AutumnRainMm, int HotDays,
    double SpringFrostC, DateOnly SpringFrostDate, int GddRank, int RecordYears, int RecordFrom, int RecordTo, double Gst = 0)
{
    /// <summary>The Region's absolute climate class from its average growing-season temperature (April–October mean) over the
    /// record years: cool ≤ 16.5 °C, moderate to 18.5, warm to 21, hot above (UW-2016 p. 30). Game simplification: the
    /// Region's ERA5 grid cell stands for its vineyards. Inside a game the average stops at upTo (ADR 0002).</summary>
    public static (string Class, double MeanGst) RegionClass(GameData data, string regionId, int? upTo = null)
    {
        double m = Math.Round(Record(data, regionId, upTo).Average(f => f.Gst), 1);
        return (m <= 16.5 ? "cool" : m <= 18.5 ? "moderate" : m <= 21 ? "warm" : "hot", m);
    }

    public const int FirstRecordYear = 1995;

    private static readonly ConcurrentDictionary<string, WeatherArchive> Archives = new();
    private static readonly ConcurrentDictionary<string, VintageFacts[]> Records = new();

    public static WeatherArchive Archive(GameData data, string regionId) =>
        Archives.GetOrAdd(data.DataRoot + "|" + regionId, _ => new WeatherArchive(data.DataRoot, data.Region(regionId).WeatherFile));

    /// <summary>The last vintage the record covers in full.</summary>
    public static int LastRecordYear(GameData data, string regionId) => Archive(data, regionId).LastCompleteYear;

    /// <summary>Every vintage from 1995 to the end of the record, or to upTo (inside a game: the last vintage harvested on its
    /// Timeline, so ranks never count years the player cannot know yet; ADR 0002), ranked by growing-degree days.</summary>
    public static IReadOnlyList<VintageFacts> Record(GameData data, string regionId, int? upTo = null)
    {
        var arc = Archive(data, regionId);
        int to = Math.Min(arc.LastCompleteYear, upTo ?? int.MaxValue);
        if (to < FirstRecordYear) to = FirstRecordYear;
        return Records.GetOrAdd($"{data.DataRoot}|{regionId}|{to}", _ =>
        {
            var raw = Enumerable.Range(FirstRecordYear, to - FirstRecordYear + 1).Select(y => Compute(arc, regionId, y)).ToList();
            var byGdd = raw.OrderByDescending(f => f.Gdd).Select(f => f.Year).ToList();
            return raw.Select(f => f with { GddRank = byGdd.IndexOf(f.Year) + 1, RecordYears = raw.Count, RecordFrom = FirstRecordYear, RecordTo = to }).ToArray();
        });
    }

    public static VintageFacts For(GameData data, string regionId, int year, int? upTo = null) =>
        Record(data, regionId, upTo is int u && u < year ? year : upTo).First(f => f.Year == year);

    /// <summary>The coldest night (lowest minimum) between two dates, in the Region's record.</summary>
    public static (DateOnly Date, double Tmin) ColdestNight(GameData data, string regionId, DateOnly from, DateOnly to)
    {
        var arc = Archive(data, regionId);
        (DateOnly, double) best = (from, double.MaxValue);
        for (var d = from; d <= to; d = d.AddDays(1))
            if (arc.Has(d) && arc.Get(d).Tmin < best.Item2) best = (d, arc.Get(d).Tmin);
        return best;
    }

    private static VintageFacts Compute(WeatherArchive arc, string regionId, int y)
    {
        double gdd = 0, tmaxSum = 0, rain = 0, tmeanSum = 0; int n = 0, hot = 0, days = 0;
        for (var d = new DateOnly(y, 4, 1); d <= new DateOnly(y, 10, 31); d = d.AddDays(1))
        {
            var w = arc.Get(d);
            tmeanSum += (w.Tmax + w.Tmin) / 2; days++;
            gdd += Math.Max(0, (w.Tmax + w.Tmin) / 2 - 10);
            if (d.Month is >= 6 and <= 8) { tmaxSum += w.Tmax; n++; if (w.Tmax >= 30) hot++; }
            if (d.Month is 9 or 10) rain += w.Precip;
        }
        var arcFrost = new DateOnly(y, 4, 1);
        double frostC = double.MaxValue;
        for (var d = new DateOnly(y, 4, 1); d <= new DateOnly(y, 5, 31); d = d.AddDays(1))
            if (arc.Get(d).Tmin < frostC) { frostC = arc.Get(d).Tmin; arcFrost = d; }
        return new VintageFacts(regionId, y, Math.Round(gdd), Math.Round(tmaxSum / n, 1), Math.Round(rain), hot, frostC, arcFrost, 0, 0, 0, 0, Math.Round(tmeanSum / days, 1));
    }
}
