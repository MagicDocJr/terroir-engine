using System.Text.Json.Nodes;
using TerroirEngine.Game;
using TerroirEngine.Tasting;
using TerroirEngine.Tasting.Practice;
using TerroirEngine.Winery;

namespace TerroirEngine.Learning;

/// <summary>Predict before reveal on the Estate (learning-core design §6, research track A §5): before a new Wine's Tasting
/// sheet opens, the player predicts its acidity, alcohol, leading aroma family and quality, and recalls what up to two of their
/// own choices did in it. Marking reads the Wine's own sheet and its Cause tags; it never changes the Wine. Revealed Wines are
/// game flags ("revealed_&lt;id&gt;"); a game from before this feature counts its existing Wines as revealed.</summary>
public static class Predictions
{
    public const string InitFlag = "predict_v1";

    private sealed record Item(string Key, string Prompt, List<string> Options, bool Ordered, string Answer, string Because, string Skill, IReadOnlyList<string> Causes);
    private sealed record Recall(string Choice, string Cause, string Prompt, List<string> Options, string Answer, string Because, string Skill);

    public static bool IsRevealed(GameSession g, string wineId) => g.Flags.Contains("revealed_" + wineId);

    public static void Init(GameSession g)
    {
        if (g.Flags.Contains(InitFlag)) return;
        foreach (var w in g.Wines) g.Apply(new Command { Type = "flag", A = "revealed_" + w.Id });
        g.Apply(new Command { Type = "flag", A = InitFlag });
    }

    public static void Reveal(GameSession g, string wineId) => g.Apply(new Command { Type = "flag", A = "revealed_" + wineId });

    private static readonly string[] Quality = { "Faulty", "Poor", "Acceptable", "Good", "Very good", "Outstanding" };

