using System.Globalization;
using System.Text.Json.Nodes;
using TerroirEngine.Data;

namespace TerroirEngine.Tasting.Practice;

/// <summary>One round of Tasting practice, from request to marked result (tasting-practice design §4–§6b). The game's bridge
/// runs Pour on a background thread, hands Json() to the screen, and passes the player's answers to Mark together with the
/// study record; everything that decides an outcome lives here (ADR 0001).</summary>
public sealed class PracticeSession
{
    public string Kind = "practice", Exercise = "sheet";
    public Stand? Stand;
    public string? Focus;
    public int Seed;
    public bool Blind;
    public List<PourSpec> Specs = new();
    public List<PouredWine> Flight = new();
    public List<QuizQuestion> Quiz = new();
    public List<string> Shown = new();

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

    /// <summary>The last vintage whose harvest is over on a game's Timeline: this year's from December, else last year's.
    /// Game simplification: a single cut-off date for every Region and style.</summary>
    public static int MaxVintageFor(DateOnly today) => today.Month == 12 ? today.Year : today.Year - 1;

    private static string? Str(JsonNode? n) => n is JsonValue v && v.TryGetValue<string>(out var s) ? s : null;
    private static int? Int(JsonNode? n) => n is JsonValue v ? v.TryGetValue<int>(out var i) ? i : v.TryGetValue<double>(out var d) ? (int)d : null : null;
    private static bool Bool(JsonNode? n) => n is JsonValue v && v.TryGetValue<bool>(out var b) && b;

