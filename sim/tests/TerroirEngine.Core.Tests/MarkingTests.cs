using System.Text.Json.Nodes;
using TerroirEngine.Tasting.Practice;

namespace TerroirEngine.Tests;

/// <summary>Tasting practice marking and progression (tasting-practice design §6, §6b).</summary>
public class MarkingTests
{
    private static readonly Lazy<PouredWine> Red = new(() => TastingLab.Pour(Fixture.Data, new PourSpec("cotedor-village", 2015, "A", "Pinot Noir", "classic"), 1));

    private static JsonObject Answers(params (string k, JsonNode? v)[] kv)
    {
        var o = new JsonObject();
        foreach (var (k, v) in kv) o[k] = v;
        return o;
    }

    private static string Palate(PouredWine p, string attr) => p.Sheet.Palate.First(x => x.Attribute == attr).Level.Split(',')[0];

    [Fact]
    public void OrderedScales_ExactOne_OneStepOffHalf_ElseZero()
    {
        var p = Red.Value;
        var scale = TastingMarker.Scale("acidity")!;
        int i = Array.IndexOf(scale, Palate(p, "Acidity"));
        string off1 = scale[i > 0 ? i - 1 : i + 1], off2 = scale[i > 1 ? i - 2 : i + 2];
        double Score(string v) => TastingMarker.Mark(Fixture.Data, p, "cause", Answers(("acidity", v))).Items.First(x => x.Key == "acidity").Score;
        Assert.Equal(1, Score(scale[i]));
        Assert.Equal(0.5, Score(off1));
        Assert.Equal(0, Score(off2));
    }

    [Fact]
    public void Categorical_OneOrZero_AndAromas_ByOverlap()
    {
        var p = Red.Value;
        var m = TastingMarker.Mark(Fixture.Data, p, "sheet", Answers(("colour", p.Sheet.Colour), ("development", p.Sheet.Development == "youthful" ? "tired" : "youthful")));
        Assert.Equal(1, m.Items.First(x => x.Key == "colour").Score);
        Assert.Equal(0, m.Items.First(x => x.Key == "development").Score);
        var fams = p.Sheet.Aromas.Select(a => a.Family).Distinct().ToList();
        Assert.True(fams.Count >= 2);
        // one right family and one wrong one: |∩| / |∪| = 1 / (fams + 1)
        var guess = new JsonArray(fams[0], "musty");
        double s = TastingMarker.Mark(Fixture.Data, p, "sheet", Answers(("aromas", guess))).Items.First(x => x.Key == "aromas").Score;
        Assert.Equal(Math.Round(1.0 / (fams.Count + 1), 2), s);
        var all = new JsonArray(fams.Select(f => (JsonNode)JsonValue.Create(f)!).ToArray());
        Assert.Equal(1, TastingMarker.Mark(Fixture.Data, p, "sheet", Answers(("aromas", all))).Items.First(x => x.Key == "aromas").Score);
    }

    [Fact]
    public void Mark_EmptyAnswers_ScoreZeroAndShowTheSheet()
    {
        foreach (var ex in TastingMarker.Exercises)
        {
            var m = TastingMarker.Mark(Fixture.Data, Red.Value, ex, new JsonObject());
            Assert.NotEmpty(m.Items);
            Assert.Equal(0, m.Total);
            Assert.All(m.Items, x => { Assert.Equal(0, x.Score); Assert.Equal("", x.Yours); Assert.False(string.IsNullOrEmpty(x.Actual), $"{ex}/{x.Key} has no answer"); });
        }
        // garbage types do not crash either
        var junk = JsonNode.Parse("""{"acidity": 7, "aromas": "oak", "blic": [1], "quality": null}""")!.AsObject();
        Assert.Equal(0, TastingMarker.Mark(Fixture.Data, Red.Value, "sheet", junk).Total);
    }

    [Fact]
    public void Tannin_IsAskedOnlyForReds_AndIdentifyKnowsTheVintageClimate()
    {
        var white = TastingLab.Pour(Fixture.Data, new PourSpec("mosel-seitental", 2018, Style: "dry"), 1);
        Assert.DoesNotContain(TastingMarker.Mark(Fixture.Data, white, "cause", new JsonObject()).Items, x => x.Key == "tannin");
        Assert.Contains(TastingMarker.Mark(Fixture.Data, Red.Value, "cause", new JsonObject()).Items, x => x.Key == "tannin");
        var id = TastingMarker.Mark(Fixture.Data, white, "identify", Answers(("variety", "Riesling"), ("region", "Mosel"), ("climate", "warm")));
        Assert.Equal(3, id.Total);   // 2018: the warmest year in the Mosel record
    }

