#:project ../../sim/src/TerroirEngine.Core/TerroirEngine.Core.csproj
#:property PublishAot=false
#:property JsonSerializerIsReflectionEnabledByDefault=true
// Print the Vintage-in-review cause cards of a famous-vintage scenario played by the scripted player.
// Usage: dotnet run tools/probes/review-cards.cs <scenario-id> [pick-oe] ['{"Sweetness":2}']
using System.Text.Json;
using TerroirEngine.Data;
using TerroirEngine.Game;
var data = new GameData(Path.GetFullPath(Path.Combine(Path.GetDirectoryName((string)AppContext.GetData("EntryPointFilePath")!)!, "../../data")));
string id = args.Length > 0 ? args[0] : "cotedor-2016";
double oe = args.Length > 1 ? double.Parse(args[1]) : 94;
var ch = args.Length > 2 ? JsonSerializer.Deserialize<Dictionary<string, int>>(args[2]) : null;
var g = new GameSession(data, Scenarios.Setup(data, id)); Scenarios.Autoplay(g, oe, ch);
int v = Scenarios.Find(data, id)!.Vintage;
foreach (var c in VintageReview.Cards(g, v))
{
    Console.WriteLine($"[{c!["priority"]}] {c["date"]} · {c["title"]} ({c["wine"]})");
    foreach (var h in c["happened"]!.AsArray()) Console.WriteLine($"    {h}");
    foreach (var l in c["lines"]!.AsArray()) Console.WriteLine($"    → {l!["attribute"]}: {l["level"]} — {l["because"]}");
}
