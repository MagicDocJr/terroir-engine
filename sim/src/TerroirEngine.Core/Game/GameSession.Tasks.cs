using TerroirEngine.Util;
using TerroirEngine.Vineyard;
using TerroirEngine.Winery;

namespace TerroirEngine.Game;

public sealed partial class GameSession
{
    public List<FieldTask> Tasks { get; } = new();
    private int _taskId;

    /// <summary>The staff member's plan for a task: the current setting (so an ignored task changes nothing).</summary>
    public string TaskPlan(FieldTask t)
    {
        var b = Blocks.FirstOrDefault(x => x.Data.Id == t.BlockId);
        return t.Kind switch
        {
            TaskKind.Prune => b!.BudLoad.ToString(),
            TaskKind.LeafRemoval => b!.LeafSide.ToString(),
            TaskKind.GreenHarvest => b!.CropThinning.ToString(),
            _ => (Lots.FirstOrDefault(l => l.Id == t.LotId)?.Choices["Cap management"] ?? 0).ToString(),
        };
    }

    private FieldTask OpenTask(TaskKind kind, string blockId, string lotId, DateOnly due)
    {
        var t = new FieldTask { Id = ++_taskId, Kind = kind, BlockId = blockId, LotId = lotId, Opened = Date, Due = due };
        Tasks.Add(t);
        return t;
    }

    /// <summary>Opens the pruning tasks of the current Vintage (15 January; the first Vintage's at game start).</summary>
    private void OpenPruningTasks()
    {
        var due = new DateOnly(Date.Year, 3, 1);
        var opened = Blocks.Select(b => OpenTask(TaskKind.Prune, b.Data.Id, "", due)).ToList();
        PostTaskMessage(TaskKind.Prune, opened);
    }

    /// <summary>Daily: open tasks whose moment has come, close tasks whose due date (or event) has passed.</summary>
    private void UpdateTasks()
    {
        if (Phase != GamePhase.Running) return;
        if (Date.Month == 1 && Date.Day == 15 && Date.Year > FirstVintage && Gate($"tasks-prune-{Date.Year}")) OpenPruningTasks();
        var newLeaf = new List<FieldTask>(); var newThin = new List<FieldTask>(); var newCap = new List<FieldTask>();
        foreach (var b in Blocks)
        {
            if (b.FruitSet == Date && !Tasks.Any(t => t.Kind == TaskKind.LeafRemoval && t.BlockId == b.Data.Id && t.Opened.Year == Date.Year))
                newLeaf.Add(OpenTaskOn(TaskKind.LeafRemoval, b.Data.Id, "", b.FruitSet.Value, b.FruitSet.Value.AddDays(25)));
            if (b.Veraison == Date && !b.Harvested && !Tasks.Any(t => t.Kind == TaskKind.GreenHarvest && t.BlockId == b.Data.Id && t.Opened.Year == Date.Year))
                newThin.Add(OpenTaskOn(TaskKind.GreenHarvest, b.Data.Id, "", b.Veraison.Value, b.Veraison.Value.AddDays(21)));
        }
        foreach (var l in Lots.Where(l => l.Red && l.FermentStart != null && l.FermentStart.Value >= Date.AddDays(-1)))
            if (!Tasks.Any(t => t.Kind == TaskKind.CapManagement && t.LotId == l.Id))
                newCap.Add(OpenTaskOn(TaskKind.CapManagement, l.BlockId, l.Id, l.FermentStart!.Value, l.FermentStart.Value.AddDays(2)));
        if (newLeaf.Count > 0) PostTaskMessage(TaskKind.LeafRemoval, newLeaf);
        if (newThin.Count > 0) PostTaskMessage(TaskKind.GreenHarvest, newThin);
        if (newCap.Count > 0) PostTaskMessage(TaskKind.CapManagement, newCap);
        foreach (var t in Tasks.Where(t => t.Status == TaskState.Open))
        {
            var b = Blocks.FirstOrDefault(x => x.Data.Id == t.BlockId);
            bool closed = Date >= t.Due
                || (t.Kind == TaskKind.Prune && b?.Budburst != null)
                || (t.Kind == TaskKind.GreenHarvest && (b!.Harvested || b.Picking));
            if (!closed) continue;
            t.Status = TaskState.Planned; t.Choice = TaskPlan(t); t.DecidedBy = "crew"; t.Decided = Date;
            bool pickedFirst = t.Kind == TaskKind.GreenHarvest && (b!.Harvested || b.Picking);
            if (!pickedFirst) t.CrewUntil = Date.AddDays(CrewDays(t) - 1);   // the crew does the work to the plan
        }
    }

