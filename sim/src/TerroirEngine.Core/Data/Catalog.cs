using System.Text.Json;
using System.Text.Json.Serialization;

namespace TerroirEngine.Data;

public enum VarietyId { Riesling, Chardonnay, PinotNoir, CabernetSauvignon }
public enum RootstockId { OwnRooted, R3309C, SO4, R1103P, Fercal }
public enum TrainingSystem { Einzelpfahl, Guyot, Cordon }
public enum RowOrientation { NorthSouth, EastWest, DownSlope }
public enum Tier { Low = 0, Medium = 1, High = 2 }

/// <summary>Per-Variety parameters. Sources: docs/science/phenology.md §4/§8, ripening.md §9, canopy-and-yield.md §3.3–3.4,
/// disease.md §5.4. Values marked UNVERIFIED in the docs are design values until the science review.</summary>
public sealed record Variety(
    VarietyId Id, string Name, bool Red,
    double BudburstForcingGdd5,      // GDD>5 °C from 1 Jan to budburst (game simplification, calibrated) UNVERIFIED
    double GfvFlowering, double GfvVeraison, // Parker et al. 2013 (verified)
    double GsrF200,                  // thermal time base 0 °C from 1 Apr to 200 g/L (provisional, UNVERIFIED)
    double ClustersPerShoot, double BerriesPerCluster, double BerryWeightG,
    double BaseSet, double MillerandageProne, double CoulureProne,
    double TartaricVeraisonGL, double MalicRetention, double AnthocyaninMax, double IbmpBase,
    double TdnPotential, double ThiolPotential, double BotrytisCompactness, double TanninPotential,
    string SkinNote)
{
    public static readonly Variety Riesling = new(VarietyId.Riesling, "Riesling", false, 190, 1249, 2590, 2900,
        1.7, 90, 1.35, 0.50, 0.2, 0.2, 8.0, 0.7, 0, 0, 1.0, 0.12, 1.3, 0.2, "thin skins, compact bunches, high natural acidity");
    public static readonly Variety Chardonnay = new(VarietyId.Chardonnay, "Chardonnay", false, 150, 1217, 2547, 2720,
        1.7, 100, 1.4, 0.45, 0.8, 0.4, 7.2, 0.85, 0, 0, 0.15, 0.025, 1.2, 0.2, "neutral, winemaker-shaped; early budburst");
    public static readonly Variety PinotNoir = new(VarietyId.PinotNoir, "Pinot Noir", true, 158, 1219, 2511, 2700,
        1.7, 90, 1.2, 0.45, 0.5, 0.5, 7.2, 0.85, 0.65, 0, 0.1, 0.02, 1.4, 0.5, "thin skins, low colour (no acylated anthocyanins), rot-prone");
    public static readonly Variety CabernetSauvignon = new(VarietyId.CabernetSauvignon, "Cabernet Sauvignon", true, 200, 1299, 2689, 3100,
        1.5, 110, 1.05, 0.50, 0.2, 0.2, 6.8, 1.1, 1.4, 30, 0.1, 0.02, 0.8, 1.0, "small thick-skinned berries, loose bunches, late, pyrazine-prone");

    public static readonly IReadOnlyList<Variety> All = new[] { Riesling, Chardonnay, PinotNoir, CabernetSauvignon };
    public static Variety Get(VarietyId id) => All.First(v => v.Id == id);
}

/// <summary>Rootstocks (docs/science/soil-and-water.md §7).</summary>
public sealed record Rootstock(RootstockId Id, string Name, double RootDepthFactor, double DroughtShiftMPa, double VigourFactor,
    double MaxChlorosisIndex, bool PhylloxeraResistant, double PotassiumFactor, string Note)
{
    public static readonly Rootstock OwnRooted = new(RootstockId.OwnRooted, "Own-rooted", 1.0, 0.0, 1.0, 200, false, 1.0,
        "No phylloxera resistance: roots are destroyed over the years (only harmless in slate soils phylloxera avoids).");
    public static readonly Rootstock R3309C = new(RootstockId.R3309C, "3309C", 0.8, -0.2, 0.85, 10, true, 0.95,
        "Low-moderate vigour, early ripening; drought-susceptible and lime-sensitive (chlorosis index max 10).");
    public static readonly Rootstock SO4 = new(RootstockId.SO4, "SO4", 0.9, -0.1, 1.15, 30, true, 1.1,
        "Moderate-high vigour; tolerates 17 % active lime; can raise potassium and pH.");
    public static readonly Rootstock R1103P = new(RootstockId.R1103P, "1103 Paulsen", 1.25, 0.2, 1.15, 30, true, 1.05,
        "Deep, plunging roots: drought-tolerant and vigorous.");
    public static readonly Rootstock Fercal = new(RootstockId.Fercal, "Fercal", 1.0, 0.0, 1.0, 120, true, 1.0,
        "The limestone specialist: tolerates very high active lime (chlorosis index up to 120).");
    public static readonly IReadOnlyList<Rootstock> All = new[] { OwnRooted, R3309C, SO4, R1103P, Fercal };
    public static Rootstock Get(RootstockId id) => All.First(r => r.Id == id);
}

