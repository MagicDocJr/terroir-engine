using System.Collections.Concurrent;
using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using TerroirEngine.Data;
using TerroirEngine.Learning;
using TerroirEngine.Tasting;
using TerroirEngine.Tasting.Practice;
using TerroirEngine.Util;
using TerroirEngine.Winery;

namespace TerroirEngine.Game;

/// <summary>A medal criterion: its type, its value, and an optional short wording for the screens.</summary>
public sealed record Criterion(string Type, JsonNode? Value, string? Text = null);
public sealed record Medal(string Name, IReadOnlyList<Criterion> Criteria);
/// <summary>A debrief line with its source key (data/vintage_notes.json "sources", docs/science/vintage-notes.md).</summary>
public sealed record SourcedLine(string Text, string Source);
/// <summary>A number from the real year to set beside the player's Wine: what (harvestDate, naturalOe, yieldHlHa), the
/// reported value as text, and its source.</summary>
public sealed record CompareLine(string What, string Label, string Real, string Source);
public sealed record Scenario(string Id, string Region, string Plot, string Variety, int Vintage, string Title, string Teaser, string Briefing,
    IReadOnlyList<Medal> Medals, IReadOnlyList<SourcedLine> Growers, IReadOnlyList<CompareLine> Compare, IReadOnlyList<string> Causes);

/// <summary>Famous vintages (docs/superpowers/specs/2026-10-03-famous-vintages-design.md): one real year on an established
/// Estate, three medals judged on the best Wine of that vintage, and a cited debrief once it is in bottle. A scenario is a
/// normal game whose setup carries the scenario id, so saves replay it. The briefing holds only what a grower knew in
/// January (ADR 0002); the debrief reveals the year.</summary>
public static class Scenarios
{
    public static readonly string[] MedalOrder = { "bronze", "silver", "gold" };
    private static readonly string[] QualityOrder = { "Faulty", "Poor", "Acceptable", "Good", "Very good", "Outstanding" };
    private static readonly string[] AcidityOrder = { "low", "medium(−)", "medium", "medium(+)", "high" };
    private static readonly ConcurrentDictionary<string, IReadOnlyList<Scenario>> Cache = new();
    private static readonly HashSet<string> CriterionTypes = new() { "category", "qualityAtLeast", "noFault", "noChaptalisation", "naturalSugarAtLeast", "acidityAtLeast", "balanceMet", "seedsRipe", "noRotTaint", "alcoholAtMost" };

    public static IReadOnlyList<Scenario> Catalog(GameData data) => Cache.GetOrAdd(data.DataRoot, root =>
    {
        var path = Path.Combine(root, "scenarios.json");
        if (!File.Exists(path)) return Array.Empty<Scenario>();
        var doc = JsonNode.Parse(File.ReadAllText(path))!;
        return doc["scenarios"]!.AsArray().Select(n => new Scenario(
            (string)n!["id"]!, (string)n["region"]!, (string)n["plot"]!, (string)n["variety"]!, (int)n["vintage"]!,
            (string)n["title"]!, (string)n["teaser"]!, (string)n["briefing"]!,
            n["medals"]!.AsArray().Select(m => new Medal((string)m!["name"]!, m["criteria"]!.AsArray().Select(c => new Criterion((string)c!["type"]!, c["value"]?.DeepClone(), (string?)c["text"])).ToList())).ToList(),
            (n["growers"] as JsonArray ?? new()).Select(g => new SourcedLine((string)g!["text"]!, (string)g["source"]!)).ToList(),
            (n["compare"] as JsonArray ?? new()).Select(c => new CompareLine((string)c!["what"]!, (string)c["label"]!, (string)c["real"]!, (string)c["source"]!)).ToList(),
            (n["causes"] as JsonArray ?? new()).Select(c => (string)c!).ToList())).ToList();
    });

    public static Scenario? Find(GameData data, string? id) => id == null ? null : Catalog(data).FirstOrDefault(s => s.Id == id);

