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

public class VintageReportTests
{
    [Fact]
    public void VintageReports_ArePerVintage_FromSeasonRecords()
    {
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 2);
        var r1 = VintageReport.Build(g, g.FirstVintage);
        var r2 = VintageReport.Build(g, g.FirstVintage + 1);
        Assert.Equal(g.FirstVintage, r1["vintage"]!.GetValue<int>());
        Assert.Equal(g.FirstVintage + 1, r2["vintage"]!.GetValue<int>());
        Assert.NotEqual(r1["weather"]!["winkler"]!.GetValue<double>(), r2["weather"]!["winkler"]!.GetValue<double>());
        foreach (var r in new[] { r1, r2 })
            foreach (var b in r["blocks"]!.AsArray()) { Assert.NotNull(b!["harvest"]); Assert.NotNull(b["wine"]); }
        Assert.True(r1["farewell"]!.GetValue<bool>());
        Assert.False(r2["farewell"]!.GetValue<bool>());
        Assert.NotEmpty(r2["weekly"]!.AsArray());
        Assert.All(g.Blocks, b => Assert.Contains(b.Seasons, s => s.Year == g.FirstVintage && s.HarvestDate != null && s.YieldKgHa > 0));
        var snap = Snapshot.Build(g);
        Assert.Equal(2, snap["reports"]!.AsArray().Count);
        Assert.Equal(g.FirstVintage + 1, snap["reports"]![0]!["vintage"]!.GetValue<int>());   // newest first
    }
}

public class CarryOverTests
{
    [Fact]
    public void FirstVintage_HasNeutralCarryOver()
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2014 });
        Assert.All(g.Blocks, b => { Assert.Equal(1.0, b.Fruitfulness); Assert.Equal(1.0, b.Reserves); Assert.Equal(1.0, b.FruitfulnessNext); });
        Assert.All(g.Blocks, b => Assert.NotNull(b.ClimNormalTmean));
    }

    [Fact]
    public void Fruitfulness_FollowsFloweringWarmthAndLight_AndIsBounded()
    {
        Assert.Equal(1.0, VineyardModel.FruitfulnessFrom(0, 0.45), 6);
        Assert.True(VineyardModel.FruitfulnessFrom(2, 0.45) > 1.05);
        Assert.True(VineyardModel.FruitfulnessFrom(-2, 0.45) < 0.95);
        Assert.True(VineyardModel.FruitfulnessFrom(0, 0.65) > 1.05);
        Assert.Equal(1.15, VineyardModel.FruitfulnessFrom(10, 0.9), 6);
        Assert.Equal(0.85, VineyardModel.FruitfulnessFrom(-10, 0.1), 6);
    }

    [Fact]
    public void SeasonReserves_DropWithBigCropLateHarvestAndLeafLoss()
    {
        double balanced = VineyardModel.SeasonReserves(1.0, 40, 0);
        Assert.InRange(balanced, 0.99, 1.01);
        Assert.True(VineyardModel.SeasonReserves(1.8, 40, 0) < balanced - 0.05);    // over-cropped
        Assert.True(VineyardModel.SeasonReserves(1.0, 0, 0) < balanced - 0.05);     // picked at leaf fall
        Assert.True(VineyardModel.SeasonReserves(1.0, 40, 0.4) < balanced - 0.1);   // mildew defoliation
        Assert.True(VineyardModel.SeasonReserves(0.3, 40, 0) > balanced);           // light crop: vines recover
        Assert.Equal(0.70, VineyardModel.SeasonReserves(5, 0, 0.9), 6);
    }

    [Fact]
    public void InoculumCarry_RisesWithLastYearsMildew()
    {
        Assert.Equal(0.85, GameSession.InoculumCarry(0), 6);
        Assert.True(GameSession.InoculumCarry(20) > 1.1);
        Assert.Equal(1.30, GameSession.InoculumCarry(80), 6);
    }

    private static GameSession YearTwoAfter(string budLoad, string spray)
    {
        // Mosel 2016 was a heavy downy-mildew year in Germany (cited in disease.md)
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2013 });
        foreach (var b in g.Blocks) g.Apply(new Command { Type = "block", A = b.Data.Id, B = "budload", C = budLoad });
        g.Apply(new Command { Type = "programme", A = "spray", B = spray });
        while (g.Date.Year == g.FirstVintage)
        {
            g.Advance(7, stopAtAlerts: false);
            foreach (var b in g.Blocks.Where(b => !b.Harvested && !b.Picking && b.Veraison != null && (Chemistry.MustFromBlock(b).Oe >= 80 || b.LeafFall != null)))
                g.Apply(new Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Table" });
        }
        // the second Vintage is farmed identically in both games
        foreach (var b in g.Blocks) g.Apply(new Command { Type = "block", A = b.Data.Id, B = "budload", C = "Balanced" });
        g.Apply(new Command { Type = "programme", A = "spray", B = "Medium" });
        while (g.Blocks.Any(b => b.SetFraction < 0)) g.Advance(7, stopAtAlerts: false);
        return g;
    }

    [Fact]
    public void HardYear_ShrinksNextYearsCrop_ComparedWithACarefulYear()
    {
        var hard = YearTwoAfter("High", "Low");
        var careful = YearTwoAfter("Low", "High");
        Assert.True(hard.Blocks.Average(b => b.Reserves) < careful.Blocks.Average(b => b.Reserves));
        Assert.True(hard.Blocks.Average(b => b.Reserves) < 1.0);
        Assert.True(hard.Blocks.Sum(b => b.BerriesPerVine) < careful.Blocks.Sum(b => b.BerriesPerVine));
        Assert.All(hard.Blocks, b => Assert.Contains(b.Seasons, s => s.Year == hard.FirstVintage && s.ReservesAfter == b.Reserves));
    }
}

