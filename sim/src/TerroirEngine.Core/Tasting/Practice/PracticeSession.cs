using System.Globalization;
using System.Text.Json.Nodes;
using TerroirEngine.Data;
using TerroirEngine.Learning;

namespace TerroirEngine.Tasting.Practice;

/// <summary>One round of Tasting practice, from request to marked result (tasting-practice design §4–§6b). The game's bridge
/// runs Pour on a background thread, hands Json() to the screen, and passes the player's answers to Mark together with the
/// study record; everything that decides an outcome lives here (ADR 0001).</summary>
/// <summary>One question of a review-session entry: its options (a scale when Ordered, marked 1 / ½ / 0), the answer and the
/// explanation shown whatever the player answered.</summary>
public sealed class SessionQuestion
{
    public string Prompt = "", Answer = "", Because = "", Skill = "";
    public List<string> Options = new();
    public bool Ordered;
}

/// <summary>One entry of a review session: a Cause checked by a Wine to predict, a contrast pair, or its chain with blanks.</summary>
public sealed class SessionEntry
{
    public string Kind = "", Cause = "", Reason = "";
    public int Blanks, WithGlass;
    public PouredWine? Wine, Wine2;
    public ChainQ? Chain;
    public List<SessionQuestion> Questions = new();
}

public sealed class PracticeSession
{
    public string Kind = "practice", Exercise = "sheet";
    public Stand? Stand;
    public string? Focus;
    public int Seed;
    public bool Blind;
    /// <summary>Inside a game: the last vintage harvested on its Timeline (null from the title screen).</summary>
    public int? MaxVintage;
    public List<PourSpec> Specs = new();
    public List<PouredWine> Flight = new();
    public List<QuizQuestion> Quiz = new();
    public List<string> Shown = new();
    public List<SessionEntry> Entries = new();

    private static readonly CultureInfo Ci = CultureInfo.InvariantCulture;

    public static readonly (string Id, string Title, string Line)[] ExerciseList =
    {
        ("conclusions", "Conclusions", "Read the appearance, nose and palate, then judge the quality and readiness, as in a tasting exam."),
        ("cause", "Cause to glass", "Read the site, the vintage and the winemaking, then predict the palate: the theory behind the glass."),
        ("identify", "Identify", "Read the whole Tasting sheet, then name the grape, the Region and how warm the vintage was, as in a blind tasting."),
        ("sheet", "Your Tasting sheet", "See the glass and what the label tells you, then write the whole Tasting sheet."),
    };

    private static readonly Dictionary<string, string> FocusLines = new()
    {
        ["tannin"] = "Your weak spot: tannin. Here is a red to work on it.",
        ["sweetness"] = "Your weak spot: sweetness. Here is a Riesling that may or may not be dry.",
        ["acidity"] = "Your weak spot: acidity. Think about the site and the season before you answer.",
        ["alcohol"] = "Your weak spot: alcohol. Must weight at harvest is the clue.",
        ["body"] = "Your weak spot: body. Alcohol, sugar, extract and oak all add weight.",
        ["quality"] = "Your weak spot: judging quality. Weigh balance, length, intensity and complexity one by one.",
        ["readiness"] = "Your weak spot: readiness. Ask what the Wine has that could improve with age.",
        ["identify"] = "Your weak spot: identifying Wines. Look for each grape's signature.",
        ["nose"] = "Your weak spot: the nose. Think about which aroma families the winemaking adds.",
        ["appearance"] = "Your weak spot: appearance. Grape, age and winemaking all change the colour.",
        ["finish"] = "Your weak spot: flavour intensity and finish. Yield and ripeness drive concentration.",
    };

    /// <summary>The highest open tier of stands: what the medals open, and inside an early game also the next tier while every
    /// stand below it is still in the future (otherwise the Fair would have nothing to taste).</summary>
    public static int OpenTier(GameData data, JsonObject record, int? maxVintage)
    {
        int tier = PracticeProgress.UnlockedTier(record);
        var stands = FairStands.All(data, maxVintage);
        while (tier + 1 < PracticeProgress.MedalsForTier.Length && stands.Where(s => s.Tier <= tier).All(s => s.Locked)) tier++;
        return tier;
    }

