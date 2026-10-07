namespace TerroirEngine.Game;

/// <summary>The Shop (docs/superpowers/specs/2026-10-07-equipment-shop-design.md): the Estate's cash buys winery looks and
/// equipment. Purchases are `buy &lt;section&gt; &lt;value&gt;` commands (section "equipment" for equipment), replayed with the save.</summary>
public sealed partial class GameSession
{
    private readonly HashSet<string> _bought = new();
    /// <summary>Why the last `buy` was refused ("" when it went through), for the UI's message.</summary>
    public string ShopRefusal { get; private set; } = "";

    /// <summary>Games from before the shop (ShopVersion 0) keep the free look panel until loaded once: the full cozy regional
    /// look and every look chosen are then owned for free (migration in <see cref="Load"/>).</summary>
    private bool LegacyShop => Setup.ShopVersion == 0;

    private ShopCatalog ShopData => Shop.Catalog(Data);

    /// <summary>The look a game starts with: a new Estate has the Region's own walls and floor (the building is made of
    /// them) and the plain working winery elsewhere; a game from before the shop had the full cozy regional look.</summary>
    public Dictionary<string, string> StartLook()
    {
        var src = Setup.StartLook ?? (LegacyShop ? ShopData.LegacyStart : ShopData.RegionalStart).GetValueOrDefault(Region.Id) ?? new();
        var look = new Dictionary<string, string>();
        foreach (var s in ShopData.Look)
            look[s.Key] = src.TryGetValue(s.Key, out var v) && s.Options.Any(o => o.Value == v) ? v : s.Options.FirstOrDefault(o => o.Price == 0)?.Value ?? s.Options[0].Value;
        return look;
    }

    public bool OwnsLook(string key, string value)
    {
        var o = ShopData.Option(key, value);
        if (o == null) return false;
        return o.Price == 0 || _bought.Contains($"{key}:{value}") || Setup.ShopGrants.Contains($"{key}:{value}") || StartLook()[key] == value;
    }

    /// <summary>Games from before the shop keep rigorous sorting (they had it without a table), so they own the sorting table.</summary>
    public bool OwnsEquipment(string id) => ShopData.Item(id) is { } e && (e.Owned || _bought.Contains($"equipment:{id}") || Setup.ShopGrants.Contains($"equipment:{id}") || (LegacyShop && e.Id == "sorting-table"));

    /// <summary>The look in use: the player's choice if owned, else the start look.</summary>
    public Dictionary<string, string> LookInUse()
    {
        var look = StartLook();
        foreach (var s in ShopData.Look)
            if (Decor.TryGetValue(s.Key, out var v) && !string.IsNullOrEmpty(v) && OwnsLook(s.Key, v)) look[s.Key] = v;
        return look;
    }

    /// <summary>Price of an item (0 if unknown or owned).</summary>
    public double ShopPrice(string section, string value) => section == "equipment"
        ? (OwnsEquipment(value) ? 0 : EquipmentPrice(value))
        : (OwnsLook(section, value) ? 0 : ShopData.Option(section, value)?.Price ?? 0);

    /// <summary>An item's list price on this Plot: per-hectare items (sprinklers) scale with the Plot's area.</summary>
    public double EquipmentPrice(string id) => ShopData.Item(id) is { } e ? (e.P("perHa") > 0 ? Math.Round(e.P("perHa") * Blocks.Sum(b => b.AreaHa) / 100) * 100 : e.Price) : 0;

    /// <summary>How much cash is missing to buy it (0 = affordable).</summary>
    public double ShopGap(string section, string value) => Math.Max(0, ShopPrice(section, value) - Math.Max(0, Ledger.Cash));

    /// <summary>Why an item cannot be offered on this Plot ("" = it can).</summary>
    public string ShopUnavailable(string id) => id switch
    {
        // Overhead sprinklers need a big, reliable water supply and a pump; on the steep Mosel slate there is none (spec §6)
        "sprinklers" when Region.Id == "mosel" && Plot.SlopePct >= 30 => "Not on these steep slate slopes: there is no water supply for overhead sprinklers.",
        // a fan tower needs flat or gently sloping ground; on steep slopes the cold air drains away downhill anyway (UNVERIFIED rule)
        "wind-machine" when Plot.SlopePct >= 30 => "Not on a slope this steep: a fan tower needs gentle ground, and cold air drains off steep slopes by itself.",
        _ => "",
    };

    private void Buy(Command c)
    {
        ShopRefusal = "";
        string section = c.A, value = c.B;
        bool equip = section == "equipment";
        string label;
        double price;
        if (equip)
        {
            var e = ShopData.Item(value);
            if (e == null || OwnsEquipment(value)) return;
            if (ShopUnavailable(value) is { Length: > 0 } why) { ShopRefusal = why; return; }
            label = e.Label; price = EquipmentPrice(value);
        }
        else
        {
            var o = ShopData.Option(section, value);
            if (o == null || OwnsLook(section, value)) return;
            label = $"{ShopData.Section(section)!.Label}: {o.Label}"; price = o.Price;
        }
        double gap = ShopGap(section, value);
        if (gap > 0) { ShopRefusal = $"Not enough cash for {label}: €{gap:N0} short."; return; }
        _bought.Add($"{section}:{value}");
        Ledger.Post(Date, equip ? Shop.EquipmentCategory : Shop.LookCategory, -price, $"Shop: {label}");
        if (!equip) Decor[section] = value;   // a new look goes straight into use
    }

    private readonly HashSet<int> _treated = new();

    /// <summary>The first Wine sold of a Vintage invites you to the Shop, once per Vintage, when the cash would buy
    /// something (spec §3: a friendly line, never an alert).</summary>
    private bool ShopTreat(int? vintage)
    {
        if (LegacyShop || vintage is not int v || !_treated.Add(v)) return false;
        return ShopData.Look.Any(s => s.Options.Any(o => !OwnsLook(s.Key, o.Value) && o.Price <= Ledger.Cash));
    }

    private void SetDecor(Command c)
    {
        if (string.IsNullOrWhiteSpace(c.A)) return;
        string v = c.B ?? "";
        if (LegacyShop)
        {
            Decor[c.A] = v;
            if (v != "") _bought.Add($"{c.A}:{v}");   // before the shop every look was free: what was chosen is kept
            return;
        }
        if (ShopData.Section(c.A) is null) { Decor[c.A] = v; return; }   // a key this build doesn't sell: stored, harmless
        if (v == "" || OwnsLook(c.A, v)) Decor[c.A] = v;
    }

    /// <summary>Harness only (the 3D look harness and the thumbnail renderer): own every look and piece of equipment.</summary>
    public void HarnessOwnAll()
    {
        foreach (var s in ShopData.Look) foreach (var o in s.Options) Setup.ShopGrants.Add($"{s.Key}:{o.Value}");
        foreach (var e in ShopData.Equipment) Setup.ShopGrants.Add($"equipment:{e.Id}");
    }

    /// <summary>Loading a game from before the shop: its start look and every look chosen become owned for free.</summary>
    private void MigrateShop()
    {
        if (!LegacyShop) return;
        var start = StartLook();
        var grants = _bought.Where(x => !x.StartsWith("equipment:", StringComparison.Ordinal)).Append("equipment:sorting-table").ToList();
        Setup.StartLook = start;
        Setup.ShopGrants = grants;
        Setup.ShopVersion = 1;
        foreach (var gr in grants) _bought.Remove(gr);
    }
}
