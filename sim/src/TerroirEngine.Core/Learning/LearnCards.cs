using System.Collections.Concurrent;
using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using TerroirEngine.Data;
using TerroirEngine.Game;
using TerroirEngine.Util;
using TerroirEngine.Winery;

namespace TerroirEngine.Learning;

public sealed record LearnChain(string? Cause, string[] Steps, string[] Sources);
public sealed record LearnCheck(string Question, string[] Options, string Answer, string Why);

/// <summary>A learn card: the explanation at a decision, in one fixed structure (learning-core design §7.1).</summary>
public sealed record LearnCard(string Id, string Title, string What, IReadOnlyList<LearnChain> Chains, string Choose, string Exam,
    LearnCheck Check, string[] Sources, string Visual, string[] Causes, string Simplification);

/// <summary>What the "On this site" line can use (all optional): the Plot and Block in front of the player, and the Lot.</summary>
public sealed record SiteFacts(string? Region = null, string? PlotName = null, double? PlotSlope = null, string[]? TrainingAllowed = null,
    string? BlockId = null, double? BlockSlope = null, double? Aspect = null, double? ActiveLime = null, double? Taw = null,
    string? BudLoad = null, double? BudsPerVine = null, double? MustOe = null, double? MustTa = null, double? MustPh = null, double? SeedRipe = null,
    string? LotId = null, string? Variety = null, bool? Red = null, double? Yan = null, double? Malic = null, double? Ph = null, double? Sugar = null,
    string? Vessel = null, string? Temperature = null, string? Lees = null, double? HarvestSeedRipe = null,
    string? RegionId = null, string? Classification = null, string? BlockVariety = null, double? MustSugar = null, string? LeafSide = null, string? LeafTiming = null,
    double? Lafr = null, double? Ta = null, double? TaAfterMlf = null, double? PhAfterMlf = null, double? YanStart = null, double? H2s = null, string? OakTerms = null);

/// <summary>Loads data/learn/*.json, checks the mechanical part of the quality gate, and builds a card for the screen with its
/// "On this site" line from the player's own data (learning-core design §7). A card whose Causes are all Known shows briefly.</summary>
public static class LearnCards
{
    public const int MinWords = 120, MaxWords = 180;
    private static readonly ConcurrentDictionary<string, IReadOnlyList<LearnCard>> Cache = new();
    private static readonly CultureInfo Ci = CultureInfo.InvariantCulture;