    /// <summary>The last vintage whose harvest is over on a game's Timeline: this year's from December, else last year's.
    /// Game simplification: a single cut-off date for every Region and style.</summary>
    public static int MaxVintageFor(DateOnly today) => today.Month == 12 ? today.Year : today.Year - 1;

    private static string? Str(JsonNode? n) => n is JsonValue v && v.TryGetValue<string>(out var s) ? s : null;
    private static int? Int(JsonNode? n) => n is JsonValue v ? v.TryGetValue<int>(out var i) ? i : v.TryGetValue<double>(out var d) ? (int)d : null : null;
    private static bool Bool(JsonNode? n) => n is JsonValue v && v.TryGetValue<bool>(out var b) && b;

    public static PracticeSession Pour(GameData data, JsonObject req, JsonObject record, DateOnly today, int? maxVintage)
    {
        var s = new PracticeSession { Kind = Str(req["kind"]) ?? "practice", Seed = Int(req["seed"]) ?? 1, MaxVintage = maxVintage };
        string? ex = Str(req["exercise"]);
        if (s.Kind == "stand")
        {
            string id = Str(req["stand"]) ?? "";
            var st = FairStands.All(data, maxVintage).FirstOrDefault(x => x.Id == id) ?? throw new InvalidOperationException($"no stand {id}");
            if (st.Locked) throw new InvalidOperationException($"stand {id} opens after the {st.UnlockYear} harvest");
            if (st.Tier > OpenTier(data, record, maxVintage)) throw new InvalidOperationException($"stand {id} needs more medals");
            s.Stand = st; s.Exercise = "sheet"; s.Specs = st.Pours.ToList(); s.Shown = st.Shown.ToList();
            s.Blind = Bool(req["blind"]) && PracticeProgress.Summary(record, today, CauseCatalog.All(data))["rankIndex"]!.GetValue<int>() >= PracticeProgress.BlindRank;
            if (s.Blind)
            {
                // blind: the glasses in a seeded secret order, vintages hidden until the reveal
                var order = Enumerable.Range(0, s.Specs.Count).OrderBy(i => new Random(s.Seed * 17 + i).Next()).ToList();
                s.Specs = order.Select(i => s.Specs[i]).ToList();
                s.Shown = s.Specs.Select(_ => "?").ToList();
            }
            s.Flight = s.Specs.Select((p, i) => TastingLab.Pour(data, p, s.Seed * 31 + i)).ToList();
            s.Quiz = VintageQuiz.For(data, st, s.Flight, maxVintage);
            return s;
        }
        if (!PracticePours.Available(maxVintage)) throw new InvalidOperationException($"no vintage from {PracticePours.FirstVintage} on has been harvested yet");
        if (s.Kind == "session")
        {
            s.Exercise = "session";
            var cat = CauseCatalog.All(data);
            var items = SessionComposer.Compose(data, record, today, maxVintage, Int(req["size"]) ?? 6, s.Seed);
            for (int k = 0; k < items.Count; k++) s.Entries.Add(BuildEntry(data, cat, items[k], s.Seed * 97 + k, maxVintage));
            return s;
        }
        switch (s.Kind)
        {
            case "daily":
                s.Exercise = "identify"; s.Seed = PracticePours.DailySeed(today);
                // a due Cause seeds the day's glass: the review happens inside the blind glass (learning-core design §4.6)
                foreach (var id in ReviewScheduler.Due(record, today))
                    if (CauseCatalog.Find(data, id) is { ReviewBy: "wine" } dc && PracticePours.ForCause(data, dc, s.Seed, maxVintage) is { } dw)
                    {
                        s.Focus = id; s.Flight.Add(dw); s.Specs.Add(new PourSpec(dw.Context.PlotId, dw.Context.Vintage, dw.Context.BlockId, dw.Context.Variety, dw.Context.StyleId));
                        break;
                    }
                if (s.Flight.Count == 0) s.Specs.Add(PracticePours.Daily(data, today, maxVintage));
                break;
            case "suggest":
                var (spec, focus) = PracticePours.Suggest(data, record, s.Seed, maxVintage);
                s.Focus = focus; s.Specs.Add(spec);
                s.Exercise = ex ?? focus switch
                {
                    "quality" or "readiness" => "conclusions",
                    "identify" => "identify",
                    "nose" or "appearance" or "finish" => "sheet",
                    _ => "cause",
                };
                break;
            default:
                s.Kind = "practice"; s.Specs.Add(PracticePours.Random(data, s.Seed, maxVintage));
                break;
        }
        if (ex != null && TastingMarker.Exercises.Contains(ex) && s.Kind != "daily") s.Exercise = ex;
        if (s.Flight.Count == 0) s.Flight = s.Specs.Select((p, i) => TastingLab.Pour(data, p, s.Seed + i)).ToList();
        s.Shown = s.Specs.Select(p => p.Vintage.ToString()).ToList();
        return s;
    }

