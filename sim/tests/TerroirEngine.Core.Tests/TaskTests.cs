using TerroirEngine.Data;
using TerroirEngine.Game;
using TerroirEngine.Vineyard;
using TerroirEngine.Winery;

namespace TerroirEngine.Tests;

public class TaskTests
{
    private static GameSession New(string plot = "mosel-seitental", int planting = 2014) => new(Fixture.Data, new GameSetup { PlotId = plot, PlantingYear = planting });
    private static void Until(GameSession g, Func<bool> cond, int max = 800) { int n = 0; while (!cond() && n++ < max) g.Advance(1, stopAtAlerts: false); }

    [Fact]
    public void PruningTasks_OpenAtGameStart_OnePerBlock_DueFirstOfMarch()
    {
        var g = New();
        var prune = g.Tasks.Where(t => t.Kind == TaskKind.Prune).ToList();
        Assert.Equal(g.Blocks.Count, prune.Count);
        Assert.All(prune, t => { Assert.Equal(TaskState.Open, t.Status); Assert.Equal(new DateOnly(g.FirstVintage, 3, 1), t.Due); });
        Assert.Contains(g.Inbox, m => m.Kind == "task-prune");
    }

    [Fact]
    public void GuyotPruningOptions_DifferAtLowDensity_DoubleGuyotAboveTwelveBuds()
    {
        // Carneros plants Guyot at 3,800 vines/ha: 6/8/11 buds per m² are 16/21/29 buds per vine; a single-cane cap of
        // 16 made all three the same, a double Guyot (two canes of up to 12) keeps them apart up to 24
        var g = New("napa-carneros", 2014);
        var b = g.Blocks.First(x => x.Planting.Training == TrainingSystem.Guyot);
        var buds = new[] { BudLoad.Low, BudLoad.Balanced, BudLoad.High }.Select(l => VineyardModel.BudsPerVine(b, l)).ToList();
        Assert.True(buds[0] < buds[1] && buds[1] < buds[2], string.Join(", ", buds));
        Assert.True(buds[2] <= 24);
    }

    [Fact]
    public void DoingNothing_AppliesThePlan_AndChangesNothing()
    {
        var g = New("cotedor-village", 2013);
        var before = g.Blocks.Select(b => b.BudLoad).ToList();
        Until(g, () => g.Date >= new DateOnly(g.FirstVintage, 3, 2));
        Assert.All(g.Tasks.Where(t => t.Kind == TaskKind.Prune), t => Assert.Equal(TaskState.Planned, t.Status));
        Assert.Equal(before, g.Blocks.Select(b => b.BudLoad).ToList());
    }

    [Fact]
    public void DoingATask_AppliesTheOption_AndStartsTheCrew()
    {
        var g = New();
        var t = g.Tasks.First(x => x.Kind == TaskKind.Prune);
        g.Apply(new Command { Type = "task", A = t.Id.ToString(), B = "do", C = "Low" });
        Assert.Equal(TaskState.Done, t.Status);
        Assert.Equal("3d", t.DecidedBy);
        Assert.Equal(BudLoad.Low, g.Blocks.First(b => b.Data.Id == t.BlockId).BudLoad);
        Assert.True(t.CrewActive(g.Date));
    }

    [Fact]
    public void Delegating_AppliesThePlan_ForEveryOpenTaskOfTheKind()
    {
        var g = New();
        g.Apply(new Command { Type = "task", A = "kind:Prune", B = "delegate" });
        Assert.All(g.Tasks.Where(t => t.Kind == TaskKind.Prune), t => { Assert.Equal(TaskState.Delegated, t.Status); Assert.Equal("crew", t.DecidedBy); });
    }

    [Fact]
    public void DashboardSetting_CompletesTheOpenTask()
    {
        var g = New();
        var b = g.Blocks[0];
        g.Apply(new Command { Type = "block", A = b.Data.Id, B = "budload", C = "High" });
        var t = g.Tasks.First(x => x.Kind == TaskKind.Prune && x.BlockId == b.Data.Id);
        Assert.Equal(TaskState.Done, t.Status);
        Assert.Equal("dashboard", t.DecidedBy);
        Assert.Equal("High", t.Choice);
    }

