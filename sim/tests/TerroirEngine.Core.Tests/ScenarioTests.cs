using System.Text.Json.Nodes;
using TerroirEngine.Game;
using TerroirEngine.Learning;
using TerroirEngine.Winery;

namespace TerroirEngine.Tests;

/// <summary>Famous vintages (docs/superpowers/specs/2026-10-03-famous-vintages-design.md).</summary>
public class ScenarioTests
{
    /// <summary>Scripted player for a scenario: harvest every Block at a target must weight, apply cellar choices, bottle each
    /// Lot on its own, until the scenario vintage is in bottle (or a later one, with extraVintages).</summary>
    public static GameSession Play(string id, double targetOe, Dictionary<string, int>? choices = null, int extraVintages = 0)
    {
        var g = new GameSession(Fixture.Data, Scenarios.Setup(Fixture.Data, id));
        Scenarios.Autoplay(g, targetOe, choices, g.FirstVintage + extraVintages);
        return g;
    }

    private static readonly Lazy<GameSession> Mosel = new(() => Play("mosel-2018", 80));

    [Fact]
    public void Catalog_ThreeScenarios_PassTheValidator()
    {
        var all = Scenarios.Catalog(Fixture.Data);
        Assert.Equal(new[] { "cotedor-2016", "mosel-2018", "napa-2011" }, all.Select(s => s.Id));
        foreach (var s in all) Assert.Empty(Scenarios.Problems(Fixture.Data, s));
    }

    [Fact]
    public void Setup_OpensOnJanuary15_WithEstablishedVines()
    {
        var g = new GameSession(Fixture.Data, Scenarios.Setup(Fixture.Data, "cotedor-2016"));
        Assert.Equal(new DateOnly(2016, 1, 15), g.Date);
        Assert.Equal(GamePhase.Running, g.Phase);
        Assert.Equal("cotedor-2016", g.Setup.ScenarioId);
    }

    [Fact]
    public void Briefings_DoNotLeakTheYear()
    {
        var s = Scenarios.Catalog(Fixture.Data)[0];
        foreach (var leak in new[] { "a late frost", "the heat", "a hot summer", "wildfire", "smoke", "an earthquake", "heavy rain", "on 26 April", "in September" })
            Assert.NotEmpty(Scenarios.Problems(Fixture.Data, s with { Briefing = s.Briefing + " Expect " + leak + "." }));
        Assert.NotEmpty(Scenarios.Problems(Fixture.Data, s with { Teaser = "the frost year" }));
    }

    [Fact]
    public void Status_BeforeBottling_ShowsGoalsUnjudged()
    {
        var g = new GameSession(Fixture.Data, Scenarios.Setup(Fixture.Data, "napa-2011"));
        var st = Scenarios.Status(g);
        Assert.False((bool)st["judged"]!);
        Assert.Equal(3, st["goals"]!.AsArray().Count);
        Assert.All(st["goals"]!.AsArray(), m => Assert.NotEmpty(m!["criteria"]!.AsArray()));
        Assert.Null(st["debrief"]);
    }

    [Fact]
    public void Evaluate_BestWineOfTheVintage()
    {
        var g = Mosel.Value;
        var ev = Scenarios.Evaluate(g);
        Assert.True((bool)ev["judged"]!);
        Assert.Contains((string)ev["medal"]!, new[] { "bronze", "silver", "gold" });
        Assert.Contains("2018", (string)ev["wine"]!["vintage"]!.ToString());
        var st = Scenarios.Status(g);
        Assert.NotNull(st["debrief"]);
        Assert.NotEmpty(st["debrief"]!["causes"]!.AsArray());
    }

    [Fact]
    public void LaterVintages_DoNotChangeTheMedal()
    {
        var g = Play("mosel-2018", 80, extraVintages: 1);
        var once = Scenarios.Evaluate(Mosel.Value);
        var later = Scenarios.Evaluate(g);
        Assert.Equal((string?)once["medal"], (string?)later["medal"]);
        Assert.Equal((string?)once["wine"]!["name"], (string?)later["wine"]!["name"]);
    }

