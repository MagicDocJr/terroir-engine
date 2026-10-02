using System.Text.Json.Nodes;
using TerroirEngine.Data;

namespace TerroirEngine.Tasting.Practice;

/// <summary>One marked item: the player's answer beside the Tasting sheet's, with its "because".</summary>
public sealed record MarkItem(string Key, string Label, string Skill, string Yours, string Actual, double Score, string Because,
    int Confidence = 0, string Case = "no-confidence", IReadOnlyList<string>? Causes = null);

public sealed record MarkResult(string Exercise, IReadOnlyList<MarkItem> Items, double Total, double Max, int Hints)
{
    public double Percent => Max <= 0 ? 0 : Math.Round(100 * Total / Max, 1);
}

/// <summary>Marks the player's Tasting sheet, or one exercise, against the Wine's own Tasting sheet (tasting-practice design §6).
/// Ordered scales score 1 for an exact match, ½ for one step off, else 0; categorical items 1 or 0; aroma families by overlap
/// (Jaccard: shared families over all families named). Each hint costs half a mark. Marking lives in the simulation (ADR 0001):
/// the UI sends the answers and shows the result, and gets its picker options from Options().</summary>
public static class TastingMarker
{
    public static readonly string[] Exercises = { "sheet", "conclusions", "cause", "identify" };
    public const double HintCost = 0.5;

    private static readonly Dictionary<string, string[]> Scales = new()
    {
        ["colourIntensity"] = new[] { "pale", "medium", "deep" },
        ["noseIntensity"] = new[] { "light", "medium(−)", "medium", "medium(+)", "pronounced" },
        ["flavourIntensity"] = new[] { "light", "medium(−)", "medium", "medium(+)", "pronounced" },
        ["sweetness"] = new[] { "dry", "off-dry", "medium-dry", "medium-sweet", "sweet", "luscious" },
        ["acidity"] = new[] { "low", "medium(−)", "medium", "medium(+)", "high" },
        ["tannin"] = new[] { "low", "medium(−)", "medium", "medium(+)", "high" },
        ["alcohol"] = new[] { "low", "medium", "high" },
        ["body"] = new[] { "light", "medium(−)", "medium", "medium(+)", "full" },
        ["finish"] = new[] { "short", "medium(−)", "medium", "medium(+)", "long" },
        ["quality"] = new[] { "Faulty", "Poor", "Acceptable", "Good", "Very good", "Outstanding" },
    };

    private static readonly Dictionary<string, string[]> Categories = new()
    {
        ["clarity"] = new[] { "clear", "hazy" },
        ["colourWhite"] = new[] { "lemon-green", "lemon", "gold", "amber" },
        ["colourRed"] = new[] { "purple", "ruby", "garnet", "tawny" },
        ["noseCondition"] = new[] { "clean", "unclean" },
        ["development"] = new[] { "youthful", "developing", "fully developed", "tired" },
        ["readiness"] = new[] { "drink now; not designed for long ageing", "can drink now, but has potential for ageing", "not for sale as it is" },
        ["variety"] = Variety.All.Select(v => v.Name).ToArray(),
        ["climate"] = new[] { "cool", "moderate", "warm" },
    };

    public static readonly string[] AromaFamiliesWhite = { "fruit", "floral", "tropical (thiols)", "herbaceous", "noble rot", "fermentation", "malolactic", "lees", "oak", "bottle age (petrol)", "oxidative", "volatile", "reductive", "musty", "cooked" };
    public static readonly string[] AromaFamiliesRed = { "red and black fruit", "floral", "earthy", "herbal", "herbaceous", "fermentation", "malolactic", "oak", "bottle age", "animal", "oxidative", "volatile", "reductive", "musty", "cooked" };
    public static readonly string[] BlicCriteria = { "Balance", "Length", "Intensity", "Complexity" };