    // ------------------------------------------------------------------------------------------------ review-session entries

    private static readonly Dictionary<string, string> PalateKey = new()
    {
        ["palate:Acidity"] = "acidity", ["palate:Tannin"] = "tannin", ["palate:Alcohol"] = "alcohol", ["palate:Sweetness"] = "sweetness",
        ["palate:Flavour intensity"] = "flavourIntensity",
    };

    private static string ChainText(Cause c) => string.Join(" → ", c.Chain);

    private static SessionEntry ChainEntry(Cause c, string reason, int blanks, int seed, IReadOnlyList<Cause> cat)
    {
        var q = ChainQuestion.For(c, Math.Max(1, blanks), seed, cat);
        var e = new SessionEntry { Kind = "chain", Cause = c.Id, Reason = reason, Blanks = q.Blanks.Count, Chain = q };
        foreach (var b in q.Blanks)
            e.Questions.Add(new SessionQuestion
            {
                Prompt = $"Step {b.Index + 1} of the chain", Options = b.Options, Answer = b.Answer,
                Because = ChainText(c), Skill = SessionComposer.SkillFor(c.Line),
            });
        return e;
    }

    /// <summary>The question a Wine asks about its Cause's line: predict the palate level, the colour, or which aroma family it
    /// shows (with plausible decoys absent from the sheet). Null when the line has no question form.</summary>
    private static SessionQuestion? WineQuestion(Cause c, PouredWine w, int seed)
    {
        var sh = w.Sheet; var rng = new Random(seed);
        string because = ChainText(c);
        if (PalateKey.TryGetValue(c.Line, out var key))
        {
            var line = sh.Palate.FirstOrDefault(l => "palate:" + l.Attribute == c.Line);
            if (line == null) return null;
            return new SessionQuestion
            {
                Prompt = $"Predict the {line.Attribute.ToLowerInvariant()}", Options = TastingMarker.Scale(key)!.ToList(),
                Answer = line.Level.Split(',')[0].Trim(), Ordered = true, Because = line.Because + ". " + because, Skill = SessionComposer.SkillFor(c.Line),
            };
        }
        if (c.Line == "appearance")
            return new SessionQuestion
            {
                Prompt = "Predict the colour", Options = (w.Context.Red ? new[] { "purple", "ruby", "garnet", "tawny" } : new[] { "lemon-green", "lemon", "gold", "amber" }).ToList(),
                Answer = sh.Colour, Ordered = true, Because = sh.AppearanceBecause + ". " + because, Skill = "appearance",
            };
        if (c.Line.StartsWith("aroma:"))
        {
            var fam = c.Line[6..];
            var d = sh.Aromas.FirstOrDefault(a => a.Family == fam);
            if (d == null) return null;
            var present = sh.Aromas.Select(a => a.Family).ToHashSet();
            var pool = (w.Context.Red ? TastingMarker.AromaFamiliesRed : TastingMarker.AromaFamiliesWhite).Where(f => !present.Contains(f)).OrderBy(_ => rng.Next()).Take(3);
            return new SessionQuestion
            {
                Prompt = "Which of these will you find on the nose?", Options = pool.Append(fam).OrderBy(_ => rng.Next()).ToList(),
                Answer = fam, Because = $"{d.Family} ({d.Terms}): {d.Because}. " + because, Skill = "nose",
            };
        }
        return null;
    }