// ---------------------------------------------------------------------------------------------------- plots.json

public sealed class SoilData
{
    public string Texture { get; set; } = "";
    public double SandPct { get; set; }
    public double SiltPct { get; set; }
    public double ClayPct { get; set; }
    public double StonesPctVol { get; set; }
    public double RootingDepthCm { get; set; }
    public double TawMm { get; set; }
    public double PH { get; set; }
    public double ActiveLimePct { get; set; }
    public double OrganicMatterPct { get; set; }
    public string Drainage { get; set; } = "";
    /// <summary>Relative potassium supply of the soil (1 = average). Set per Region at load (UNVERIFIED calibration).</summary>
    public double SoilPotassiumFactor { get; set; } = 1.0;
}
public sealed class TopoData { public double AspectDeg { get; set; } public double SlopePct { get; set; } public double ElevationM { get; set; } }
public sealed class MicroData
{
    public double FrostPocket { get; set; }
    public double FogFrequency { get; set; }
    public double WindExposure { get; set; }
    public double RadiativeHeat { get; set; }
}
public sealed class BlockData
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public double AreaHa { get; set; }
    public SoilData Soil { get; set; } = new();
    public TopoData Topography { get; set; } = new();
    public MicroData Microclimate { get; set; } = new();
    public string Notes { get; set; } = "";
}
public sealed class PlotData
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Tier { get; set; } = "";
    public double Lat { get; set; }
    public double Lon { get; set; }
    public double ElevationM { get; set; }
    public double SlopePct { get; set; }
    public double AspectDeg { get; set; }
    public double AreaHa { get; set; }
    public string Classification { get; set; } = "";
    public double PricePerHaEur { get; set; }
    public string Mechanisation { get; set; } = "";
    public List<string> TrainingAllowed { get; set; } = new();
    public string Summary { get; set; } = "";
    public List<BlockData> Blocks { get; set; } = new();
    [JsonIgnore] public RegionData Region { get; set; } = null!;
    [JsonIgnore] public double Price => PricePerHaEur * AreaHa;
    [JsonIgnore] public bool Steep => SlopePct >= 30;
    [JsonIgnore] public int TierRank => Tier switch { "cheap" => 0, "mid-low" => 1, "mid-high" => 2, _ => 3 };
}
public sealed class RegionData
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Country { get; set; } = "";
    public string? EuZone { get; set; }
    public string AppellationSystem { get; set; } = "";
    public string WeatherReference { get; set; } = "";
    public List<PlotData> Plots { get; set; } = new();
    [JsonIgnore] public string WeatherFile => Id switch { "mosel" => "mosel", "cote-dor" => "cote_dor", _ => "napa" };
}
public sealed class PlotsFile
{
    public int SchemaVersion { get; set; }
    public double StartingCapitalEur { get; set; }
    public List<RegionData> Regions { get; set; } = new();
}

/// <summary>Loads the authored game data from the repo's data/ folder.</summary>
public sealed class GameData
{
    public string DataRoot { get; }
    public PlotsFile Plots { get; }
    public static double NapaSoilK = 1.2;
    public double StartingCapital => Plots.StartingCapitalEur;

    public GameData(string dataRoot)
    {
        DataRoot = dataRoot;
        var json = File.ReadAllText(Path.Combine(dataRoot, "plots.json"));
        Plots = JsonSerializer.Deserialize<PlotsFile>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
                ?? throw new InvalidDataException("plots.json");
        foreach (var r in Plots.Regions) foreach (var p in r.Plots)
        {
            p.Region = r;
            foreach (var bd in p.Blocks) bd.Soil.SoilPotassiumFactor = r.Id == "napa" ? NapaSoilK : 1.0;
        }
    }
    public RegionData Region(string id) => Plots.Regions.First(r => r.Id == id);
    public PlotData Plot(string id) => Plots.Regions.SelectMany(r => r.Plots).First(p => p.Id == id);

    /// <summary>Finds the repo data folder by walking up from a start directory.</summary>
    public static string LocateDataRoot(string startDir)
    {
        var d = new DirectoryInfo(startDir);
        while (d != null)
        {
            var candidate = Path.Combine(d.FullName, "data", "plots.json");
            if (File.Exists(candidate)) return Path.Combine(d.FullName, "data");
            d = d.Parent;
        }
        throw new DirectoryNotFoundException("Could not find data/plots.json above " + startDir);
    }
}