    [Fact]
    public void DashboardChange_AfterDecision_JustChangesTheSetting()
    {
        var g = New();
        var t = g.Tasks.First(x => x.Kind == TaskKind.Prune);
        g.Apply(new Command { Type = "task", A = t.Id.ToString(), B = "do", C = "Low" });
        g.Apply(new Command { Type = "block", A = t.BlockId, B = "budload", C = "High" });
        Assert.Equal(TaskState.Done, t.Status);
        Assert.Equal("Low", t.Choice);                // the task records what was done at the vine
        Assert.Equal(BudLoad.High, g.Blocks.First(b => b.Data.Id == t.BlockId).BudLoad);
    }

    [Fact]
    public void LeafRemoval_OpensAtFruitSet_GreenHarvest_AtVeraison()
    {
        var g = New();
        Until(g, () => g.Blocks.All(b => b.Veraison != null));
        foreach (var b in g.Blocks)
        {
            var lr = g.Tasks.Single(t => t.Kind == TaskKind.LeafRemoval && t.BlockId == b.Data.Id);
            Assert.Equal(b.FruitSet!.Value, lr.Opened);
            Assert.Equal(b.FruitSet!.Value.AddDays(25), lr.Due);
            var gh = g.Tasks.Single(t => t.Kind == TaskKind.GreenHarvest && t.BlockId == b.Data.Id);
            Assert.Equal(b.Veraison!.Value, gh.Opened);
        }
    }

    [Fact]
    public void LeafRemoval_Later_SetsLateTiming()
    {
        var g = New();
        Until(g, () => g.Tasks.Any(t => t.Kind == TaskKind.LeafRemoval));
        var t = g.Tasks.First(x => x.Kind == TaskKind.LeafRemoval);
        g.Apply(new Command { Type = "task", A = t.Id.ToString(), B = "do", C = "Afternoon", D = "Late" });
        var b = g.Blocks.First(x => x.Data.Id == t.BlockId);
        Assert.Equal(LeafRemovalSide.Afternoon, b.LeafSide);
        Assert.Equal(LeafRemovalTiming.Late, b.LeafTiming);
    }

    [Fact]
    public void GreenHarvest_ClosesAtHarvest()
    {
        var g = New();
        Until(g, () => g.Tasks.Any(t => t.Kind == TaskKind.GreenHarvest));
        var t = g.Tasks.First(x => x.Kind == TaskKind.GreenHarvest);
        g.Apply(new Command { Type = "harvest", A = t.BlockId, B = "hand", C = "Table" });
        Until(g, () => g.Blocks.First(b => b.Data.Id == t.BlockId).Harvested, 60);
        Assert.Equal(TaskState.Planned, t.Status);
        Assert.Equal(0, g.Blocks.First(b => b.Data.Id == t.BlockId).CropThinning);
    }

