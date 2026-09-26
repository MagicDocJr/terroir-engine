namespace TerroirEngine.Util;

/// <summary>Deterministic pseudo-random numbers (SplitMix64). Every stream is derived from the game seed and a purpose key,
/// so replaying the same decisions always gives the same game (ADR 0001).</summary>
public sealed class Rng
{
    private ulong _state;
    public Rng(ulong seed) { _state = seed == 0 ? 0x9E3779B97F4A7C15UL : seed; }
    public static Rng For(ulong gameSeed, string purpose, int a = 0, int b = 0)
    {
        ulong h = gameSeed ^ 0xCBF29CE484222325UL;
        foreach (char c in purpose) { h ^= c; h *= 0x100000001B3UL; }
        h ^= (ulong)(uint)a * 0x9E3779B97F4A7C15UL;
        h ^= (ulong)(uint)b * 0xC2B2AE3D27D4EB4FUL;
        return new Rng(h);
    }
    public ulong NextU64()
    {
        ulong z = (_state += 0x9E3779B97F4A7C15UL);
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
        z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;
        return z ^ (z >> 31);
    }
    public double NextDouble() => (NextU64() >> 11) * (1.0 / (1UL << 53));
    public double Range(double lo, double hi) => lo + (hi - lo) * NextDouble();
    public int Int(int loInclusive, int hiExclusive) => loInclusive + (int)(NextDouble() * (hiExclusive - loInclusive));
    public double Gauss(double mean = 0, double sd = 1)
    {
        double u1 = Math.Max(1e-12, NextDouble()), u2 = NextDouble();
        return mean + sd * Math.Sqrt(-2 * Math.Log(u1)) * Math.Cos(2 * Math.PI * u2);
    }
}

public static class M
{
    public static double Clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
    public static double Clamp01(double v) => Clamp(v, 0, 1);
    public static double Lerp(double a, double b, double t) => a + (b - a) * t;
    public static double Sigmoid(double x) => 1.0 / (1.0 + Math.Exp(-x));
    public static double SmoothStep(double a, double b, double x) { var t = Clamp01((x - a) / (b - a)); return t * t * (3 - 2 * t); }
    public static double Round(double v, int d) => Math.Round(v, d, MidpointRounding.AwayFromZero);
}

/// <summary>Must and wine unit conversions (docs/science/fermentation.md §2, ripening.md §3.2).</summary>
public static class Units
{
    /// <summary>Specific gravity from °Brix (standard brewing/winemaking relation).</summary>
    public static double SgFromBrix(double brix) => 1 + brix / (258.6 - brix / 258.2 * 227.1);
    public static double OeFromBrix(double brix) => (SgFromBrix(brix) - 1) * 1000;
    public static double BrixFromOe(double oe)
    {
        // invert numerically (monotonic)
        double lo = 0, hi = 45;
        for (int i = 0; i < 50; i++) { double mid = (lo + hi) / 2; if (OeFromBrix(mid) < oe) lo = mid; else hi = mid; }
        return (lo + hi) / 2;
    }
    /// <summary>Sugar g/L from °Brix: S ≈ 10·SG·°Brix − 25 (removes non-sugar solids; game simplification).</summary>
    public static double SugarFromBrix(double brix) => Math.Max(0, 10 * SgFromBrix(brix) * brix - 25);
    public static double BrixFromSugar(double sugarGL)
    {
        double lo = 0, hi = 45;
        for (int i = 0; i < 50; i++) { double mid = (lo + hi) / 2; if (SugarFromBrix(mid) < sugarGL) lo = mid; else hi = mid; }
        return (lo + hi) / 2;
    }
    public static double OeFromSugar(double sugarGL) => OeFromBrix(BrixFromSugar(sugarGL));
    public static double SugarFromOe(double oe) => SugarFromBrix(BrixFromOe(oe));
    /// <summary>EU convention: 16.83 g/L sugar per 1 % vol potential alcohol.</summary>
    public static double PotentialAlcohol(double sugarGL) => sugarGL / 16.83;
    public static double EthanolGLToPctVol(double ethanolGL) => ethanolGL / 7.89;
    public static double PctVolToEthanolGL(double pct) => pct * 7.89;
}

public static class Dates
{
    public static int Doy(DateOnly d) => d.DayOfYear;
    public static string MonthName(int m) => System.Globalization.CultureInfo.InvariantCulture.DateTimeFormat.GetAbbreviatedMonthName(m);
    public static string Short(DateOnly d) => d.ToString("d MMM", System.Globalization.CultureInfo.InvariantCulture);
    public static string Long(DateOnly d) => d.ToString("ddd d MMM yyyy", System.Globalization.CultureInfo.InvariantCulture);
    public static string Iso(DateOnly d) => d.ToString("yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);
}
