using TerroirEngine.Util;
using TerroirEngine.Vineyard;

namespace TerroirEngine.Winery;

/// <summary>Cellar choice keys and their options (spec §5.2, explicit choices). Option index 0 is the default.</summary>
public static class CellarOptions
{
    public record Choice(string Key, string[] Options, string Why, bool WhiteOnly = false, bool RedOnly = false, bool LockedAfterFermentStart = true);

    public static readonly Choice[] All =
    {
        new("Pressing", new[] { "Whole bunch, slow press", "Crushed, pressed", "Crushed + 12 h skin contact" },
            "Whole-bunch pressing is gentle: clean, low-phenolic juice. Crushing and skin contact extract more flavour and thiol precursors, but also phenolic bitterness.", WhiteOnly: true),
        new("Settling", new[] { "Natural, 18 h", "Cold settling, 24 h", "None (cloudy must)" },
            "Settling removes solids. Clear juice gives cleaner, fruitier wines; cloudy juice ferments faster but risks reduction (H₂S) and gives broader flavours.", WhiteOnly: true),
        new("Destemming", new[] { "Fully destemmed", "30 % whole bunch", "100 % whole bunch" },
            "Whole bunches add stem tannin, a fresh herbal lift and some carbonic fruit; unripe stems taste green and raise pH (stems release potassium).", RedOnly: true),
        new("Cold soak", new[] { "None", "3 days", "7 days" },
            "A pre-fermentation cold soak extracts colour and fruit in water before alcohol pulls out seed tannin. The evidence is mixed; the risk is spoilage in a warm cellar.", RedOnly: true),
        new("Cap management", new[] { "Pump-over 2×/day", "Punch-down 2×/day", "Délestage + pump-over", "Gentle (1×/day)" },
            "Pump-over is gentle and aerates; punch-down extracts more from the skins (traditional for Pinot Noir); délestage extracts strongly and removes some seeds.", RedOnly: true, LockedAfterFermentStart: false),
        new("Maceration", new[] { "Press at dryness", "Extended +7 days", "Press early (≈5 °Oe left)" },
            "Longer contact after fermentation extracts and softens more tannin (seed tannin needs alcohol); pressing early keeps the wine lighter and fruitier.", RedOnly: true, LockedAfterFermentStart: false),
        new("Yeast", new[] { "Cultured S. cerevisiae", "Ambient (spontaneous)" },
            "Cultured yeast ferments reliably and cleanly. Ambient (wild) yeast starts slowly and can stall, but often adds texture and complexity."),
        new("Nutrients", new[] { "Add DAP if YAN < 150 mg/L", "None" },
            "Yeast need nitrogen. Below ~140–150 mg/L YAN, fermentations become sluggish and yeast release H₂S (rotten egg)."),
        new("Temperature", new[] { "16 °C", "14 °C", "18 °C", "Cellar ambient" },
            "Cool fermentations (14–16 °C) keep fruity esters in whites; warm ones (26–30 °C) extract colour and tannin in reds. Above ~32 °C yeast die and fermentation sticks.", WhiteOnly: true, LockedAfterFermentStart: false),
        new("Red temperature", new[] { "26 °C", "22 °C", "30 °C", "Uncontrolled" },
            "Reds ferment warmer to extract colour and tannin; 30 °C extracts most but risks a stuck fermentation if cooling can't keep up.", RedOnly: true, LockedAfterFermentStart: false),
        new("Chaptalisation", new[] { "None", "+1 % vol", "+2 % vol" },
            "Adding sugar before fermentation raises alcohol. Legal for German Qualitätswein and French AOC within limits; forbidden for Prädikat wines and in California."),
        new("Acidification", new[] { "None", "+1 g/L tartaric", "+2 g/L tartaric" },
            "Adding tartaric acid lowers pH and freshens warm-climate musts; allowed in Napa and within EU limits. Not combined with chaptalisation in the EU."),
        new("Sweetness", new[] { "Ferment dry", "Stop off-dry (≈15 g/L)", "Stop medium (≈35 g/L)", "Stop sweet (≈60 g/L)" },
            "Chilling and adding SO₂ stops fermentation with sugar left (the Mosel Kabinett / feinherb way). Needs sterile filtration at bottling.", WhiteOnly: true, LockedAfterFermentStart: false),
        new("MLF", new[] { "Block (SO₂ after fermentation)", "Inoculate", "Spontaneous" },
            "Malolactic conversion turns sharp malic acid into softer lactic acid (TA falls, pH rises) and can add buttery notes. Usual for reds; for crisp whites it's often blocked.", LockedAfterFermentStart: false),
        new("Vessel", new[] { "Stainless steel", "Old Fuder (1 000 L)", "Neutral barriques", "Barriques 1st fill", "New French barriques", "New American barriques" },
            "Steel keeps fruit pure. Old wood adds texture through slow oxygen exchange without oak flavour. New barriques add vanilla, toast and spice; American oak adds more coconut (oak lactone).", LockedAfterFermentStart: false),
        new("Toast", new[] { "Medium", "Light", "Medium+", "Heavy" },
            "Toast level shapes oak flavour: heavier toast gives more smoky, toasty notes (volatile phenols and furanic compounds); its effect on the coconut-like oak lactones depends on the wood.", LockedAfterFermentStart: false),
        new("Ageing", new[] { "6 months", "3 months", "10 months", "18 months" },
            "Time in vessel before bottling. Longer oak ageing integrates tannin and builds oak character; Côte d'Or AOC wines may not be released before 15 June after harvest.", LockedAfterFermentStart: false),
        new("Lees", new[] { "Fine lees", "Racked off lees", "Fine lees + bâtonnage" },
            "Ageing on fine lees adds texture (mannoproteins) and protects from oxidation; stirring (bâtonnage) adds bready, creamy notes but risks reduction if neglected.", LockedAfterFermentStart: false),
        new("SO₂", new[] { "Adjust to pH (molecular 0.8 whites / 0.5 reds)", "Low (20 mg/L free)", "Fixed 30 mg/L free" },
            "Free SO₂ protects against oxidation and microbes; what matters is molecular SO₂ (≈0.8 mg/L for whites, 0.5 for reds), which falls fast as pH rises.", LockedAfterFermentStart: false),
    };
    public static Choice Get(string key) => All.First(c => c.Key == key);
    public static IEnumerable<Choice> For(bool red) => All.Where(c => red ? !c.WhiteOnly : !c.RedOnly);
}

