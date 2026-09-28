using TerroirEngine.Data;
using TerroirEngine.Game;
using TerroirEngine.Tasting;
using TerroirEngine.Util;
using TerroirEngine.Vineyard;
using TerroirEngine.Weather;
using TerroirEngine.Winery;

namespace TerroirEngine.Tests;

public static class Fixture
{
    private static GameData? _data;
    public static GameData Data => _data ??= new GameData(GameData.LocateDataRoot(AppContext.BaseDirectory));

    /// <summary>Scripted player over several Vintages: harvest at a target, default cellar choices, bottle each Lot on its own,
    /// until the last requested Vintage is in bottle.</summary>
    public static GameSession PlayVintages(string plotId, int plantingYear, double targetOe, int vintages, Action<GameSession>? onStart = null)
    {
        var g = new GameSession(Data, new GameSetup { PlotId = plotId, PlantingYear = plantingYear });
        onStart?.Invoke(g);
        int last = g.FirstVintage + vintages - 1, guard = 0;
        while (!g.IsVintageBottled(last) && guard++ < 400 * vintages)
        {
            g.Advance(30);
            if (g.Vintage <= last)
                foreach (var b in g.Blocks.Where(b => !b.Harvested && !b.Picking && b.Veraison != null))
                    if (Chemistry.MustFromBlock(b).Oe >= targetOe || b.LeafFall != null) g.Apply(new Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Table" });
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Ready).ToList()) g.Apply(new Command { Type = "wine", A = lot.Id, E = lot.Id });
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Stuck).ToList()) g.Apply(new Command { Type = "restart", A = lot.Id });
        }
        return g;
    }

    /// <summary>Scripted player for the first Vintage only.</summary>
    public static GameSession Play(string plotId, int plantingYear, double targetOe, Action<GameSession>? onStart = null) => PlayVintages(plotId, plantingYear, targetOe, 1, onStart);
}

public class UnitConversionTests
{
    [Theory]
    [InlineData(80, 19.3)]
    [InlineData(100, 23.8)]
    public void OechsleToBrix_MatchesRuleOfThumb(double oe, double brix) => Assert.InRange(Units.BrixFromOe(oe), brix - 0.3, brix + 0.3);

    [Fact] public void EuPotentialAlcohol_Uses16_83() => Assert.Equal(10.0, Units.PotentialAlcohol(168.3), 3);

    [Fact] public void Must88Oe_FermentsToAbout12Percent()
    {
        double sugar = Units.SugarFromOe(88);
        Assert.InRange(Units.PotentialAlcohol(sugar), 11.8, 12.8);   // fermentation.md calibration check
    }
}

public class ChemistryTests
{
    [Fact]
    public void MolecularSo2_AtPh35_Free40_IsAbout08() => Assert.InRange(Chemistry.MolecularSo2(40, 3.5), 0.75, 0.85);   // AWRI worked example

    [Fact]
    public void MorePotassium_RaisesPh()
    {
        var a = new AcidComposition { Tartaric = 6, Malic = 4, PotassiumGL = 1.0 };
        var b = a with { PotassiumGL = 2.0 };
        Assert.True(Chemistry.Ph(b) > Chemistry.Ph(a) + 0.1);
    }

    [Fact]
    public void Mlf_LowersTa_AndRaisesPh_AsStoichiometryPredicts()
    {
        var before = new AcidComposition { Tartaric = 5, Malic = 3, PotassiumGL = 1.2, EthanolPctVol = 12 };
        var after = before with { Malic = 0, Lactic = 3 * 0.672 };
        double dTa = Chemistry.TitratableAcidity(before) - Chemistry.TitratableAcidity(after);
        Assert.InRange(dTa, 1.2, 2.0);                                  // ≈ 0.56 g/L TA per g/L malic → ≈ 1.7 for 3 g/L
        Assert.InRange(Chemistry.Ph(after) - Chemistry.Ph(before), 0.05, 0.35);
    }

    [Fact]
    public void TypicalMoselMust_HasLowPh_AndNapaMust_HighPh()
    {
        var mosel = new AcidComposition { Tartaric = 6, Malic = 5, PotassiumGL = 1.0 };
        var napa = new AcidComposition { Tartaric = 6.5, Malic = 2.5, PotassiumGL = 1.8 };   // warm-site harvest must (ripening.md §4.4)
        Assert.InRange(Chemistry.Ph(mosel), 2.85, 3.25);
        Assert.InRange(Chemistry.Ph(napa), 3.45, 3.95);
    }
}