    private static SessionEntry BuildEntry(GameData data, IReadOnlyList<Cause> cat, SessionItem item, int seed, int? maxVintage)
    {
        var c = cat.First(x => x.Id == item.Cause);
        if (item.Kind == "contrast" && PracticePours.ContrastFor(data, c, seed, maxVintage) is { } pair)
        {
            var rng = new Random(seed);
            int withGlass = rng.Next(2);
            var kind = c.Line.Contains(':') ? c.Line[..c.Line.IndexOf(':')] : c.Line;
            var decoys = cat.Where(o => o.Id != c.Id && (o.Line.Contains(':') ? o.Line[..o.Line.IndexOf(':')] : o.Line) == kind).OrderBy(_ => rng.Next()).Take(3).Select(o => o.Title);
            var e = new SessionEntry { Kind = "contrast", Cause = c.Id, Reason = item.Reason, WithGlass = withGlass };
            e.Wine = withGlass == 0 ? pair.With : pair.Without; e.Wine2 = withGlass == 0 ? pair.Without : pair.With;
            e.Questions.Add(new SessionQuestion
            {
                Prompt = "These two Wines differ in one cause. Which?", Options = decoys.Append(c.Title).OrderBy(_ => rng.Next()).ToList(),
                Answer = c.Title, Because = ChainText(c), Skill = SessionComposer.SkillFor(c.Line),
            });
            e.Questions.Add(new SessionQuestion
            {
                Prompt = "Which glass shows it?", Options = new() { "Glass 1", "Glass 2" }, Answer = $"Glass {withGlass + 1}",
                Because = $"Glass {withGlass + 1} has it on its sheet ({c.Line.Replace("palate:", "").Replace("aroma:", "")}); the other glass does not.",
                Skill = SessionComposer.SkillFor(c.Line),
            });
            return e;
        }
        if (item.Kind is "wine" or "contrast" && PracticePours.ForCause(data, c, seed, maxVintage) is { } wine && WineQuestion(c, wine, seed) is { } q)
            return new SessionEntry { Kind = "wine", Cause = c.Id, Reason = item.Reason, Wine = wine, Questions = { q } };
        // no Wine shows it here (chain-reviewed Cause, an early Timeline, or no candidate): its chain with two blanks
        return ChainEntry(c, item.Reason, item.Kind == "chain" ? item.Blanks : 2, seed, cat);
    }

    // ------------------------------------------------------------------------------------------------ JSON for the screen

    private static JsonArray A(IEnumerable<string> xs) => new(xs.Select(x => (JsonNode)JsonValue.Create(x)!).ToArray());

    public static string Hint(PouredWine p, string exercise)
    {
        var c = p.Context;
        return exercise switch
        {
            "conclusions" => "Balance: " + (p.Sheet.Blic.FirstOrDefault(b => b.Criterion == "Balance").Why ?? ""),
            "cause" => $"The finished Wine has {p.Wine.Blend.AlcoholPct.ToString("0.0", Ci)} % vol alcohol and {p.Wine.Blend.Rs.ToString("0", Ci)} g/L of sugar.",
            "identify" => $"Picked on {c.HarvestDate.ToString("d MMMM", Ci)} at {c.HarvestOe:0} °Oe; tasted {c.AgeYears.ToString("0.#", Ci)} years after the harvest.",
            _ => p.Sheet.Palate.FirstOrDefault(x => x.Attribute == "Acidity") is { } l ? $"Acidity: {l.Level.Split(',')[0]}, because {l.Because}" : "",
        };
    }

    public static JsonObject StandJson(GameData data, Stand st) => new()
    {
        ["id"] = st.Id, ["title"] = st.Title, ["blurb"] = st.Blurb, ["region"] = st.RegionId, ["regionName"] = data.Region(st.RegionId).Name,
        ["variety"] = st.Locked ? "" : st.Variety, ["tier"] = st.Tier, ["locked"] = st.Locked, ["unlockYear"] = st.UnlockYear, ["glasses"] = st.Pours.Count,
        ["host"] = new JsonObject { ["name"] = st.Host.Name, ["producer"] = st.Host.Producer, ["greeting"] = st.Host.Greeting },
        ["shown"] = A(st.Shown),
    };

