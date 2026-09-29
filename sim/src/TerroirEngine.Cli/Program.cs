using TerroirEngine.Data;
using TerroirEngine.Util;
using TerroirEngine.Vineyard;
using TerroirEngine.Weather;
using TerroirEngine.Winery;

// Terroir Engine CLI — calibration and scripted playthroughs.
//   dotnet run -- vineyard <plotId> <plantingYear> [variety] [rootstock]
var dataRoot = GameData.LocateDataRoot(AppContext.BaseDirectory);
var data = new GameData(dataRoot);
var cmd = args.Length > 0 ? args[0] : "vineyard";

if (cmd == "vineyard")
{
    string plotId = args.Length > 1 ? args[1] : "mosel-blauschiefer";
    int year = args.Length > 2 ? int.Parse(args[2]) : 2015;
    var plot = data.Plot(plotId);
    var variety = args.Length > 3 ? Enum.Parse<VarietyId>(args[3]) : DefaultVariety(plot);
    var archive = new WeatherArchive(dataRoot, plot.Region.WeatherFile);
    var rw = new RegionWeather(archive, 42);
    Console.WriteLine($"{plot.Name} ({plot.Region.Name}) grid {archive.GridElevationM} m, {variety}, planted {year}, played vintage {year + 3}");
    foreach (var bd in plot.Blocks)
    {
        var b = new BlockState(plot, bd, new BlockClimate(plot, bd, archive.GridElevationM))
        {
            Planted = true, PlantingYear = year,
            Planting = new PlantingChoice { Variety = variety, Rootstock = RootstockId.SO4, Training = Enum.Parse<TrainingSystem>(plot.TrainingAllowed[0]),
                DensityVinesHa = plot.Region.Id == "napa" ? 3800 : plot.Region.Id == "cote-dor" ? 10000 : plot.Steep ? 8000 : 5000 },
        };
        var ctx = new VineyardContext { IrrigationLegal = plot.Region.Id == "napa", Irrigation = plot.Region.Id == "napa" ? Tier.Medium : Tier.Low,
            DownyInoculum = plot.Region.Id == "napa" ? 0.1 : 0.7, PowderyInoculum = plot.Region.Id == "napa" ? 0.9 : 0.6 };
        for (var d = new DateOnly(year, 1, 1); d <= new DateOnly(year + 3, 11, 30); d = d.AddDays(1))
        {
            ctx.AutoManage = d.Year < year + 3;
            VineyardModel.Step(b, rw.Get(d), ctx, 42);
        }
        var s = b.Samples;
        Console.WriteLine($"\nBlock {bd.Id} {bd.Name} elev {bd.Topography.ElevationM} slope {bd.Topography.SlopePct}% aspect {bd.Topography.AspectDeg} TAW {b.Taw:0}");
        Console.WriteLine($"  budburst {b.Budburst:dd MMM} flowering {b.Flowering:dd MMM} veraison {b.Veraison:dd MMM} leaffall {b.LeafFall:dd MMM}  Winkler {b.Winkler:0} Huglin {b.Huglin:0}  set {b.SetFraction:0.00} frost {b.FrostShootLoss:0.00}");
        Console.WriteLine($"  yield {b.YieldKgHa / 1000:0.0} t/ha  berries/vine {b.BerriesPerVine:0}  LAI {b.Lai:0.0} exposure {b.Exposure:0.00}  downy leaf {b.Disease.DownyLeaf:0.0}% bunch {b.Disease.DownyBunch * 100:0.0}%  powdery bunch {b.Disease.PowderyBunch * 100:0.0}%  grey {b.Disease.GreyRot * 100:0.0}% noble {b.Disease.NobleRot * 100:0.0}%  sprays {b.Disease.SpraysThisSeason}");
        foreach (var x in s.Where((_, i) => i % 1 == 0).TakeLast(10))
            Console.WriteLine($"    {x.Date:dd MMM}: {x.Oe,5:0} °Oe {x.Brix,5:0.0} °Bx  TA {x.TaGL,4:0.0}  pH {x.Ph:0.00}  malic {x.MalicGL,4:0.0}  seeds {x.SeedMaturity:0.00}  anth {x.Anthocyanin:0.00}  IBMP {x.IbmpNgL,4:0.0}  berry {x.BerryWeightG:0.00} g  Ψ {x.PsiStem:0.00}");
    }
}


