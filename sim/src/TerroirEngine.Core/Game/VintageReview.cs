using System.Globalization;
using System.Text.Json.Nodes;
using TerroirEngine.Learning;
using TerroirEngine.Tasting;
using TerroirEngine.Winery;
using TerroirEngine.Vineyard;

namespace TerroirEngine.Game;

/// <summary>Vintage in review (docs/superpowers/specs/2026-10-03-vintage-in-review-design.md): the cause cards and the season
/// strip at the top of the Vintage report. Every card is a Cause tagged on a sheet of the Vintage's Wines, placed at the
/// moment it acted, with its evidence from the simulation and the sheet line it shaped. Descriptive only: what happened and
/// what it did, never a verdict. Reads state up to the bottling (ADR 0002).</summary>
public static class VintageReview
{
    public const int MaxCards = 8;
    private static readonly CultureInfo Ci = CultureInfo.InvariantCulture;
    private static readonly string[] QualityOrder = { "Faulty", "Poor", "Acceptable", "Good", "Very good", "Outstanding" };
    private static readonly HashSet<string> SeasonCauses = new() { "spring-frost-yield", "cool-season-acid", "warm-season-malic-loss", "sunburn-cooked", "sun-exposure-tdn", "pyrazines-shade-cool", "noble-rot", "grey-rot-taint" };
    private static readonly HashSet<string> HarvestCauses = new() { "ripeness-fruit-character", "sugar-to-alcohol", "seed-ripeness-tannin", "yield-concentration", "riesling-terpenes" };
    private static readonly HashSet<string> FaultCauses = new() { "volatile-acidity", "brett", "oxidation", "molecular-so2-ph", "low-yan-h2s" };
    private static readonly Dictionary<string, string[]> CellarChoice = new()
    {
        ["mlf-softens-acid"] = new[] { "MLF" }, ["mlf-diacetyl"] = new[] { "MLF" }, ["new-oak-vanilla-toast"] = new[] { "Vessel", "Toast", "Ageing" },
        ["old-oak-texture"] = new[] { "Vessel", "Ageing" }, ["lees-bread-texture"] = new[] { "Lees" }, ["whole-bunch-stems"] = new[] { "Destemming" },
        ["stopped-ferment-sweetness"] = new[] { "Sweetness" }, ["chaptalisation"] = new[] { "Chaptalisation" }, ["acidification"] = new[] { "Acidification" },
        ["cool-ferment-esters"] = new[] { "Temperature" }, ["extraction-colour-tannin"] = new[] { "Maceration", "Cap management", "Red temperature" },
        ["thiols-skin-contact"] = new[] { "Pressing" },
    };

    private static string D(DateOnly d) => d.ToString("d MMMM", Ci);

    private sealed record Ctx(Wine Wine, Lot? Lot, Provenance? Prov, SeasonRecord? Season, TerroirEngine.Vineyard.BlockState? Block);

    /// <summary>The Wine's main Lot of this Vintage (the largest component), its provenance, Block and season.</summary>
    private static Ctx Context(GameSession g, Wine w, int vintage)
    {
        var comp = w.Components.Where(c => g.Lots.FirstOrDefault(l => l.Id == c.LotId)?.Vintage == vintage).OrderByDescending(c => c.Litres).FirstOrDefault();
        var lot = comp == null ? null : g.Lots.FirstOrDefault(l => l.Id == comp.LotId);
        var prov = lot != null && g.Provenance.TryGetValue(lot.Id, out var p) ? p : null;
        var block = prov == null ? null : g.Blocks.FirstOrDefault(b => b.Data.Id == prov.BlockId);
        return new Ctx(w, lot, prov, block == null ? null : g.Season(block, vintage), block);
    }

    private static JsonObject? Line(TastingSheet sh, string line)
    {
        if (line.StartsWith("palate:"))
            return sh.Palate.FirstOrDefault(l => "palate:" + l.Attribute == line) is { } p ? new JsonObject { ["attribute"] = p.Attribute, ["level"] = p.Level, ["because"] = p.Because } : null;
        if (line.StartsWith("aroma:"))
            return sh.Aromas.FirstOrDefault(a => "aroma:" + a.Family == line) is { } a ? new JsonObject { ["attribute"] = "Aroma: " + a.Family, ["level"] = a.Terms, ["because"] = a.Because } : null;
        if (line == "appearance") return new JsonObject { ["attribute"] = "Colour", ["level"] = $"{sh.ColourIntensity} {sh.Colour}", ["because"] = sh.AppearanceBecause };
        if (line == "fault") return sh.Faults.Count > 0 ? new JsonObject { ["attribute"] = "Fault", ["level"] = "faulty", ["because"] = sh.Faults[0] } : null;
        return null;
    }

