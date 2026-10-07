using System.Text.Json;
using System.Text.Json.Nodes;
using TerroirEngine.Data;
using TerroirEngine.Tasting;
using TerroirEngine.Util;
using TerroirEngine.Vineyard;
using TerroirEngine.Weather;
using TerroirEngine.Winery;

namespace TerroirEngine.Game;

/// <summary>Builds the JSON snapshot the Godot UI reads (one object per screen). Front-ends never compute outcomes (ADR 0001).</summary>
public static class Snapshot
{
    private static readonly JsonSerializerOptions Opt = new() { WriteIndented = false };
    private static double R(double v, int d = 1) => Math.Round(v, d, MidpointRounding.AwayFromZero);

    public static string Json(GameSession g) => Build(g).ToJsonString(Opt);

    public static JsonObject Build(GameSession g)
    {
        var o = new JsonObject
        {
            ["phase"] = g.Phase.ToString(),
            ["date"] = Dates.Iso(g.Date),
            ["dateLabel"] = Dates.Long(g.Date),
            ["vintage"] = g.Vintage,
            ["firstVintage"] = g.FirstVintage,
            ["seasonLabel"] = $"Vintage {g.Vintage} · {Ordinal(g.Vintage - g.Setup.PlantingYear + 1)} leaf",
            ["season"] = SeasonState(g),
            ["quiet"] = Quiet(g),
            ["bottledVintages"] = Arr(g.BottledVintages.Select(v => (JsonNode)v)),
            ["history"] = Arr(Enumerable.Range(g.FirstVintage, Math.Max(0, g.Vintage - g.FirstVintage + 1)).Reverse().Select(v => (JsonNode)VintageReport.HistoryRow(g, v))),
            ["years"] = YearsObj(g),
            ["plantingYear"] = g.Setup.PlantingYear,
            ["estate"] = g.Setup.EstateName,
            ["cash"] = R(g.Ledger.Cash, 0),
            ["stage"] = StageLabel(g),
            ["mode"] = "Normal mode",
            ["weatherMode"] = g.Weather.IsHistorical(g.Date) ? $"Historical weather: {g.Region.Name} {g.Date.Year}" : $"Synthetic weather (resampled {g.Weather.SyntheticSourceYear(g.Date.Year)} + warming trend)",
            ["unreadAlerts"] = g.Inbox.Count(m => !m.Read && m.Priority == "high"),
            ["mentor"] = new JsonObject { ["name"] = g.MentorName, ["retired"] = g.MentorRetired },
            ["region"] = new JsonObject { ["id"] = g.Region.Id, ["name"] = g.Region.Name, ["country"] = g.Region.Country, ["units"] = g.Region.Id == "napa" ? "brix" : "oe", ["vintageShare"] = Law.VintageShareRequired(g.Region.Id) },
            ["plot"] = PlotObj(g),
            ["staff"] = new JsonObject
            {
                ["vineyard"] = new JsonObject { ["name"] = g.StaffName("vineyard", g.VineyardManager), ["level"] = g.VineyardManager.ToString(), ["salary"] = R(g.StaffCostYear("vineyard", g.VineyardManager), 0), ["post"] = R(EconomyTables.StaffPost("vineyard", g.Plot, g.WineHlEstimate) * 100, 0), ["forecastDays"] = g.ForecastSkill(g.VineyardManager).Horizon },
                ["cellar"] = new JsonObject { ["name"] = g.StaffName("cellar", g.CellarMaster), ["level"] = g.CellarMaster.ToString(), ["salary"] = R(g.StaffCostYear("cellar", g.CellarMaster), 0), ["post"] = R(EconomyTables.StaffPost("cellar", g.Plot, g.WineHlEstimate) * 100, 0) },
                ["salaries"] = Arr(new[] { "Junior", "Experienced", "Senior" }.Select(l => (JsonNode)new JsonObject { ["level"] = l, ["vineyard"] = R(g.StaffCostYear("vineyard", Enum.Parse<StaffLevel>(l)), 0), ["cellar"] = R(g.StaffCostYear("cellar", Enum.Parse<StaffLevel>(l)), 0) })),
            },
            ["blocks"] = Arr(g.Blocks.Select(b => (JsonNode)BlockObj(g, b))),
            ["weather"] = WeatherObj(g),
            ["programmes"] = ProgrammesObj(g),
            ["lots"] = Arr(g.Lots.Where(l => l.Phase != LotPhase.Blended).Select(l => (JsonNode)LotObj(g, l))),   // bottled Lots live on in their Wines
            ["cellarOptions"] = Arr(CellarOptions.All.Select(c => (JsonNode)new JsonObject { ["key"] = c.Key, ["options"] = Arr(c.Options.Select(x => (JsonNode)x)), ["why"] = c.Why, ["whiteOnly"] = c.WhiteOnly, ["redOnly"] = c.RedOnly, ["locked"] = c.LockedAfterFermentStart })),
            ["wines"] = Arr(g.Wines.Select(w => (JsonNode)WineObj(w))),
            ["finance"] = FinanceObj(g),
            ["inbox"] = Arr(g.Inbox.OrderByDescending(m => m.Id).Take(80).Select(m => (JsonNode)MsgObj(m))),
            ["reports"] = Arr(g.BottledVintages.OrderByDescending(v => v).Select(v => (JsonNode)VintageReport.Build(g, v))),
            ["tasks"] = TasksObj(g),
            ["flags"] = Arr(g.Flags.OrderBy(f => f).Select(f => (JsonNode)f)),
            ["decor"] = DecorObj(g),
            ["shop"] = ShopObj(g),
            ["establishment"] = Arr(g.EstablishmentReports.Select(x => (JsonNode)x)),
        };
        return o;
    }