public enum LotPhase { Received, ColdSoak, Fermenting, Stuck, PostMaceration, Pressed, Malolactic, Ageing, Ready, Blended }

/// <summary>A Lot: the fruit of one Block in one Vintage, fermented and aged as its own batch (CONTEXT.md).</summary>
public sealed class Lot
{
    public string Id { get; set; } = "";
    public string BlockId { get; set; } = "";
    public string VarietyName { get; set; } = "";
    public bool Red { get; set; }
    public DateOnly Harvested { get; set; }
    /// <summary>The Vintage this Lot belongs to: its harvest year (the December rule picks every Block within its year).</summary>
    public int Vintage => Harvested.Year;
    public DateOnly? FermentStart, FermentEnd, MlfEnd, AgeingStart, ReadyDate;
    public double GrapeKg, VolumeL;
    public double VineyardHa;
    public LotPhase Phase { get; set; } = LotPhase.Received;
    public int PhaseDay;
    public Dictionary<string, int> Choices { get; } = CellarOptions.All.ToDictionary(c => c.Key, _ => 0);
    // composition (g/L unless noted)
    public double Sugar, Ethanol, Malic, Tartaric, Lactic, Acetic, Succinic, Glycerol, PotassiumGL, YanMgL, Biomass, TempC, FreeSo2, TotalSo2;
    public double NaturalOe, NaturalSugar, ChaptalSugarAdded, AcidAdded, WaterAdded;
    public double HarvestTa, HarvestPh;
    public double Anthocyanin, SkinTannin, SeedTannin, StemTannin, PolymericPigment, OakTannin;   // mg/L
    public double AnthPotential, SkinTanPotential, SeedTanPotential, StemTanPotential;            // mg/L max extractable
    public double IsoamylAcetate, EthylHexanoate, Damascenone, Linalool, TdnPotential, Ibmp, ThiolPotential, Thiol3mh, Diacetyl; // µg/L (IBMP, 3MH in ng/L)
    public double OakLactone, Vanillin, Guaiacol, Eugenol, Furfural;                               // µg/L
    public double YanStart, YanTarget;   // YAN at inoculation (after DAP) and what this must needed (fermentation.md YAN heuristic)
    public double H2sIndex, Acetaldehyde, FourEp, OxygenDose, LeesMonths, BatonnageMonths, Laccase, MustyIndex, SunburnIndex, NobleRotShare, GreyRotShare;
    public double SeedMaturity, IbmpGrape, WholeBunchShare, Clarity = 1;
    public double MaxTempC, DapAddedMgL;
    public bool Stopped, MlfBlocked, Restarted;
    public List<(int Day, double Sugar, double Temp)> Curve { get; } = new();
    public List<string> Log { get; } = new();
    public string Status => Phase switch
    {
        LotPhase.Received => "Received",
        LotPhase.ColdSoak => $"Cold soak, day {PhaseDay}",
        LotPhase.Fermenting => $"Alcoholic fermentation, day {PhaseDay}",
        LotPhase.Stuck => "Fermentation STUCK",
        LotPhase.PostMaceration => $"Post-fermentation maceration, day {PhaseDay}",
        LotPhase.Pressed => "Pressed, settling",
        LotPhase.Malolactic => $"Malolactic fermentation, day {PhaseDay}",
        LotPhase.Ageing => $"Ageing in {Opt("Vessel")}, month {PhaseDay / 30 + 1}",
        LotPhase.Ready => "Ready to bottle",
        _ => "Blended into a Wine",
    };
    public string Opt(string key) => CellarOptions.Get(key).Options[Choices[key]];
    public double Rs => Math.Max(0, Sugar);
    public double AlcoholPct => Units.EthanolGLToPctVol(Ethanol);
    public AcidComposition Acids => new() { Tartaric = Tartaric, Malic = Malic, Lactic = Lactic, Acetic = Acetic, Succinic = Succinic, Citric = 0.25, PotassiumGL = PotassiumGL, EthanolPctVol = AlcoholPct };
    public double Ph => Chemistry.Ph(Acids);
    public double Ta => Chemistry.TitratableAcidity(Acids);
    public double MolecularSo2 => Chemistry.MolecularSo2(FreeSo2, Ph);
    public double Oe => Units.OeFromSugar(Math.Max(0, Sugar));
    public double TotalTannin => SkinTannin + SeedTannin + StemTannin + OakTannin + (Red ? 0 : 60);
    public int AgeingMonthsTarget => Choices["Ageing"] switch { 1 => 3, 2 => 10, 3 => 18, _ => 6 };
}