public class LawTests
{
    [Fact]
    public void SweetnessTerms_FollowEuRules()
    {
        Assert.Equal("trocken", Law.SweetnessTermEu(7, 8, true));        // ≤ 9 g/L with TA ≥ RS − 2
        Assert.Equal("halbtrocken", Law.SweetnessTermEu(15, 8, true));
        Assert.Equal("lieblich", Law.SweetnessTermEu(38, 8.6, true));
        Assert.Equal("süß", Law.SweetnessTermEu(60, 8, true));
    }

    [Fact]
    public void Chaptalisation_ForbidsPradikat_OnTheMosel()
    {
        var g = Fixture.Play("mosel-blauschiefer", 2015, 84, s => { });
        // redo one Lot chaptalised through a fresh game with the choice applied at harvest time
        var g2 = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-blauschiefer", PlantingYear = 2015 });
        int guard = 0;
        while (!g2.IsVintageBottled(g2.FirstVintage) && guard++ < 400)
        {
            g2.Advance(30);
            if (g2.Vintage == g2.FirstVintage)
                foreach (var b in g2.Blocks.Where(b => !b.Harvested && !b.Picking && b.Veraison != null))
                    if (Chemistry.MustFromBlock(b).Oe >= 84) g2.Apply(new Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Table" });
            foreach (var lot in g2.Lots.Where(l => l.Phase == LotPhase.Received)) g2.Apply(new Command { Type = "lot", A = lot.Id, B = "Chaptalisation", C = "1" });
            foreach (var lot in g2.Lots.Where(l => l.Phase == LotPhase.Ready).ToList()) g2.Apply(new Command { Type = "wine", A = lot.Id, E = lot.Id });
        }
        Assert.All(g.WinesOf(g.FirstVintage), w => Assert.Contains(w.Legal!.Category, new[] { "Kabinett", "Spätlese", "Auslese" }));
        // chaptalised: never Prädikat; at 86 °Oe + 1 % vol it also breaks the zone A 11.5 % ceiling → Deutscher Wein
        Assert.All(g2.WinesOf(g2.FirstVintage), w => Assert.DoesNotContain(w.Legal!.Category, new[] { "Kabinett", "Spätlese", "Auslese", "Beerenauslese" }));
        Assert.Contains(g2.WinesOf(g2.FirstVintage).SelectMany(w => w.Legal!.Notes), n => n.Contains("chaptalisation is forbidden"));
    }

    [Fact]
    public void Riesling_InBurgundy_IsVinDeFrance()
    {
        var setup = new GameSetup { PlotId = "cotedor-hautes", PlantingYear = 2012 };
        foreach (var b in Fixture.Data.Plot("cotedor-hautes").Blocks)
            setup.Planting[b.Id] = new PlantingChoice { Variety = VarietyId.Riesling, Rootstock = RootstockId.Fercal, Training = TrainingSystem.Guyot, DensityVinesHa = 10000 };
        var g = new GameSession(Fixture.Data, setup);
        int guard = 0;
        while (!g.IsVintageBottled(g.FirstVintage) && guard++ < 400)
        {
            g.Advance(30);
            if (g.Vintage == g.FirstVintage)
                foreach (var b in g.Blocks.Where(b => !b.Harvested && !b.Picking && b.Veraison != null && (Chemistry.MustFromBlock(b).Oe >= 82 || b.LeafFall != null)))
                    g.Apply(new Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Table" });
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Ready).ToList()) g.Apply(new Command { Type = "wine", A = lot.Id, E = lot.Id });
        }
        Assert.NotEmpty(g.WinesOf(g.FirstVintage));
        Assert.All(g.WinesOf(g.FirstVintage), w => Assert.Equal("Vin de France", w.Legal!.Category));
    }
}

