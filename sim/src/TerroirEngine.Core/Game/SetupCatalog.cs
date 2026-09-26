using System.Text.Json.Nodes;
using TerroirEngine.Data;
using TerroirEngine.Util;
using TerroirEngine.Vineyard;
using TerroirEngine.Weather;

namespace TerroirEngine.Game;

/// <summary>Everything the pre-game screens need: Regions, Plots with Football-Manager-style 1–20 ratings, climate normals computed
/// from the Historical weather with each Block's microclimate, costs, and the Mentor's comments.</summary>
public static class SetupCatalog
{
    private static JsonObject? _cache;

    public static string Json(GameData data) => Build(data).ToJsonString();

    public static JsonObject Build(GameData data)
    {
        if (_cache != null) return _cache;
        var regions = new JsonArray();
        foreach (var r in data.Plots.Regions)
        {
            var archive = new WeatherArchive(data.DataRoot, r.WeatherFile);
            var plots = new JsonArray();
            foreach (var p in r.Plots) plots.Add(PlotEntry(p, archive));
            regions.Add(new JsonObject
            {
                ["id"] = r.Id, ["name"] = r.Name, ["country"] = r.Country, ["appellation"] = r.AppellationSystem,
                ["blurb"] = r.Id switch
                {
                    "mosel" => "Cool, northern, steep. Blue and red Devonian slate slopes above a winding river. Spring frost in the hollows, rot in wet autumns, and the world's greatest Rieslings on the steepest sites. Land is cheap; labour is not.",
                    "cote-dor" => "Continental Burgundy: limestone and marl on a gentle east-facing slope. The home of Pinot Noir and Chardonnay, graded plot by plot from regional to Grand Cru. Spring frost and hail are the enemies; prestige is expensive.",
                    _ => "Warm Mediterranean California. Dry summers, fog from the bay, gravelly alluvial fans and volcanic mountain soils. Irrigation is legal, powdery mildew is the main disease, heat spikes and wildfire smoke the wildcards.",
                },
                ["plots"] = plots,
            });
        }
        var varieties = new JsonArray();
        foreach (var v in Variety.All)
            varieties.Add(new JsonObject { ["id"] = v.Id.ToString(), ["name"] = v.Name, ["red"] = v.Red, ["note"] = v.SkinNote, ["heatNeed"] = v.Id == VarietyId.CabernetSauvignon ? 1950 : 1700 });
        var rootstocks = new JsonArray();
        foreach (var rs in Rootstock.All) rootstocks.Add(new JsonObject { ["id"] = rs.Id.ToString(), ["name"] = rs.Name, ["note"] = rs.Note });
        _cache = new JsonObject
        {
            ["startingCapital"] = data.StartingCapital, ["regions"] = regions, ["varieties"] = varieties, ["rootstocks"] = rootstocks,
            ["plantingYears"] = new JsonArray(1990, 2022),
            ["training"] = new JsonArray("Einzelpfahl", "Guyot", "Cordon"),
            ["staffLevels"] = new JsonArray("Junior", "Experienced", "Senior"),
        };
        return _cache;
    }