    private FieldTask OpenTaskOn(TaskKind kind, string blockId, string lotId, DateOnly opened, DateOnly due)
    {
        var t = new FieldTask { Id = ++_taskId, Kind = kind, BlockId = blockId, LotId = lotId, Opened = opened, Due = due };
        Tasks.Add(t);
        return t;
    }

    private int CrewDays(FieldTask t)
    {
        if (t.Kind == TaskKind.CapManagement) return 1;
        var b = Blocks.First(x => x.Data.Id == t.BlockId);
        return (int)M.Clamp(Math.Ceiling(b.AreaHa * TaskCatalog.CrewHoursPerHa(t.Kind) / EconomyTables.CrewHoursPerDay(Ctx.Labour)), 1, 10);
    }

    /// <summary>Applies an option through the existing setting (no new physics).</summary>
    private void ApplyTaskOption(FieldTask t, string value, string timing)
    {
        var b = Blocks.FirstOrDefault(x => x.Data.Id == t.BlockId);
        switch (t.Kind)
        {
            case TaskKind.Prune: b!.BudLoad = Enum.Parse<BudLoad>(value); break;
            case TaskKind.LeafRemoval:
                b!.LeafSide = Enum.Parse<LeafRemovalSide>(value);
                b.LeafTiming = timing == "Late" ? LeafRemovalTiming.Late : LeafRemovalTiming.Early;
                break;
            case TaskKind.GreenHarvest:
                b!.CropThinning = Math.Clamp(int.Parse(value), 0, 2);
                if (b.Veraison != null && !b.Harvested) VineyardModel.ApplyCropThinning(b);
                break;
            case TaskKind.CapManagement:
                var lot = Lots.First(l => l.Id == t.LotId);
                lot.Choices["Cap management"] = Math.Clamp(int.Parse(value), 0, 3);
                break;
        }
    }

    private void Decide(FieldTask t, TaskState status, string value, string timing, string by)
    {
        ApplyTaskOption(t, value, timing);
        t.Status = status; t.Choice = value; t.Timing = timing; t.DecidedBy = by; t.Decided = Date;
        t.CrewUntil = Date.AddDays(CrewDays(t) - 1);
    }

    /// <summary>Command `task`: A = task id or "kind:Prune"; B = "do" | "delegate"; C = option value; D = timing ("Late"); E = "dashboard" when sent from the dashboard panel.</summary>
    private void TaskCommand(Command c)
    {
        var targets = c.A.StartsWith("kind:")
            ? Tasks.Where(t => t.Status == TaskState.Open && t.Kind.ToString() == c.A[5..]).ToList()
            : Tasks.Where(t => t.Status == TaskState.Open && t.Id.ToString() == c.A).ToList();
        foreach (var t in targets)
        {
            if (c.B == "delegate") Decide(t, TaskState.Delegated, TaskPlan(t), t.Kind == TaskKind.LeafRemoval ? Blocks.First(b => b.Data.Id == t.BlockId).LeafTiming.ToString() : "", "crew");
            else if (c.B == "do" && TaskCatalog.Options(t.Kind).Any(o => o.Value == c.C)) Decide(t, TaskState.Done, c.C, c.D, c.E == "dashboard" ? "dashboard" : "3d");
        }
    }

    /// <summary>A dashboard setting on a Block or Lot with an open task of the matching kind completes it.</summary>
    private void CompleteFromDashboard(TaskKind kind, string blockId, string lotId, string value, string timing)
    {
        var t = Tasks.FirstOrDefault(x => x.Status == TaskState.Open && x.Kind == kind && (lotId != "" ? x.LotId == lotId : x.BlockId == blockId));
        if (t == null) return;
        t.Status = TaskState.Done; t.Choice = value; t.Timing = timing; t.DecidedBy = "dashboard"; t.Decided = Date;
        t.CrewUntil = Date.AddDays(CrewDays(t) - 1);
    }