    public static IReadOnlyList<LearnCard> All(GameData data) => Cache.GetOrAdd(data.DataRoot, root =>
    {
        var dir = Path.Combine(root, "learn");
        if (!Directory.Exists(dir)) return Array.Empty<LearnCard>();
        var list = new List<LearnCard>();
        foreach (var f in Directory.GetFiles(dir, "*.json").OrderBy(x => x, StringComparer.Ordinal))
        {
            using var doc = JsonDocument.Parse(File.ReadAllText(f));
            var e = doc.RootElement;
            string S(JsonElement x, string k) => x.TryGetProperty(k, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString()! : "";
            string[] A(JsonElement x, string k) => x.TryGetProperty(k, out var v) && v.ValueKind == JsonValueKind.Array ? v.EnumerateArray().Select(y => y.GetString() ?? "").ToArray() : Array.Empty<string>();
            var chains = e.TryGetProperty("chains", out var cs) ? cs.EnumerateArray().Select(c =>
                new LearnChain(S(c, "cause") is { Length: > 0 } id ? id : null, A(c, "steps"), A(c, "sources"))).ToList() : new List<LearnChain>();
            var ck = e.GetProperty("check");
            list.Add(new LearnCard(S(e, "id"), S(e, "title"), S(e, "what"), chains, S(e, "choose"), S(e, "exam"),
                new LearnCheck(S(ck, "question"), A(ck, "options"), S(ck, "answer"), S(ck, "why")), A(e, "sources"), S(e, "visual"), A(e, "causes"), S(e, "simplification")));
        }
        return list;
    });

    public static LearnCard? Find(GameData data, string id) => All(data).FirstOrDefault(c => c.Id == id);

    /// <summary>The card's check question: marks the answer and puts the card's Causes in the review queue (due tomorrow) if
    /// they are not there yet. It is never a review itself: the question is fixed and could be answered again and again, so it
    /// must not move a Cause towards Known (final review of the learning core).</summary>
    public static (JsonObject Record, bool Right) Check(GameData data, JsonObject record, string id, string answer, DateOnly today)
    {
        if (Find(data, id) is not { } card) return (record, false);
        var rec = StudyRecord.Migrate(record);
        var states = StudyRecord.States(rec);
        foreach (var c in card.Causes.Where(c => !states.ContainsKey(c) && CauseCatalog.Find(data, c) != null))
            StudyRecord.Put(rec, new CauseState(c, 0, 0, ReviewScheduler.StartDifficulty, today.AddDays(1), null, new List<CauseAnswer>(), false));
        return (rec, answer == card.Check.Answer);
    }

    /// <summary>The chain steps a card shows: a catalogue Cause's chain, or the card's own steps.</summary>
    public static string[] Steps(GameData data, LearnChain ch) => ch.Cause != null ? CauseCatalog.Find(data, ch.Cause)?.Chain ?? Array.Empty<string>() : ch.Steps;

    private static int Words(string s) => s.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Length;

    public static int WordCount(GameData data, LearnCard c) =>
        Words(c.What) + Words(c.Choose) + Words(c.Exam) + c.Chains.Sum(ch => Steps(data, ch).Sum(Words));

    /// <summary>The mechanical part of the quality gate (spec §7.4): an empty list means the card passes.</summary>
    public static List<string> Problems(GameData data, LearnCard c)
    {
        var p = new List<string>();
        int w = WordCount(data, c);
        if (w < MinWords || w > MaxWords) p.Add($"main text {w} words (budget {MinWords}–{MaxWords})");
        if (c.Chains.Count is < 1 or > 3) p.Add($"{c.Chains.Count} chains (1–3)");
        foreach (var ch in c.Chains)
        {
            if (ch.Cause != null && CauseCatalog.Find(data, ch.Cause) == null) p.Add($"unknown Cause {ch.Cause}");
            int n = Steps(data, ch).Length;
            if (n is < 2 or > 4) p.Add($"chain of {n} steps");
            foreach (var s in ch.Sources) if (!CauseCatalog.SourceResolves(data, s)) p.Add($"chain source '{s}' not found");
        }
        foreach (var id in c.Causes) if (CauseCatalog.Find(data, id) == null) p.Add($"unknown Cause {id}");
        if (c.Sources.Length == 0) p.Add("no sources");
        foreach (var s in c.Sources) if (!CauseCatalog.SourceResolves(data, s)) p.Add($"source '{s}' not found");
        if (string.IsNullOrWhiteSpace(c.Check.Question) || c.Check.Options.Length < 3 || !c.Check.Options.Contains(c.Check.Answer) || string.IsNullOrWhiteSpace(c.Check.Why))
            p.Add("check question incomplete");
        var main = string.Join(" ", c.What, c.Choose, c.Exam, string.Join(" ", c.Chains.SelectMany(ch => Steps(data, ch))), c.Check.Question, c.Check.Why);
        if (main.Contains("WSET", StringComparison.OrdinalIgnoreCase)) p.Add("mentions WSET");
        if (main.Contains("UNVERIFIED", StringComparison.Ordinal)) p.Add("UNVERIFIED claim in the main text");
        return p;
    }

    private static string F(double v, string fmt = "0") => v.ToString(fmt, Ci);
    private static string Dir(double aspect) => new[] { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" }[(int)Math.Round(((aspect % 360) + 360) % 360 / 45.0) % 8];

    private static readonly (string Name, double Limit)[] LimeLimits = Rootstock.All.Where(r => r.Id != RootstockId.OwnRooted).Select(r => (r.Name, r.MaxChlorosisIndex)).ToArray();

    /// <summary>The "On this site" line: one or two sentences that interpret the player's own data with the game's rules
    /// (learning-core design §7.1), or a general line when the context is missing (pre-game with no Block chosen, a Lot not
    /// yet received). Every rule quoted here is the simulation's own.</summary>
    public static string SiteLine(string cardId, SiteFacts f)
    {
        string allowed = string.Join(", ", f.TrainingAllowed ?? Array.Empty<string>());
        string? line = cardId switch
        {
            "training-system" when f.BlockSlope is double sl => f.TrainingAllowed is { Length: 1 } ta && ta[0] == "Einzelpfahl"
                ? $"Block {f.BlockId}: {F(sl)} % slope; this Plot allows only single stakes (Einzelpfahl), tended by hand."
                : sl >= 30 ? $"Block {f.BlockId}: {F(sl)} % slope. In this game slopes from 30 % rule out machines whatever the trellis; this Plot allows {allowed}."
                : $"Block {f.BlockId}: {F(sl)} % slope, so machines can work and pick here; this Plot allows {allowed}.",
            "rootstock" when f.ActiveLime is double lime && f.Taw is double taw => RootstockLine(f.BlockId, lime, taw),
            "harvest-date" when f.MustOe is double oe && f.MustTa is double mta => Harvest(f, oe, mta),
            "leaf-removal" when f.LeafSide != null => Leaf(f),
            "green-harvest" when f.Lafr is double lafr && lafr > 0 =>
                $"Block {f.BlockId}: about {F(lafr, "0.00")} m² of leaf per kg of fruit. " + (lafr < 1.0 ? "That is below the game's 1 m²/kg: thinning would speed ripening." : lafr <= 1.2 ? "That is balanced: thinning would add little ripening and only cost fruit." : "Plenty of leaf: the vine can ripen this crop as it is."),
            "whole-bunch" when f.HarvestSeedRipe is double hs => $"Lot {f.LotId}: seeds were {F(hs * 100)} % ripe at harvest, the game's sign of how ripe the stems are. " +
                (hs < 0.44 ? "100 % whole bunch would add stalky, green notes and firm tannin; 30 % some of both." : hs < 0.83 ? "100 % whole bunch would still add stalky notes; 30 % adds tannin with little stalkiness." : "The stems are ripe enough: whole bunches add tannin without green, stalky notes."),
            "fermentation-temperature" when f.Red is bool red && f.Sugar is double sug =>
                $"Lot {f.LotId} ({(red ? "red" : "white")}): {F(sug)} g/L of sugar to ferment, enough to warm an uncooled tank by up to about {F(sug / 10 * 1.3)} °C. " +
                (f.Temperature is "Uncontrolled" or "Cellar ambient" ? "The plan leaves it uncooled." : f.Temperature != null ? $"The plan holds it at {f.Temperature}." : ""),
            "yeast-nitrogen" when f.Yan is double yan && f.Sugar is double ys =>
                YanLine(f.LotId, yan, Units.BrixFromSugar(Math.Max(0, ys))),
            "malolactic" when f.Malic is double ml && f.Ta is double lta && f.Ph is double lp =>
                $"Lot {f.LotId}: {F(ml, "0.0")} g/L malic acid, TA {F(lta, "0.0")} g/L, pH {F(lp, "0.00")}." +
                (f.TaAfterMlf is double ta2 && f.PhAfterMlf is double ph2 && ml > 0.2 ? $" Full conversion would bring TA to about {F(ta2, "0.0")} g/L and pH to about {F(ph2, "0.00")}." : " Little malic acid is left to convert.") +
                (f.RegionId == "cote-dor" && f.Red == true ? " Côte d'Or village and Premier Cru reds must end at 0.4 g/L malic or less." : ""),
            "oak" when f.Variety != null && f.Vessel != null =>
                $"Lot {f.LotId} ({f.Variety}) is planned in {f.Vessel}." + (f.OakTerms != null ? (f.OakTerms == "" ? " In the game's oak model a Chardonnay in that vessel shows no oak on the nose." : $" In the game's oak model a Chardonnay in that vessel shows {f.OakTerms}.") : ""),
            "lees" when f.H2s is double h2s =>
                $"Lot {f.LotId}" + (f.YanStart is double ys0 && ys0 > 0 ? $" fermented from YAN {F(ys0)} mg/L" : "") + ": " +
                (h2s > 1.0 ? "it smells reduced (H₂S), a fault." : h2s > 0.5 ? "a slight struck-match reduction." : h2s > 0.05 ? "a trace of H₂S below what you would notice." : "no H₂S.") + " Unstirred lees let any reduction linger; stirring dissolves a little oxygen.",
            "stopping-for-sweetness" when f.Sugar is double sug2 && sug2 > 20 => Stops(f.LotId, sug2),
            _ => null,
        };
        return line ?? cardId switch
        {
            "training-system" => "In this game slopes from 30 % rule out machines whatever the trellis; flatter Blocks can be worked and picked by machine.",
            "harvest-date" => "The Ripeness screen's weekly samples show each Block's sugar, acid and seed ripeness: decide from those, not the calendar.",
            _ => "Open this card from a Block or a Lot to see what it means there.",
        };
    }

    private static string RootstockLine(string? block, double lime, double taw)
    {
        double ipc = lime * 4;   // the game's chlorosis index (VineyardModel): about 4 × active lime % under its fixed soil-iron assumption (game simplification, soil-and-water.md §8)
        var yellow = LimeLimits.Where(r => ipc > 0.8 * r.Limit).Select(r => r.Name).ToList();
        var fine = LimeLimits.Where(r => ipc <= 0.8 * r.Limit).Select(r => r.Name).ToList();
        string Join(List<string> xs) => xs.Count <= 1 ? string.Concat(xs) : string.Join(", ", xs.Take(xs.Count - 1)) + " and " + xs[^1];
        string l = lime <= 0 ? $"Block {block}: no active lime, so any rootstock copes."
            : $"Block {block}: {F(lime, "0.#")} % active lime (chlorosis index about {F(ipc)} in this game): " +
              (yellow.Count == 0 ? "every rootstock copes." : $"{Join(yellow)} would turn yellow; {Join(fine)} {(fine.Count == 1 ? "copes" : "cope")}.");
        bool paulsenYellows = yellow.Contains("1103 Paulsen");
        return l + (taw >= 100 ? $" {F(taw)} mm of water in reach, so drought is not the main limit."
            : paulsenYellows ? $" Only {F(taw)} mm of water in reach: 1103 Paulsen would suit the dry soil but yellows on this lime, so weigh drought against chlorosis."
            : $" Only {F(taw)} mm of water in reach: deep-rooting 1103 Paulsen copes best with dry summers.");
    }

    private static string Harvest(SiteFacts f, double oe, double mta)
    {
        string head = $"Block {f.BlockId} today: {F(oe)} °Oe, TA {F(mta, "0.0")} g/L" + (f.MustPh is double mp ? $", pH {F(mp, "0.00")}" : "") + (f.SeedRipe is double sr ? $", seeds {F(sr * 100)} % ripe." : ".");
        string tail = "";
        if (f.RegionId == "mosel")
        {
            bool otherWhite = f.Red == false && f.BlockVariety != "Riesling";
            var steps = new (string Name, double Oe)[] { ("Kabinett", 73), ("Spätlese", otherWhite ? 85 : 80), ("Auslese", otherWhite ? 93 : 88) };
            var reached = steps.LastOrDefault(x => oe >= x.Oe);
            var next = steps.FirstOrDefault(x => oe < x.Oe);
            tail = (reached.Name != null ? $" {reached.Name} level ({F(reached.Oe)}) reached" : " Below Kabinett level (73)") + (next.Name != null ? $"; {next.Name} needs {F(next.Oe)}." : ".");
        }
        else if (f.RegionId == "cote-dor" && f.MustSugar is double sg && f.Classification is string cls && (cls.StartsWith("Village") || cls.StartsWith("Premier Cru")))
        {
            bool pc = cls.StartsWith("Premier Cru");
            tail = $" {F(sg)} g/L sugar against the {(pc ? "Premier Cru" : "Village")} minimum of {F(pc ? 189 : 180)} g/L.";
        }
        if (f.Red == true && f.SeedRipe is double s2 && s2 < 0.62) tail += " The seeds are still green: their tannin would taste coarse.";
        return head + tail;
    }

    private static string Leaf(SiteFacts f)
    {
        string side = f.LeafSide!.ToLowerInvariant(), timing = (f.LeafTiming ?? "").ToLowerInvariant();
        string plan = f.LeafSide switch
        {
            "None" => "Planned: no leaf removal, so shaded, damper bunches.",
            "Morning" => "Planned: morning side, so drier bunches with little sunburn risk.",
            _ => timing == "late" ? $"Planned: {(side == "both" ? "both sides" : side + " side")}, late: the riskiest pairing in a heatwave." : $"Planned: {(side == "both" ? "both sides" : side + " side")}, early: more sun on bunches that have time to acclimatise.",
        };
        string grape = f.BlockVariety switch
        {
            "Cabernet Sauvignon" => " For Cabernet Sauvignon, only removal before véraison lowers the green-pepper pyrazines.",
            "Riesling" => " For Riesling, early sun on the bunches builds the petrol note's precursors.",
            _ => "",
        };
        return plan + grape;
    }

    private static string YanLine(string? lot, double yan, double brix)
    {
        double target = 140 + 25 * Math.Max(0, brix - 20);   // the game's need (fermentation.md YAN heuristic)
        return $"Lot {lot}: YAN {F(yan)} mg/L; at {F(brix, "0.0")} °Brix the game reckons the yeast need about {F(target)}: " +
               (yan < target ? "short, so expect a slow ferment and H₂S unless you add DAP." : "enough for a clean fermentation.");
    }

    private static string Stops(string? lot, double sugar)
    {
        string Pa(double g) => F(g / 16.83, "0.0");
        var stops = new[] { 15.0, 35, 60 }.Where(x => x < sugar - 5).Select(x => $"{F(x)} g/L gives about {Pa(sugar - x)} % vol");
        return $"Lot {lot}: {F(sugar)} g/L of sugar to ferment. Dry gives about {Pa(sugar)} % vol; stopping at {string.Join(", at ", stops)}.";
    }

    /// <summary>Facts for the site line from a game (when there is one) and the context ids.</summary>
    public static SiteFacts Facts(GameData data, JsonObject context, GameSession? g)
    {
        string? S(string k) => context[k] is JsonValue v && v.TryGetValue<string>(out var s) && s != "" ? s : null;
        var plot = S("plot") is string pid ? data.Plots.Regions.SelectMany(r => r.Plots).FirstOrDefault(p => p.Id == pid) : g?.Plot;
        var blockData = S("block") is string bid ? plot?.Blocks.FirstOrDefault(b => b.Id == bid) : null;
        var f = new SiteFacts(Region: plot?.Region.Name, PlotName: plot?.Name, PlotSlope: plot?.SlopePct, TrainingAllowed: plot?.TrainingAllowed.ToArray(),
            BlockId: blockData?.Id, BlockSlope: blockData?.Topography.SlopePct, Aspect: blockData?.Topography.AspectDeg,
            ActiveLime: blockData?.Soil.ActiveLimePct, Taw: blockData?.Soil.TawMm, RegionId: plot?.Region.Id, Classification: plot?.Classification);
        if (g != null && blockData != null && g.Blocks.FirstOrDefault(b => b.Data.Id == blockData.Id) is { } bs)
        {
            f = f with
            {
                BudLoad = bs.BudLoad.ToString(), BudsPerVine = bs.BudsPerVine, BlockVariety = bs.Variety.Name, Red = bs.Variety.Red,
                LeafSide = bs.LeafSide.ToString(), LeafTiming = bs.LeafTiming.ToString(),
                Lafr = bs.CropKgPerVine > 0.05 && !bs.Harvested ? bs.LeafAreaPerVine * 0.55 / bs.CropKgPerVine : null,
            };
            if (bs.Veraison != null && !bs.Harvested)
            {
                var must = Chemistry.MustFromBlock(bs);
                f = f with { MustOe = must.Oe, MustTa = must.TaGL, MustPh = must.Ph, SeedRipe = bs.SeedMaturity, MustSugar = bs.SugarGL };
            }
        }
        if (g != null && S("lot") is string lid && g.Lots.FirstOrDefault(l => l.Id == lid) is { } lot)
        {
            string Opt(string key) => lot.Choices.TryGetValue(key, out var i) ? CellarOptions.Get(key).Options[Math.Clamp(i, 0, CellarOptions.Get(key).Options.Length - 1)] : "";
            var after = lot.Acids; after.Lactic += lot.Malic * 0.672; after.Malic = 0;   // malic (134 g/mol, two acid groups) → lactic (90 g/mol, one)
            string vessel = Opt("Vessel");
            var oakRow = OakTable(data).FirstOrDefault(r => r?["vessel"]?.GetValue<string>() == vessel);   // cached after the first call
            f = f with
            {
                LotId = lot.Id, Variety = lot.VarietyName, Red = lot.Red, Yan = lot.YanMgL, Malic = lot.Malic, Ph = lot.Ph, Ta = lot.Ta, Sugar = lot.Rs,
                TaAfterMlf = Chemistry.TitratableAcidity(after), PhAfterMlf = Chemistry.Ph(after),
                Vessel = vessel, Temperature = lot.Red ? Opt("Red temperature") : Opt("Temperature"), Lees = Opt("Lees"),
                HarvestSeedRipe = g.Provenance.TryGetValue(lot.Id, out var prov) ? prov.SeedMaturity : null,
                YanStart = lot.YanStart, H2s = lot.H2sIndex, OakTerms = oakRow?["oak"]?.GetValue<string>(),
                RegionId = f.RegionId ?? g.Region.Id,
            };
        }
        return f;
    }

    /// <summary>The card for the screen: full while any of its Causes is not yet Known, brief (the chains and the site line)
    /// once all are.</summary>
    public static JsonObject? Card(GameData data, string id, JsonObject context, JsonObject record, GameSession? g)
    {
        var c = Find(data, id);
        if (c == null) return null;
        var states = StudyRecord.States(record);
        bool known = c.Causes.Length > 0 && c.Causes.All(x => states.TryGetValue(x, out var s) && s.Known);
        JsonArray Arr(IEnumerable<string> xs) => new(xs.Select(x => (JsonNode)JsonValue.Create(x)!).ToArray());
        return new JsonObject
        {
            ["id"] = c.Id, ["title"] = c.Title, ["depth"] = known ? "brief" : "full", ["what"] = c.What,
            ["chains"] = new JsonArray(c.Chains.Select(ch => (JsonNode)new JsonObject
            {
                ["title"] = ch.Cause != null ? CauseCatalog.Find(data, ch.Cause)?.Title : null, ["steps"] = Arr(Steps(data, ch)),
            }).ToArray()),
            ["choose"] = c.Choose, ["site"] = SiteLine(c.Id, Facts(data, context, g)), ["exam"] = c.Exam,
            ["check"] = new JsonObject { ["question"] = c.Check.Question, ["options"] = Arr(c.Check.Options), ["answer"] = c.Check.Answer, ["why"] = c.Check.Why },
            ["sources"] = Arr(c.Sources), ["visual"] = c.Visual, ["causes"] = Arr(c.Causes), ["simplification"] = c.Simplification,
            ["visualData"] = VisualData(data, c.Visual, context, g),
        };
    }

    private static JsonArray? _oak;
    private static readonly object OakLock = new();

    /// <summary>What the simulation's own oak model gives: one Côte d'Or Chardonnay (2018, Block D) aged in each vessel, with the
    /// oak aromas and the tannin its Tasting sheet then shows. Computed once (about a second; the bridge warms it up).</summary>
    public static JsonArray OakTable(GameData data)
    {
        lock (OakLock)
        {
            if (_oak != null) return (JsonArray)_oak.DeepClone();
            var rows = new JsonArray();
            var names = CellarOptions.Get("Vessel").Options;
            for (int i = 0; i < names.Length; i++)
            {
                var spec = new Tasting.Practice.PourSpec("cotedor-village", 2018, "D", "Chardonnay", "old-oak",
                    Choices: new Dictionary<string, int> { ["Vessel"] = i, ["Toast"] = 0, ["Ageing"] = 0 });
                var p = Tasting.Practice.TastingLab.Pour(data, spec, 1);
                var oak = p.Sheet.Aromas.FirstOrDefault(a => a.Family == "oak");
                rows.Add(new JsonObject { ["vessel"] = names[i], ["oak"] = oak?.Terms ?? "", ["intensity"] = oak?.Intensity ?? "" });
            }
            _oak = rows;
            return (JsonArray)rows.DeepClone();
        }
    }

    /// <summary>Numbers a card's visual draws from the game's own data (rootstock traits, a Block's ripening samples, a Lot's
    /// acids); null where the visual is schematic.</summary>
    private static JsonNode? VisualData(GameData data, string visual, JsonObject context, GameSession? g)
    {
        string? S(string k) => context[k] is JsonValue v && v.TryGetValue<string>(out var s) && s != "" ? s : null;
        var f = Facts(data, context, g);
        switch (visual)
        {
            case "rootstock-roots":
                return new JsonObject
                {
                    ["rows"] = new JsonArray(Rootstock.All.Where(r => r.Id != RootstockId.OwnRooted).Select(r => (JsonNode)new JsonObject
                    {
                        ["name"] = r.Name, ["depth"] = r.RootDepthFactor, ["vigour"] = r.VigourFactor, ["lime"] = r.MaxChlorosisIndex, ["drought"] = r.DroughtShiftMPa,
                    }).ToArray()),
                    ["blockIndex"] = f.ActiveLime is double lime ? Math.Round(lime * 4) : null,
                };
            case "ripening-curves":
            {
                var o = new JsonObject { ["region"] = f.RegionId };
                if (f.RegionId == "mosel")
                {
                    bool otherWhite = f.Red == false && f.BlockVariety != null && f.BlockVariety != "Riesling";
                    o["lines"] = new JsonArray(new (string, int)[] { ("Kabinett", 73), ("Spätlese", otherWhite ? 85 : 80), ("Auslese", otherWhite ? 93 : 88) }
                        .Select(x => (JsonNode)new JsonObject { ["name"] = x.Item1, ["oe"] = x.Item2 }).ToArray());
                }
                if (g != null && S("block") is string bid && g.Blocks.FirstOrDefault(b => b.Data.Id == bid) is { Samples.Count: > 1 } bs)
                    o["samples"] = new JsonArray(bs.Samples.Select(x => (JsonNode)new JsonObject
                    {
                        ["date"] = x.Date.ToString("d MMM", Ci), ["oe"] = Math.Round(x.Oe), ["ta"] = Math.Round(x.TaGL, 1), ["seed"] = Math.Round(x.SeedMaturity, 2),
                    }).ToArray());
                return o;
            }
            case "berry-temperature":
            {
                // the game's sunburn model (VineyardModel, canopy-and-yield.md §2.5) on a clear, calm 41 °C heatwave day with a typical canopy:
                // berry surface ≈ Tmax + 12 × afternoon exposure; exposure 0.42 (medium canopy Programme) plus the side's bonus; morning and none bare the
                // afternoon side only half. Burn starts at 46 °C for shade-grown berries, 48.5 °C once acclimatised (early removal).
                var sides = new (string Name, double Bonus, bool Afternoon)[] { ("None", 0, false), ("Morning", 0.10, false), ("Afternoon", 0.15, true), ("Both", 0.25, true) };
                return new JsonObject
                {
                    ["tmax"] = 41, ["shade"] = 46, ["acclimatised"] = 48.5,
                    ["rows"] = new JsonArray(sides.Select(x => { double e = 0.42 + x.Bonus; double t = 41 + 12 * (x.Afternoon ? e : e * 0.5);
                        return (JsonNode)new JsonObject { ["side"] = x.Name, ["berry"] = Math.Round(t, 1) }; }).ToArray()),
                };
            }
            case "ripening-capacity":
                return new JsonObject { ["lafr"] = f.Lafr is double l ? Math.Round(l, 2) : null };
            case "oak-aromas": return OakTable(data);
            case "malic-to-lactic" when f.Malic is double ml:
                return new JsonObject { ["malic"] = Math.Round(ml, 1), ["ph"] = Math.Round(f.Ph ?? 0, 2), ["ta"] = Math.Round(f.Ta ?? 0, 1),
                    ["taAfter"] = f.TaAfterMlf is double t2 ? Math.Round(t2, 1) : null, ["phAfter"] = f.PhAfterMlf is double p2 ? Math.Round(p2, 2) : null };
            default: return null;
        }
    }
}
