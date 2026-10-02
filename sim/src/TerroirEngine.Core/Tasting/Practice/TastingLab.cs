using TerroirEngine.Data;
using TerroirEngine.Game;
using TerroirEngine.Util;
using TerroirEngine.Winery;

namespace TerroirEngine.Tasting.Practice;

/// <summary>What to pour: a Plot, a vintage, optionally a Block or Variety, a winemaker style id, a ripeness target and the producer
/// (a Wine Fair host pours its own Wines).</summary>
public sealed record PourSpec(string PlotId, int Vintage, string? BlockId = null, string? Variety = null, string? Style = null, double? TargetOe = null,
    string? Producer = null, IReadOnlyDictionary<string, int>? Choices = null);

/// <summary>Everything the reveal and the quiz need about how a poured Wine came to be.</summary>
public sealed class PourContext
{
    public string RegionId = "", RegionName = "", PlotId = "", PlotName = "", BlockId = "", Variety = "", Producer = "", StyleId = "", StyleLabel = "";
    public bool Red;
    public int Vintage;
    public double Gdd, SeasonTemp, SummerTmax, HarvestRainMm, FrostLossPct, GreyRotPct, NobleRotPct, YieldHlHa, HarvestOe, HarvestTa, HarvestPh, AgeYears;
    public DateOnly HarvestDate, TastedOn;
    public DateOnly? Budburst;
}

public sealed class PouredWine
{
    public required Wine Wine { get; init; }
    public required TastingSheet Sheet { get; init; }
    public required PourContext Context { get; init; }
}

/// <summary>Pours a Wine for Tasting practice by running a headless scripted Estate for one real vintage
/// (tasting-practice design §3): planted three years before, harvested at the style's ripeness, the style's cellar
/// choices, bottled, then tasted "today" (2026), aged at most MaxAgeYears. Deterministic in (spec, seed).</summary>
public static class TastingLab
{
    public const double MaxAgeYears = 8;       // game simplification: the Tasting sheet's ageing model is not calibrated beyond this
    public const int TastingYear = 2026;

    private static readonly Dictionary<string, string[]> Producers = new()
    {
        ["mosel"] = new[] { "Weingut Brandt", "Weingut Meurer", "Weingut Kessler", "Weingut Lenz", "Weingut Hahn" },
        ["cote-dor"] = new[] { "Domaine Garnier", "Domaine Dumont-Rivière", "Domaine Fontaine", "Domaine Moreau-Bernard" },
        ["napa"] = new[] { "Morales Cellars", "Sullivan Family Vineyards", "Henning Estate", "Okafor Wines" },
    };

    public static PouredWine Pour(GameData data, PourSpec spec, int seed)
    {
        for (int attempt = 0; attempt < 6; attempt++)
        {
            var p = TryPour(data, spec, seed + attempt * 101);
            if (p != null) return p;
        }
        throw new InvalidOperationException($"no Wine could be made for {spec.PlotId} {spec.Vintage}");
    }

    private static VarietyId ToId(string name) => Enum.Parse<VarietyId>(name.Replace(" ", ""));