    private static readonly Dictionary<string, (string Label, string Skill)> Meta = new()
    {
        ["clarity"] = ("Clarity", "appearance"), ["colourIntensity"] = ("Colour intensity", "appearance"), ["colour"] = ("Colour", "appearance"),
        ["noseCondition"] = ("Condition", "nose"), ["noseIntensity"] = ("Nose intensity", "nose"), ["development"] = ("Development", "nose"), ["aromas"] = ("Aroma families", "nose"),
        ["sweetness"] = ("Sweetness", "sweetness"), ["acidity"] = ("Acidity", "acidity"), ["tannin"] = ("Tannin", "tannin"), ["alcohol"] = ("Alcohol", "alcohol"),
        ["body"] = ("Body", "body"), ["flavourIntensity"] = ("Flavour intensity", "finish"), ["finish"] = ("Finish", "finish"),
        ["quality"] = ("Quality", "quality"), ["readiness"] = ("Readiness", "readiness"),
        ["blic.Balance"] = ("Balance", "quality"), ["blic.Length"] = ("Length", "quality"), ["blic.Intensity"] = ("Intensity", "quality"), ["blic.Complexity"] = ("Complexity", "quality"),
        ["variety"] = ("Grape variety", "identify"), ["region"] = ("Region", "identify"), ["climate"] = ("Vintage: cool, moderate or warm", "identify"),
    };

    /// <summary>The items an exercise asks, in sheet order (tannin only for reds).</summary>
    public static IReadOnlyList<string> Keys(string exercise, bool red)
    {
        var k = exercise switch
        {
            "conclusions" => new List<string> { "blic.Balance", "blic.Length", "blic.Intensity", "blic.Complexity", "quality", "readiness" },
            "cause" => new List<string> { "sweetness", "acidity", "tannin", "alcohol", "body" },
            "identify" => new List<string> { "variety", "region", "climate" },
            _ => new List<string> { "clarity", "colourIntensity", "colour", "noseIntensity", "development", "aromas", "sweetness", "acidity", "tannin",
                "alcohol", "body", "flavourIntensity", "finish", "quality", "readiness" },
        };
        if (!red) k.Remove("tannin");
        return k;
    }

    public static string[]? Scale(string key) => Scales.GetValueOrDefault(key);

    /// <summary>The four cases of commit-then-reveal (learning-core design §5): right means full marks; "sure" is Confidence 3,
    /// anything lower counts as unsure; no Confidence given is its own case.</summary>
    public static string CaseFor(double score, int confidence) => confidence <= 0 ? "no-confidence"
        : score >= 1 ? (confidence >= 3 ? "sure-right" : "guess-right") : (confidence >= 3 ? "sure-wrong" : "guess-wrong");

    /// <summary>The sheet line an item asks about, for its Cause tags.</summary>
    public static string? LineFor(string key) => key switch
    {
        "acidity" => "palate:Acidity", "tannin" => "palate:Tannin", "alcohol" => "palate:Alcohol", "sweetness" => "palate:Sweetness",
        "flavourIntensity" => "palate:Flavour intensity", "colour" or "colourIntensity" => "appearance", "aromas" => "aroma:", "noseCondition" => "fault",
        _ => null,
    };

    public static IReadOnlyList<string> CausesFor(TastingSheet sheet, string key) => LineFor(key) is string line
        ? sheet.CauseLinks.Where(l => line.EndsWith(':') ? l.Line.StartsWith(line) : l.Line == line).Select(l => l.Cause).Distinct().ToList()
        : Array.Empty<string>();

    private static int Conf(JsonObject answers, string key) =>
        answers["confidence"] is JsonObject co && co[key] is JsonValue v && v.TryGetValue<int>(out var i) ? Math.Clamp(i, 1, 3) : 0;