public class StaffAdviceTests
{
    [Fact]
    public void LaterVintages_BeginWithTheVineyardManagersMessage()
    {
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 2);
        var ns = g.Inbox.Single(m => m.Kind == "newseason" && m.Date == new DateOnly(g.FirstVintage + 1, 1, 15));
        Assert.Equal("vineyard", ns.Role);
        Assert.StartsWith($"Vintage {g.FirstVintage + 1} begins", ns.Subject);
        Assert.Contains("buds", ns.Body);
        Assert.Contains(ns.Actions, a => a.Action == "goto" && a.Arg == "plot");
        Assert.DoesNotContain(g.Inbox, m => m.Kind == "newseason" && m.Date.Year == g.FirstVintage);
    }

    [Fact]
    public void AfterRetirement_SeasonalAdviceComesFromStaff_JuniorsWithoutTheWhy()
    {
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 3);
        var later = g.Inbox.Where(m => m.Date > g.FinishedDate && m.Kind is "budburst" or "flowering" or "veraison").ToList();
        Assert.NotEmpty(later);
        Assert.All(later, m => Assert.Equal("vineyard", m.Role));
        Assert.All(later, m => Assert.Equal("", m.Why));   // default staff are Junior
        Assert.DoesNotContain(g.Inbox, m => m.Date > g.FinishedDate && m.Role == "mentor" && m.Kind is "budburst" or "flowering" or "veraison" or "forced-harvest" or "yield");
    }
}

public class VintageLawAndMoneyTests
{
    [Theory]
    [InlineData("mosel", 0.90, true)]
    [InlineData("napa", 0.90, false)]
    [InlineData("cote-dor", 0.80, false)]
    [InlineData("napa", 0.96, true)]
    [InlineData("mosel", 1.00, true)]
    public void VintageStatement_FollowsEuAndUsThresholds(string region, double share, bool vintage)
    {
        var parts = share >= 1 ? new[] { (2020, 100.0) } : new[] { (2020, share * 100), (2019, (1 - share) * 100) };
        var (year, note) = Law.VintageStatement(parts, region);
        Assert.Equal(vintage ? 2020 : (int?)null, year);
        Assert.Equal(vintage, note == null);
    }