    public JsonObject Json(GameData data)
    {
        var glasses = new JsonArray();
        for (int i = 0; i < Flight.Count; i++)
        {
            var p = Flight[i];
            glasses.Add(new JsonObject
            {
                ["shown"] = Shown[i], ["wine"] = PracticeJson.Shown(p, Exercise, Blind, Stand != null), ["options"] = TastingMarker.Options(data, p.Context.Red),
                ["keys"] = A(TastingMarker.Keys(Exercise, p.Context.Red)), ["hint"] = Hint(p, Exercise),
            });
        }
        var ex = Exercise == "session" ? ("session", "Today's session", "Causes due for review, your weak spot and something new, each checked a different way.") : ExerciseList.First(e => e.Id == Exercise);
        var cat = Entries.Count > 0 ? CauseCatalog.All(data) : null;
        var entries = new JsonArray(Entries.Select(e => (JsonNode)new JsonObject
        {
            ["kind"] = e.Kind, ["cause"] = e.Cause, ["reason"] = e.Reason, ["title"] = cat!.First(c => c.Id == e.Cause).Title,
            ["steps"] = e.Chain == null ? null : A(e.Chain.Steps.Select((st, i) => e.Chain.Blanks.Any(b => b.Index == i) ? "" : st)),
            ["blanks"] = e.Chain == null ? null : new JsonArray(e.Chain.Blanks.Select(b => (JsonNode)JsonValue.Create(b.Index)!).ToArray()),
            ["wine"] = e.Wine == null ? null : PracticeJson.Shown(e.Wine, "session", false, false),
            ["wine2"] = e.Wine2 == null ? null : PracticeJson.Shown(e.Wine2, "session", false, false),
            ["questions"] = new JsonArray(e.Questions.Select(q => (JsonNode)new JsonObject { ["prompt"] = q.Prompt, ["options"] = A(q.Options), ["ordered"] = q.Ordered }).ToArray()),
        }).ToArray());
        return new JsonObject
        {
            ["entries"] = entries,
            ["kind"] = Kind, ["exercise"] = Exercise, ["exerciseTitle"] = ex.Item2, ["exerciseLine"] = ex.Item3, ["blind"] = Blind,
            ["focus"] = Focus, ["focusLine"] = Focus != null ? FocusLines.GetValueOrDefault(Focus) : null, ["seed"] = Seed,
            ["stand"] = Stand != null ? StandJson(data, Stand) : null,
            ["glasses"] = glasses,
            ["quiz"] = new JsonArray(Quiz.Select(q => (JsonNode)new JsonObject { ["topic"] = q.Topic, ["text"] = q.Text, ["options"] = A(q.Options) }).ToArray()),
        };
    }

    // ------------------------------------------------------------------------------------------------ marking

    private static JsonObject ItemJson(MarkItem m) => new()
    {
        ["key"] = m.Key, ["label"] = m.Label, ["skill"] = m.Skill, ["yours"] = m.Yours, ["actual"] = m.Actual, ["score"] = m.Score, ["because"] = m.Because,
        ["confidence"] = m.Confidence, ["case"] = m.Case,
    };

    private static JsonObject EventItem(MarkItem x) => new()
    {
        ["skill"] = x.Skill, ["score"] = x.Score, ["confidence"] = x.Confidence > 0 ? x.Confidence : null,
        ["causes"] = x.Causes is { Count: > 0 } cs ? A(cs) : null,
    };

    private static string? AnswerAt(JsonNode? entry, int j, out int confidence)
    {
        confidence = 0;
        if (entry is not JsonObject o) return null;
        if (o["confidence"] is JsonArray ca && j < ca.Count && ca[j] is JsonValue cv && cv.TryGetValue<int>(out var ci)) confidence = Math.Clamp(ci, 1, 3);
        return o["answers"] is JsonArray aa && j < aa.Count && aa[j] is JsonValue av && av.TryGetValue<string>(out var s) ? s : null;
    }