    /// <summary>The picker options for every item, from the model's own vocabulary.</summary>
    public static JsonObject Options(GameData data, bool red)
    {
        var o = new JsonObject();
        JsonArray A(IEnumerable<string> xs) => new(xs.Select(x => (JsonNode)JsonValue.Create(x)!).ToArray());
        foreach (var (k, v) in Scales) o[k] = A(v);
        foreach (var (k, v) in Categories) if (k is not ("colourWhite" or "colourRed")) o[k] = A(v);
        o["colour"] = A(Categories[red ? "colourRed" : "colourWhite"]);
        o["aromas"] = A(red ? AromaFamiliesRed : AromaFamiliesWhite);
        o["region"] = A(data.Plots.Regions.Select(r => r.Name));
        o["blic"] = A(BlicCriteria);
        return o;
    }

    /// <summary>Cool, moderate or warm for the Region: the vintage's growing-degree days against the record's thirds.</summary>
    public static (string Climate, string Because) VintageClimate(GameData data, string regionId, int vintage, int? upTo = null)
    {
        var f = VintageFacts.For(data, regionId, vintage, upTo);
        string c = f.GddRank <= f.RecordYears / 3.0 ? "warm" : f.GddRank > f.RecordYears * 2 / 3.0 ? "cool" : "moderate";
        return (c, $"{vintage}: {f.Gdd:0} growing-degree days, {Ord(f.GddRank)} warmest of the {f.RecordYears} years in the {data.Region(regionId).Name} record ({f.RecordFrom}–{f.RecordTo}); the warmest third counts as warm, the coolest third as cool");
    }

    private static string Ord(int n) => n + (n % 100 is 11 or 12 or 13 ? "th" : (n % 10) switch { 1 => "st", 2 => "nd", 3 => "rd", _ => "th" });

    private static string Str(JsonObject a, string key) =>
        a.TryGetPropertyValue(key, out var v) && v is JsonValue jv && jv.TryGetValue<string>(out var s) ? s.Trim() : "";