    [Fact]
    public void CrossVintageBlend_InNapa_IsNonVintage()
    {
        // hold the first Vintage's Lots unbottled until the second Vintage's are ready, then blend 50/50
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "napa-carneros", PlantingYear = 2016 });
        int guard = 0;
        while (!g.Lots.Any(l => l.Vintage == g.FirstVintage + 1 && l.Phase == LotPhase.Ready) && guard++ < 60)
        {
            g.Advance(30, stopAtAlerts: false);
            foreach (var b in g.Blocks.Where(b => !b.Harvested && !b.Picking && b.Veraison != null && (Chemistry.MustFromBlock(b).Oe >= 100 || b.LeafFall != null)))
                g.Apply(new Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Table" });
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Stuck).ToList()) g.Apply(new Command { Type = "restart", A = lot.Id });
        }
        var a = g.Lots.First(l => l.Vintage == g.FirstVintage && l.Phase == LotPhase.Ready);
        var b2 = g.Lots.First(l => l.Vintage == g.FirstVintage + 1 && l.Phase == LotPhase.Ready);
        double litres = Math.Min(a.VolumeL, b2.VolumeL);
        g.Apply(new Command { Type = "wine", A = "Two-Vintage blend", E = FormattableString.Invariant($"{a.Id}:{litres:0.0};{b2.Id}:{litres:0.0}") });
        var w = g.Wines.Last();
        Assert.Null(w.Vintage);
        Assert.StartsWith("Non-vintage", w.Legal!.Label);
        Assert.Contains(w.Legal.Notes, n => n.Contains("non-vintage"));
    }

    [Fact]
    public void SingleVintageWine_StatesItsYear()
    {
        var g = Fixture.Play("mosel-seitental", 2014, 80);
        Assert.All(g.WinesOf(g.FirstVintage), w => { Assert.Equal(g.FirstVintage, w.Vintage); Assert.StartsWith($"{g.FirstVintage} ", w.Legal!.Label); });
    }

    [Fact]
    public void OverdraftInterest_IsChargedMonthly_OnlyWhileOverdrawn()
    {
        Assert.Equal(0.0, EconomyTables.OverdraftInterest(1000));
        Assert.Equal(-75.0, EconomyTables.OverdraftInterest(-10000), 6);   // 9 % a year on €10,000, one month
        // the Premier Cru Plot costs more than the starting capital: overdrawn from day one
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "cotedor-premiercru", PlantingYear = 2015 });
        g.Advance(100, stopAtAlerts: false);
        double running = 0; int n = 0;
        foreach (var e in g.Ledger.Entries)
        {
            if (e.Category == "Interest") { Assert.True(running < 0); Assert.Equal(running * EconomyTables.OverdraftRate / 12, e.Amount, 0); n++; }
            running += e.Amount;
        }
        Assert.InRange(n, 3, 4);
        var rich = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2015 });
        rich.Advance(100, stopAtAlerts: false);
        Assert.DoesNotContain(rich.Ledger.Entries, e => e.Category == "Interest");
    }
}

public class MultiVintageSnapshotTests
{
    [Fact]
    public void Snapshot_HasHistoryYearsAndVintagedLots()
    {
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 2);
        var s = Snapshot.Build(g);
        Assert.Equal("Running", s["phase"]!.GetValue<string>());
        Assert.Equal(g.FirstVintage, s["firstVintage"]!.GetValue<int>());
        Assert.StartsWith($"Vintage {g.Vintage} · ", s["seasonLabel"]!.GetValue<string>());
        var hist = s["history"]!.AsArray();
        Assert.Equal(g.Vintage - g.FirstVintage + 1, hist.Count);
        Assert.Equal(g.Vintage, hist[0]!["vintage"]!.GetValue<int>());
        Assert.Contains(hist, h => h!["vintage"]!.GetValue<int>() == g.FirstVintage && h["status"]!.GetValue<string>() == "In bottle" && h["wines"]!.AsArray().Count > 0);
        Assert.Equal(new[] { g.FirstVintage, g.FirstVintage + 1 }, s["bottledVintages"]!.AsArray().Select(x => x!.GetValue<int>()));
        Assert.All(s["lots"]!.AsArray(), l => Assert.InRange(l!["vintage"]!.GetValue<int>(), g.FirstVintage, g.Vintage));
        Assert.All(s["wines"]!.AsArray(), w => Assert.NotNull(w!["vintage"]));
        var years = s["years"]!.AsArray();
        Assert.Equal(g.Setup.PlantingYear, years[0]!["year"]!.GetValue<int>());
        Assert.Equal(Math.Round(g.Ledger.Cash), years[^1]!["cashEnd"]!.GetValue<double>(), 0);
    }

    [Fact]
    public void FiveVintageSave_LoadsWithinBudget_AndSnapshotStaysSmall()
    {
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 5);
        var sw = System.Diagnostics.Stopwatch.StartNew();
        var g2 = GameSession.Load(Fixture.Data, g.Save());
        long loadMs = sw.ElapsedMilliseconds;
        Assert.True(loadMs < 30_000, $"five-Vintage load took {loadMs} ms (budget 10 s on the owner's PC, 30 s CI headroom)");
        sw.Restart();
        string json = Snapshot.Json(g2);
        long snapMs = sw.ElapsedMilliseconds;
        Assert.True(json.Length < 400_000, $"snapshot is {json.Length / 1024} KB");
        Assert.True(snapMs < 500, $"snapshot took {snapMs} ms");
    }
}