    private static string SeasonState(GameSession g) =>
        g.Blocks.Any(b => b.Picking) ? "Harvest" : g.Blocks.All(b => b.Budburst == null) ? "Dormant" : g.Blocks.All(b => b.Harvested) ? "PostHarvest" : "Growing";

    /// <summary>Nothing growing, being picked or fermenting: the UI may take bigger steps.</summary>
    private static bool Quiet(GameSession g) =>
        g.Blocks.All(b => b.Budburst == null || b.Harvested) && !g.Blocks.Any(b => b.Picking)
        && !g.Lots.Any(l => l.Phase is LotPhase.Received or LotPhase.ColdSoak or LotPhase.Fermenting or LotPhase.Stuck or LotPhase.PostMaceration or LotPhase.Malolactic);

    /// <summary>Money by calendar year: costs (without interest), wine sales, overdraft interest and cash at the year's end.</summary>
    private static JsonArray YearsObj(GameSession g)
    {
        var arr = new JsonArray(); double cash = 0;
        foreach (var grp in g.Ledger.Entries.GroupBy(e => e.Date.Year).OrderBy(x => x.Key))
        {
            cash += grp.Sum(e => e.Amount);
            arr.Add(new JsonObject
            {
                ["year"] = grp.Key, ["costs"] = R(grp.Where(e => e.Amount < 0 && e.Category != "Interest").Sum(e => -e.Amount), 0),
                ["sales"] = R(grp.Where(e => e.Category == "Sales").Sum(e => e.Amount), 0), ["interest"] = R(grp.Where(e => e.Category == "Interest").Sum(e => -e.Amount), 0), ["cashEnd"] = R(cash, 0),
            });
        }
        return arr;
    }

    private static JsonObject DecorObj(GameSession g)
    {
        var o = new JsonObject();
        foreach (var kv in g.Decor.OrderBy(kv => kv.Key, StringComparer.Ordinal)) o[kv.Key] = kv.Value;
        return o;
    }

    /// <summary>The Shop: each look section with its options (owned, in use, price, affordable), the look in use, and the
    /// equipment (owned, available on this Plot).</summary>
    private static JsonObject ShopObj(GameSession g)
    {
        var cat = Shop.Catalog(g.Data);
        var inUse = g.LookInUse();
        var use = new JsonObject();
        foreach (var kv in inUse) use[kv.Key] = kv.Value;
        return new JsonObject
        {
            ["inUse"] = use,
            ["start"] = Obj(g.StartLook()),
            ["cash"] = Math.Round(g.Ledger.Cash, 0),
            ["look"] = Arr(cat.Look.Select(s => (JsonNode)new JsonObject
            {
                ["key"] = s.Key, ["label"] = s.Label,
                ["options"] = Arr(s.Options.Select(o => (JsonNode)new JsonObject
                {
                    ["value"] = o.Value, ["label"] = o.Label, ["blurb"] = o.Blurb, ["price"] = o.Price,
                    ["owned"] = g.OwnsLook(s.Key, o.Value), ["inUse"] = inUse[s.Key] == o.Value, ["gap"] = Math.Round(g.ShopGap(s.Key, o.Value), 0),
                    ["affordable"] = g.ShopGap(s.Key, o.Value) <= 0,
                })),
            })),
            ["equipment"] = Arr(cat.Equipment.Select(e => (JsonNode)new JsonObject
            {
                ["id"] = e.Id, ["label"] = e.Label, ["category"] = e.Category, ["price"] = e.Price, ["blurb"] = e.Blurb, ["what"] = e.What, ["when"] = e.When,
                ["owned"] = g.OwnsEquipment(e.Id), ["gap"] = Math.Round(g.ShopGap("equipment", e.Id), 0), ["affordable"] = g.ShopGap("equipment", e.Id) <= 0,
                ["unavailable"] = g.ShopUnavailable(e.Id),
            })),
        };
    }

    private static JsonObject Obj(Dictionary<string, string> d)
    {
        var o = new JsonObject();
        foreach (var kv in d) o[kv.Key] = kv.Value;
        return o;
    }

