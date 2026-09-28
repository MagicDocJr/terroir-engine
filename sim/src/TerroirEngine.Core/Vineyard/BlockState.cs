using TerroirEngine.Data;
using TerroirEngine.Weather;

namespace TerroirEngine.Vineyard;

public enum Stage { Dormant, Budburst, Shoots, Flowering, FruitSet, BunchClosure, Veraison, Ripening, Harvested, LeafFall }
public enum BudLoad { Low, Balanced, High }
public enum LeafRemovalSide { None, Morning, Afternoon, Both }
public enum LeafRemovalTiming { Early, Late }

/// <summary>What was planted on a Block (Planting, CONTEXT.md).</summary>
public sealed class PlantingChoice
{
    public VarietyId Variety { get; set; } = VarietyId.Riesling;
    public RootstockId Rootstock { get; set; } = RootstockId.SO4;
    public TrainingSystem Training { get; set; } = TrainingSystem.Guyot;
    public RowOrientation Rows { get; set; } = RowOrientation.NorthSouth;
    public int DensityVinesHa { get; set; } = 5000;
}

public sealed class LatentCohort { public double Progress; public double Leaf; public double Bunch; public int Countdown; }

public sealed class DiseaseState
{
    // downy mildew
    public bool DownyPrimarySeason;
    public DateOnly? DownyFirstInfection;
    public List<LatentCohort> DownyLatent { get; } = new();
    public double DownyLeaf;       // % leaf area with sporulating lesions
    public double DownyBunch;      // fraction of bunches lost
    public double DownySporangia;  // relative secondary source available for the next wet period
    public double DownyRiskToday;  // 0..100 for the dashboard
    // powdery mildew
    public bool PowderyStarted;
    public double PowderyIndex;    // UC Davis risk index 0..100
    public List<LatentCohort> PowderyPending { get; } = new();
    public double PowderyLeaf;
    public double PowderyBunch;    // fraction of berries infected (→ cracking, off-flavour)
    // botrytis
    public double BotrytisLatentFlowering;
    public double GreyRot;         // fraction of fruit
    public double NobleRot;        // fraction of fruit
    public List<LatentCohort> BotrytisPending { get; } = new(); // candidate infections awaiting the noble/grey decision
    public double BotrytisRiskToday;
    public double Cracking;        // 0..1 berry splitting index
    // protection
    public double Protection;      // current mildew fungicide cover 0..1
    public DateOnly? LastSpray;
    public double RainSinceSpray;
    public int SpraysThisSeason;
    public DateOnly? NextSprayDue;
}

/// <summary>Daily state of one Block through the year. All quantities per vine unless stated.</summary>
public sealed class BlockState
{
    public PlotData Plot { get; }
    public BlockData Data { get; }
    public BlockClimate Climate { get; }
    public PlantingChoice Planting { get; set; } = new();
    public int PlantingYear { get; set; }
    public bool Planted { get; set; }
    public double VineSurvival { get; set; } = 1.0;

    // explicit per-Block choices (spec §5.2)
    public BudLoad BudLoad { get; set; } = BudLoad.Balanced;
    public LeafRemovalSide LeafSide { get; set; } = LeafRemovalSide.Morning;
    public LeafRemovalTiming LeafTiming { get; set; } = LeafRemovalTiming.Early;
    public bool PruningDone { get; set; }
    public int CropThinning { get; set; }          // 0 none, 1 light (−20 %), 2 heavy (−40 %) — green harvest at véraison
    public bool ThinningApplied { get; set; }