public class BottlingCompletesVintageTests
{
    [Fact]
    public void BottlingTheLastLot_MarksTheVintageBottledTheSameDay()
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2014 });
        int guard = 0;
        while (!g.Lots.Any() || g.Lots.Any(l => l.Vintage == g.FirstVintage && l.Phase != LotPhase.Ready && l.Phase != LotPhase.Blended) || g.Blocks.Any(b => !b.Harvested) && g.Date.Year == g.FirstVintage)
        {
            if (guard++ > 400) break;
            g.Advance(15, stopAtAlerts: false);
            foreach (var b in g.Blocks.Where(b => !b.Harvested && !b.Picking && b.Veraison != null && (Chemistry.MustFromBlock(b).Oe >= 80 || b.LeafFall != null)))
                g.Apply(new Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Table" });
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Stuck).ToList()) g.Apply(new Command { Type = "restart", A = lot.Id });
        }
        var ready = g.Lots.Where(l => l.Vintage == g.FirstVintage && l.Phase == LotPhase.Ready).ToList();
        foreach (var lot in ready) g.Apply(new Command { Type = "wine", A = lot.Id, E = lot.Id });
        Assert.True(g.IsVintageBottled(g.FirstVintage));   // no day step needed
        Assert.Equal(g.Date, g.FinishedDate);
    }
}

public class VintageNormalTests
{
    [Fact]
    public void WeatherNormal_DoesNotDependOnTheGameDate()
    {
        // a game dated January 2017 must still use complete 1991–2020 years for the normal (mosel-uferflur: no other report test uses it)
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-uferflur", PlantingYear = 2014 });
        double normal = VintageReport.HistoryRow(g, g.FirstVintage)["winklerNormal"]!.GetValue<double>();
        var clim = g.Blocks[0].Climate; var arch = g.Weather.Archive;
        var totals = new List<double>();
        for (int y = 1991; y <= 2020; y++)
        {
            double wi = 0;
            for (var d = new DateOnly(y, 4, 1); d <= new DateOnly(y, 10, 31); d = d.AddDays(1)) wi += Math.Max(0, clim.Adjust(arch.Get(d)).Tmean - 10);
            totals.Add(wi);
        }
        Assert.Equal(Math.Round(totals.Average()), normal, 0);
    }
}

public class ReviewFixTests
{
    [Fact]
    public void CellarMessages_NameTheirOwnLot_AfterTheYearTurns()
    {
        // Napa Cabernet ages 18 months: its Lots become ready after the next Vintage has begun (review finding #1)
        var g = Fixture.Play("napa-bench", 2012, Units.OeFromBrix(25));
        var readies = g.Inbox.Where(m => m.Kind == "lot-ready").ToList();
        Assert.NotEmpty(readies);
        Assert.All(readies, m => Assert.Contains($"Lot {g.FirstVintage % 100:00}-", m.Subject));
    }