    private (JsonObject Result, JsonObject Record) MarkSession(GameData data, JsonObject answers, JsonObject record, DateOnly today)
    {
        var cat = CauseCatalog.All(data);
        var given = answers["entries"] as JsonArray;
        var all = new List<MarkItem>();
        var entries = new JsonArray();
        for (int i = 0; i < Entries.Count; i++)
        {
            var e = Entries[i];
            var items = new List<MarkItem>();
            for (int j = 0; j < e.Questions.Count; j++)
            {
                var q = e.Questions[j];
                string yours = AnswerAt(given != null && i < given.Count ? given[i] : null, j, out int conf) ?? "";
                double score;
                if (yours == "") score = 0;
                else if (q.Ordered)
                {
                    int a = q.Options.IndexOf(yours), b = q.Options.IndexOf(q.Answer);
                    score = a < 0 || b < 0 ? 0 : a == b ? 1 : Math.Abs(a - b) == 1 ? 0.5 : 0;
                }
                else score = yours == q.Answer ? 1 : 0;
                items.Add(new MarkItem($"{e.Cause}.{j}", q.Prompt, q.Skill, yours, q.Answer, score, q.Because, conf, TastingMarker.CaseFor(score, conf), new[] { e.Cause }));
            }
            all.AddRange(items);
            var c = cat.First(x => x.Id == e.Cause);
            entries.Add(new JsonObject
            {
                ["kind"] = e.Kind, ["cause"] = e.Cause, ["title"] = c.Title, ["chain"] = A(c.Chain), ["topic"] = c.Topic,
                ["items"] = new JsonArray(items.Select(x => (JsonNode)ItemJson(x)).ToArray()),
                ["wine"] = e.Wine == null ? null : PracticeJson.Poured(e.Wine), ["wine2"] = e.Wine2 == null ? null : PracticeJson.Poured(e.Wine2),
            });
        }
        double total = all.Sum(x => x.Score), max = all.Count;
        var ev = new JsonObject
        {
            ["kind"] = "practice", ["date"] = today.ToString("yyyy-MM-dd", Ci),
            ["items"] = new JsonArray(all.Select(x => (JsonNode)EventItem(x)).ToArray()),
        };
        var before = PracticeProgress.Summary(record, today, cat);
        var rec = PracticeProgress.Apply(record, ev);
        var after = PracticeProgress.Summary(rec, today, cat);
        var result = new JsonObject
        {
            ["entries"] = entries, ["total"] = total, ["max"] = max, ["percent"] = max <= 0 ? 0 : Math.Round(100 * total / max, 1),
            ["recap"] = new JsonArray(all.Where(x => x.Score < 1).Select(x => (JsonNode)ItemJson(x)).ToArray()),
            ["xpGained"] = after["lastGain"]!.DeepClone(), ["rankUp"] = after["rankIndex"]!.GetValue<int>() > before["rankIndex"]!.GetValue<int>(),
            ["knownGained"] = after["known"]!.GetValue<int>() - before["known"]!.GetValue<int>(),
            ["summary"] = after,
        };
        return (result, rec);
    }

    public static JsonObject? NoteJson(GameData data, string regionId, int year) => VintageNotes.For(data, regionId, year) is { } n
        ? new JsonObject { ["note"] = n.Note, ["sources"] = new JsonArray(n.Sources.Select(s => (JsonNode)new JsonObject { ["title"] = s.Title, ["url"] = s.Url }).ToArray()) }
        : null;