    // season state
    public int SeasonYear { get; set; }
    public Stage Stage { get; set; } = Stage.Dormant;
    public double Chill, NextSeasonChill, Forcing, Gfv, Gsr, Gdd10SinceBudburst, TtSinceVeraison, SEff, Winkler, Huglin, SeasonTempSum; public int SeasonTempDays;
    public DateOnly? Budburst, Flowering, FruitSet, BunchClosure, Veraison, LeafFall;
    public double BudsPerVine, Shoots, LeafAreaPerVine, Lai, Exposure = 0.45, ExposureEarlySum, ExposureLateSum; public int ExposureEarlyDays, ExposureLateDays;
    public double FrostShootLoss, FrostDamageToday;
    public DateOnly? LastFrostEvent;
    public double FlowerTempSum, FlowerRainDays, FlowerDays, SetFraction = -1, MillerandageShare;
    public double BerriesPerVine, BerryWeight, BerryWeightPeak, BerryWeightVeraison, SugarPerBerry, MalicPerBerry, TartaricPerBerry;
    public double LoadingFraction, SeedMaturity, SkinExtractability, Anthocyanin, IbmpVeraison, Ibmp, TdnPotential, ThiolPotential, PotassiumGL;
    public double PreVeraisonTempSum; public int PreVeraisonDays;
    public double StressPreSum; public int StressPreDays; public double StressPostSum; public int StressPostDays; public int SevereStressDays;
    public double SunburnFraction, AcclimatedFraction;
    public DiseaseState Disease { get; set; } = new();
    public double Chlorosis;
    // multi-vintage carry-over (canopy-and-yield.md §3.2 and §3.6; disease.md). All 1.0 until the first cropping season closes.
    public double Fruitfulness { get; set; } = 1.0;       // this season's bunches-per-shoot factor, set by last season's flowering weather
    public double FruitfulnessNext { get; set; } = 1.0;   // being set this season, 25 days after flowering
    public double Reserves { get; set; } = 1.0;           // carbohydrate reserves the vine went into this season with
    /// <summary>1991–2020 mean daily Tmean for this Block's microclimate, indexed by day of year (1–366). Null in bare model tests.</summary>
    public double[]? ClimNormalTmean { get; set; }
    public double FlowerWindowAnomSum, FlowerWindowExpSum; public int FlowerWindowDays;
    public double LeafAreaPeak, DownyLeafPeak, PowderyLeafPeak;
    public double EarlyDefoliationPeak;   // mildew leaf loss before harvest or leaf fall: what costs the vine its reserves (§3.6)
    // water
    public double Taw, Raw, Dr, PsiPd, PsiStem = -0.3, StressIndex, IrrigationMmSeason, Et0Season, RainSeason;
    // harvest
    public bool Harvested { get; set; }
    public DateOnly? HarvestDate { get; set; }
    public string? LotId { get; set; }
    public bool Picking { get; set; }
    public double PickedKg { get; set; }
    public double PickTargetKg { get; set; }
    public HarvestOrder? Order { get; set; }
    // history for charts (weekly samples)
    public List<RipenessSample> Samples { get; } = new();
    /// <summary>Closed seasons, oldest first (Establishment years included).</summary>
    public List<SeasonRecord> Seasons { get; } = new();

    public BlockState(PlotData plot, BlockData data, BlockClimate climate) { Plot = plot; Data = data; Climate = climate; }

    public Variety Variety => TerroirEngine.Data.Variety.Get(Planting.Variety);
    public Rootstock Rootstock => TerroirEngine.Data.Rootstock.Get(Planting.Rootstock);
    public int Leaf(int year) => year - PlantingYear + 1;
    public double AreaHa => Data.AreaHa;
    public double Vines => Planting.DensityVinesHa * AreaHa * VineSurvival;

    // derived composition
    public double BerryJuiceFactor => 1080.0;   // g sugar per g berry → g/L juice (juice density and solids; game simplification)
    public double SugarGL => BerryWeight > 0 ? SugarPerBerry / BerryWeight * BerryJuiceFactor : 0;
    public double MalicGL => BerryWeight > 0 ? MalicPerBerry / BerryWeight * BerryJuiceFactor : 0;
    public double TartaricGL => BerryWeight > 0 ? TartaricPerBerry / BerryWeight * BerryJuiceFactor : 0;
    public double CropKgPerVine
    {
        get
        {
            double healthy = (1 - Disease.DownyBunch) * (1 - Disease.GreyRot * 0.9) * (1 - SunburnFraction * 0.5) * (1 - Disease.PowderyBunch * 0.3);
            double noble = Disease.NobleRot;   // noble-rotted berries shrink (already in BerryWeight dehydration)
            return Math.Max(0, BerriesPerVine * BerryWeight / 1000.0 * Math.Max(0, healthy) * (1 - noble * 0.4));
        }
    }
    public double YieldKgHa => CropKgPerVine * Planting.DensityVinesHa * VineSurvival;
    public double CropKg => YieldKgHa * AreaHa;
}

public sealed record RipenessSample(DateOnly Date, double Oe, double Brix, double TaGL, double Ph, double MalicGL, double SeedMaturity,
    double Anthocyanin, double IbmpNgL, double BerryWeightG, double GreyRotPct, double NobleRotPct, double PsiStem, double DownyLeafPct, double PowderyBunchPct);

/// <summary>One closed season of a Block, archived on 1 January because BlockState itself is reset (multi-vintage design §3.3).</summary>
public sealed class SeasonRecord
{
    public int Year { get; init; }
    public int Leaf { get; init; }
    public DateOnly? Budburst { get; init; }
    public DateOnly? Flowering { get; init; }
    public DateOnly? Veraison { get; init; }
    public DateOnly? HarvestDate { get; init; }
    public DateOnly? LeafFall { get; init; }
    public double YieldKgHa { get; init; }
    public double FrostShootLoss { get; init; }
    public double GreyRotPct { get; init; }
    public double Winkler { get; init; }
    public double RainSeason { get; init; }
    public double DownyLeafPeak { get; init; }
    public double PowderyLeafPeak { get; init; }
    public double CropLoadKgM2 { get; init; }
    public int PostHarvestDays { get; init; }
    public double Defoliation { get; init; }
    public double FruitfulnessNext { get; init; }
    public double ReservesAfter { get; init; }
}

public enum SortingLevel { None, Table, Rigorous }
public sealed class HarvestOrder
{
    public bool HandPick { get; set; } = true;
    public SortingLevel Sorting { get; set; } = SortingLevel.Table;
    public string? Note { get; set; }
}
