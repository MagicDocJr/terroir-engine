using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Threading.Tasks;
using Godot;
using TerroirEngine.Data;
using TerroirEngine.Game;
using TerroirEngine.Tasting.Practice;
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
            // editor/dev: data/ above the project; exported build: data/ next to the .exe
            string start = OS.HasFeature("editor") ? ProjectSettings.GlobalizePath("res://") : System.IO.Path.GetDirectoryName(OS.GetExecutablePath())!;
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

    // ------------------------------------------------------------------ Tasting practice (tasting-practice design §7)
    // Pours run on a background thread (a Flight takes about a second); the screen polls PourStatus. The study record lives in
    // user://tasting_record.json, separate from any Estate save. The bridge only passes JSON; PracticeSession decides.

    private Task<PracticeSession>? _pourTask;
    private int _pourId, _pourTaskId;
    private PracticeSession? _session;
    private string _recordPath = "";

    private string RecordPath => _recordPath != "" ? _recordPath : ProjectSettings.GlobalizePath("user://tasting_record.json");
    /// <summary>Harness and fuzz runs keep their own record so they never touch the player's.</summary>
    public void SetRecordPath(string path) { _recordPath = path.StartsWith("user://") ? ProjectSettings.GlobalizePath(path) : path; if (File.Exists(_recordPath)) File.Delete(_recordPath); }
    public string RecordFile() => RecordPath;
    private JsonObject LoadRecord()
    {
        if (!File.Exists(RecordPath)) return new JsonObject();
        if (PracticeProgress.TryLoad(File.ReadAllText(RecordPath), out var rec)) return rec;
        // unreadable: keep a copy before the next save replaces it, so no XP or medals are lost for good
        var bad = RecordPath + $".unreadable-{DateTime.Now:yyyyMMdd-HHmmss}";
        File.Copy(RecordPath, bad, true);
        File.Delete(RecordPath);
        _lastError = "The Tasting-practice record could not be read; a copy was kept at " + bad;
        GD.PushWarning("Terroir: " + _lastError);
        return rec;
    }
    private void SaveRecord(JsonObject r)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(RecordPath)!);
        var tmp = RecordPath + ".tmp";
        File.WriteAllText(tmp, r.ToJsonString());
        File.Move(tmp, RecordPath, true);
    }
    private int? MaxVintage() => _game == null ? null : PracticeSession.MaxVintageFor(_game.Date);
    private static DateOnly Today() => DateOnly.FromDateTime(DateTime.Now);

    public string PracticeSummary()
    {
        try { return PracticeProgress.Summary(LoadRecord(), Today()).ToJsonString(); }
        catch (Exception e) { _lastError = e.ToString(); return "{}"; }
    }

    public string PracticeLobby()
    {
        try { return _data == null ? "{}" : PracticeSession.Lobby(_data, LoadRecord(), Today(), MaxVintage()).ToJsonString(); }
        catch (Exception e) { _lastError = e.ToString(); GD.PushError("Terroir: practice lobby failed: " + e); return "{}"; }
    }

    /// <summary>requestJson: {kind: practice|suggest|daily|stand, exercise?, stand?, blind?, seed?}. Starts a pour and returns its id;
    /// a new pour replaces any pour still running (its result is dropped).</summary>
    public int PourStart(string requestJson)
    {
        if (_data == null) return 0;
        JsonObject req;
        try { req = JsonNode.Parse(requestJson) as JsonObject ?? new JsonObject(); }
        catch (Exception e) { _lastError = e.Message; return 0; }
        if (req["seed"] == null) req["seed"] = (int)(DateTime.Now.Ticks % 1_000_000) + 1;
        var rec = LoadRecord(); var max = MaxVintage(); var today = Today(); var data = _data;
        _pourTaskId = ++_pourId;
        _session = null;
        _pourTask = Task.Run(() => PracticeSession.Pour(data, req, rec, today, max));
        return _pourTaskId;
    }

    /// <summary>"pouring", "ready", "failed: …" or "none" (an unknown or dropped id).</summary>
    public string PourStatus(int id)
    {
        if (id == 0 || id != _pourTaskId || _pourTask == null) return "none";
        if (!_pourTask.IsCompleted) return "pouring";
        if (_pourTask.IsFaulted) return "failed: " + (_pourTask.Exception?.InnerException?.Message ?? "unknown error");
        return "ready";
    }

    public string PourResult(int id)
    {
        if (PourStatus(id) != "ready") return "{}";
        _session = _pourTask!.Result;
        return _session.Json(_data!).ToJsonString();
    }

    public void PourDrop() { _pourTaskId = 0; _session = null; }

    /// <summary>Marks the poured Flight once, updates and saves the study record, and returns the reveal.</summary>
    public string PracticeMark(string answersJson)
    {
        if (_session == null || _data == null) return "{}";
        try
        {
            var answers = JsonNode.Parse(answersJson) as JsonObject ?? new JsonObject();
            var (result, rec) = _session.Mark(_data, answers, LoadRecord(), Today());
            SaveRecord(rec);
            _session = null; _pourTask = null; _pourTaskId = 0;   // one mark per pour: no double points
            return result.ToJsonString();
        }
        catch (Exception e) { _lastError = e.ToString(); GD.PushError("Terroir: marking failed: " + e); return "{}"; }
    }
}
