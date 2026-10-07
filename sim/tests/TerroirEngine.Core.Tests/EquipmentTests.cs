using TerroirEngine.Game;
using TerroirEngine.Vineyard;

namespace TerroirEngine.Tests;

/// <summary>The Shop's Vineyard & cellar equipment (equipment-shop design §6): frost methods and the sorting table.</summary>
public class EquipmentTests
{
    private static GameSession New(string plot = "cotedor-village") => new(Fixture.Data, new GameSetup { PlotId = plot, PlantingYear = 2014, ShopVersion = 1 });

    [Fact]
    public void WindMachine_LiftsTmin_UnderAnInversion_NotOnAWindyNight()
    {
        var calm = VineyardModel.FrostProtection(-3.0, -1.7, radiationNight: true, windKmh: 2, clear: 0.9, windMachine: true, sprinklers: false);
        Assert.True(calm.Fan);
        Assert.InRange(calm.TMin - (-3.0) - (calm.Candles ? VineyardModel.CandleGainC : 0), 0.5, 1.6);   // ≈ ⅓ of a 1.5–4.5 °C inversion
        var breezy = VineyardModel.FrostProtection(-3.0, -1.7, radiationNight: true, windKmh: 9, clear: 0.9, windMachine: true, sprinklers: false);
        Assert.True(breezy.TMin - (breezy.Candles ? VineyardModel.CandleGainC : 0) < calm.TMin - (calm.Candles ? VineyardModel.CandleGainC : 0), "a weaker inversion in a breeze");
        var windy = VineyardModel.FrostProtection(-3.0, -1.7, radiationNight: false, windKmh: 20, clear: 0.9, windMachine: true, sprinklers: false);
        Assert.False(windy.Fan);
        Assert.Equal(-3.0, windy.TMin);
    }

    [Fact]
    public void WindMachine_SavesCandles_OnMildNights_AndAddsThemOnHardOnes()
    {
        var mild = VineyardModel.FrostProtection(-1.0, -1.7, true, 1, 1.0, windMachine: true, sprinklers: false);
        Assert.True(mild.Fan); Assert.False(mild.Candles);
        var hard = VineyardModel.FrostProtection(-4.5, -1.7, true, 1, 1.0, windMachine: true, sprinklers: false);
        Assert.True(hard.Fan); Assert.True(hard.Candles);
        var candlesOnly = VineyardModel.FrostProtection(-4.5, -1.7, true, 1, 1.0, windMachine: false, sprinklers: false);
        Assert.True(hard.TMin > candlesOnly.TMin);
    }

    [Fact]
    public void Sprinklers_ProtectBelowTheCandleLimit_AndInAdvectiveFrost()
    {
        var candles = VineyardModel.FrostProtection(-5.0, -1.7, true, 2, 0.9, false, false);
        var spr = VineyardModel.FrostProtection(-5.0, -1.7, true, 2, 0.9, false, sprinklers: true);
        Assert.True(candles.TMin < -1.7 - 1.0, "candles alone leave damage at −5 °C");
        Assert.True(spr.TMin >= -1.0, "sprinklers hold the buds near 0 °C down to −6 °C");
        Assert.True(VineyardModel.FrostProtection(-8.0, -1.7, true, 2, 0.9, false, true).TMin < -1.7, "below the limit they give way");
        var windy = VineyardModel.FrostProtection(-4.0, -1.7, false, 25, 0.2, false, sprinklers: true);
        Assert.True(windy.Sprinklers && windy.TMin >= -1.0);
    }

    [Fact]
    public void BuyingEquipment_DebitsEquipment_AndSprinklersScaleWithArea()
    {
        var g = New("cotedor-hautes");    // 1.2 ha
        var cat = Shop.Catalog(Fixture.Data);
        double perHa = cat.Item("sprinklers")!.P("perHa");
        Assert.Equal(perHa * 1.2, g.ShopPrice("equipment", "sprinklers"), 0);
        double cash = g.Ledger.Cash;
        g.Apply(new Command { Type = "buy", A = "equipment", B = "wind-machine" });
        Assert.True(g.OwnsEquipment("wind-machine"));
        Assert.Equal(cash - cat.Item("wind-machine")!.Price, g.Ledger.Cash, 0);
        Assert.Contains(g.Ledger.Entries, e => e.Category == Shop.EquipmentCategory);
    }

    [Fact]
    public void SteepMoselSlate_OffersNoSprinklers_NorAWindMachine()
    {
        var g = New("mosel-blauschiefer");
        Assert.NotEqual("", g.ShopUnavailable("sprinklers"));
        Assert.NotEqual("", g.ShopUnavailable("wind-machine"));
        double cash = g.Ledger.Cash;
        g.Apply(new Command { Type = "buy", A = "equipment", B = "sprinklers" });
        Assert.Equal(cash, g.Ledger.Cash);
        Assert.False(g.OwnsEquipment("sprinklers"));
        Assert.Equal("", New("mosel-uferflur").ShopUnavailable("sprinklers"));
    }

