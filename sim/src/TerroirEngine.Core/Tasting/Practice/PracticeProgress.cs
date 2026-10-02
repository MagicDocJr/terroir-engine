using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using TerroirEngine.Learning;

namespace TerroirEngine.Tasting.Practice;

/// <summary>Progression for Tasting practice (tasting-practice design §6b), computed from the player's study record — a JSON
/// document the game stores as user://tasting_record.json and passes back unchanged. Every point is earned by a marked answer:
/// 10 XP per full mark (5 for half), a bonus for a better medal and for the Glass of the day. The record is tolerant: missing,
/// malformed or unknown fields are defaulted or kept, never fatal. Rank thresholds are paced for months of study: a Flight at the
/// Fair earns roughly 250 XP at half marks.</summary>
public static class PracticeProgress
{
    public const int Version = StudyRecord.Version, HistoryLength = 20, XpPerMark = 10, HintXp = 5, DailyBonus = 25;

    public static readonly (string Name, int Xp, string Line)[] Ranks =
    {
        ("Novice taster", 0, "Learning the systematic approach, one glass at a time."),
        ("Cellar hand", 300, "You can describe what is in the glass."),
        ("Taster", 1500, "You judge structure and quality with confidence. Blind Flights are open to you."),
        ("Senior taster", 5000, "You reason from the glass back to the vineyard and the vintage."),
        ("Fair judge", 12000, "Your verdicts would hold up on any panel."),
    };
    public const int BlindRank = 2;
    /// <summary>Ranks by the share of the Cause catalogue the player Knows (learning-core design §4.3): rewards report
    /// durable mastery, never volume. XP stays as a quiet tally (and ranks a record when no catalogue is given).</summary>
    public static readonly double[] RankShare = { 0, 0.15, 0.40, 0.70, 0.95 };
    public const int RhythmTarget = 5, RepairReviews = 5;
    private static readonly string[] MedalOrder = { "bronze", "silver", "gold" };
    private static readonly Dictionary<string, int> MedalBonus = new() { ["bronze"] = 20, ["silver"] = 40, ["gold"] = 80 };
    /// <summary>Stand tiers open with medals: tier 1 after the first medal, tier 2 after three.</summary>
    public static readonly int[] MedalsForTier = { 0, 1, 3 };
    public static readonly string[] CoreSkills = { "appearance", "nose", "sweetness", "acidity", "tannin", "alcohol", "body", "finish", "quality", "readiness", "identify", "vintage" };

    public static string? MedalFor(double percent) => percent >= 85 ? "gold" : percent >= 70 ? "silver" : percent >= 50 ? "bronze" : null;

    public static JsonObject Load(string? text) => TryLoad(text, out var r) ? r : r;

    /// <summary>False when the text is not a readable record (not JSON, not an object, duplicate keys): the caller should keep a
    /// copy of the file before anything overwrites it. The record is then empty. No text at all is a fresh start (true).</summary>
    public static bool TryLoad(string? text, out JsonObject record)
    {
        record = new JsonObject();
        if (string.IsNullOrWhiteSpace(text)) return true;
        try
        {
            if (JsonNode.Parse(text) is not JsonObject o) return false;
            Walk(o);   // enumerating builds each object's dictionary, so duplicate keys fail here and not later
            record = o;
            return true;
        }
        catch (Exception e) when (e is JsonException or ArgumentException or InvalidOperationException) { record = new JsonObject(); return false; }
    }

    private static void Walk(JsonNode? n)
    {
        if (n is JsonObject o) foreach (var kv in o) Walk(kv.Value);
        else if (n is JsonArray arr) foreach (var x in arr) Walk(x);
    }

    // ------------------------------------------------------------------------------------------------ tolerant readers

    private static int Int(JsonNode? n) => double.IsNaN(Num(n)) ? 0 : (int)Math.Clamp(Num(n), int.MinValue, int.MaxValue);
    private static double Num(JsonNode? n)
    {
        if (n is not JsonValue v) return double.NaN;
        double d = v.TryGetValue<double>(out var a) ? a : v.TryGetValue<int>(out var b) ? b : v.TryGetValue<long>(out var c) ? c
            : v.TryGetValue<float>(out var e) ? e : v.TryGetValue<decimal>(out var f) ? (double)f : double.NaN;
        return double.IsFinite(d) ? d : double.NaN;
    }
    private static string? Str(JsonNode? n) => n is JsonValue v && v.TryGetValue<string>(out var s) ? s : null;
    private static JsonObject Obj(JsonObject parent, string key)
    {
        if (parent[key] is JsonObject o) return o;
        var fresh = new JsonObject(); parent[key] = fresh; return fresh;
    }
    private static JsonArray Arr(JsonObject parent, string key)
    {
        if (parent[key] is JsonArray a) return a;
        var fresh = new JsonArray(); parent[key] = fresh; return fresh;
    }
    private static DateOnly? Date(JsonNode? n) => Str(n) is { } s && DateOnly.TryParseExact(s, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d) ? d : null;

