using TerroirEngine.Data;
using TerroirEngine.Game;
using TerroirEngine.Tasting;
using TerroirEngine.Util;
using TerroirEngine.Vineyard;
using TerroirEngine.Weather;
using TerroirEngine.Winery;

namespace TerroirEngine.Tests;

public class MultiVintageLoopTests
{
    [Theory]
    [InlineData("mosel-seitental", 2014, 80)]
    [InlineData("cotedor-village", 2013, 95)]
    [InlineData("napa-carneros", 2016, 104)]
    public void ThreeVintages_BackToBack(string plot, int year, double target)
    {
        var g = Fixture.PlayVintages(plot, year, target, vintages: 3);
        for (int v = g.FirstVintage; v < g.FirstVintage + 3; v++)
        {
            Assert.True(g.IsVintageBottled(v), $"Vintage {v} is not in bottle");
            Assert.NotEmpty(g.WinesOf(v));
            Assert.All(g.Lots.Where(l => l.Vintage == v), l => Assert.StartsWith($"{v % 100:00}-", l.Id));
        }
        Assert.Single(g.Inbox, m => m.Kind == "finished");
        Assert.Equal(2, g.Inbox.Count(m => m.Kind == "vintage-bottled"));
        Assert.True(g.MentorRetired);
    }

    [Fact]
    public void SeasonalAlerts_FireOncePerYear()
    {
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 2);
        var budbursts = g.Inbox.Where(m => m.Kind == "budburst").Select(m => m.Date.Year).ToList();
        Assert.Equal(new[] { g.FirstVintage, g.FirstVintage + 1 }, budbursts.Take(2));
        Assert.Equal(budbursts.Count, budbursts.Distinct().Count());
        var windows = g.Inbox.Where(m => m.Kind == "harvest-window").GroupBy(m => (m.Date.Year, m.BlockId)).ToList();
        Assert.All(windows, grp => Assert.Single(grp));
        Assert.Contains(windows, grp => grp.Key.Year == g.FirstVintage + 1);
    }

    [Fact]
    public void SaveAndLoad_TwoVintagesIn_ReproducesTheSnapshot()
    {
        var g = Fixture.PlayVintages("mosel-terrassen", 2016, 86, vintages: 2);
        var g2 = GameSession.Load(Fixture.Data, g.Save());
        Assert.Equal(Snapshot.Json(g), Snapshot.Json(g2));
    }

    [Fact]
    public void ForcedHarvest_EveryVintage_WithoutPlayerInput()
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2014 });
        while (g.Date < new DateOnly(g.FirstVintage + 2, 1, 1)) g.Advance(60, stopAtAlerts: false);
        Assert.Contains(g.Lots, l => l.Vintage == g.FirstVintage);
        Assert.Contains(g.Lots, l => l.Vintage == g.FirstVintage + 1);
        var forced = g.Inbox.Where(m => m.Kind == "forced-harvest").ToList();
        Assert.Equal(forced.Count, forced.Select(m => (m.Date.Year, m.BlockId)).Distinct().Count());
    }

    [Fact]
    public void UnbottledVintage_DoesNotBlockTheNext()
    {
        // never bottle the first Vintage; bottle everything from the second
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2014 });
        int guard = 0;
        while (!g.IsVintageBottled(g.FirstVintage + 1) && guard++ < 800)
        {
            g.Advance(30);
            foreach (var b in g.Blocks.Where(b => !b.Harvested && !b.Picking && b.Veraison != null && (Chemistry.MustFromBlock(b).Oe >= 80 || b.LeafFall != null)))
                g.Apply(new Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Table" });
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Ready && l.Vintage > g.FirstVintage).ToList()) g.Apply(new Command { Type = "wine", A = lot.Id, E = lot.Id });
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Stuck).ToList()) g.Apply(new Command { Type = "restart", A = lot.Id });
        }
        Assert.True(g.IsVintageBottled(g.FirstVintage + 1));
        Assert.False(g.IsVintageBottled(g.FirstVintage));
        Assert.False(g.MentorRetired);   // the Mentor stays until the first Vintage is in bottle
    }
}
