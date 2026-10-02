using System.Text.Json.Nodes;
using TerroirEngine.Learning;
using TerroirEngine.Tasting.Practice;

namespace TerroirEngine.Tests;

/// <summary>Mixed review sessions, review pours, Confidence and the question forms (learning-core design §4.4–4.6, §5).</summary>
public class SessionTests
{
    private static readonly DateOnly Today = new(2026, 10, 5);
    private static IReadOnlyList<Cause> Cat => CauseCatalog.All(Fixture.Data);

    private static JsonObject RecordWith(params (string id, int daysAgo, bool right)[] answers)
    {
        var rec = new JsonObject();
        foreach (var (id, ago, right) in answers.OrderByDescending(a => a.daysAgo))
            rec = PracticeProgress.Apply(rec, new JsonObject
            {
                ["kind"] = "practice", ["date"] = Today.AddDays(-ago).ToString("yyyy-MM-dd"),
                ["items"] = new JsonArray(new JsonObject { ["skill"] = "acidity", ["score"] = right ? 1 : 0, ["confidence"] = 2, ["causes"] = new JsonArray(id) }),
            });
        return rec;
    }

    [Fact]
    public void Session_MixesDueWeakNew_AndNeverRepeatsACause()
    {
        var rec = RecordWith(("cool-season-acid", 2, false), ("warm-season-malic-loss", 3, false), ("mlf-softens-acid", 5, false), ("sugar-to-alcohol", 4, false));
        var items = SessionComposer.Compose(Fixture.Data, rec, Today, null, 6, 1);
        Assert.Equal(6, items.Count);
        Assert.Equal(items.Count, items.Select(i => i.Cause).Distinct().Count());
        int due = items.Count(i => i.Reason == "due"), fresh = items.Count(i => i.Reason == "new");
        Assert.InRange(due, 3, 4);
        Assert.True(fresh >= 1);
        Assert.Contains(items, i => i.Reason == "weak" || i.Reason == "new");
    }

    [Fact]
    public void NewCause_StartsAsAChainWithOneBlank_MatureCauseIsAWine()
    {
        var items = SessionComposer.Compose(Fixture.Data, new JsonObject(), Today, null, 6, 2);
        Assert.All(items.Where(i => i.Reason == "new"), i => { Assert.Equal("chain", i.Kind); Assert.Equal(1, i.Blanks); });
        var mature = RecordWith(("cool-season-acid", 30, true), ("cool-season-acid", 20, true), ("cool-season-acid", 5, true));
        var it = SessionComposer.Compose(Fixture.Data, mature, Today.AddDays(40), null, 6, 3).First(i => i.Cause == "cool-season-acid");
        Assert.Contains(it.Kind, new[] { "wine", "contrast" });
    }

    [Fact]
    public void ChainFillIn_FadesWithStep_AndHasPlausibleDecoys()
    {
        var c = CauseCatalog.Get(Fixture.Data, "mlf-softens-acid");
        var q1 = ChainQuestion.For(c, 1, 7, Cat);
        var q2 = ChainQuestion.For(c, 2, 7, Cat);
        Assert.Single(q1.Blanks);
        Assert.Equal(2, q2.Blanks.Count);
        foreach (var b in q2.Blanks)
        {
            Assert.Contains(c.Chain[b.Index], b.Options);
            Assert.InRange(b.Options.Count, 3, 4);
            Assert.Equal(b.Options.Count, b.Options.Distinct().Count());
        }
        Assert.Equal(q1.Blanks[0].Index, ChainQuestion.For(c, 1, 7, Cat).Blanks[0].Index);   // deterministic
    }

    [Fact]
    public void ReviewPour_ShowsTheCause_WithANewWineEachTime()
    {
        var c = CauseCatalog.Get(Fixture.Data, "new-oak-vanilla-toast");
        var a = PracticePours.ForCause(Fixture.Data, c, 1, null);
        var b = PracticePours.ForCause(Fixture.Data, c, 2, null);
        Assert.NotNull(a); Assert.NotNull(b);
        Assert.Contains(c.Id, a!.Sheet.Causes);
        Assert.Contains(c.Id, b!.Sheet.Causes);
        Assert.False(a.Context.Vintage == b.Context.Vintage && a.Context.PlotId == b.Context.PlotId && a.Context.Producer == b.Context.Producer);
    }

    [Fact]
    public void DueCause_WithoutAShowingWine_FallsBackToChainFillIn()
    {
        // an early game (only 1995–1997 harvested) cannot pour a Wine for most Causes' vintage classes or styles reliably;
        // a chain-only Cause can never be poured: both come back as chain items, never an empty session
        var rec = RecordWith(("brett", 3, false), ("noble-rot", 3, false));
        var s = PracticeSession.Pour(Fixture.Data, JsonNode.Parse("""{"kind":"session","seed":4}""")!.AsObject(), rec, Today, 1997);
        Assert.NotEmpty(s.Entries);
        Assert.All(s.Entries.Where(e => e.Cause is "brett" or "noble-rot"), e => Assert.Equal("chain", e.Kind));
        Assert.All(s.Entries.Where(e => e.Kind != "chain"), e => Assert.True(e.Wine!.Context.Vintage <= 1997));
    }

    [Fact]
    public void ContrastPair_DiffersInTheCause()
    {
        var c = CauseCatalog.Get(Fixture.Data, "new-oak-vanilla-toast");
        var pair = PracticePours.ContrastFor(Fixture.Data, c, 3, null);
        Assert.NotNull(pair);
        Assert.Contains(c.Id, pair!.Value.With.Sheet.Causes);
        Assert.DoesNotContain(c.Id, pair.Value.Without.Sheet.Causes);
        Assert.Equal(pair.Value.With.Context.PlotId, pair.Value.Without.Context.PlotId);
    }

