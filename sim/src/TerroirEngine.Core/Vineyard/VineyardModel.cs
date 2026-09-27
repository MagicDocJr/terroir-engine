using TerroirEngine.Data;
using TerroirEngine.Util;
using TerroirEngine.Weather;

namespace TerroirEngine.Vineyard;

public enum StaffLevel { Junior = 0, Experienced = 1, Senior = 2 }

public sealed record VineEvent(DateOnly Date, string BlockId, string Kind, string Text, int Severity = 1, double Value = 0);

/// <summary>Estate-wide Programme settings and staff that the daily vineyard step needs.</summary>
public sealed class VineyardContext
{
    public Tier Spray = Tier.Medium, Canopy = Tier.Medium, Floor = Tier.Medium, Irrigation = Tier.Low, Frost = Tier.Low, Labour = Tier.Medium;
    public bool IrrigationLegal;
    public StaffLevel VineyardManager = StaffLevel.Experienced;
    public double LabourFactor = 1.0;           // available / required crew hours (0.7..1.3)
    public double DownyInoculum = 0.7, PowderyInoculum = 0.6, BotrytisInoculum = 0.7;
    public bool AutoManage;                     // Establishment years: vines managed by the Mentor, fruit dropped
    public List<VineEvent> Events { get; } = new();
    public int FrostProtectionNights;
    public int SprayPassesToday;
    public bool ForceSprayToday;   // the player's one-off override: an extra spray pass today (spec §5.1)
}

/// <summary>Daily vineyard model per Block. Formulas and parameters from docs/science/{phenology, soil-and-water, canopy-and-yield,
/// ripening, disease}.md. Parameters marked UNVERIFIED there are design values pending the science review.</summary>
public static class VineyardModel
{
    /// <summary>Chill units (Bidabe action, from 1 Nov) needed before forcing starts. Game simplification of BRIN's chilling phase
    /// (phenology.md §3); calibrated so Napa budburst falls in late March. UNVERIFIED.</summary>
    public const double ChillRequirementDays = 120;

    // ------------------------------------------------------------------------------------------ season set-up
    public static void StartSeason(BlockState b, int year)
    {
        b.SeasonYear = year;
        b.Chill = b.NextSeasonChill > 0 || b.Leaf(year) > 1 ? b.NextSeasonChill : ChillRequirementDays;
        b.NextSeasonChill = 0;
        b.Stage = Stage.Dormant;
        b.Forcing = b.Gfv = b.Gsr = b.Gdd10SinceBudburst = b.TtSinceVeraison = b.SEff = b.Winkler = b.Huglin = b.SeasonTempSum = 0; b.SeasonTempDays = 0;
        b.Budburst = b.Flowering = b.FruitSet = b.BunchClosure = b.Veraison = b.LeafFall = null;
        b.LeafAreaPerVine = b.Lai = 0; b.Exposure = 0.45; b.ExposureEarlySum = b.ExposureLateSum = 0; b.ExposureEarlyDays = b.ExposureLateDays = 0;
        b.FrostShootLoss = 0; b.FrostDamageToday = 0; b.LastFrostEvent = null;
        b.FlowerTempSum = b.FlowerRainDays = b.FlowerDays = 0; b.SetFraction = -1; b.MillerandageShare = 0;
        b.BerriesPerVine = b.BerryWeight = b.BerryWeightPeak = b.BerryWeightVeraison = b.SugarPerBerry = b.MalicPerBerry = b.TartaricPerBerry = 0;
        b.LoadingFraction = b.SeedMaturity = b.SkinExtractability = b.Anthocyanin = b.IbmpVeraison = b.Ibmp = b.TdnPotential = b.ThiolPotential = b.PotassiumGL = 0;
        b.PreVeraisonTempSum = 0; b.PreVeraisonDays = 0;
        b.StressPreSum = b.StressPostSum = 0; b.StressPreDays = b.StressPostDays = b.SevereStressDays = 0;
        b.SunburnFraction = 0; b.AcclimatedFraction = 0;
        b.Disease = new DiseaseState();
        b.IrrigationMmSeason = b.Et0Season = b.RainSeason = 0;
        b.Harvested = false; b.HarvestDate = null; b.LotId = null; b.Picking = false; b.PickedKg = 0; b.PickTargetKg = 0; b.Order = null;
        b.Samples.Clear();
        b.PruningDone = false;
        b.ThinningApplied = false;
        // soil water: full profile after winter
        b.Taw = EffectiveTaw(b, year);
        b.Raw = 0.45 * b.Taw;
        b.Dr = 0;
    }

    /// <summary>Total available water in the root zone (FAO-56 TAW with stone correction; soil-and-water.md §3). Adds a fracture-water
    /// reserve for very stony slate/volcanic Blocks (regions-and-plots open question 4; UNVERIFIED design value) and young-vine rooting (§9).</summary>
    public static double EffectiveTaw(BlockState b, int year)
    {
        var s = b.Data.Soil;
        double baseTaw = s.TawMm * b.Rootstock.RootDepthFactor;
        double fracture = 60 * M.Clamp((s.StonesPctVol - 30) / 40.0, 0, 1);
        int leaf = b.Leaf(year);
        double youngDepthM = leaf switch { <= 1 => 0.3, 2 => 0.5, 3 => 0.8, _ => 99 };
        double rootFrac = Math.Min(1, youngDepthM / Math.Max(0.3, s.RootingDepthCm / 100.0));
        return Math.Max(25, (baseTaw + fracture) * rootFrac);
    }

    public static double BudsPerVine(BlockState b)
    {
        double perM2 = b.BudLoad switch { BudLoad.Low => 6.0, BudLoad.High => 11.0, _ => 8.0 };   // buds per m² (UNVERIFIED design)
        double buds = perM2 * 10000.0 / b.Planting.DensityVinesHa;
        double cap = b.Planting.Training switch { TrainingSystem.Einzelpfahl => 26, TrainingSystem.Guyot => 16, _ => 24 };
        return M.Clamp(buds, 4, cap);
    }

