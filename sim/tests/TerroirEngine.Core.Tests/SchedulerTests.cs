using System.Text.Json.Nodes;
using TerroirEngine.Learning;
using TerroirEngine.Tasting.Practice;

namespace TerroirEngine.Tests;

/// <summary>Spaced review of Causes, mastery, the weekly rhythm and the study-record upgrade (learning-core design §4).</summary>
public class SchedulerTests
{
    private static readonly DateOnly D0 = new(2026, 10, 5);   // a Monday

    private static CauseState Run(params (int day, bool right, int conf)[] answers)
    {
        CauseState? s = null;
        foreach (var (day, right, conf) in answers) s = ReviewScheduler.Review(s, "x", right, conf, D0.AddDays(day), null);
        return s!;
    }

    [Fact]
    public void Ladder_1_3_7_16_35_ThenStability()
    {
        CauseState? s = null; var day = D0; var gaps = new List<int>();
        for (int i = 0; i < 7; i++)
        {
            s = ReviewScheduler.Review(s, "x", true, 3, day, null);
            gaps.Add(s.Due!.Value.DayNumber - day.DayNumber);
            day = s.Due!.Value;
        }
        Assert.Equal(new[] { 1, 3, 7, 16, 35 }, gaps.Take(5));
        Assert.True(gaps[5] > 35 && gaps[6] > gaps[5], string.Join(",", gaps));
    }

    [Fact]
    public void NoRetestInTheSameSitting_AndSureWrongComesBackTomorrow()
    {
        var s = Run((0, false, 3));
        Assert.Equal(D0.AddDays(1), s.Due);
        s = Run((0, true, 3), (1, true, 3), (4, false, 3));
        Assert.Equal(D0.AddDays(5), s.Due);
        Assert.Equal(0, s.Step);
    }

    [Fact]
    public void GuessAndRight_ScheduledHarderThanSure()
    {
        var sure = Run((0, true, 3), (1, true, 3));
        var guess = Run((0, true, 3), (1, true, 1));
        Assert.True(guess.Due < sure.Due, $"{guess.Due} vs {sure.Due}");
        Assert.True(guess.Difficulty > sure.Difficulty);
    }

    [Fact]
    public void Known_After3RightOn3Days_LostAfterTwoMisses()
    {
        Assert.False(Run((0, true, 3), (0, true, 3), (0, true, 3)).Known);          // one day only
        Assert.False(Run((0, true, 3), (1, true, 3)).Known);
        var k = Run((0, true, 3), (1, true, 3), (4, true, 3));
        Assert.True(k.Known);
        Assert.True(ReviewScheduler.Review(k, "x", false, 2, D0.AddDays(11), null).Known);   // one miss keeps it
        var lost = Run((0, true, 3), (1, true, 3), (4, true, 3), (11, false, 2), (12, false, 2));
        Assert.False(lost.Known);
    }

    [Fact]
    public void ExamDate_CapsGaps_AndGivesThreeSuccessesBeforeIt()
    {
        var exam = D0.AddDays(120);
        CauseState? s = null; var day = D0; int successes = 0;
        while (day < exam)
        {
            s = ReviewScheduler.Review(s, "x", true, 3, day, exam);
            successes++;
            int left = exam.DayNumber - day.DayNumber, gap = s.Due!.Value.DayNumber - day.DayNumber;
            Assert.True(gap <= Math.Max(3, (int)Math.Ceiling(left * 0.10)) || gap <= 1, $"gap {gap} with {left} days left");
            if (left <= 21) Assert.True(gap <= 5);
            day = s.Due!.Value;
        }
        Assert.True(successes >= 3);
    }

    [Fact]
    public void Scheduler_ToleratesClockJumps()
    {
        var s = Run((10, true, 3));
        var back = ReviewScheduler.Review(s, "x", true, 3, D0.AddDays(2), null);   // the clock went backwards
        Assert.True(back.Due > D0.AddDays(10));
        Assert.True(back.LastSeen >= D0.AddDays(10));
        var many = Run((0, true, 3), (0, true, 3), (0, true, 3), (0, false, 1), (0, true, 3));
        Assert.True(many.Due > D0);
        var gap = Run((0, true, 3), (1, true, 3), (200, true, 3));
        Assert.True(gap.Due > D0.AddDays(200));
    }

    [Fact]
    public void Due_ListsOverdueFirst()
    {
        var rec = new JsonObject();
        rec = PracticeProgress.Apply(rec, Ev(D0.AddDays(-3), ("c", false)));
        rec = PracticeProgress.Apply(rec, Ev(D0.AddDays(-1), ("b", false)));
        rec = PracticeProgress.Apply(rec, Ev(D0, ("a", true)));
        var due = ReviewScheduler.Due(rec, D0);
        Assert.Equal("c", due[0]);
        Assert.Contains("b", due);
        Assert.DoesNotContain("a", due);
    }