    // ------------------------------------------------------------------------------------------------ events

    /// <summary>Applies one marked result and returns the updated record (the input is not changed). Event:
    /// {kind: practice|stand|daily, date: yyyy-MM-dd, items: [{skill, score}], hints?, stand?, percent?, cards?: ["region year"]}.
    /// A malformed event returns the record unchanged.</summary>
    public static JsonObject Apply(JsonObject record, JsonObject ev)
    {
        var rec = StudyRecord.Migrate(record);
        string? kind = Str(ev["kind"]);
        var date = Date(ev["date"]);
        rec["lastGain"] = 0;
        if (kind is not ("practice" or "stand" or "daily") || date == null || ev["items"] is not JsonArray items) return rec;
        rec["version"] = Version;
        var daily = Obj(rec, "daily");
        if (kind == "daily" && Date(daily["last"]) == date) return rec;   // one Glass of the day per calendar day

        int xp = Math.Max(0, Int(rec["xp"]));
        var skills = Obj(rec, "skills");
        double marks = 0;
        var outcomes = new Dictionary<string, (bool Right, int Conf)>();   // per Cause: the worst outcome in this event
        foreach (var it in items)
        {
            if (it is not JsonObject o || Str(o["skill"]) is not { Length: > 0 } skill || double.IsNaN(Num(o["score"]))) continue;
            double sc = Math.Clamp(Num(o["score"]), 0, 1);
            marks += sc;
            int conf = double.IsNaN(Num(o["confidence"])) ? 2 : Math.Clamp(Int(o["confidence"]), 1, 3);
            if (o["causes"] is JsonArray cs)
                foreach (var id in cs.Select(Str).Where(x => !string.IsNullOrEmpty(x)))
                {
                    // half credit counts as right but hard (scheduled like a guess)
                    var now = (Right: sc >= 0.5, Conf: sc >= 0.5 && sc < 1 ? 1 : conf);
                    outcomes[id!] = outcomes.TryGetValue(id!, out var was) ? (was.Right && now.Right, Math.Min(was.Conf, now.Conf)) : now;
                }
            var hist = Arr(skills, skill);
            hist.Add(Math.Round(sc, 2));
            while (hist.Count > HistoryLength) hist.RemoveAt(0);
        }
        int gained = (int)Math.Round(marks * XpPerMark) - HintXp * Math.Max(0, Int(ev["hints"]));
        gained = Math.Max(0, gained);

        if (kind == "stand" && Str(ev["stand"]) is { Length: > 0 } stand)
        {
            // a replayed stand pours the same vintages again: only an improvement on the best score earns item XP
            double prev = rec["bestPercent"] is JsonObject bp ? Num(bp[stand]) : double.NaN;
            double pctNow = Num(ev["percent"]);
            if (!double.IsNaN(prev))
                gained = double.IsNaN(pctNow) || pctNow <= prev ? 0 : (int)Math.Round((pctNow - prev) / 100.0 * items.Count * XpPerMark);
            var medals = Obj(rec, "medals");
            string? old = Str(medals[stand]), now = MedalFor(Num(ev["percent"]) is var p && double.IsNaN(p) ? 0 : p);
            if (now != null && Array.IndexOf(MedalOrder, now) > Array.IndexOf(MedalOrder, old ?? ""))
            {
                gained += MedalBonus[now] - (old != null ? MedalBonus[old] : 0);
                medals[stand] = now;
            }
            var best = Obj(rec, "bestPercent");
            if (Num(ev["percent"]) is var pc && !double.IsNaN(pc) && (double.IsNaN(Num(best[stand])) || pc > Num(best[stand]))) best[stand] = pc;
        }
        if (ev["cards"] is JsonArray cards)
        {
            var have = Arr(rec, "cards");
            var set = have.Select(Str).Where(s => s != null).ToHashSet();
            foreach (var c in cards.Select(Str).Where(s => !string.IsNullOrEmpty(s) && !set.Contains(s))) { have.Add(c); set.Add(c); }
        }
        if (kind == "daily")
        {
            var last = Date(daily["last"]);
            int run = last != null && last.Value.AddDays(1) == date ? Math.Max(0, Int(daily["streak"])) + 1 : 1;
            daily["last"] = date.Value.ToString("yyyy-MM-dd");
            daily["streak"] = run;
            daily["best"] = Math.Max(run, Int(daily["best"]));
            gained += DailyBonus;
        }
        var stats = Obj(rec, "stats");
        stats[kind == "stand" ? "flights" : "glasses"] = Int(stats[kind == "stand" ? "flights" : "glasses"]) + 1;
        var states = StudyRecord.States(rec);
        var exam = Date(rec["examDate"]);
        foreach (var (id, o) in outcomes) StudyRecord.Put(rec, ReviewScheduler.Review(states.GetValueOrDefault(id), id, o.Right, o.Conf, date.Value, exam));
        var rhythm = Arr(rec, "rhythm");
        var today = rhythm.OfType<JsonObject>().FirstOrDefault(e => Date(e["date"]) == date);
        if (today == null) { today = new JsonObject { ["date"] = date.Value.ToString("yyyy-MM-dd"), ["n"] = 0 }; rhythm.Add(today); }
        today["n"] = Int(today["n"]) + items.Count;
        while (rhythm.Count > 60) rhythm.RemoveAt(0);
        rec["xp"] = xp + gained;
        rec["lastGain"] = gained;
        return rec;
    }