    private static (DateOnly Date, double Tmin) ColdestNight(GameSession g, Ctx c, int vintage)
    {
        var from = c.Season?.Budburst ?? new DateOnly(vintage, 4, 1);
        (DateOnly, double) best = (from, double.MaxValue);
        for (var d = from; d <= new DateOnly(vintage, 5, 20); d = d.AddDays(1))
        {
            var w = c.Block!.Climate.Adjust(g.Weather.Get(d));
            if (w.Tmin < best.Item2) best = (d, w.Tmin);
        }
        return best;
    }

    private static (DateOnly Date, double Tmax) HottestDay(GameSession g, Ctx c, int vintage)
    {
        var from = c.Season?.Veraison ?? new DateOnly(vintage, 7, 15);
        var to = c.Prov?.HarvestDate ?? new DateOnly(vintage, 10, 15);
        (DateOnly, double) best = (from, double.MinValue);
        for (var d = from; d <= to; d = d.AddDays(1))
        {
            var w = c.Block!.Climate.Adjust(g.Weather.Get(d));
            if (w.Tmax > best.Item2) best = (d, w.Tmax);
        }
        return best;
    }

    private static string Opt(Lot lot, string key) => CellarOptions.Get(key).Options[Math.Clamp(lot.Choices.GetValueOrDefault(key), 0, CellarOptions.Get(key).Options.Length - 1)];

    /// <summary>When the Cause acted, its priority (0 faults, 1 season, 2 harvest, 3 cellar, 4 other) and the evidence lines.</summary>
    private static (DateOnly When, int Priority, List<string> Happened) Evidence(GameSession g, Ctx c, string cause, int vintage)
    {
        var lines = new List<string>();
        var b = c.Wine.Blend; var p = c.Prov; var s = c.Season;
        var harvest = p?.HarvestDate ?? new DateOnly(vintage, 9, 30);
        var bottled = c.Wine.Bottled ?? harvest.AddMonths(6);
        string blockName = p?.BlockId ?? "?";
        switch (cause)
        {
            case "spring-frost-yield" when c.Block != null:
                var (night, tmin) = ColdestNight(g, c, vintage);
                var hit = g.Blocks.Select(bl => (bl.Data.Id, Loss: g.Season(bl, vintage)?.FrostShootLoss ?? 0)).Where(x => x.Loss > 0.05).ToList();
                lines.Add($"{D(night)}: {tmin:0.0} °C at Block {blockName} after budburst");
                if (hit.Count > 0) lines.Add("Young shoots killed: " + string.Join(", ", hit.Select(x => $"Block {x.Id} {x.Loss * 100:0} %")));
                if (p != null) lines.Add($"Block {blockName} yielded {p.YieldHlHa:0} hL/ha");
                return (night, 1, lines);
            case "cool-season-acid" or "warm-season-malic-loss":
                var (gst, normal) = VintageReport.SeasonTemps(g, vintage);
                lines.Add($"The growing season averaged {gst:0.0} °C (April–October), against a normal of {normal:0.0} °C");
                if (p != null) lines.Add($"Block {blockName} was picked with TA {p.HarvestTa:0.0} g/L and pH {p.HarvestPh:0.00}");
                return (s?.Veraison ?? new DateOnly(vintage, 8, 1), 1, lines);
            case "sunburn-cooked" when c.Block != null:
                var (hot, tmax) = HottestDay(g, c, vintage);
                lines.Add($"{D(hot)}: {tmax:0.0} °C at Block {blockName}");
                if (p != null) lines.Add($"{p.SunburnPct:0.#} % of the berries were sunburned; leaves pulled: {(p.LeafSide == "" ? "none" : p.LeafSide.ToLowerInvariant() + " side")}");
                return (hot, 1, lines);
            case "sun-exposure-tdn" or "pyrazines-shade-cool":
                if (p != null)
                {
                    lines.Add($"Leaves pulled: {(p.LeafSide is "" or "None" ? "none" : $"{p.LeafSide.ToLowerInvariant()} side, {p.LeafTiming.ToLowerInvariant()}")}; canopy programme {p.CanopyTier.ToLowerInvariant()}");
                    if (cause == "pyrazines-shade-cool") lines.Add($"Green-pepper pyrazine (IBMP) at harvest: {p.IbmpNgL:0} ng/L");
                }
                return (s?.Flowering ?? new DateOnly(vintage, 6, 15), 1, lines);
            case "noble-rot" or "grey-rot-taint":
                double rain = 0;
                for (var d = harvest.AddDays(-21); d < harvest; d = d.AddDays(1)) rain += g.Weather.Get(d).Precip;
                lines.Add($"{rain:0} mm of rain fell in the three weeks before picking");
                if (p != null) lines.Add(cause == "noble-rot" ? $"{p.NobleRotPct:0.#} % noble rot on Block {blockName}" : $"{p.GreyRotPct:0.#} % grey rot reached the press from Block {blockName}");
                return (harvest, 1, lines);
        }
        if (HarvestCauses.Contains(cause) && p != null)
        {
            lines.Add($"You picked Block {blockName} on {D(harvest)} at {p.HarvestOe:0} °Oe, TA {p.HarvestTa:0.0} g/L, pH {p.HarvestPh:0.00}");
            if (cause == "seed-ripeness-tannin") lines.Add($"Seeds were {p.SeedMaturity * 100:0} % ripe");
            if (cause == "yield-concentration") lines.Add($"Yield {p.YieldHlHa:0} hL/ha");
            if (cause == "sugar-to-alcohol") lines.Add($"The Wine reached {b.AlcoholPct:0.0} % vol");
            return (harvest, 2, lines);
        }
        if (FaultCauses.Contains(cause))
        {
            if (c.Wine.Sheet!.Faults.Count > 0) lines.Add(c.Wine.Sheet.Faults[0]);
            if (cause == "low-yan-h2s" && c.Lot != null) lines.Add($"Yeast-assimilable nitrogen in the must: {c.Lot.YanMgL:0} mg/L; nutrients: {Opt(c.Lot, "Nutrients").ToLowerInvariant()}");
            if (cause == "molecular-so2-ph") lines.Add($"Molecular SO₂ {b.MolecularSo2:0.00} mg/L at pH {b.Ph:0.00}");
            return (bottled, 0, lines);
        }
        if (CellarChoice.TryGetValue(cause, out var keys) && c.Lot != null)
        {
            foreach (var k in keys) lines.Add($"{k}: {Opt(c.Lot, k)}");
            if (cause == "mlf-softens-acid") lines.Add($"Malic acid at bottling {b.Malic:0.0} g/L, lactic {b.Lactic:0.0} g/L");
            if (cause == "stopped-ferment-sweetness") lines.Add($"{b.Rs:0} g/L of sugar left");
            if (cause == "chaptalisation") lines.Add($"+{b.ChaptalSugarAdded / 16.83:0.0} % vol from added sugar");
            bool aging = cause is "new-oak-vanilla-toast" or "old-oak-texture" or "lees-bread-texture";
            return (aging ? bottled : harvest.AddDays(1), 3, lines);
        }
        return (bottled, 4, lines);
    }