    private static JsonObject PlotEntry(PlotData p, WeatherArchive archive)
    {
        // climate normals 2001–2020 averaged over the Blocks (with their microclimates)
        double wink = 0, hug = 0, frostNights = 0; int n = 0;
        foreach (var b in p.Blocks)
        {
            var clim = new BlockClimate(p, b, archive.GridElevationM);
            for (int y = 2001; y <= 2020; y++)
            {
                double w = 0, h = 0;
                for (var d = new DateOnly(y, 1, 1); d.Year == y; d = d.AddDays(1))
                {
                    var x = clim.Adjust(archive.Get(d));
                    int doy = d.DayOfYear;
                    if (doy >= 91 && doy <= 304) w += Math.Max(0, x.Tmean - 10);
                    if (doy >= 91 && doy <= 273) h += Math.Max(0, ((x.Tmean - 10) + (x.Tmax - 10)) / 2) * VineyardModel.HuglinK(p.Lat);
                    if (doy >= 90 && doy <= 135 && x.Tmin <= -1) frostNights++;
                }
                wink += w; hug += h; n++;
            }
        }
        wink /= n; hug /= n; frostNights /= n;
        double taw = p.Blocks.Average(b => b.Soil.TawMm), lime = p.Blocks.Max(b => b.Soil.ActiveLimePct), pocket = p.Blocks.Average(b => b.Microclimate.FrostPocket);
        int Rate(double v, double lo, double hi) => (int)Math.Round(M.Clamp((v - lo) / (hi - lo), 0, 1) * 19 + 1);
        var ratings = new JsonObject
        {
            ["Heat"] = Rate(hug, 1250, 2350),
            ["Frost safety"] = Rate(-frostNights - pocket * 2, -6, 0),
            ["Water reserve"] = Rate(taw, 50, 220),
            ["Drainage"] = Rate(p.Blocks.Average(b => b.Soil.StonesPctVol + b.Soil.SandPct * 0.5), 20, 90),
            ["Workability"] = Rate(-p.SlopePct, -70, 0),
            ["Prestige"] = p.TierRank * 5 + 5,
            ["Value"] = Rate(-p.PricePerHaEur, -2500000, -15000),
        };
        double labour = EconomyTables.LabourHoursPerHa(p) * p.AreaHa * EconomyTables.LabourRate(p.Region.Id);
        double planting = EconomyTables.PlantingCostPerHa(p, Enum.Parse<TrainingSystem>(p.TrainingAllowed[0])) * p.AreaHa;
        var blocks = new JsonArray();
        foreach (var b in p.Blocks)
        {
            var def = GameSession.DefaultPlanting(p, b);
            blocks.Add(new JsonObject
            {
                ["id"] = b.Id, ["name"] = b.Name, ["area"] = b.AreaHa, ["texture"] = b.Soil.Texture, ["stones"] = b.Soil.StonesPctVol, ["depth"] = b.Soil.RootingDepthCm, ["taw"] = b.Soil.TawMm,
                ["ph"] = b.Soil.PH, ["lime"] = b.Soil.ActiveLimePct, ["slope"] = b.Topography.SlopePct, ["aspect"] = Snapshot.Aspect(b.Topography.AspectDeg), ["elevation"] = b.Topography.ElevationM,
                ["frostPocket"] = b.Microclimate.FrostPocket, ["fog"] = b.Microclimate.FogFrequency, ["notes"] = b.Notes,
                ["default"] = new JsonObject { ["variety"] = def.Variety.ToString(), ["rootstock"] = def.Rootstock.ToString(), ["training"] = def.Training.ToString(), ["density"] = def.DensityVinesHa },
            });
        }
        return new JsonObject
        {
            ["id"] = p.Id, ["name"] = p.Name, ["tier"] = p.Tier, ["summary"] = p.Summary, ["classification"] = p.Classification, ["ha"] = p.AreaHa, ["slope"] = p.SlopePct,
            ["aspect"] = Snapshot.Aspect(p.AspectDeg), ["elevation"] = p.ElevationM, ["price"] = Math.Round(p.Price), ["pricePerHa"] = p.PricePerHaEur, ["mechanisation"] = p.Mechanisation,
            ["training"] = new JsonArray(p.TrainingAllowed.Select(t => (JsonNode)t).ToArray()),
            ["winkler"] = Math.Round(wink), ["huglin"] = Math.Round(hug), ["springFrostNights"] = Math.Round(frostNights, 1),
            ["plantingCost"] = Math.Round(planting), ["runningCostYear"] = Math.Round(labour + EconomyTables.MaterialsPerHaYear(p.Region.Id) * p.AreaHa + EconomyTables.SprayCostPerHaYear(Tier.Medium, p.SlopePct >= 30) * p.AreaHa),
            ["labourHoursHa"] = EconomyTables.LabourHoursPerHa(p),
            ["ratings"] = ratings, ["blocks"] = blocks, ["mentor"] = new JsonArray(MentorComments(p, hug, frostNights, taw, lime, pocket).Select(s => (JsonNode)s).ToArray()),
        };
    }

    private static IEnumerable<string> MentorComments(PlotData p, double huglin, double frostNights, double taw, double lime, double pocket)
    {
        if (pocket > 0.5) yield return $"Look at the hollow: cold air drains down here on clear spring nights. Expect about {frostNights:0.#} frost nights around budburst in an average year — frost protection or a late-budding variety.";
        if (p.SlopePct >= 50) yield return $"This slope is {p.SlopePct:0} % — everything is done by hand. Budget ≈{EconomyTables.LabourHoursPerHa(p):0} hours per hectare a year. The reward is heat: south-facing slate here gains several hundred Huglin units over the flat.";
        else if (p.SlopePct < 5) yield return "Flat, deep and easy to work with a tractor. Fertile soil means vigour — big crops that ripen slowly and taste dilute unless you hold them back.";
        if (huglin < 1650) yield return $"Heat is marginal (Huglin ≈{huglin:0}). Riesling ripens in good years; Cabernet Sauvignon will not.";
        else if (huglin > 2100) yield return $"Plenty of heat (Huglin ≈{huglin:0}). The danger is sugar racing ahead of the seeds, and acidity falling away.";
        if (lime >= 12) yield return $"Up to {lime:0} % active lime in the soil: most rootstocks turn yellow (lime-induced chlorosis) here. Fercal is the rootstock for this.";
        if (taw < 90) yield return $"Shallow, stony soil — only ≈{taw:0} mm of water in reach of the roots. Good for concentration, dangerous in a drought year, especially for the young vines.";
        if (taw > 180) yield return "Deep soil that holds a lot of water: no drought worries, but vigorous canopies and a higher rot risk in wet autumns.";
        if (p.Region.Id == "cote-dor" && p.TierRank >= 2) yield return $"The classification ({p.Classification}) is what you pay for. Keep yields and buds per vine inside the AOC rules, or the wine is declassified.";
        if (p.Region.Id == "napa" && p.Id == "napa-carneros") yield return "Fog from the bay keeps it cool: this is Pinot Noir and Chardonnay country, not Cabernet.";
        if (p.Region.Id == "napa" && p.Id == "napa-mountain") yield return "Above the fog line on thin volcanic soil: small berries, firm tannin, low yields. Cabernet here is powerful but hard-won.";
        yield return p.Summary;
    }
}