    /// <summary>Sets (or clears, with null) the exam date the review schedule works towards.</summary>
    public static JsonObject SetExamDate(JsonObject record, DateOnly? exam)
    {
        var rec = StudyRecord.Migrate(record);
        if (exam is DateOnly d) rec["examDate"] = d.ToString("yyyy-MM-dd"); else rec.Remove("examDate");
        return rec;
    }

    /// <summary>The weekly rhythm (Monday to Sunday): days studied, plus missed days repaired by an extra set of reviews
    /// (every 5 beyond the first 5 on a day) later in the week. A new week starts fresh and quietly.</summary>
    public static (int Days, int Elapsed) Rhythm(JsonObject rec, DateOnly today)
    {
        var monday = today.AddDays(-(((int)today.DayOfWeek + 6) % 7));
        int elapsed = today.DayNumber - monday.DayNumber + 1;
        var week = (rec["rhythm"] as JsonArray ?? new JsonArray()).OfType<JsonObject>()
            .Select(e => (D: Date(e["date"]), N: Int(e["n"]))).Where(e => e.D >= monday && e.D <= today).ToList();
        int days = week.Select(e => e.D).Distinct().Count();
        int repairs = week.Sum(e => Math.Max(0, e.N - RepairReviews) / RepairReviews);
        return (Math.Min(elapsed, days + Math.Min(elapsed - days, repairs)), elapsed);
    }

    // ------------------------------------------------------------------------------------------------ summary

    public static int RankIndex(int xp) => Array.FindLastIndex(Ranks, r => xp >= r.Xp);

    /// <summary>The average score per skill over its recent history (skills with no answers are absent).</summary>
    public static Dictionary<string, (double Avg, int N)> Skills(JsonObject rec)
    {
        var d = new Dictionary<string, (double, int)>();
        if (rec["skills"] is not JsonObject sk) return d;
        foreach (var (k, v) in sk)
            if (v is JsonArray a && a.Select(Num).Where(x => !double.IsNaN(x)).ToList() is { Count: > 0 } xs) d[k] = (xs.Average(), xs.Count);
        return d;
    }

    /// <summary>The skill to practise next: the lowest average among skills with at least three answers, else null.</summary>
    public static string? Weakest(JsonObject rec) =>
        Skills(rec).Where(kv => kv.Value.N >= 3 && kv.Key != "vintage").OrderBy(kv => kv.Value.Avg).ThenBy(kv => kv.Key).Select(kv => kv.Key).FirstOrDefault();

    public static int MedalCount(JsonObject rec) => rec["medals"] is JsonObject m ? m.Count(kv => MedalOrder.Contains(Str(kv.Value))) : 0;

    public static int UnlockedTier(JsonObject rec) => Array.FindLastIndex(MedalsForTier, n => MedalCount(rec) >= n);