    /// <summary>The moment a Cause belongs to: Causes acting at the same moment share one card (one harvest card, one
    /// malolactic card), so the same evidence is never repeated.</summary>
    private static (string Key, string? Title) Moment(string cause)
    {
        if (cause == "spring-frost-yield") return ("frost", null);
        if (cause is "cool-season-acid" or "warm-season-malic-loss") return ("season", "The season's warmth");
        if (cause == "sunburn-cooked") return ("heat", null);
        if (cause is "sun-exposure-tdn" or "pyrazines-shade-cool") return ("canopy", "Sun and shade on the bunches");
        if (cause is "noble-rot" or "grey-rot-taint") return ("rain", "Rain before the harvest");
        if (HarvestCauses.Contains(cause)) return ("harvest", "The harvest");
        if (CellarChoice.TryGetValue(cause, out var keys)) return ("cellar:" + keys[0], keys[0] switch
        {
            "MLF" => "Malolactic conversion", "Vessel" => "The barrels", "Lees" => "Time on the lees", "Destemming" => "Whole bunches",
            "Sweetness" => "Stopping the fermentation", "Maceration" => "Extraction", "Temperature" => "Fermentation temperature", _ => null,
        });
        return ("cause:" + cause, null);
    }

    /// <summary>The cause cards: from the Vintage's best Wine, plus season events and faults tagged on its other Wines; one card
    /// per moment; faults first, then season, harvest, cellar, the rest; chronological within each; at most eight.</summary>
    public static JsonArray Cards(GameSession g, int vintage)
    {
        var wines = g.Wines.Where(w => w.Vintage == vintage && w.Sheet != null && w.Bottled != null).ToList();
        if (wines.Count == 0) return new JsonArray();
        var best = wines.OrderByDescending(w => Array.IndexOf(QualityOrder, w.Sheet!.Quality)).ThenBy(w => w.Id, StringComparer.Ordinal).First();
        var picks = new List<(Wine W, string Cause, string Line)>();
        foreach (var l in best.Sheet!.CauseLinks) if (picks.All(x => x.Cause != l.Cause)) picks.Add((best, l.Cause, l.Line));
        foreach (var w in wines.Where(w => w != best))
            foreach (var l in w.Sheet!.CauseLinks.Where(l => SeasonCauses.Contains(l.Cause) || FaultCauses.Contains(l.Cause)))
                if (picks.All(x => x.Cause != l.Cause)) picks.Add((w, l.Cause, l.Line));
        var groups = new Dictionary<string, (int Priority, DateOnly When, string? Title, Wine W, List<string> Causes, List<string> Happened, List<JsonObject> Lines)>();
        foreach (var (w, cause, lineKey) in picks)
        {
            var c = Context(g, w, vintage);
            var line = Line(w.Sheet!, lineKey) ?? (lineKey == "vintage" && c.Prov != null
                ? new JsonObject { ["attribute"] = "Vintage", ["level"] = vintage.ToString(Ci), ["because"] = $"{c.Prov.YieldHlHa:0} hL/ha from Block {c.Prov.BlockId}" }
                : null);
            if (line == null) continue;
            var (when, pr, happened) = Evidence(g, c, cause, vintage);
            var (key, title) = Moment(cause);
            key += "|" + w.Id;
            if (!groups.TryGetValue(key, out var gr)) groups[key] = gr = (pr, when, title, w, new(), new(), new());
            gr.Causes.Add(cause);
            foreach (var h in happened.Where(h => !gr.Happened.Contains(h))) gr.Happened.Add(h);
            if (gr.Lines.All(x => (string?)x["attribute"] != (string?)line["attribute"])) gr.Lines.Add(line);
        }
        string Label(DateOnly d) => d.Year == vintage ? D(d) : d.ToString("d MMMM yyyy", Ci);
        var cards = groups.Values.Select(gr =>
        {
            var metas = gr.Causes.Select(id => CauseCatalog.Find(g.Data, id)).ToList();
            string title = gr.Causes.Count == 1 || gr.Title == null ? metas[0]?.Title ?? gr.Causes[0] : gr.Title;
            return (gr.Priority, gr.When, Card: new JsonObject
            {
                ["causes"] = new JsonArray(gr.Causes.Select((id, k) => (JsonNode)new JsonObject { ["id"] = id, ["title"] = metas[k]?.Title ?? id }).ToArray()),
                ["title"] = title, ["date"] = Label(gr.When), ["when"] = gr.When.ToString("yyyy-MM-dd", Ci), ["priority"] = gr.Priority, ["wine"] = gr.W.Name,
                ["happened"] = new JsonArray(gr.Happened.Select(h => (JsonNode)JsonValue.Create(h)!).ToArray()),
                ["lines"] = new JsonArray(gr.Lines.Select(x => (JsonNode)x).ToArray()),
            });
        });
        return new JsonArray(cards.OrderBy(x => x.Priority).ThenBy(x => x.When).Take(MaxCards).Select(x => (JsonNode)x.Card).ToArray());
    }

