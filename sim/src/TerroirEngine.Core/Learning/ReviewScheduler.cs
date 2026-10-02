using System.Globalization;
using System.Text.Json.Nodes;

namespace TerroirEngine.Learning;

public sealed record CauseAnswer(DateOnly Date, bool Right, int Confidence);

/// <summary>A Cause's place in the review queue: the ladder step, an FSRS-style stability (days) and difficulty (1–10),
/// when it is due, when it was last seen, its answer history and whether it is Known.</summary>
public sealed record CauseState(string Id, int Step, double Stability, double Difficulty, DateOnly? Due, DateOnly? LastSeen,
    List<CauseAnswer> History, bool Known);

/// <summary>Spaced review of Causes (learning-core design §4.1–4.3; research track A §1, §3).
/// A new or missed Cause comes back after 1, 3, 7, 16 and 35 days, then a light FSRS-style stability grows with each right
/// answer (more for a sure one, less for a hard Cause). A miss returns it the next day and restarts the ladder; a right answer
/// with Confidence "guess" repeats the previous rung instead of climbing. Nothing is ever due again the same day. With an exam
/// date, gaps are capped at about a tenth of the days left (at least 3) and at 3–5 days in the last three weeks.
/// Known: right answers on three separate days; lost after two misses in a row.</summary>
public static class ReviewScheduler
{
    public static readonly int[] Ladder = { 1, 3, 7, 16, 35 };
    public const double StartDifficulty = 5, LadderStability = 35;
    private const int HistoryCap = 40, MaxInterval = 3650;

    public static CauseState Review(CauseState? s, string id, bool right, int confidence, DateOnly today, DateOnly? examDate)
    {
        s ??= new CauseState(id, 0, 0, StartDifficulty, null, null, new List<CauseAnswer>(), false);
        var day = s.LastSeen is DateOnly last && today < last ? last : today;   // a clock that went backwards never schedules into the past
        int conf = Math.Clamp(confidence, 1, 3);
        var history = s.History.Append(new CauseAnswer(day, right, conf)).TakeLast(HistoryCap).ToList();
        // one sitting counts once: a further right answer on a day the Cause was already reviewed is recorded, not rewarded
        if (right && s.LastSeen == day && s.Due != null) return s with { History = history, Known = IsKnown(history) };
        int step = s.Step, interval;
        double stab = s.Stability, diff = s.Difficulty;
        if (!right)
        {
            step = 0; interval = 1;
            diff = Math.Min(10, diff + 1);
            stab = Math.Max(1, stab * 0.5);
        }
        else if (step < Ladder.Length)
        {
            if (conf == 1) { interval = Ladder[Math.Max(0, step - 1)]; diff = Math.Min(10, diff + 0.5); }
            else { interval = Ladder[step]; step++; diff = Math.Max(1, diff - (conf == 3 ? 0.3 : 0.1)); }
            if (step == Ladder.Length) stab = Math.Max(stab, LadderStability);
        }
        else
        {
            double gain = (conf == 1 ? 0.3 : conf == 2 ? 0.8 : 1.2) * (11 - diff) / 10;
            stab = Math.Max(stab, LadderStability) * Math.Max(1.1, 1 + gain);
            interval = (int)Math.Round(stab);
            diff = conf == 1 ? Math.Min(10, diff + 0.3) : Math.Max(1, diff - 0.1);
        }
        if (examDate is DateOnly exam && day < exam)
        {
            int left = exam.DayNumber - day.DayNumber;
            int cap = Math.Max(3, (int)Math.Ceiling(left * 0.10));
            if (left <= 21) cap = Math.Min(5, cap);
            interval = Math.Min(interval, cap);
        }
        interval = Math.Clamp(interval, 1, MaxInterval);
        return new CauseState(id, step, stab, diff, day.AddDays(interval), day, history, IsKnown(history));
    }

    /// <summary>Right answers on three separate days; two misses in a row undo it (and the count starts again).</summary>
    public static bool IsKnown(IEnumerable<CauseAnswer> history)
    {
        var days = new HashSet<DateOnly>(); int misses = 0; bool known = false;
        foreach (var a in history)
        {
            if (a.Right) { misses = 0; days.Add(a.Date); if (days.Count >= 3) known = true; }
            else if (++misses >= 2) { known = false; days.Clear(); }
        }
        return known;
    }

    /// <summary>Causes due on or before today, most overdue first.</summary>
    public static IReadOnlyList<string> Due(JsonObject record, DateOnly today) =>
        StudyRecord.States(record).Values.Where(s => s.Due is DateOnly d && d <= today)
            .OrderBy(s => s.Due).ThenBy(s => s.Id, StringComparer.Ordinal).Select(s => s.Id).ToList();
}

/// <summary>The study record, version 2: the v1 Tasting-practice record plus "causes" (per-Cause review state) and "rhythm"
/// (study days). Migration keeps every v1 field and is idempotent.</summary>
public static class StudyRecord
{
    public const int Version = 2;
    private static readonly CultureInfo Ci = CultureInfo.InvariantCulture;

    public static JsonObject Migrate(JsonObject record)
    {
        var r = (JsonObject)record.DeepClone();
        if (r["causes"] is not JsonObject) r["causes"] = new JsonObject();
        if (r["rhythm"] is not JsonArray) r["rhythm"] = new JsonArray();
        r["version"] = Version;
        return r;
    }

    private static DateOnly? Date(JsonNode? n) =>
        n is JsonValue v && v.TryGetValue<string>(out var s) && DateOnly.TryParseExact(s, "yyyy-MM-dd", Ci, DateTimeStyles.None, out var d) ? d : null;
    private static double Num(JsonNode? n, double dflt) =>
        n is JsonValue v ? v.TryGetValue<double>(out var d) ? d : v.TryGetValue<int>(out var i) ? i : dflt : dflt;

    public static Dictionary<string, CauseState> States(JsonObject record)
    {
        var map = new Dictionary<string, CauseState>();
        if (record["causes"] is not JsonObject causes) return map;
        foreach (var (id, node) in causes)
        {
            if (node is not JsonObject o) continue;
            var hist = new List<CauseAnswer>();
            if (o["h"] is JsonArray h)
                foreach (var e in h)
                    if (e is JsonArray a && a.Count >= 3 && Date(a[0]) is DateOnly d) hist.Add(new CauseAnswer(d, Num(a[1], 0) > 0, (int)Num(a[2], 2)));
            map[id] = new CauseState(id, (int)Num(o["step"], 0), Num(o["stab"], 0), Num(o["diff"], ReviewScheduler.StartDifficulty),
                Date(o["due"]), Date(o["last"]), hist, ReviewScheduler.IsKnown(hist));
        }
        return map;
    }

    public static void Put(JsonObject record, CauseState s)
    {
        if (record["causes"] is not JsonObject causes) { causes = new JsonObject(); record["causes"] = causes; }
        causes[s.Id] = new JsonObject
        {
            ["step"] = s.Step, ["stab"] = Math.Round(s.Stability, 2), ["diff"] = Math.Round(s.Difficulty, 2),
            ["due"] = s.Due?.ToString("yyyy-MM-dd", Ci), ["last"] = s.LastSeen?.ToString("yyyy-MM-dd", Ci), ["known"] = s.Known,
            ["h"] = new JsonArray(s.History.Select(a => (JsonNode)new JsonArray(a.Date.ToString("yyyy-MM-dd", Ci), a.Right ? 1 : 0, a.Confidence)).ToArray()),
        };
    }
}