/// <summary>Daily winery model per Lot, with an hourly fermentation integrator. docs/science/{fermentation, acid-ph-so2, extraction-and-oak,
/// aroma-and-faults}.md. Kinetic constants are design values shaped to the doc's calibration checks (Coleman 2007 values UNVERIFIED).</summary>
public static class WineryModel
{
    public const double CellarTempC = 14.0;

    /// <summary>Sorting trade-off (game simplification, UNVERIFIED shares): share of the grey rot removed, share of sound fruit
    /// lost with it, and the extra sorting labour in hours per kg picked.</summary>
    public static (double rotRemoved, double soundLoss, double hoursPerKg) Sorting(SortingLevel s) => s switch
    {
        SortingLevel.Rigorous => (0.9, 0.08, 0.012),
        SortingLevel.Table => (0.6, 0.03, 0.004),
        _ => (0.1, 0.0, 0.0),
    };

    public static Lot FromBlock(BlockState b, string lotId, DateOnly date, double grapeKg, SortingLevel sorting)
    {
        var must = Chemistry.MustFromBlock(b);
        var v = b.Variety;
        double rot = b.Disease.GreyRot;
        var so = Sorting(sorting);
        double removed = so.rotRemoved;
        double kgLoss = so.soundLoss + rot * removed;
        double kg = grapeKg * (1 - kgLoss);
        var lot = new Lot
        {
            Id = lotId, BlockId = b.Data.Id, VarietyName = v.Name, Red = v.Red, Harvested = date, GrapeKg = kg, VineyardHa = b.AreaHa,
            Sugar = must.SugarGL, NaturalSugar = must.SugarGL, NaturalOe = must.Oe, Malic = must.MalicGL, Tartaric = must.TartaricGL,
            PotassiumGL = must.PotassiumGL, YanMgL = must.YanMgL, TempC = 18, HarvestTa = must.TaGL, HarvestPh = must.Ph,
            SeedMaturity = b.SeedMaturity, IbmpGrape = b.Ibmp, TdnPotential = b.TdnPotential, ThiolPotential = b.ThiolPotential,
            GreyRotShare = rot * (1 - removed), NobleRotShare = b.Disease.NobleRot, MustyIndex = b.Disease.PowderyBunch * (1 - removed * 0.5),
            SunburnIndex = b.SunburnFraction * (1 - removed * 0.6),
        };
        lot.Laccase = lot.GreyRotShare;
        lot.Log.Add($"{Dates.Short(date)}: {kg:0} kg picked from Block {b.Data.Id} ({must.Oe:0} °Oe, TA {must.TaGL:0.0} g/L, pH {must.Ph:0.00}){(rot > 0.02 ? $", sorting removed {removed * 100:0}% of the {rot * 100:0}% grey rot" : "")}.");
        // potentials for extraction (reds) — mg/L if fully extracted (extraction-and-oak.md §2)
        double conc = b.BerryWeightPeak > 0 ? Math.Clamp(v.BerryWeightG / Math.Max(0.3, b.BerryWeight), 0.8, 1.6) : 1;   // small berries → more skin per juice
        lot.AnthPotential = v.Red ? b.Anthocyanin * 600 * conc : 0;
        lot.SkinTanPotential = v.Red ? (60 + 420 * v.TanninPotential) * conc * b.SkinExtractability : 0;
        lot.SeedTanPotential = v.Red ? (150 + 450 * v.TanninPotential) * (1 - 0.6 * b.SeedMaturity) * conc : 0;
        lot.Damascenone = 1.5 + 1.5 * b.Exposure + 2.5 * lot.NobleRotShare;
        lot.Linalool = v.Id switch { Data.VarietyId.Riesling => 35, Data.VarietyId.Chardonnay => 4, Data.VarietyId.PinotNoir => 5, _ => 3 } * (0.8 + 0.5 * b.Exposure);
        return lot;
    }

    public static void Step(Lot lot, DateOnly date, StaffLevel cellarMaster, List<VineEvent> events)
    {
        lot.PhaseDay++;
        switch (lot.Phase)
        {
            case LotPhase.Received: Receive(lot, date, events); break;
            case LotPhase.ColdSoak:
                lot.TempC = 9;
                Extract(lot, 24, coldSoak: true);
                int soak = lot.Choices["Cold soak"] switch { 1 => 3, 2 => 7, _ => 0 };
                if (lot.PhaseDay >= soak) StartFermentation(lot, date, events);
                break;
            case LotPhase.Fermenting:
            case LotPhase.Stuck:
                Ferment(lot, date, cellarMaster, events); break;
            case LotPhase.PostMaceration:
                lot.TempC += (22 - lot.TempC) * 0.2;
                Extract(lot, 24, coldSoak: false);
                if (lot.PhaseDay >= 7) Press(lot, date, events);
                break;
            case LotPhase.Pressed:
                if (lot.PhaseDay >= 2) AfterFermentation(lot, date, events);
                break;
            case LotPhase.Malolactic: Malolactic(lot, date, events); break;
            case LotPhase.Ageing: Age(lot, date, events); break;
        }
    }

