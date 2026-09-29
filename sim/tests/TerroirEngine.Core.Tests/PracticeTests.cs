using TerroirEngine.Game;
using TerroirEngine.Tasting.Practice;

namespace TerroirEngine.Tests;

/// <summary>Tasting practice: Wines poured from real vintages by a scripted Estate (tasting-practice design §3).</summary>
public class PracticeTests
{
    [Fact]
    public void Pour_IsDeterministic()
    {
        var spec = new PourSpec("mosel-seitental", 2011);
        var a = PracticeJson.Poured(TastingLab.Pour(Fixture.Data, spec, 7)).ToJsonString();
        var b = PracticeJson.Poured(TastingLab.Pour(Fixture.Data, spec, 7)).ToJsonString();
        Assert.Equal(a, b);
    }

    [Theory]
    [InlineData("mosel-seitental", 2005, "Riesling")]
    [InlineData("cotedor-village", 2009, "Pinot Noir")]
    [InlineData("cotedor-village", 2014, "Chardonnay")]
    [InlineData("napa-bench", 2012, "Cabernet Sauvignon")]
    public void Pour_BottlesAWineWithASheet_OfTheAskedVarietyAndVintage(string plot, int vintage, string variety)
    {
        var p = TastingLab.Pour(Fixture.Data, new PourSpec(plot, vintage, Variety: variety), 3);
        Assert.NotNull(p.Sheet);
        Assert.Equal(vintage, p.Context.Vintage);
        Assert.Equal(variety, p.Context.Variety);
        Assert.NotEmpty(p.Sheet.Palate);
        Assert.False(string.IsNullOrEmpty(p.Sheet.Quality));
        Assert.True(p.Context.Gdd > 500, $"growing-degree days {p.Context.Gdd}");
        Assert.True(p.Context.HarvestOe > 50);
        Assert.False(string.IsNullOrEmpty(p.Context.Producer));
    }

    [Theory]
    [InlineData("cotedor-village", 2016)]
    [InlineData("cotedor-village", 2021)]
    [InlineData("mosel-seitental", 2010)]
    public void Pour_AlwaysBottles_AcrossRegionsAndHardVintages(string plot, int vintage)
    {
        for (int seed = 1; seed <= 3; seed++)
            Assert.NotNull(TastingLab.Pour(Fixture.Data, new PourSpec(plot, vintage), seed).Sheet);
    }

    [Fact]
    public void RipenessLadder_GivesKabinettSpatleseAuslese()
    {
        string Cat(string style) => TastingLab.Pour(Fixture.Data, new PourSpec("mosel-seitental", 2018, Style: style), 5).Wine.Legal!.Category;
        Assert.Equal(new[] { "Kabinett", "Spätlese", "Auslese" }, new[] { Cat("kabinett"), Cat("spatlese"), Cat("auslese") });
    }

    [Fact]
    public void Context_Carries2016FrostLoss()
    {
        var p16 = TastingLab.Pour(Fixture.Data, new PourSpec("cotedor-village", 2016, Variety: "Pinot Noir"), 2);
        var p15 = TastingLab.Pour(Fixture.Data, new PourSpec("cotedor-village", 2015, Variety: "Pinot Noir"), 2);
        Assert.True(p16.Context.FrostLossPct > p15.Context.FrostLossPct + 10, $"2016 {p16.Context.FrostLossPct} vs 2015 {p15.Context.FrostLossPct}");
    }

    [Fact]
    public void StylesDiffer_OakShowsOnTheNose()
    {
        var steel = TastingLab.Pour(Fixture.Data, new PourSpec("cotedor-village", 2014, Variety: "Chardonnay", Style: "steel"), 4);
        var oak = TastingLab.Pour(Fixture.Data, new PourSpec("cotedor-village", 2014, Variety: "Chardonnay", Style: "new-oak"), 4);
        Assert.DoesNotContain(steel.Sheet.Aromas, a => a.Family == "oak");
        Assert.Contains(oak.Sheet.Aromas, a => a.Family == "oak");
    }
}