    private static readonly Regex Leak = new(
        @"\b(frost|frosts|freez\w*|heat|heatwave|hot|scorch\w*|fire|fires|wildfire\w*|smoke|earthquake|rain|rains|storm\w*|hail|drought|flood\w*|mildew|rot|shatter\w*|"
        + @"january|february|march|april|may|june|july|august|september|october|november|december)\b", RegexOptions.IgnoreCase);

    private static IReadOnlySet<string> SourceKeys(GameData data)
    {
        var path = Path.Combine(data.DataRoot, "vintage_notes.json");
        if (!File.Exists(path)) return new HashSet<string>();
        return (JsonNode.Parse(File.ReadAllText(path))!["sources"] as JsonObject ?? new()).Select(kv => kv.Key).ToHashSet();
    }

    /// <summary>Everything wrong with a scenario: unknown plot, variety, criterion or Cause; an unresolved source; a briefing or
    /// teaser that names what the year will bring (ADR 0002; "January" is allowed only as the opening date).</summary>
    public static List<string> Problems(GameData data, Scenario s)
    {
        var p = new List<string>();
        if (data.Plots.Regions.SelectMany(r => r.Plots).All(pl => pl.Id != s.Plot)) p.Add($"unknown plot {s.Plot}");
        if (Variety.All.All(v => v.Name != s.Variety)) p.Add($"unknown variety {s.Variety}");
        if (s.Medals.Select(m => m.Name).SequenceEqual(MedalOrder) == false) p.Add("medals must be bronze, silver, gold");
        foreach (var c in s.Medals.SelectMany(m => m.Criteria).Where(c => !CriterionTypes.Contains(c.Type))) p.Add($"unknown criterion {c.Type}");
        foreach (var c in s.Causes.Where(c => CauseCatalog.Find(data, c) == null)) p.Add($"unknown Cause {c}");
        var keys = SourceKeys(data);
        foreach (var src in s.Growers.Select(g => g.Source).Concat(s.Compare.Select(c => c.Source)).Where(k => !keys.Contains(k))) p.Add($"unresolved source {src}");
        string brief = Regex.Replace(s.Briefing, $@"^January {s.Vintage}\.\s*", "");
        foreach (var (field, text) in new[] { ("briefing", brief), ("teaser", s.Teaser), ("title", s.Title) })
        {
            if (Leak.Match(text) is { Success: true } m) p.Add($"{field} gives the year away: '{m.Value}'");
            if (Regex.IsMatch(text, @"\b\d{1,2}(st|nd|rd|th)?\s+(of\s+)?[A-Z][a-z]+")) p.Add($"{field} names a date");
        }
        return p;
    }

    /// <summary>The scenario's game: the plot planted three years before the vintage with its default planting, so the game
    /// opens on 15 January of the vintage with established vines.</summary>
    public static GameSetup Setup(GameData data, string id)
    {
        var s = Find(data, id) ?? throw new ArgumentException($"no scenario {id}");
        return new GameSetup { PlotId = s.Plot, PlantingYear = s.Vintage - 3, EstateName = s.Title, ScenarioId = s.Id, Seed = (ulong)s.Vintage };
    }

    // ------------------------------------------------------------------------------------------------ judging

    private static string CriterionText(Criterion c) => c.Text ?? c.Type switch
    {
        "category" => $"labelled {string.Join(" or ", c.Value!.AsArray().Select(x => (string)x!))}",
        "qualityAtLeast" => $"quality {(string)c.Value!} or better",
        "noFault" => "no fault",
        "noChaptalisation" => "no sugar added (no chaptalisation)",
        "naturalSugarAtLeast" => $"picked ripe: at least {(double)c.Value!:0} g/L natural sugar",
        "acidityAtLeast" => $"acidity {(string)c.Value!} or higher",
        "balanceMet" => "balanced",
        "seedsRipe" => "ripe tannin: seeds ripe at harvest",
        "noRotTaint" => "no rot taint",
        "alcoholAtMost" => $"picked before the alcohol runs hot: at most {(double)c.Value!:0.0} % vol",
        _ => c.Type,
    };