    [Fact]
    public void Hints_CostHalfAMarkEach_NeverBelowZero()
    {
        var p = Red.Value;
        var full = TastingMarker.Mark(Fixture.Data, p, "cause", Answers(("acidity", Palate(p, "Acidity"))));
        var hinted = TastingMarker.Mark(Fixture.Data, p, "cause", Answers(("acidity", Palate(p, "Acidity")), ("hints", 1)));
        Assert.Equal(full.Total - 0.5, hinted.Total);
        Assert.Equal(0, TastingMarker.Mark(Fixture.Data, p, "cause", Answers(("hints", 9))).Total);
    }

    // ------------------------------------------------------------------------------------------------ progression

    private static JsonObject Stand(string id, double pct, string date = "2026-09-29") => new()
    {
        ["kind"] = "stand", ["stand"] = id, ["percent"] = pct, ["date"] = date,
        ["items"] = new JsonArray(new JsonObject { ["skill"] = "acidity", ["score"] = 1 }), ["cards"] = new JsonArray("cote-dor 2016"),
    };

    [Theory]
    [InlineData(49, null)]
    [InlineData(50, "bronze")]
    [InlineData(70, "silver")]
    [InlineData(85, "gold")]
    public void Medals_At50_70_85(double pct, string? medal) => Assert.Equal(medal, PracticeProgress.MedalFor(pct));

    [Fact]
    public void BestMedalIsKept_AndMedalsUnlockTiers()
    {
        var rec = PracticeProgress.Apply(new JsonObject(), Stand("frost-2016", 90));
        rec = PracticeProgress.Apply(rec, Stand("frost-2016", 55));
        var sum = PracticeProgress.Summary(rec);
        Assert.Equal("gold", sum["medals"]!["frost-2016"]!.GetValue<string>());
        Assert.Equal(1, sum["unlockedTier"]!.GetValue<int>());           // one medal opens tier 1
        rec = PracticeProgress.Apply(rec, Stand("mosel-ladder", 60));
        rec = PracticeProgress.Apply(rec, Stand("burgundy-2003-2005", 75));
        Assert.Equal(2, PracticeProgress.Summary(rec)["unlockedTier"]!.GetValue<int>());   // three medals open tier 2
        Assert.Contains("cote-dor 2016", PracticeProgress.Summary(rec)["cards"]!.AsArray().Select(c => c!.GetValue<string>()));
        Assert.Equal(0, PracticeProgress.Summary(new JsonObject())["unlockedTier"]!.GetValue<int>());
    }

    [Fact]
    public void XpClimbsTheRanks()
    {
        var rec = new JsonObject();
        Assert.Equal("Novice taster", PracticeProgress.Summary(rec)["rank"]!.GetValue<string>());
        var items = new JsonArray(Enumerable.Range(0, 20).Select(_ => (JsonNode)new JsonObject { ["skill"] = "body", ["score"] = 1 }).ToArray());
        for (int i = 0; i < 8; i++) rec = PracticeProgress.Apply(rec, new JsonObject { ["kind"] = "practice", ["date"] = "2026-09-29", ["items"] = items.DeepClone() });
        var s = PracticeProgress.Summary(rec);
        Assert.Equal(1600, s["xp"]!.GetValue<int>());
        Assert.Equal("Taster", s["rank"]!.GetValue<string>());
        Assert.True(s["blindUnlocked"]!.GetValue<bool>());
    }