if (cmd == "calib")
{
    // calib <plotId> [variety] [tier] [years comma-separated]
    string plotId = args.Length > 1 ? args[1] : "mosel-blauschiefer";
    var plot = data.Plot(plotId);
    var variety = args.Length > 2 && args[2] != "-" ? Enum.Parse<VarietyId>(args[2]) : DefaultVariety(plot);
    var tier = args.Length > 3 ? Enum.Parse<Tier>(args[3]) : Tier.Medium;
    var years = args.Length > 4 ? args[4].Split(',').Select(int.Parse).ToArray() : new[] { 2003, 2010, 2013, 2015, 2018, 2019, 2021, 2022, 2024 };
    var archive = new WeatherArchive(dataRoot, plot.Region.WeatherFile);
    var rw = new RegionWeather(archive, 42);
    double target = plot.Region.Id switch { "mosel" => Units.SugarFromOe(85), "cote-dor" => Units.SugarFromBrix(22.5), _ => Units.SugarFromBrix(25) };
    if (Environment.GetEnvironmentVariable("TE_SUGAR") is { } ts) target = double.Parse(ts, System.Globalization.CultureInfo.InvariantCulture);   // g/L
    Console.WriteLine($"{plot.Name} ({plot.Region.Name}) {variety} spray={tier} target {Units.OeFromSugar(target):0} °Oe / {Units.BrixFromSugar(target):0.0} °Bx");
    Console.WriteLine("vint blk  budburst flower  veraison target    °Oe  °Bx   TA   pH malic  seeds anth IBMP  t/ha  frost downyL downyB powB grey noble sprays Wink Hugl");
    foreach (var vint in years)
    {
        int py = vint - 3;
        foreach (var bd in plot.Blocks.Take(args.Length > 5 ? int.Parse(args[5]) : 2))
        {
            var b = new BlockState(plot, bd, new BlockClimate(plot, bd, archive.GridElevationM))
            {
                Planted = true, PlantingYear = py,
                Planting = new PlantingChoice { Variety = variety, Rootstock = RootstockId.SO4, Training = Enum.Parse<TrainingSystem>(plot.TrainingAllowed[0]),
                    DensityVinesHa = plot.Region.Id == "napa" ? 3800 : plot.Region.Id == "cote-dor" ? 10000 : plot.Steep ? 8000 : 5000 },
            };
            var ctx = new VineyardContext { Spray = tier, IrrigationLegal = plot.Region.Id == "napa", Irrigation = plot.Region.Id == "napa" ? Tier.Medium : Tier.Low,
                DownyInoculum = plot.Region.Id == "napa" ? 0.1 : 0.7, PowderyInoculum = plot.Region.Id == "napa" ? 0.9 : 0.6 };
            DateOnly? hit = null; string line = "";
            for (var d = new DateOnly(py, 1, 1); d <= new DateOnly(vint, 11, 15); d = d.AddDays(1))
            {
                ctx.AutoManage = d.Year < vint;
                VineyardModel.Step(b, rw.Get(d), ctx, 42);
                if (d.Year == vint && hit == null && b.Veraison != null && (b.SugarGL >= target || d == new DateOnly(vint, 10, 31)))
                {
                    hit = d;
                    var m = Chemistry.MustFromBlock(b);
                    line = $"{d:dd MMM}  {m.Oe,5:0} {m.Brix,4:0.0} {m.TaGL,4:0.0} {m.Ph,4:0.00} {m.MalicGL,4:0.0}  {b.SeedMaturity,4:0.00} {b.Anthocyanin,4:0.00} {b.Ibmp,4:0.0} {b.YieldKgHa / 1000,5:0.0} {b.FrostShootLoss,5:0.00} {b.Disease.DownyLeaf,5:0.0}% {b.Disease.DownyBunch * 100,5:0.0}% {b.Disease.PowderyBunch * 100,4:0.0} {b.Disease.GreyRot * 100,4:0.0} {b.Disease.NobleRot * 100,4:0.0}  {b.Disease.SpraysThisSeason,3} stressPost {(b.StressPostDays > 0 ? b.StressPostSum / b.StressPostDays : 0):0.00} psi {b.PsiStem:0.00} taw {b.Taw:0}";
                }
            }
            Console.WriteLine($"{vint} {bd.Id}    {b.Budburst:dd MMM}   {b.Flowering:dd MMM}  {b.Veraison:dd MMM}   {line} {b.Winkler,5:0} {b.Huglin,5:0}");
        }
    }
}


