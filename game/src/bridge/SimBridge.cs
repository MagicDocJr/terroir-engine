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
using TerroirEngine.Learning;
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
            var d = _data;
            Task.Run(() => { try { LearnCards.OakTable(d); } catch { } });   // warm the oak card's visual (about a second of pours)
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
                ShopVersion = 1,
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
            Predictions.Init(_game);
            return true;
        }
        catch (Exception e) { _lastError = e.ToString(); GD.PushError("Terroir: new game failed: " + e); return false; }
    }

    // ------------------------------------------------------------------ Vintage in review
    /// <summary>The first time a Vintage's review is shown: its cards' Causes join the review queue (no answer counted),
    /// once per game (a flag in the save).</summary>
    public void ReviewSeen(int vintage)
    {
        if (_game == null || _data == null) return;
        try
        {
            string flag = $"review-seen-{vintage}";
            if (_game.Flags.Contains(flag) || VintageReview.Review(_game, vintage) is not { } rev) return;
            _game.Apply(new Command { Type = "flag", A = flag });
            SaveRecord(StudyRecord.Enqueue(LoadRecord(), VintageReview.CauseIds(rev), Today(), _data));
        }
        catch (Exception e) { _lastError = e.ToString(); }
    }

    // ------------------------------------------------------------------ famous vintages (docs/superpowers/specs/2026-10-03-famous-vintages-design.md)
    public string ScenarioList()
    {
        try { return _data == null ? "[]" : Scenarios.List(_data, LoadRecord()).ToJsonString(); }
        catch (Exception e) { _lastError = e.ToString(); return "[]"; }
    }

    /// <summary>The scenario id of the game in play ("" for a normal game): the shell's autosave slot follows it.</summary>
    public string ScenarioId() => _game?.Setup.ScenarioId ?? "";

    public bool NewScenarioGame(string id)
    {
        try
        {
            _game = new GameSession(_data!, Scenarios.Setup(_data!, id));
            Predictions.Init(_game);
            return true;
        }
        catch (Exception e) { _lastError = e.ToString(); GD.PushError("Terroir: scenario failed: " + e); return false; }
    }

    /// <summary>The scenario's goals, and once a Wine of the vintage is in bottle its medals and debrief. A newly earned or
    /// better medal is kept in the study record, and the year's Causes join the review queue (no answer counted).</summary>
    public string ScenarioStatus()
    {
        if (_game == null || _data == null) return "{\"scenario\":null}";
        try
        {
            var st = Scenarios.Status(_game);
            if ((bool)st["judged"]!)
            {
                // written only when something changed (a new or better medal, Causes not yet queued)
                var rec = LoadRecord();
                var next = Scenarios.ApplyToRecord(rec, st, Today(), _data);
                if (next.ToJsonString() != StudyRecord.Migrate(rec).ToJsonString()) SaveRecord(next);
            }
            return st.ToJsonString();
        }
        catch (Exception e) { _lastError = e.ToString(); return "{\"scenario\":null}"; }
    }

    public void ScenarioDebriefSeen() { if (_game != null && !_game.Flags.Contains("scenario-debrief-seen")) _game.Apply(new Command { Type = "flag", A = "scenario-debrief-seen" }); }

    /// <summary>Harness only (scripts/scenarios.sh): plays the current scenario with the scripted player to bottling.</summary>
    public void ScenarioAutoplay(double targetOe, string choicesJson)
    {
        if (_game == null) return;
        var ch = (JsonNode.Parse(string.IsNullOrEmpty(choicesJson) ? "{}" : choicesJson) as JsonObject ?? new()).ToDictionary(kv => kv.Key, kv => (int)kv.Value!);
        Scenarios.Autoplay(_game, targetOe, ch);
    }

    /// <summary>Why the last Shop purchase was refused ("" if it went through).</summary>
    public string ShopRefusal() => _game?.ShopRefusal ?? "";
    /// <summary>Harness only: own every Shop item (3D look checks and the thumbnail renderer).</summary>
    public void ShopOwnAll() => _game?.HarnessOwnAll();

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

    private string _saveDir = "user://saves";
    public string SaveDir() => ProjectSettings.GlobalizePath(_saveDir);
    /// <summary>Harness only: each harness saves into its own folder, so harnesses can run in parallel (scripts/check.sh).</summary>
    public void SetSaveDir(string dir) => _saveDir = dir;

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
            Predictions.Init(_game);   // Wines bottled before predictions existed count as revealed
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
    private static DateOnly? _todayOverride;
    private static DateOnly Today() => _todayOverride ?? DateOnly.FromDateTime(DateTime.Now);
    /// <summary>Harness only: play sessions on chosen dates ("" returns to the real date).</summary>
    public void SetPracticeToday(string date) => _todayOverride = DateOnly.TryParse(date, System.Globalization.CultureInfo.InvariantCulture, out var d) ? d : null;

    public string PracticeSummary()
    {
        try { return PracticeProgress.Summary(LoadRecord(), Today(), _data == null ? null : CauseCatalog.All(_data)).ToJsonString(); }
        catch (Exception e) { _lastError = e.ToString(); return "{}"; }
    }

    /// <summary>Sets the exam date the review schedule works towards ("yyyy-MM-dd"; "" clears it). Returns "" when saved, else
    /// the reason it was refused (the sim validates; the screen only shows the message).</summary>
    public string PracticeSetExamDate(string date)
    {
        try
        {
            var (rec, err) = PracticeProgress.TrySetExamDate(LoadRecord(), date, Today());
            if (err == null) SaveRecord(rec);
            return err ?? "";
        }
        catch (Exception e) { _lastError = e.ToString(); return "The exam date could not be saved."; }
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

    /// <summary>Harness only (scripts/practice.sh, learning.sh): the poured Wines and the session's answers. The screens never
    /// call it; they get only what they may show until the reveal.</summary>
    public string PracticeDebugKey()
    {
        if (_session == null) return "{}";
        return new JsonObject
        {
            ["wines"] = new JsonArray(_session.Flight.Select(p => (JsonNode)PracticeJson.Poured(p)).ToArray()),
            ["entries"] = new JsonArray(_session.Entries.Select(e => (JsonNode)new JsonObject
            {
                ["answers"] = new JsonArray(e.Questions.Select(q => (JsonNode)JsonValue.Create(q.Answer)!).ToArray()),
            }).ToArray()),
        }.ToJsonString();
    }

    // ------------------------------------------------------------------ learn cards (learning-core §7)
    /// <summary>contextJson: {plot?, block?, lot?}. Returns the card for the drawer and remembers it was opened.</summary>
    public string LearnCard(string id, string contextJson)
    {
        if (_data == null) return "{}";
        try
        {
            var ctx = JsonNode.Parse(string.IsNullOrEmpty(contextJson) ? "{}" : contextJson) as JsonObject ?? new JsonObject();
            var rec = LoadRecord();
            var card = LearnCards.Card(_data, id, ctx, rec, _game);
            if (card == null) return "{}";
            var seen = rec["seenCards"] as JsonArray ?? new JsonArray();
            if (!seen.Any(x => x?.GetValue<string>() == id)) { seen.Add(id); rec["seenCards"] = seen.DeepClone(); SaveRecord(rec); }
            return card.ToJsonString();
        }
        catch (Exception e) { _lastError = e.ToString(); GD.PushError("Terroir: learn card failed: " + e); return "{}"; }
    }

    public string LearnSeenList()
    {
        var rec = LoadRecord();
        return (rec["seenCards"] as JsonArray ?? new JsonArray()).ToJsonString();
    }

    /// <summary>The card's check question: marks it and puts the card's Causes in the review queue (never a review itself).</summary>
    public bool LearnCheck(string id, string answer, int confidence)
    {
        if (_data == null) return false;
        try
        {
            var (rec, right) = LearnCards.Check(_data, LoadRecord(), id, answer, Today());
            SaveRecord(rec);
            return right;
        }
        catch (Exception e) { _lastError = e.ToString(); return false; }
    }

    // ------------------------------------------------------------------ predict before reveal on the Estate (learning-core §6)
    public string PredictionFor(string wineId)
    {
        if (_game == null) return "{}";
        try { return Predictions.ForOrNull(_game, wineId)?.ToJsonString() ?? "{}"; }
        catch (Exception e) { _lastError = e.ToString(); return "{}"; }
    }

    /// <summary>Marks the predictions, adds them to the study record, and reveals the Wine (a game flag).</summary>
    public string RevealWine(string wineId, string answersJson)
    {
        if (_game == null || _data == null) return "{}";
        try
        {
            var answers = JsonNode.Parse(answersJson) as JsonObject ?? new JsonObject();
            var (result, events) = Predictions.Mark(_game, wineId, answers);
            var ev = new JsonObject { ["kind"] = "practice", ["date"] = Today().ToString("yyyy-MM-dd"), ["items"] = new JsonArray(events.Select(e => (JsonNode)e).ToArray()) };
            var rec = PracticeProgress.Apply(LoadRecord(), ev);
            SaveRecord(rec);
            result["summary"] = PracticeProgress.Summary(rec, Today(), CauseCatalog.All(_data));
            Predictions.Reveal(_game, wineId);
            return result.ToJsonString();
        }
        catch (Exception e) { _lastError = e.ToString(); GD.PushError("Terroir: reveal failed: " + e); return "{}"; }
    }

    public void SkipPrediction(string wineId) { if (_game != null) Predictions.Reveal(_game, wineId); }

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