    public static PracticeSession Pour(GameData data, JsonObject req, JsonObject record, DateOnly today, int? maxVintage)
    {
        var s = new PracticeSession { Kind = Str(req["kind"]) ?? "practice", Seed = Int(req["seed"]) ?? 1 };
        string? ex = Str(req["exercise"]);
        if (s.Kind == "stand")
        {
            string id = Str(req["stand"]) ?? "";
            var st = FairStands.All(data, maxVintage).FirstOrDefault(x => x.Id == id) ?? throw new InvalidOperationException($"no stand {id}");
            if (st.Locked) throw new InvalidOperationException($"stand {id} opens after the {st.UnlockYear} harvest");
            if (st.Tier > PracticeProgress.UnlockedTier(record)) throw new InvalidOperationException($"stand {id} needs more medals");
            s.Stand = st; s.Exercise = "sheet"; s.Specs = st.Pours.ToList(); s.Shown = st.Shown.ToList();
            s.Blind = Bool(req["blind"]) && PracticeProgress.RankIndex(Int(record["xp"]) ?? 0) >= PracticeProgress.BlindRank;
            if (s.Blind)
            {
                // blind: the glasses in a seeded secret order, vintages hidden until the reveal
                var order = Enumerable.Range(0, s.Specs.Count).OrderBy(i => new Random(s.Seed * 17 + i).Next()).ToList();
                s.Specs = order.Select(i => s.Specs[i]).ToList();
                s.Shown = s.Specs.Select(_ => "?").ToList();
            }
            s.Flight = s.Specs.Select((p, i) => TastingLab.Pour(data, p, s.Seed * 31 + i)).ToList();
            s.Quiz = VintageQuiz.For(data, st, s.Flight);
            return s;
        }
        if (!PracticePours.Available(maxVintage)) throw new InvalidOperationException($"no vintage from {PracticePours.FirstVintage} on has been harvested yet");
        switch (s.Kind)
        {
            case "daily":
                s.Exercise = "identify"; s.Seed = PracticePours.DailySeed(today);
                s.Specs.Add(PracticePours.Daily(data, today, maxVintage));
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
        s.Flight = s.Specs.Select((p, i) => TastingLab.Pour(data, p, s.Seed + i)).ToList();
        s.Shown = s.Specs.Select(p => p.Vintage.ToString()).ToList();
        return s;
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
                ["shown"] = Shown[i], ["wine"] = PracticeJson.Poured(p), ["options"] = TastingMarker.Options(data, p.Context.Red),
                ["keys"] = A(TastingMarker.Keys(Exercise, p.Context.Red)), ["hint"] = Hint(p, Exercise),
            });
        }
        var ex = ExerciseList.First(e => e.Id == Exercise);
        return new JsonObject
        {
            ["kind"] = Kind, ["exercise"] = Exercise, ["exerciseTitle"] = ex.Title, ["exerciseLine"] = ex.Line, ["blind"] = Blind,
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
    };

    public static JsonObject? NoteJson(GameData data, string regionId, int year) => VintageNotes.For(data, regionId, year) is { } n
        ? new JsonObject { ["note"] = n.Note, ["sources"] = new JsonArray(n.Sources.Select(s => (JsonNode)new JsonObject { ["title"] = s.Title, ["url"] = s.Url }).ToArray()) }
        : null;

    public (JsonObject Result, JsonObject Record) Mark(GameData data, JsonObject answers, JsonObject record, DateOnly today)
    {
        var wineAnswers = answers["wines"] as JsonArray;
        var marks = Flight.Select((p, i) => TastingMarker.Mark(data, p, Exercise, wineAnswers != null && i < wineAnswers.Count && wineAnswers[i] is JsonObject o ? o : new JsonObject())).ToList();
        var quiz = TastingMarker.MarkQuiz(Quiz, answers["quiz"] as JsonObject ?? new JsonObject());
        double total = marks.Sum(m => m.Total) + quiz.Sum(q => q.Score), max = marks.Sum(m => m.Max) + quiz.Count;
        double percent = max <= 0 ? 0 : Math.Round(100 * total / max, 1);
        var items = marks.SelectMany(m => m.Items).Concat(quiz).ToList();
        var cards = Stand != null ? Flight.Select(p => $"{p.Context.RegionId} {p.Context.Vintage}").Distinct().ToList() : new List<string>();
        var ev = new JsonObject
        {
            ["kind"] = Kind == "stand" ? "stand" : Kind == "daily" ? "daily" : "practice", ["date"] = today.ToString("yyyy-MM-dd", Ci),
            ["items"] = new JsonArray(items.Select(x => (JsonNode)new JsonObject { ["skill"] = x.Skill, ["score"] = x.Score }).ToArray()),
            ["hints"] = marks.Sum(m => m.Hints), ["stand"] = Stand?.Id, ["percent"] = percent, ["cards"] = A(cards),
        };
        var before = PracticeProgress.Summary(record, today);
        var had = (record["cards"] as JsonArray ?? new JsonArray()).Select(Str).ToHashSet();
        var rec = PracticeProgress.Apply(record, ev);
        var after = PracticeProgress.Summary(rec, today);
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
                ["climate"] = TastingMarker.VintageClimate(data, c.RegionId, c.Vintage).Because,
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
            ["summary"] = after,
        };
        return (result, rec);
    }

    // ------------------------------------------------------------------------------------------------ lobby

    /// <summary>Everything the Tasting-practice screens show before a pour: the record summary, the exercises, the stands with
    /// medals and locks, and the Cellar book. Inside a game, cards for vintages not yet harvested stay hidden (ADR 0002).</summary>
    public static JsonObject Lobby(GameData data, JsonObject record, DateOnly today, int? maxVintage)
    {
        var sum = PracticeProgress.Summary(record, today);
        int tier = PracticeProgress.UnlockedTier(record);
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
            cards.Add(CardJson(data, parts[0], year));
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

    public static JsonObject CardJson(GameData data, string regionId, int year)
    {
        var f = VintageFacts.For(data, regionId, year);
        var (climate, because) = TastingMarker.VintageClimate(data, regionId, year);
        return new JsonObject
        {
            ["region"] = regionId, ["regionName"] = data.Region(regionId).Name, ["year"] = year, ["climate"] = climate, ["climateBecause"] = because,
            ["gdd"] = f.Gdd, ["gddRank"] = f.GddRank, ["recordYears"] = f.RecordYears, ["summerTmax"] = f.SummerTmax, ["autumnRain"] = f.AutumnRainMm,
            ["hotDays"] = f.HotDays, ["frostNight"] = f.SpringFrostDate.ToString("d MMMM", Ci), ["frostC"] = Math.Round(f.SpringFrostC, 1),
            ["note"] = NoteJson(data, regionId, year),
        };
    }
}