if (cmd == "play")
{
    // play <plotId> <plantingYear> [targetOe] [verbose]
    var setup = new TerroirEngine.Game.GameSetup { PlotId = args.Length > 1 ? args[1] : "mosel-blauschiefer", PlantingYear = args.Length > 2 ? int.Parse(args[2]) : 2015, EstateName = "CLI Estate" };
    var sw = System.Diagnostics.Stopwatch.StartNew();
    var g = new TerroirEngine.Game.GameSession(data, setup);
    Console.WriteLine($"{g.Plot.Name} ({g.Region.Name}), planted {setup.PlantingYear}, first Vintage {g.FirstVintage}. Setup+establishment {sw.ElapsedMilliseconds} ms. Cash €{g.Ledger.Cash:N0}");
    double targetOe = args.Length > 3 ? double.Parse(args[3], System.Globalization.CultureInfo.InvariantCulture) : g.Region.Id switch { "mosel" => 84, "cote-dor" => Units.OeFromBrix(22.5), _ => Units.OeFromBrix(25) };
    bool verbose = args.Length > 4;
    int vintages = int.TryParse(Environment.GetEnvironmentVariable("TE_VINTAGES"), out var nv) ? Math.Max(1, nv) : 1;
    int lastVintage = g.FirstVintage + vintages - 1;
    int guard = 0, stops = 0;
    while (!g.IsVintageBottled(lastVintage) && guard++ < 3000 * vintages)
    {
        int days = g.Advance(30);
        stops++;
        foreach (var m in g.Inbox.Where(m => !m.Read).OrderBy(m => m.Id)) { if (verbose) Console.WriteLine($"  [{Dates.Short(m.Date)}] {m.From}: {m.Subject}" + (args[4] == "full" ? $"\n      {m.Body.Replace("\n", "\n      ")}\n      WHY: {m.Why}" : "")); m.Read = true; }
        if (g.Vintage <= lastVintage)
        foreach (var b in g.Blocks.Where(b => !b.Harvested && !b.Picking && b.Veraison != null))
        {
            var must = Chemistry.MustFromBlock(b);
            var fc = g.CurrentForecast();
            double rain = fc.Take(5).Where(f => f.RainProb >= 0.5).Sum(f => f.RainMm);
            bool rot = b.Disease.GreyRot > 0.06;
            if (must.Oe >= targetOe || (must.Oe >= targetOe - 8 && (rain > 20 || rot)) || b.LeafFall != null)
                g.Apply(new TerroirEngine.Game.Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Table" });
        }
        foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Ready).ToList())
            g.Apply(new TerroirEngine.Game.Command { Type = "wine", A = $"{lot.VarietyName} Block {lot.BlockId}", B = "Screwcap", C = "Sterile", D = "Bentonite", E = lot.Id });
        foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Stuck).ToList()) g.Apply(new TerroirEngine.Game.Command { Type = "restart", A = lot.Id });
    }
    Console.WriteLine($"{vintages} Vintage(s) bottled by {g.Date} (first on {g.FinishedDate}) after {stops} stops, {sw.ElapsedMilliseconds} ms. Inbox {g.Inbox.Count} messages.");
    var snapOut = Environment.GetEnvironmentVariable("TE_SNAPSHOT");
    if (!string.IsNullOrEmpty(snapOut)) File.WriteAllText(snapOut, TerroirEngine.Game.Snapshot.Json(g));
    foreach (var b in g.Blocks)
    {
        var pv = g.Provenance.GetValueOrDefault(b.LotId ?? "");
        Console.WriteLine($" Block {b.Data.Id}: bb {b.Budburst:dd MMM} fl {b.Flowering:dd MMM} ver {b.Veraison:dd MMM} harvest {b.HarvestDate:dd MMM} {pv?.HarvestOe:0} °Oe TA {pv?.HarvestTa:0.0} pH {pv?.HarvestPh:0.00} yield {pv?.YieldHlHa:0} hL/ha  rot {pv?.GreyRotPct:0.0}%");
    }
    foreach (var grp in g.Provenance.Values.Where(p => p.Vintage <= lastVintage).GroupBy(p => p.Vintage).OrderBy(x => x.Key))
        Console.WriteLine($" Vintage {grp.Key}: mean yield {grp.Average(p => p.YieldHlHa):0} hL/ha, {grp.Average(p => p.HarvestOe):0} °Oe, rot {grp.Average(p => p.GreyRotPct):0.0} %");
    foreach (var grp in g.Blocks.SelectMany(b => b.Seasons).Where(r => r.Leaf >= 4).GroupBy(r => r.Year).OrderBy(x => x.Key))
        Console.WriteLine($" Carry-over after {grp.Key}: crop load {grp.Average(r => r.CropLoadKgM2):0.00} kg/m², post-harvest {grp.Average(r => r.PostHarvestDays):0} d, defoliation {grp.Average(r => r.Defoliation):0.00}, reserves {grp.Average(r => r.ReservesAfter):0.00}, fruitfulness next {grp.Average(r => r.FruitfulnessNext):0.00}");
    var ys = g.Provenance.Values.Where(p => p.Vintage <= lastVintage).GroupBy(p => p.Vintage).Select(x => x.Average(p => p.YieldHlHa)).ToList();
    if (ys.Count > 1) { double mean = ys.Average(), sd = Math.Sqrt(ys.Average(v => (v - mean) * (v - mean))); Console.WriteLine($" Yield over {ys.Count} Vintages: mean {mean:0} hL/ha, CV {sd / mean * 100:0} %"); }
    foreach (var l in g.Lots) Console.WriteLine($" Lot {l.Id}: {l.AlcoholPct:0.0}% RS {l.Rs:0.0} TA {l.Ta:0.0} pH {l.Ph:0.00} malic {l.Malic:0.0} VA {l.Acetic:0.00} H2S {l.H2sIndex:0.00} maxT {l.MaxTempC:0} tannin {l.TotalTannin:0} anth {l.Anthocyanin:0} fermDays {(l.FermentEnd?.DayNumber - l.FermentStart?.DayNumber)}");
    foreach (var w in g.Wines)
    {
        var s = w.Sheet!;
        Console.WriteLine($"\n== {w.Name}: {w.Legal!.Label} | {w.Legal.Category} | {s.Quality} | €{w.PricePerBottle:0.00} × {w.Bottles} = €{w.Revenue:N0}");
        foreach (var n in w.Legal.Notes) Console.WriteLine($"   law: {n}");
        foreach (var c in s.Chemistry) Console.WriteLine($"   {c}");
        Console.WriteLine($"   Appearance: {s.Clarity}, {s.ColourIntensity} {s.Colour} ({s.AppearanceBecause})");
        Console.WriteLine($"   Nose: {s.NoseCondition}, {s.NoseIntensity}, {s.Development}");
        foreach (var a in s.Aromas) Console.WriteLine($"     {a.Category,-9} {a.Family,-20} {a.Terms,-35} ← {a.Because}");
        foreach (var pl in s.Palate) Console.WriteLine($"   {pl.Attribute,-17} {pl.Level,-22} ← {pl.Because}");
        foreach (var f in s.Faults) Console.WriteLine($"   FAULT: {f}");
        Console.WriteLine($"   Quality: {s.Quality} — {s.QualityBecause}\n   Readiness: {s.Readiness}");
    }
    Console.WriteLine("\nP&L (all years):");
    foreach (var kv in g.Ledger.ByCategory(DateOnly.MinValue, DateOnly.MaxValue).OrderBy(k => k.Value)) Console.WriteLine($"   {kv.Key,-18} €{kv.Value,12:N0}");
    Console.WriteLine($"   Cash now           €{g.Ledger.Cash,12:N0}");
    var save = g.Save(); var sw2 = System.Diagnostics.Stopwatch.StartNew();
    var g2 = TerroirEngine.Game.GameSession.Load(data, save);
    Console.WriteLine($"Save/replay: {save.Length} bytes, replay {sw2.ElapsedMilliseconds} ms, cash match {Math.Abs(g2.Ledger.Cash - g.Ledger.Cash) < 1}, wines {g2.Wines.Count}/{g.Wines.Count}");
    var json = TerroirEngine.Game.Snapshot.Json(g); Console.WriteLine($"Snapshot JSON {json.Length / 1024} KB");
}