public class VineyardCalibrationTests
{
    [Fact]
    public void Burgundy2021_AprilFrost_DestroysMostShootsInTheFrostPocket()
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "cotedor-plaine", PlantingYear = 2018 });
        g.Advance(140, stopAtAlerts: false);
        Assert.True(g.Blocks.Average(b => b.FrostShootLoss) > 0.5, "April 2021 radiation frost should hit the frost-pocket Plot hard");
    }

    [Fact]
    public void Mosel_Riesling_HarvestComposition_IsInRange()
    {
        var g = Fixture.Play("mosel-blauschiefer", 2016, 84);   // vintage 2019
        foreach (var p in g.Provenance.Values.Where(p => p.Vintage == g.FirstVintage))
        {
            Assert.InRange(p.HarvestTa, 7.0, 11.5);
            Assert.InRange(p.HarvestPh, 2.85, 3.35);
            Assert.InRange(p.HarvestDate.Month, 9, 10);
        }
    }

    [Fact]
    public void Napa_Cabernet_IsLowAcidHighPh_AndRipensInAutumn()
    {
        var g = Fixture.Play("napa-bench", 2016, Units.OeFromBrix(25));
        foreach (var p in g.Provenance.Values.Where(p => p.Vintage == g.FirstVintage))
        {
            Assert.InRange(p.HarvestPh, 3.4, 3.95);
            Assert.InRange(p.HarvestTa, 4.0, 7.0);
        }
        Assert.All(g.Provenance.Values.Where(p => p.Vintage == g.FirstVintage), p => Assert.InRange(p.Budburst!.Value.Month, 3, 4));
    }

    [Fact]
    public void VeryRipeMust_CannotFermentBeyondYeastTolerance()
    {
        // 29 °Brix ≈ 18 % potential: yeast stop short of dryness (fermentation.md: very high sugar is a stuck-fermentation cause)
        var g = Fixture.Play("napa-bench", 2018, Units.OeFromBrix(29));
        // the ordinary cultured yeast sticks; the test fixture then restarts with a tolerant culture (≈18 %)
        Assert.All(g.Lots.Where(l => l.Vintage == g.FirstVintage), l => Assert.Contains(l.Log, x => x.Contains("STUCK")));
        Assert.All(g.Lots.Where(l => l.Vintage == g.FirstVintage), l => Assert.True(l.AlcoholPct <= 18.3, $"{l.Id} reached {l.AlcoholPct:0.0} %"));
    }

    [Theory]
    [InlineData(VarietyId.PinotNoir)]
    [InlineData(VarietyId.Chardonnay)]
    public void CoteDor_200gL_AveragesMidSeptember_1990To2018(VarietyId variety)
    {
        // phenology.md: Beaune harvests start around mid-September over 1988–2018 (Labbé et al. 2019); ±1 week tolerance
        var plot = Fixture.Data.Plot("cotedor-village");
        var archive = new WeatherArchive(Fixture.Data.DataRoot, plot.Region.WeatherFile);
        var rw = new RegionWeather(archive, 42);
        var bd = plot.Blocks[0];
        var days = new List<int>();
        for (int vint = 1990; vint <= 2018; vint += 2)
        {
            var b = new BlockState(plot, bd, new BlockClimate(plot, bd, archive.GridElevationM))
            {
                Planted = true, PlantingYear = vint - 3,
                Planting = new PlantingChoice { Variety = variety, Rootstock = RootstockId.SO4, Training = TrainingSystem.Guyot, DensityVinesHa = 10000 },
            };
            var ctx = new VineyardContext { Spray = Tier.Medium };
            for (var d = new DateOnly(vint - 3, 1, 1); d <= new DateOnly(vint, 11, 15); d = d.AddDays(1))
            {
                ctx.AutoManage = d.Year < vint;
                VineyardModel.Step(b, rw.Get(d), ctx, 42);
                if (d.Year == vint && b.Veraison != null && b.SugarGL >= 200) { days.Add(d.DayOfYear); break; }
            }
        }
        double mean = days.Average();
        Assert.InRange(mean, 251, 265);   // 8–22 September
    }

    [Fact]
    public void Cabernet_OnTheMoselFlats_FailsToRipen()
    {
        var setup = new GameSetup { PlotId = "mosel-uferflur", PlantingYear = 2007 };   // vintage 2010, a cool year
        foreach (var b in Fixture.Data.Plot("mosel-uferflur").Blocks)
            setup.Planting[b.Id] = new PlantingChoice { Variety = VarietyId.CabernetSauvignon, Rootstock = RootstockId.SO4, Training = TrainingSystem.Guyot, DensityVinesHa = 5000 };
        var g = new GameSession(Fixture.Data, setup);
        g.Advance(300, stopAtAlerts: false);   // to late October
        foreach (var b in g.Blocks)
        {
            Assert.True(Chemistry.MustFromBlock(b).Brix < 22.5, "Cabernet should not reach Napa-style ripeness on a cool Mosel flat");
            Assert.True(b.Ibmp > 10, "unripe Cabernet keeps green pyrazine");
        }
    }
}