    [Fact]
    public void OldSave_NoScenario()
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-blauschiefer", PlantingYear = 2014 });
        var loaded = GameSession.Load(Fixture.Data, g.Save().Replace("\"ScenarioId\": null,", ""));
        Assert.Null(Scenarios.Status(loaded)["scenario"]);
        var sc = new GameSession(Fixture.Data, Scenarios.Setup(Fixture.Data, "mosel-2018"));
        Assert.Equal("mosel-2018", GameSession.Load(Fixture.Data, sc.Save()).Setup.ScenarioId);
    }

    [Fact]
    public void RecordMedal_KeepsTheBest()
    {
        var rec = Scenarios.RecordMedal(new JsonObject(), "napa-2011", "silver");
        rec = Scenarios.RecordMedal(rec, "napa-2011", "bronze");
        Assert.Equal("silver", (string?)rec["scenarios"]!["napa-2011"]);
        rec = Scenarios.RecordMedal(rec, "napa-2011", "gold");
        Assert.Equal("gold", (string?)rec["scenarios"]!["napa-2011"]);
    }

    [Fact]
    public void Enqueue_AddsCausesWithoutHistory()
    {
        var today = new DateOnly(2026, 10, 3);
        var rec = StudyRecord.Enqueue(new JsonObject(), new[] { "spring-frost-yield", "not-a-cause" }, today, Fixture.Data);
        var st = StudyRecord.States(rec);
        Assert.True(st.ContainsKey("spring-frost-yield"));
        Assert.False(st.ContainsKey("not-a-cause"));
        Assert.Empty(st["spring-frost-yield"].History);
        Assert.Equal(today.AddDays(1), st["spring-frost-yield"].Due);
    }
}

/// <summary>Fixes from the famous-vintages final review.</summary>
public class ScenarioReviewFixTests
{
    private static readonly Lazy<GameSession> CoteDor = new(() => ScenarioTests.Play("cotedor-2016", 94));

    [Fact]
    public void ApplyToRecord_QueuesTheCauses_EvenWithoutAMedal()
    {
        var status = new System.Text.Json.Nodes.JsonObject
        {
            ["judged"] = true, ["scenario"] = new System.Text.Json.Nodes.JsonObject { ["id"] = "cotedor-2016" },
            ["evaluation"] = new System.Text.Json.Nodes.JsonObject { ["medal"] = null },
            ["debrief"] = new System.Text.Json.Nodes.JsonObject { ["causes"] = new System.Text.Json.Nodes.JsonArray(new System.Text.Json.Nodes.JsonObject { ["id"] = "spring-frost-yield" }) },
        };
        var rec = Scenarios.ApplyToRecord(new System.Text.Json.Nodes.JsonObject(), status, new DateOnly(2026, 10, 3), Fixture.Data);
        Assert.True(StudyRecord.States(rec).ContainsKey("spring-frost-yield"));
        Assert.Null(rec["scenarios"]?["cotedor-2016"]);
    }

    [Fact]
    public void MissedCriterion_ShowsWhatTheWineHad()
    {
        var ev = Scenarios.Evaluate(CoteDor.Value);
        var silver = ev["medals"]!.AsArray().First(m => (string)m!["name"]! == "silver")!;
        foreach (var c in silver["criteria"]!.AsArray().Where(c => !(bool)c!["met"]!))
            Assert.NotEqual("", (string)c!["evidence"]!);
    }

    [Fact]
    public void Evidence_IsShownOnAMiss_EvenWhenTheCriterionTextContainsIt()
    {
        Assert.Equal("acidity medium", Scenarios.EvidenceShown("acidity medium(+) or higher", false, "acidity medium"));
        Assert.Equal("", Scenarios.EvidenceShown("balanced", true, "balanced"));
    }

    [Fact]
    public void Evaluate_JudgesOnlyTheScenarioGrape_AndPicksTheBestWine()
    {
        var g = CoteDor.Value;
        Assert.Contains(g.Wines, w => w.Vintage == 2016 && w.Blend.VarietyName == "Chardonnay");   // the Plot grows both
        var ev = Scenarios.Evaluate(g);
        var judged = g.Wines.First(w => w.Id == (string)ev["wine"]!["id"]!);
        Assert.Equal("Pinot Noir", judged.Blend.VarietyName);
        string[] q = { "Faulty", "Poor", "Acceptable", "Good", "Very good", "Outstanding" };
        int best = g.Wines.Where(w => w.Vintage == 2016 && w.Blend.VarietyName == "Pinot Noir").Max(w => Array.IndexOf(q, w.Sheet!.Quality));
        Assert.Equal(best, Array.IndexOf(q, judged.Sheet!.Quality));
    }
}