    [Fact]
    public void VintageReport_CountsEachWinesBottlingOnce()
    {
        // review finding #2: a report counts its own wines' bottling, never the previous Vintage's bottled in its calendar year
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 3);
        int v = g.FirstVintage + 1;
        double yearCostsWithoutBottling = g.Ledger.Entries.Where(e => e.Date.Year == v && e.Amount < 0 && e.Category != "Bottling").Sum(e => -e.Amount);
        double expected = yearCostsWithoutBottling + g.WinesOf(v).Sum(w => w.BottlingCost);
        Assert.Equal(Math.Round(expected), VintageReport.Build(g, v)["money"]!["costs"]!.GetValue<double>(), 0);
    }

    [Fact]
    public void NormalFarming_KeepsReservesNearNeutral()
    {
        // review finding #3: Balanced bud load, Medium tiers and a timely harvest should not tire the vines year after year
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 3);
        var later = g.Blocks.SelectMany(b => b.Seasons).Where(s => s.Year > g.FirstVintage && s.Year < g.Vintage).ToList();
        Assert.NotEmpty(later);
        Assert.InRange(later.Average(s => s.ReservesAfter), 0.97, 1.05);
    }

    [Fact]
    public void VintageReport_KeyEvents_ListItsOwnBottlings()
    {
        // review finding #4
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 3);
        int v = g.FirstVintage + 1;
        var bottled = VintageReport.Build(g, v)["events"]!.AsArray().Where(e => e!["kind"]!.GetValue<string>() == "bottled").Select(e => e!["text"]!.GetValue<string>()).ToList();
        Assert.NotEmpty(bottled);
        Assert.All(bottled, t => Assert.Contains($": {v} ", t));
    }

    [Fact]
    public void GameRulesAndTheVineAgeStance_AreInTheMessageBody()
    {
        // review finding #5: a Junior's message drops the "why", so labels the rules require must sit in the body
        var noInput = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2014 });
        while (noInput.Date < new DateOnly(noInput.FirstVintage + 1, 1, 1)) noInput.Advance(60, stopAtAlerts: false);
        Assert.All(noInput.Inbox.Where(m => m.Kind == "forced-harvest"), m => Assert.Contains("Game rule", m.Body));
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 3);
        var ns = g.Inbox.Where(m => m.Kind == "newseason" && m.Date > g.FinishedDate).ToList();
        Assert.NotEmpty(ns);
        Assert.All(ns, m => Assert.Contains("old vines", m.Body));
    }
}

public class CoteDorYieldCalibrationTests
{
    [Fact]
    public void CoteDor_MatureVines_AverageNearTheBaseYield()
    {
        // Village reds have a 40 hL/ha base yield; ≈ 0.5–0.65 kg of fruit per vine at 10,000 vines/ha (canopy-and-yield.md §7).
        // Mature (5th leaf on), the Mentor's Low bud load, Medium tiers, frost-free Vintages: the yield components alone should give
        // about the base yield. Frost years are tested on their own (Burgundy 2016, 2021).
        var g = Fixture.PlayVintages("cotedor-village", 2008, 95, vintages: 10);
        var mature = g.Provenance.Values.Where(p => p.Leaf >= 5 && p.Vintage < g.FirstVintage + 10 && p.FrostLoss <= 0.10).ToList();
        Assert.NotEmpty(mature);
        Assert.InRange(mature.Average(p => p.YieldHlHa), 38, 50);
    }
}

public class FollowUpTests
{
    [Fact]
    public void Snapshot_OmitsBottledLots_AndTheDuplicateReport()
    {
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 3);
        var s = Snapshot.Build(g);
        Assert.DoesNotContain(s["lots"]!.AsArray(), l => l!["phase"]!.GetValue<string>() == "Blended");
        Assert.False(s.ContainsKey("report"));
        Assert.Equal(3, s["reports"]!.AsArray().Count);
    }

    [Fact]
    public void HistoryRow_ShowsNothingYet_BeforeTheSeason_AndCountsBottles()
    {
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 2);
        while (g.Date.Month >= 4 || g.Date.Month < 1) g.Advance(20, stopAtAlerts: false);   // next January–March
        var now = VintageReport.HistoryRow(g, g.Vintage);
        Assert.Null(now["winkler"]);
        Assert.Null(now["rain"]);
        var first = VintageReport.HistoryRow(g, g.FirstVintage);
        Assert.Equal(g.WinesOf(g.FirstVintage).Sum(w => w.Bottles), first["bottles"]!.GetValue<int>());
    }

    [Fact]
    public void HistoryRow_PastVintageWithoutLots_IsNoHarvest_NotGrowing()
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2014 });
        g.Advance(400, stopAtAlerts: false);   // into the next year; the December rule picked the first Vintage
        Assert.Equal("No harvest", VintageReport.HistoryRow(g, g.FirstVintage - 1)["status"]!.GetValue<string>());
    }

    [Theory]
    [InlineData("mosel-seitental", 0.85)]
    [InlineData("cotedor-village", 0.85)]
    [InlineData("napa-bench", 0.95)]
    public void Snapshot_CarriesTheVintageShareRule(string plot, double share)
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = plot, PlantingYear = 2014 });
        Assert.Equal(share, Snapshot.Build(g)["region"]!["vintageShare"]!.GetValue<double>(), 6);
        Assert.Equal(share, Law.VintageShareRequired(g.Region.Id), 6);
    }
}
