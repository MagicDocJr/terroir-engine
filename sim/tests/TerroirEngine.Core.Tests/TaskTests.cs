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
}
