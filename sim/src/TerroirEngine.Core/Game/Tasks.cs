namespace TerroirEngine.Game;

public enum TaskKind { Prune, LeafRemoval, GreenHarvest, CapManagement }
public enum TaskState { Open, Done, Delegated, Planned }

/// <summary>A dated job from the staff (CONTEXT.md: Task): the player does it on a demonstration vine or tank in 3D, decides it on the
/// dashboard, or lets the crew do it to the staff member's plan. Every option maps onto an existing setting (tasks-in-3d design §3).</summary>
public sealed class FieldTask
{
    public int Id { get; init; }
    public TaskKind Kind { get; init; }
    public string BlockId { get; init; } = "";
    public string LotId { get; init; } = "";
    public DateOnly Opened { get; init; }
    public DateOnly Due { get; init; }
    public TaskState Status { get; set; } = TaskState.Open;
    public string Choice { get; set; } = "";
    public string Timing { get; set; } = "";
    public string DecidedBy { get; set; } = "";
    public DateOnly? Decided { get; set; }
    public DateOnly? CrewUntil { get; set; }
    public bool CrewActive(DateOnly today) => CrewUntil != null && Decided != null && today >= Decided && today <= CrewUntil;
}

/// <summary>Player-facing words and options for each task kind. Explanations restate cited facts (canopy-and-yield.md, extraction-and-oak.md).</summary>
public static class TaskCatalog
{
    public sealed record Option(string Value, string Label, string Why);

    public static string Title(TaskKind k) => k switch { TaskKind.Prune => "Winter pruning", TaskKind.LeafRemoval => "Leaf removal", TaskKind.GreenHarvest => "Green harvest", _ => "Cap management" };
    public static string Verb(TaskKind k) => k switch { TaskKind.Prune => "prune this vine", TaskKind.LeafRemoval => "pull leaves on this vine", TaskKind.GreenHarvest => "thin this vine", _ => "work the cap" };
    public static string Where(TaskKind k) => k == TaskKind.CapManagement ? "hall" : "vineyard";
    /// <summary>Hours per hectare for the crew to finish the Block after the decision (visual only; UNVERIFIED design values).</summary>
    public static double CrewHoursPerHa(TaskKind k) => k switch { TaskKind.Prune => 80, TaskKind.LeafRemoval => 40, TaskKind.GreenHarvest => 30, _ => 0 };

    public static IReadOnlyList<Option> Options(TaskKind k) => k switch
    {
        TaskKind.Prune => new Option[]
        {
            new("Low", "Short cane · 6 buds per m²", "Fewer buds, fewer bunches: a smaller crop that ripens more fully and concentrates more. Burgundy growers prune short to stay inside the yield limits."),
            new("Balanced", "Medium cane · 8 buds per m²", "The usual compromise between crop size and ripeness."),
            new("High", "Long cane · 11 buds per m²", "A big crop. Over about 1 kg of fruit per m² of leaf area it ripens slowly and can taste diluted (Kliewer & Dokoozlian 2005)."),
        },
        TaskKind.LeafRemoval => new Option[]
        {
            new("Morning", "Morning side", "Opens the bunches to the gentle morning sun: they dry faster after dew and rain (less rot) without the afternoon heat that burns berries."),
            new("Afternoon", "Afternoon side", "More light and warmth on the fruit, but exposed bunches can pass 46 °C at the berry surface on hot afternoons and sunburn."),
            new("Both", "Both sides", "The most open fruit zone: driest bunches, most colour and aroma precursors, the highest sunburn risk."),
            new("None", "Leave the leaves", "A shaded fruit zone: fresher, greener flavours, more rot risk in wet years."),
        },
        TaskKind.GreenHarvest => new Option[]
        {
            new("0", "Keep every bunch", "The full crop stays on the vine."),
            new("1", "Drop about a fifth", "Cutting bunches at véraison lowers the yield and raises the leaf-area-to-fruit ratio: the rest ripens faster and more completely (Kliewer & Dokoozlian 2005)."),
            new("2", "Drop about two fifths", "A strong green harvest: the lowest yield, the most concentration. Also spares the vine's reserves for next year."),
        },
        _ => new Option[]
        {
            new("0", "Pump-over 2×/day", "Gentle: juice from the bottom is sprayed over the cap, which also aerates the yeast."),
            new("1", "Punch-down 2×/day", "Pushing the cap into the juice extracts more colour and tannin from the skins: traditional for Pinot Noir."),
            new("2", "Délestage + pump-over", "Draining the tank and pouring the juice back over the cap extracts strongly and removes some seeds (less harsh seed tannin)."),
            new("3", "Gentle, 1×/day", "The lightest extraction: a paler, softer wine."),
        },
    };

    public static string Label(TaskKind k, string value) => Options(k).FirstOrDefault(o => o.Value == value)?.Label ?? value;
}