    private static void Receive(Lot lot, DateOnly date, List<VineEvent> events)
    {
        if (!lot.Red)
        {
            int press = lot.Choices["Pressing"];
            double yield = press switch { 0 => 0.60, 1 => 0.66, _ => 0.68 };
            lot.VolumeL = lot.GrapeKg * yield;
            lot.SkinTannin = press switch { 0 => 40, 1 => 90, _ => 160 };
            lot.ThiolPotential *= press == 2 ? 1.5 : press == 1 ? 1.15 : 1.0;
            lot.PotassiumGL += press == 2 ? 0.12 : press == 1 ? 0.05 : 0;
            int settle = lot.Choices["Settling"];
            lot.Clarity = settle switch { 1 => 1.0, 0 => 0.85, _ => 0.45 };
            lot.Log.Add($"{Dates.Short(date)}: {lot.Opt("Pressing").ToLowerInvariant()} → {lot.VolumeL:0} L of juice; {lot.Opt("Settling").ToLowerInvariant()}.");
            StartFermentation(lot, date.AddDays(1), events);
        }
        else
        {
            double wb = lot.Choices["Destemming"] switch { 1 => 0.3, 2 => 1.0, _ => 0 };
            lot.WholeBunchShare = wb;
            lot.VolumeL = lot.GrapeKg * 0.74;                      // must volume on skins; pressing later yields ~0.72 L/kg total wine
            lot.StemTanPotential = wb * (250 + 300 * (1 - lot.SeedMaturity));
            lot.PotassiumGL += 0.15 * wb;
            lot.IsoamylAcetate += 400 * wb;                         // carbonic-maceration style fruit from intact berries
            lot.Log.Add($"{Dates.Short(date)}: {lot.Opt("Destemming").ToLowerInvariant()}, {lot.VolumeL:0} L of must on skins.");
            if (lot.Choices["Cold soak"] > 0) { lot.Phase = LotPhase.ColdSoak; lot.PhaseDay = 0; }
            else StartFermentation(lot, date, events);
        }
    }

    private static void StartFermentation(Lot lot, DateOnly date, List<VineEvent> events)
    {
        int chap = lot.Choices["Chaptalisation"];
        if (chap > 0) { lot.ChaptalSugarAdded = chap * 16.83; lot.Sugar += lot.ChaptalSugarAdded; }
        int acid = lot.Choices["Acidification"];
        if (acid > 0) { lot.AcidAdded = acid; lot.Tartaric += acid; }
        // fermentation.md: YAN target 140 mg/L at 20 °Brix + 25 mg/L per extra °Brix (game heuristic, UNVERIFIED); DAP tops the must up to it
        lot.YanTarget = 140 + 25 * Math.Max(0, Units.BrixFromSugar(lot.Sugar) - 20);
        if (lot.Choices["Nutrients"] == 0 && lot.YanMgL < lot.YanTarget) { lot.DapAddedMgL = lot.YanTarget - lot.YanMgL + 20; lot.YanMgL += lot.DapAddedMgL; }
        lot.YanStart = lot.YanMgL;
        bool ambient = lot.Choices["Yeast"] == 1;
        lot.Biomass = ambient ? 0.015 : 0.2;
        lot.TempC = lot.Red ? 20 : 15;
        lot.FermentStart = date;
        lot.Phase = LotPhase.Fermenting; lot.PhaseDay = 0;
        lot.Log.Add($"{Dates.Short(date)}: fermentation started with {(ambient ? "ambient yeast" : "cultured yeast")}{(lot.DapAddedMgL > 0 ? $", DAP added (+{lot.DapAddedMgL:0} mg/L YAN)" : "")}{(chap > 0 ? $", chaptalised +{chap} % vol" : "")}{(acid > 0 ? $", acidified +{acid} g/L" : "")}.");
        events.Add(new VineEvent(date, lot.BlockId, "ferment-start", $"Lot {lot.Id}: fermentation has started ({lot.Oe:0} °Oe must, YAN {lot.YanMgL:0} mg/L).") { LotId = lot.Id });
    }

    private static double SetpointFor(Lot lot)
    {
        if (!lot.Red) return lot.Choices["Temperature"] switch { 1 => 14, 2 => 18, 3 => double.NaN, _ => 16 };
        return lot.Choices["Red temperature"] switch { 1 => 22, 2 => 30, 3 => double.NaN, _ => 26 };
    }

