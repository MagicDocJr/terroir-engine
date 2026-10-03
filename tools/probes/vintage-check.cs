#:project ../../sim/src/TerroirEngine.Core/TerroirEngine.Core.csproj
#:property PublishAot=false
#:property JsonSerializerIsReflectionEnabledByDefault=true
// Does the simulation reproduce a real vintage? Pours one practice Wine per (plot, year, grape, style) and prints frost,
// budburst, harvest, must, yield, rot, degree-days, category and quality.
// Usage: dotnet run tools/probes/vintage-check.cs plot:year:grape:style [...]   e.g. cotedor-village:2016:Pinot_Noir:classic
using TerroirEngine.Data;
using TerroirEngine.Tasting.Practice;
var data = new GameData(Path.GetFullPath(Path.Combine(Path.GetDirectoryName((string)AppContext.GetData("EntryPointFilePath")!)!, "../../data")));
foreach (var a in args.Length > 0 ? args : new[] { "cotedor-village:2016:Pinot_Noir:classic", "mosel-blauschiefer:2018:Riesling:kabinett" })
{
    var f = a.Split(':');
    var p = TastingLab.Pour(data, new PourSpec(f[0], int.Parse(f[1]), Variety: f[2].Replace('_', ' '), Style: f.Length > 3 ? f[3] : null), 1); var c = p.Context;
    Console.WriteLine($"{f[0]} {f[1]} {c.Variety}: frost {c.FrostLossPct:0}% · budburst {c.Budburst:MM-dd} · harvest {c.HarvestDate:MM-dd} {c.HarvestOe:0}°Oe TA {c.HarvestTa:0.0} · {c.YieldHlHa:0} hL/ha · grey rot {c.GreyRotPct:0.0}% · GDD {c.Gdd:0} · {p.Wine.Legal!.Category} · {p.Sheet.Quality}");
}
