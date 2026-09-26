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
                    line = $"{d:dd MMM}  {m.Oe,5:0} {m.Brix,4:0.0} {m.TaGL,4:0.0} {m.Ph,4:0.00} {m.MalicGL,4:0.0}  {b.SeedMaturity,4:0.00} {b.Anthocyanin,4:0.00} {b.Ibmp,4:0.0} {b.YieldKgHa / 1000,5:0.0} {b.FrostShootLoss,5:0.00} {b.Disease.DownyLeaf,5:0.0}% {b.Disease.DownyBunch * 100,5:0.0}% {b.Disease.PowderyBunch * 100,4:0.0} {b.Disease.GreyRot * 100,4:0.0} {b.Disease.NobleRot * 100,4:0.0}  {b.Disease.SpraysThisSeason,3}";
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
    Console.WriteLine($"{g.Plot.Name} ({g.Region.Name}), planted {setup.PlantingYear}, vintage {g.Vintage}. Setup+establishment {sw.ElapsedMilliseconds} ms. Cash €{g.Ledger.Cash:N0}");
    double targetOe = args.Length > 3 ? double.Parse(args[3], System.Globalization.CultureInfo.InvariantCulture) : g.Region.Id switch { "mosel" => 84, "cote-dor" => Units.OeFromBrix(22.5), _ => Units.OeFromBrix(25) };
    bool verbose = args.Length > 4;
    int guard = 0, stops = 0;
    while (g.Phase != TerroirEngine.Game.GamePhase.Finished && guard++ < 3000)
    {
        int days = g.Advance(30);
        stops++;
        foreach (var m in g.Inbox.Where(m => !m.Read)) { if (verbose) Console.WriteLine($"  [{Dates.Short(m.Date)}] {m.From}: {m.Subject}"); m.Read = true; }
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
    Console.WriteLine($"Finished {g.FinishedDate} after {stops} stops, {sw.ElapsedMilliseconds} ms. Inbox {g.Inbox.Count} messages.");
    foreach (var b in g.Blocks)
    {
        var pv = g.Provenance.GetValueOrDefault(b.LotId ?? "");
        Console.WriteLine($" Block {b.Data.Id}: bb {b.Budburst:dd MMM} fl {b.Flowering:dd MMM} ver {b.Veraison:dd MMM} harvest {b.HarvestDate:dd MMM} {pv?.HarvestOe:0} °Oe TA {pv?.HarvestTa:0.0} pH {pv?.HarvestPh:0.00} yield {pv?.YieldHlHa:0} hL/ha  rot {pv?.GreyRotPct:0.0}%");
    }
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

if (cmd == "catalog") { var sw = System.Diagnostics.Stopwatch.StartNew(); var j = TerroirEngine.Game.SetupCatalog.Json(data); Console.WriteLine($"catalog {j.Length / 1024} KB in {sw.ElapsedMilliseconds} ms"); Console.WriteLine(j[..Math.Min(1500, j.Length)]); }

static VarietyId DefaultVariety(PlotData p) => p.Region.Id switch { "mosel" => VarietyId.Riesling, "cote-dor" => VarietyId.PinotNoir, _ => VarietyId.CabernetSauvignon };
