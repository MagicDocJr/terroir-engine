using TerroirEngine.Util;
using TerroirEngine.Winery;

namespace TerroirEngine.Tasting;

public sealed record Descriptor(string Category, string Family, string Terms, string Intensity, string Because);
public sealed record StructureLine(string Attribute, string Level, string Because);

public sealed class TastingSheet
{
    public string WineName = "", Label = "", Category = "";
    public string Clarity = "clear", ColourIntensity = "", Colour = "", AppearanceBecause = "";
    public string NoseCondition = "clean", NoseIntensity = "", Development = "";
    public List<Descriptor> Aromas { get; } = new();
    public List<StructureLine> Palate { get; } = new();
    public string FlavourIntensity = "", Finish = "";
    public List<string> Faults { get; } = new();
    public string Quality = "", QualityBecause = "", Readiness = "";
    public List<(string Criterion, bool Met, string Why)> Blic { get; } = new();
    // Tasting sheet 2 (docs/superpowers/specs/2026-10-02-tasting-sheet-2-design.md §3)
    public static readonly string[] ColoursWhite = { "lemon-green", "lemon", "gold", "amber", "brown" };
    public static readonly string[] ColoursRed = { "purple", "ruby", "garnet", "tawny", "brown" };
    public static readonly string[] FruitRipenessScale = { "unripe", "fresh", "ripe", "dried or cooked" };
    public static readonly string[] ReadinessOptions = { "too young", "can drink now, has potential for ageing", "drink now, not for (further) ageing", "too old" };
    public static readonly string[] FruitFamiliesWhite = { "green fruit", "citrus fruit", "stone fruit", "tropical fruit" };
    public static readonly string[] FruitFamiliesRed = { "red fruit", "black fruit" };
    public static bool IsFruit(string family) => FruitFamiliesWhite.Contains(family) || FruitFamiliesRed.Contains(family);
    /// <summary>Other observations (deposit, legs, spritz): noted, not marked.</summary>
    public List<(string Term, string Because)> Observations { get; } = new();
    public string FruitRipeness = "", FruitRipenessBecause = "";
    /// <summary>A nose of very few aromas: nothing from oak, lees, malolactic or age (fermentation esters allowed), at most one clear
    /// family besides the fruit, and no fault.</summary>
    public bool Simple;
    /// <summary>Flavour characteristics: the nose families felt on the palate (medium or above, without smell-only notes).</summary>
    public List<string> Flavours { get; } = new();
    /// <summary>The quality argument: the criteria met and missed with their evidence, and why the Wine is not a level higher.</summary>
    public List<string> QualityFor { get; } = new();
    public List<string> QualityAgainst { get; } = new();
    public string QualityNotHigher = "";
    /// <summary>The drinking window in years from the harvest (structure-based; UNVERIFIED design values).</summary>
    public double WindowYears;
    /// <summary>The raw scores behind the scale words (calibration and the qualitysweep report only; never shown).</summary>
    public double NoseScore, FlavourScore, FinishScore, BodyScore;
    public List<string> Chemistry { get; } = new();
    /// <summary>The Causes (data/causes.json) behind this sheet and the line each shows on: "appearance", "aroma:&lt;family&gt;",
    /// "palate:&lt;Attribute&gt;", "fault" or "vintage" (learning-core design §3.2). Written by the generator at the same
    /// conditions that write each "because".</summary>
    public List<(string Cause, string Line)> CauseLinks { get; } = new();
    public IEnumerable<string> Causes => CauseLinks.Select(x => x.Cause).Distinct();
}

/// <summary>Turns chemistry and history into a structured tasting sheet in our own wording (docs/science/tasting-sheet.md;
/// aroma-and-faults.md odour-activity model OAV = C / threshold, perceived = log10(OAV) + 1 when OAV ≥ 1).</summary>
public static class TastingSheetGenerator
{
    private static readonly Dictionary<string, string> FruitFamily = new()
    {
        ["green apple"] = "green fruit", ["apple"] = "green fruit", ["pear"] = "green fruit",
        ["lime"] = "citrus fruit", ["lemon"] = "citrus fruit", ["grapefruit"] = "citrus fruit",
        ["white peach"] = "stone fruit", ["peach"] = "stone fruit", ["apricot"] = "stone fruit",
        ["pineapple"] = "tropical fruit", ["melon"] = "tropical fruit",
        ["redcurrant"] = "red fruit", ["cranberry"] = "red fruit", ["sour cherry"] = "red fruit", ["red cherry"] = "red fruit", ["raspberry"] = "red fruit", ["strawberry"] = "red fruit",
        ["blackcurrant"] = "black fruit", ["tart blackcurrant"] = "black fruit", ["black cherry"] = "black fruit", ["plum"] = "black fruit", ["blackberry"] = "black fruit",
        ["black plum"] = "black fruit", ["jammy blackcurrant"] = "black fruit",
    };

    private static double Perceived(double c, double threshold) { double oav = c / threshold; return oav < 1 ? 0 : Math.Log10(oav) + 1; }
    private static string IntensityWord(double p) => p <= 0 ? "" : p < 1.3 ? "light" : p < 1.7 ? "medium" : "pronounced";
    private static readonly string[] Five = { "low", "medium(−)", "medium", "medium(+)", "high" };

