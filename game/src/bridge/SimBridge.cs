using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using Godot;
using TerroirEngine.Data;
using TerroirEngine.Game;
using TerroirEngine.Vineyard;

namespace TerroirGame;

/// <summary>Autoload "Sim": the only door between the GDScript UI and the C# simulation core (ADR 0001).
/// The UI reads JSON snapshots and sends commands; it never computes outcomes.</summary>
public partial class SimBridge : Node
{
    private GameData? _data;
    private GameSession? _game;
    private string _lastError = "";

    public override void _Ready()
    {
        try
        {
            var start = ProjectSettings.GlobalizePath("res://");
            _data = new GameData(GameData.LocateDataRoot(start));
        }
        catch (Exception e) { _lastError = e.Message; GD.PushError("Terroir: could not load game data: " + e.Message); }
    }

    public string LastError() => _lastError;
    public bool HasGame() => _game != null;
    public string Catalog() => _data == null ? "{}" : SetupCatalog.Json(_data);

    /// <summary>setupJson: {plotId, plantingYear, estateName, vineyardManager, cellarMaster, planting:{blockId:{variety, rootstock, training, density}}}</summary>
    public bool NewGame(string setupJson)
    {
        try
        {
            using var doc = JsonDocument.Parse(setupJson);
            var r = doc.RootElement;
            var setup = new GameSetup
            {
                PlotId = r.GetProperty("plotId").GetString()!,
                PlantingYear = r.GetProperty("plantingYear").GetInt32(),
                EstateName = r.TryGetProperty("estateName", out var en) ? en.GetString() ?? "Weingut" : "Weingut",
                Seed = r.TryGetProperty("seed", out var sd) ? (ulong)sd.GetInt64() : (ulong)DateTime.Now.Ticks,
                VineyardManager = r.TryGetProperty("vineyardManager", out var vm) ? Enum.Parse<StaffLevel>(vm.GetString()!) : StaffLevel.Junior,
                CellarMaster = r.TryGetProperty("cellarMaster", out var cm) ? Enum.Parse<StaffLevel>(cm.GetString()!) : StaffLevel.Junior,
            };
            if (r.TryGetProperty("planting", out var pl))
                foreach (var b in pl.EnumerateObject())
                    setup.Planting[b.Name] = new PlantingChoice
                    {
                        Variety = Enum.Parse<VarietyId>(b.Value.GetProperty("variety").GetString()!),
                        Rootstock = Enum.Parse<RootstockId>(b.Value.GetProperty("rootstock").GetString()!),
                        Training = Enum.Parse<TrainingSystem>(b.Value.GetProperty("training").GetString()!),
                        Rows = b.Value.TryGetProperty("rows", out var rw) ? Enum.Parse<RowOrientation>(rw.GetString()!) : RowOrientation.NorthSouth,
                        DensityVinesHa = b.Value.GetProperty("density").GetInt32(),
                    };
            _game = new GameSession(_data!, setup);
            return true;
        }
        catch (Exception e) { _lastError = e.ToString(); GD.PushError("Terroir: new game failed: " + e); return false; }
    }

    public string Snapshot() => _game == null ? "{}" : TerroirEngine.Game.Snapshot.Json(_game);

    /// <summary>Advance up to maxDays, stopping at the first Alert. Returns days advanced.</summary>
    public int Advance(int maxDays, bool stopAtAlerts)
    {
        if (_game == null) return 0;
        try { return _game.Advance(maxDays, stopAtAlerts); }
        catch (Exception e) { _lastError = e.ToString(); GD.PushError("Terroir: advance failed: " + e); return 0; }
    }

    public bool Command(string type, string a, string b, string c, string d, string e)
    {
        if (_game == null) return false;
        try
        {
            _game.Apply(new TerroirEngine.Game.Command { Type = type, A = a ?? "", B = b ?? "", C = c ?? "", D = d ?? "", E = e ?? "" }, record: true);   // "read" is recorded too, so read state survives save and load
            return true;
        }
        catch (Exception ex) { _lastError = ex.ToString(); GD.PushError("Terroir: command failed: " + ex); return false; }
    }

    public string SaveDir() => ProjectSettings.GlobalizePath("user://saves");

    public bool SaveGame(string name)
    {
        if (_game == null) return false;
        Directory.CreateDirectory(SaveDir());
        File.WriteAllText(Path.Combine(SaveDir(), Safe(name) + ".json"), _game.Save());
        return true;
    }

    public bool LoadGame(string name)
    {
        try
        {
            var path = Path.Combine(SaveDir(), Safe(name) + ".json");
            if (!File.Exists(path)) return false;
            _game = GameSession.Load(_data!, File.ReadAllText(path));
            return true;
        }
        catch (Exception e) { _lastError = e.ToString(); GD.PushError("Terroir: load failed: " + e); return false; }
    }

    public string ListSaves()
    {
        if (!Directory.Exists(SaveDir())) return "[]";
        var files = Directory.GetFiles(SaveDir(), "*.json").OrderByDescending(File.GetLastWriteTimeUtc)
            .Select(f => new { name = Path.GetFileNameWithoutExtension(f), modified = File.GetLastWriteTime(f).ToString("yyyy-MM-dd HH:mm") });
        return JsonSerializer.Serialize(files);
    }

    private static string Safe(string n) => string.Concat((string.IsNullOrWhiteSpace(n) ? "autosave" : n).Select(ch => char.IsLetterOrDigit(ch) || ch is '-' or '_' ? ch : '_'));
}