    /// <summary>The season strip: phenology of the best Wine's main Block and a pin per card, for the animated replay.</summary>
    public static JsonObject? Strip(GameSession g, int vintage, JsonArray cards)
    {
        var wines = g.Wines.Where(w => w.Vintage == vintage && w.Sheet != null && w.Bottled != null).ToList();
        if (wines.Count == 0) return null;
        var best = wines.OrderByDescending(w => Array.IndexOf(QualityOrder, w.Sheet!.Quality)).ThenBy(w => w.Id, StringComparer.Ordinal).First();
        var c = Context(g, best, vintage);
        string? Iso(DateOnly? d) => d?.ToString("yyyy-MM-dd", Ci);
        return new JsonObject
        {
            ["block"] = c.Prov?.BlockId,
            ["budburst"] = Iso(c.Season?.Budburst), ["flowering"] = Iso(c.Season?.Flowering), ["veraison"] = Iso(c.Season?.Veraison), ["harvest"] = Iso(c.Prov?.HarvestDate),
            ["pins"] = new JsonArray(cards.Select(x => (JsonNode)new JsonObject { ["when"] = x!["when"]!.DeepClone(), ["title"] = x["title"]!.DeepClone(), ["priority"] = x["priority"]!.DeepClone() }).ToArray()),
        };
    }

    /// <summary>The review object for the report, or null when the Vintage has no bottled Wine with a sheet.</summary>
    public static JsonObject? Review(GameSession g, int vintage)
    {
        var cards = Cards(g, vintage);
        if (cards.Count == 0) return null;
        return new JsonObject { ["cards"] = cards, ["strip"] = Strip(g, vintage, cards), ["seen"] = g.Flags.Contains($"review-seen-{vintage}") };
    }
}
