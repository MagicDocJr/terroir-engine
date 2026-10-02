using System.Text.Json.Nodes;
using TerroirEngine.Data;
using TerroirEngine.Learning;

namespace TerroirEngine.Tasting.Practice;

/// <summary>What Tasting practice pours next: a seeded random Wine, one aimed at the player's weakest skill (adaptive practice),
/// or the Glass of the day (seeded by the date). Vintages come from 1995 to the end of the weather record, and inside a game only
/// up to the last vintage harvested on its Timeline (ADR 0002).</summary>
public static class PracticePours
{
    public const int FirstVintage = VintageFacts.FirstRecordYear;

    private static readonly (string Region, string Variety)[] Combos =
    {
        ("mosel", "Riesling"), ("cote-dor", "Pinot Noir"), ("cote-dor", "Chardonnay"), ("napa", "Cabernet Sauvignon"),
    };

    /// <summary>(Region, Variety, vintage) the simulation does not yet reproduce (docs/backlog.md, science review): random pours
    /// skip them so practice never teaches a wrong vintage. Côte d'Or spring frost is far too harsh in 2019, 2020 and 2022, and
    /// Mosel 2010's tiny, very acidic crop comes out normal.</summary>
    private static readonly HashSet<(string, string, int)> Skip = new()
    {
        ("cote-dor", "Chardonnay", 2019), ("cote-dor", "Chardonnay", 2020), ("cote-dor", "Chardonnay", 2022),
        ("cote-dor", "Pinot Noir", 2019), ("cote-dor", "Pinot Noir", 2020), ("cote-dor", "Pinot Noir", 2022),
        ("mosel", "Riesling", 2010),
    };

    public static bool Miscalibrated(string regionId, string variety, int vintage) => Skip.Contains((regionId, variety, vintage));

    /// <summary>False inside a game that has not yet harvested a vintage Tasting practice can pour.</summary>
    public static bool Available(int? maxVintage) => maxVintage == null || maxVintage >= FirstVintage;

    public static PourSpec Random(GameData data, int seed, int? maxVintage = null, string? focus = null)
    {
        if (!Available(maxVintage)) throw new InvalidOperationException($"no vintage from {FirstVintage} on has been harvested yet");
        var rng = new System.Random(seed * 7919 + 13);
        var combos = focus switch
        {
            "tannin" or "appearance" => Combos.Where(c => c.Variety is "Pinot Noir" or "Cabernet Sauvignon").ToArray(),
            "sweetness" => Combos.Where(c => c.Variety == "Riesling").ToArray(),
            "nose" => Combos.Where(c => c.Variety is "Chardonnay" or "Riesling" or "Pinot Noir").ToArray(),
            _ => Combos,
        };
        var (region, variety) = combos[rng.Next(combos.Length)];
        var plots = data.Region(region).Plots;
        var plot = plots[rng.Next(plots.Count)];
        int last = Math.Min(VintageFacts.LastRecordYear(data, region), maxVintage ?? int.MaxValue);
        int vintage = FirstVintage + rng.Next(last - FirstVintage + 1);
        for (int tries = 0; tries < 50 && Miscalibrated(region, variety, vintage); tries++) vintage = FirstVintage + rng.Next(last - FirstVintage + 1);
        string? style = focus switch
        {
            "sweetness" => new[] { "dry", "off-dry", "kabinett", "spatlese", "auslese" }[rng.Next(5)],
            "nose" when variety == "Chardonnay" => new[] { "steel", "new-oak", "old-oak" }[rng.Next(3)],
            _ => null,
        };
        return new PourSpec(plot.Id, vintage, Variety: variety, Style: style);
    }

    /// <summary>A pour aimed at the weakest skill in the record (or a random one while there is too little history).</summary>
    public static (PourSpec Spec, string? Focus) Suggest(GameData data, JsonObject record, int seed, int? maxVintage = null)
    {
        var focus = PracticeProgress.Weakest(record);
        return (Random(data, seed, maxVintage, focus), focus);
    }

    /// <summary>The Glass of the day: the same Wine for everyone all day long.</summary>
    public static PourSpec Daily(GameData data, DateOnly date, int? maxVintage = null) => Random(data, date.DayNumber, maxVintage);

    public static int DailySeed(DateOnly date) => date.DayNumber % 100000 + 1;

    /// <summary>A new Wine that shows the Cause (its sheet is tagged with it), found from the Cause's pour hints; null for a
    /// chain-reviewed Cause or when six candidates do not show it (the session then falls back to the chain).</summary>
    public static PouredWine? ForCause(GameData data, Cause c, int seed, int? maxVintage)
    {
        if (c.ReviewBy != "wine" || !Available(maxVintage)) return null;
        for (int i = 0; i < 6; i++)
        {
            int sd = seed * 37 + i;
            try
            {
                var p = TastingLab.Pour(data, CausePours.Spec(data, c, sd, maxVintage), sd);
                if (p.Sheet.Causes.Contains(c.Id)) return p;
            }
            catch (InvalidOperationException) { }
        }
        return null;
    }

    private static string[] StylesFor(string variety) => variety switch
    {
        "Riesling" => new[] { "dry", "off-dry", "kabinett", "spatlese", "auslese" },
        "Chardonnay" => new[] { "steel", "old-oak", "new-oak" },
        _ => new[] { "classic", "light", "extracted" },
    };

    /// <summary>Two Wines from the same Block that differ in this Cause: one shows it, the other (another cellar style, or
    /// another vintage) does not. Null when no such pair turns up.</summary>
    public static (PouredWine With, PouredWine Without)? ContrastFor(GameData data, Cause c, int seed, int? maxVintage)
    {
        var with = ForCause(data, c, seed, maxVintage);
        if (with == null) return null;
        var x = with.Context;
        var candidates = StylesFor(x.Variety).Where(st => st != x.StyleId).Select(st => new PourSpec(x.PlotId, x.Vintage, x.BlockId, x.Variety, st)).ToList();
        var years = VintageFacts.Record(data, x.RegionId, maxVintage).Select(f => f.Year)
            .Where(y => y != x.Vintage && !Miscalibrated(x.RegionId, x.Variety, y)).OrderBy(y => new Random(seed * 13 + y).Next()).Take(4);
        candidates.AddRange(years.Select(y => new PourSpec(x.PlotId, y, x.BlockId, x.Variety, x.StyleId)));
        foreach (var spec in candidates)
        {
            try
            {
                var w = TastingLab.Pour(data, spec, seed * 41 + 1);
                if (!w.Sheet.Causes.Contains(c.Id)) return (with, w);
            }
            catch (InvalidOperationException) { }
        }
        return null;
    }
}