    private static (bool Met, string Evidence) Judge(Criterion c, Wine w)
    {
        var sh = w.Sheet!; var b = w.Blend;
        switch (c.Type)
        {
            case "category":
                var cat = w.Legal?.Category ?? "";
                return (c.Value!.AsArray().Any(x => (string)x! == cat), $"labelled {cat}");
            case "qualityAtLeast":
                return (Array.IndexOf(QualityOrder, sh.Quality) >= Array.IndexOf(QualityOrder, (string)c.Value!), $"quality {sh.Quality}");
            case "noFault":
                var faults = sh.Faults.Where(f => !f.StartsWith("Refermentation")).ToList();
                return (faults.Count == 0, faults.Count == 0 ? "no fault" : faults[0]);
            case "noChaptalisation":
                return (b.ChaptalSugarAdded <= 0.5, b.ChaptalSugarAdded <= 0.5 ? "no sugar added" : $"chaptalised (+{b.ChaptalSugarAdded / 16.83:0.0} % vol)");
            case "naturalSugarAtLeast":
                double need = (double)c.Value!;
                return (b.NaturalSugar >= need, $"natural sugar {b.NaturalSugar:0} g/L{(b.NaturalSugar >= need ? "" : $" (needs {need:0})")}");
            case "acidityAtLeast":
                var acid = sh.Palate.FirstOrDefault(l => l.Attribute == "Acidity")?.Level ?? "";
                return (Array.IndexOf(AcidityOrder, acid) >= Array.IndexOf(AcidityOrder, (string)c.Value!), $"acidity {acid}");
            case "balanceMet":
                var bal = sh.Blic.FirstOrDefault(x => x.Criterion == "Balance");
                return (bal.Met, bal.Met ? "balanced" : $"not balanced: {bal.Why}");
            case "seedsRipe":
                return (b.SeedMaturity >= 0.62, $"seed ripeness {b.SeedMaturity * 100:0} % at harvest{(b.SeedMaturity >= 0.62 ? "" : " (still green)")}");
            case "alcoholAtMost":
                double max = (double)c.Value!;
                return (b.AlcoholPct <= max + 1e-9, $"{b.AlcoholPct:0.0} % vol{(b.AlcoholPct <= max + 1e-9 ? "" : $" (more than {max:0.0})")}");
            case "noRotTaint":
                return (b.GreyRotShare <= 0.06, $"{b.GreyRotShare * 100:0.#} % grey-rotten fruit{(b.GreyRotShare <= 0.06 ? "" : " (taints the wine)")}");
        }
        return (false, "");
    }

    /// <summary>The medals of one Wine: each medal needs its own criteria and every medal below it.</summary>
    private static (int Earned, JsonArray Medals) JudgeWine(Scenario s, Wine w)
    {
        var arr = new JsonArray(); int earned = -1; bool chain = true;
        for (int i = 0; i < s.Medals.Count; i++)
        {
            var crit = new JsonArray(); bool all = true;
            foreach (var c in s.Medals[i].Criteria)
            {
                var (met, ev) = Judge(c, w); all &= met;
                // the evidence only where it says more than the criterion itself ("balanced — balanced" says nothing)
                string text = CriterionText(c);
                crit.Add(new JsonObject { ["text"] = text, ["met"] = met, ["evidence"] = text.Contains(ev, StringComparison.OrdinalIgnoreCase) ? "" : ev });
            }
            chain &= all;
            if (chain) earned = i;
            arr.Add(new JsonObject { ["name"] = s.Medals[i].Name, ["met"] = chain, ["criteria"] = crit });
        }
        return (earned, arr);
    }