    private static (List<Item> Items, List<Recall> Recall) Build(GameSession g, Wine w)
    {
        var sh = w.Sheet!;
        var data = g.Data;
        var rng = new Random(w.Id.Sum(ch => ch) * 31 + (w.Vintage ?? 0));
        string Level(string attr) => sh.Palate.FirstOrDefault(l => l.Attribute == attr)?.Level.Split(',')[0].Trim() ?? "";
        string Because(string attr) => sh.Palate.FirstOrDefault(l => l.Attribute == attr)?.Because ?? "";
        var items = new List<Item>
        {
            new("acidity", "Predict the acidity", TastingMarker.Scale("acidity")!.ToList(), true, Level("Acidity"), Because("Acidity"), "acidity", TastingMarker.CausesFor(sh, "acidity")),
            new("alcohol", "Predict the alcohol", TastingMarker.Scale("alcohol")!.ToList(), true, Level("Alcohol"), Because("Alcohol"), "alcohol", TastingMarker.CausesFor(sh, "alcohol")),
        };
        var lead = sh.Aromas.FirstOrDefault(a => a.Family is not ("fruit" or "red and black fruit")) ?? sh.Aromas.FirstOrDefault();
        if (lead != null)
        {
            var present = sh.Aromas.Select(a => a.Family).ToHashSet();
            var decoys = (w.Blend.Red ? TastingMarker.AromaFamiliesRed : TastingMarker.AromaFamiliesWhite).Where(f => !present.Contains(f)).OrderBy(_ => rng.Next()).Take(3);
            items.Add(new("aroma", "Which aroma family, besides the fruit, will stand out on the nose?", decoys.Append(lead.Family).OrderBy(_ => rng.Next()).ToList(), false,
                lead.Family, $"{lead.Family} ({lead.Terms}): {lead.Because}", "nose",
                sh.CauseLinks.Where(l => l.Line == "aroma:" + lead.Family).Select(l => l.Cause).ToList()));
        }
        items.Add(new("quality", "Predict the quality", Quality.ToList(), true, sh.Quality, sh.QualityBecause, "quality", Array.Empty<string>()));

        // choice recall: the player's own decisions behind Causes on this sheet, cellar first
        var cat = CauseCatalog.All(data);
        var lots = w.Components.Select(c => g.Lots.FirstOrDefault(l => l.Id == c.LotId)).Where(l => l != null).Select(l => l!).ToList();
        var main = lots.FirstOrDefault();
        var found = new List<(string Choice, string Cause)>();
        void Add(string choice, string cause) { if (sh.Causes.Contains(cause) && found.All(f => f.Cause != cause)) found.Add((choice, cause)); }
        if (main != null)
        {
            string Opt(string key) => CellarOptions.Get(key).Options[Math.Clamp(main.Choices.GetValueOrDefault(key), 0, CellarOptions.Get(key).Options.Length - 1)];
            int C(string key) => main.Choices.GetValueOrDefault(key, -1);
            if (C("Vessel") >= 4) Add($"Vessel: {Opt("Vessel")}", "new-oak-vanilla-toast");
            if (C("Vessel") is >= 1 and <= 3) Add($"Vessel: {Opt("Vessel")}", "old-oak-texture");
            if (C("MLF") >= 1) { Add($"MLF: {Opt("MLF")}", "mlf-softens-acid"); Add($"MLF: {Opt("MLF")}", "mlf-diacetyl"); }
            if (C("Lees") == 2) Add($"Lees: {Opt("Lees")}", "lees-bread-texture");
            if (C("Sweetness") >= 1) Add($"Sweetness: {Opt("Sweetness")}", "stopped-ferment-sweetness");
            if (C("Chaptalisation") >= 1) Add($"Chaptalisation: {Opt("Chaptalisation")}", "chaptalisation");
            if (C("Acidification") >= 1) Add($"Acidification: {Opt("Acidification")}", "acidification");
            if (C("Destemming") >= 1) Add($"Destemming: {Opt("Destemming")}", "whole-bunch-stems");
            if (!main.Red && C("Temperature") is 0 or 1) Add($"Fermentation temperature: {Opt("Temperature")}", "cool-ferment-esters");
            if (C("Maceration") == 1) Add($"Maceration: {Opt("Maceration")}", "extraction-colour-tannin");
            if (C("Red temperature") == 2) Add($"Red temperature: {Opt("Red temperature")}", "extraction-colour-tannin");
            if (g.Provenance.TryGetValue(main.Id, out var prov))
            {
                if (prov.LeafSide is "Afternoon" or "Both") { Add($"Leaf removal: {prov.LeafSide.ToLowerInvariant()} side", "sun-exposure-tdn"); Add($"Leaf removal: {prov.LeafSide.ToLowerInvariant()} side", "sunburn-cooked"); }
                if (prov.BudLoad == "Low") Add("Winter pruning: low bud load", "yield-concentration");
            }
        }
        var recall = new List<Recall>();
        foreach (var (choice, causeId) in found.Take(2))
        {
            var c = cat.First(x => x.Id == causeId);
            string kind = c.Line.Contains(':') ? c.Line[..c.Line.IndexOf(':')] : c.Line;
            var decoys = cat.Where(o => o.Id != c.Id && o.Chain[^1] != c.Chain[^1])
                .OrderBy(o => (o.Line.Contains(':') ? o.Line[..o.Line.IndexOf(':')] : o.Line) == kind ? 0 : 1).ThenBy(_ => rng.Next())
                .Select(o => o.Chain[^1]).Distinct().Take(3);
            var link = sh.CauseLinks.First(l => l.Cause == causeId).Line;
            string lineBecause = link.StartsWith("palate:") ? Because(link[7..]) : link.StartsWith("aroma:") ? sh.Aromas.FirstOrDefault(a => "aroma:" + a.Family == link)?.Because ?? "" : "";
            recall.Add(new Recall(choice, causeId, $"Your choice: {choice}. What did it do in this Wine?",
                decoys.Append(c.Chain[^1]).OrderBy(_ => rng.Next()).ToList(), c.Chain[^1],
                (lineBecause != "" ? lineBecause + ". " : "") + string.Join(" → ", c.Chain), SessionComposer.SkillFor(c.Line)));
        }
        return (items, recall);
    }

    private static JsonArray A(IEnumerable<string> xs) => new(xs.Select(x => (JsonNode)JsonValue.Create(x)!).ToArray());