if (cmd == "pour")
{
    // pour <plotId> <vintage> [block|-] [variety|-] [style|-] [seed]: one Tasting-practice pour, timed
    string? Arg(int i) => args.Length > i && args[i] != "-" ? args[i] : null;
    var spec = new TerroirEngine.Tasting.Practice.PourSpec(args[1], int.Parse(args[2]), Arg(3), Arg(4)?.Replace('_', ' '), Arg(5));
    var sw = System.Diagnostics.Stopwatch.StartNew();
    var p = TerroirEngine.Tasting.Practice.TastingLab.Pour(data, spec, args.Length > 6 ? int.Parse(args[6]) : 1);
    var c = p.Context;
    Console.WriteLine($"{c.Producer} · {c.Variety} {c.Vintage} ({c.PlotName} {c.BlockId}) · style {c.StyleId} · {sw.ElapsedMilliseconds} ms");
    Console.WriteLine($"  GDD {c.Gdd:0} · summer Tmax {c.SummerTmax} · budburst {c.Budburst} · frost {c.FrostLossPct:0} % · harvest {c.HarvestDate} {c.HarvestOe:0} °Oe TA {c.HarvestTa:0.0} pH {c.HarvestPh:0.00} · rain before harvest {c.HarvestRainMm} mm · yield {c.YieldHlHa:0} hL/ha · tasted {c.TastedOn} ({c.AgeYears} y)");
    Console.WriteLine($"  {p.Wine.Legal!.Label} · {p.Sheet.Quality} · {string.Join(" / ", p.Sheet.Palate.Select(x => x.Attribute + " " + x.Level))}");
}