    private static PouredWine? TryPour(GameData data, PourSpec spec, int seed)
    {
        var plot = data.Plot(spec.PlotId);
        var rng = new Random(seed);
        // the Block: asked for, or one whose house Variety matches, or a seeded pick; its Variety as asked
        var blocks = plot.Blocks.ToList();
        var block = spec.BlockId != null ? blocks.First(b => b.Id == spec.BlockId)
            : spec.Variety != null && blocks.Any(b => GameSession.DefaultPlanting(plot, b).Variety == ToId(spec.Variety))
                ? blocks.Where(b => GameSession.DefaultPlanting(plot, b).Variety == ToId(spec.Variety)).ElementAt(rng.Next(blocks.Count(b => GameSession.DefaultPlanting(plot, b).Variety == ToId(spec.Variety))))
                : blocks[rng.Next(blocks.Count)];
        var planting = GameSession.DefaultPlanting(plot, block);
        if (spec.Variety != null) planting.Variety = ToId(spec.Variety);
        var setup = new GameSetup { PlotId = plot.Id, PlantingYear = spec.Vintage - 3, Seed = (ulong)seed, EstateName = "Tasting practice" };
        setup.Planting[block.Id] = planting;
        var g = new GameSession(data, setup);
        var bs = g.Blocks.First(b => b.Data.Id == block.Id);
        string variety = bs.Variety.Name;
        var style = spec.Style != null ? WinemakerStyle.Get(spec.Style) : WinemakerStyle.Pick(variety, seed);
        double baseOe = g.Region.Id switch { "mosel" => 84, "cote-dor" => Units.OeFromBrix(22.5), _ => Units.OeFromBrix(25) };
        double target = spec.TargetOe ?? style.TargetOe ?? baseOe + style.OeOffset + (rng.NextDouble() - 0.5) * 6;
        Wine? wine = null;
        bool styled = false;
        for (int guard = 0; guard < 2000 && wine == null; guard++)
        {
            // daily from véraison until the Lot has its style (the harvest date and the cellar choices must land on time)
            bool close = bs.Veraison != null && !styled;
            g.Advance(close ? 1 : 10, stopAtAlerts: false);
            if (!bs.Harvested && !bs.Picking && bs.Veraison != null && g.Vintage == spec.Vintage)
            {
                var must = Chemistry.MustFromBlock(bs);
                bool rot = bs.Disease.GreyRot > 0.08;
                if (must.Oe >= target || (rot && must.Oe >= target - 10) || bs.LeafFall != null)
                    g.Apply(new Command { Type = "harvest", A = bs.Data.Id, B = "hand", C = "Table" });
            }
            var lot = g.Lots.FirstOrDefault(l => l.BlockId == bs.Data.Id && l.Vintage == spec.Vintage);
            if (lot == null) continue;
            if (!styled && lot.Phase is LotPhase.Received or LotPhase.ColdSoak)
            {
                foreach (var kv in style.Choices.Concat(spec.Choices ?? new Dictionary<string, int>()))   // explicit choices override the style's
                    if ((kv.Key == "Sweetness" || kv.Key == "Temperature") && lot.Red || kv.Key == "Red temperature" && !lot.Red) continue;
                    else g.Apply(new Command { Type = "lot", A = lot.Id, B = kv.Key, C = kv.Value.ToString() });
                styled = true;
            }
            if (lot.Phase == LotPhase.Stuck) g.Apply(new Command { Type = "restart", A = lot.Id });
            if (lot.Phase == LotPhase.Ready)
            {
                g.Apply(new Command { Type = "wine", A = $"{variety} {spec.Vintage}", B = style.Closure.ToString(), C = "Sterile", D = "Bentonite", E = lot.Id });
                wine = g.Wines.LastOrDefault(w => w.Components.Any(c => c.LotId == lot.Id));
            }
        }
        if (wine?.Sheet == null) return null;
        var prov = g.Provenance[wine.Components[0].LotId];
        // tasted "today": aged since the harvest, at most MaxAgeYears, at least three months after bottling
        double age = Math.Clamp(TastingYear - spec.Vintage + 0.2, 0.5, MaxAgeYears);
        var tasted = prov.HarvestDate.AddDays((int)(age * 365));
        if (wine.Bottled != null && tasted < wine.Bottled.Value.AddMonths(3)) tasted = wine.Bottled.Value.AddMonths(3);
        var parts = wine.Components.Select(c => (g.Lots.First(l => l.Id == c.LotId), g.Provenance[c.LotId], c.Litres)).ToList();
        var sheet = TastingSheetGenerator.Generate(wine, parts, tasted);
        sheet.Label = wine.Legal!.Label; sheet.Category = wine.Legal.Category;
        wine.Sheet = sheet;
        var names = Producers.GetValueOrDefault(g.Region.Id, new[] { "Fair Estate" });
        var ctx = new PourContext
        {
            RegionId = g.Region.Id, RegionName = g.Region.Name, PlotId = plot.Id, PlotName = plot.Name, BlockId = bs.Data.Id, Variety = variety,
            // stable across runs (HashCode.Combine is randomised per process)
            Producer = spec.Producer ?? names[Math.Abs(spec.Vintage * 31 + bs.Data.Id.Sum(ch => ch) * 7 + seed) % names.Length],
            StyleId = style.Id, StyleLabel = style.Label, Red = bs.Variety.Red, Vintage = spec.Vintage,
            Gdd = prov.WinklerBlock, SeasonTemp = prov.SeasonTemp, FrostLossPct = prov.FrostLoss * 100,   // share of shoots killed by spring frost; Provenance stores a fraction
            GreyRotPct = prov.GreyRotPct, NobleRotPct = prov.NobleRotPct,
            YieldHlHa = prov.YieldHlHa, HarvestOe = prov.HarvestOe, HarvestTa = prov.HarvestTa, HarvestPh = prov.HarvestPh,
            HarvestDate = prov.HarvestDate, Budburst = prov.Budburst, TastedOn = tasted, AgeYears = Math.Round((tasted.DayNumber - prov.HarvestDate.DayNumber) / 365.0, 1),
        };
        double tsum = 0; int n = 0;
        for (var d = new DateOnly(spec.Vintage, 6, 1); d <= new DateOnly(spec.Vintage, 8, 31); d = d.AddDays(1)) { tsum += g.Weather.Get(d).Tmax; n++; }
        ctx.SummerTmax = Math.Round(tsum / n, 1);
        double rain = 0;
        for (var d = prov.HarvestDate.AddDays(-21); d <= prov.HarvestDate; d = d.AddDays(1)) rain += g.Weather.Get(d).Precip;
        ctx.HarvestRainMm = Math.Round(rain);
        return new PouredWine { Wine = wine, Sheet = sheet, Context = ctx };
    }
}