    private static JsonArray TasksObj(GameSession g) => Arr(g.Tasks
        .Where(t => t.Status == TaskState.Open || t.CrewActive(g.Date))
        .OrderBy(t => t.Due).ThenBy(t => t.Id)
        .Select(t =>
        {
            string plan = g.TaskPlan(t);
            return (JsonNode)new JsonObject
            {
                ["id"] = t.Id, ["kind"] = t.Kind.ToString(), ["title"] = TaskCatalog.Title(t.Kind), ["verb"] = TaskCatalog.Verb(t.Kind),
                ["block"] = t.BlockId, ["lot"] = t.LotId, ["variety"] = g.Blocks.FirstOrDefault(b => b.Data.Id == t.BlockId)?.Variety.Name,
                ["status"] = t.Status.ToString(), ["opened"] = D(t.Opened), ["due"] = D(t.Due), ["daysLeft"] = t.Due.DayNumber - g.Date.DayNumber,
                ["plan"] = plan, ["planLabel"] = TaskCatalog.Label(t.Kind, plan, g.TaskTraining(t)), ["choice"] = t.Choice, ["timing"] = t.Timing, ["decidedBy"] = t.DecidedBy,
                ["planTiming"] = t.Kind == TaskKind.LeafRemoval ? g.Blocks.FirstOrDefault(b => b.Data.Id == t.BlockId)?.LeafTiming.ToString() : null,
                ["training"] = g.TaskTraining(t)?.ToString(), ["red"] = t.Kind == TaskKind.CapManagement || (g.Blocks.FirstOrDefault(b => b.Data.Id == t.BlockId)?.Variety.Red ?? false),
                ["options"] = Arr(TaskCatalog.Options(t.Kind, g.TaskTraining(t)).Select(o =>
                {
                    var jo = new JsonObject { ["value"] = o.Value, ["label"] = o.Label, ["why"] = o.Why };
                    var blk = g.Blocks.FirstOrDefault(b => b.Data.Id == t.BlockId);
                    if (t.Kind == TaskKind.Prune && blk != null) jo["buds"] = R(VineyardModel.BudsPerVine(blk, Enum.Parse<BudLoad>(o.Value)), 0);   // buds per vine: the 3D canes carry this many
                    return (JsonNode)jo;
                })),
                ["crewActive"] = t.CrewActive(g.Date), ["crewUntil"] = t.CrewUntil == null ? null : D(t.CrewUntil.Value), ["where"] = TaskCatalog.Where(t.Kind),
            };
        }));

    private static JsonArray Arr(IEnumerable<JsonNode?> items) { var a = new JsonArray(); foreach (var i in items) a.Add(i); return a; }

    private static string StageLabel(GameSession g)
    {
        if (g.Blocks.All(x => x.Harvested)) return g.Lots.Any(l => l.Phase != LotPhase.Blended) ? "After the harvest · wine in the cellar" : "After the harvest";
        var b = g.Blocks.OrderBy(x => (int)x.Stage).First();
        var lead = g.Blocks.OrderByDescending(x => (int)x.Stage).First();
        string s = lead.Stage switch
        {
            Stage.Dormant => "Dormancy · winter pruning",
            Stage.Budburst or Stage.Shoots => "Budburst · shoot growth",
            Stage.Flowering => "Flowering",
            Stage.FruitSet => "Fruit set",
            Stage.BunchClosure => "Berry growth",
            Stage.Veraison => "Véraison",
            Stage.Ripening => g.Blocks.Any(x => !x.Harvested && x.SugarGL >= g.HarvestWindowSugar(x)) ? "Ripening · harvest window" : "Ripening",
            Stage.Harvested => "Harvest",
            _ => "Leaf fall",
        };
        if (g.Blocks.Any(x => x.Picking)) s = "Harvest in progress";
        return s;
    }

    private static JsonObject PlotObj(GameSession g)
    {
        var p = g.Plot;
        return new JsonObject
        {
            ["id"] = p.Id, ["name"] = p.Name, ["region"] = g.Region.Name, ["ha"] = R(p.AreaHa, 2), ["blocks"] = p.Blocks.Count, ["classification"] = p.Classification,
            ["varieties"] = string.Join(", ", g.Blocks.Select(b => b.Variety.Name).Distinct()), ["leaf"] = $"{Ordinal(g.Vintage - g.Setup.PlantingYear + 1)} leaf (planted {g.Setup.PlantingYear})",
            ["training"] = string.Join(", ", g.Blocks.Select(b => b.Planting.Training.ToString()).Distinct()), ["summary"] = p.Summary, ["slope"] = p.SlopePct, ["aspect"] = Aspect(p.AspectDeg), ["aspectDeg"] = p.AspectDeg,
            ["elevation"] = p.ElevationM, ["lat"] = p.Lat, ["lon"] = p.Lon, ["price"] = R(p.Price, 0), ["mechanisation"] = p.Mechanisation,
        };
    }

    private static string Ordinal(int n) => n + (n == 1 ? "st" : n == 2 ? "nd" : n == 3 ? "rd" : "th");
    public static string Aspect(double deg) { string[] d = { "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW" }; return d[(int)Math.Round(((deg % 360) + 360) % 360 / 22.5) % 16]; }