    public (JsonObject Result, JsonObject Record) Mark(GameData data, JsonObject answers, JsonObject record, DateOnly today)
    {
        if (Kind == "session") return MarkSession(data, answers, record, today);
        var cat = CauseCatalog.All(data);
        var wineAnswers = answers["wines"] as JsonArray;
        var marks = Flight.Select((p, i) => TastingMarker.Mark(data, p, Exercise, wineAnswers != null && i < wineAnswers.Count && wineAnswers[i] is JsonObject o ? o : new JsonObject(), MaxVintage)).ToList();
        var quizAnswers = (answers["quiz"] as JsonObject)?.DeepClone() as JsonObject ?? new JsonObject();
        if (answers["quizConfidence"] is JsonObject qc) quizAnswers["confidence"] = qc.DeepClone();
        var quiz = TastingMarker.MarkQuiz(Quiz, quizAnswers);
        double total = marks.Sum(m => m.Total) + quiz.Sum(q => q.Score), max = marks.Sum(m => m.Max) + quiz.Count;
        double percent = max <= 0 ? 0 : Math.Round(100 * total / max, 1);
        var items = marks.SelectMany(m => m.Items).Concat(quiz).ToList();
        var cards = Stand != null ? Flight.Select(p => $"{p.Context.RegionId} {p.Context.Vintage}").Distinct().ToList() : new List<string>();
        var ev = new JsonObject
        {
            ["kind"] = Kind == "stand" ? "stand" : Kind == "daily" ? "daily" : "practice", ["date"] = today.ToString("yyyy-MM-dd", Ci),
            ["items"] = new JsonArray(items.Select(x => (JsonNode)EventItem(x)).ToArray()),
            ["hints"] = marks.Sum(m => m.Hints), ["stand"] = Stand?.Id, ["percent"] = percent, ["cards"] = A(cards),
        };
        var before = PracticeProgress.Summary(record, today, cat);
        var had = (record["cards"] as JsonArray ?? new JsonArray()).Select(Str).ToHashSet();
        var rec = PracticeProgress.Apply(record, ev);
        var after = PracticeProgress.Summary(rec, today, cat);
        // the longest run of full marks, item by item, for the reveal's streak flourish
        int run = 0, best = 0;
        foreach (var x in items) { run = x.Score >= 1 ? run + 1 : 0; best = Math.Max(best, run); }
        var glasses = new JsonArray();
        for (int i = 0; i < Flight.Count; i++)
        {
            var c = Flight[i].Context;
            glasses.Add(new JsonObject
            {
                ["items"] = new JsonArray(marks[i].Items.Select(x => (JsonNode)ItemJson(x)).ToArray()),
                ["total"] = marks[i].Total, ["max"] = marks[i].Max, ["percent"] = marks[i].Percent, ["hints"] = marks[i].Hints,
                ["vintage"] = c.Vintage, ["label"] = Flight[i].Wine.Legal?.Label, ["producer"] = c.Producer, ["style"] = c.StyleLabel,
                ["wine"] = PracticeJson.Poured(Flight[i]),
                ["climate"] = TastingMarker.VintageClimate(data, c.RegionId, c.Vintage, MaxVintage).Because,
                ["note"] = NoteJson(data, c.RegionId, c.Vintage),
            });
        }
        string? medal = Stand != null ? PracticeProgress.MedalFor(percent) : null;
        var result = new JsonObject
        {
            ["glasses"] = glasses, ["quiz"] = new JsonArray(quiz.Select(x => (JsonNode)ItemJson(x)).ToArray()),
            ["total"] = total, ["max"] = max, ["percent"] = percent, ["medal"] = medal,
            ["bestMedal"] = Stand != null ? after["medals"]?[Stand.Id]?.DeepClone() : null,
            ["xpGained"] = after["lastGain"]!.DeepClone(), ["rankUp"] = after["rankIndex"]!.GetValue<int>() > before["rankIndex"]!.GetValue<int>(),
            ["tierUp"] = after["unlockedTier"]!.GetValue<int>() > before["unlockedTier"]!.GetValue<int>(),
            ["newCards"] = A(cards.Where(k => !had.Contains(k))),
            ["newCardNames"] = A(Flight.Select(p => p.Context).Where(c => Stand != null && !had.Contains($"{c.RegionId} {c.Vintage}"))
                .Select(c => $"{c.RegionName} {c.Vintage}").Distinct()),
            ["bestStreak"] = best,
            ["recap"] = new JsonArray(items.Where(x => x.Score < 1).Select(x => (JsonNode)ItemJson(x)).ToArray()),
            ["knownGained"] = after["known"]!.GetValue<int>() - before["known"]!.GetValue<int>(),
            ["summary"] = after,
        };
        return (result, rec);
    }

    // ------------------------------------------------------------------------------------------------ lobby

