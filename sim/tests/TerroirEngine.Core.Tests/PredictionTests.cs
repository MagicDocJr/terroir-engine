using System.Text.Json.Nodes;
using TerroirEngine.Game;
using TerroirEngine.Learning;
using TerroirEngine.Winery;

namespace TerroirEngine.Tests;

/// <summary>Predict your own Wine before its Tasting sheet, and recall what your choices did (learning-core design §6).</summary>
public class PredictionTests
{
    private static readonly Lazy<GameSession> Game = new(() =>
    {
        return Fixture.Play("cotedor-village", 2012, 95);
    });

    private static GameSession Fresh()
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "cotedor-village", PlantingYear = 2012 });
        Predictions.Init(g);
        int guard = 0;
        while (g.Wines.Count == 0 && guard++ < 400)
        {
            g.Advance(30);
            foreach (var b in g.Blocks.Where(b => !b.Harvested && !b.Picking && b.Veraison != null))
                if (Chemistry.MustFromBlock(b).Oe >= 95 || b.LeafFall != null) g.Apply(new Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Table" });
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Received).ToList())
            {
                g.Apply(new Command { Type = "lot", A = lot.Id, B = "MLF", C = "0" });       // MLF blocked
                g.Apply(new Command { Type = "lot", A = lot.Id, B = "Vessel", C = "4" });    // new French barriques
            }
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Ready).ToList()) g.Apply(new Command { Type = "wine", A = lot.Id, E = lot.Id });
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Stuck).ToList()) g.Apply(new Command { Type = "restart", A = lot.Id });
        }
        return g;
    }

    private static readonly Lazy<GameSession> Mine = new(Fresh);

    [Fact]
    public void Predictions_FourItems_MarkedAgainstTheSheet()
    {
        var g = Mine.Value;
        var w = g.Wines[0];
        Assert.False(Predictions.IsRevealed(g, w.Id));
        var p = Predictions.For(g, w.Id);
        var items = p["items"]!.AsArray();
        Assert.Equal(4, items.Count);
        Assert.DoesNotContain("because", p.ToJsonString());   // nothing given away before the reveal
        // answer with the sheet's own acidity, sure
        var acid = w.Sheet!.Palate.First(l => l.Attribute == "Acidity").Level.Split(',')[0];
        var answers = new JsonObject
        {
            ["items"] = new JsonObject { ["acidity"] = acid }, ["confidence"] = new JsonObject { ["acidity"] = 3 },
        };
        var (result, events) = Predictions.Mark(g, w.Id, answers);
        var a = result["items"]!.AsArray().First(i => i!["key"]!.GetValue<string>() == "acidity")!;
        Assert.Equal(1, a["score"]!.GetValue<double>());
        Assert.Equal("sure-right", a["case"]!.GetValue<string>());
        Assert.False(string.IsNullOrEmpty(a["because"]!.GetValue<string>()));
        Assert.NotEmpty(events);
        Assert.All(events, e => Assert.NotNull(e["skill"]));
    }

    [Fact]
    public void ChoiceRecall_PicksThePlayersRealChoices()
    {
        var g = Mine.Value;
        var w = g.Wines.First(x => x.Sheet!.Causes.Contains("new-oak-vanilla-toast"));
        var recall = Predictions.For(g, w.Id)["recall"]!.AsArray();
        Assert.InRange(recall.Count, 1, 2);
        Assert.Contains(recall, r => r!["choice"]!.GetValue<string>().Contains("New French barriques"));
        var (result, events) = Predictions.Mark(g, w.Id, new JsonObject());
        Assert.Contains(events, e => e["causes"]!.AsArray().Any(c => c!.GetValue<string>() == "new-oak-vanilla-toast"));
    }

    [Fact]
    public void Predictions_NeverChangeTheWine()
    {
        var g = Mine.Value;
        var w = g.Wines[0];
        var before = Snapshot.WineObj(w).ToJsonString();
        Predictions.Mark(g, w.Id, new JsonObject { ["items"] = new JsonObject { ["acidity"] = "low", ["quality"] = "Poor" } });
        Assert.Equal(before, Snapshot.WineObj(w).ToJsonString());
    }

    [Fact]
    public void Predictions_OldWinesRevealed_BlendsUseBlendSheet()
    {
        // a game from before this release: no predict_v1 flag; Init counts its Wines as revealed
        var old = Game.Value;
        Assert.False(old.Flags.Contains(Predictions.InitFlag));
        Predictions.Init(old);
        Assert.All(old.Wines, w => Assert.True(Predictions.IsRevealed(old, w.Id)));
        Assert.True(old.Flags.Contains(Predictions.InitFlag));
        // the prediction reads the Wine's own (blend) sheet
        var g = Mine.Value; var w = g.Wines[0];
        var q = Predictions.For(g, w.Id)["items"]!.AsArray().First(i => i!["key"]!.GetValue<string>() == "alcohol")!;
        Assert.Contains(w.Sheet!.Palate.First(l => l.Attribute == "Alcohol").Level, q["options"]!.AsArray().Select(o => o!.GetValue<string>()));
        // an unknown Wine id is not a crash
        Assert.Null(Predictions.ForOrNull(g, "no-such-wine"));
    }
}