    private static JsonObject Ev(DateOnly date, params (string cause, bool right)[] items) => new()
    {
        ["kind"] = "practice", ["date"] = date.ToString("yyyy-MM-dd"),
        ["items"] = new JsonArray(items.Select(i => (JsonNode)new JsonObject
        {
            ["skill"] = "acidity", ["score"] = i.right ? 1 : 0, ["confidence"] = 3, ["causes"] = new JsonArray(i.cause),
        }).ToArray()),
    };

    [Fact]
    public void RanksFromKnownShare()
    {
        var cat = CauseCatalog.All(Fixture.Data);
        var rec = new JsonObject();
        int n = (int)Math.Ceiling(cat.Count * 0.40);
        foreach (var d in new[] { 0, 1, 4 })
            rec = PracticeProgress.Apply(rec, Ev(D0.AddDays(d), cat.Take(n).Select(c => (c.Id, true)).ToArray()));
        var s = PracticeProgress.Summary(rec, D0.AddDays(4), cat);
        Assert.Equal(n, s["known"]!.GetValue<int>());
        Assert.Equal("Taster", s["rank"]!.GetValue<string>());
        Assert.True(s["blindUnlocked"]!.GetValue<bool>());
        Assert.Equal("Novice taster", PracticeProgress.Summary(new JsonObject(), D0, cat)["rank"]!.GetValue<string>());
        // volume earns nothing: answering the same three Causes a hundred times on one day is still not Known
        var spam = new JsonObject();
        for (int i = 0; i < 100; i++) spam = PracticeProgress.Apply(spam, Ev(D0, ("cool-season-acid", true)));
        Assert.Equal(0, PracticeProgress.Summary(spam, D0, cat)["known"]!.GetValue<int>());
    }

    [Fact]
    public void WeeklyRhythm_CountsDays_RepairWithinWeek()
    {
        var rec = new JsonObject();
        foreach (var d in new[] { 0, 1, 3 }) rec = PracticeProgress.Apply(rec, Ev(D0.AddDays(d), ("a", true)));
        var r = PracticeProgress.Summary(rec, D0.AddDays(3))["rhythm"]!;
        Assert.Equal(3, r["daysThisWeek"]!.GetValue<int>());
        Assert.Equal(5, r["target"]!.GetValue<int>());
        // a missed day (Tuesday + 2 = Wednesday) is repaired by an extra set of reviews later that week
        var big = Ev(D0.AddDays(4), Enumerable.Range(0, 10).Select(i => ($"r{i}", true)).ToArray());
        rec = PracticeProgress.Apply(rec, big);
        Assert.Equal(5, PracticeProgress.Summary(rec, D0.AddDays(4))["rhythm"]!["daysThisWeek"]!.GetValue<int>());
        // a new week starts fresh, quietly
        Assert.Equal(0, PracticeProgress.Summary(rec, D0.AddDays(7))["rhythm"]!["daysThisWeek"]!.GetValue<int>());
    }

    [Fact]
    public void Migration_V1RecordKeepsEverything()
    {
        var v1 = JsonNode.Parse("""
            {"version":1,"xp":640,"lastGain":30,"medals":{"frost-2016":"silver"},"bestPercent":{"frost-2016":72.5},
             "cards":["cote-dor 2016"],"skills":{"acidity":[1,0.5,0]},"daily":{"last":"2026-09-30","streak":2,"best":4},
             "stats":{"glasses":7,"flights":1},"future":{"x":1}}
            """)!.AsObject();
        var v2 = StudyRecord.Migrate(v1);
        Assert.Equal(2, v2["version"]!.GetValue<int>());
        foreach (var key in new[] { "xp", "medals", "bestPercent", "cards", "skills", "daily", "stats", "future" })
            Assert.Equal(v1[key]!.ToJsonString(), v2[key]!.ToJsonString());
        Assert.NotNull(v2["causes"]);
        var s = PracticeProgress.Summary(v2, new DateOnly(2026, 10, 2), CauseCatalog.All(Fixture.Data));
        Assert.Equal("silver", s["medals"]!["frost-2016"]!.GetValue<string>());
        Assert.Equal(640, s["xp"]!.GetValue<int>());
        Assert.Equal(v2.ToJsonString(), StudyRecord.Migrate(v2).ToJsonString());   // idempotent
    }
}