    private void PostTaskMessage(TaskKind kind, List<FieldTask> opened)
    {
        var first = opened[0];
        string blocks = string.Join(", ", opened.Select(t => kind == TaskKind.CapManagement ? $"Lot {t.LotId}" : $"Block {t.BlockId}"));
        string due = Dates.Short(first.Due);
        string plan = string.Join(", ", opened.Select(t => $"{(kind == TaskKind.CapManagement ? t.LotId : t.BlockId)}: {TaskCatalog.Label(kind, TaskPlan(t))}"));
        string role = kind == TaskKind.CapManagement ? "cellar" : kind == TaskKind.Prune && !MentorRetired ? "mentor" : "vineyard";
        (string subject, string body, string why, string msgKind) = kind switch
        {
            TaskKind.Prune => ($"Winter pruning: {blocks} (due {due})",
                $"January is pruning time. The number of buds left per vine sets this year's crop, and how well it ripens.\n\n• Short cane (Low, ≈ 6 buds per m²): fewer, riper grapes.\n• Medium cane (Balanced, ≈ 8): the usual compromise.\n• Long cane (High, ≈ 11): a big crop that ripens slowly and can taste diluted.\n\n{(Region.Id == "cote-dor" ? "Remember: Village and Premier Cru rules allow at most 8 buds per vine." : Region.Id == "mosel" ? "Steep Einzelpfahl vines carry two bows; the buds are shared between them." : "On the valley floor vigour is high: too few buds and the canopy runs wild.")}\n\nWalk to a Block and prune its marked vine yourself; the crew then prunes the rest the same way. Or let the crew prune to the plan ({plan}).",
                "Bud load balances yield against ripening capacity: over ~1 kg of fruit per m² of leaf area ripens poorly (Kliewer & Dokoozlian 2005).", "task-prune"),
            TaskKind.LeafRemoval => ($"Leaf removal: {blocks} (due {due})",
                $"The fruit has set. Pulling the leaves around the bunches now opens the fruit zone.\n\n• Morning side: bunches dry fast after dew and rain, without the afternoon heat.\n• Afternoon side: more warmth, but a sunburn risk in hot weather.\n• Both sides, or none.\nYou can also leave it until véraison (late leaf removal).\n\nDo the marked vine yourself, or let the crew keep the plan ({plan}).",
                "Leaf removal between fruit set and bunch closure lets the berries acclimatise to the sun; late removal is gentler on colour but riskier for sunburn.", "task-leaves"),
            TaskKind.GreenHarvest => ($"Green harvest: {blocks} (due {due})",
                $"Véraison has begun. This is the moment to decide how much crop the vines should ripen: cutting bunches now helps the rest ripen more completely.\n\nThin the marked vine yourself (the crew follows), or keep every bunch ({plan}).",
                "Green harvesting lowers yield and raises the leaf-area-to-fruit ratio; the remaining bunches ripen faster and more completely (Kliewer & Dokoozlian 2005).", "task-thinning"),
            _ => ($"Cap management: {blocks} (due {due})",
                $"The red fermentation has started and the skins have risen into a cap on top of the juice. How we work the cap decides how much colour and tannin we extract.\n\nWork the cap on the tank yourself, or keep my plan ({plan}).",
                "Pump-overs are gentle; punch-downs extract more (traditional for Pinot Noir); délestage extracts strongly and removes some seeds.", "task-cap"),
        };
        var m = Post(role, subject, body, why, "high", msgKind, stop: true, blockId: kind == TaskKind.CapManagement ? "" : first.BlockId);
        m.Actions.Add(("Do it in 3D", "task3d", first.Id.ToString()));
        m.Actions.Add(("Let the crew do it", "taskcrew", kind.ToString()));
        m.Actions.Add((kind == TaskKind.CapManagement ? "Open Winery" : "Open Plot & Blocks", "goto", kind == TaskKind.CapManagement ? "winery" : "plot"));
    }
}