    // ------------------------------------------------------------------------------------------ daily step
    public static void Step(BlockState b, DailyWeather wRaw, VineyardContext ctx, ulong seed)
    {
        var date = wRaw.Date;
        if (!b.Planted) return;
        if (date.Month == 1 && date.Day == 1 || b.SeasonYear != date.Year) StartSeason(b, date.Year);
        var w = b.Climate.Adjust(wRaw);
        var v = b.Variety;
        int leaf = b.Leaf(date.Year);
        int doy = date.DayOfYear;
        double clear = b.Climate.ClearFraction(w);

        // --- season climate indices (per Block, weather-and-climate.md §4)
        if (doy >= 91 && doy <= 304) b.Winkler += Math.Max(0, w.Tmean - 10);
        if (doy >= 91 && doy <= 273) b.Huglin += Math.Max(0, ((w.Tmean - 10) + (w.Tmax - 10)) / 2) * HuglinK(b.Plot.Lat);
        if (doy >= 91 && doy <= 273) { b.SeasonTempSum += w.Tmean; b.SeasonTempDays++; }
        b.RainSeason += w.Precip;

        // --- phenology (phenology.md §3–5)
        if (!b.PruningDone && date.Month >= 3) { b.PruningDone = true; }
        double cu = Math.Pow(2.17, -w.Tmax / 10.0) + Math.Pow(2.17, -w.Tmin / 10.0);      // Bidabe chill action (BRIN), Q10 = 2.17
        if (date.Month >= 11) b.NextSeasonChill += cu;
        if (date.Month <= 3 && b.Budburst == null) b.Chill += cu;
        if (b.Budburst == null && b.Chill >= ChillRequirementDays) b.Forcing += Math.Max(0, w.Tmean - 5);
        if (doy >= 60) b.Gfv += Math.Max(0, w.Tmean);
        if (doy >= 91) b.Gsr += Math.Max(0, w.Tmean);

        if (b.Budburst == null && ((b.Forcing >= v.BudburstForcingGdd5 && doy > 45) || doy >= 135))   // warm winters: erratic but certain budburst by mid-May
        {
            b.Budburst = date; b.Stage = Stage.Budburst;
            b.BudsPerVine = BudsPerVine(b);
            b.Shoots = b.BudsPerVine * 0.9;
            ctx.Events.Add(new VineEvent(date, b.Data.Id, "budburst", $"Budburst in Block {b.Data.Id} ({v.Name}). Buds are now vulnerable to spring frost below about −2 °C."));
        }
        if (b.Budburst != null)
        {
            b.Gdd10SinceBudburst += Math.Max(0, w.Tmean - 10);
            int daysSinceBb = date.DayNumber - b.Budburst.Value.DayNumber;
            if (b.Stage == Stage.Budburst && b.Gdd10SinceBudburst > 40) b.Stage = Stage.Shoots;
            if (b.Flowering == null && b.Gfv >= v.GfvFlowering && daysSinceBb > 30)
            {
                b.Flowering = date; b.Stage = Stage.Flowering;
                ctx.Events.Add(new VineEvent(date, b.Data.Id, "flowering", $"Flowering in Block {b.Data.Id}. Cold, wet weather in the next ten days means poor fruit set (coulure, millerandage)."));
            }
            if (b.Flowering != null && b.FruitSet == null && date.DayNumber - b.Flowering.Value.DayNumber >= 10) { b.FruitSet = date; b.Stage = Stage.FruitSet; }
            if (b.FruitSet != null && b.BunchClosure == null && date.DayNumber - b.Flowering!.Value.DayNumber >= 35) { b.BunchClosure = date; b.Stage = Stage.BunchClosure; }
            if (b.Veraison == null && b.Gfv >= v.GfvVeraison && b.FruitSet != null)
            {
                b.Veraison = date; b.Stage = Stage.Veraison;
                InitVeraison(b, w);
                ctx.Events.Add(new VineEvent(date, b.Data.Id, "veraison", $"Véraison in Block {b.Data.Id}: berries soften and {(v.Red ? "colour" : "turn translucent")}. Ripening has begun; weekly lab samples start."));
            }
            if (b.Veraison != null && b.Stage == Stage.Veraison && date.DayNumber - b.Veraison.Value.DayNumber > 7) b.Stage = Stage.Ripening;
        }

        // --- frost damage by stage (phenology.md §6)
        b.FrostDamageToday = 0;
        if (b.Budburst != null && b.Flowering == null)
        {
            int dsb = date.DayNumber - b.Budburst.Value.DayNumber;
            double tCrit = dsb <= 4 ? -2.2 : dsb <= 14 ? -1.7 : -1.1;
            double tMin = w.Tmin;
            bool radiationNight = clear > 0.6 && w.WindKmh < 11;
            if (tMin < tCrit + 2 && radiationNight && ctx.Frost != Tier.Low)
            {
                tMin += ctx.Frost == Tier.High ? 2.0 : 1.0;   // candles / wind machine under an inversion (UNVERIFIED magnitudes)
                ctx.FrostProtectionNights++;
            }
            double dmg = M.Clamp((tCrit + 1.0 - tMin) / 2.0, 0, 1);
            if (dmg > 0.02)
            {
                double remaining = 1 - b.FrostShootLoss;
                b.FrostShootLoss += remaining * dmg;
                b.FrostDamageToday = dmg;
                b.LastFrostEvent = date;
                ctx.Events.Add(new VineEvent(date, b.Data.Id, "frost", $"Frost night in Block {b.Data.Id}: {w.Tmin:0.0} °C at vine level killed {dmg * 100:0}% of the young shoots still alive. Secondary buds will push, but with a smaller crop.", 3, dmg));
            }
        }
        if (b.LeafFall == null && b.Veraison != null && (w.Tmin <= -2 || (date.Month == 11 && date.Day >= 15)))
        {
            b.LeafFall = date; b.Stage = b.Harvested ? Stage.Harvested : Stage.LeafFall;
            ctx.Events.Add(new VineEvent(date, b.Data.Id, "leaffall", $"Leaf fall in Block {b.Data.Id}: {(w.Tmin <= -2 ? "a hard autumn frost ended" : "the season has ended")} ripening. Fruit still hanging keeps what it reached."));
        }

        // --- canopy (canopy-and-yield.md §2)
        double vigour = b.Rootstock.VigourFactor * M.Clamp(Math.Pow(b.Taw / 150.0, 0.3), 0.6, 1.3) * (leaf <= 2 ? 0.5 : leaf == 3 ? 0.8 : 1.0);
        double stressMean = b.StressPreDays > 0 ? b.StressPreSum / b.StressPreDays : 0;
        if (b.Budburst != null && b.LeafFall == null)
        {
            double effShoots = b.Shoots * (1 - b.FrostShootLoss * 0.55);   // secondary shoots replace some
            double laShoot = 0.35 * vigour * (1 - 0.4 * stressMean) * (1 - Math.Exp(-0.004 * b.Gdd10SinceBudburst * 2.2));
            double capPerVine = 2.6 * 10000.0 / b.Planting.DensityVinesHa * vigour;         // LAI cap ≈ 2.6 (UNVERIFIED)
            double diseaseLoss = M.Clamp((b.Disease.DownyLeaf + b.Disease.PowderyLeaf * 0.4) / 100.0, 0, 0.9);
            double severeLoss = b.SevereStressDays * 0.01;
            b.LeafAreaPerVine = Math.Min(effShoots * laShoot, capPerVine) * (1 - diseaseLoss) * (1 - Math.Min(0.5, severeLoss));
            b.Lai = b.LeafAreaPerVine * b.Planting.DensityVinesHa / 10000.0;
            // exposure from canopy tier + leaf removal (explicit choice)
            double baseExp = ctx.Canopy switch { Tier.Low => 0.22, Tier.High => 0.62, _ => 0.42 };
            bool removalActive = b.LeafSide != LeafRemovalSide.None &&
                ((b.LeafTiming == LeafRemovalTiming.Early && b.FruitSet != null) || (b.LeafTiming == LeafRemovalTiming.Late && b.Veraison != null));
            double sideBonus = !removalActive ? 0 : b.LeafSide switch { LeafRemovalSide.Morning => 0.10, LeafRemovalSide.Afternoon => 0.15, LeafRemovalSide.Both => 0.25, _ => 0 };
            double labourPenalty = (1 - Math.Min(1, ctx.LabourFactor)) * 0.3;
            b.Exposure = M.Clamp((baseExp + sideBonus) * (1 - labourPenalty) * M.Clamp(1.25 - 0.18 * b.Lai, 0.6, 1.2), 0.05, 0.95);
            if (b.Veraison == null && b.FruitSet != null) { b.ExposureEarlySum += b.Exposure; b.ExposureEarlyDays++; }
            else if (b.Veraison != null) { b.ExposureLateSum += b.Exposure; b.ExposureLateDays++; }
            if (removalActive && b.LeafTiming == LeafRemovalTiming.Early) b.AcclimatedFraction = Math.Min(1, b.AcclimatedFraction + 0.05);
        }

        // --- water balance (FAO-56; soil-and-water.md §4–6)
        {
            double kcCanopy = 0.3 + 0.4 * M.Clamp(b.Lai / 2.5, 0, 1);
            double kcFloor = ctx.Floor switch { Tier.Low => 0.12, Tier.Medium => 0.06, _ => 0.0 };   // spontaneous cover competes; tillage doesn't
            double kc = (b.Budburst != null && b.LeafFall == null) ? kcCanopy + kcFloor : 0.15 + kcFloor * 0.5;
            double ks = b.Dr <= b.Raw ? 1 : M.Clamp((b.Taw - b.Dr) / (b.Taw - b.Raw), 0, 1);
            double et0 = w.Et0 * (b.Plot.Region.Id == "napa" ? 0.82 : 1.0);   // ET0 follows the corrected (cooler, foggier) Napa temperatures
            double etc = ks * kc * et0;
            double slope = b.Data.Topography.SlopePct;
            double runoff = w.Precip > 10 ? (w.Precip - 10) * M.Clamp(slope / 150.0, 0, 0.4) : 0;
            double irrigation = 0;
            if (ctx.IrrigationLegal && ctx.Irrigation != Tier.Low && b.Budburst != null && b.LeafFall == null)
            {
                double trigger = ctx.Irrigation == Tier.Medium ? b.Raw + 0.35 * (b.Taw - b.Raw) : b.Raw * 0.7;  // Medium = regulated deficit
                if (b.Dr > trigger) { irrigation = Math.Min(8, b.Dr - b.Raw * 0.6); b.IrrigationMmSeason += irrigation; }
            }
            if (leaf == 1 && ctx.AutoManage && ctx.IrrigationLegal && b.Dr > b.Raw) { irrigation += 5; b.IrrigationMmSeason += 5; }
            b.Dr = M.Clamp(b.Dr - (w.Precip - runoff) - irrigation + etc, 0, b.Taw);
            b.Et0Season += et0;
            double depletion = Math.Max(0, (b.Dr - b.Raw) / Math.Max(1, b.Taw - b.Raw));
            double psiDry = -1.2 + b.Rootstock.DroughtShiftMPa;
            b.PsiPd = -0.1 + (psiDry + 0.1) * Math.Pow(depletion, 1.5);
            b.PsiStem = b.PsiPd - 0.35 - 0.03 * Math.Max(0, w.Tmax - 20);
            b.StressIndex = M.Clamp((-0.6 - b.PsiStem) / 0.8, 0, 1);
            if (b.Budburst != null && b.LeafFall == null)
            {
                if (b.Veraison == null) { b.StressPreSum += b.StressIndex; b.StressPreDays++; }
                else { b.StressPostSum += b.StressIndex; b.StressPostDays++; }
                if (b.PsiStem < -1.4) b.SevereStressDays++;
            }
            if (leaf == 1 && b.PsiStem < -1.4 && !ctx.IrrigationLegal) b.VineSurvival = Math.Max(0.6, b.VineSurvival - 0.004);
        }

        // --- lime-induced chlorosis (soil-and-water.md §8), assuming easily extractable Fe ≈ 5 mg/kg on calcareous soils
        {
            double lime = b.Data.Soil.ActiveLimePct;
            double ipc = lime <= 0 ? 0 : 10000 * lime / 100.0 / 25.0 * 1.0;      // IPC = 10⁴·(CaCO₃ %)/Fe²; Fe² = 25 (UNVERIFIED default)
            double r = ipc / b.Rootstock.MaxChlorosisIndex;
            b.Chlorosis = M.Clamp((r - 0.8) / 0.8, 0, 1);
        }

        // --- flowering window and fruit set (canopy-and-yield.md §3.4)
        if (b.Flowering != null && b.SetFraction < 0)
        {
            int rel = date.DayNumber - b.Flowering.Value.DayNumber;
            if (rel >= -3 && rel <= 7) { b.FlowerTempSum += w.Tmean; b.FlowerDays++; if (w.Precip >= 1) b.FlowerRainDays++; }
            if (rel > 7)
            {
                double tMeanF = b.FlowerDays > 0 ? b.FlowerTempSum / b.FlowerDays : 15;
                double fTemp = M.Clamp((tMeanF - 10) / (17 - 10), 0.3, 1.0);
                double fRain = Math.Max(0.6, 1 - 0.04 * b.FlowerRainDays);
                double needed = 1.2 * b.Shoots * 0.12;
                double fCarb = M.Clamp(0.6 + 0.4 * b.LeafAreaPerVine / Math.Max(0.1, needed), 0.6, 1.0);
                double coulure = 1 - v.CoulureProne * (1 - fTemp * fRain) * 0.6;
                b.SetFraction = v.BaseSet * fTemp * fRain * fCarb * coulure / Math.Max(0.3, 0.85);
                b.SetFraction = M.Clamp(b.SetFraction, 0.1, v.BaseSet * 1.1);
                b.MillerandageShare = 0.5 * (1 - fTemp) * (1 + v.MillerandageProne);
                double setRatio = b.SetFraction / v.BaseSet;
                double fruitfulShoots = b.Shoots * (1 - b.FrostShootLoss) + b.Shoots * b.FrostShootLoss * 0.4;   // secondary shoots ~40 % fruitful
                b.BerriesPerVine = fruitfulShoots * v.ClustersPerShoot * v.BerriesPerCluster * setRatio;
                if (leaf <= 3 || ctx.AutoManage) b.BerriesPerVine = 0;                                          // young vines: fruit dropped
                if (leaf == 4) b.BerriesPerVine *= 0.85;                                                         // 4th leaf (soil-and-water.md §9)
                b.BerryWeight = v.BerryWeightG * 0.12;
                string set = setRatio < 0.75 ? "poor" : setRatio < 0.92 ? "below average" : "good";
                if (b.BerriesPerVine > 0)
                    ctx.Events.Add(new VineEvent(date, b.Data.Id, "fruitset", $"Fruit set in Block {b.Data.Id} was {set} ({setRatio * 100:0}% of normal){(b.MillerandageShare > 0.15 ? ", with millerandage (mixed small and normal berries)" : "")}. Crop estimate at full berry size: {b.BerriesPerVine * v.BerryWeightG * b.Planting.DensityVinesHa * b.VineSurvival / 1e6:0.0} t/ha.", set == "poor" ? 2 : 1, setRatio));
            }
        }

        // --- berry growth before véraison
        double stressPre = b.StressPreDays > 0 ? b.StressPreSum / b.StressPreDays : 0;
        if (b.FruitSet != null && b.Veraison == null && b.BerriesPerVine > 0)
        {
            b.BerryWeightPeak = v.BerryWeightG * (1 - 0.25 * stressPre) * (1 - 0.66 * b.MillerandageShare * 0.5) * (leaf == 4 ? 0.97 : 1);
            double target = 0.55 * b.BerryWeightPeak;
            b.BerryWeight += (target - b.BerryWeight) * 0.05;
            b.PreVeraisonTempSum += w.Tmean; b.PreVeraisonDays++;
        }

        // --- ripening after véraison (ripening.md §3–8)
        if (b.Veraison != null && b.BerriesPerVine > 0 && !b.Harvested)
        {
            bool active = b.LeafFall == null;
            b.TtSinceVeraison += Math.Max(0, w.Tmean);
            double lafr = b.LeafAreaPerVine * 0.55 / Math.Max(0.05, b.CropKgPerVine);
            double capacity = M.Clamp(lafr / 1.0, 0.4, 1.1) * (1 - 0.4 * b.Chlorosis);
            double stressPost = b.StressIndex;
            // ripening.md: no slowdown for none-to-moderate stress, 0.4 when severe. Ψstem −1.2 → −1.6 MPa is the transition (UNVERIFIED breakpoints).
            double waterFactor = 1 - 0.6 * M.Clamp((-1.2 - b.PsiStem) / 0.4, 0, 1);
            double radiation = 0.7 + 0.4 * clear;
            double heat = w.Tmax > 35 ? 0.5 : 1.0;
            if (active) b.SEff += Math.Max(0, w.Tmean) * capacity * waterFactor * radiation * heat;
            double s50 = v.GsrF200 - 146, width = 180;
            double cLoad = 20 + 260 * M.Sigmoid((b.SEff - s50) / width);
            if (leaf == 4) cLoad *= 0.97;
            b.LoadingFraction = M.Clamp((cLoad - 20) / 260.0, 0, 1);
            // berry weight: swell with loading, then dehydrate after the plateau
            double wLoaded = b.BerryWeightVeraison + (b.BerryWeightPeak - b.BerryWeightVeraison) * Math.Min(1, b.LoadingFraction / 0.7);
            if (b.LoadingFraction < 0.85 && active) b.BerryWeight = Math.Max(b.BerryWeight, wLoaded);
            else
            {
                double r = (0.1 + 0.3 * w.VpdKpa) / 100.0 + (active ? 0 : 0.002);
                r += b.Disease.NobleRot * 0.03;
                b.BerryWeight *= 1 - r;
            }
            if (w.Precip > 15 && active) { b.BerryWeight *= 1.02; b.Disease.Cracking = Math.Min(1, b.Disease.Cracking + (b.StressIndex > 0.4 ? 0.12 : 0.05)); }
            b.SugarPerBerry = Math.Max(b.SugarPerBerry, cLoad * b.BerryWeightPeak / b.BerryJuiceFactor);
            // malic acid respiration (Q10 law); exposed fruit runs warmer
            double tBerry = w.Tmean + 1.5 * b.Exposure * clear;
            b.MalicPerBerry *= Math.Exp(-0.021 * v.MalicRetention * Math.Pow(2.0, (tBerry - 20) / 10.0));
            // potassium
            double warmth = M.Clamp((SeasonMeanTemp(b) - 15) / 6.0, 0, 1);
            // Napa's alluvial and volcanic soils are potassium-rich (ripening.md §4.4: high soil K → high must pH); factor is UNVERIFIED calibration to the 3.6–3.9 target
            double soilK = b.Data.Soil.SoilPotassiumFactor;
            b.PotassiumGL = (0.85 + 1.4 * Math.Pow(warmth, 1.5)) * b.Rootstock.PotassiumFactor * soilK * (0.8 + 0.2 * vigour) * (0.75 + 0.25 * b.LoadingFraction);
            // phenolics
            b.SeedMaturity = 1 - 1 / (1 + 0.0044 * b.TtSinceVeraison);
            b.SkinExtractability = 0.4 + 0.6 * b.LoadingFraction;
            if (v.Red && active)
            {
                double rT = tBerry < 15 ? 0.6 + 0.4 * (tBerry - 5) / 10 : tBerry <= 25 ? 1.0 : Math.Max(0, 1 - (tBerry - 25) / 10.0);
                double light = 0.7 + 0.5 * Math.Min(b.Exposure, 0.6);
                double water = 1 + 0.15 * Math.Min(stressPost, 0.6);
                b.Anthocyanin += 0.035 * Math.Max(0, rT) * (v.AnthocyaninMax * water - b.Anthocyanin) * light;
                if (w.Tmax > 35) b.Anthocyanin *= 0.99;
            }
            b.Ibmp = b.IbmpVeraison * Math.Exp(-0.0018 * b.TtSinceVeraison);
            double expEarly = b.ExposureEarlyDays > 0 ? b.ExposureEarlySum / b.ExposureEarlyDays : b.Exposure;
            double expLate = b.ExposureLateDays > 0 ? b.ExposureLateSum / b.ExposureLateDays : b.Exposure;
            b.TdnPotential = v.TdnPotential * (1 + 1.2 * expEarly + 0.5 * expLate) * (1 + 0.3 * (b.StressPostDays > 0 ? b.StressPostSum / b.StressPostDays : 0)) * (0.8 + 0.4 * warmth);
            b.ThiolPotential = v.ThiolPotential * (1 + 0.3 * (1 - stressPost)) * (0.8 + 0.4 * Math.Min(1, b.TtSinceVeraison / 800));
            // sunburn (canopy-and-yield.md §2.5)
            double afternoonExp = b.LeafSide is LeafRemovalSide.Afternoon or LeafRemovalSide.Both ? b.Exposure : b.Exposure * 0.5;
            double tb = w.Tmax + 12 * afternoonExp * clear * (1 - 0.08 * w.WindKmh / 3.6);
            double threshold = 46 + 2.5 * b.AcclimatedFraction;
            if (tb > threshold) b.SunburnFraction = Math.Min(0.6, b.SunburnFraction + afternoonExp * M.Clamp((tb - threshold) / 3, 0, 1) * 0.25);
            if (date.DayOfWeek == DayOfWeek.Monday) b.Samples.Add(Sample(b, date));
        }
        else if (b.FruitSet != null && b.Veraison == null && b.BerriesPerVine > 0 && date.DayOfWeek == DayOfWeek.Monday)
        {
            // pre-véraison sampling too (for the ripeness chart's start)
        }

        // --- sunburn pre-véraison (hard green berries are also susceptible)
        if (b.FruitSet != null && b.Veraison == null && b.BerriesPerVine > 0)
        {
            double afternoonExp = b.LeafSide is LeafRemovalSide.Afternoon or LeafRemovalSide.Both ? b.Exposure : b.Exposure * 0.5;
            double tb = w.Tmax + 12 * afternoonExp * clear * (1 - 0.08 * w.WindKmh / 3.6);
            double threshold = 46 + 2.5 * b.AcclimatedFraction;
            if (tb > threshold)
            {
                double add = afternoonExp * M.Clamp((tb - threshold) / 3, 0, 1) * 0.25;
                b.SunburnFraction = Math.Min(0.6, b.SunburnFraction + add);
                if (add > 0.02) ctx.Events.Add(new VineEvent(date, b.Data.Id, "sunburn", $"Heat: exposed bunches in Block {b.Data.Id} reached ~{tb:0} °C at the berry surface and sunburned ({add * 100:0}% more fruit damaged).", 2, add));
            }
        }

        // --- diseases (disease.md)
        Disease(b, w, ctx, seed);
    }

