using System.Text.Json.Nodes;
using TerroirEngine.Tasting.Practice;

namespace TerroirEngine.Tests;

/// <summary>The whole Tasting-practice loop the game's bridge drives: request → Flight → JSON for the screen → marking → record.</summary>
public class PracticeSessionTests
{
    private static readonly DateOnly Today = new(2026, 9, 29);
    private static JsonObject Req(string json) => JsonNode.Parse(json)!.AsObject();

    [Fact]
    public void Stand_PourMarkAndRecord_TheWholeLoop()
    {
        var s = PracticeSession.Pour(Fixture.Data, Req("""{"kind":"stand","stand":"frost-2016","seed":3}"""), new JsonObject(), Today, null);
        var json = s.Json(Fixture.Data);
        Assert.Equal(3, json["glasses"]!.AsArray().Count);
        Assert.All(json["quiz"]!.AsArray(), q => { Assert.Null(q!["answer"]); Assert.Null(q["evidence"]); });   // no answers before marking
        Assert.NotNull(json["glasses"]![0]!["options"]!["acidity"]);

        // answer each glass with its own sheet's acidity, and the frost question right
        var wines = new JsonArray();
        foreach (var g in s.Flight) wines.Add(new JsonObject { ["acidity"] = g.Sheet.Palate.First(p => p.Attribute == "Acidity").Level });
        var frostQ = s.Quiz.First(q => q.Topic == "frost");
        var answers = new JsonObject { ["wines"] = wines, ["quiz"] = new JsonObject { ["frost"] = frostQ.Answer } };
        var (result, rec) = s.Mark(Fixture.Data, answers, new JsonObject(), Today);
        Assert.Equal(3 + 1, result["total"]!.GetValue<double>());
        Assert.Contains(result["quiz"]!.AsArray(), q => q!["key"]!.GetValue<string>() == "quiz.frost" && q["score"]!.GetValue<double>() == 1);
        Assert.Contains("27 April", result["quiz"]!.AsArray().First(q => q!["key"]!.GetValue<string>() == "quiz.frost")!["because"]!.GetValue<string>());
        Assert.True(rec["xp"]!.GetValue<int>() > 0);
        Assert.Contains("cote-dor 2016", rec["cards"]!.AsArray().Select(c => c!.GetValue<string>()));
        Assert.NotNull(result["glasses"]![1]!["note"]);                           // the real 2016 note shows in the reveal
        Assert.Equal("Opens after the 2017 harvest.", FairStands.All(Fixture.Data, 2010).First(x => x.Id == "frost-2016").Blurb);
    }

    [Fact]
    public void Practice_EmptyAnswers_ScoreZero_ButStillRecordTheGlass()
    {
        var s = PracticeSession.Pour(Fixture.Data, Req("""{"kind":"practice","exercise":"cause","seed":5}"""), new JsonObject(), Today, null);
        Assert.Single(s.Flight);
        var (result, rec) = s.Mark(Fixture.Data, new JsonObject(), new JsonObject(), Today);
        Assert.Equal(0, result["total"]!.GetValue<double>());
        Assert.Equal(1, rec["stats"]!["glasses"]!.GetValue<int>());
        Assert.Null(result["medal"]);
    }

    [Fact]
    public void Daily_UsesIdentify_AndTheDatesWine()
    {
        var s = PracticeSession.Pour(Fixture.Data, Req("""{"kind":"daily"}"""), new JsonObject(), Today, null);
        Assert.Equal("identify", s.Exercise);
        Assert.Equal(PracticePours.Daily(Fixture.Data, Today), s.Specs[0]);
        var (_, rec) = s.Mark(Fixture.Data, new JsonObject(), new JsonObject(), Today);
        Assert.True(PracticeProgress.Summary(rec, Today)["dailyDone"]!.GetValue<bool>());
    }

    [Fact]
    public void InAGame_LockedStandsAndTooEarlyTimelinesAreRefused()
    {
        Assert.Throws<InvalidOperationException>(() => PracticeSession.Pour(Fixture.Data, Req("""{"kind":"stand","stand":"frost-2016"}"""), new JsonObject(), Today, 2010));
        Assert.Throws<InvalidOperationException>(() => PracticeSession.Pour(Fixture.Data, Req("""{"kind":"practice"}"""), new JsonObject(), Today, 1993));
        // a stand whose tier the medals have not opened is refused too
        Assert.Throws<InvalidOperationException>(() => PracticeSession.Pour(Fixture.Data, Req("""{"kind":"stand","stand":"mosel-2003"}"""), new JsonObject(), Today, null));
        Assert.Equal(2023, PracticeSession.MaxVintageFor(new DateOnly(2024, 11, 30)));
        Assert.Equal(2024, PracticeSession.MaxVintageFor(new DateOnly(2024, 12, 1)));
    }

    [Fact]
    public void Lobby_ListsStandsWithMedalsLocksAndTheRecord()
    {
        var rec = PracticeProgress.Apply(new JsonObject(), new JsonObject
        {
            ["kind"] = "stand", ["stand"] = "frost-2016", ["percent"] = 90, ["date"] = "2026-09-29", ["items"] = new JsonArray(), ["cards"] = new JsonArray("cote-dor 2016"),
        });
        var lobby = PracticeSession.Lobby(Fixture.Data, rec, Today, null);
        var stands = lobby["stands"]!.AsArray();
        Assert.Equal("gold", stands.First(x => x!["id"]!.GetValue<string>() == "frost-2016")!["medal"]!.GetValue<string>());
        Assert.False(stands.First(x => x!["id"]!.GetValue<string>() == "napa-cool-hot")!["tierLocked"]!.GetValue<bool>());   // one medal opens tier 1
        Assert.True(stands.First(x => x!["id"]!.GetValue<string>() == "mosel-2003")!["tierLocked"]!.GetValue<bool>());
        Assert.Single(lobby["cellarBook"]!["cards"]!.AsArray());
        var card = lobby["cellarBook"]!["cards"]![0]!;
        Assert.Equal(2016, card["year"]!.GetValue<int>());
        Assert.Contains("April", card["note"]!["note"]!.GetValue<string>());
        Assert.True(lobby["available"]!.GetValue<bool>());
    }
}
