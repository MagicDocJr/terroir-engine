using System.Text.Json.Nodes;
using TerroirEngine.Data;
using TerroirEngine.Tasting.Practice;

namespace TerroirEngine.Learning;

/// <summary>One item of a review session: how the Cause is checked (a Wine to predict, a contrast pair, or its chain with
/// blanks), why it is in the session (due, weak spot or new), and how many chain steps are blank.</summary>
public sealed record SessionItem(string Kind, string Cause, string Reason, int Blanks);

/// <summary>Composes a review session (learning-core design §4.6, research track A §1–§2): about 60 % due reviews (most
/// overdue first), 25 % the weak spot (Causes on the skill with the lowest recent average) and at least one new Cause (in
/// catalogue order, foundations first); never the same Cause twice. New Causes start as a worked chain with one blank, maturing
/// ones get two blanks, and Causes past the second rung are checked with a new Wine, sometimes a contrast pair.</summary>
public static class SessionComposer
{
    public static string SkillFor(string line) => line switch
    {
        "palate:Acidity" => "acidity", "palate:Tannin" => "tannin", "palate:Alcohol" => "alcohol", "palate:Sweetness" => "sweetness",
        "palate:Flavour intensity" => "finish", "appearance" => "appearance", "vintage" => "vintage",
        _ when line.StartsWith("aroma:") || line == "fault" => "nose",
        _ => "causes",
    };

    public static List<SessionItem> Compose(GameData data, JsonObject record, DateOnly today, int? maxVintage, int size, int seed)
    {
        var cat = CauseCatalog.All(data);
        var ids = cat.Select(c => c.Id).ToHashSet();
        var states = StudyRecord.States(record);
        var due = ReviewScheduler.Due(record, today).Where(ids.Contains).ToList();
        int nNew = Math.Max(1, (int)Math.Round(size * 0.15));
        int nDue = Math.Min(due.Count, (int)Math.Floor(size * 0.6 + 0.5));
        var chosen = new List<(string Id, string Reason)>();
        bool Has(string id) => chosen.Any(x => x.Id == id);
        foreach (var id in due.Take(nDue)) chosen.Add((id, "due"));
        int nWeak = Math.Max(0, size - nDue - nNew);
        if (PracticeProgress.Weakest(record) is string weak)
            foreach (var c in cat.Where(c => SkillFor(c.Line) == weak && !Has(c.Id))
                         .OrderBy(c => states.TryGetValue(c.Id, out var s) && s.Known ? 1 : 0).Take(nWeak))
                chosen.Add((c.Id, "weak"));
        foreach (var c in cat.Where(c => !states.ContainsKey(c.Id) && !Has(c.Id)).Take(Math.Max(nNew, size - chosen.Count - (due.Count - nDue))))
        {
            if (chosen.Count >= size) break;
            chosen.Add((c.Id, "new"));
        }
        // fill any gap: the rest of the due list, then Causes still being learnt (soonest due), then anything
        foreach (var id in due.Where(id => !Has(id))) { if (chosen.Count >= size) break; chosen.Add((id, "due")); }
        foreach (var s in states.Values.Where(s => ids.Contains(s.Id) && !s.Known && !Has(s.Id)).OrderBy(s => s.Due))
        { if (chosen.Count >= size) break; chosen.Add((s.Id, "learning")); }
        foreach (var c in cat.Where(c => !Has(c.Id))) { if (chosen.Count >= size) break; chosen.Add((c.Id, "review")); }

        var items = new List<SessionItem>();
        for (int k = 0; k < chosen.Count; k++)
        {
            var (id, reason) = chosen[k];
            var c = cat.First(x => x.Id == id);
            var st = states.GetValueOrDefault(id);
            bool chainOnly = c.ReviewBy != "wine" || c.Line is "vintage" or "fault";
            string kind; int blanks = 0;
            if (st == null) { kind = "chain"; blanks = 1; }
            else if (chainOnly || st.Step <= 1) { kind = "chain"; blanks = Math.Min(2, st.Step + 1); }
            else kind = st.History.Count >= 2 && (seed + k) % 3 == 0 ? "contrast" : "wine";
            items.Add(new SessionItem(kind, id, reason, blanks));
        }
        return items;
    }
}