    private static void InitVeraison(BlockState b, DailyWeather w)
    {
        var v = b.Variety;
        ApplyCropThinning(b);
        b.BerryWeightVeraison = Math.Max(b.BerryWeight, 0.5 * Math.Max(0.1, b.BerryWeightPeak));
        b.BerryWeight = b.BerryWeightVeraison;
        b.SEff = b.Gsr;
        double preT = b.PreVeraisonDays > 0 ? b.PreVeraisonTempSum / b.PreVeraisonDays : 18;
        double malicGL = M.Clamp(15 + 0.35 * (18 - preT) * 3, 9, 22);
        b.MalicPerBerry = malicGL * b.BerryWeight / b.BerryJuiceFactor;
        b.TartaricPerBerry = v.TartaricVeraisonGL * 1.55 * b.BerryWeight / b.BerryJuiceFactor;  // concentrated in the small green berry
        double expPre = b.ExposureEarlyDays > 0 ? b.ExposureEarlySum / b.ExposureEarlyDays : b.Exposure;
        double coolFactor = 1 + 0.03 * (20 - preT);
        b.IbmpVeraison = v.IbmpBase * (1 + 1.5 * (1 - expPre)) * Math.Max(0.5, coolFactor);
        b.SugarPerBerry = 20 * b.BerryWeightPeak / b.BerryJuiceFactor;
    }

