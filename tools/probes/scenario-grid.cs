#:project ../../sim/src/TerroirEngine.Core/TerroirEngine.Core.csproj
#:property PublishAot=false
#:property JsonSerializerIsReflectionEnabledByDefault=true
// Play a famous-vintage scenario with a grid of picking targets and cellar choices and print the medal and each Wine of
// the scenario grape. Usage: dotnet run tools/probes/scenario-grid.cs <scenario-id> <oe,oe,...> ['{"Vessel":3}' ...]
using System.Text.Json;
using TerroirEngine.Data;
using TerroirEngine.Game;
var data = new GameData(Path.GetFullPath(Path.Combine(Path.GetDirectoryName((string)AppContext.GetData("EntryPointFilePath")!)!, "../../data")));
string id = args.Length > 0 ? args[0] : "mosel-2018";
var oes = (args.Length > 1 ? args[1] : "75,84").Split(',').Select(double.Parse);
var choiceSets = args.Length > 2 ? args.Skip(2).Select(a => JsonSerializer.Deserialize<Dictionary<string, int>>(a)!).ToList() : new List<Dictionary<string, int>> { new() };
var sc = Scenarios.Find(data, id)!;
foreach (var oe in oes) foreach (var ch in choiceSets)
{
    var g = new GameSession(data, Scenarios.Setup(data, id)); Scenarios.Autoplay(g, oe, ch);
    var ev = Scenarios.Evaluate(g);
    var wines = g.Wines.Where(w => w.Vintage == sc.Vintage && w.Blend.VarietyName == sc.Variety)
        .Select(w => $"{w.Legal!.Category} {w.Sheet!.Quality} {w.Blend.AlcoholPct:0.0}% B{(w.Sheet.Blic[0].Met ? 1 : 0)}L{(w.Sheet.Blic[1].Met ? 1 : 0)}I{(w.Sheet.Blic[2].Met ? 1 : 0)}C{(w.Sheet.Blic[3].Met ? 1 : 0)}");
    Console.WriteLine($"{id} @{oe} {JsonSerializer.Serialize(ch)} → medal {ev["medal"]} | {string.Join(" | ", wines)}");
}
