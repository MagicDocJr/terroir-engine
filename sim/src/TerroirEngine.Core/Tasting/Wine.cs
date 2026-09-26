using TerroirEngine.Data;
using TerroirEngine.Util;
using TerroirEngine.Vineyard;
using TerroirEngine.Winery;

namespace TerroirEngine.Tasting;

/// <summary>Vineyard history captured at harvest, so the Tasting sheet can explain causes (spec §3.2).</summary>
public sealed class Provenance
{
    public string BlockId = "", BlockName = "", Soil = "", Variety = "", Rootstock = "", Training = "";
    public int Vintage, Leaf;
    public double ExposureEarly, ExposureLate, StressPost, YieldKgHa, YieldHlHa, WinklerBlock, SeasonTemp, BudsPerVine, DensityVinesHa;
    public string LeafSide = "", LeafTiming = "", CanopyTier = "", SprayTier = "", BudLoad = "", Sorting = "", Picking = "";
    public DateOnly HarvestDate;
    public double HarvestOe, HarvestTa, HarvestPh, SeedMaturity, FrostLoss, SunburnPct, GreyRotPct, NobleRotPct, DownyLeafPct, IbmpNgL;
}

public sealed record Component(string LotId, double Litres);

public enum Closure { Screwcap, NaturalCork, TechnicalCork }
public enum Filtration { Sterile, Coarse, Unfiltered }
public enum Fining { None, Bentonite, BentoniteGelatine }

public sealed class Wine
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public List<Component> Components { get; } = new();
    public Closure Closure { get; set; } = Closure.Screwcap;
    public Filtration Filtration { get; set; } = Filtration.Sterile;
    public Fining Fining { get; set; } = Fining.Bentonite;
    public DateOnly? Bottled { get; set; }
    public int Bottles { get; set; }
    public Lot Blend { get; set; } = new();
    public LegalResult? Legal { get; set; }
    public TastingSheet? Sheet { get; set; }
    public double PricePerBottle { get; set; }
    public double Revenue { get; set; }
    public double BottlingCost { get; set; }
}

public sealed record LegalResult(string Category, string Label, string SweetnessTerm, double BasePrice, List<string> Notes, bool Declassified);

/// <summary>Blends Lots by volume into a virtual Lot with the combined chemistry (spec §5.2 blending).</summary>
public static class Blending
{
    public static Lot Combine(IEnumerable<(Lot lot, double litres)> parts, string id)
    {
        var list = parts.Where(p => p.litres > 0).ToList();
        double total = list.Sum(p => p.litres);
        var r = new Lot { Id = id, VolumeL = total };
        if (total <= 0) return r;
        var first = list.OrderByDescending(p => p.litres).First().lot;
        r.Red = first.Red; r.VarietyName = first.VarietyName; r.Harvested = first.Harvested; r.BlockId = string.Join("+", list.Select(p => p.lot.BlockId).Distinct());
        foreach (var (lot, l) in list) { double f = l / total; Mix(r, lot, f); }
        foreach (var k in first.Choices.Keys) r.Choices[k] = first.Choices[k];
        r.Stopped = list.Any(p => p.lot.Stopped); r.MlfBlocked = list.All(p => p.lot.MlfBlocked);
        return r;
    }
    private static void Mix(Lot r, Lot s, double f)
    {
        r.Sugar += s.Sugar * f; r.Ethanol += s.Ethanol * f; r.Malic += s.Malic * f; r.Tartaric += s.Tartaric * f; r.Lactic += s.Lactic * f; r.Acetic += s.Acetic * f;
        r.Succinic += s.Succinic * f; r.Glycerol += s.Glycerol * f; r.PotassiumGL += s.PotassiumGL * f; r.FreeSo2 += s.FreeSo2 * f; r.TotalSo2 += s.TotalSo2 * f;
        r.NaturalOe += s.NaturalOe * f; r.NaturalSugar += s.NaturalSugar * f; r.ChaptalSugarAdded += s.ChaptalSugarAdded * f; r.AcidAdded += s.AcidAdded * f;
        r.Anthocyanin += s.Anthocyanin * f; r.SkinTannin += s.SkinTannin * f; r.SeedTannin += s.SeedTannin * f; r.StemTannin += s.StemTannin * f;
        r.PolymericPigment += s.PolymericPigment * f; r.OakTannin += s.OakTannin * f;
        r.IsoamylAcetate += s.IsoamylAcetate * f; r.EthylHexanoate += s.EthylHexanoate * f; r.Damascenone += s.Damascenone * f; r.Linalool += s.Linalool * f;
        r.TdnPotential += s.TdnPotential * f; r.Ibmp += s.Ibmp * f; r.Thiol3mh += s.Thiol3mh * f; r.Diacetyl += s.Diacetyl * f;
        r.OakLactone += s.OakLactone * f; r.Vanillin += s.Vanillin * f; r.Guaiacol += s.Guaiacol * f; r.Eugenol += s.Eugenol * f; r.Furfural += s.Furfural * f;
        r.H2sIndex += s.H2sIndex * f; r.Acetaldehyde += s.Acetaldehyde * f; r.FourEp += s.FourEp * f; r.OxygenDose += s.OxygenDose * f;
        r.LeesMonths += s.LeesMonths * f; r.BatonnageMonths += s.BatonnageMonths * f; r.Laccase += s.Laccase * f; r.MustyIndex += s.MustyIndex * f;
        r.SunburnIndex += s.SunburnIndex * f; r.NobleRotShare += s.NobleRotShare * f; r.GreyRotShare += s.GreyRotShare * f; r.SeedMaturity += s.SeedMaturity * f;
        r.WholeBunchShare += s.WholeBunchShare * f; r.MaxTempC = Math.Max(r.MaxTempC, s.MaxTempC); r.VineyardHa += s.VineyardHa * f;
        r.HarvestTa += s.HarvestTa * f; r.HarvestPh += s.HarvestPh * f;
    }
}