    /// <summary>Green harvest: bunches cut at véraison lower the crop and raise the leaf-area-to-fruit ratio (canopy-and-yield.md §2.2).</summary>
    public static void ApplyCropThinning(BlockState b)
    {
        if (b.ThinningApplied || b.CropThinning == 0 || b.BerriesPerVine <= 0) return;
        b.BerriesPerVine *= b.CropThinning == 1 ? 0.8 : 0.6;
        b.ThinningApplied = true;
    }

    public static double SeasonMeanTemp(BlockState b) => b.SeasonTempDays > 0 ? b.SeasonTempSum / b.SeasonTempDays : 15;
    public static double HuglinK(double lat) => lat <= 40 ? 1.0 : M.Lerp(1.02, 1.06, M.Clamp((lat - 40) / 10.0, 0, 1));

    public static RipenessSample Sample(BlockState b, DateOnly date)
    {
        var must = Winery.Chemistry.MustFromBlock(b);
        return new RipenessSample(date, M.Round(must.Oe, 1), M.Round(must.Brix, 1), M.Round(must.TaGL, 1), M.Round(must.Ph, 2), M.Round(b.MalicGL, 1),
            M.Round(b.SeedMaturity, 2), M.Round(b.Anthocyanin, 2), M.Round(b.Ibmp, 1), M.Round(b.BerryWeight, 2),
            M.Round(b.Disease.GreyRot * 100, 1), M.Round(b.Disease.NobleRot * 100, 1), M.Round(b.PsiStem, 2), M.Round(b.Disease.DownyLeaf, 1), M.Round(b.Disease.PowderyBunch * 100, 1));
    }

