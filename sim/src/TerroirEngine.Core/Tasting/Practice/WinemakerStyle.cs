namespace TerroirEngine.Tasting.Practice;

/// <summary>How the invented producer at a Tasting-practice pour makes its Wine (tasting-practice design §3): a harvest
/// ripeness offset and cellar choices on top of the Region's house style (GameSession.DefaultCellarChoices).
/// Game simplification: a handful of recognisable styles within each Region's norms.</summary>
public sealed record WinemakerStyle(string Id, string Label, double OeOffset, IReadOnlyDictionary<string, int> Choices,
    double? TargetOe = null, Closure Closure = Closure.Screwcap, bool FaultProne = false)
{
    private static Dictionary<string, int> C(params (string k, int v)[] kv) => kv.ToDictionary(x => x.k, x => x.v);

    public static readonly WinemakerStyle[] All =
    {
        // Riesling
        new("dry", "dry, steel-fermented", 0, C(("Sweetness", 0))),
        new("off-dry", "off-dry, fermentation stopped with some sugar left", 0, C(("Sweetness", 1))),
        new("kabinett", "Kabinett: picked light, stopped medium-sweet", 0, C(("Sweetness", 2)), TargetOe: 76),       // Kabinett ≥ 73 °Oe (law.md)
        new("spatlese", "Spätlese: picked riper, stopped medium-sweet", 0, C(("Sweetness", 2)), TargetOe: 83),       // Spätlese ≥ 80 °Oe
        new("auslese", "Auslese: selected very ripe bunches, stopped sweet", 0, C(("Sweetness", 3)), TargetOe: 95),       // Auslese ≥ 88 °Oe
        // Chardonnay
        new("steel", "steel-fermented, no malolactic, off the lees", 0, C(("Vessel", 0), ("MLF", 0), ("Lees", 1), ("Temperature", 0))),
        new("new-oak", "barrel-fermented in new French oak, malolactic, lees stirring", 3, C(("Vessel", 4), ("MLF", 1), ("Lees", 2), ("Ageing", 2), ("Temperature", 2))),
        new("old-oak", "fermented in old barriques, malolactic, fine lees", 0, C(("Vessel", 2), ("MLF", 1), ("Lees", 0), ("Ageing", 2))),
        // reds
        new("classic", "the Region's classic way", 0, C()),
        new("light", "picked earlier, gentle pump-overs, cooler fermentation, old wood", -8, C(("Cap management", 0), ("Red temperature", 1), ("Vessel", 2))),
        new("extracted", "picked late, warm fermentation, long maceration, new oak", 10, C(("Red temperature", 2), ("Maceration", 1), ("Vessel", 4), ("Ageing", 3))),
        // any: a rustic, fault-prone cellar (ambient yeast, low SO₂, long in old wood, natural cork)
        new("rustic", "ambient yeast, low sulphur, long in old casks, natural cork", 0, C(("Yeast", 1), ("SO₂", 1), ("Vessel", 1), ("Ageing", 3)),
            Closure: Closure.NaturalCork, FaultProne: true),
    };

    public static WinemakerStyle Get(string id) => All.First(s => s.Id == id);

    /// <summary>The styles that fit a Variety (the ripeness ladder is only for Mosel Riesling stands, asked by id).</summary>
    public static string[] For(string variety) => variety switch
    {
        "Riesling" => new[] { "dry", "off-dry", "dry", "off-dry" },
        "Chardonnay" => new[] { "steel", "new-oak", "old-oak" },
        _ => new[] { "classic", "classic", "light", "extracted" },
    };

    /// <summary>A seeded pick; a few per cent of pours get the fault-prone rustic cellar (spotting faults is part of the exam).</summary>
    public static WinemakerStyle Pick(string variety, int seed)
    {
        var r = new Random(seed * 7919 + variety.Length);
        if (r.NextDouble() < 0.05) return Get("rustic");
        var ids = For(variety);
        return Get(ids[r.Next(ids.Length)]);
    }
}