    private static JsonObject BlockObj(GameSession g, BlockState b)
    {
        var must = Chemistry.MustFromBlock(b);
        var d = b.Disease;
        double health = M.Clamp(1 - d.DownyLeaf / 100 * 0.8 - d.PowderyLeaf / 100 * 0.3 - d.GreyRot - b.Chlorosis * 0.3 - b.FrostShootLoss * 0.3, 0, 1);
        var soil = b.Data.Soil;
        return new JsonObject
        {
            ["id"] = b.Data.Id, ["name"] = b.Data.Name, ["area"] = b.AreaHa, ["soil"] = $"{Cap(soil.Texture)}, {soil.StonesPctVol:0} % stones, {soil.RootingDepthCm:0} cm", ["slope"] = b.Data.Topography.SlopePct,
            ["aspect"] = Aspect(b.Data.Topography.AspectDeg), ["elevation"] = b.Data.Topography.ElevationM, ["variety"] = b.Variety.Name, ["red"] = b.Variety.Red, ["rootstock"] = b.Rootstock.Name,
            ["training"] = b.Planting.Training.ToString(), ["rows"] = b.Planting.Rows.ToString(), ["density"] = b.Planting.DensityVinesHa, ["planted"] = b.PlantingYear, ["leaf"] = b.Leaf(g.Vintage), ["taw"] = R(b.Taw, 0),
            ["stage"] = b.Harvested ? "Harvested" : b.Picking ? "Picking" : StageName(b.Stage),
            ["budburst"] = D(b.Budburst), ["flowering"] = D(b.Flowering), ["veraison"] = D(b.Veraison), ["harvestDate"] = D(b.HarvestDate),
            ["health"] = R(health, 2), ["water"] = R(b.PsiStem, 2), ["stress"] = R(b.StressIndex, 2), ["waterClass"] = b.PsiStem > -0.6 ? "none" : b.PsiStem > -0.9 ? "weak" : b.PsiStem > -1.1 ? "weak–moderate" : b.PsiStem > -1.4 ? "moderate–severe" : "severe",
            ["soilWaterPct"] = R(100 * (1 - b.Dr / Math.Max(1, b.Taw)), 0),
            ["downy"] = R(d.DownyRiskToday, 0), ["downyLeaf"] = R(d.DownyLeaf, 1), ["downyBunch"] = R(d.DownyBunch * 100, 1), ["powdery"] = R(d.PowderyIndex, 0), ["powderyBunch"] = R(d.PowderyBunch * 100, 1),
            ["botrytis"] = R(d.BotrytisRiskToday, 0), ["greyRot"] = R(d.GreyRot * 100, 1), ["nobleRot"] = R(d.NobleRot * 100, 1), ["protection"] = R(d.Protection * 100, 0), ["sprays"] = d.SpraysThisSeason,
            ["frostLoss"] = R(b.FrostShootLoss * 100, 0), ["sunburn"] = R(b.SunburnFraction * 100, 1), ["chlorosis"] = R(b.Chlorosis * 100, 0),
            ["yieldKgHa"] = R(b.YieldKgHa, 0), ["cropKg"] = R(b.CropKg, 0), ["exposure"] = R(b.Exposure, 2), ["lai"] = R(b.Lai, 2), ["berriesPerVine"] = R(b.BerriesPerVine, 0), ["berryWeight"] = R(b.BerryWeight, 2),
            ["budLoad"] = b.BudLoad.ToString(), ["thinning"] = b.CropThinning, ["budsPerVine"] = R(VineyardModel.BudsPerVine(b), 1), ["leafSide"] = b.LeafSide.ToString(), ["leafTiming"] = b.LeafTiming.ToString(),
            ["harvested"] = b.Harvested, ["picking"] = b.Picking, ["pickedPct"] = R(b.CropKg > 0 ? 100 * b.PickedKg / Math.Max(1, b.PickTargetKg) : 0, 0), ["lotId"] = b.LotId ?? "",
            ["sortingOptions"] = Arr(new[] { SortingLevel.None, SortingLevel.Table, SortingLevel.Rigorous }.Select(sl =>
            {
                var so = WineryModel.Sorting(sl);
                double lossPct = 100 * (so.soundLoss + d.GreyRot * so.rotRemoved);
                double rotLeft = 100 * d.GreyRot * (1 - so.rotRemoved) / Math.Max(0.01, 1 - so.soundLoss - d.GreyRot * so.rotRemoved);
                return (JsonNode)new JsonObject { ["level"] = sl.ToString(), ["rotRemovedPct"] = R(so.rotRemoved * 100, 0), ["cropLossPct"] = R(lossPct, 1), ["rotLeftPct"] = R(rotLeft, 1),
                    ["extraCost"] = R(b.CropKg * so.hoursPerKg * EconomyTables.LabourRate(g.Region.Id), 0), ["slower"] = so.hoursPerKg > 0 };
            })),
            ["harvestMethod"] = b.Order == null ? "" : b.Order.HandPick ? "hand" : "machine", ["sorting"] = b.Order?.Sorting.ToString() ?? "",
            ["lastSpray"] = D(d.LastSpray), ["daysSinceSpray"] = d.LastSpray == null ? null : g.Date.DayNumber - d.LastSpray.Value.DayNumber,
            ["inWindow"] = !b.Harvested && b.Veraison != null && b.SugarGL >= g.HarvestWindowSugar(b),
            ["must"] = b.Veraison == null ? null : new JsonObject { ["oe"] = R(must.Oe, 0), ["brix"] = R(must.Brix, 1), ["pa"] = R(must.PotentialAlcohol, 1), ["ta"] = R(must.TaGL, 1), ["ph"] = R(must.Ph, 2), ["malic"] = R(must.MalicGL, 1), ["yan"] = R(must.YanMgL, 0), ["seeds"] = R(b.SeedMaturity * 100, 0), ["anth"] = R(b.Anthocyanin, 2), ["ibmp"] = R(b.Ibmp, 1) },
            ["samples"] = Arr(b.Samples.Select(s => (JsonNode)new JsonObject { ["date"] = Dates.Short(s.Date), ["oe"] = s.Oe, ["brix"] = s.Brix, ["ta"] = s.TaGL, ["ph"] = s.Ph, ["malic"] = s.MalicGL, ["seeds"] = R(s.SeedMaturity * 100, 0), ["anth"] = s.Anthocyanin, ["ibmp"] = s.IbmpNgL, ["berry"] = s.BerryWeightG, ["grey"] = s.GreyRotPct, ["noble"] = s.NobleRotPct })),
            ["targets"] = Arr(g.StyleTargets(b).Select(t => (JsonNode)new JsonObject { ["style"] = t.Name, ["oe"] = R(t.Oe, 0), ["brix"] = R(Units.BrixFromOe(t.Oe), 1) })),
            ["soilProfile"] = new JsonObject { ["texture"] = soil.Texture, ["sand"] = soil.SandPct, ["silt"] = soil.SiltPct, ["clay"] = soil.ClayPct, ["stones"] = soil.StonesPctVol, ["depthCm"] = soil.RootingDepthCm, ["tawMm"] = soil.TawMm, ["ph"] = soil.PH, ["lime"] = soil.ActiveLimePct, ["om"] = soil.OrganicMatterPct, ["drainage"] = soil.Drainage },
            ["micro"] = new JsonObject { ["frostPocket"] = b.Data.Microclimate.FrostPocket, ["fog"] = b.Data.Microclimate.FogFrequency, ["wind"] = b.Data.Microclimate.WindExposure, ["radiative"] = b.Data.Microclimate.RadiativeHeat },
            ["notes"] = b.Data.Notes, ["winkler"] = R(b.Winkler, 0), ["huglin"] = R(b.Huglin, 0),
        };
    }