    public static JsonObject? ForOrNull(GameSession g, string wineId) =>
        g.Wines.FirstOrDefault(w => w.Id == wineId) is { Sheet: not null } w ? For(g, w) : null;

    public static JsonObject For(GameSession g, string wineId) => ForOrNull(g, wineId) ?? throw new InvalidOperationException($"no Wine {wineId}");

    private static JsonObject For(GameSession g, Wine w)
    {
        var (items, recall) = Build(g, w);
        return new JsonObject
        {
            ["wineId"] = w.Id, ["name"] = w.Name, ["glassColour"] = PracticeJson.GlassColour(w.Sheet!),
            ["items"] = new JsonArray(items.Select(i => (JsonNode)new JsonObject { ["key"] = i.Key, ["prompt"] = i.Prompt, ["options"] = A(i.Options), ["ordered"] = i.Ordered }).ToArray()),
            ["recall"] = new JsonArray(recall.Select(r => (JsonNode)new JsonObject { ["choice"] = r.Choice, ["prompt"] = r.Prompt, ["options"] = A(r.Options) }).ToArray()),
        };
    }

    private static string Str(JsonNode? n) => n is JsonValue v && v.TryGetValue<string>(out var s) ? s : "";
    private static int Int(JsonNode? n) => n is JsonValue v && v.TryGetValue<int>(out var i) ? Math.Clamp(i, 1, 3) : 0;

    /// <summary>Marks the predictions and the recall. Returns the verdicts (with the four cases and every "because") and the
    /// study-record event items (skill, score, Confidence, Causes) for the bridge to apply.</summary>
    public static (JsonObject Result, List<JsonObject> Events) Mark(GameSession g, string wineId, JsonObject answers)
    {
        var w = g.Wines.First(x => x.Id == wineId);
        var (items, recall) = Build(g, w);
        var given = answers["items"] as JsonObject ?? new JsonObject();
        var conf = answers["confidence"] as JsonObject ?? new JsonObject();
        var rGiven = answers["recall"] as JsonArray ?? new JsonArray();
        var rConf = answers["recallConfidence"] as JsonArray ?? new JsonArray();
        var outItems = new JsonArray(); var outRecall = new JsonArray(); var events = new List<JsonObject>();
        void Emit(JsonArray into, string key, string label, string yours, string actual, double score, int cf, string because, string skill, IEnumerable<string> causes)
        {
            into.Add(new JsonObject
            {
                ["key"] = key, ["label"] = label, ["yours"] = yours, ["actual"] = actual, ["score"] = score, ["confidence"] = cf,
                ["case"] = TastingMarker.CaseFor(score, cf), ["because"] = because,
            });
            // an unanswered prediction is not a miss: it carries no Causes
            events.Add(new JsonObject { ["skill"] = skill, ["score"] = score, ["confidence"] = cf > 0 ? cf : null, ["causes"] = A(yours == "" ? Array.Empty<string>() : causes) });
        }
        foreach (var it in items)
        {
            string yours = Str(given[it.Key]);
            double score = yours == "" ? 0 : it.Ordered
                ? (it.Options.IndexOf(yours) is var a && it.Options.IndexOf(it.Answer) is var b && a >= 0 && b >= 0 ? (a == b ? 1 : Math.Abs(a - b) == 1 ? 0.5 : 0) : 0)
                : (yours == it.Answer ? 1 : 0);
            Emit(outItems, it.Key, it.Prompt, yours, it.Answer, score, Int(conf[it.Key]), it.Because, it.Skill, it.Causes);
        }
        for (int i = 0; i < recall.Count; i++)
        {
            var r = recall[i];
            string yours = i < rGiven.Count ? Str(rGiven[i]) : "";
            Emit(outRecall, "recall." + r.Cause, r.Prompt, yours, r.Answer, yours == r.Answer ? 1 : 0, i < rConf.Count ? Int(rConf[i]) : 0, r.Because, r.Skill, new[] { r.Cause });
        }
        return (new JsonObject { ["wineId"] = wineId, ["items"] = outItems, ["recall"] = outRecall }, events);
    }
}
