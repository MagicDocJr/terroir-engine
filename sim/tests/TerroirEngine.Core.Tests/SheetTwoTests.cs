using TerroirEngine.Tasting;
using TerroirEngine.Tasting.Practice;

namespace TerroirEngine.Tests;

/// <summary>Tasting sheet 2 (docs/superpowers/specs/2026-10-02-tasting-sheet-2-design.md §3): the sheet's lines as the
/// systematic approach to tasting has them.</summary>
public class SheetTwoTests
{
    private static readonly Dictionary<string, PouredWine> Cache = new();
    private static PouredWine Pour(string plot, int vintage, string variety, string style, int seed = 1)
    {
        var key = $"{plot}/{vintage}/{variety}/{style}/{seed}";
        lock (Cache)
            if (!Cache.TryGetValue(key, out var p)) Cache[key] = p = TastingLab.Pour(Fixture.Data, new PourSpec(plot, vintage, Variety: variety, Style: style), seed);
        return Cache[key];
    }

    private static readonly string[] WhiteFruit = { "green fruit", "citrus fruit", "stone fruit", "tropical fruit" };
    private static readonly string[] RedFruit = { "red fruit", "black fruit" };

    private static IEnumerable<PouredWine> Sample() => new[]
    {
        Pour("mosel-blauschiefer", 2018, "Riesling", "auslese"), Pour("mosel-blauschiefer", 2010, "Riesling", "dry"),
        Pour("napa-floor", 2019, "Cabernet Sauvignon", "classic"), Pour("cotedor-village", 2021, "Pinot Noir", "light"),
        Pour("cotedor-village", 2018, "Chardonnay", "steel"), Pour("napa-mountain", 2018, "Cabernet Sauvignon", "extracted"),
    };

    [Fact]
    public void Fruit_IsSplitIntoTheExamFamilies()
    {
        foreach (var p in Sample())
        {
            var fams = p.Sheet.Aromas.Select(a => a.Family).ToList();
            Assert.DoesNotContain("fruit", fams);
            Assert.DoesNotContain("red and black fruit", fams);
            Assert.Contains(fams, f => (p.Context.Red ? RedFruit : WhiteFruit).Contains(f));
            Assert.DoesNotContain(fams, f => (p.Context.Red ? WhiteFruit : RedFruit).Contains(f));
        }
        Assert.Contains("black fruit", Pour("napa-floor", 2019, "Cabernet Sauvignon", "classic").Sheet.Aromas.Select(a => a.Family));
        Assert.Contains("red fruit", Pour("cotedor-village", 2021, "Pinot Noir", "light").Sheet.Aromas.Select(a => a.Family));
    }

    [Fact]
    public void FruitRipeness_IsOnTheScale_AndFollowsTheHarvest()
    {
        foreach (var p in Sample()) Assert.Contains(p.Sheet.FruitRipeness, TastingSheet.FruitRipenessScale);
        Assert.NotEqual("unripe", Pour("mosel-blauschiefer", 2018, "Riesling", "auslese").Sheet.FruitRipeness);
        Assert.NotEqual("dried or cooked", Pour("mosel-blauschiefer", 2010, "Riesling", "dry").Sheet.FruitRipeness);
    }

    [Fact]
    public void Simple_OnlyWhenTheNoseHasFewPrimaryFamilies()
    {
        int simple = 0;
        for (int seed = 1; seed <= 24; seed++)
        {
            var s = TastingLab.Pour(Fixture.Data, PracticePours.Random(Fixture.Data, seed), seed).Sheet;
            bool allPrimary = s.Aromas.All(a => a.Category == "Primary");
            int nonFruit = s.Aromas.Select(a => a.Family).Where(f => !WhiteFruit.Contains(f) && !RedFruit.Contains(f)).Distinct().Count();
            Assert.Equal(allPrimary && nonFruit <= 1 && s.Faults.Count == 0, s.Simple);
            if (s.Simple) simple++;
        }
    }

    [Fact]
    public void Flavours_AreTheNoseFamiliesFeltOnThePalate()
    {
        foreach (var p in Sample())
        {
            var s = p.Sheet;
            Assert.NotEmpty(s.Flavours);
            Assert.All(s.Flavours, f => Assert.Contains(f, s.Aromas.Select(a => a.Family)));
            Assert.DoesNotContain("volatile", s.Flavours);
            Assert.DoesNotContain("reductive", s.Flavours);
        }
    }

    [Fact]
    public void Readiness_HasFourOptions_AndAFaultyWineHasNone()
    {
        for (int seed = 1; seed <= 24; seed++)
        {
            var s = TastingLab.Pour(Fixture.Data, PracticePours.Random(Fixture.Data, seed), seed).Sheet;
            if (s.Quality == "Faulty") Assert.Equal("", s.Readiness);
            else Assert.Contains(s.Readiness, TastingSheet.ReadinessOptions);
        }
        Assert.Equal(4, TastingSheet.ReadinessOptions.Length);
    }

    [Fact]
    public void OldLowStructureRed_IsTooOld_AndTired()
    {
        var s = Pour("cotedor-village", 2015, "Pinot Noir", "classic").Sheet;   // warm year: medium(−) acidity, medium tannin
        Assert.Equal("too old", s.Readiness);
        Assert.Equal("tired", s.Development);
    }