    /// <summary>The scenario verdict on the best bottled Wine labelled with the scenario vintage (later Vintages never count).</summary>
    public static JsonObject Evaluate(GameSession g)
    {
        var s = Find(g.Data, g.Setup.ScenarioId);
        if (s == null) return new JsonObject { ["judged"] = false };
        // the scenario's grape only: a Plot's other Blocks may grow another grape, but the medal is about the year's challenge for this one
        var wines = g.Wines.Where(w => w.Vintage == s.Vintage && w.Sheet != null && w.Bottled != null && w.Blend.VarietyName == s.Variety).ToList();
        if (wines.Count == 0) return new JsonObject { ["judged"] = false };
        var best = wines.Select(w => (w, j: JudgeWine(s, w)))
            .OrderByDescending(x => x.j.Earned).ThenByDescending(x => Array.IndexOf(QualityOrder, x.w.Sheet!.Quality)).ThenBy(x => x.w.Id, StringComparer.Ordinal).First();
        return new JsonObject
        {
            ["judged"] = true,
            ["medal"] = best.j.Earned >= 0 ? MedalOrder[best.j.Earned] : null,
            ["wine"] = new JsonObject { ["id"] = best.w.Id, ["name"] = best.w.Name, ["vintage"] = best.w.Vintage, ["quality"] = best.w.Sheet!.Quality, ["category"] = best.w.Legal?.Category },
            ["medals"] = best.j.Medals,
        };
    }

    private static JsonObject Brief(Scenario s) => new()
    {
        ["id"] = s.Id, ["title"] = s.Title, ["teaser"] = s.Teaser, ["briefing"] = s.Briefing, ["vintage"] = s.Vintage, ["region"] = s.Region,
        ["plot"] = s.Plot, ["variety"] = s.Variety,
    };

    private static JsonArray Goals(Scenario s) => new(s.Medals.Select(m => (JsonNode)new JsonObject
    {
        ["name"] = m.Name, ["criteria"] = new JsonArray(m.Criteria.Select(c => (JsonNode)JsonValue.Create(CriterionText(c))!).ToArray()),
    }).ToArray());

    /// <summary>For the screens: the scenario (or null in a normal game), its goals, and once a Wine of the vintage is in
    /// bottle the verdict and the debrief.</summary>
    public static JsonObject Status(GameSession g)
    {
        var s = Find(g.Data, g.Setup.ScenarioId);
        if (s == null) return new JsonObject { ["scenario"] = null, ["judged"] = false };
        var ev = Evaluate(g);
        bool judged = (bool)ev["judged"]!;
        return new JsonObject
        {
            ["scenario"] = Brief(s), ["goals"] = Goals(s), ["judged"] = judged,
            ["evaluation"] = judged ? ev : null, ["debrief"] = judged ? Debrief(g, s, ev) : null,
            ["seen"] = g.Flags.Contains("scenario-debrief-seen"),
        };
    }

    private static JsonObject Debrief(GameSession g, Scenario s, JsonObject ev)
    {
        var path = Path.Combine(g.Data.DataRoot, "vintage_notes.json");
        var sources = File.Exists(path) ? JsonNode.Parse(File.ReadAllText(path))!["sources"] as JsonObject : null;
        JsonObject Src(string key) => new() { ["key"] = key, ["title"] = sources?[key]?["title"]?.DeepClone(), ["url"] = sources?[key]?["url"]?.DeepClone() };
        var wine = g.Wines.First(w => w.Id == (string)ev["wine"]!["id"]!);
        var lot = g.Lots.FirstOrDefault(l => l.Id == wine.Components[0].LotId);
        var prov = lot != null && g.Provenance.TryGetValue(lot.Id, out var pv) ? pv : null;
        string Yours(string what) => what switch
        {
            "harvestDate" => prov == null ? "" : prov.HarvestDate.ToString("d MMMM", CultureInfo.InvariantCulture),
            "naturalOe" => $"{wine.Blend.NaturalOe:0} °Oe",
            "naturalSugar" => $"{wine.Blend.NaturalSugar:0} g/L",
            "yieldHlHa" => prov == null ? "" : $"{prov.YieldHlHa:0} hL/ha",
            "brix" => $"{Units.BrixFromOe(wine.Blend.NaturalOe):0.0} °Brix",
            "potentialAlcohol" => $"{wine.Blend.NaturalSugar / 16.83:0.0} %",
            "frostLoss" => prov == null ? "" : $"{prov.FrostLoss * 100:0} %",
            _ => "",
        };
        return new JsonObject
        {
            ["note"] = PracticeSession.NoteJson(g.Data, s.Region, s.Vintage),
            ["growers"] = new JsonArray(s.Growers.Select(x => (JsonNode)new JsonObject { ["text"] = x.Text, ["source"] = Src(x.Source) }).ToArray()),
            ["compare"] = new JsonArray(s.Compare.Select(c => (JsonNode)new JsonObject { ["label"] = c.Label, ["yours"] = Yours(c.What), ["real"] = c.Real, ["source"] = Src(c.Source) }).ToArray()),
            ["causes"] = new JsonArray(s.Causes.Select(id => CauseCatalog.Find(g.Data, id)).Where(c => c != null)
                .Select(c => (JsonNode)new JsonObject { ["id"] = c!.Id, ["title"] = c.Title }).ToArray()),
        };
    }