    public static JsonObject Summary(JsonObject rec, DateOnly? today = null, IReadOnlyList<Cause>? catalog = null)
    {
        int xp = Math.Max(0, Int(rec["xp"]));
        var states = StudyRecord.States(rec);
        int known = catalog == null ? states.Values.Count(x => x.Known) : catalog.Count(c => states.TryGetValue(c.Id, out var st) && st.Known);
        double share = catalog == null || catalog.Count == 0 ? 0 : (double)known / catalog.Count;
        int ri = catalog == null ? RankIndex(xp) : Array.FindLastIndex(RankShare, x => share >= x);
        var medals = new JsonObject();
        if (rec["medals"] is JsonObject m) foreach (var (k, v) in m) if (MedalOrder.Contains(Str(v))) medals[k] = Str(v);
        var daily = rec["daily"] as JsonObject;
        var last = Date(daily?["last"]);
        var t = today ?? DateOnly.FromDateTime(DateTime.Now);
        int streak = last != null && (last == t || last.Value.AddDays(1) == t) ? Math.Max(0, Int(daily!["streak"])) : 0;
        var skills = Skills(rec);
        string? weak = Weakest(rec);
        var rhythm = Rhythm(rec, t);
        return new JsonObject
        {
            ["xp"] = xp, ["rank"] = Ranks[ri].Name, ["rankLine"] = Ranks[ri].Line, ["rankIndex"] = ri,
            ["nextRank"] = ri + 1 < Ranks.Length ? Ranks[ri + 1].Name : null,
            ["nextXp"] = ri + 1 < Ranks.Length ? Ranks[ri + 1].Xp : null,
            ["rankXp"] = Ranks[ri].Xp,
            ["lastGain"] = Math.Max(0, Int(rec["lastGain"])),
            ["medals"] = medals, ["medalCount"] = medals.Count, ["unlockedTier"] = UnlockedTier(rec),
            ["tierNeeds"] = new JsonArray(MedalsForTier.Select(n => (JsonNode)JsonValue.Create(n)!).ToArray()),
            ["blindUnlocked"] = ri >= BlindRank,
            ["cards"] = new JsonArray((rec["cards"] as JsonArray ?? new JsonArray()).Select(Str).Where(s => s != null).Select(s => (JsonNode)JsonValue.Create(s!)!).ToArray()),
            ["dailyDone"] = last == t, ["daysInARow"] = streak, ["bestDaysInARow"] = Math.Max(0, Int(daily?["best"])),
            ["skills"] = new JsonArray(CoreSkills.Select(s => (JsonNode)new JsonObject
            {
                ["skill"] = s, ["avg"] = skills.TryGetValue(s, out var v) ? Math.Round(v.Avg, 2) : null, ["n"] = skills.TryGetValue(s, out var w) ? w.N : 0,
                ["history"] = (rec["skills"] as JsonObject)?[s] is JsonArray ha ? ha.DeepClone() : new JsonArray(),
            }).ToArray()),
            ["weakest"] = weak,
            ["stats"] = (rec["stats"] as JsonObject)?.DeepClone() ?? new JsonObject(),
            ["known"] = known, ["knownShare"] = Math.Round(share, 3), ["catalogSize"] = catalog?.Count ?? 0, ["byKnown"] = catalog != null,
            ["rankShare"] = RankShare[ri], ["nextShare"] = ri + 1 < RankShare.Length ? RankShare[ri + 1] : null,
            ["due"] = ReviewScheduler.Due(rec, t).Count,
            ["rhythm"] = new JsonObject { ["daysThisWeek"] = rhythm.Days, ["elapsed"] = rhythm.Elapsed, ["target"] = RhythmTarget, ["met"] = rhythm.Days >= RhythmTarget },
            ["examDate"] = Str(rec["examDate"]),
            // calibration: how often answers at each Confidence were right (learning-core design §5)
            ["calibration"] = new JsonArray(new[] { 1, 2, 3 }.Select(cf =>
            {
                var hs = states.Values.SelectMany(x => x.History).Where(h => h.Confidence == cf).ToList();
                return (JsonNode)new JsonObject { ["confidence"] = cf, ["n"] = hs.Count, ["accuracy"] = hs.Count == 0 ? null : Math.Round(hs.Count(h => h.Right) / (double)hs.Count, 2) };
            }).ToArray()),
            ["daysToExam"] = Date(rec["examDate"]) is DateOnly ed ? ed.DayNumber - t.DayNumber : null,
            // coverage by area (the topic up to its first ':' or ';'): six rows, not one per fine topic
            ["coverage"] = catalog == null ? null : new JsonArray(catalog.GroupBy(c => c.Topic.Split(':', ';')[0].Trim()).Select(g => (JsonNode)new JsonObject
            {
                ["topic"] = g.Key,
                ["known"] = g.Count(c => states.TryGetValue(c.Id, out var st) && st.Known),
                ["learning"] = g.Count(c => states.TryGetValue(c.Id, out var st) && !st.Known),
                ["notSeen"] = g.Count(c => !states.ContainsKey(c.Id)),
            }).ToArray()),
        };
    }
}