    [Fact]
    public void RigorousSorting_WithoutATable_IsRefused_ToTableLevel()
    {
        var g = new GameSession(Fixture.Data, Scenarios.Setup(Fixture.Data, "cotedor-2016"));
        while (g.Blocks.All(b => b.Veraison == null)) g.Advance(10, stopAtAlerts: false);
        var b = g.Blocks.First(x => x.Veraison != null);
        g.Apply(new Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Rigorous" });
        Assert.Equal(SortingLevel.Table, b.Order!.Sorting);
        g.Apply(new Command { Type = "buy", A = "equipment", B = "sorting-table" });
        var b2 = g.Blocks.First(x => x.Veraison != null && !x.Picking);
        g.Apply(new Command { Type = "harvest", A = b2.Data.Id, B = "hand", C = "Rigorous" });
        Assert.Equal(SortingLevel.Rigorous, b2.Order!.Sorting);
    }

    // the frost-prone plain below the village: candles alone leave damage on the night of 27 April 2016
    private static double FrostLoss2016(bool windMachine)
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "cotedor-plaine", PlantingYear = 2013, Seed = 2016, ShopVersion = 1 });
        if (windMachine) g.Apply(new Command { Type = "buy", A = "equipment", B = "wind-machine" });
        g.Apply(new Command { Type = "programme", A = "frost", B = "Medium" });
        while (g.Date < new DateOnly(2016, 6, 1)) g.Advance(10, stopAtAlerts: false);
        return g.Blocks.Average(b => b.FrostShootLoss);
    }

    [Fact]
    public void CoteDor2016_LosesLessToFrost_WithAWindMachine()
    {
        double without = FrostLoss2016(false), with = FrostLoss2016(true);
        Assert.True(without > 0.02, $"the April 2016 frost should still bite with candles only ({without:P0})");
        Assert.True(with < without, $"with a wind machine {with:P1} vs without {without:P1}");
    }

    [Fact]
    public void FrostNights_AreCharged_PerMethod()
    {
        var g = new GameSession(Fixture.Data, Scenarios.Setup(Fixture.Data, "cotedor-2016"));
        g.Apply(new Command { Type = "programme", A = "frost", B = "Medium" });
        while (g.Date < new DateOnly(2016, 6, 1)) g.Advance(10, stopAtAlerts: false);
        Assert.Contains(g.Ledger.Entries, e => e.Category == "Frost protection" && e.Note.Contains("candles"));
    }

    [Fact]
    public void FrostEquipment_NeedsInstalling_ItDoesNotProtectTheNightItIsBought()
    {
        var g = New("cotedor-hautes");
        g.Apply(new Command { Type = "buy", A = "equipment", B = "wind-machine" });
        g.Advance(1, stopAtAlerts: false);
        Assert.True(g.OwnsEquipment("wind-machine"));
        Assert.False(g.Ctx.FrostWindMachine, "a tower is not up the day after it is ordered");
        g.Advance(Shop.InstallDays + 1, stopAtAlerts: false);
        Assert.True(g.Ctx.FrostWindMachine);
    }

    [Fact]
    public void CoteDor_OffersNoSprinklers_NoWaterReservoir()
    {
        Assert.NotEqual("", New("cotedor-plaine").ShopUnavailable("sprinklers"));
        Assert.Equal("", New("cotedor-plaine").ShopUnavailable("wind-machine"));
        Assert.Equal("", New("napa-floor").ShopUnavailable("sprinklers"));
    }

    [Fact]
    public void Sprinklers_StopWhenTheSeasonsWaterRunsOut()
    {
        var g = New("napa-floor");
        g.Setup.ShopGrants.Add("equipment:sprinklers");
        g.Advance(1, stopAtAlerts: false);
        Assert.True(g.Ctx.FrostSprinklers);
        g.Ctx.SprinklerNightsLeft = 0;
        g.Advance(1, stopAtAlerts: false);
        Assert.False(g.Ctx.FrostSprinklers, "an empty reservoir runs no sprinklers");
    }

    [Fact]
    public void FrostWarning_DoesNotSellEquipment()
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "cotedor-plaine", PlantingYear = 2013, Seed = 2016, ShopVersion = 1 });
        while (g.Date < new DateOnly(2016, 6, 1)) g.Advance(10, stopAtAlerts: false);
        var warnings = g.Inbox.Where(m => m.Kind == "frost-warning").ToList();
        Assert.NotEmpty(warnings);
        Assert.DoesNotContain(warnings, m => m.Actions.Any(a => a.Arg == "shop-equipment") || m.Body.Contains("Shop"));
    }

    [Fact]
    public void ForcedDecemberHarvest_SaysTheSortingItReallyUsed()
    {
        var g = New("mosel-seitental");
        while (g.Date < new DateOnly(g.FirstVintage, 12, 3)) g.Advance(20, stopAtAlerts: false);
        var m = g.Inbox.First(x => x.Kind == "forced-harvest");
        Assert.DoesNotContain("rigorous", m.Body);
        Assert.All(g.Blocks, b => Assert.Equal(SortingLevel.Table, b.Order!.Sorting));
    }
}