    /// <summary>Keeps the best medal per scenario in the study record ("scenarios": {id: medal}).</summary>
    public static JsonObject RecordMedal(JsonObject record, string id, string? medal)
    {
        var rec = StudyRecord.Migrate(record);
        if (medal == null || Array.IndexOf(MedalOrder, medal) < 0) return rec;
        var o = rec["scenarios"] as JsonObject ?? new JsonObject();
        string? old = o[id] is JsonValue v && v.TryGetValue<string>(out var sv) ? sv : null;
        if (old == null || Array.IndexOf(MedalOrder, medal) > Array.IndexOf(MedalOrder, old)) o[id] = medal;
        rec["scenarios"] = o.DeepClone();
        return rec;
    }

    /// <summary>Harness and tests only: a scripted player. Harvests every Block at a target must weight, sets the cellar
    /// choices on each new Lot (daily steps near harvest, as choices lock once fermentation starts), bottles each Lot on its
    /// own, restarts stuck ferments, until the given vintage is in bottle.</summary>
    public static void Autoplay(GameSession g, double targetOe, IReadOnlyDictionary<string, int>? choices = null, int? untilVintage = null)
    {
        int last = untilVintage ?? g.FirstVintage, guard = 0;
        var styled = new HashSet<string>();
        while (!g.IsVintageBottled(last) && guard++ < 800)
        {
            bool near = g.Blocks.Any(b => b.Veraison != null && !b.Harvested) || g.Lots.Any(l => l.Phase is LotPhase.Received or LotPhase.ColdSoak);
            g.Advance(near ? 1 : 20, stopAtAlerts: false);
            if (g.Vintage <= last)
                foreach (var b in g.Blocks.Where(b => !b.Harvested && !b.Picking && b.Veraison != null))
                    if (Chemistry.MustFromBlock(b).Oe >= targetOe || b.LeafFall != null) g.Apply(new Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Table" });
            foreach (var lot in g.Lots.Where(l => l.Phase is LotPhase.Received or LotPhase.ColdSoak && styled.Add(l.Id)).ToList())
                foreach (var kv in choices ?? new Dictionary<string, int>())
                    if (!((kv.Key is "Sweetness" or "Temperature") && lot.Red || kv.Key == "Red temperature" && !lot.Red))
                        g.Apply(new Command { Type = "lot", A = lot.Id, B = kv.Key, C = kv.Value.ToString(CultureInfo.InvariantCulture) });
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Ready).ToList()) g.Apply(new Command { Type = "wine", A = lot.Id, E = lot.Id });
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Stuck).ToList()) g.Apply(new Command { Type = "restart", A = lot.Id });
        }
    }

    /// <summary>The scenario list for the title screen, with the best medal earned so far.</summary>
    public static JsonArray List(GameData data, JsonObject record) => new(Catalog(data).Select(s => (JsonNode)new JsonObject
    {
        ["scenario"] = Brief(s), ["goals"] = Goals(s),
        ["best"] = record["scenarios"]?[s.Id] is JsonValue v && v.TryGetValue<string>(out var m) ? m : null,
    }).ToArray());
}