    /// <summary>Hourly fermentation (Coleman-type): yeast growth limited by nitrogen, sugar uptake, ethanol-driven inactivation rising
    /// steeply with temperature, and a tank heat balance (~1.3 °C per °Brix fermented without cooling).</summary>
    private static void Ferment(Lot lot, DateOnly date, StaffLevel cellarMaster, List<VineEvent> events)
    {
        double sp = SetpointFor(lot);
        double deadband = cellarMaster switch { StaffLevel.Senior => 0.5, StaffLevel.Junior => 2.0, _ => 1.0 };
        bool ambient = lot.Choices["Yeast"] == 1;
        double sugarStart = lot.Sugar;
        double stopAt = lot.Red ? 0 : lot.Choices["Sweetness"] switch { 1 => 15, 2 => 35, 3 => 60, _ => 0 };
        double pressEarlyAt = lot.Red && lot.Choices["Maceration"] == 2 ? Units.SugarFromOe(5) + 3 : -1;
        double volumeFactor = lot.VolumeL < 1500 ? 0.6 : 1.0;   // small lots lose heat faster
        for (int h = 0; h < 24; h++)
        {
            double T = lot.TempC;
            double n = lot.YanMgL / 1000.0 / 1.0;                       // g N/L equivalent (YAN mg/L → g/L)
            double tf = Math.Pow(1.07, T - 20);
            double lag = ambient && lot.PhaseDay < 3 ? 0.4 : 1.0;
            double mu = 0.16 * tf * lag * n / (0.02 + n);
            double kd = 0.00003 * Math.Exp(0.15 * (T - 20)) * (T > 32 ? 4 : 1);
            double uptake = 0.42 * tf * lot.Biomass * lot.Sugar / (10 + lot.Sugar) * (1 - 0.3 * Math.Min(1, lot.GreyRotShare * 4));
            if (ambient) uptake *= 0.85;
            // ethanol shuts down hexose transport near the strain's tolerance (Bisson 1999 mechanism; fermentation.md "very high sugar" stuck cause).
            // Tolerance 16.8 % cultured / 15.5 % ambient and the exponent are UNVERIFIED calibration.
            // A restart culture (acclimatised, alcohol-tolerant strain of the EC-1118 type) tolerates ≈18 % (UNVERIFIED).
            double tolerance = lot.Restarted ? 18.0 : ambient ? 15.5 : 16.8;
            uptake *= Math.Max(0, 1 - Math.Pow(lot.Ethanol / 7.89 / tolerance, 6));
            double dX = mu * lot.Biomass - kd * lot.Ethanol * lot.Biomass;
            double dN = -mu * lot.Biomass / 12.0 * 1000;                 // mg/L N used
            double dS = -Math.Min(lot.Sugar, uptake);
            lot.Biomass = Math.Max(0.0005, lot.Biomass + dX);
            lot.YanMgL = Math.Max(0, lot.YanMgL + dN);
            lot.Sugar += dS;
            lot.Ethanol += -dS * 0.47;
            lot.Glycerol += -dS * 0.035;
            lot.Succinic += -dS * 0.004;
            // heat balance: 0.126 °C per g/L sugar fermented (adiabatic), jacket cooling towards setpoint, loss to cellar
            T += -dS * 0.126;
            if (!double.IsNaN(sp) && T > sp + deadband / 2) T -= Math.Min(T - sp, 0.35);
            T += (CellarTempC + (lot.Red ? 4 : 0) - T) * 0.004 * volumeFactor * (double.IsNaN(sp) ? 1.5 : 1);
            lot.TempC = T;
            lot.MaxTempC = Math.Max(lot.MaxTempC, T);
            // esters: favoured by cool, clean, nitrogen-rich fermentations (aroma-and-faults.md)
            double esterRate = -dS * (T < 15 ? 30 : T < 18 ? 24 : T < 24 ? 12 : 6) * lot.Clarity * (ambient ? 0.8 : 1.0) * (lot.YanMgL > 50 ? 1 : 0.6);
            lot.IsoamylAcetate += esterRate;
            lot.EthylHexanoate += esterRate * 0.2;
            // H₂S when yeast run short of nitrogen while sugar remains, worse when warm and cloudy
            // (yeast always use up YAN mid-ferment; how much H₂S follows depends on how short the must was of its requirement)
            double deficit = M.Clamp(1 - lot.YanStart / Math.Max(1, lot.YanTarget), 0, 1);
            if (lot.YanMgL < 30 && lot.Sugar > 30) lot.H2sIndex += 0.01 * (0.1 + 1.5 * deficit) * (1 + (T - 16) / 10) * (2 - lot.Clarity);
            if (lot.Red) Extract(lot, 1, coldSoak: false);
            if (stopAt > 0 && lot.Sugar <= stopAt) { StopFermentation(lot, date, events); return; }
            if (pressEarlyAt > 0 && lot.Sugar <= pressEarlyAt) { EndFermentationPhase(lot, date, events, pressedEarly: true); return; }
        }
        // thiols released during fermentation
        lot.Thiol3mh = lot.ThiolPotential * 1600 * Math.Min(1, (lot.NaturalSugar - lot.Sugar) / Math.Max(1, lot.NaturalSugar));
        lot.Curve.Add((lot.PhaseDay, Math.Round(Units.OeFromSugar(Math.Max(0, lot.Sugar)), 1), Math.Round(lot.TempC, 1)));
        double rate = sugarStart - lot.Sugar;
        if (lot.MaxTempC > 32 && lot.Log.All(l => !l.Contains("heat")))
        {
            lot.Log.Add($"{Dates.Short(date)}: fermentation overheated to {lot.MaxTempC:0} °C — yeast are dying (heat).");
            events.Add(new VineEvent(date, lot.BlockId, "ferment-hot", $"Lot {lot.Id} reached {lot.MaxTempC:0} °C. Above ~32 °C yeast die fast; the fermentation may stick.", 3) { LotId = lot.Id });
        }
        if (lot.Sugar <= 2) { EndFermentationPhase(lot, date, events, pressedEarly: false); return; }
        if (lot.Phase == LotPhase.Fermenting && lot.PhaseDay > 5 && rate < 1.0 && lot.Sugar > 4)
        {
            lot.Phase = LotPhase.Stuck;
            events.Add(new VineEvent(date, lot.BlockId, "ferment-stuck", $"Lot {lot.Id}: fermentation has STUCK at {lot.Sugar:0} g/L sugar ({lot.Oe:0} °Oe). Yeast are exhausted (YAN {lot.YanMgL:0} mg/L, max {lot.MaxTempC:0} °C, {lot.AlcoholPct:0.0} % vol). Re-inoculating with a robust yeast can restart it.", 3) { LotId = lot.Id });
            lot.Log.Add($"{Dates.Short(date)}: fermentation STUCK at {lot.Sugar:0} g/L.");
        }
        if (lot.H2sIndex > 0.5 && lot.Log.All(l => !l.Contains("H₂S")))
        {
            lot.Log.Add($"{Dates.Short(date)}: H₂S (rotten egg) detected — yeast short of nitrogen.");
            events.Add(new VineEvent(date, lot.BlockId, "ferment-h2s", $"Lot {lot.Id} smells of rotten egg (H₂S): the yeast ran out of nitrogen. Aeration now helps; left alone it becomes a reduction fault.", 2) { LotId = lot.Id });
        }
    }

