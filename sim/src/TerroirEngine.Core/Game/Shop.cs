using System.Collections.Concurrent;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace TerroirEngine.Game;

/// <summary>One look choice for sale (data/shop.json): bought once, then switched freely. Price 0 = everyone has it.</summary>
public sealed record ShopOption(string Value, string Label, string Blurb, double Price);
public sealed record ShopSection(string Key, string Label, IReadOnlyList<ShopOption> Options);
/// <summary>Vineyard and cellar equipment: unlike the look, it changes the simulation (spec §6). Params are cited in
/// docs/science/economy.md and phenology.md §6.</summary>
public sealed record ShopEquipment(string Id, string Label, string Category, double Price, bool Owned, string Blurb, string What, string When, IReadOnlyDictionary<string, double> Params)
{
    public double P(string key, double fallback = 0) => Params.TryGetValue(key, out var v) ? v : fallback;
}
public sealed record ShopCatalog(IReadOnlyList<ShopSection> Look, IReadOnlyDictionary<string, Dictionary<string, string>> RegionalStart,
    IReadOnlyDictionary<string, Dictionary<string, string>> LegacyStart, IReadOnlyList<ShopEquipment> Equipment)
{
    public ShopSection? Section(string key) => Look.FirstOrDefault(s => s.Key == key);
    public ShopOption? Option(string key, string value) => Section(key)?.Options.FirstOrDefault(o => o.Value == value);
    public ShopEquipment? Item(string id) => Equipment.FirstOrDefault(e => e.Id == id);
}

/// <summary>The Shop (docs/superpowers/specs/2026-10-07-equipment-shop-design.md): the catalogue in data/shop.json.</summary>
public static class Shop
{
    /// <summary>Ledger categories for purchases.</summary>
    public const string LookCategory = "Winery", EquipmentCategory = "Equipment";
    /// <summary>The frost methods, best first: the frost Programme uses the best one you own (spec §6).</summary>
    public static readonly string[] FrostMethods = { "sprinklers", "wind-machine", "candles" };

    private static readonly ConcurrentDictionary<string, ShopCatalog> Cache = new();

    public static ShopCatalog Catalog(Data.GameData data) => Cache.GetOrAdd(data.DataRoot, root =>
    {
        var doc = JsonNode.Parse(File.ReadAllText(Path.Combine(root, "shop.json")))!;
        static Dictionary<string, Dictionary<string, string>> Starts(JsonNode? n) => (n as JsonObject ?? new()).ToDictionary(kv => kv.Key,
            kv => kv.Value!.AsObject().ToDictionary(x => x.Key, x => (string)x.Value!));
        var look = doc["look"]!.AsArray().Select(s => new ShopSection((string)s!["key"]!, (string)s["label"]!,
            s["options"]!.AsArray().Select(o => new ShopOption((string)o!["value"]!, (string)o["label"]!, (string)o["blurb"]!, (double)o["price"]!)).ToList())).ToList();
        var eq = doc["equipment"]!.AsArray().Select(e => new ShopEquipment((string)e!["id"]!, (string)e["label"]!, (string)e["category"]!, (double)e["price"]!,
            (bool?)e["owned"] ?? false, (string)e["blurb"]!, (string)e["what"]!, (string)e["when"]!,
            (e["params"] as JsonObject ?? new()).ToDictionary(kv => kv.Key, kv => (double)kv.Value!))).ToList();
        return new ShopCatalog(look, Starts(doc["regionalStart"]), Starts(doc["legacyStart"]), eq);
    });
}
