using System.Collections.Concurrent;
using System.Text.Json;
using TerroirEngine.Data;
using TerroirEngine.Tasting.Practice;

namespace TerroirEngine.Learning;

/// <summary>Where to find a Wine that shows a Cause: Region, Variety, winemaker style and a vintage class (cool, warm, frost
/// or any), all optional.</summary>
public sealed record CausePour(string? Region, string? Variety, string? Style, string? VintageClass);

/// <summary>One cause→effect link the simulation models and the game teaches (learning-core design §3): a 2–4 step chain
/// from a condition or decision to the glass, the Tasting-sheet line it shows on, its Level 3 topic (paraphrased) and the
/// docs/science sections that back it. ReviewBy "chain" marks a Cause practice pours rarely show (faults, sunburn): it is
/// reviewed with chain questions only.</summary>
public sealed record Cause(string Id, string Title, string[] Chain, string Topic, string Level, string Line, string[] Sources, CausePour Pour, string ReviewBy = "wine");

/// <summary>Loads data/causes.json.</summary>
public static class CauseCatalog
{
    private static readonly ConcurrentDictionary<string, IReadOnlyList<Cause>> Cache = new();

    public static IReadOnlyList<Cause> All(GameData data) => Cache.GetOrAdd(data.DataRoot, root =>
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(Path.Combine(root, "causes.json")));
        string? S(JsonElement e, string k) => e.TryGetProperty(k, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;
        string[] A(JsonElement e, string k) => e.TryGetProperty(k, out var v) ? v.EnumerateArray().Select(x => x.GetString()!).ToArray() : Array.Empty<string>();
        return doc.RootElement.GetProperty("causes").EnumerateArray().Select(e =>
        {
            var p = e.TryGetProperty("pour", out var pe) ? pe : default;
            var pour = p.ValueKind == JsonValueKind.Object ? new CausePour(S(p, "region"), S(p, "variety"), S(p, "style"), S(p, "vintageClass")) : new CausePour(null, null, null, null);
            return new Cause(S(e, "id")!, S(e, "title")!, A(e, "chain"), S(e, "topic") ?? "", S(e, "level") ?? "L3", S(e, "line") ?? "", A(e, "sources"), pour, S(e, "reviewBy") ?? "wine");
        }).ToArray();
    });

    public static Cause Get(GameData data, string id) => All(data).First(c => c.Id == id);
    public static Cause? Find(GameData data, string id) => All(data).FirstOrDefault(c => c.Id == id);

    /// <summary>"file.md#heading text": the science doc exists under docs/science and has a heading containing the text.</summary>
    public static bool SourceResolves(GameData data, string source)
    {
        var parts = source.Split('#', 2);
        var path = Path.Combine(Path.GetDirectoryName(Path.GetFullPath(data.DataRoot))!, "docs", "science", parts[0]);
        if (!File.Exists(path)) return false;
        if (parts.Length == 1) return true;
        return File.ReadLines(path).Any(l => l.StartsWith('#') && l.Contains(parts[1], StringComparison.OrdinalIgnoreCase));
    }
}

/// <summary>Finds Wines that show a Cause (review pours, reference pours).</summary>
public static class CausePours
{
    private static readonly string[] Regions = { "mosel", "cote-dor", "napa" };
    private static readonly Dictionary<string, string[]> Grapes = new()
    {
        ["mosel"] = new[] { "Riesling" }, ["cote-dor"] = new[] { "Pinot Noir", "Chardonnay" }, ["napa"] = new[] { "Cabernet Sauvignon" },
    };

    /// <summary>A seeded candidate pour for a Cause: its hints fill what they name, the seed the rest. Vintages come from the
    /// class (coolest or warmest third of the record by growing-degree days, the third with the coldest spring nights, or any),
    /// inside the Timeline (maxVintage) and never from a year the simulation does not yet reproduce.</summary>
    public static PourSpec Spec(GameData data, Cause c, int seed, int? maxVintage)
    {
        var rng = new Random(seed * 104729 + c.Id.Sum(ch => ch));
        string region = c.Pour.Region ?? Regions[rng.Next(Regions.Length)];
        string variety = c.Pour.Variety ?? Grapes[region][rng.Next(Grapes[region].Length)];
        var plots = data.Region(region).Plots;
        var plot = plots[rng.Next(plots.Count)];
        var record = VintageFacts.Record(data, region, maxVintage).ToList();
        int n = record.Count;
        var pool = (c.Pour.VintageClass ?? "any") switch
        {
            "cool" => record.Where(f => f.GddRank > n * 2 / 3.0),
            "warm" => record.Where(f => f.GddRank <= n / 3.0),
            "frost" => record.OrderBy(f => f.SpringFrostC).Take(Math.Max(1, n / 3)),
            _ => record,
        };
        var years = pool.Select(f => f.Year).Where(y => !PracticePours.Miscalibrated(region, variety, y)).OrderBy(y => y).ToList();
        if (years.Count == 0) years = record.Select(f => f.Year).Where(y => !PracticePours.Miscalibrated(region, variety, y)).ToList();
        int vintage = years[rng.Next(years.Count)];
        return new PourSpec(plot.Id, vintage, Variety: variety, Style: c.Pour.Style);
    }
}