    [Fact]
    public void CapManagement_OnlyForRedLots()
    {
        var g = New("cotedor-village", 2013);   // Pinot Noir (red) and Chardonnay (white) Blocks
        Until(g, () => g.Blocks.All(b => b.Veraison != null));
        foreach (var b in g.Blocks) g.Apply(new Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Table" });
        Until(g, () => g.Lots.Count == g.Blocks.Count && g.Lots.All(l => l.FermentStart != null), 120);
        var cap = g.Tasks.Where(t => t.Kind == TaskKind.CapManagement).ToList();
        Assert.Equal(g.Lots.Count(l => l.Red), cap.Count);
        Assert.All(cap, t => Assert.True(g.Lots.First(l => l.Id == t.LotId).Red));
        var c = cap[0];
        g.Apply(new Command { Type = "task", A = c.Id.ToString(), B = "do", C = "1" });
        Assert.Equal(1, g.Lots.First(l => l.Id == c.LotId).Choices["Cap management"]);
    }

    [Fact]
    public void Tasks_ReplayExactly_TwoVintagesIn()
    {
        var g = Fixture.PlayVintages("mosel-terrassen", 2016, 86, vintages: 2, onStart: s =>
        {
            var t = s.Tasks.First(x => x.Kind == TaskKind.Prune);
            s.Apply(new Command { Type = "task", A = t.Id.ToString(), B = "do", C = "Low" });
        });
        var g2 = GameSession.Load(Fixture.Data, g.Save());
        Assert.Equal(Snapshot.Json(g), Snapshot.Json(g2));
        Assert.Equal(g.Tasks.Count, g2.Tasks.Count);
        Assert.True(g.Tasks.Count(t => t.Kind == TaskKind.Prune) >= 2 * g.Blocks.Count);
    }
    [Fact]
    public void Snapshot_ListsOpenTasks_WithOptionsAndPlan()
    {
        var g = New();
        var s = Snapshot.Build(g);
        var tasks = s["tasks"]!.AsArray();
        Assert.Equal(g.Blocks.Count, tasks.Count);
        var t = tasks[0]!;
        Assert.Equal("Prune", t["kind"]!.GetValue<string>());
        Assert.Equal("vineyard", t["where"]!.GetValue<string>());
        Assert.Equal(3, t["options"]!.AsArray().Count);
        Assert.False(string.IsNullOrEmpty(t["options"]![0]!["why"]!.GetValue<string>()));
        Assert.Equal(g.Blocks[0].BudLoad.ToString(), t["plan"]!.GetValue<string>());
        var buds = t["options"]!.AsArray().Select(o => o!["buds"]!.GetValue<double>()).ToList();   // buds per vine for each pruning option
        Assert.True(buds[0] < buds[2] && buds[0] <= buds[1] && buds[1] <= buds[2]);   // the training system caps buds per vine (Guyot 16)
        g.Apply(new Command { Type = "task", A = t["id"]!.GetValue<int>().ToString(), B = "do", C = "Low" });
        var after = Snapshot.Build(g)["tasks"]!.AsArray().First(x => x!["id"]!.GetValue<int>() == t["id"]!.GetValue<int>())!;
        Assert.Equal("Done", after["status"]!.GetValue<string>());
        Assert.True(after["crewActive"]!.GetValue<bool>());
    }

    [Fact]
    public void CoteDor_FirstPruningMessage_StatesTheMentorsLowPlan()
    {
        var g = New("cotedor-village", 2013);
        var m = g.Inbox.Single(x => x.Kind == "task-prune");
        Assert.Contains("Fewer buds", m.Body);
        Assert.DoesNotContain("Standard buds", m.Body);
    }

    [Fact]
    public void CoteDor_PruningOverTheBudLimit_IsWarned_AndDeclassifies()
    {
        // Village AOC allows 8 buds per vine (law.md §3): at 10,000 vines/ha High (11 buds per m²) is 11 buds per vine
        var g = New("cotedor-village", 2013);
        var t = g.Tasks.First(x => x.Kind == TaskKind.Prune);
        Assert.Null(g.PruneOption(t.BlockId, "Balanced").Warning);
        Assert.Contains("Bourgogne", g.PruneOption(t.BlockId, "High").Warning);
        Assert.Contains("at most 8 buds", g.Inbox.Single(x => x.Kind == "task-prune").Body);
        var opt = Snapshot.Build(g)["tasks"]!.AsArray().First(x => x!["id"]!.GetValue<int>() == t.Id)!["options"]!.AsArray().First(o => o!["value"]!.GetValue<string>() == "High")!;
        Assert.NotNull(opt["warning"]);
        Assert.Contains("one cane", opt["detail"]!.GetValue<string>());
        // no limit outside Village and Premier Cru
        var n = New("napa-carneros", 2014);
        Assert.Null(n.PruneOption(n.Tasks.First(x => x.Kind == TaskKind.Prune).BlockId, "High").Warning);
    }

    [Fact]
    public void PruneDetail_SplitsBudsTheWayTheVineCarriesThem()
    {
        Assert.Equal("10 buds on one cane", TaskCatalog.PruneDetail(TrainingSystem.Guyot, 10));
        Assert.Equal("21 buds: two canes of 11 + 10 (double Guyot)", TaskCatalog.PruneDetail(TrainingSystem.Guyot, 21));
        Assert.Equal("8 spurs of 2 buds", TaskCatalog.PruneDetail(TrainingSystem.Cordon, 16));
        Assert.Equal("14 buds: two bows of 7 + 7", TaskCatalog.PruneDetail(TrainingSystem.Einzelpfahl, 14));
    }

    [Fact]
    public void GreenHarvest_CannotThinABlockBeingPicked()
    {
        var g = New();
        Until(g, () => g.Tasks.Any(t => t.Kind == TaskKind.GreenHarvest));
        var t = g.Tasks.First(x => x.Kind == TaskKind.GreenHarvest);
        var b = g.Blocks.First(x => x.Data.Id == t.BlockId);
        g.Apply(new Command { Type = "harvest", A = t.BlockId, B = "hand", C = "Table" });
        double berries = b.BerriesPerVine;
        Assert.Equal(TaskState.Planned, t.Status);                       // the harvest order closes it at once
        g.Apply(new Command { Type = "task", A = t.Id.ToString(), B = "do", C = "2" });
        g.Apply(new Command { Type = "block", A = t.BlockId, B = "thinning", C = "2" });
        Assert.Equal(berries, b.BerriesPerVine);
    }

    [Fact]
    public void LeafTiming_OnTheDashboard_CompletesTheTask_AndSnapshotCarriesThePlanTiming()
    {
        var g = New();
        Until(g, () => g.Tasks.Any(t => t.Kind == TaskKind.LeafRemoval));
        var t = g.Tasks.First(x => x.Kind == TaskKind.LeafRemoval);
        string PlanTiming() => Snapshot.Build(g)["tasks"]!.AsArray().First(x => x!["id"]!.GetValue<int>() == t.Id)!["planTiming"]!.GetValue<string>();
        Assert.Equal(g.Blocks.First(b => b.Data.Id == t.BlockId).LeafTiming.ToString(), PlanTiming());
        g.Apply(new Command { Type = "block", A = t.BlockId, B = "leaftiming", C = "Late" });
        Assert.Equal(TaskState.Done, t.Status);
        Assert.Equal("Late", t.Timing);
        Assert.Equal("Late", PlanTiming());   // crew-active tasks stay in the list and show the timing now set
    }

    [Theory]
    [InlineData("napa-bench", "spur")]          // Cordon: spur pruning
    [InlineData("mosel-terrassen", "bow")]      // Einzelpfahl: arched bows
    [InlineData("mosel-seitental", "cane")]     // Guyot: cane pruning (one or two canes, in the per-Block detail)
    public void PruningOptions_UseTheTrainingSystemsWords(string plot, string word)
    {
        var g = New(plot, 2014);
        var opts = Snapshot.Build(g)["tasks"]!.AsArray()[0]!["options"]!.AsArray();
        Assert.All(opts, o => Assert.Contains(word, o!["label"]!.GetValue<string>() + " " + o["detail"]!.GetValue<string>(), StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void LaterOpeningsOfTheSameKind_DoNotStopTimeAgain()
    {
        var g = New("napa-carneros", 2016);
        Until(g, () => g.Blocks.All(b => b.Veraison != null) && g.Date.Year == g.FirstVintage && g.Blocks.All(b => b.Veraison!.Value.AddDays(3) < g.Date));
        foreach (var kind in new[] { "task-leaves", "task-thinning" })
            Assert.True(g.Inbox.Count(m => m.Kind == kind && m.Stop) <= 1, $"{kind} stopped time {g.Inbox.Count(m => m.Kind == kind && m.Stop)} times");
    }

    [Fact]
    public void CrewButton_DelegatesOnlyThatMessagesTasks()
    {
        var g = New();
        var m = g.Inbox.Single(x => x.Kind == "task-prune");
        var arg = m.Actions.First(a => a.Action == "taskcrew").Arg;
        Assert.StartsWith("ids:", arg);
        var ids = arg[4..].Split(',').Select(int.Parse).ToList();
        g.Apply(new Command { Type = "task", A = arg, B = "delegate" });
        Assert.All(g.Tasks.Where(t => ids.Contains(t.Id)), t => Assert.Equal(TaskState.Delegated, t.Status));
    }

    [Fact]
    public void Tasks_FullListReplaysExactly()
    {
        var g = Fixture.PlayVintages("mosel-terrassen", 2016, 86, vintages: 2);
        var g2 = GameSession.Load(Fixture.Data, g.Save());
        string Dump(GameSession s) => string.Join("\n", s.Tasks.Select(t => $"{t.Id} {t.Kind} {t.BlockId} {t.LotId} {t.Opened} {t.Due} {t.Status} {t.Choice} {t.Timing} {t.DecidedBy} {t.Decided} {t.CrewUntil}"));
        Assert.Equal(Dump(g), Dump(g2));
    }
}