public class GameLoopTests
{
    [Theory]
    [InlineData("mosel-seitental", 2014, 80)]
    [InlineData("cotedor-village", 2013, 95)]
    [InlineData("napa-carneros", 2016, 104)]
    public void FullGame_ReachesBottling_WithTastingSheets(string plot, int year, double target)
    {
        var g = Fixture.Play(plot, year, target);
        Assert.True(g.IsVintageBottled(g.FirstVintage));
        Assert.True(g.MentorRetired);
        Assert.NotEmpty(g.WinesOf(g.FirstVintage));
        foreach (var w in g.WinesOf(g.FirstVintage))
        {
            Assert.NotNull(w.Sheet);
            Assert.NotEmpty(w.Sheet!.Aromas);
            Assert.All(w.Sheet.Aromas, a => Assert.False(string.IsNullOrWhiteSpace(a.Because)));   // every descriptor links to a cause (spec §3.2)
            Assert.Contains(w.Sheet.Quality, new[] { "Faulty", "Poor", "Acceptable", "Good", "Very good", "Outstanding" });
        }
    }

    [Fact]
    public void SprayNow_AddsOneExtraPass_OnADryDay_AndReplays()
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-blauschiefer", PlantingYear = 2016 });
        while (g.Blocks.Any(b => b.Budburst == null) || g.Date.Month < 6) g.Advance(1, false);
        while (g.Weather.Get(g.Date).Precip > 5) g.Advance(1, false);   // wait for a dry day
        int before = g.Blocks.Sum(b => b.Disease.SpraysThisSeason);
        double cash = g.Ledger.Cash;
        g.Apply(new Command { Type = "spraynow" });
        g.Advance(1, false);
        Assert.True(g.Blocks.Sum(b => b.Disease.SpraysThisSeason) >= before + g.Blocks.Count);
        Assert.True(g.Ledger.Cash < cash);
        var g2 = GameSession.Load(Fixture.Data, g.Save());
        Assert.Equal(g.Blocks.Sum(b => b.Disease.SpraysThisSeason), g2.Blocks.Sum(b => b.Disease.SpraysThisSeason));
    }

    [Fact]
    public void SaveAndReplay_IsDeterministic()
    {
        var g = Fixture.Play("mosel-terrassen", 2016, 86);
        var g2 = GameSession.Load(Fixture.Data, g.Save());
        Assert.Equal(g.Ledger.Cash, g2.Ledger.Cash, 2);
        Assert.Equal(g.Wines.Count, g2.Wines.Count);
        Assert.Equal(g.Wines.Select(w => w.Sheet!.Quality), g2.Wines.Select(w => w.Sheet!.Quality));
    }

    [Fact]
    public void StaffForecasts_NeverSeeTheRealFuture_ExactlyBeyondDayOne()
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-blauschiefer", PlantingYear = 2015 });
        var fc = g.CurrentForecast();
        var clim = g.Blocks[0].Climate;
        int exact = fc.Count(f => Math.Abs(f.Tmax - clim.Adjust(g.Weather.Get(f.Date)).Tmax) < 0.05);
        Assert.True(exact < fc.Count / 2, "forecasts must carry error (ADR 0002)");
    }

    [Fact]
    public void SetupCatalog_Has12Plots_With1To20Ratings()
    {
        var cat = SetupCatalog.Build(Fixture.Data);
        var plots = cat["regions"]!.AsArray().SelectMany(r => r!["plots"]!.AsArray()).ToList();
        Assert.Equal(12, plots.Count);
        foreach (var p in plots)
            foreach (var kv in p!["ratings"]!.AsObject()) Assert.InRange((int)kv.Value!, 1, 20);
    }
}
