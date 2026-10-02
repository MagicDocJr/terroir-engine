using System.Text.Json.Nodes;
using TerroirEngine.Learning;
using TerroirEngine.Tasting.Practice;

namespace TerroirEngine.Tests;

/// <summary>Fixes from the learning core's final review: Known and the Taster rank must mean what the spec says.</summary>
public class FinalReviewFixTests
{
    private static readonly DateOnly Today = new(2026, 10, 5);
    private static IReadOnlyList<Cause> Cat => CauseCatalog.All(Fixture.Data);

    [Fact]
    public void LearnCheck_OnlyQueuesItsCauses_NeverCountsAsAReview()
    {
        var card = LearnCards.Find(Fixture.Data, "malolactic")!;
        var rec = new JsonObject();
        for (int d = 0; d < 3; d++)
        {
            var (r, right) = LearnCards.Check(Fixture.Data, rec, card.Id, card.Check.Answer, Today.AddDays(d));
            Assert.True(right);
            rec = r;
        }
        var states = StudyRecord.States(rec);
        foreach (var id in card.Causes)
        {
            Assert.True(states.ContainsKey(id), id);
            Assert.Empty(states[id].History);
            Assert.False(states[id].Known);
            Assert.Equal(Today.AddDays(1), states[id].Due);
        }
        Assert.Equal(0, (int?)PracticeProgress.Summary(rec, Today.AddDays(2), Cat)["known"]);
    }

    [Fact]
    public void Aromas_EachFamilysCause_IsCreditedOnlyWhenThatFamilyIsPicked()
    {
        var mlf = Cat.First(c => c.Id == "mlf-diacetyl");
        var wine = Enumerable.Range(1, 6).Select(s => PracticePours.ForCause(Fixture.Data, mlf, s, null))
            .First(w => w != null && w.Sheet.CauseLinks.Any(l => l.Line.StartsWith("aroma:") && l.Line != "aroma:malolactic"))!;
        var picked = wine.Sheet.Aromas.Select(a => a.Family).Distinct().Where(f => f != "malolactic").ToList();
        var answers = new JsonObject { ["aromas"] = new JsonArray(picked.Select(f => (JsonNode)JsonValue.Create(f)!).ToArray()) };
        var item = TastingMarker.Mark(Fixture.Data, wine, "sheet", answers).Items.First(i => i.Key == "aromas");
        var ev = TastingMarker.EventItem(item);
        var scores = ev["causeScores"]!.AsObject();
        Assert.Equal(0, (double)scores["mlf-diacetyl"]!);
        var other = wine.Sheet.CauseLinks.First(l => l.Line.StartsWith("aroma:") && l.Line != "aroma:malolactic").Cause;
        Assert.Equal(1, (double)scores[other]!);

        var rec = PracticeProgress.Apply(new JsonObject(), new JsonObject { ["kind"] = "practice", ["date"] = "2026-10-05", ["items"] = new JsonArray(ev) });
        var st = StudyRecord.States(rec);
        Assert.False(st["mlf-diacetyl"].History[^1].Right);
        Assert.True(st[other].History[^1].Right);
    }

    [Fact]
    public void UnansweredItem_LeavesItsCausesUntouched()
    {
        var ev = TastingMarker.EventItem(new MarkItem("acidity", "Acidity", "acidity", "", "high", 0, "", 0, "no-confidence", new[] { "cool-season-acid" }));
        Assert.Null(ev["causes"]);
        var rec = PracticeProgress.Apply(new JsonObject(), new JsonObject { ["kind"] = "practice", ["date"] = "2026-10-05", ["items"] = new JsonArray(ev) });
        Assert.Empty(StudyRecord.States(rec));
    }

    [Fact]
    public void Contrast_DecoysAreNeverRealDifferencesBetweenTheTwoGlasses()
    {
        var c = Cat.First(x => x.Id == "new-oak-vanilla-toast");
        int checkedPairs = 0;
        for (int seed = 1; seed <= 4; seed++)
        {
            if (PracticePours.ContrastFor(Fixture.Data, c, seed, null) is not { } pair) continue;
            var diff = pair.With.Sheet.Causes.ToHashSet(); diff.SymmetricExceptWith(pair.Without.Sheet.Causes);
            var decoys = PracticeSession.ContrastDecoys(Cat, c, pair.With, pair.Without, new Random(seed));
            Assert.Equal(3, decoys.Count);
            foreach (var d in decoys) Assert.DoesNotContain(Cat.First(x => x.Title == d).Id, diff);
            checkedPairs++;
        }
        Assert.True(checkedPairs > 0);
    }

    [Fact]
    public void GlassOfTheDay_IsTheSameForEveryone_EvenWithACauseDue()
    {
        var rec = PracticeProgress.Apply(new JsonObject(), new JsonObject
        {
            ["kind"] = "practice", ["date"] = Today.AddDays(-2).ToString("yyyy-MM-dd"),
            ["items"] = new JsonArray(new JsonObject { ["skill"] = "nose", ["score"] = 0, ["confidence"] = 2, ["causes"] = new JsonArray("new-oak-vanilla-toast") }),
        });
        var s = PracticeSession.Pour(Fixture.Data, JsonNode.Parse("""{"kind":"daily"}""")!.AsObject(), rec, Today, null);
        Assert.Null(s.Focus);
        Assert.Equal(PracticePours.Daily(Fixture.Data, Today), s.Specs[0]);
    }

    [Fact]
    public void WeeklyRhythm_CountsCausesReviewed_NotMarkedItems()
    {
        var items = new JsonArray();
        for (int i = 0; i < 15; i++) items.Add(new JsonObject { ["skill"] = "body", ["score"] = 1 });
        foreach (var id in new[] { "cool-season-acid", "sugar-to-alcohol", "mlf-softens-acid" })
            items.Add(new JsonObject { ["skill"] = "acidity", ["score"] = 1, ["causes"] = new JsonArray(id) });
        var rec = PracticeProgress.Apply(new JsonObject(), new JsonObject { ["kind"] = "practice", ["date"] = "2026-10-05", ["items"] = items });
        Assert.Equal(3, (int)rec["rhythm"]![0]!["n"]!);
    }

    [Fact]
    public void V1TasterRecord_KeepsBlindFlights_AfterRanksMoveToKnownCauses()
    {
        var v1 = new JsonObject { ["version"] = 1, ["xp"] = 2000 };
        Assert.True((bool)PracticeProgress.Summary(StudyRecord.Migrate(v1), Today, Cat)["blindUnlocked"]!);
        var fresh = new JsonObject { ["version"] = 2, ["xp"] = 2000, ["causes"] = new JsonObject() };
        Assert.False((bool)PracticeProgress.Summary(fresh, Today, Cat)["blindUnlocked"]!);
        var low = new JsonObject { ["version"] = 1, ["xp"] = 900 };
        Assert.False((bool)PracticeProgress.Summary(StudyRecord.Migrate(low), Today, Cat)["blindUnlocked"]!);
    }
}