    /// <summary>Everything the Tasting-practice screens show before a pour: the record summary, the exercises, the stands with
    /// medals and locks, and the Cellar book. Inside a game, cards for vintages not yet harvested stay hidden (ADR 0002).</summary>
    public static JsonObject Lobby(GameData data, JsonObject record, DateOnly today, int? maxVintage)
    {
        var sum = PracticeProgress.Summary(record, today, CauseCatalog.All(data));
        int tier = OpenTier(data, record, maxVintage);
        sum["unlockedTier"] = tier;
        var medals = sum["medals"] as JsonObject;
        var best = record["bestPercent"] as JsonObject;
        var stands = new JsonArray();
        var slots = new Dictionary<string, SortedSet<int>>();
        foreach (var st in FairStands.All(data, maxVintage))
        {
            var j = StandJson(data, st);
            j["medal"] = medals?[st.Id]?.DeepClone();
            j["bestPercent"] = best?[st.Id]?.DeepClone();
            j["tierLocked"] = st.Tier > tier;
            j["medalsNeeded"] = PracticeProgress.MedalsForTier[Math.Min(st.Tier, PracticeProgress.MedalsForTier.Length - 1)];
            stands.Add(j);
            if (!st.Locked) foreach (var p in st.Pours) (slots.TryGetValue(st.RegionId, out var ss) ? ss : slots[st.RegionId] = new SortedSet<int>()).Add(p.Vintage);
        }
        var cards = new JsonArray(); int hidden = 0;
        foreach (var key in (record["cards"] as JsonArray ?? new JsonArray()).Select(Str).Where(k => k != null).Distinct())
        {
            var parts = key!.Split(' ');
            if (parts.Length != 2 || !int.TryParse(parts[1], out int year) || data.Plots.Regions.All(r => r.Id != parts[0])) continue;
            if (year < VintageFacts.FirstRecordYear || year > VintageFacts.LastRecordYear(data, parts[0])) continue;
            if (maxVintage != null && year > maxVintage) { hidden++; continue; }
            cards.Add(CardJson(data, parts[0], year, maxVintage));
        }
        return new JsonObject
        {
            ["available"] = PracticePours.Available(maxVintage), ["maxVintage"] = maxVintage, ["summary"] = sum,
            ["exercises"] = new JsonArray(ExerciseList.Select(e => (JsonNode)new JsonObject { ["id"] = e.Id, ["title"] = e.Title, ["line"] = e.Line }).ToArray()),
            ["focusLine"] = sum["weakest"] is JsonValue w && w.TryGetValue<string>(out var ws) ? FocusLines.GetValueOrDefault(ws) : null,
            ["ranks"] = new JsonArray(PracticeProgress.Ranks.Select(r => (JsonNode)new JsonObject { ["name"] = r.Name, ["xp"] = r.Xp, ["line"] = r.Line }).ToArray()),
            ["stands"] = stands,
            ["cellarBook"] = new JsonObject
            {
                ["cards"] = cards, ["hidden"] = hidden,
                ["slots"] = new JsonObject(slots.Select(kv => KeyValuePair.Create(kv.Key, (JsonNode?)new JsonArray(kv.Value.Select(y => (JsonNode)JsonValue.Create(y)!).ToArray())))),
                ["regionNames"] = new JsonObject(data.Plots.Regions.Select(r => KeyValuePair.Create(r.Id, (JsonNode?)JsonValue.Create(r.Name)))),
            },
        };
    }

    public static JsonObject CardJson(GameData data, string regionId, int year, int? upTo = null)
    {
        var f = VintageFacts.For(data, regionId, year, upTo);
        var (climate, because) = TastingMarker.VintageClimate(data, regionId, year, upTo);
        return new JsonObject
        {
            ["region"] = regionId, ["regionName"] = data.Region(regionId).Name, ["year"] = year, ["climate"] = climate, ["climateBecause"] = because,
            ["gdd"] = f.Gdd, ["gddRank"] = f.GddRank, ["recordYears"] = f.RecordYears, ["summerTmax"] = f.SummerTmax, ["autumnRain"] = f.AutumnRainMm,
            ["hotDays"] = f.HotDays, ["frostNight"] = f.SpringFrostDate.ToString("d MMMM", Ci), ["frostC"] = Math.Round(f.SpringFrostC, 1),
            ["note"] = NoteJson(data, regionId, year),
        };
    }
}
