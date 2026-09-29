using System.Text.Json.Nodes;
using TerroirEngine.Data;

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
}