    // ------------------------------------------------------------------------------------------ diseases
    private static void Disease(BlockState b, DailyWeather w, VineyardContext ctx, ulong seed)
    {
        var d = b.Disease;
        var date = w.Date;
        if (b.Budburst == null || b.LeafFall != null) { d.DownyRiskToday = 0; d.BotrytisRiskToday = 0; return; }
        var v = b.Variety;
        double fog = b.Climate.FogWetHours(w, b.Data.Microclimate.FogFrequency);
        double lw = Math.Min(24, w.LeafWetHours(fog) * (1 + 0.5 * (1 - b.Exposure)) * (1 - 0.25 * b.Data.Microclimate.WindExposure));
        double twet = w.WetTemp;

        // --- spray programme (disease.md §6)
        double interval = ctx.Spray switch { Tier.Low => 17, Tier.High => 8, _ => 12 };
        double p0 = ctx.Spray switch { Tier.Low => 0.70, Tier.High => 0.92, _ => 0.85 };
        double halfLife = ctx.Spray switch { Tier.Low => 7, Tier.High => 8, _ => 8 };
        bool sprayWindow = b.Gdd10SinceBudburst > 25 && (b.Veraison == null || date.DayNumber - b.Veraison.Value.DayNumber < 10);
        d.NextSprayDue ??= date;
        if (ctx.ForceSprayToday && !b.Harvested && w.Precip <= 5)
        {
            d.LastSpray = date; d.RainSinceSpray = 0; d.SpraysThisSeason++;
            ctx.SprayPassesToday++;
            d.NextSprayDue = date.AddDays((int)interval);
        }
        else if (sprayWindow && date >= d.NextSprayDue)
        {
            bool raining = w.Precip > 5;
            bool skip = raining && ctx.Spray == Tier.Low;
            if (!raining || ctx.Spray == Tier.High)
            {
                d.LastSpray = date; d.RainSinceSpray = 0; d.SpraysThisSeason++;
                ctx.SprayPassesToday++;
                d.NextSprayDue = date.AddDays((int)interval);
            }
            else if (skip) d.NextSprayDue = date.AddDays((int)interval);
            else d.NextSprayDue = date.AddDays(1);
        }
        if (d.LastSpray != null)
        {
            d.RainSinceSpray += w.Precip;
            double days = date.DayNumber - d.LastSpray.Value.DayNumber;
            double washoff = d.RainSinceSpray >= 25 ? 0.5 : 1;
            double newGrowth = b.Flowering == null ? 1 - Math.Min(0.3, 0.03 * days) : 1 - Math.Min(0.1, 0.01 * days);   // unsprayed new leaves
            d.Protection = p0 * Math.Pow(0.5, days / halfLife) * washoff * newGrowth;
        }
        double staffBonus = ctx.VineyardManager switch { StaffLevel.Senior => 0.05, StaffLevel.Junior => -0.05, _ => 0 };
        double labourPen = (1 - Math.Min(1, ctx.LabourFactor)) * 0.15;
        double prot = M.Clamp(d.Protection + (d.Protection > 0 ? staffBonus : 0) - labourPen, 0, 0.97);

        int dsf = b.Flowering != null ? date.DayNumber - b.Flowering.Value.DayNumber : -99;
        bool shoots10cm = b.Gdd10SinceBudburst > 50;

        // --- downy mildew
        if (!d.DownyPrimarySeason && shoots10cm && w.Tmean >= 10 && w.Precip >= 10)
        {
            d.DownyPrimarySeason = true;
            ctx.Events.Add(new VineEvent(date, b.Data.Id, "downy-primary", $"3-10 rule met in Block {b.Data.Id} on {Dates.Short(date)}: ≥10 °C, ≥10 mm rain and shoots over 10 cm. Primary downy mildew infections are now possible.", 2));
        }
        double leafSusc = b.Veraison == null ? (dsf < 21 ? 1.0 : 0.6) : 0.3;
        double bunchSusc = (dsf >= -14 && dsf <= 21) ? 1.0 : (b.Flowering == null && shoots10cm ? 0.6 : 0.05);
        d.DownyRiskToday = 0;
        if (d.DownyPrimarySeason)
        {
            double f = MagareyF(twet, 4.0, 21.0, 30.2);
            double wReq = f > 0 ? 2.0 / f : double.PositiveInfinity;
            double eff = double.IsInfinity(wReq) ? 0 : M.Clamp((lw - wReq) / wReq, 0, 1);
            double source = ctx.DownyInoculum * 0.01 + d.DownySporangia;
            d.DownyRiskToday = M.Clamp(eff * 100 * (1 - prot) * Math.Min(1, source * 20 + 0.3), 0, 100);
            if (eff > 0 && w.Precip > 0.2)
            {
                double newLeaf = eff * leafSusc * (1 - prot) * source * 0.6;
                double newBunch = eff * bunchSusc * (1 - prot) * source * 0.45;
                if (newLeaf > 1e-5 || newBunch > 1e-5)
                {
                    d.DownyLatent.Add(new LatentCohort { Leaf = newLeaf, Bunch = newBunch });
                    d.DownyFirstInfection ??= date;
                }
            }
            // curative: a spray within 48 h removes half of a fresh cohort
            if (d.LastSpray == date) foreach (var c in d.DownyLatent) if (c.Progress < 0.4) { c.Leaf *= 0.5; c.Bunch *= 0.5; }
        }
        for (int i = d.DownyLatent.Count - 1; i >= 0; i--)
        {
            var c = d.DownyLatent[i];
            c.Progress += 1.0 / DownyIncubationDays(w.Tmean);
            if (c.Progress >= 1)
            {
                double before = d.DownyLeaf;
                d.DownyLeaf = Math.Min(95, d.DownyLeaf + c.Leaf * 100 * (1 - d.DownyLeaf / 100));
                d.DownyBunch = Math.Min(0.95, d.DownyBunch + c.Bunch * (1 - d.DownyBunch));
                d.DownyLatent.RemoveAt(i);
                if (d.DownyLeaf - before > 0.8)
                    ctx.Events.Add(new VineEvent(date, b.Data.Id, "downy-symptoms", $"Downy mildew oil spots appear in Block {b.Data.Id}: {d.DownyLeaf:0.#}% of leaf area affected{(d.DownyBunch > 0.01 ? $", {d.DownyBunch * 100:0.#}% of bunches lost" : "")}.", 2, d.DownyLeaf));
            }
        }
        bool sporulationNight = w.RhMax >= 80 && w.Tmin >= 10 && w.Tmin <= 30;
        d.DownySporangia = sporulationNight ? d.DownyLeaf / 100.0 * 0.2 : d.DownySporangia * 0.3;

        // --- powdery mildew (UC Davis index)
        if (!d.PowderyStarted && w.Precip >= 2.5 && w.Tmean >= 10) d.PowderyStarted = true;
        if (d.PowderyStarted)
        {
            int h = w.HoursBetween(21, 29);
            d.PowderyIndex += h >= 6 ? 20 : -10;
            if (w.Tmax >= 35) d.PowderyIndex -= 10;
            d.PowderyIndex = M.Clamp(d.PowderyIndex, 0, 100);
            double berrySusc = (b.FruitSet != null && dsf <= 28) || (b.Flowering != null && dsf >= 0 && dsf <= 28) ? 1.0 : 0.0;
            double infection = d.PowderyIndex / 100.0 * (1 - prot) * ctx.PowderyInoculum * 0.0025;
            if (infection > 0) d.PowderyPending.Add(new LatentCohort { Countdown = 6, Leaf = infection * 0.8, Bunch = infection * berrySusc });
            for (int i = d.PowderyPending.Count - 1; i >= 0; i--)
            {
                var c = d.PowderyPending[i];
                if (--c.Countdown > 0) continue;
                d.PowderyLeaf = Math.Min(80, d.PowderyLeaf + c.Leaf * 100 * (1 - d.PowderyLeaf / 100));
                double before = d.PowderyBunch;
                d.PowderyBunch = Math.Min(0.9, d.PowderyBunch + c.Bunch * (1 - d.PowderyBunch));
                d.PowderyPending.RemoveAt(i);
                if (before < 0.03 && d.PowderyBunch >= 0.03)
                    ctx.Events.Add(new VineEvent(date, b.Data.Id, "powdery", $"Powdery mildew on the bunches in Block {b.Data.Id} ({d.PowderyBunch * 100:0}% of berries). Infected berries crack and taste musty.", 2, d.PowderyBunch));
            }
            if (d.PowderyIndex >= 60 && date.DayOfWeek == DayOfWeek.Monday && b.Veraison == null)
                ctx.Events.Add(new VineEvent(date, b.Data.Id, "powdery-index", $"Powdery mildew risk index {d.PowderyIndex:0} in Block {b.Data.Id}: high pressure (UC Davis index ≥ 60). Keep spray intervals short.", 1, d.PowderyIndex));
        }
        d.Cracking = Math.Min(1, d.Cracking * 0.995 + d.PowderyBunch * 0.01);

        // --- botrytis (Broome et al. 1995) and noble rot
        double sugarProgress = b.Veraison != null ? M.Clamp((b.SugarGL - 120) / 110.0, 0, 1) : 0;
        double botSusc = b.Flowering == null ? 0 : dsf <= 10 ? 0.4 : b.BunchClosure == null ? 0.1 : b.Veraison == null ? 0.05 : 0.2 + 0.8 * sugarProgress;
        botSusc *= v.BotrytisCompactness * (1 + 1.5 * d.Cracking) * (1 + 0.5 * (1 - b.Exposure)) * (b.Data.Microclimate.FogFrequency > 0.5 ? 1.2 : 1);
        double wH = M.Clamp(lw, 0, 24);
        double logit = -2.647866 - 0.374927 * wH + 0.061911 * wH * twet - 0.001023 * wH * twet * twet;
        double y = wH >= 4 ? M.Sigmoid(logit) : 0;
        double protB = prot * 0.6 + (ctx.Canopy == Tier.High ? 0.1 : 0);
        double newRot = y * botSusc * (1 - protB) * ctx.BotrytisInoculum * 0.006;
        d.BotrytisRiskToday = M.Clamp(y * botSusc * (1 - protB) * 100, 0, 100);
        if (b.Veraison == null && dsf >= 0 && dsf <= 10) d.BotrytisLatentFlowering += newRot;
        else if (b.Veraison != null && b.BerriesPerVine > 0 && !b.Harvested)
        {
            if (b.Veraison == date) newRot += d.BotrytisLatentFlowering * 0.3;
            double healthy = 1 - d.GreyRot - d.NobleRot;
            if (newRot > 0) d.BotrytisPending.Add(new LatentCohort { Countdown = 5, Leaf = newRot * healthy, Bunch = b.SugarGL });
            // weather tracker for the noble-rot rule: afternoon RH < 60 %
            foreach (var c in d.BotrytisPending) { c.Countdown--; if (w.RhMin < 60) c.Progress += 1; }
            for (int i = d.BotrytisPending.Count - 1; i >= 0; i--)
            {
                var c = d.BotrytisPending[i];
                if (c.Countdown > 0) continue;
                double oe = Units.OeFromSugar(c.Bunch);
                bool noble = oe >= 80 && d.Cracking < 0.2 && c.Progress >= 3;
                if (noble) d.NobleRot = Math.Min(0.8, d.NobleRot + c.Leaf); else d.GreyRot = Math.Min(0.9, d.GreyRot + c.Leaf);
                d.BotrytisPending.RemoveAt(i);
            }
            // spread berry-to-berry in wet weather
            double spread = lw > 10 ? 0.03 : lw > 4 ? 0.01 : 0.002;
            d.GreyRot = Math.Min(0.9, d.GreyRot + d.GreyRot * (1 - d.GreyRot - d.NobleRot) * spread * v.BotrytisCompactness);
            if (w.RhMin < 60 && d.NobleRot > 0 && d.GreyRot < 0.2) d.NobleRot = Math.Min(0.8, d.NobleRot * 1.01);
            if (d.GreyRot > 0.05 && date.DayOfWeek == DayOfWeek.Monday)
                ctx.Events.Add(new VineEvent(date, b.Data.Id, "botrytis", $"Grey rot is spreading in Block {b.Data.Id}: {d.GreyRot * 100:0}% of the fruit. Each wet day makes it worse; picking with rigorous sorting removes most of it.", d.GreyRot > 0.12 ? 3 : 2, d.GreyRot));
        }
    }

    /// <summary>Magarey et al. (2005) temperature response, P. viticola parameters (Caffi et al. 2016).</summary>
    public static double MagareyF(double t, double tmin, double topt, double tmax)
    {
        if (t <= tmin || t >= tmax) return 0;
        return (tmax - t) / (tmax - topt) * Math.Pow((t - tmin) / (topt - tmin), (topt - tmin) / (tmax - topt));
    }
    /// <summary>Downy incubation days by daily mean temperature (disease.md §3.3, interpolated table, UNVERIFIED).</summary>
    public static double DownyIncubationDays(double t)
    {
        double[] ts = { 10, 13, 17, 21, 24, 27, 30 };
        double[] ds = { 16, 12, 8, 5, 4, 5, 8 };
        if (t <= ts[0]) return ds[0];
        if (t >= ts[^1]) return ds[^1];
        for (int i = 0; i < ts.Length - 1; i++) if (t <= ts[i + 1]) return M.Lerp(ds[i], ds[i + 1], (t - ts[i]) / (ts[i + 1] - ts[i]));
        return 8;
    }
}
