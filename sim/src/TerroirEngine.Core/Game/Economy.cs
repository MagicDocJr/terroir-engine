using TerroirEngine.Data;
using TerroirEngine.Util;
using TerroirEngine.Vineyard;

namespace TerroirEngine.Game;

public sealed record LedgerEntry(DateOnly Date, string Category, double Amount, string Note);

/// <summary>Estate accounts. Cost figures from docs/science/economy.md (EUR at 2026 levels, a labelled game simplification).</summary>
public sealed class Ledger
{
    public List<LedgerEntry> Entries { get; } = new();
    public double Cash { get; private set; }
    public void Post(DateOnly date, string category, double amount, string note)
    {
        if (Math.Abs(amount) < 0.005) return;
        Cash += amount;
        // merge small daily running costs of the same category and day to keep the ledger readable
        if (Entries.Count > 0 && Entries[^1].Date == date && Entries[^1].Category == category && Entries[^1].Note == note)
            Entries[^1] = Entries[^1] with { Amount = Entries[^1].Amount + amount };
        else Entries.Add(new LedgerEntry(date, category, amount, note));
    }
    public Dictionary<string, double> ByCategory(DateOnly from, DateOnly to) =>
        Entries.Where(e => e.Date >= from && e.Date <= to).GroupBy(e => e.Category).ToDictionary(g => g.Key, g => Math.Round(g.Sum(e => e.Amount), 0));
}

public static class EconomyTables
{
    public static double LabourRate(string region) => region == "napa" ? 29 : 17;          // €/h seasonal hand labour
    public static double SkilledRate(string region) => region == "napa" ? 33 : region == "cote-dor" ? 22 : 23;
    /// <summary>Labour hours per ha per year for a mature vineyard, by work class (economy.md table; KTBL/UC Davis anchors).</summary>
    public static double LabourHoursPerHa(PlotData p)
    {
        if (p.Region.Id == "napa") return p.SlopePct >= 15 ? 450 : 300;
        if (p.Region.Id == "cote-dor") return 600;
        return p.SlopePct >= 50 ? 1200 : p.SlopePct >= 30 ? 450 : p.SlopePct >= 10 ? 300 : 225;
    }
    public static double PlantingCostPerHa(PlotData p, TrainingSystem training)
    {
        if (p.Region.Id == "napa") return p.SlopePct >= 15 ? 110000 : 75000;
        if (p.Region.Id == "cote-dor") return 41000;
        return training == TrainingSystem.Einzelpfahl || p.SlopePct >= 30 ? 55000 : 27500;
    }
    public static double MaterialsPerHaYear(string region) => region switch { "napa" => 2500, "cote-dor" => 2000, _ => 1500 };
    public static double SprayCostPerHaYear(Tier t, bool steep) => (t, steep) switch
    {
        (Tier.Low, false) => 1600, (Tier.Medium, false) => 2300, (Tier.High, false) => 3300,
        (Tier.Low, true) => 1000, (Tier.Medium, true) => 1500, _ => 2200,
    };
    public static int TypicalPasses(string region, Tier t) => region switch
    {
        "napa" => t switch { Tier.Low => 5, Tier.High => 10, _ => 7 },
        "cote-dor" => t switch { Tier.Low => 6, Tier.High => 12, _ => 9 },
        _ => t switch { Tier.Low => 6, Tier.High => 13, _ => 9 },
    };
    public static double TaxAndDuesPerHaYear(PlotData p) => p.Region.Id switch { "napa" => p.PricePerHaEur * 0.01 + 235, "cote-dor" => 700, _ => 250 };
    public static double Salary(string role, StaffLevel l) => role == "vineyard"
        ? l switch { StaffLevel.Junior => 38000, StaffLevel.Senior => 62000, _ => 48000 }
        : l switch { StaffLevel.Junior => 40000, StaffLevel.Senior => 68000, _ => 52000 };
    public static double SalaryMultiplier(string region) => region switch { "napa" => 1.70, "cote-dor" => 0.95, _ => 1.00 };
    /// <summary>Part-time share of a full post on a small estate (economy.md §7): vineyard max(0.25, hours ÷ 3,400), cellar max(0.25, hL ÷ 400).</summary>
    public static double StaffPost(string role, PlotData p, double wineHl) => role == "vineyard"
        ? Math.Max(0.25, LabourHoursPerHa(p) * p.AreaHa / 3400.0)
        : Math.Max(0.25, wineHl / 400.0);
    public static double CrewHoursPerDay(Tier t) => t switch { Tier.Low => 64, Tier.High => 160, _ => 96 };   // harvest crew
    public static double HarvestHoursPerKg(PlotData p, bool hand) => !hand ? 0.0006 : p.SlopePct >= 30 ? 0.035 : 0.015;
    public static double BottleCost(Tasting.Closure c) => c switch { Tasting.Closure.NaturalCork => 1.80, Tasting.Closure.TechnicalCork => 1.45, _ => 1.35 };
}