    public static TastingSheet Generate(Wine wine, IList<(Lot lot, Provenance prov, double litres)> parts, DateOnly tastingDate)
    {
        var b = wine.Blend;
        var s = new TastingSheet { WineName = wine.Name, Label = wine.Legal?.Label ?? "", Category = wine.Legal?.Category ?? "" };
        var p0 = parts.OrderByDescending(p => p.litres).First().prov;
        double ageYears = Math.Max(0, (tastingDate.DayNumber - b.Harvested.DayNumber) / 365.0);
        double ph = b.Ph, ta = b.Ta, alc = b.AlcoholPct, rs = b.Rs;
        bool red = b.Red;
        string v = b.VarietyName;
        double avgExpEarly = parts.Average(p => p.prov.ExposureEarly), yieldT = parts.Average(p => p.prov.YieldKgHa) / 1000.0;
        double harvestOe = b.NaturalOe;
        s.Chemistry.Add($"{alc:0.0} % vol · residual sugar {rs:0.0} g/L · TA {ta:0.0} g/L · pH {ph:0.00} · free SO₂ {b.FreeSo2:0} mg/L (molecular {b.MolecularSo2:0.00})");
        if (red) s.Chemistry.Add($"Tannin {b.TotalTannin:0} mg/L · anthocyanins {b.Anthocyanin:0} mg/L · polymeric pigment {b.PolymericPigment:0} · malic {b.Malic:0.0} g/L");
        else s.Chemistry.Add($"Malic {b.Malic:0.0} g/L · lactic {b.Lactic:0.0} g/L · VA {b.Acetic:0.00} g/L");

        // ---------------- appearance
        if (!red)
        {
            double colourScore = 0.2 * ageYears + b.Acetaldehyde / 120 + (b.OakTannin > 40 ? 0.35 : 0) + b.NobleRotShare * 1.5 + (b.Choices["Pressing"] == 2 ? 0.25 : 0) + b.Laccase * 3 + (b.SunburnIndex * 1.5);
            s.Colour = b.Acetaldehyde > 100 || colourScore >= 2.6 ? "brown" : colourScore < 0.25 ? "lemon-green" : colourScore < 0.8 ? "lemon" : colourScore < 1.6 ? "gold" : "amber";
            s.ColourIntensity = colourScore < 0.35 && alc < 11.5 ? "pale" : colourScore < 1.0 ? "medium" : "deep";
            s.AppearanceBecause = s.Colour switch
            {
                "lemon-green" => "young, protected from oxygen, no oak",
                "lemon" => "young; " + (b.OakTannin > 40 ? "oak contact deepens the colour" : "normal for the style"),
                "gold" => b.NobleRotShare > 0.1 ? "noble rot concentrates and deepens colour" : b.OakTannin > 40 ? "barrel ageing and oxygen deepen the colour" : "oxygen exposure and age",
                "brown" => "advanced oxidation: the wine has browned — " + (b.Laccase > 0.05 ? "laccase from grey-rotten grapes" : "too much oxygen"),
                _ => "oxidation (browning) — " + (b.Laccase > 0.05 ? "laccase from grey-rotten grapes" : "too much oxygen"),
            };
        }
        else
        {
            double colour = b.Anthocyanin + b.PolymericPigment * 1.4;
            s.ColourIntensity = colour < 150 ? "pale" : colour < 350 ? "medium" : "deep";
            s.Colour = b.Acetaldehyde > 100 ? "brown" : ageYears > 10 || b.Acetaldehyde > 70 ? "tawny" : ph > 3.75 || ageYears > 4 ? "garnet" : ageYears < 1.5 && ph < 3.5 && colour > 250 ? "purple" : "ruby";
            s.AppearanceBecause = s.ColourIntensity switch
            {
                "pale" => v == "Pinot Noir" ? "Pinot Noir has few, unstable anthocyanins (no acylated forms)" : "little colour extracted — short maceration, rot or unripe skins",
                "deep" => "thick skins and good extraction" + (b.PolymericPigment > 60 ? "; stable polymeric pigments formed with tannin" : ""),
                _ => "moderate colour extraction",
            } + (s.Colour switch
            {
                "garnet" => "; higher pH shifts colour towards garnet",
                "tawny" => "; age and oxygen have turned the colour tawny",
                "brown" => "; oxidation has browned the wine",
                _ => "",
            });
        }
        if (b.Choices["Pressing"] == 0 && !red && b.Opt("Settling").StartsWith("None")) s.Clarity = "clear (slight haze before fining)";

        // ---------------- aromas
        var fam = new List<(string cat, string family, string terms, double p, string because)>();
        double ripeness = M.Clamp((harvestOe - (red ? 85 : 75)) / 25.0, -1, 1.2);
        double concentration = M.Clamp(1.2 - (yieldT - 6) / 10.0, 0.5, 1.4) * (1 + b.NobleRotShare);
        double fruitP = (1.2 + 0.4 * ripeness) * concentration;
        string fruitTerms; string fruitBecause;
        switch (v)
        {
            case "Riesling":
                fruitTerms = ripeness < 0.1 ? "green apple, lime, lemon" : ripeness < 0.6 ? "green apple, lemon, white peach" : "peach, apricot, pineapple";
                fruitBecause = $"Riesling picked at {harvestOe:0} °Oe: {(ripeness < 0.1 ? "early, so citrus and green fruit" : ripeness < 0.6 ? "balanced ripeness" : "very ripe, so stone and tropical fruit")}; yield {yieldT:0.0} t/ha {(yieldT > 11 ? "dilutes flavour" : yieldT < 6 ? "concentrates flavour" : "")}";
                break;
            case "Chardonnay":
                fruitTerms = ripeness < 0.1 ? "green apple, lemon" : ripeness < 0.6 ? "apple, pear, lemon" : "peach, melon, pineapple";
                fruitBecause = $"Chardonnay is fairly neutral; ripeness ({harvestOe:0} °Oe) moves it from citrus to stone and tropical fruit";
                break;
            case "Pinot Noir":
                fruitTerms = ripeness < 0.1 ? "redcurrant, cranberry, sour cherry" : ripeness < 0.6 ? "red cherry, raspberry, strawberry" : "red cherry, black cherry, plum";
                fruitBecause = $"Pinot Noir at {harvestOe:0} °Oe gives {(ripeness < 0.1 ? "tart red fruit" : ripeness < 0.6 ? "fresh red fruit" : "riper, darker fruit")}";
                break;
            default:
                fruitTerms = ripeness < 0.1 ? "redcurrant, tart blackcurrant" : ripeness < 0.6 ? "blackcurrant, black cherry" : "blackberry, black plum, jammy blackcurrant";
                fruitBecause = $"Cabernet Sauvignon picked at {harvestOe:0} °Oe";
                break;
        }
        // the fruit split into the exam's families (green, citrus, stone, tropical; red, black); the first family leads
        var fruitGroups = fruitTerms.Split(", ").GroupBy(t => FruitFamily.GetValueOrDefault(t, red ? "red fruit" : "green fruit")).ToList();
        for (int fi = 0; fi < fruitGroups.Count; fi++)
            fam.Add(("Primary", fruitGroups[fi].Key, string.Join(", ", fruitGroups[fi]), fi == 0 ? fruitP : fruitP * 0.9, fruitBecause));
        bool driedCooked = b.NobleRotShare > 0.05 || b.SunburnIndex > 0.08 || (red && ripeness >= 1.0);
        s.FruitRipeness = driedCooked ? "dried or cooked" : ripeness < -0.2 ? "unripe" : ripeness < 0.6 ? "fresh" : "ripe";
        s.FruitRipenessBecause = $"picked at {harvestOe:0} °Oe" + (b.NobleRotShare > 0.05 ? "; noble rot dries the berries (dried fruit)" : b.SunburnIndex > 0.08 ? "; sunburn cooks the fruit" : red && ripeness >= 1.0 ? "; very ripe, so the black fruit reads cooked or jammy" : ripeness < -0.2 ? ", well short of full ripeness" : ripeness < 0.6 ? ", so the fruit is fresh" : ", so the fruit is ripe");
        if (v == "Pinot Noir") fam.Add(("Primary", "earthy", "forest floor, mushroom", 0.9 + 0.4 * Math.Max(0, ripeness) + 0.3 * b.WholeBunchShare, "Pinot Noir's savoury side, more pronounced from ripe fruit and whole bunches"));
        if (v == "Cabernet Sauvignon" && b.Ibmp < 15) fam.Add(("Primary", "herbal", "mint, cedar, graphite", 0.9 + 0.3 * Math.Max(0, ripeness), "Cabernet Sauvignon's herbal-savoury character without green pyrazine"));
        if (b.NobleRotShare > 0.05) fam.Add(("Primary", "noble rot", "honey, marmalade, dried apricot", 1.2 + b.NobleRotShare * 3, $"{b.NobleRotShare * 100:0} % noble rot (botrytis on ripe, intact berries in misty-then-dry weather)"));
        double floral = Perceived(b.Linalool, 25) + Perceived(b.Damascenone, 0.05) * 0.3;
        if (floral > 0.3) fam.Add(("Primary", "floral", v == "Riesling" ? "blossom, citrus flower" : red ? "violet, rose" : "blossom, honeysuckle", floral * 0.8, v == "Riesling" ? $"Riesling terpenes (linalool {b.Linalool:0} µg/L){(avgExpEarly > 0.5 ? ", raised by sun-exposed bunches" : "")}" : "β-damascenone and terpenes"));
        double thiol = Perceived(b.Thiol3mh, 60);
        if (thiol > 0) fam.Add(("Primary", "tropical (thiols)", v == "Riesling" ? "grapefruit, citrus zest" : "grapefruit, passion fruit", thiol, $"3MH {b.Thiol3mh:0} ng/L released from grape precursors by the yeast{(b.Choices["Pressing"] == 2 ? "; skin contact raised the precursors" : "")}"));
        double herb = Perceived(b.Ibmp, red ? 15 : 8) + b.WholeBunchShare * (1 - b.SeedMaturity) * 1.5;
        if (herb > 0.2) fam.Add(("Primary", "herbaceous", b.Ibmp > (red ? 15 : 8) ? "green bell pepper, leafy" : "stalky, herbal", herb, b.Ibmp > (red ? 15 : 8) ? $"methoxypyrazine (IBMP {b.Ibmp:0} ng/L, threshold {(red ? 15 : 8)}): {(p0.ExposureEarly < 0.35 ? "shaded fruit before véraison" : "cool season")} and harvest before the pyrazines broke down" : "whole bunches with unripe stems"));
        // secondary
        double ester = Perceived(b.IsoamylAcetate, red ? 250 : 30) * (ageYears > 2 ? 0.5 : 1);   // red matrix masks esters
        if (ester > 1.2) fam.Add(("Secondary", "fermentation", "banana, pear drop", (ester - 1) * 0.9, $"fruity esters (isoamyl acetate {b.IsoamylAcetate / 1000:0.0} mg/L) from a {(b.MaxTempC < 18 ? "cool" : "moderate")}, clean fermentation{(b.WholeBunchShare > 0.2 ? " and intact whole-bunch berries" : "")}"));
        double mlf = Perceived(b.Diacetyl, red ? 2.8 : 1.0);
        if (mlf > 0) fam.Add(("Secondary", "malolactic", "butter, cream", mlf, $"diacetyl from malolactic fermentation ({(b.Choices["MLF"] == 2 ? "spontaneous, which makes more" : "inoculated")})"));
        double lees = b.LeesMonths / 9.0 * (1 + 1.5 * (b.BatonnageMonths / Math.Max(0.01, b.LeesMonths)));
        if (lees > 0.6) fam.Add(("Secondary", "lees", "bread, biscuit, yeast", Math.Min(2, lees), $"{b.LeesMonths:0} months on fine lees{(b.BatonnageMonths > 0.5 ? " with bâtonnage" : "")}"));
        // the oak family's strength: the strongest oak compound leads and the others add a little (perceived strengths do not
        // simply add up; game calibration, UNVERIFIED)
        double[] oakParts = { Perceived(b.Vanillin, 60), Perceived(b.OakLactone, red ? 74 : 20), Perceived(b.Guaiacol, 10) * 0.8, Perceived(b.Eugenol, 6) * 0.6 };
        double oak = oakParts.Max() + 0.25 * (oakParts.Sum() - oakParts.Max());
        if (oak > 0.3)
        {
            var t = new List<string>();
            if (b.Vanillin > 60) t.Add("vanilla");
            // coconut is the American-oak signature (whisky lactone, extraction-and-oak.md "Oak evidence"); French oak below a very high lactone level reads as cedar and sweet spice
            if (b.OakLactone > (red ? 74 : 20)) t.Add(b.Choices["Vessel"] == 5 || b.OakLactone > (red ? 300 : 250) ? "coconut" : "cedar, sweet spice");
            if (b.Guaiacol > 10) t.Add("smoke, toast");
            if (b.Eugenol > 6) t.Add("clove");
            if (b.Furfural > 15000) t.Add("caramel");
            if (t.Count == 0) t.Add("sweet spice");
            fam.Add(("Secondary", "oak", string.Join(", ", t), oak * 0.8, $"{b.Opt("Vessel").ToLowerInvariant()}, {b.Opt("Toast").ToLowerInvariant()} toast, {b.AgeingMonthsTarget} months{(b.Choices["Vessel"] == 5 ? "; American oak is rich in oak lactone (coconut)" : "")}"));
        }
        // tertiary
        double tdn = b.TdnPotential * 0.55 * (1 + 0.6 * ageYears) * Math.Clamp(3.1 / Math.Max(2.8, ph), 0.8, 1.2);
        double tdnP = Perceived(tdn, 2.0);
        if (tdnP > 0) fam.Add(("Tertiary", "bottle age (petrol)", "petrol, kerosene", tdnP, $"TDN {tdn:0.0} µg/L (detection 2 µg/L): carotenoid precursors from {(avgExpEarly > 0.5 ? "sun-exposed bunches after early leaf removal" : "a sunny, warm season")}; grows with bottle age"));
        if (ageYears > 3 && red) fam.Add(("Tertiary", "bottle age", "dried fruit, leather, forest floor", 1 + ageYears / 8, "several years of development in bottle"));
        if (b.Acetaldehyde > 40 && b.Acetaldehyde <= 100) fam.Add(("Tertiary", "oxidative", "nutty, bruised apple", 1.1, $"acetaldehyde {b.Acetaldehyde:0} mg/L from oxygen exposure"));
        if (b.FourEp > 230 && b.FourEp <= 425) fam.Add(("Tertiary", "animal", "leather, barnyard", 1.1, $"Brettanomyces (4-EP {b.FourEp:0} µg/L): high pH, low molecular SO₂, used barrels"));

        // ---------------- faults
        double vaLimit = red ? 1.20 : 1.08;
        if (b.Acetic > vaLimit) s.Faults.Add($"Volatile acidity {b.Acetic:0.00} g/L exceeds the EU legal limit ({vaLimit} g/L): vinegar, nail varnish.");
        else if (b.Acetic > 0.75) fam.Add(("Secondary", "volatile", "nail varnish lift", 1.0, $"volatile acidity {b.Acetic:0.00} g/L"));
        if (b.H2sIndex > 1.0) s.Faults.Add("Reduction: rotten egg / drains (H₂S) — the yeast ran short of nitrogen and the wine was not aerated.");
        else if (b.H2sIndex > 0.5) fam.Add(("Secondary", "reductive", "flint", 1.0, "slight reduction (H₂S) from a nitrogen-poor fermentation"));
        if (b.FourEp > 425) s.Faults.Add($"Brettanomyces taint (4-EP {b.FourEp:0} µg/L): sticking plaster, barnyard, sweaty saddle.");
        if (b.Acetaldehyde > 100) s.Faults.Add($"Oxidised: acetaldehyde {b.Acetaldehyde:0} mg/L — bruised apple, flat, browning.");
        if (b.MustyIndex > 0.06) s.Faults.Add("Musty, mouldy notes from powdery-mildew-infected grapes.");
        else if (b.MustyIndex > 0.025) fam.Add(("Primary", "musty", "dusty, slightly mouldy", 1.0, $"{b.MustyIndex * 100:0.#} % powdery-mildew-infected berries reached the press"));
        if (b.GreyRotShare > 0.06) s.Faults.Add($"Mouldy, earthy off-flavour: {b.GreyRotShare * 100:0} % grey-rotten fruit reached the press.");
        if (wine.Closure == Closure.NaturalCork) s.Chemistry.Add("Natural cork: about 3 % of bottles will show cork taint (TCA) — a closure risk, not a fault of this wine as made.");
        if (rs > 4 && wine.Filtration != Filtration.Sterile) s.Faults.Add($"Refermentation risk: {rs:0} g/L sugar in bottle without sterile filtration.");
        if (b.SunburnIndex > 0.08) fam.Add(("Primary", "cooked", "cooked fruit, bitter phenolics", 1.0 + b.SunburnIndex * 3, $"{b.SunburnIndex * 100:0} % sunburned berries (exposed bunches in a heatwave)"));

        foreach (var f in fam.Where(f => f.p > 0.25).OrderBy(f => f.cat == "Primary" ? 0 : f.cat == "Secondary" ? 1 : 2).ThenByDescending(f => f.p))
            s.Aromas.Add(new Descriptor(f.cat, f.family, f.terms, IntensityWord(Math.Max(1, f.p)), f.because));
        // the fruit counts once in the intensity, however many fruit families it is split into
        var ps = fam.Where(f => f.p > 0.25).GroupBy(f => TastingSheet.IsFruit(f.family) ? "fruit" : f.family).Select(g => g.Max(f => f.p)).OrderByDescending(x => x).ToList();
        double intensity = ps.Count == 0 ? 0 : 0.55 * ps[0] + 0.17 * ps.Skip(1).Take(3).Sum();
        s.NoseIntensity = intensity < 0.9 ? "light" : intensity < 1.25 ? "medium(−)" : intensity < 1.6 ? "medium" : intensity < 1.95 ? "medium(+)" : "pronounced";
        s.NoseCondition = s.Faults.Count > 0 ? "unclean" : "clean";
        // simple: a very limited number of aromas (UW-2016 p. 6): nothing from oak, lees, malolactic or age (fermentation esters
        // allowed), and at most one clear family besides the fruit
        s.Simple = s.Faults.Count == 0 && s.Aromas.All(a => a.Category == "Primary" || a.Family == "fermentation")
            && s.Aromas.Where(a => a.Intensity != "light" && !TastingSheet.IsFruit(a.Family)).Select(a => a.Family).Distinct().Count() <= 1;
        foreach (var a in s.Aromas)
            if (a.Intensity != "light" && a.Family is not ("volatile" or "reductive") && !s.Flavours.Contains(a.Family)) s.Flavours.Add(a.Family);
        if (s.Flavours.Count == 0 && s.Aromas.FirstOrDefault(a => a.Family is not ("volatile" or "reductive")) is { } top) s.Flavours.Add(top.Family);
        bool tertiary = s.Aromas.Any(a => a.Category == "Tertiary");
        s.Development = ageYears > 6 ? "fully developed" : (tertiary && ageYears > 1) || ageYears > 3 ? "developing" : "youthful";

        // ---------------- palate
        double perceivedSweet = rs - (ta - 6) * 2;
        string sweet = rs < 4 ? "dry" : perceivedSweet < 12 ? "off-dry" : perceivedSweet < 30 ? "medium-dry" : perceivedSweet < 45 ? "medium-sweet" : rs < 120 ? "sweet" : "luscious";
        s.Palate.Add(new("Sweetness", sweet, rs < 4 ? "fermented to dryness" : b.Stopped ? $"fermentation stopped at {rs:0} g/L by chilling and SO₂" : $"{rs:0} g/L of sugar left{(b.MaxTempC > 32 ? " after the fermentation overheated and stuck" : "")}"));
        // Perceived acidity from TA and pH. Reds are judged on a lower scale (tannin adds to the impression of structure).
        // Anchors (UNVERIFIED calibration): Mosel Riesling TA 8/pH 3.0 → high; Burgundy Pinot TA 5.8/pH 3.5 → medium(+); Napa Cabernet TA 6/pH 3.75 → medium.
        double acidScore = ta + (3.4 - ph) * 2 + (red ? 0.8 : 0);
        string acid = acidScore < 4.5 ? Five[0] : acidScore < 5.5 ? Five[1] : acidScore < 6.5 ? Five[2] : acidScore < 7.5 ? Five[3] : Five[4];
        s.Palate.Add(new("Acidity", acid, $"TA {ta:0.0} g/L, pH {ph:0.00}: {(b.Malic < 0.3 && b.Lactic > 0.5 ? "softened by malolactic fermentation; " : "")}{(p0.SeasonTemp < 15.5 ? "cool site and season kept malic acid" : p0.SeasonTemp > 18 ? "warm season burned malic acid off" : "moderate climate")}{(b.AcidAdded > 0 ? $"; acidified +{b.AcidAdded:0} g/L" : "")}"));
        if (red)
        {
            double tan = b.TotalTannin;
            string tl = tan < 300 ? Five[0] : tan < 500 ? Five[1] : tan < 750 ? Five[2] : tan < 1000 ? Five[3] : Five[4];
            double seedShare = (b.SeedTannin + b.StemTannin) / Math.Max(1, tan);
            string nature = b.SeedMaturity < 0.62 && seedShare > 0.35 || b.WholeBunchShare > 0.5 && b.SeedMaturity < 0.65 ? "green, coarse" : seedShare > 0.5 ? "firm, grippy" : b.PolymericPigment > 60 ? "ripe, fine-grained" : "soft";
            s.Palate.Add(new("Tannin", $"{tl}, {nature}", $"{tan:0} mg/L: skins {b.SkinTannin:0}, seeds {b.SeedTannin:0}{(b.StemTannin > 5 ? $", stems {b.StemTannin:0}" : "")}{(b.OakTannin > 5 ? $", oak {b.OakTannin:0}" : "")}. Seeds were {(b.SeedMaturity < 0.62 ? "still green" : "brown and ripe")} at harvest; {b.Opt("Cap management").ToLowerInvariant()}, {b.Opt("Maceration").ToLowerInvariant()}"));
        }
        s.Palate.Add(new("Alcohol", alc < 11 ? "low" : alc < 14 ? "medium" : "high", $"{alc:0.0} % vol from {harvestOe:0} °Oe must{(b.ChaptalSugarAdded > 0 ? $" plus chaptalisation (+{b.ChaptalSugarAdded / 16.83:0} % vol)" : "")}{(b.Stopped ? "; stopped with sugar left" : "")}"));
        double bodyScore = (alc - 8) / 5 + rs / 60 + (b.Glycerol - 6) / 12 + b.TotalTannin / 2000 + b.LeesMonths * 0.01 + b.NobleRotShare;
        string body = bodyScore < 0.8 ? "light" : bodyScore < 1.05 ? "medium(−)" : bodyScore < 1.35 ? "medium" : bodyScore < 1.8 ? "medium(+)" : "full";
        s.Palate.Add(new("Body", body, $"alcohol {alc:0.0} %, glycerol {b.Glycerol:0} g/L{(rs > 10 ? $", sugar {rs:0} g/L" : "")}{(b.LeesMonths > 3 ? ", lees texture" : "")}{(red ? $", tannin {b.TotalTannin:0} mg/L" : "")}"));
        // sugar carries flavour (an Auslese reads stronger than a dry wine of the same nose); tannin adds a little grip
        double flav = intensity + Math.Min(rs, 100) / 250 + (red && b.TotalTannin > 700 ? 0.1 : 0);
        s.FlavourIntensity = flav < 0.9 ? "light" : flav < 1.25 ? "medium(−)" : flav < 1.6 ? "medium" : flav < 1.95 ? "medium(+)" : "pronounced";
        s.Palate.Add(new("Flavour intensity", s.FlavourIntensity, "as on the nose; " + (concentration > 1.1 ? "low yields concentrate flavour" : concentration < 0.8 ? "high yields dilute flavour" : "average concentration")));
        // length follows flavour concentration first, then acidity and sugar; body and tannin add a little (game calibration, UNVERIFIED)
        double finishScore = 0.15 + flav * 0.8 + (bodyScore - 1) * 0.25 + (acidScore >= 8 ? 0.3 : acidScore >= 6.5 ? 0.15 : 0) + Math.Min(rs, 90) / 200
            + (red ? Math.Max(0, b.TotalTannin - 600) / 2500 : 0) + b.NobleRotShare;
        s.NoseScore = intensity; s.FlavourScore = flav; s.FinishScore = finishScore; s.BodyScore = bodyScore;
        s.Finish = finishScore < 1.3 ? "short" : finishScore < 1.6 ? "medium(−)" : finishScore < 1.9 ? "medium" : finishScore < 2.2 ? "medium(+)" : "long";
        s.Palate.Add(new("Finish", s.Finish, "length follows flavour concentration, extract and acidity"));

        // ---------------- quality (balance, length, intensity, complexity)
        bool faulty = s.Faults.Any(f => !f.StartsWith("Refermentation"));
        double perceivedAcid = acidScore - rs / 12;
        // Alcohol reads as hot when it isn't carried by sugar, extract or (for reds) tannin. Thresholds are game calibration (UNVERIFIED).
        bool hot = rs < 30 && (red ? alc >= 15.5 || (alc >= 14.5 && body is not ("full" or "medium(+)")) : alc >= 15.0 || (alc >= 14.0 && body is not ("full" or "medium(+)")));
        bool flabby = perceivedAcid < 4.0;
        bool tart = perceivedAcid > 11 && rs < 10;
        bool green = red && s.Palate.Any(pl => pl.Attribute == "Tannin" && pl.Level.Contains("green"));
        bool thin = !red && body == "light" && s.FlavourIntensity is "light" or "medium(−)" && acidScore > 8.5;
        double oakP = fam.Where(f => f.family == "oak").Select(f => f.p * 0.8).DefaultIfEmpty(0).Max();
        double fruitMax = fam.Where(f => TastingSheet.IsFruit(f.family)).Select(f => f.p).DefaultIfEmpty(0).Max();
        bool oakDominant = oakP > 0 && oakP >= fruitMax + 0.3 && fruitMax < 1.3;   // integration (UW-2016 p. 8); thresholds are game calibration (UNVERIFIED)
        bool balance = !(hot || flabby || tart || green || thin || oakDominant);
        string balWhy = balance ? "sugar, acidity, alcohol" + (red ? " and tannin" : "") + " in harmony" :
            hot ? "alcohol is hot and not carried by the body" : oakDominant ? "the oak dominates the fruit (not integrated)" : flabby ? "too little acidity for the sweetness and ripeness (flabby)" : tart ? "acidity is sharp and unripe" : green ? "green, coarse tannins" : "thin and tart";
        // length: long, or medium(+) carried by pronounced flavour (intense wines generally have a long finish, UW-2016 p. 8)
        bool length = s.Finish == "long" || (s.Finish == "medium(+)" && s.FlavourIntensity == "pronounced");
        bool inten = s.FlavourIntensity is "medium(+)" or "pronounced";
        var clear = fam.Where(f => f.p >= 1.25).ToList();   // clearly perceived families only
        int families = clear.Select(a => TastingSheet.IsFruit(a.family) ? "fruit" : a.family).Distinct().Count();
        int cats = clear.Select(a => a.cat).Distinct().Count();
        bool complexity = families >= 3 && cats >= 2;
        s.Blic.Add(("Balance", balance, balWhy));
        s.Blic.Add(("Length", length, $"finish is {s.Finish}" + (s.Finish == "medium(+)" && !length ? ", not carried by pronounced flavour" : "")));
        s.Blic.Add(("Intensity", inten, $"flavour intensity is {s.FlavourIntensity}"));
        s.Blic.Add(("Complexity", complexity, $"{families} clearly defined aroma families across {cats} categor{(cats == 1 ? "y" : "ies")}"));
        int met = s.Blic.Count(x => x.Met);
        s.Quality = faulty ? "Faulty" : met switch { 0 => "Poor", 1 => "Acceptable", 2 => "Good", 3 => "Very good", _ => "Outstanding" };
        if (!faulty)
        {
            foreach (var x in s.Blic) (x.Met ? s.QualityFor : s.QualityAgainst).Add($"{x.Criterion}: {x.Why}");
            string[] levels = { "Poor", "Acceptable", "Good", "Very good", "Outstanding" };
            var missed = s.Blic.FirstOrDefault(x => !x.Met);
            s.QualityNotHigher = met >= 4 ? "" : $"Not {levels[met + 1]}, because {missed.Criterion.ToLowerInvariant()} falls short ({missed.Why})";
        }
        s.QualityBecause = faulty ? "a fault dominates the wine" :
            $"For: {(s.QualityFor.Count == 0 ? "none" : string.Join("; ", s.QualityFor))}. Against: {(s.QualityAgainst.Count == 0 ? "none" : string.Join("; ", s.QualityAgainst))}." + (s.QualityNotHigher != "" ? " " + s.QualityNotHigher + "." : "");

        // ---------------- readiness: a drinking window from structure (UW-2016 pp. 9–10; window values are UNVERIFIED design values)
        int flavIdx = Array.IndexOf(new[] { "light", "medium(−)", "medium", "medium(+)", "pronounced" }, s.FlavourIntensity);
        // structure (acid, tannin, sugar) carries a wine through ageing only with the concentration to go with it
        double structure = M.Clamp((acidScore - 6) / 1.5, 0, 2.5) + (red ? M.Clamp(b.TotalTannin / 500, 0, 2.4) : 0) + M.Clamp(rs / 40, 0, 2);
        double conc = 0.4 + 0.15 * Math.Max(0, flavIdx);
        s.WindowYears = Math.Round(M.Clamp(1.5 + 5 * structure * conc, 2, 20), 1);
        bool firm = red ? b.TotalTannin >= 1000 : rs >= 30 && acidScore >= 8;
        s.Readiness = faulty ? "" :
            ageYears > 1.3 * s.WindowYears ? "too old" :
            ageYears > 0.7 * s.WindowYears || s.WindowYears < 6 ? "drink now, not for (further) ageing" :
            ageYears < 0.25 * s.WindowYears && firm ? "too young" : "can drink now, has potential for ageing";
        if (!faulty && ageYears > s.WindowYears) s.Development = "tired";

        // ---------------- other observations (noted, not marked)
        if (red && ageYears >= 4 && b.TotalTannin >= 700) s.Observations.Add(("deposit", "tannin and pigment bind and drop out after years in bottle"));
        else if (wine.Filtration == Filtration.Unfiltered && ageYears >= 1) s.Observations.Add(("deposit", "the wine was bottled unfiltered"));
        if (alc >= 14 || rs >= 45) s.Observations.Add(("pronounced legs", alc >= 14 ? $"{alc:0.0} % alcohol" : $"{rs:0} g/L of sugar"));
        if (s.Faults.Any(f => f.StartsWith("Refermentation"))) s.Observations.Add(("possible spritz", "sugar and live yeast in bottle can referment"));

        // ---------------- Causes (learning-core design §3.2): the same conditions as the "because" lines above
        void Tag(string cause, string line) { if (!s.CauseLinks.Contains((cause, line))) s.CauseLinks.Add((cause, line)); }
        if (red && s.ColourIntensity == "deep") Tag("extraction-colour-tannin", "appearance");
        if (red && s.Colour is "garnet" or "tawny") Tag("age-garnet-colour", "appearance");
        foreach (var a in s.Aromas)
        {
            string line = "aroma:" + a.Family;
            if (TastingSheet.IsFruit(a.Family)) Tag("ripeness-fruit-character", line);
            switch (a.Family)
            {
                case "noble rot": Tag("noble-rot", line); break;
                case "floral" when v == "Riesling": Tag("riesling-terpenes", line); break;
                case "tropical (thiols)": Tag("thiols-skin-contact", line); break;
                case "herbaceous": Tag(b.Ibmp > (red ? 15 : 8) ? "pyrazines-shade-cool" : "whole-bunch-stems", line); break;
                case "fermentation" when b.MaxTempC < 18: Tag("cool-ferment-esters", line); break;
                case "malolactic": Tag("mlf-diacetyl", line); break;
                case "lees": Tag("lees-bread-texture", line); break;
                case "oak": Tag(b.Choices["Vessel"] >= 4 ? "new-oak-vanilla-toast" : "old-oak-texture", line); break;
                case "bottle age (petrol)": Tag("sun-exposure-tdn", line); break;
                case "bottle age": Tag("bottle-age-tertiary", line); break;
                case "oxidative": Tag("oxidation", line); break;
                case "animal": Tag("brett", line); break;
                case "volatile": Tag("volatile-acidity", line); break;
                case "reductive": Tag("low-yan-h2s", line); break;
                case "cooked": Tag("sunburn-cooked", line); break;
            }
        }
        if (b.Acetic > vaLimit) Tag("volatile-acidity", "fault");
        if (b.H2sIndex > 1.0) Tag("low-yan-h2s", "fault");
        if (b.FourEp > 425) Tag("brett", "fault");
        if (b.Acetaldehyde > 100) Tag("oxidation", "fault");
        if (b.GreyRotShare > 0.06) Tag("grey-rot-taint", "fault");
        if ((b.FourEp > 230 || b.Acetic > 0.75 || b.Acetaldehyde > 40) && b.MolecularSo2 < 0.5) Tag("molecular-so2-ph", "fault");
        if (b.Stopped) Tag("stopped-ferment-sweetness", "palate:Sweetness");
        if (p0.SeasonTemp < 15.5) Tag("cool-season-acid", "palate:Acidity");
        if (p0.SeasonTemp > 18) Tag("warm-season-malic-loss", "palate:Acidity");
        if (b.Malic < 0.3 && b.Lactic > 0.5) Tag("mlf-softens-acid", "palate:Acidity");
        if (b.AcidAdded > 0) Tag("acidification", "palate:Acidity");
        if (red)
        {
            var tl = s.Palate.First(x => x.Attribute == "Tannin").Level;
            if (tl.Contains("green")) Tag("seed-ripeness-tannin", "palate:Tannin");
            if (b.TotalTannin >= 750) Tag("extraction-colour-tannin", "palate:Tannin");
            if (b.StemTannin > 5 && b.WholeBunchShare > 0.2) Tag("whole-bunch-stems", "palate:Tannin");
        }
        Tag("sugar-to-alcohol", "palate:Alcohol");
        if (b.ChaptalSugarAdded > 0) Tag("chaptalisation", "palate:Alcohol");
        if (concentration > 1.1 || concentration < 0.8) Tag("yield-concentration", "palate:Flavour intensity");
        if (parts.Any(pt => pt.prov.FrostLoss > 0.1)) Tag("spring-frost-yield", "vintage");
        return s;
    }
}