    public static MarkResult Mark(GameData data, PouredWine p, string exercise, JsonObject answers, int? upTo = null)
    {
        var sh = p.Sheet; var c = p.Context;
        string Pal(string attr) => sh.Palate.FirstOrDefault(x => x.Attribute == attr) is { } l ? l.Level.Split(',')[0].Trim() : "";
        string PalBecause(string attr) => sh.Palate.FirstOrDefault(x => x.Attribute == attr)?.Because ?? "";
        var items = new List<MarkItem>();
        foreach (var key in Keys(exercise, c.Red))
        {
            var (label, skill) = Meta[key];
            string actual, because, yours;
            double score;
            if (key == "aromas")
            {
                var act = sh.Aromas.Select(a => a.Family).Distinct().ToList();
                var mine = answers["aromas"] is JsonArray arr
                    ? arr.Select(x => x is JsonValue v && v.TryGetValue<string>(out var s) ? s : null).Where(s => !string.IsNullOrEmpty(s)).Select(s => s!).Distinct().ToList()
                    : new List<string>();
                int inter = mine.Intersect(act).Count(), union = mine.Union(act).Count();
                score = mine.Count == 0 ? 0 : union == 0 ? 1 : Math.Round((double)inter / union, 2);
                yours = string.Join(", ", mine);
                actual = act.Count == 0 ? "no clear aromas" : string.Join(", ", act);
                because = string.Join("; ", sh.Aromas.Select(a => $"{a.Family} ({a.Terms}): {a.Because}"));
                items.Add(new(key, label, skill, yours, actual, score, because, Conf(answers, key), CaseFor(score, Conf(answers, key)), CausesFor(sh, key)));
                continue;
            }
            if (key.StartsWith("blic."))
            {
                string crit = key[5..];
                var b = sh.Blic.FirstOrDefault(x => x.Criterion == crit);
                actual = b.Criterion == null ? "not judged" : b.Met ? "met" : "not met";
                because = b.Why ?? "";
                bool? mine = answers["blic"] is JsonObject bo && bo.TryGetPropertyValue(crit, out var bv) && bv is JsonValue bj && bj.TryGetValue<bool>(out var bb) ? bb : null;
                yours = mine == null ? "" : mine.Value ? "met" : "not met";
                score = mine != null && yours == actual ? 1 : 0;
                items.Add(new(key, label, skill, yours, actual, score, because, Conf(answers, key), CaseFor(score, Conf(answers, key))));
                continue;
            }
            yours = Str(answers, key);
            (actual, because) = key switch
            {
                "clarity" => (sh.Clarity, "the Wine was fined and filtered"),
                "colourIntensity" => (sh.ColourIntensity, sh.AppearanceBecause),
                "colour" => (sh.Colour, sh.AppearanceBecause),
                "noseCondition" => (sh.NoseCondition, sh.Faults.Count > 0 ? string.Join(" ", sh.Faults) : "no faults"),
                "noseIntensity" => (sh.NoseIntensity, "how strongly the aroma families come through"),
                "development" => (sh.Development, $"{c.AgeYears:0.#} years since the harvest" + (sh.Aromas.Any(a => a.Category == "Tertiary") ? "; bottle-age aromas have appeared" : "")),
                "sweetness" => (Pal("Sweetness"), PalBecause("Sweetness")),
                "acidity" => (Pal("Acidity"), PalBecause("Acidity")),
                "tannin" => (Pal("Tannin"), PalBecause("Tannin")),
                "alcohol" => (Pal("Alcohol"), PalBecause("Alcohol")),
                "body" => (Pal("Body"), PalBecause("Body")),
                "flavourIntensity" => (sh.FlavourIntensity, PalBecause("Flavour intensity")),
                "finish" => (sh.Finish, PalBecause("Finish")),
                "quality" => (sh.Quality, sh.QualityBecause),
                "readiness" => (sh.Readiness, sh.QualityBecause),
                "variety" => (c.Variety, $"{c.Variety} from {c.PlotName}, {c.RegionName}"),
                "region" => (c.RegionName, $"{c.PlotName}, {c.RegionName}"),
                "climate" => VintageClimate(data, c.RegionId, c.Vintage, upTo),
                _ => ("", ""),
            };
            if (yours.Length == 0) score = 0;
            else if (Scales.TryGetValue(key, out var sc))
            {
                int i = Array.IndexOf(sc, yours), j = Array.IndexOf(sc, actual);
                score = i < 0 || j < 0 ? 0 : i == j ? 1 : Math.Abs(i - j) == 1 ? 0.5 : 0;
            }
            else score = string.Equals(yours, actual, StringComparison.OrdinalIgnoreCase) ? 1 : 0;
            items.Add(new(key, label, skill, yours, actual, score, because, Conf(answers, key), CaseFor(score, Conf(answers, key)), CausesFor(sh, key)));
        }
        int hints = answers["hints"] is JsonValue hv && hv.TryGetValue<int>(out var h) ? Math.Max(0, h) : 0;
        double total = Math.Max(0, items.Sum(x => x.Score) - hints * HintCost);
        return new MarkResult(exercise, items, total, items.Count, hints);
    }

    /// <summary>Marks the vintage quiz: 1 for the right glass, else 0.</summary>
    public static List<MarkItem> MarkQuiz(IReadOnlyList<QuizQuestion> quiz, JsonObject answers) =>
        quiz.Select((q, i) =>
        {
            string yours = Str(answers, q.Topic);
            int conf = answers["confidence"] is JsonObject co && co[q.Topic] is JsonValue v && v.TryGetValue<int>(out var ci) ? Math.Clamp(ci, 1, 3) : 0;
            double sc = yours == q.Answer ? 1 : 0;
            return new MarkItem("quiz." + q.Topic, q.Text, "vintage", yours, q.Answer, sc, q.Evidence, conf, CaseFor(sc, conf));
        }).ToList();
}
