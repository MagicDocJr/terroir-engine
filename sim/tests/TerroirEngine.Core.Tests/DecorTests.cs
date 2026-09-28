using TerroirEngine.Game;

namespace TerroirEngine.Tests;

/// <summary>Cosmetic Winery look (cozy-winery design §3): stored and replayed, never interpreted.</summary>
public class DecorTests
{
    private static GameSession New() => new(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2014 });

    [Fact]
    public void Decor_EmptyByDefault() => Assert.Empty(Snapshot.Build(New())["decor"]!.AsObject());

    [Fact]
    public void Decor_IsStored_AndReplays_AndChangesNothingElse()
    {
        var g = New();
        var before = Snapshot.Build(g); before.Remove("decor");
        g.Apply(new Command { Type = "decor", A = "walls", B = "brick" });
        var after = Snapshot.Build(g);
        Assert.Equal("brick", after["decor"]!["walls"]!.GetValue<string>());
        after.Remove("decor");
        Assert.Equal(before.ToJsonString(), after.ToJsonString());
        var g2 = GameSession.Load(Fixture.Data, g.Save());
        Assert.Equal("brick", Snapshot.Build(g2)["decor"]!["walls"]!.GetValue<string>());
    }

    [Fact]
    public void Decor_LaterChoiceWins_AndCostsNothing()
    {
        var g = New();
        double cash = g.Ledger.Cash;
        g.Apply(new Command { Type = "decor", A = "floor", B = "slate" });
        g.Apply(new Command { Type = "decor", A = "floor", B = "terracotta" });
        Assert.Equal("terracotta", Snapshot.Build(g)["decor"]!["floor"]!.GetValue<string>());
        Assert.Equal(cash, g.Ledger.Cash);
    }

    [Fact]
    public void Decor_UnknownKeys_AreStoredAndHarmless()
    {
        var g = New();
        g.Apply(new Command { Type = "decor", A = "hologram", B = "on" });
        Assert.Equal("on", Snapshot.Build(g)["decor"]!["hologram"]!.GetValue<string>());
        g.Apply(new Command { Type = "decor", A = "", B = "x" });   // no key: ignored
        Assert.Single(Snapshot.Build(g)["decor"]!.AsObject());
    }
}