if (cmd == "yieldcheck")
{
    // yieldcheck <plotId> <plantingYear> [vintages]: yield components per Block at harvest (hand-picked at the harvest-window sugar + 15 g/L)
    var g = new TerroirEngine.Game.GameSession(data, new TerroirEngine.Game.GameSetup { PlotId = args[1], PlantingYear = int.Parse(args[2]) });
    int last = g.FirstVintage + (args.Length > 3 ? int.Parse(args[3]) : 10) - 1;
    Console.WriteLine("vint blk variety      leaf shoots fruitf reserv setRat berries/v berryG kg/vine rot% hL/ha");
    var seen = new HashSet<string>();
    while (g.Date.Year <= last)
    {
        g.Advance(1, false);
        foreach (var b in g.Blocks)
        {
            if (!b.Harvested && !b.Picking && b.Veraison != null && (b.SugarGL >= g.HarvestWindowSugar(b) + 15 || b.LeafFall != null))
            {
                double hl = b.CropKg * (b.Variety.Red ? 0.72 : 0.62) / 100.0 / b.AreaHa;
                Console.WriteLine($"{g.Date.Year} {b.Data.Id,-3} {b.Variety.Name,-12} {b.Leaf(g.Date.Year),4} {b.Shoots,6:0.0} {b.Fruitfulness,6:0.00} {b.Reserves,6:0.00} {b.SetFraction / b.Variety.BaseSet,6:0.00} {b.BerriesPerVine,9:0} {b.BerryWeight,6:0.00} {b.CropKgPerVine,7:0.00} {b.Disease.GreyRot * 100,4:0} {hl,5:0}");
                g.Apply(new TerroirEngine.Game.Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Table" });
            }
        }
    }
}

if (cmd == "frostcheck")
{
    // frostcheck <plotId> <plantingYear> <yyyy-mm-dd> [days]: vine-level minima, stage and frost loss per Block around a date
    var g = new TerroirEngine.Game.GameSession(data, new TerroirEngine.Game.GameSetup { PlotId = args[1], PlantingYear = int.Parse(args[2]) });
    var from = DateOnly.Parse(args[3], System.Globalization.CultureInfo.InvariantCulture);
    int span = args.Length > 4 ? int.Parse(args[4]) : 6;
    while (g.Date < from.AddDays(-span)) g.Advance(1, false);
    while (g.Date <= from.AddDays(span))
    {
        var raw = g.Weather.Get(g.Date);
        g.Advance(1, false);
        var d = g.Date.AddDays(-1);
        Console.Write($"{d:yyyy-MM-dd} grid Tmin {raw.Tmin,5:0.0} wind {raw.WindKmh,4:0} rain {raw.Precip,4:0} |");
        foreach (var b in g.Blocks) { var w = b.Climate.Adjust(raw); Console.Write($" {b.Data.Id}:{w.Tmin,5:0.0} bb {(b.Budburst == null ? "--" : b.Budburst.Value.ToString("dd/MM"))} loss {b.FrostShootLoss * 100,3:0}%"); }
        Console.WriteLine();
    }
}

if (cmd == "ripecheck")
{
    // ripecheck <plotId> [variety]: per year flowering, véraison, date at 200 g/L, and the heat / water brakes after véraison
    var plot = data.Plot(args[1]);
    var variety = args.Length > 2 ? Enum.Parse<VarietyId>(args[2]) : VarietyId.PinotNoir;
    var archive = new WeatherArchive(data.DataRoot, plot.Region.WeatherFile);
    var rw = new RegionWeather(archive, 42);
    var bd = plot.Blocks[0];
    Console.WriteLine("year flower  verais  200g/L  doy  heatBrake waterBrake  daysTmax35");
    var doys = new List<int>();
    for (int vint = 1990; vint <= 2020; vint++)
    {
        var b = new BlockState(plot, bd, new BlockClimate(plot, bd, archive.GridElevationM))
        { Planted = true, PlantingYear = vint - 3, Planting = new PlantingChoice { Variety = variety, Rootstock = RootstockId.SO4, Training = TrainingSystem.Guyot, DensityVinesHa = 10000 } };
        var ctx = new VineyardContext { Spray = Tier.Medium };
        double heatLoss = 0, waterLoss = 0; int n = 0, hot = 0; DateOnly? hit = null;
        for (var d = new DateOnly(vint - 3, 1, 1); d <= new DateOnly(vint, 11, 15); d = d.AddDays(1))
        {
            ctx.AutoManage = d.Year < vint;
            var raw = rw.Get(d);
            VineyardModel.Step(b, raw, ctx, 42);
            if (d.Year == vint && b.Veraison != null && hit == null)
            {
                var w = b.Climate.Adjust(raw);
                heatLoss += M.Clamp((w.Tmax - 35) * 0.04, 0, 0.4); waterLoss += 0.6 * M.Clamp((-1.2 - b.PsiStem) / 0.4, 0, 1); n++;
                if (w.Tmax >= 35) hot++;
                if (b.SugarGL >= 200) hit = d;
            }
        }
        if (hit != null) doys.Add(hit.Value.DayOfYear);
        Console.WriteLine($"{vint} {b.Flowering:dd/MM}   {b.Veraison:dd/MM}   {hit:dd/MM}   {hit?.DayOfYear,3}   {heatLoss / Math.Max(1, n),6:0.000}   {waterLoss / Math.Max(1, n),6:0.000}   {hot,4}");
    }
    double mean = doys.Average(), sd = Math.Sqrt(doys.Average(x => (x - mean) * (x - mean)));
    Console.WriteLine($"mean DOY {mean:0.0}, SD {sd:0.0} days, earliest {doys.Min()}, latest {doys.Max()}");
}

if (cmd == "climcheck")
{
    if (Environment.GetEnvironmentVariable("TE_SW") is { } sw) BlockClimate.SiteWarmthC = double.Parse(sw, System.Globalization.CultureInfo.InvariantCulture);
    if (Environment.GetEnvironmentVariable("TE_AT") is { } at) BlockClimate.SlopeHeatCoeff = double.Parse(at, System.Globalization.CultureInfo.InvariantCulture);
    if (Environment.GetEnvironmentVariable("TE_NAPA") is { } nc) { var v = nc.Split(','); BlockClimate.NapaTmax = double.Parse(v[0], System.Globalization.CultureInfo.InvariantCulture); BlockClimate.NapaTmin = double.Parse(v[1], System.Globalization.CultureInfo.InvariantCulture); BlockClimate.NapaFog = double.Parse(v[2], System.Globalization.CultureInfo.InvariantCulture); }
    // climcheck: raw grid vs Block-adjusted Winkler/Huglin (1991–2020 means) for every Plot — the acceptance checks in weather-and-climate.md §5.1
    foreach (var r in data.Plots.Regions)
    {
        var archive = new WeatherArchive(dataRoot, r.WeatherFile);
        (double wi, double hi) Idx(Func<DailyWeather, DailyWeather> f, double lat)
        {
            double wi = 0, hi = 0; int n = 0;
            for (int y = 1991; y <= 2020; y++)
            {
                if (!archive.Has(new DateOnly(y, 1, 1))) continue;
                n++;
                for (var d = new DateOnly(y, 4, 1); d <= new DateOnly(y, 10, 31); d = d.AddDays(1))
                {
                    var x = f(archive.Get(d));
                    wi += Math.Max(0, x.Tmean - 10);
                    if (d.Month <= 9) hi += Math.Max(0, ((x.Tmean - 10) + (x.Tmax - 10)) / 2) * TerroirEngine.Vineyard.VineyardModel.HuglinK(lat);
                }
            }
            return (wi / n, hi / n);
        }
        var p0 = r.Plots[0];
        var raw = Idx(w => w, p0.Lat);
        Console.WriteLine($"{r.Name}: grid {archive.GridElevationM:0} m  raw WI {raw.wi:0}  HI {raw.hi:0}");
        foreach (var p in r.Plots)
            foreach (var bd in p.Blocks)
            {
                var clim = new BlockClimate(p, bd, archive.GridElevationM);
                var a = Idx(clim.Adjust, p.Lat);
                Console.WriteLine($"   {p.Id,-20} {bd.Id} {bd.Topography.ElevationM,4:0} m {bd.Topography.SlopePct,3:0}% {TerroirEngine.Game.Snapshot.Aspect(bd.Topography.AspectDeg),-3}  WI {a.wi,5:0}  HI {a.hi,5:0}");
            }
    }
}

if (cmd == "catalog") { var sw = System.Diagnostics.Stopwatch.StartNew(); var j = TerroirEngine.Game.SetupCatalog.Json(data); Console.WriteLine($"catalog {j.Length / 1024} KB in {sw.ElapsedMilliseconds} ms"); Console.WriteLine(args.Length > 1 && args[1] == "full" ? j : j[..Math.Min(1500, j.Length)]); }

static VarietyId DefaultVariety(PlotData p) => p.Region.Id switch { "mosel" => VarietyId.Riesling, "cote-dor" => VarietyId.PinotNoir, _ => VarietyId.CabernetSauvignon };