/// <summary>Legal category per Region (docs/science/law.md; simplified, extensible rulebooks, spec §4.4).</summary>
public static class Law
{
    public static string SweetnessTermEu(double rs, double ta, bool german)
    {
        // EU 2019/33 Annex III (as summarised in law.md)
        if (rs <= 4 || (rs <= 9 && ta >= rs - 2)) return german ? "trocken" : "dry";
        if (rs <= 12 || (rs <= 18 && ta >= rs - 10)) return german ? "halbtrocken" : "medium dry";
        if (rs <= 45) return german ? "lieblich" : "medium";
        return german ? "süß" : "sweet";
    }

    public static LegalResult Evaluate(Wine w, IList<(Lot lot, Provenance prov, double litres)> parts, PlotData plot, DateOnly bottling)
    {
        var b = w.Blend;
        var notes = new List<string>();
        double total = parts.Sum(p => p.litres);
        var byVariety = parts.GroupBy(p => p.prov.Variety).Select(g => (variety: g.Key, share: g.Sum(x => x.litres) / total)).OrderByDescending(x => x.share).ToList();
        string mainVar = byVariety[0].variety; double mainShare = byVariety[0].share;
        double naturalOe = b.NaturalOe, naturalAlc = b.NaturalSugar / 16.83;
        bool chaptalised = b.ChaptalSugarAdded > 0.5, acidified = b.AcidAdded > 0.05;
        double alc = b.AlcoholPct, rs = b.Rs, ta = b.Ta;
        double yieldHl = parts.Sum(p => p.prov.YieldHlHa * p.litres) / total;
        string region = plot.Region.Id;

        if (region == "mosel")
        {
            string term = SweetnessTermEu(rs, ta, true);
            bool riesling = mainVar == "Riesling" && mainShare >= 0.85;
            bool whiteOther = mainVar == "Chardonnay";
            if (chaptalised && acidified) notes.Add("Enrichment and acidification together are not allowed in the EU; treated as Deutscher Wein.");
            double spaet = whiteOther ? 85 : 80, ausl = whiteOther ? 93 : 88;
            if (yieldHl > 125) notes.Add($"Yield {yieldHl:0} hL/ha exceeds the Mosel PDO cap of 125 hL/ha.");
            bool pdoOk = yieldHl <= 125 && !(chaptalised && acidified);
            if (chaptalised) { double maxTotal = b.Red ? 12.0 : 11.5; if (alc > maxTotal + 0.3) { notes.Add($"After enrichment the alcohol ({alc:0.0} %) is above the zone A limit ({maxTotal} %)."); pdoOk = false; } }
            string cat; double price;
            if (!pdoOk) { cat = "Deutscher Wein"; price = 4.0; }
            // BA/TBA must come from noble-rotten (or at least overripe, for TBA shrivelled) berries picked berry by berry (WeinV §20).
            // Game simplification: a whole-Block pick qualifies only if enough of it is noble rot (thresholds UNVERIFIED).
            else if (!chaptalised && naturalOe >= 150 && b.NobleRotShare >= 0.6) { cat = "Trockenbeerenauslese"; price = 90; }
            else if (!chaptalised && naturalOe >= 110 && b.NobleRotShare >= 0.3) { cat = "Beerenauslese"; price = 45; }
            else if (!chaptalised && naturalOe >= ausl)
            {
                cat = "Auslese"; price = 24;
                if (naturalOe >= 110) notes.Add($"Must weight {naturalOe:0} °Oe reaches Beerenauslese, but only {b.NobleRotShare * 100:0} % of the fruit was noble-rotten: Beerenauslese needs botrytised or overripe berries selected one by one (game rule: ≥ 30 % noble rot).");
                if (term == "trocken") { price = 18; notes.Add("A dry Auslese sells for less than the classic sweet style: the market expects Auslese to be sweet (price UNVERIFIED)."); }
            }
            else if (!chaptalised && naturalOe >= spaet) { cat = "Spätlese"; price = 15; }
            else if (!chaptalised && naturalOe >= 73) { cat = "Kabinett"; price = 11; }
            else if (naturalOe >= 55) { cat = "Qualitätswein Mosel"; price = 8; }
            else if (naturalOe >= 50 && rs <= 18) { cat = "Landwein der Mosel"; price = 5.5; }
            else { cat = "Deutscher Wein"; price = 4; }
            if (chaptalised && naturalOe >= 73) notes.Add($"Must weight {naturalOe:0} °Oe would have qualified as Prädikatswein, but chaptalisation is forbidden for Prädikat wines (Weingesetz §20).");
            // Site matters as much as Prädikat: flat riverbank wine sells near bulk prices, famous steep slate at a premium (UNVERIFIED factors, economy.md §9).
            price *= plot.TierRank switch { 0 => 0.55, 1 => 0.75, 3 => 1.15, _ => 1.0 };
            bool singleVineyard = (riesling || (mainVar == "Pinot Noir" && mainShare >= 0.85)) && cat != "Deutscher Wein" && cat != "Landwein der Mosel";
            if (singleVineyard) price *= 1.2;
            else if (cat != "Deutscher Wein" && cat != "Landwein der Mosel") notes.Add("No single-vineyard name: in Bereich Bernkastel that needs ≥ 85 % Riesling or Pinot Noir.");
            if (cat == "Kabinett" && naturalOe >= spaet) notes.Add($"Declared as Kabinett although the must ({naturalOe:0} °Oe) qualified for Spätlese — allowed.");
            string label = $"{(singleVineyard ? plot.Name + " " : "")}{mainVar} {cat}{(term == "trocken" || term == "halbtrocken" ? " " + term : "")}".Trim();
            return new LegalResult(cat, label, term, price, notes, cat == "Deutscher Wein" && naturalOe >= 55);
        }
        if (region == "cote-dor")
        {
            string term = SweetnessTermEu(rs, ta, false);
            bool permitted = (mainVar == "Pinot Noir" || mainVar == "Chardonnay") && mainShare >= 0.85;
            int level = plot.Id switch { "cotedor-premiercru" => 3, "cotedor-village" => 2, "cotedor-hautes" => 1, _ => 0 };
            string[] names = { "Bourgogne", "Bourgogne Hautes-Côtes de Beaune", "Village AOC", "Premier Cru" };
            double[] prices = { 16, 15, 38, 75 };
            if (!permitted) { notes.Add($"{mainVar} is not a permitted variety for Burgundy AOCs: the wine can only be Vin de France."); return new LegalResult("Vin de France", $"Vin de France {mainVar}", term, 7, notes, true); }
            bool red = b.Red;
            int plotLevel = level;
            int[] tryLevels = plotLevel switch { 3 => new[] { 3, 2, 0 }, 2 => new[] { 2, 0 }, 1 => new[] { 1, 0 }, _ => new[] { 0 } };
            foreach (var lv in tryLevels)
            {
                var fails = new List<string>();
                double minNat = lv >= 3 ? 11.0 : lv == 2 ? 10.5 : red ? 10.0 : 10.5;
                double maxTotal = lv >= 3 ? 14.0 : lv == 2 ? 13.5 : red ? 12.8 : 13.25;
                double maxYield = lv >= 3 ? 56 : lv == 2 ? 58 : red ? 58 : 66;
                if (naturalAlc < minNat) fails.Add($"natural potential alcohol {naturalAlc:0.0} % is below the {minNat} % minimum");
                if (alc > maxTotal + 0.2 && chaptalised) fails.Add($"after chaptalisation the wine is {alc:0.0} %, above the {maxTotal} % maximum");
                if (yieldHl > maxYield) fails.Add($"yield {yieldHl:0} hL/ha is above the {maxYield} hL/ha limit");
                if (lv >= 2 && parts.Any(p => p.prov.DensityVinesHa < 9000)) fails.Add("planting density is below 9,000 vines/ha");
                if (lv >= 2 && parts.Any(p => p.prov.BudsPerVine > 8.5)) fails.Add("more than 8 buds per vine were left at pruning");
                if (red && b.Malic > 0.4) fails.Add($"malic acid {b.Malic:0.0} g/L at bottling (max 0.4 g/L: reds must complete MLF)");
                if (red && rs > 2) fails.Add($"residual sugar {rs:0.0} g/L (reds max 2 g/L)");
                if (lv >= 2 && bottling < new DateOnly(b.Harvested.Year + 1, 6, 15)) fails.Add("bottled before 15 June after the harvest");
                if (fails.Count == 0)
                {
                    if (lv < plotLevel) notes.Add($"Declassified to {names[lv]}.");
                    return new LegalResult(names[lv], $"{names[lv]} {(red ? "Rouge" : "Blanc")}", term, prices[lv], notes, lv < plotLevel);
                }
                notes.Add($"Not {names[lv]}: {string.Join("; ", fails)}.");
            }
            return new LegalResult("Vin de France", $"Vin de France {mainVar}", term, 7, notes, true);
        }
        // Napa
        {
            string term = rs <= 4 ? "dry" : rs <= 12 ? "off-dry" : rs <= 45 ? "medium" : "sweet";
            if (chaptalised) { notes.Add("Adding sugar is not allowed for California wine: this can't be labelled Napa Valley."); return new LegalResult("American wine (non-California)", $"American Red/White Wine", term, 9, notes, true); }
            string ava = plot.Id switch { "napa-carneros" => "Los Carneros", "napa-mountain" => "Mount Veeder", "napa-bench" => "Rutherford", _ => "Napa Valley" };
            double basePrice = (plot.Id, mainVar) switch
            {
                ("napa-bench", "Cabernet Sauvignon") => 70, ("napa-mountain", "Cabernet Sauvignon") => 60, ("napa-carneros", "Pinot Noir" or "Chardonnay") => 30,
                (_, "Cabernet Sauvignon") => 45, (_, "Pinot Noir" or "Chardonnay") => 32, _ => 28,
            };
            bool varietal = mainShare >= 0.75;
            if (!varietal) { basePrice *= 0.9; notes.Add($"Only {mainShare * 100:0} % {mainVar}: labelled as a proprietary blend."); }
            if (mainVar == "Riesling") { basePrice = 22; notes.Add("Riesling from Napa has little market recognition."); }
            return new LegalResult($"{ava} AVA", $"{ava} {(varietal ? mainVar : "Red Wine")}", term, basePrice, notes, false);
        }
    }

    public static double QualityMultiplier(string quality) => quality switch { "Outstanding" => 1.6, "Very good" => 1.25, "Good" => 1.0, "Acceptable" => 0.8, "Poor" => 0.55, _ => 0.3 };
}
