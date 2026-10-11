#:project ../../sim/src/TerroirEngine.Core/TerroirEngine.Core.csproj
#:property PublishAot=false
#:property JsonSerializerIsReflectionEnabledByDefault=true
// What a new game looks like on its first day (date, stage, the Blocks), e.g. for the intro cinematic. Usage:
// dotnet run tools/probes/start-state.cs [plotId=mosel-blauschiefer] [plantingYear=2015]
using TerroirEngine.Data;
using TerroirEngine.Game;
var data = new GameData(Path.GetFullPath(Path.Combine(Path.GetDirectoryName((string)AppContext.GetData("EntryPointFilePath")!)!, "../../data")));
var g = new GameSession(data, new GameSetup { PlotId = args.Length > 0 ? args[0] : "mosel-blauschiefer", PlantingYear = args.Length > 1 ? int.Parse(args[1]) : 2015 });
Console.WriteLine($"{g.Date} first vintage {g.FirstVintage}");
foreach (var b in g.Blocks) Console.WriteLine($"  {b.Data.Id} {b.Variety.Name} {b.Planting.Training} stage {b.Stage}");