    public static void Restart(Lot lot, DateOnly date)
    {
        if (lot.Phase != LotPhase.Stuck) return;
        lot.Biomass = 0.3; lot.YanMgL += 60; lot.TempC = Math.Min(lot.TempC, 20); lot.Restarted = true;
        lot.Phase = LotPhase.Fermenting;
        lot.Log.Add($"{Dates.Short(date)}: re-inoculated with an alcohol-tolerant yeast and nutrients to restart the fermentation.");
    }

    /// <summary>The player gives up on a stuck fermentation: chill, add SO₂ and carry on with the sugar that is left.</summary>
    public static void AcceptStuck(Lot lot, DateOnly date)
    {
        if (lot.Phase != LotPhase.Stuck) return;
        lot.Log.Add($"{Dates.Short(date)}: decided to stop the stuck fermentation and keep the {lot.Rs:0} g/L of sugar.");
        StopFermentation(lot, date, new List<VineEvent>());
    }

    private static void StopFermentation(Lot lot, DateOnly date, List<VineEvent> events)
    {
        lot.Stopped = true;
        lot.Biomass = 0.001; lot.TempC = 4;
        lot.FreeSo2 = 40; lot.TotalSo2 = 90;
        lot.MlfBlocked = true;
        lot.FermentEnd = date;
        lot.Log.Add($"{Dates.Short(date)}: fermentation stopped by chilling and SO₂ at {lot.Rs:0} g/L residual sugar, {lot.AlcoholPct:0.0} % vol.");
        events.Add(new VineEvent(date, lot.BlockId, "ferment-stopped", $"Lot {lot.Id}: fermentation stopped at {lot.Rs:0} g/L sugar and {lot.AlcoholPct:0.0} % vol (chilled, SO₂ added).") { LotId = lot.Id });
        lot.Phase = LotPhase.Pressed; lot.PhaseDay = 0;
    }

    private static void EndFermentationPhase(Lot lot, DateOnly date, List<VineEvent> events, bool pressedEarly)
    {
        lot.FermentEnd = date;
        lot.Log.Add($"{Dates.Short(date)}: fermentation finished — {lot.AlcoholPct:0.0} % vol, {lot.Rs:0.0} g/L sugar, peak {lot.MaxTempC:0} °C.");
        events.Add(new VineEvent(date, lot.BlockId, "ferment-done", $"Lot {lot.Id}: fermentation finished at {lot.AlcoholPct:0.0} % vol ({lot.Rs:0.0} g/L sugar left).{(lot.Red && !pressedEarly && lot.Choices["Maceration"] == 1 ? " Extended maceration continues for 7 days." : "")}") { LotId = lot.Id });
        if (lot.Red && !pressedEarly && lot.Choices["Maceration"] == 1) { lot.Phase = LotPhase.PostMaceration; lot.PhaseDay = 0; }
        else if (lot.Red) Press(lot, date, events);
        else { lot.Phase = LotPhase.Pressed; lot.PhaseDay = 0; }
    }

    private static void Press(Lot lot, DateOnly date, List<VineEvent> events)
    {
        lot.VolumeL *= 0.97;   // free run + press (0.72 L/kg overall from 0.74 on skins)
        lot.Log.Add($"{Dates.Short(date)}: pressed — {lot.VolumeL:0} L of new wine. Tannin {lot.SkinTannin + lot.SeedTannin + lot.StemTannin:0} mg/L, colour {lot.Anthocyanin:0} mg/L.");
        lot.Phase = LotPhase.Pressed; lot.PhaseDay = 0;
    }