    [Fact]
    public void DaysInARow_CountsConsecutiveDailyGlasses_ResetsAfterAGap_OnceADay()
    {
        JsonObject Daily(string d) => new() { ["kind"] = "daily", ["date"] = d, ["items"] = new JsonArray(new JsonObject { ["skill"] = "identify", ["score"] = 1 }) };
        var rec = new JsonObject();
        foreach (var d in new[] { "2026-09-27", "2026-09-28", "2026-09-29" }) rec = PracticeProgress.Apply(rec, Daily(d));
        int xp = PracticeProgress.Summary(rec)["xp"]!.GetValue<int>();
        rec = PracticeProgress.Apply(rec, Daily("2026-09-29"));      // a second glass the same day earns nothing more
        var s = PracticeProgress.Summary(rec, new DateOnly(2026, 9, 29));
        Assert.Equal(3, s["daysInARow"]!.GetValue<int>());
        Assert.Equal(xp, s["xp"]!.GetValue<int>());
        Assert.True(s["dailyDone"]!.GetValue<bool>());
        rec = PracticeProgress.Apply(rec, Daily("2026-10-02"));
        s = PracticeProgress.Summary(rec, new DateOnly(2026, 10, 2));
        Assert.Equal(1, s["daysInARow"]!.GetValue<int>());
        Assert.Equal(3, s["bestDaysInARow"]!.GetValue<int>());
        Assert.Equal("Novice taster", s["rank"]!.GetValue<string>());   // missing days never costs rank
    }

    [Fact]
    public void Progress_ToleratesMissingAndUnknownFields()
    {
        foreach (var text in new[] { "", "not json", "[]", "{\"xp\":\"lots\",\"medals\":[1,2],\"skills\":{\"acidity\":\"x\"},\"future\":{\"a\":1},\"daily\":7}", "{\"version\":99}" })
        {
            var rec = PracticeProgress.Load(text);
            var s = PracticeProgress.Summary(rec);
            Assert.Equal(0, s["xp"]!.GetValue<int>());
            rec = PracticeProgress.Apply(rec, Stand("frost-2016", 72));
            Assert.Equal("silver", PracticeProgress.Summary(rec)["medals"]!["frost-2016"]!.GetValue<string>());
        }
        var kept = PracticeProgress.Load("{\"xp\":40,\"future\":{\"a\":1}}");
        Assert.Equal(1, PracticeProgress.Apply(kept, Stand("x", 10))["future"]!["a"]!.GetValue<int>());   // unknown fields survive a save
        // a malformed event is ignored, not fatal
        Assert.Equal(40, PracticeProgress.Summary(PracticeProgress.Apply(kept, JsonNode.Parse("{\"items\":\"no\"}")!.AsObject()))["xp"]!.GetValue<int>());
    }

    [Fact]
    public void SkillHistory_KeepsTheLast20_AndAdaptivePracticeTargetsTheWeakestSkill()
    {
        var rec = new JsonObject();
        JsonObject Ev(string skill, double score) => new() { ["kind"] = "practice", ["date"] = "2026-09-29", ["items"] = new JsonArray(new JsonObject { ["skill"] = skill, ["score"] = score }) };
        for (int i = 0; i < 25; i++) rec = PracticeProgress.Apply(rec, Ev("acidity", i < 5 ? 0 : 1));
        for (int i = 0; i < 4; i++) rec = PracticeProgress.Apply(rec, Ev("tannin", 0.5));
        for (int i = 0; i < 4; i++) rec = PracticeProgress.Apply(rec, Ev("sweetness", 1));
        Assert.Equal(20, rec["skills"]!["acidity"]!.AsArray().Count);
        Assert.Equal("tannin", PracticeProgress.Weakest(rec));
        for (int seed = 1; seed <= 5; seed++)
        {
            var (spec, focus) = PracticePours.Suggest(Fixture.Data, rec, seed);
            Assert.Equal("tannin", focus);
            Assert.Contains(spec.Variety, new[] { "Pinot Noir", "Cabernet Sauvignon" });
        }
    }

    [Fact]
    public void GlassOfTheDay_IsTheSameAllDay_AndRespectsTheTimeline()
    {
        var a = PracticePours.Daily(Fixture.Data, new DateOnly(2026, 9, 29));
        Assert.Equal(a, PracticePours.Daily(Fixture.Data, new DateOnly(2026, 9, 29)));
        Assert.NotEqual(a, PracticePours.Daily(Fixture.Data, new DateOnly(2026, 9, 30)));
        for (int d = 0; d < 30; d++) Assert.True(PracticePours.Daily(Fixture.Data, new DateOnly(2026, 1, 1).AddDays(d), maxVintage: 2004).Vintage <= 2004);
    }
}