    [Fact]
    public void OldUnoakedWhite_IsPastItsBest_NotForAgeing()
    {
        var s = Pour("cotedor-village", 2017, "Chardonnay", "steel").Sheet;
        Assert.Contains(s.Readiness, new[] { "drink now, not for (further) ageing", "too old" });
    }

    [Fact]
    public void AgedStructuredWines_StillHavePotential()
    {
        Assert.Equal("can drink now, has potential for ageing", Pour("mosel-blauschiefer", 2018, "Riesling", "kabinett").Sheet.Readiness);
        Assert.Equal("can drink now, has potential for ageing", Pour("napa-mountain", 2018, "Cabernet Sauvignon", "extracted").Sheet.Readiness);
    }

    [Fact]
    public void YoungTannicRed_IsTooYoung()
    {
        var s = Pour("napa-mountain", 2024, "Cabernet Sauvignon", "extracted").Sheet;
        Assert.Equal("too young", s.Readiness);
    }

    [Fact]
    public void YoungWines_AreNeverTooOld()
    {
        foreach (var (plot, v, st) in new[] { ("cotedor-village", "Chardonnay", "steel"), ("mosel-blauschiefer", "Riesling", "dry"), ("cotedor-village", "Pinot Noir", "light") })
            Assert.NotEqual("too old", Pour(plot, 2025, v, st).Sheet.Readiness);
    }

    [Fact]
    public void Quality_IsAnArgument_ForAgainstAndWhyNotHigher()
    {
        foreach (var p in Sample())
        {
            var s = p.Sheet;
            if (s.Quality == "Faulty") continue;
            Assert.Equal(s.Blic.Count(b => b.Met), s.QualityFor.Count);
            Assert.Equal(s.Blic.Count(b => !b.Met), s.QualityAgainst.Count);
            if (s.Quality != "Outstanding") Assert.StartsWith("Not ", s.QualityNotHigher);
            Assert.Contains("For:", s.QualityBecause + " For:");
        }
    }

    [Fact]
    public void OldTannicRed_ShowsADeposit()
    {
        var s = Pour("napa-mountain", 2018, "Cabernet Sauvignon", "extracted").Sheet;
        Assert.Contains(s.Observations, o => o.Term == "deposit");
    }

    [Fact]
    public void Colours_IncludeBrown()
    {
        Assert.Contains("brown", TastingSheet.ColoursWhite);
        Assert.Contains("brown", TastingSheet.ColoursRed);
        Assert.Contains("tawny", TastingSheet.ColoursRed);
    }
}

/// <summary>The quality verdict spreads like a mixed line-up (Tasting sheet 2 spec §3.3; target bands UNVERIFIED, for the
/// Level 3 reviewer). Over 150 pours on 2026-10-02: Outstanding 13 %, Very good 24 %, Good 33 %, Acceptable 27 %, Poor 3 %.</summary>
public class QualitySpreadTests
{
    [Fact]
    public void Quality_SpreadsAcrossRandomPours()
    {
        var counts = new Dictionary<string, int>(); int n = 0;
        for (int seed = 1; seed <= 60; seed++)
        {
            var q = TastingLab.Pour(Fixture.Data, PracticePours.Random(Fixture.Data, seed), seed).Sheet.Quality;
            counts[q] = counts.GetValueOrDefault(q) + 1; n++;
        }
        double Share(string q) => counts.GetValueOrDefault(q) / (double)n;
        var report = string.Join(", ", counts.Select(kv => $"{kv.Key} {kv.Value}"));
        Assert.True(Share("Outstanding") <= 0.17, report);
        Assert.InRange(Share("Very good"), 0.15, 0.35);
        Assert.InRange(Share("Good"), 0.20, 0.42);
        Assert.InRange(Share("Acceptable"), 0.15, 0.38);
        Assert.True(Share("Very good") + Share("Outstanding") <= 0.45, report);
    }
}

/// <summary>The absolute climate class beside the game's relative one (Tasting sheet 2 spec §3.4; UW-2016 p. 30).</summary>
public class ClimateClassTests
{
    [Fact]
    public void Climate_AbsoluteClassBesideRelative()
    {
        var (mosel, moselGst) = VintageFacts.RegionClass(Fixture.Data, "mosel");
        var (napa, napaGst) = VintageFacts.RegionClass(Fixture.Data, "napa");
        Assert.Equal("cool", mosel);
        Assert.True(moselGst <= 16.5, $"{moselGst}");
        Assert.Contains(napa, new[] { "moderate", "warm" });
        Assert.True(napaGst > moselGst);
        var f = VintageFacts.For(Fixture.Data, "mosel", 2018);
        Assert.InRange(f.Gst, 12, 20);
        var (rel, because) = TastingMarker.VintageClimate(Fixture.Data, "mosel", 2018);
        Assert.Equal("warm", rel);   // 2018 was a hot year on the Mosel
        Assert.Contains("cool climate", because);
        var card = PracticeSession.CardJson(Fixture.Data, "mosel", 2018);
        Assert.Equal("cool", (string?)card["climateClass"]);
        Assert.Contains("warm year", (string?)card["climateLine"]);
    }
}