    [Fact]
    public void Session_MarksWithConfidence_FourCases_AndUpdatesTheQueue()
    {
        var s = PracticeSession.Pour(Fixture.Data, JsonNode.Parse("""{"kind":"session","seed":5}""")!.AsObject(), new JsonObject(), Today, null);
        var json = s.Json(Fixture.Data);
        var entries = json["entries"]!.AsArray();
        Assert.NotEmpty(entries);
        // answer every question with its first option, sure
        var answers = new JsonObject { ["entries"] = new JsonArray(entries.Select(e => (JsonNode)new JsonObject
        {
            ["answers"] = new JsonArray(e!["questions"]!.AsArray().Select(q => (JsonNode)JsonValue.Create(q!["options"]![0]!.GetValue<string>())!).ToArray()),
            ["confidence"] = new JsonArray(e["questions"]!.AsArray().Select(_ => (JsonNode)JsonValue.Create(3)!).ToArray()),
        }).ToArray()) };
        var (result, rec) = s.Mark(Fixture.Data, answers, new JsonObject(), Today);
        var items = result["entries"]!.AsArray().SelectMany(e => e!["items"]!.AsArray()).ToList();
        Assert.All(items, i => Assert.Contains(i!["case"]!.GetValue<string>(), new[] { "sure-right", "sure-wrong" }));
        Assert.All(items, i => Assert.False(string.IsNullOrEmpty(i!["because"]!.GetValue<string>())));   // explained, right or wrong
        var states = StudyRecord.States(rec);
        Assert.All(s.Entries, e => Assert.True(states.ContainsKey(e.Cause), e.Cause));
        Assert.All(states.Values, st => Assert.True(st.Due > Today));
    }

    [Fact]
    public void Exercises_FeedTheQueue_FromTheSheetsCauseTags()
    {
        var s = PracticeSession.Pour(Fixture.Data, JsonNode.Parse("""{"kind":"practice","exercise":"cause","seed":6}""")!.AsObject(), new JsonObject(), Today, null);
        var acid = s.Flight[0].Sheet.Palate.First(p => p.Attribute == "Acidity").Level;
        var answers = new JsonObject { ["wines"] = new JsonArray(new JsonObject { ["acidity"] = acid, ["confidence"] = new JsonObject { ["acidity"] = 1 } }) };
        var (result, rec) = s.Mark(Fixture.Data, answers, new JsonObject(), Today);
        var item = result["glasses"]![0]!["items"]!.AsArray().First(i => i!["key"]!.GetValue<string>() == "acidity")!;
        Assert.Equal("guess-right", item["case"]!.GetValue<string>());
        var acidCauses = s.Flight[0].Sheet.CauseLinks.Where(l => l.Line == "palate:Acidity").Select(l => l.Cause).ToList();
        Assert.NotEmpty(acidCauses);
        Assert.All(acidCauses, id => Assert.True(StudyRecord.States(rec).ContainsKey(id)));
    }

    [Fact]
    public void BeforeMarking_TheScreenGetsOnlyWhatItMayShow()
    {
        var stand = PracticeSession.Pour(Fixture.Data, JsonNode.Parse("""{"kind":"stand","stand":"mosel-ladder","seed":2}""")!.AsObject(), new JsonObject(), Today, null);
        var text = stand.Json(Fixture.Data)["glasses"]!.ToJsonString();
        foreach (var leak in new[] { "Auslese", "Spätlese", "Kabinett", "Weingut Brandt", "qualityBecause", "\"because\"" })
            Assert.DoesNotContain(leak, text);
        var (result, _) = stand.Mark(Fixture.Data, new JsonObject(), new JsonObject(), Today);
        Assert.Contains("Auslese", result.ToJsonString());   // the reveal carries the full Wine
        var conc = PracticeSession.Pour(Fixture.Data, JsonNode.Parse("""{"kind":"practice","exercise":"conclusions","seed":3}""")!.AsObject(), new JsonObject(), Today, null);
        var g = conc.Json(Fixture.Data)["glasses"]![0]!["wine"]!;
        Assert.Null(g["sheet"]!["quality"]);
        Assert.Null(g["sheet"]!["readiness"]);
        Assert.Null(g["sheet"]!["blic"]);
        var id = PracticeSession.Pour(Fixture.Data, JsonNode.Parse("""{"kind":"practice","exercise":"identify","seed":3}""")!.AsObject(), new JsonObject(), Today, null);
        Assert.Null(id.Json(Fixture.Data)["glasses"]![0]!["wine"]!["context"]);
    }

    [Fact]
    public void GlassOfTheDay_ShowsADueCause()
    {
        var rec = RecordWith(("new-oak-vanilla-toast", 2, false));
        var s = PracticeSession.Pour(Fixture.Data, JsonNode.Parse("""{"kind":"daily"}""")!.AsObject(), rec, Today, null);
        Assert.Equal("identify", s.Exercise);
        Assert.Contains("new-oak-vanilla-toast", s.Flight[0].Sheet.Causes);
        var plain = PracticeSession.Pour(Fixture.Data, JsonNode.Parse("""{"kind":"daily"}""")!.AsObject(), new JsonObject(), Today, null);
        Assert.Equal(PracticePours.Daily(Fixture.Data, Today), plain.Specs[0]);
    }
}