    public static string StageName(Stage s) => s switch
    {
        Stage.Dormant => "Dormant", Stage.Budburst => "Budburst", Stage.Shoots => "Shoot growth", Stage.Flowering => "Flowering", Stage.FruitSet => "Fruit set",
        Stage.BunchClosure => "Bunch closure", Stage.Veraison => "Véraison", Stage.Ripening => "Ripening", Stage.Harvested => "Harvested", _ => "Leaf fall",
    };

    private static string Cap(string s) => s.Length == 0 ? s : char.ToUpperInvariant(s[0]) + s[1..];
    private static string? D(DateOnly? d) => d == null ? null : Dates.Short(d.Value);

    // ------------------------------------------------------------------------------ weather with normals
    private static readonly System.Collections.Concurrent.ConcurrentDictionary<string, (double[] tmean, double[] gdd, double[] rain)> NormalsCache = new();   // shared by parallel callers (tests)
    private static (double[] tmean, double[] gdd, double[] rain) Normals(GameSession g)
    {
        string key = g.Plot.Id;
        if (NormalsCache.TryGetValue(key, out var n)) return n;
        var clim = g.Blocks[0].Climate;
        var tm = new double[53]; var cnt = new int[53]; var gdd = new double[367]; var rain = new double[13];
        int years = 0;
        for (int y = 1991; y <= 2020; y++)
        {
            if (!g.Weather.Archive.Has(new DateOnly(y, 1, 1))) continue;
            years++; double cum = 0;
            for (var d = new DateOnly(y, 1, 1); d.Year == y; d = d.AddDays(1))
            {
                var w = clim.Adjust(g.Weather.Archive.Get(d));
                int wk = Math.Min(52, (d.DayOfYear - 1) / 7);
                tm[wk] += w.Tmean; cnt[wk]++;
                if (d.DayOfYear >= 91 && d.DayOfYear <= 304) cum += Math.Max(0, w.Tmean - 10);
                gdd[d.DayOfYear] += cum;
                rain[d.Month] += w.Precip;
            }
        }
        for (int i = 0; i < 53; i++) tm[i] = cnt[i] > 0 ? tm[i] / cnt[i] : 0;
        for (int i = 0; i < 367; i++) gdd[i] /= Math.Max(1, years);
        for (int i = 0; i < 13; i++) rain[i] /= Math.Max(1, years);
        n = (tm, gdd, rain);
        NormalsCache[key] = n;
        return n;
    }

