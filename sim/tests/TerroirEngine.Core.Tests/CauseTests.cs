using TerroirEngine.Learning;
using TerroirEngine.Tasting.Practice;

namespace TerroirEngine.Tests;

/// <summary>Causes: the catalogue and the tags the Tasting-sheet generator writes (learning-core design §3).</summary>
public class CauseTests
{
    [Fact]
    public void Catalogue_IsValid()
    {
        var all = CauseCatalog.All(Fixture.Data);
        Assert.True(all.Count >= 30, $"{all.Count} Causes");
        Assert.Equal(all.Count, all.Select(c => c.Id).Distinct().Count());
        foreach (var c in all)
        {
            Assert.InRange(c.Chain.Length, 2, 4);
            Assert.False(string.IsNullOrWhiteSpace(c.Title));
            Assert.False(string.IsNullOrWhiteSpace(c.Topic));
            Assert.NotEmpty(c.Sources);
            foreach (var s in c.Sources) Assert.True(CauseCatalog.SourceResolves(Fixture.Data, s), $"{c.Id}: source '{s}' not found");
            Assert.DoesNotContain("WSET", string.Join(" ", c.Chain) + c.Title + c.Topic);
        }
    }

    private static readonly PourSpec[] Varied =
    {
        new("mosel-seitental", 1996, Style: "dry"), new("mosel-seitental", 2018, Style: "auslese"), new("mosel-seitental", 2011, Style: "kabinett"),
        new("cotedor-village", 2016, Variety: "Pinot Noir"), new("cotedor-village", 2003, Variety: "Pinot Noir", Style: "extracted"),
        new("cotedor-village", 2017, Variety: "Chardonnay", Style: "new-oak"), new("cotedor-village", 2014, Variety: "Chardonnay", Style: "steel"),
        new("napa-bench", 2010, Variety: "Cabernet Sauvignon", Style: "light"), new("napa-bench", 2020, Variety: "Cabernet Sauvignon", Style: "extracted"),
        new("napa-bench", 2005, Variety: "Cabernet Sauvignon", Style: "rustic"),
    };

    [Fact]
    public void Tags_AllExistInCatalogue_AndAreDeterministic()
    {
        var ids = CauseCatalog.All(Fixture.Data).Select(c => c.Id).ToHashSet();
        foreach (var spec in Varied)
        {
            var a = TastingLab.Pour(Fixture.Data, spec, 2).Sheet;
            var b = TastingLab.Pour(Fixture.Data, spec, 2).Sheet;
            Assert.NotEmpty(a.CauseLinks);
            Assert.All(a.Causes, id => Assert.Contains(id, ids));
            Assert.Equal(a.CauseLinks, b.CauseLinks);
        }
    }

    [Fact]
    public void EveryCause_IsShownByItsReferencePour()
    {
        var missing = new List<string>();
        foreach (var c in CauseCatalog.All(Fixture.Data).Where(c => c.ReviewBy == "wine"))
        {
            bool shown = false;
            for (int seed = 1; seed <= 6 && !shown; seed++)
            {
                var spec = CausePours.Spec(Fixture.Data, c, seed, null);
                shown = TastingLab.Pour(Fixture.Data, spec, seed).Sheet.Causes.Contains(c.Id);
            }
            if (!shown) missing.Add(c.Id);
        }
        Assert.True(missing.Count == 0, "not shown by their reference pours: " + string.Join(", ", missing));
        Assert.All(CauseCatalog.All(Fixture.Data).Where(c => c.ReviewBy != "wine"), c => Assert.Equal("chain", c.ReviewBy));
    }

    [Fact]
    public void CoolSeason_TagsHighAcid_WarmSeason_TagsMalicLoss()
    {
        var cool = TastingLab.Pour(Fixture.Data, new PourSpec("mosel-seitental", 1996, Style: "dry"), 1).Sheet;
        var warm = TastingLab.Pour(Fixture.Data, new PourSpec("napa-bench", 2020, Variety: "Cabernet Sauvignon"), 1).Sheet;
        Assert.Contains(("cool-season-acid", "palate:Acidity"), cool.CauseLinks);
        Assert.Contains(("warm-season-malic-loss", "palate:Acidity"), warm.CauseLinks);
        Assert.Contains("sugar-to-alcohol", warm.Causes);
    }
}
