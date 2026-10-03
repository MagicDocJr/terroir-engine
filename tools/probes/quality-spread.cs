#:project ../../sim/src/TerroirEngine.Core/TerroirEngine.Core.csproj
#:property PublishAot=false
#:property JsonSerializerIsReflectionEnabledByDefault=true
// Quality spread over N random practice pours, per variety, with the four criteria and the raw scores behind the scale
// words. Usage: dotnet run tools/probes/quality-spread.cs [n=150]
using TerroirEngine.Data;
using TerroirEngine.Tasting.Practice;
var data = new GameData(Path.GetFullPath(Path.Combine(Path.GetDirectoryName((string)AppContext.GetData("EntryPointFilePath")!)!, "../../data")));
int n = args.Length > 0 ? int.Parse(args[0]) : 150;
var rows = new List<(string V, TerroirEngine.Tasting.TastingSheet S)>();
for (int seed = 1; seed <= n; seed++) { try { var p = TastingLab.Pour(data, PracticePours.Random(data, seed), seed); rows.Add((p.Context.Variety, p.Sheet)); } catch (InvalidOperationException) { } }
string Spread(IEnumerable<string> xs) => string.Join(", ", xs.GroupBy(x => x).OrderBy(g => g.Key).Select(g => $"{g.Key} {g.Count()}"));
string Q(IEnumerable<double> xs) { var a = xs.OrderBy(x => x).ToArray(); return $"p10 {a[a.Length / 10]:0.00} p50 {a[a.Length / 2]:0.00} p90 {a[a.Length * 9 / 10]:0.00}"; }
Console.WriteLine($"{rows.Count} pours · {Spread(rows.Select(r => r.S.Quality))}");
foreach (var g in rows.GroupBy(r => r.V))
{
    Console.WriteLine($"{g.Key} ({g.Count()}): {Spread(g.Select(r => r.S.Quality))}");
    Console.WriteLine($"   met: " + string.Join(" ", new[] { "Balance", "Length", "Intensity", "Complexity" }.Select((c, i) => $"{c} {g.Count(r => r.S.Blic[i].Met)}")));
    Console.WriteLine($"   nose {Q(g.Select(r => r.S.NoseScore))} | flavour {Q(g.Select(r => r.S.FlavourScore))} | finish {Q(g.Select(r => r.S.FinishScore))}");
}