    private static JsonObject WeatherObj(GameSession g)
    {
        var n = Normals(g);
        var clim = g.Blocks[0].Climate;
        int year = g.Date.Year;
        var weekly = new JsonArray();
        double cum = 0;
        var monthRain = new double[13];
        var end = g.Date.AddDays(-1);
        double wkSum = 0; int wkCnt = 0;
        for (var d = new DateOnly(year, 1, 1); d <= end; d = d.AddDays(1))
        {
            var w = clim.Adjust(g.Weather.Get(d));
            if (d.DayOfYear >= 91 && d.DayOfYear <= 304) cum += Math.Max(0, w.Tmean - 10);
            monthRain[d.Month] += w.Precip;
            wkSum += w.Tmean; wkCnt++;
            if (d.DayOfWeek == DayOfWeek.Sunday || d == end)
            {
                int wk = Math.Min(52, (d.DayOfYear - 1) / 7);
                if (d.Month >= 3 && d.Month <= 11)
                    weekly.Add(new JsonObject { ["date"] = Dates.Short(d), ["tmean"] = R(wkSum / wkCnt), ["tmeanNormal"] = R(n.tmean[wk]), ["gdd"] = R(cum, 0), ["gddNormal"] = R(n.gdd[d.DayOfYear], 0) });
                wkSum = 0; wkCnt = 0;
            }
        }
        var months = new JsonArray();
        string[] mn = { "", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
        for (int m = 1; m <= 12; m++) months.Add(new JsonObject { ["month"] = mn[m], ["rain"] = R(monthRain[m], 0), ["normal"] = R(n.rain[m], 0), ["past"] = new DateOnly(year, m, 1) <= end });
        var bA = g.Blocks[0];
        var fc = g.CurrentForecast();
        var today = clim.Adjust(g.Today);
        return new JsonObject
        {
            ["station"] = $"{g.Region.Name} · Block A microclimate",
            ["historical"] = g.Weather.IsHistorical(g.Date),
            ["today"] = new JsonObject { ["date"] = Dates.Short(today.Date), ["tmin"] = R(today.Tmin), ["tmax"] = R(today.Tmax), ["rain"] = R(today.Precip), ["rh"] = R(today.RhMean, 0), ["wind"] = R(today.WindKmh, 0), ["clear"] = R(clim.ClearFraction(today), 2), ["icon"] = today.Precip >= 1 ? "rain" : today.RhMean > 90 ? "fog" : today.SwRad > 14 ? "sun" : "cloud" },
            ["weekly"] = weekly,
            ["months"] = months,
            ["risk"] = Arr(g.RiskSeries.TakeLast(120).Select(r => (JsonNode)new JsonObject { ["date"] = Dates.Short(r.Date), ["downy"] = R(r.Downy, 0), ["powdery"] = R(r.Powdery, 0), ["botrytis"] = R(r.Botrytis, 0) })),
            ["forecast"] = Arr(fc.Select(f => (JsonNode)new JsonObject { ["day"] = f.Date.ToString("ddd d", System.Globalization.CultureInfo.InvariantCulture), ["icon"] = f.Icon, ["tmin"] = R(f.Tmin, 0), ["tmax"] = R(f.Tmax, 0), ["rain"] = f.RainMm, ["prob"] = R(f.RainProb * 100, 0), ["rh"] = R(f.RhMean, 0) })),
            ["indices"] = new JsonObject { ["winkler"] = R(bA.Winkler, 0), ["winklerNormal"] = R(n.gdd[Math.Min(366, end.DayOfYear)], 0), ["huglin"] = R(bA.Huglin, 0), ["seasonTmean"] = R(VineyardModel.SeasonMeanTemp(bA)), ["rainSeason"] = R(bA.RainSeason, 0) },
            ["phenology"] = Arr(new (string, DateOnly?)[] { ("Budburst", bA.Budburst), ("Flowering", bA.Flowering), ("Fruit set", bA.FruitSet), ("Véraison", bA.Veraison), ("Harvest", bA.HarvestDate) }
                .Select(x => (JsonNode)new JsonObject { ["stage"] = x.Item1, ["date"] = D(x.Item2) })),
        };
    }

    private static JsonArray ProgrammesObj(GameSession g)
    {
        var c = g.Ctx;
        double ha = g.Blocks.Sum(b => b.AreaHa);
        bool steep = g.Plot.SlopePct >= 30;
        JsonObject P(string id, string name, Tier cur, bool available, string notes, (string effect, double cost)[] tiers) => new()
        {
            ["id"] = id, ["name"] = name, ["current"] = cur.ToString(), ["available"] = available, ["notes"] = notes,
            ["changed"] = g.Commands.LastOrDefault(c => c.Type == "programme" && c.A == id) is { } lc ? Dates.Short(DateOnly.FromDayNumber(lc.Day)) : null,
            ["tiers"] = new JsonObject { ["Low"] = T(tiers[0]), ["Medium"] = T(tiers[1]), ["High"] = T(tiers[2]) },
        };
        JsonObject T((string effect, double cost) t) => new() { ["effect"] = t.effect, ["cost"] = R(t.cost, 0) };
        double lab = EconomyTables.LabourHoursPerHa(g.Plot) * ha * EconomyTables.LabourRate(g.Region.Id);
        return new JsonArray
        {
            P("spray", "Spray programme", c.Spray, true, "One programme covers downy mildew, powdery mildew and botrytis. The Vineyard manager times the passes.", new[]
            {
                ($"every ~17 days, skipped in rain · {EconomyTables.TypicalPasses(g.Region.Id, Tier.Low)} passes · infections get through in wet years", EconomyTables.SprayCostPerHaYear(Tier.Low, steep) * ha),
                ($"every ~12 days, rescheduled around rain · {EconomyTables.TypicalPasses(g.Region.Id, Tier.Medium)} passes · typical practice", EconomyTables.SprayCostPerHaYear(Tier.Medium, steep) * ha),
                ($"every ~8 days plus after rain · {EconomyTables.TypicalPasses(g.Region.Id, Tier.High)} passes · best protection", EconomyTables.SprayCostPerHaYear(Tier.High, steep) * ha),
            }),
            P("canopy", "Canopy management", c.Canopy, true, "Shoot thinning, positioning, hedging and fruit-zone leaf removal. Leaf-removal side and timing are set per Block.", new[]
            {
                ("dense canopy · fruit exposure ≈ 0.2 · more rot, less colour and TDN, more pyrazine", lab * 0.35 * 0.6),
                ("balanced · exposure ≈ 0.45", lab * 0.35),
                ("open fruit zone · exposure ≈ 0.65 · driest bunches, highest sunburn risk", lab * 0.35 * 1.6),
            }),
            P("floor", "Floor management", c.Floor, true, "What grows between the rows competes for water.", new[]
            {
                ("spontaneous cover crop · competes for water, less vigour", EconomyTables.MaterialsPerHaYear(g.Region.Id) * ha * 0.8),
                ("mown cover crop", EconomyTables.MaterialsPerHaYear(g.Region.Id) * ha),
                ("cultivated soil · no competition, more vigour", EconomyTables.MaterialsPerHaYear(g.Region.Id) * ha * 1.2),
            }),
            P("irrigation", "Irrigation", c.Irrigation, c.IrrigationLegal, c.IrrigationLegal ? "Drip irrigation is legal and usual in Napa." : "Not allowed or not used here (rain-fed).", new[]
            {
                ("none · vines rely on the soil reserve", 0.0), ("regulated deficit · water only under moderate stress", 300 * ha), ("full · keep vines unstressed (bigger berries, dilution)", 500 * ha),
            }),
            P("frost", "Frost protection", c.Frost, true, "Candles or wind machines on clear, calm nights after budburst. Only works under an inversion.", new[]
            {
                ("none", 0.0), ("≈ +1 °C at vine level · €600/ha per frost night", 600 * ha), ("≈ +2 °C · €900/ha per frost night", 900 * ha),
            }),
            P("labour", "Labour", c.Labour, true, "Crew size. Short-handed crews do canopy work late and harvest slowly (grapes hang longer).", new[]
            {
                ("85 % of the hours needed · 8 pickers", lab * 0.85), ("100 % · 12 pickers", lab), ("120 % · 20 pickers, fast harvest", lab * 1.2),
            }),
        };
    }

    private static JsonObject LotObj(GameSession g, Lot l)
    {
        var choices = new JsonObject();
        foreach (var c in CellarOptions.For(l.Red)) choices[c.Key] = l.Choices[c.Key];
        bool started = l.Phase is not (LotPhase.Received or LotPhase.ColdSoak);
        double sp = l.Red ? l.Choices["Red temperature"] switch { 1 => 22, 2 => 30, 3 => -1, _ => 26 } : l.Choices["Temperature"] switch { 1 => 14, 2 => 18, 3 => -1, _ => 16 };
        return new JsonObject
        {
            ["id"] = l.Id, ["vintage"] = l.Vintage, ["block"] = l.BlockId, ["variety"] = l.VarietyName, ["red"] = l.Red, ["volume"] = R(l.VolumeL, 0), ["kg"] = R(l.GrapeKg, 0), ["picked"] = Dates.Short(l.Harvested),
            ["phase"] = l.Phase.ToString(), ["status"] = l.Status, ["started"] = started, ["tempC"] = R(l.TempC), ["setC"] = sp < 0 ? null : sp,
            ["sugar"] = R(l.Rs, 1), ["oe"] = R(l.Oe, 0), ["alcohol"] = R(l.AlcoholPct, 1), ["ta"] = R(l.Ta, 1), ["ph"] = R(l.Ph, 2), ["malic"] = R(l.Malic, 1), ["yan"] = R(l.YanMgL, 0),
            ["freeSo2"] = R(l.FreeSo2, 0), ["molSo2"] = R(l.MolecularSo2, 2), ["va"] = R(l.Acetic, 2), ["tannin"] = R(l.TotalTannin, 0), ["anth"] = R(l.Anthocyanin, 0),
            ["naturalOe"] = R(l.NaturalOe, 0), ["must"] = new JsonObject { ["oe"] = R(l.NaturalOe, 0), ["ta"] = R(l.HarvestTa, 1), ["ph"] = R(l.HarvestPh, 2) },
            ["curve"] = Arr(l.Curve.Select(c => (JsonNode)new JsonObject { ["day"] = c.Day, ["oe"] = c.Sugar, ["temp"] = c.Temp })),
            ["choices"] = choices, ["log"] = Arr(l.Log.Select(x => (JsonNode)x)),
            ["ready"] = l.Phase == LotPhase.Ready, ["stuck"] = l.Phase == LotPhase.Stuck, ["restarted"] = l.Restarted,
            ["ageingMonths"] = l.AgeingMonthsTarget, ["ageingDay"] = l.Phase == LotPhase.Ageing ? l.PhaseDay : 0,
        };
    }

    public static JsonObject WineObj(Wine w)
    {
        var s = w.Sheet!;
        return new JsonObject
        {
            ["id"] = w.Id, ["vintage"] = w.Vintage, ["name"] = w.Name, ["bottled"] = D(w.Bottled), ["bottles"] = w.Bottles, ["closure"] = w.Closure.ToString(), ["filtration"] = w.Filtration.ToString(), ["fining"] = w.Fining.ToString(),
            ["components"] = Arr(w.Components.Select(c => (JsonNode)new JsonObject { ["lot"] = c.LotId, ["litres"] = R(c.Litres, 0) })),
            ["category"] = w.Legal?.Category, ["label"] = w.Legal?.Label, ["sweetnessTerm"] = w.Legal?.SweetnessTerm, ["legalNotes"] = Arr(w.Legal!.Notes.Select(n => (JsonNode)n)),
            ["price"] = w.PricePerBottle, ["revenue"] = R(w.Revenue, 0), ["bottlingCost"] = R(w.BottlingCost, 0),
            ["sheet"] = new JsonObject
            {
                ["appearance"] = new JsonObject { ["clarity"] = s.Clarity, ["intensity"] = s.ColourIntensity, ["colour"] = s.Colour, ["because"] = s.AppearanceBecause },
                ["nose"] = new JsonObject { ["condition"] = s.NoseCondition, ["intensity"] = s.NoseIntensity, ["development"] = s.Development },
                ["aromas"] = Arr(s.Aromas.Select(a => (JsonNode)new JsonObject { ["category"] = a.Category, ["family"] = a.Family, ["terms"] = a.Terms, ["intensity"] = a.Intensity, ["because"] = a.Because })),
                ["palate"] = Arr(s.Palate.Select(p => (JsonNode)new JsonObject { ["attribute"] = p.Attribute, ["level"] = p.Level, ["because"] = p.Because })),
                ["faults"] = Arr(s.Faults.Select(f => (JsonNode)f)),
                ["quality"] = s.Quality, ["qualityBecause"] = s.QualityBecause, ["readiness"] = s.Readiness,
                ["qualityFor"] = Arr(s.QualityFor.Select(x => (JsonNode)x)), ["qualityAgainst"] = Arr(s.QualityAgainst.Select(x => (JsonNode)x)), ["qualityNotHigher"] = s.QualityNotHigher,
                ["windowYears"] = s.WindowYears, ["readinessBecause"] = s.ReadinessBecause, ["fruitRipeness"] = s.FruitRipeness, ["fruitRipenessBecause"] = s.FruitRipenessBecause, ["simple"] = s.Simple,
                ["flavours"] = Arr(s.Flavours.Select(x => (JsonNode)x)),
                ["observations"] = Arr(s.Observations.Select(o => (JsonNode)new JsonObject { ["term"] = o.Term, ["because"] = o.Because })),
                ["blic"] = Arr(s.Blic.Select(b => (JsonNode)new JsonObject { ["criterion"] = b.Criterion, ["met"] = b.Met, ["why"] = b.Why })),
                ["chemistry"] = Arr(s.Chemistry.Select(c => (JsonNode)c)),
            },
        };
    }

    private static JsonObject FinanceObj(GameSession g)
    {
        var all = g.Ledger.ByCategory(DateOnly.MinValue, DateOnly.MaxValue);
        var vintage = g.Ledger.ByCategory(new DateOnly(g.Vintage, 1, 1), DateOnly.MaxValue);
        double revenue = g.Wines.Sum(w => w.Revenue);
        double projected = g.Wines.Count > 0 ? revenue : EstimateRevenue(g);
        return new JsonObject
        {
            ["cash"] = R(g.Ledger.Cash, 0),
            ["byCategory"] = Obj(all), ["vintageByCategory"] = Obj(vintage),
            // routine daily postings are summed per month so the ledger stays readable
            ["entries"] = Arr(g.Ledger.Entries.GroupBy(e => (e.Date.Year, e.Date.Month, e.Category, e.Note))
                .Select(grp => (date: grp.Max(e => e.Date), grp.Key.Category, note: grp.Count() > 1 ? $"{grp.Key.Note} ({grp.Count()} days, {Dates.MonthName(grp.Key.Month)})" : grp.Key.Note, amount: grp.Sum(e => e.Amount)))
                .OrderByDescending(e => e.date).Take(60)
                .Select(e => (JsonNode)new JsonObject { ["date"] = Dates.Short(e.date), ["category"] = e.Category, ["amount"] = R(e.amount, 0), ["note"] = e.note })),
            ["cashSeries"] = Arr(g.CashSeries.Select(c => (JsonNode)new JsonObject { ["date"] = Dates.Short(c.Date), ["cash"] = R(c.Cash, 0) })),
            ["revenue"] = R(revenue, 0), ["projectedRevenue"] = R(projected, 0),
            ["landValue"] = R(g.Plot.Price, 0),
        };
        static JsonObject Obj(Dictionary<string, double> d) { var o = new JsonObject(); foreach (var kv in d) o[kv.Key] = kv.Value; return o; }
    }

    private static double EstimateRevenue(GameSession g)
    {
        double bottles = g.Blocks.Sum(b => b.CropKg) * 0.65 / 0.75;
        double price = g.Region.Id switch { "mosel" => 11, "cote-dor" => g.Plot.Id switch { "cotedor-premiercru" => 75, "cotedor-village" => 38, _ => 16 }, _ => 45 };
        return bottles * price;
    }

    private static JsonObject MsgObj(Message m) => new()
    {
        ["id"] = m.Id, ["date"] = Dates.Short(m.Date), ["from"] = m.From, ["sender"] = m.Sender, ["role"] = m.Role, ["subject"] = m.Subject, ["body"] = m.Body, ["why"] = m.Why,
        ["priority"] = m.Priority, ["kind"] = m.Kind, ["block"] = m.BlockId, ["read"] = m.Read, ["stop"] = m.Stop,
        ["actions"] = Arr(m.Actions.Select(a => (JsonNode)new JsonObject { ["label"] = a.Label, ["action"] = a.Action, ["arg"] = a.Arg })),
    };
}