    /// <summary>Extraction kinetics of anthocyanins, skin, seed and stem tannin (extraction-and-oak.md §2).</summary>
    private static void Extract(Lot lot, int hours, bool coldSoak)
    {
        if (!lot.Red) return;
        double T = lot.TempC, E = lot.AlcoholPct;
        double m = lot.Choices["Cap management"] switch { 1 => 1.2, 2 => 1.3, 3 => 0.5, _ => 1.0 };
        double theta(double q) => Math.Pow(q, (T - 25) / 10);
        for (int h = 0; h < hours; h++)
        {
            double kA = 0.018 * theta(1.8) * m * (coldSoak ? 0.5 : 1);
            lot.Anthocyanin += kA * (lot.AnthPotential - lot.Anthocyanin) - 0.0025 * lot.Anthocyanin * (E / 13.0);
            double poly = 0.0003 * lot.Anthocyanin * Math.Min(1, (lot.SkinTannin + lot.SeedTannin) / 400.0);
            lot.PolymericPigment += poly; lot.Anthocyanin -= poly * 0.5;
            lot.SkinTannin += 0.008 * theta(1.6) * m * (lot.SkinTanPotential - lot.SkinTannin) * (coldSoak ? 0.4 : 1);
            double ethanolGate = M.Clamp(E / 8.0, 0, 1);
            double seedPot = lot.Choices["Cap management"] == 2 ? lot.SeedTanPotential * 0.75 : lot.SeedTanPotential;
            lot.SeedTannin += 0.005 * theta(2.0) * m * ethanolGate * (seedPot - lot.SeedTannin);
            lot.StemTannin += 0.006 * theta(1.6) * (lot.StemTanPotential - lot.StemTannin);
            lot.Ibmp = lot.IbmpGrape * (0.6 + 0.4 * M.Clamp((lot.SkinTannin) / Math.Max(1, lot.SkinTanPotential), 0, 1)) + lot.WholeBunchShare * 4;
        }
    }

    private static void AfterFermentation(Lot lot, DateOnly date, List<VineEvent> events)
    {
        if (!lot.Red) lot.Ibmp = lot.IbmpGrape * 0.4;
        int mlf = lot.Choices["MLF"];
        if (lot.MlfBlocked || mlf == 0)
        {
            AddSo2(lot, date);
            StartAgeing(lot, date, events);
        }
        else { lot.Phase = LotPhase.Malolactic; lot.PhaseDay = 0; lot.Log.Add($"{Dates.Short(date)}: malolactic fermentation {(mlf == 1 ? "inoculated" : "left to start spontaneously")}."); }
    }

    /// <summary>MLF by O. oeni: malic → lactic + CO₂ (1 g → 0.672 g); rate depends on temperature, pH, SO₂ and ethanol (acid-ph-so2.md §5).</summary>
    private static void Malolactic(Lot lot, DateOnly date, List<VineEvent> events)
    {
        bool inoc = lot.Choices["MLF"] == 1;
        double T = Math.Max(lot.TempC = lot.TempC + (17 - lot.TempC) * 0.2, 10);
        double ph = lot.Ph;
        if (!inoc && lot.PhaseDay < 12) return;   // spontaneous lag
        double r = 0.12 * Math.Pow(1.08, T - 18) * M.Clamp((ph - 2.9) / 0.5, 0.05, 1.2) * (lot.AlcoholPct > 14 ? 0.5 : 1) * (inoc ? 1.3 : 0.8);
        double converted = Math.Min(lot.Malic, r * lot.Malic / (0.5 + lot.Malic) * 1.2);
        lot.Malic -= converted; lot.Lactic += converted * 0.672;
        lot.Diacetyl += converted * (inoc ? 0.25 : 0.55);
        if (!inoc) lot.Acetic += converted * 0.01;
        if (lot.Malic < 0.1)
        {
            lot.MlfEnd = date;
            lot.Log.Add($"{Dates.Short(date)}: malolactic fermentation complete — TA {lot.Ta:0.0} g/L, pH {lot.Ph:0.00}.");
            events.Add(new VineEvent(date, lot.BlockId, "mlf-done", $"Lot {lot.Id}: malolactic fermentation finished (TA now {lot.Ta:0.0} g/L, pH {lot.Ph:0.00}).") { LotId = lot.Id });
            AddSo2(lot, date);
            StartAgeing(lot, date, events);
        }
    }

    /// <summary>Free SO₂ the Cellar master aims for. "Adjust to pH" uses free = molecular × (1 + 10^(pH − 1.81)) (acid-ph-so2.md §3),
    /// capped at 60 mg/L free to stay well inside EU/US total-SO₂ limits (cap is a game simplification).</summary>
    public static double So2Target(Lot lot) => lot.Choices["SO₂"] switch
    {
        1 => 20,
        2 => 30,
        _ => Math.Clamp((lot.Red ? 0.5 : 0.8) * (1 + Math.Pow(10, lot.Ph - 1.81)), 20, 60),
    };
    private static void AddSo2(Lot lot, DateOnly date)
    {
        double target = So2Target(lot);
        if (lot.FreeSo2 < target) { lot.TotalSo2 += (target - lot.FreeSo2) * 2.2; lot.FreeSo2 = target; }
        lot.Log.Add($"{Dates.Short(date)}: SO₂ adjusted to {lot.FreeSo2:0} mg/L free (molecular {lot.MolecularSo2:0.00} mg/L at pH {lot.Ph:0.00}).");
    }

    private static void StartAgeing(Lot lot, DateOnly date, List<VineEvent> events)
    {
        lot.AgeingStart = date; lot.Phase = LotPhase.Ageing; lot.PhaseDay = 0;
        if (lot.Choices["Lees"] == 1) { lot.H2sIndex *= 0.4; }
        lot.Log.Add($"{Dates.Short(date)}: into {lot.Opt("Vessel").ToLowerInvariant()} for about {lot.AgeingMonthsTarget} months ({lot.Opt("Lees").ToLowerInvariant()}).");
    }

