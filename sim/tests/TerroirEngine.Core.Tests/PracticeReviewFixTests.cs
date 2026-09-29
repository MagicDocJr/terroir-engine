using System.Text.Json.Nodes;
using TerroirEngine.Tasting.Practice;

namespace TerroirEngine.Tests;

/// <summary>Findings from the final review of Tasting practice, pinned.</summary>
public class PracticeReviewFixTests
{
    private static readonly DateOnly Today = new(2026, 9, 29);

    [Fact]
    public void InAGame_RanksAndClimateUseOnlyTheKnowableRecord()
    {
        var f = VintageFacts.For(Fixture.Data, "mosel", 2003, upTo: 2004);
        Assert.Equal(10, f.RecordYears);
        Assert.Equal(2004, f.RecordTo);
        Assert.Equal("warm", TastingMarker.VintageClimate(Fixture.Data, "mosel", 1999, upTo: 2004).Climate);
        Assert.Contains("1995–2004", TastingMarker.VintageClimate(Fixture.Data, "mosel", 1999, upTo: 2004).Because);
        Assert.Equal(10, PracticeSession.CardJson(Fixture.Data, "mosel", 2003, upTo: 2004)["recordYears"]!.GetValue<int>());
        // a pour inside a 2005 game marks Identify against the record up to 2004
        var s = PracticeSession.Pour(Fixture.Data, JsonNode.Parse("""{"kind":"practice","exercise":"identify","seed":9}""")!.AsObject(), new JsonObject(), Today, 2004);
        var c = s.Flight[0].Context;
        var (result, _) = s.Mark(Fixture.Data, new JsonObject(), new JsonObject(), Today);
        var climate = result["glasses"]![0]!["items"]!.AsArray().First(i => i!["key"]!.GetValue<string>() == "climate")!;
        Assert.Equal(TastingMarker.VintageClimate(Fixture.Data, c.RegionId, c.Vintage, 2004).Climate, climate["actual"]!.GetValue<string>());
        Assert.DoesNotContain("2025", result.ToJsonString());
    }

    [Fact]
    public void RandomPours_SkipTheYearsTheSimDoesNotYetReproduce()
    {
        for (int seed = 1; seed <= 3000; seed++)
        {
            var p = PracticePours.Random(Fixture.Data, seed);
            var region = Fixture.Data.Plot(p.PlotId).Region.Id;
            Assert.False(PracticePours.Miscalibrated(region, p.Variety!, p.Vintage), $"seed {seed}: {region} {p.Variety} {p.Vintage}");
        }
        Assert.True(PracticePours.Miscalibrated("cote-dor", "Chardonnay", 2022));
        Assert.True(PracticePours.Miscalibrated("mosel", "Riesling", 2010));
    }

    [Fact]
    public void ReplayingAStand_PaysOnlyForImprovement()
    {
        JsonObject Ev(double pct) => new()
        {
            ["kind"] = "stand", ["stand"] = "frost-2016", ["percent"] = pct, ["date"] = "2026-09-29",
            ["items"] = new JsonArray(Enumerable.Range(0, 20).Select(i => (JsonNode)new JsonObject { ["skill"] = "acidity", ["score"] = i < pct / 5 ? 1 : 0 }).ToArray()),
        };
        var rec = PracticeProgress.Apply(new JsonObject(), Ev(60));
        int xp1 = rec["xp"]!.GetValue<int>();
        rec = PracticeProgress.Apply(rec, Ev(60));
        Assert.Equal(xp1, rec["xp"]!.GetValue<int>());                 // same score again: nothing
        Assert.Equal(0, PracticeProgress.Summary(rec)["lastGain"]!.GetValue<int>());
        rec = PracticeProgress.Apply(rec, Ev(80));
        Assert.True(rec["xp"]!.GetValue<int>() > xp1);                   // a better score: the improvement plus the better medal
        Assert.True(rec["xp"]!.GetValue<int>() - xp1 < 120);
    }

    [Fact]
    public void AnUnreadableRecord_IsReported_NotSilentlyUsed()
    {
        Assert.False(PracticeProgress.TryLoad("not json", out _));
        Assert.False(PracticeProgress.TryLoad("""{"xp":1,"xp":2}""", out var dup));
        Assert.Empty(dup);
        Assert.True(PracticeProgress.TryLoad("", out _));                 // no file yet is fine
        Assert.True(PracticeProgress.TryLoad("""{"xp":40}""", out var ok));
        Assert.Equal(40, PracticeProgress.Summary(ok)["xp"]!.GetValue<int>());
    }

    [Fact]
    public void InAnEarlyGame_TheFirstOpenTierIsTheOneWithStandsOnTheTimeline()
    {
        var lobby = PracticeSession.Lobby(Fixture.Data, new JsonObject(), Today, 2004);
        var stands = lobby["stands"]!.AsArray();
        var cw = stands.First(x => x!["id"]!.GetValue<string>() == "mosel-cool-warm")!;
        Assert.False(cw["locked"]!.GetValue<bool>());
        Assert.False(cw["tierLocked"]!.GetValue<bool>());                 // every tier-0 stand is still in the future
        PracticeSession.Pour(Fixture.Data, JsonNode.Parse("""{"kind":"stand","stand":"mosel-cool-warm","seed":1}""")!.AsObject(), new JsonObject(), Today, 2004);
    }
}