    public record VesselProps(double SurfaceRatio, double Fill, bool French, bool American, double OxygenMgLPerMonth, double PricePer, double Litres);
    public static VesselProps Vessel(Lot lot) => lot.Choices["Vessel"] switch
    {
        1 => new VesselProps(0.5, 0.08, true, false, 0.7, 900, 1000),     // old Fuder
        2 => new VesselProps(1.0, 0.1, true, false, 1.5, 120, 225),       // neutral barriques
        3 => new VesselProps(1.0, 0.45, true, false, 2.0, 380, 225),      // 1st fill
        4 => new VesselProps(1.0, 1.0, true, false, 2.5, 950, 225),       // new French
        5 => new VesselProps(1.0, 1.0, false, true, 2.5, 520, 225),       // new American
        _ => new VesselProps(0, 0, false, false, 0.05, 0, 0),             // stainless
    };

    /// <summary>Ageing (extraction-and-oak.md §4–5; aroma-and-faults.md faults): oak compounds C_j(t) = pot·f_species·f_toast·f_fill·(S/V)·(1 − e^(−kt)),
    /// oxygen uptake against free SO₂, acetaldehyde, lees, Brettanomyces and VA risk.</summary>
    private static void Age(Lot lot, DateOnly date, List<VineEvent> events)
    {
        var vp = Vessel(lot);
        double months = lot.PhaseDay / 30.0;
        lot.TempC += (CellarTempC - lot.TempC) * 0.1;
        int toast = lot.Choices["Toast"];                                     // 0 Medium, 1 Light, 2 Medium+, 3 Heavy
        double sv = vp.SurfaceRatio, fill = vp.Fill, k = 0.12;               // per month
        double sat = 1 - Math.Exp(-k * months);
        double spec = vp.American ? 1.0 : 0.0;
        lot.OakLactone = 380 * (vp.American ? 2.6 : 1.0) * (toast == 3 ? 0.6 : toast == 1 ? 1.1 : 1.0) * fill * sv * sat;
        lot.Vanillin = 160 * (toast switch { 1 => 0.6, 2 => 1.15, 3 => 0.9, _ => 1.0 }) * fill * sv * sat;
        lot.Guaiacol = 22 * (toast switch { 1 => 0.3, 2 => 1.4, 3 => 2.4, _ => 1.0 }) * fill * sv * sat;
        lot.Eugenol = 14 * (toast switch { 1 => 0.6, 2 => 1.2, 3 => 1.5, _ => 1.0 }) * (1 + 0.3 * spec) * fill * sv * sat;
        lot.Furfural = 3000 * (toast switch { 1 => 0.5, 2 => 1.3, 3 => 1.6, _ => 1.0 }) * fill * sv * sat;
        lot.OakTannin = 180 * fill * sv * sat * (vp.American ? 0.7 : 1.0);
        // oxygen and SO₂
        double o2 = vp.OxygenMgLPerMonth / 30.0 * (lot.Choices["Lees"] == 1 ? 1.0 : 0.6) + (lot.Choices["Lees"] == 2 ? 0.02 : 0);
        lot.OxygenDose += o2;
        double so2Use = Math.Min(lot.FreeSo2, o2 * 4);
        lot.FreeSo2 -= so2Use; lot.TotalSo2 -= so2Use * 0.5;
        if (lot.FreeSo2 < 8) lot.Acetaldehyde += (o2 - so2Use / 4) * 3 * (1 + lot.Laccase * 3);
        lot.Acetaldehyde += lot.Laccase * 0.4;
        // monthly SO₂ top-up by the cellar master
        if (lot.PhaseDay % 30 == 0 && lot.FreeSo2 < So2Target(lot) * 0.7) AddSo2(lot, date);
        // tannin polymerisation softens and pigments stabilise with a little oxygen
        if (lot.Red) { double p = 0.002 * Math.Min(1, lot.OxygenDose / 20 + 0.3); lot.PolymericPigment += lot.Anthocyanin * p; lot.Anthocyanin *= 1 - p * 1.2; lot.SeedTannin *= 1 - p * 0.3; }
        // lees
        if (lot.Choices["Lees"] != 1) { lot.LeesMonths += 1 / 30.0; if (lot.Choices["Lees"] == 2) lot.BatonnageMonths += 1 / 30.0; }
        lot.H2sIndex *= lot.Choices["Lees"] == 0 && lot.PhaseDay < 60 ? 0.995 : 0.97;
        // Brettanomyces: high pH, low molecular SO₂, warmer than 12 °C, used wood, residual nutrients (aroma-and-faults.md, Chatonnet 1992 drivers)
        double mol = lot.MolecularSo2;
        bool usedWood = lot.Choices["Vessel"] is 1 or 2 or 3;
        if (lot.Ph > 3.55 && mol < 0.4 && usedWood) lot.FourEp += 1.8 * (lot.Ph - 3.5) * (0.5 - mol) * 10 * (lot.TempC > 12 ? 1 : 0.5);
        if (mol < 0.2 && usedWood) lot.Acetic += 0.0012;
        // esters fade slowly
        lot.IsoamylAcetate *= 0.997;
        if (months >= lot.AgeingMonthsTarget && lot.Phase == LotPhase.Ageing)
        {
            lot.Phase = LotPhase.Ready; lot.ReadyDate = date;
            lot.Log.Add($"{Dates.Short(date)}: ready to bottle after {months:0} months.");
            events.Add(new VineEvent(date, lot.BlockId, "lot-ready", $"Lot {lot.Id} has finished its {lot.AgeingMonthsTarget} months in {lot.Opt("Vessel").ToLowerInvariant()} and is ready to bottle or blend.") { LotId = lot.Id });
        }
    }
}
