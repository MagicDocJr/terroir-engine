using System.Text.Json;
using TerroirEngine.Data;
using TerroirEngine.Tasting;
using TerroirEngine.Util;
using TerroirEngine.Vineyard;
using TerroirEngine.Weather;
using TerroirEngine.Winery;

namespace TerroirEngine.Game;

/// <summary>Establishment is fast-forwarded at game start; after it the game runs year after year on the Timeline (ADR 0002).</summary>
public enum GamePhase { Establishment, Running }

public sealed class GameSetup
{
    public string EstateName { get; set; } = "Weingut";
    public string PlotId { get; set; } = "mosel-blauschiefer";
    public int PlantingYear { get; set; } = 2015;
    public ulong Seed { get; set; } = 2025;
    public StaffLevel VineyardManager { get; set; } = StaffLevel.Junior;
    public StaffLevel CellarMaster { get; set; } = StaffLevel.Junior;
    public Dictionary<string, PlantingChoice> Planting { get; set; } = new();
}

public sealed class Command
{
    public int Day { get; set; }
    public string Type { get; set; } = "";
    public string A { get; set; } = "";
    public string B { get; set; } = "";
    public string C { get; set; } = "";
    public string D { get; set; } = "";
    public string E { get; set; } = "";
}

public sealed class Message
{
    public int Id { get; set; }
    public DateOnly Date { get; set; }
    public string From { get; set; } = "";
    public string Sender { get; set; } = "";   // person's name, for the portrait in the Inbox
    public string Role { get; set; } = "";
    public string Subject { get; set; } = "";
    public string Body { get; set; } = "";
    public string Why { get; set; } = "";
    public string Priority { get; set; } = "normal";
    public string Kind { get; set; } = "";
    public string BlockId { get; set; } = "";
    public bool Stop { get; set; }
    public bool Read { get; set; }
    public List<(string Label, string Action, string Arg)> Actions { get; } = new();
}

public sealed class SaveFile { public GameSetup Setup { get; set; } = new(); public List<Command> Commands { get; set; } = new(); public string Date { get; set; } = ""; }

/// <summary>One game: an Estate on one Plot, from bare land through Establishment, then Vintage after Vintage on the Timeline (spec §3; multi-vintage design).</summary>
public sealed partial class GameSession
{
    public GameData Data { get; }
    public GameSetup Setup { get; }
    public PlotData Plot { get; }
    public RegionData Region => Plot.Region;
    public RegionWeather Weather { get; }
    public Forecaster Forecaster { get; }
    public List<BlockState> Blocks { get; } = new();
    public List<Lot> Lots { get; } = new();
    public Dictionary<string, Provenance> Provenance { get; } = new();
    public List<Wine> Wines { get; } = new();
    public Ledger Ledger { get; } = new();
    public List<Message> Inbox { get; } = new();
    public VineyardContext Ctx { get; } = new();
    /// <summary>The Region's primary mildew inoculum before any carry-over from last season (disease.md).</summary>
    public double BaseDownyInoculum { get; }
    public double BasePowderyInoculum { get; }
    public StaffLevel VineyardManager { get; private set; }
    public StaffLevel CellarMaster { get; private set; }
    public DateOnly Date { get; private set; }
    public GamePhase Phase { get; private set; } = GamePhase.Establishment;
    /// <summary>The first cropping Vintage (4th leaf; spec §3.1).</summary>
    public int FirstVintage => Setup.PlantingYear + 3;
    /// <summary>The current Vintage: the year whose vines are growing now (after Establishment, the calendar year).</summary>
    public int Vintage => Phase == GamePhase.Establishment ? FirstVintage : Date.Year;
    private readonly SortedSet<int> _bottledVintages = new();
    /// <summary>Vintages whose every Lot is in bottle, oldest first.</summary>
    public IReadOnlyCollection<int> BottledVintages => _bottledVintages;
    public bool IsVintageBottled(int vintage) => _bottledVintages.Contains(vintage);
    /// <summary>Wines containing any Lot of this Vintage (a cross-Vintage blend counts for each of its Vintages).</summary>
    public List<Wine> WinesOf(int vintage) => Wines.Where(w => w.Components.Any(c => Lots.FirstOrDefault(l => l.Id == c.LotId)?.Vintage == vintage)).ToList();
    /// <summary>A Block's season for <paramref name="year"/>: the live state for the current season, else the archived record.</summary>
    public SeasonRecord? Season(BlockState b, int year) => b.SeasonYear == year ? VineyardModel.Record(b) : b.Seasons.LastOrDefault(s => s.Year == year);
    public List<Command> Commands { get; } = new();
    /// <summary>UI progress flags (onboarding steps seen, screens visited). No effect on the simulation; saved via the command log.</summary>
    public HashSet<string> Flags { get; } = new();
    public List<(DateOnly Date, double Cash)> CashSeries { get; } = new();
    public List<string> EstablishmentReports { get; } = new();
    public List<(DateOnly Date, double Downy, double Powdery, double Botrytis)> RiskSeries { get; } = new();
    public string MentorName => Region.Id switch { "mosel" => "Klaus Weber", "cote-dor" => "Hélène Morot", _ => "Ray Castellanos" };
    /// <summary>Each Staff level is a different person you hire (names are fictional).</summary>
    public string StaffName(string role, StaffLevel l)
    {
        string[] names = (Region.Id, role) switch
        {
            ("mosel", "vineyard") => new[] { "Lukas Brandt", "Anja Meurer", "Heinz Schäfer" },
            ("mosel", _) => new[] { "Marie Kessler", "Tobias Hahn", "Ursula Lenz" },
            ("cote-dor", "vineyard") => new[] { "Théo Garnier", "Claire Dumont", "Jean-Marc Rivière" },
            ("cote-dor", _) => new[] { "Léa Fontaine", "Hugo Bernard", "Sylvie Moreau" },
            (_, "vineyard") => new[] { "Diego Morales", "Kate Sullivan", "Walt Henning" },
            _ => new[] { "Priya Nair", "Ben Carter", "Linda Okafor" },
        };
        return names[(int)l];
    }
    public bool MentorRetired { get; private set; }
    /// <summary>The day the first Vintage was fully bottled (the Mentor retires).</summary>
    public DateOnly? FinishedDate { get; private set; }
    public DailyWeather Today { get; private set; }
    private readonly HashSet<string> _gates = new();
    private int _msgId;
    private bool _replaying;
    private int _lotCounter;

    public GameSession(GameData data, GameSetup setup)
    {
        Data = data; Setup = setup;
        Plot = data.Plot(setup.PlotId);
        var archive = new WeatherArchive(data.DataRoot, Plot.Region.WeatherFile);
        Weather = new RegionWeather(archive, setup.Seed);
        Forecaster = new Forecaster(Weather, setup.Seed);
        VineyardManager = setup.VineyardManager; CellarMaster = setup.CellarMaster;
        foreach (var bd in Plot.Blocks)
        {
            var b = new BlockState(Plot, bd, new BlockClimate(Plot, bd, archive.GridElevationM)) { Planted = true, PlantingYear = setup.PlantingYear };
            b.Planting = setup.Planting.TryGetValue(bd.Id, out var pc) ? pc : DefaultPlanting(Plot, bd);
            Blocks.Add(b);
        }
        foreach (var b in Blocks) b.ClimNormalTmean = VineyardModel.ClimNormalTmean(b, archive);
        Ctx.IrrigationLegal = Region.Id == "napa";
        Ctx.DownyInoculum = Region.Id == "napa" ? 0.1 : Region.Id == "cote-dor" ? 0.65 : 0.7;
        Ctx.PowderyInoculum = Region.Id == "napa" ? 0.9 : 0.6;
        BaseDownyInoculum = Ctx.DownyInoculum; BasePowderyInoculum = Ctx.PowderyInoculum;
        Ctx.BotrytisInoculum = Region.Id == "napa" ? 0.4 : 0.7;
        Ctx.Irrigation = Region.Id == "napa" ? Tier.Medium : Tier.Low;
        Ctx.VineyardManager = VineyardManager;
        Date = new DateOnly(setup.PlantingYear, 1, 1);
        Today = Weather.Get(Date);
        Ledger.Post(Date, "Capital", data.StartingCapital, "Starting capital");
        Ledger.Post(Date, "Land", -Plot.Price, $"Bought {Plot.Name} ({Plot.AreaHa:0.0} ha)");
        double planting = Blocks.Sum(b => EconomyTables.PlantingCostPerHa(Plot, b.Planting.Training) * b.AreaHa);
        Ledger.Post(Date, "Planting", -planting, "Planting: vines, rootstocks, stakes/trellis, labour");
        RunEstablishment();
        // The Mentor's pruning for the first Vintage: Côte d'Or growers prune short to stay inside the AOC bud and yield limits
        // (canopy-and-yield.md §7 calibration: Côte d'Or ≈ 35–50 hL/ha).
        if (Region.Id == "cote-dor") foreach (var b in Blocks) b.BudLoad = BudLoad.Low;
    }

    public static PlantingChoice DefaultPlanting(PlotData p, BlockData b)
    {
        var v = p.Region.Id switch { "mosel" => VarietyId.Riesling, "cote-dor" => b.Soil.ClayPct > 30 ? VarietyId.PinotNoir : VarietyId.Chardonnay, _ => p.Id == "napa-carneros" ? VarietyId.PinotNoir : VarietyId.CabernetSauvignon };
        var t = Enum.Parse<TrainingSystem>(p.TrainingAllowed[0]);
        int density = p.Region.Id switch { "cote-dor" => 10000, "napa" => 3800, _ => t == TrainingSystem.Einzelpfahl ? 8000 : 5000 };
        var rs = b.Soil.ActiveLimePct > 12 ? RootstockId.Fercal : b.Soil.TawMm < 90 ? RootstockId.R1103P : RootstockId.SO4;
        return new PlantingChoice { Variety = v, Rootstock = rs, Training = t, Rows = p.SlopePct >= 30 ? RowOrientation.DownSlope : RowOrientation.NorthSouth, DensityVinesHa = density };
    }

    // ================================================================================== Establishment
    private void RunEstablishment()
    {
        Ctx.AutoManage = true;
        var saved = (Ctx.Spray, Ctx.Canopy, Ctx.Floor, Ctx.Labour);
        Ctx.Spray = Tier.Medium; Ctx.Canopy = Tier.Medium; Ctx.Floor = Tier.Medium; Ctx.Labour = Tier.Medium;
        for (int year = Setup.PlantingYear; year < FirstVintage; year++)
        {
            double survivalBefore = Blocks.Average(b => b.VineSurvival);
            int frostNights = 0; double severe = 0;
            for (var d = new DateOnly(year, 1, 1); d.Year == year; d = d.AddDays(1))
            {
                Date = d;
                var w = Weather.Get(d);
                foreach (var b in Blocks) VineyardModel.Step(b, w, Ctx, Setup.Seed);
                frostNights += Ctx.Events.Count(e => e.Kind == "frost");
                Ctx.Events.Clear();
                severe += Blocks.Average(b => b.PsiStem < -1.4 ? 1 : 0);
            }
            double survivalAfter = Blocks.Average(b => b.VineSurvival);
            int leaf = year - Setup.PlantingYear + 1;
            double cost = Blocks.Sum(b => b.AreaHa * (EconomyTables.LabourHoursPerHa(Plot) * EconomyTables.LabourRate(Region.Id) * 0.5 + EconomyTables.MaterialsPerHaYear(Region.Id) * 0.6 + EconomyTables.TaxAndDuesPerHaYear(Plot)));
            Ledger.Post(new DateOnly(year, 12, 31), "Establishment", -cost, $"Establishment year {leaf}: care of the young vines (managed by {MentorName})");
            double lost = survivalBefore - survivalAfter;
            double replant = lost * Blocks.Sum(b => b.Planting.DensityVinesHa * b.AreaHa) * 3.5;
            if (lost > 0.005)
            {
                Ledger.Post(new DateOnly(year, 12, 31), "Establishment", -replant, $"Replanting {lost * 100:0} % of vines lost to drought");
                foreach (var b in Blocks) b.VineSurvival = Math.Min(1, b.VineSurvival + lost * 0.9);
            }
            var bA = Blocks[0];
            string report = $"{year} — leaf {leaf}. Season heat {bA.Winkler:0} degree-days (Winkler), rain {bA.RainSeason:0} mm. " +
                (leaf == 1 ? "The young vines put down roots; I kept the soil clear so they don't compete for water. " : leaf == 2 ? "We trained the first shoots onto the " + (bA.Planting.Training == TrainingSystem.Einzelpfahl ? "stakes" : "wires") + " and removed all flowers so the vines build roots, not fruit. " : "Third leaf: a small first crop set, but I dropped it so the vines stay balanced for next year. ") +
                (severe > 20 ? $"A dry summer: {severe:0} days of severe water stress. " : "") +
                (lost > 0.005 ? $"Drought killed {lost * 100:0} % of the young vines; we replanted them (€{replant:N0}). " : "") +
                (frostNights > 0 ? $"{frostNights} spring frost night(s) touched the young shoots. " : "");
            EstablishmentReports.Add(report);
        }
        (Ctx.Spray, Ctx.Canopy, Ctx.Floor, Ctx.Labour) = saved;
        Ctx.AutoManage = false;
        Phase = GamePhase.Running;
        Date = new DateOnly(FirstVintage, 1, 15);
        // simulate 1–14 Jan quietly so the new season has begun
        for (var d = new DateOnly(FirstVintage, 1, 1); d < Date; d = d.AddDays(1)) foreach (var b in Blocks) VineyardModel.Step(b, Weather.Get(d), Ctx, Setup.Seed);
        Ctx.Events.Clear();
        Today = Weather.Get(Date);
        IntroMessages();
    }

    private void IntroMessages()
    {
        string est = string.Join("\n\n", EstablishmentReports);
        Post("mentor", "Welcome — three years of Establishment are behind us", $"Your vines are now in their fourth leaf. Here is what happened while they grew:\n\n{est}\n\nThis year is the first real vintage. I will guide you through it — every decision, and why it matters — until the wine is in bottle. Then I retire, and the Estate is yours.",
            "Young vines crop lightly and give less concentrated fruit; the 4th leaf is the first near-full crop (flagged 'young vines').", "high", "intro", stop: false);
        var pr = Post("mentor", "Winter pruning: choose the bud load for each Block",
            $"January is pruning time. The number of buds you leave per vine sets this year's crop — and how well it ripens.\n\n• Low bud load: fewer, better-ripened grapes (≈6 buds/m²).\n• Balanced: the usual compromise (≈8 buds/m²).\n• High: a big crop that ripens slowly and may taste diluted (≈11 buds/m²).\n\n{(Region.Id == "cote-dor" ? "Remember: Village and Premier Cru rules allow at most 8 buds per vine." : Region.Id == "mosel" ? "Steep Einzelpfahl vines carry two bows; the buds are shared between them." : "On the valley floor vigour is high: too few buds and the canopy runs wild.")}",
            "Bud load balances yield against ripening capacity: over ~1 kg of fruit per m² of leaf area ripens poorly (Kliewer & Dokoozlian 2005).", "high", "pruning", stop: true);
        pr.Actions.Add(("Open Plot & Blocks", "goto", "plot"));
        Post("mentor", "Set your Programmes for the season", "Your Vineyard manager runs the spray, canopy, floor, frost-protection and labour Programmes every day at the tier you choose. Low saves money but lets problems through; High costs more. You can change them any time.",
            "Tiers bundle many real operations; the costs follow the economy study for this Region.", "normal", "programmes", stop: false).Actions.Add(("Open Programmes", "goto", "programmes"));
    }

    private static string Ordinal(int n) => n + (n % 100 is 11 or 12 or 13 ? "th" : (n % 10) switch { 1 => "st", 2 => "nd", 3 => "rd", _ => "th" });

    /// <summary>15 January of every later Vintage: what the vines carry into the year, then the pruning decision (multi-vintage design §3.5).</summary>
    private void NewSeasonMessage()
    {
        int year = Date.Year, leaf = Blocks[0].Leaf(year);
        double fruit = Blocks.Average(b => b.Fruitfulness), res = Blocks.Average(b => b.Reserves);
        string fruitText = fruit >= 1.05 ? $"about {(fruit - 1) * 100:0} % more bunches per shoot than normal: last year's flowering was warm and bright"
            : fruit <= 0.95 ? $"about {(1 - fruit) * 100:0} % fewer bunches per shoot than normal: last year's flowering was cool or the canopy shaded the buds"
            : "a normal number of bunches per shoot";
        string resText = res < 0.85 ? "The vines went into winter tired: last year's crop was big for the leaf area, the fruit hung late, or the leaves were lost early. Expect weaker shoots and a poorer fruit set unless you go easy on them this year."
            : res < 0.97 ? "The vines are a little short of stored reserves after last year; shoot growth and fruit set may be slightly down."
            : res > 1.02 ? "The vines stored plenty of reserves after a moderate crop: they should push strongly this spring."
            : "The vines have normal stored reserves.";
        string disease = Ctx.DownyInoculum > BaseDownyInoculum * 1.1 ? " Last year's downy mildew left more overwintering spores in the leaf litter and soil: expect earlier, stronger pressure this spring." : "";
        string senior = VineyardManager == StaffLevel.Senior && res < 0.9 ? "\n\nMy recommendation: prune one step lower than last year (fewer buds) to let the vines recover." : "";
        var m = Post("vineyard", $"Vintage {year} begins: the vines are in their {Ordinal(leaf)} leaf",
            $"A new Vintage starts. Your vines are in their {Ordinal(leaf)} leaf.{(leaf == 5 ? " From this year they carry a full crop." : "")}\n\nWe cut open a sample of buds: they show {fruitText}. Fruit set in June still decides the final crop.\n\n{resText}{disease}\n\nNow choose the bud load for each Block for this year's pruning.{senior}",
            SeasonalWhy("Next year's bunches form inside the buds around this year's flowering, so warm, bright flowering weather means more bunches next year (Buttrose 1969). Stored starch feeds the spring flush; a heavy crop, a late harvest or early leaf loss runs it down (Bennett et al. 2005). Once vines are mature, age alone does not make better wine: well-kept old and young vines in the same vineyard gave the same yield and grape composition (Grigg et al. 2018)."),
            "high", "newseason", stop: true);
        m.Actions.Add(("Open Plot & Blocks", "goto", "plot"));
    }

    // ================================================================================== commands
    public void Apply(Command c, bool record = true)
    {
        c.Day = Date.DayNumber;
        ApplyInternal(c);
        if (record && !_replaying) Commands.Add(c);
    }

    private void ApplyInternal(Command c)
    {
        switch (c.Type)
        {
            case "programme":
                var tier = Enum.Parse<Tier>(c.B);
                switch (c.A)
                {
                    case "spray": Ctx.Spray = tier; break;
                    case "canopy": Ctx.Canopy = tier; break;
                    case "floor": Ctx.Floor = tier; break;
                    case "irrigation": if (Ctx.IrrigationLegal) Ctx.Irrigation = tier; break;
                    case "frost": Ctx.Frost = tier; break;
                    case "labour": Ctx.Labour = tier; break;
                }
                break;
            case "block":
                var b = Blocks.First(x => x.Data.Id == c.A);
                if (c.B == "budload") b.BudLoad = Enum.Parse<BudLoad>(c.C);
                else if (c.B == "leafside") b.LeafSide = Enum.Parse<LeafRemovalSide>(c.C);
                else if (c.B == "leaftiming") b.LeafTiming = Enum.Parse<LeafRemovalTiming>(c.C);
                else if (c.B == "thinning") { b.CropThinning = Math.Clamp(int.Parse(c.C), 0, 2); if (b.Veraison != null && !b.Harvested) VineyardModel.ApplyCropThinning(b); }
                break;
            case "harvest":
                var hb = Blocks.First(x => x.Data.Id == c.A);
                if (hb.Harvested || hb.Picking || hb.Veraison == null) break;
                hb.Order = new HarvestOrder { HandPick = c.B != "machine", Sorting = Enum.Parse<SortingLevel>(string.IsNullOrEmpty(c.C) ? "Table" : c.C) };
                if (!hb.Order.HandPick && (Plot.SlopePct >= 30 || hb.Planting.Training == TrainingSystem.Einzelpfahl)) hb.Order.HandPick = true;
                hb.Picking = true; hb.PickedKg = 0; hb.PickTargetKg = hb.CropKg;
                break;
            case "lot":
                var lot = Lots.First(x => x.Id == c.A);
                var ch = CellarOptions.Get(c.B);
                bool started = lot.Phase is not (LotPhase.Received or LotPhase.ColdSoak);
                if (ch.LockedAfterFermentStart && started) break;
                lot.Choices[c.B] = Math.Clamp(int.Parse(c.C), 0, ch.Options.Length - 1);
                break;
            case "restart":
                var sl = Lots.FirstOrDefault(x => x.Id == c.A);
                if (sl != null) WineryModel.Restart(sl, Date);
                break;
            case "flag": if (!string.IsNullOrWhiteSpace(c.A)) Flags.Add(c.A); break;
            case "unflag": Flags.Remove(c.A); break;
            case "spraynow": if (Blocks.Any(b => b.Budburst != null && !b.Harvested)) Ctx.ForceSprayToday = true; break;
            case "acceptstuck":
                var al = Lots.FirstOrDefault(x => x.Id == c.A);
                if (al != null) WineryModel.AcceptStuck(al, Date);
                break;
            case "staff":
                var lvl = Enum.Parse<StaffLevel>(c.B);
                if (c.A == "vineyard") { VineyardManager = lvl; Ctx.VineyardManager = lvl; } else CellarMaster = lvl;
                break;
            case "wine": CreateWine(c); break;
            case "read":
                // "all" marks everything read; ids may arrive as "12" or "12.0" from the UI's JSON numbers
                if (c.A == "all") foreach (var x in Inbox) x.Read = true;
                else if (double.TryParse(c.A, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var rid)) { var m = Inbox.FirstOrDefault(x => x.Id == (int)rid); if (m != null) m.Read = true; }
                break;
        }
    }

    // ================================================================================== time
    /// <summary>Advance up to <paramref name="maxDays"/> days, stopping early at the first Alert that needs attention. Returns days advanced.</summary>
    public int Advance(int maxDays, bool stopAtAlerts = true)
    {
        int n = 0;
        while (n < maxDays)
        {
            bool stop = StepDay();
            n++;
            if (stop && stopAtAlerts) break;
        }
        return n;
    }

    private bool StepDay()
    {
        int before = Inbox.Count(m => m.Stop);
        var w = Weather.Get(Date);
        Today = w;
        Ctx.LabourFactor = Ctx.Labour switch { Tier.Low => 0.85, Tier.High => 1.2, _ => 1.0 };
        Ctx.SprayPassesToday = 0; Ctx.FrostProtectionNights = 0;
        foreach (var b in Blocks) VineyardModel.Step(b, w, Ctx, Setup.Seed);
        if (Date.Month == 1 && Date.Day == 1) ApplyDiseaseCarryOver();
        if (Ctx.ForceSprayToday)
        {
            Post("vineyard", Ctx.SprayPassesToday > 0 ? "Extra spray pass done" : "Extra spray pass cancelled: raining", Ctx.SprayPassesToday > 0 ? "All Blocks were sprayed today, outside the normal schedule. The next regular pass moves back accordingly." : "Spraying in heavy rain washes the product off; the crew stayed in. Order it again for a dry day.",
                "A protective spray only works if it is on the leaves before the infection period (rain + leaf wetness).", "normal", "spray-now", stop: false);
            Ctx.ForceSprayToday = false;
        }
        HarvestProgress();
        // a Lot received today waits until tomorrow, so the player can set its cellar choices first
        foreach (var lot in Lots.Where(l => l.Phase != LotPhase.Blended && l.Harvested < Date)) WineryModel.Step(lot, Date, CellarMaster, Ctx.Events);
        DailyCosts();
        HandleEvents();
        if (Phase == GamePhase.Running && Date.Month == 1 && Date.Day == 15 && Date.Year > FirstVintage && Gate($"newseason-{Date.Year}")) NewSeasonMessage();
        Advisor();
        if (Ledger.Cash < 0 && Gate("overdrawn"))
            Post("mentor", "You are overdrawn", $"Your cash is now {Ledger.Cash:N0} €. The biggest costs so far were {string.Join(", ", Ledger.ByCategory(DateOnly.MinValue, DateOnly.MaxValue).Where(kv => kv.Value < 0).OrderBy(kv => kv.Value).Take(3).Select(kv => $"{kv.Key} {-kv.Value:N0} €"))}. The bank carries the debt, but charges {EconomyTables.OverdraftRate * 100:0} % a year interest every month until you are back in credit. Lower Programme tiers or cheaper staff reduce what you spend.",
                "Game simplification: an overdraft with a fixed rate instead of loans (backlog: full economics). The rate is a design value (UNVERIFIED).", "high", "overdrawn", stop: true).Actions.Add(("Open Estate", "goto", "estate"));
        if (Date.DayOfWeek == DayOfWeek.Monday) CashSeries.Add((Date, Ledger.Cash));
        if (Date.Month >= 4 && Date.Month <= 10)
        {
            if (Date.Month == 4 && Date.Day == 1) RiskSeries.Clear();   // the risk chart shows the current Vintage only
            RiskSeries.Add((Date, Blocks.Average(b => b.Disease.DownyRiskToday), Blocks.Average(b => b.Disease.PowderyIndex), Blocks.Average(b => b.Disease.BotrytisRiskToday)));
        }
        CheckBottledVintages();
        Date = Date.AddDays(1);
        return Inbox.Count(m => m.Stop) > before;
    }

    /// <summary>A Vintage is in bottle when its harvest is over and every one of its Lots is bottled. The first one ends the Mentor's storyline.</summary>
    private void CheckBottledVintages()
    {
        foreach (int v in Lots.Select(l => l.Vintage).Distinct().OrderBy(x => x).ToList())
        {
            if (_bottledVintages.Contains(v)) continue;
            bool harvestOver = v < Date.Year || Blocks.All(b => b.Harvested);
            if (!harvestOver || Lots.Any(l => l.Vintage == v && l.Phase != LotPhase.Blended)) continue;
            _bottledVintages.Add(v);
            var wines = WinesOf(v);
            double rev = wines.Sum(x => x.Revenue);
            string summary = $"{wines.Count} Wine(s), {wines.Sum(x => x.Bottles):N0} bottles, €{rev:N0} in sales.";
            if (v == FirstVintage)
            {
                FinishedDate = Date; MentorRetired = true;
                Post("mentor", "The wine is in bottle — and I am retiring", $"Every Lot of the {v} Vintage is now bottled. {summary}\n\nIt has been a pleasure. From now on the Estate is yours: your Vineyard manager and Cellar master will send the advice I used to give. Read your Tasting sheets and the Vintage report, then do it again — better — next year. The vines remember what you did to them.",
                    "The Mentor guides the first Vintage. The game then goes on Vintage after Vintage on the Timeline, and this year's decisions shape next year's vines.", "high", "finished", stop: true)
                    .Actions.AddRange(new[] { ("Open the Vintage report", "goto", "report"), ("Open Wines", "goto", "wines") });
            }
            else
                Post("cellar", $"The {v} Vintage is in bottle", $"The last Lot of the {v} Vintage is bottled. {summary} The Vintage report compares its weather and results with the normal.",
                    "Comparing Vintages side by side is how growers learn what the weather did and what their decisions did.", "high", "vintage-bottled", stop: true)
                    .Actions.AddRange(new[] { ("Open the Vintage report", "goto", "report"), ("Open Wines", "goto", "wines") });
        }
    }

    // ================================================================================== harvest
    private void HarvestProgress()
    {
        double crew = EconomyTables.CrewHoursPerDay(Ctx.Labour);
        foreach (var b in Blocks.Where(x => x.Picking && !x.Harvested))
        {
            // sorting slows the crew down: sorters are part of the harvest labour
            double hpk = EconomyTables.HarvestHoursPerKg(Plot, b.Order!.HandPick) + WineryModel.Sorting(b.Order.Sorting).hoursPerKg;
            double kgToday = crew / hpk;
            double remaining = Math.Max(0, b.CropKg - b.PickedKg);
            double picked = Math.Min(kgToday, remaining);
            b.PickedKg += picked;
            double hours = picked * hpk;
            Ledger.Post(Date, "Harvest", -hours * EconomyTables.LabourRate(Region.Id) - (b.Order.HandPick ? 0 : 400 * b.AreaHa), $"Harvest crew, Block {b.Data.Id}");
            if (b.PickedKg >= b.CropKg - 1 || b.CropKg < 1)
            {
                b.Harvested = true; b.Picking = false; b.HarvestDate = Date; b.Stage = Stage.Harvested;
                var lotId = $"{Vintage % 100:00}-{b.Data.Id}";
                var lot = WineryModel.FromBlock(b, lotId, Date, b.PickedKg, b.Order.Sorting);
                DefaultCellarChoices(lot, b);
                b.LotId = lotId;
                Lots.Add(lot);
                Provenance[lotId] = CaptureProvenance(b);
                Ledger.Post(Date, "Cellar", -lot.GrapeKg * 0.7 / 100 * 10, $"Cellar consumables, Lot {lotId}");
                var must = Chemistry.MustFromBlock(b);
                var msg = Post("cellar", $"Block {b.Data.Id} is in: Lot {lotId} received",
                    $"{lot.GrapeKg:N0} kg at {must.Oe:0} °Oe ({must.Brix:0.0} °Brix, potential {must.PotentialAlcohol:0.0} % vol), TA {must.TaGL:0.0} g/L, pH {must.Ph:0.00}, YAN {must.YanMgL:0} mg/L." +
                    (b.Disease.GreyRot > 0.02 ? $" Grey rot {b.Disease.GreyRot * 100:0} % — {b.Order.Sorting.ToString().ToLowerInvariant()} sorting." : "") +
                    $"\n\n{MentorsFirstRead(b, must)}" +
                    $"\n\nSet the cellar choices for this Lot now: {(lot.Red ? "destemming, cold soak, yeast, temperature, cap management" : "pressing, settling, yeast, temperature, sweetness")} are locked once fermentation starts.",
                    lot.Red ? "Red wine ferments on the skins: colour and tannin come from how long and how hard you extract." : "White juice is pressed off the skins straight away; the cellar choices shape fruit, texture and sweetness.",
                    "high", "lot-received", stop: true, blockId: b.Data.Id);
                msg.Actions.Add(("Open Winery", "goto", "winery"));
            }
        }
    }

    /// <summary>Immediate feedback on the harvest decision (design review §3): what this fruit is likely to become, from the must alone.
    /// It uses the same thresholds as the law module; the real category is only decided at bottling.</summary>
    private string MentorsFirstRead(BlockState b, MustAnalysis must)
    {
        string acid = must.TaGL >= 8.5 ? "racy, high acidity" : must.TaGL >= 6.5 ? "fresh acidity" : must.TaGL >= 5.5 ? "moderate acidity" : "soft, low acidity";
        string alc = $"about {must.PotentialAlcohol:0.0} % alcohol if fermented dry";
        string cat;
        if (Region.Id == "mosel")
        {
            bool rieslingLike = b.Variety.Id is VarietyId.Riesling or VarietyId.PinotNoir;
            double spaet = rieslingLike ? 80 : 85, ausl = rieslingLike ? 88 : 93;
            cat = must.Oe >= 110 ? (b.Disease.NobleRot >= 0.3 ? "Beerenauslese territory (and there is enough noble rot)" : "Auslese: the must weight reaches Beerenauslese, but that needs noble-rotten berries")
                : must.Oe >= ausl ? "Auslese level" : must.Oe >= spaet ? "Spätlese level" : must.Oe >= 73 ? "Kabinett level" : must.Oe >= 55 ? "Qualitätswein (below Kabinett)" : "only Landwein or Deutscher Wein";
        }
        else if (Region.Id == "cote-dor")
        {
            int level = Plot.Id switch { "cotedor-premiercru" => 3, "cotedor-village" => 2, "cotedor-hautes" => 1, _ => 0 };
            double minNat = level >= 3 ? 11.0 : level == 2 ? 10.5 : b.Variety.Red ? 10.0 : 10.5;
            cat = must.PotentialAlcohol >= minNat ? $"ripe enough for {Plot.Classification.Split('(')[0].Trim()} (natural alcohol minimum {minNat} %)" : $"below the {minNat} % natural-alcohol minimum; chaptalisation can fix it within the AOC limits";
        }
        else cat = "Napa: no must-weight categories; ripeness shows in body and alcohol";
        return $"The Mentor's first read: {cat}, {alc}, {acid}. The final category is decided when you bottle.";
    }

    /// <summary>Regional house style as the starting point for the player's cellar choices (all editable before fermentation).</summary>
    private void DefaultCellarChoices(Lot lot, BlockState b)
    {
        void Set(string k, int i) => lot.Choices[k] = i;
        if (lot.Red)
        {
            Set("MLF", 1);                                                          // inoculate: reds almost always complete MLF
            Set("Lees", 1);                                                         // reds are racked off the gross lees
            if (b.Variety.Id == VarietyId.PinotNoir) { Set("Cap management", 1); Set("Destemming", Region.Id == "cote-dor" ? 1 : 0); Set("Vessel", Region.Id == "mosel" ? 1 : 3); Set("Ageing", 2); }
            else { Set("Vessel", Region.Id == "napa" ? 4 : 2); Set("Ageing", Region.Id == "napa" ? 3 : 2); Set("Maceration", Region.Id == "napa" ? 1 : 0); }
        }
        else if (b.Variety.Id == VarietyId.Chardonnay)
        {
            Set("MLF", Region.Id == "mosel" ? 0 : 1);
            if (Region.Id != "mosel") { Set("Vessel", Region.Id == "napa" ? 4 : 3); Set("Lees", 2); Set("Ageing", 2); Set("Temperature", 2); }   // barrel-fermented Chardonnay runs warmer (18 °C)
        }
        else { Set("MLF", 0); Set("Vessel", Region.Id == "mosel" ? 0 : 0); }   // Riesling: steel, no MLF
        // Napa winemakers routinely add tartaric acid to high-pH musts (legal in California; acid-ph-so2.md)
        if (Region.Id == "napa") { double ph = Chemistry.MustFromBlock(b).Ph; if (ph > 3.8) Set("Acidification", 2); else if (ph > 3.6) Set("Acidification", 1); }
    }

    private Provenance CaptureProvenance(BlockState b)
    {
        var must = Chemistry.MustFromBlock(b);
        double hl = b.PickedKg * (b.Variety.Red ? 0.72 : 0.62) / 100.0 / Math.Max(0.01, b.AreaHa);
        return new Provenance
        {
            BlockId = b.Data.Id, BlockName = b.Data.Name, Soil = b.Data.Soil.Texture, Variety = b.Variety.Name, Rootstock = b.Rootstock.Name, Training = b.Planting.Training.ToString(),
            Vintage = Vintage, Leaf = b.Leaf(Vintage), ExposureEarly = b.ExposureEarlyDays > 0 ? b.ExposureEarlySum / b.ExposureEarlyDays : b.Exposure,
            ExposureLate = b.ExposureLateDays > 0 ? b.ExposureLateSum / b.ExposureLateDays : b.Exposure, StressPost = b.StressPostDays > 0 ? b.StressPostSum / b.StressPostDays : 0,
            YieldKgHa = b.PickedKg / Math.Max(0.01, b.AreaHa), YieldHlHa = hl, WinklerBlock = b.Winkler, SeasonTemp = VineyardModel.SeasonMeanTemp(b), BudsPerVine = b.BudsPerVine,
            DensityVinesHa = b.Planting.DensityVinesHa, LeafSide = b.LeafSide.ToString(), LeafTiming = b.LeafTiming.ToString(), CanopyTier = Ctx.Canopy.ToString(), SprayTier = Ctx.Spray.ToString(),
            BudLoad = b.BudLoad.ToString(), Sorting = b.Order?.Sorting.ToString() ?? "", Picking = b.Order?.HandPick == false ? "machine" : "hand", HarvestDate = Date, Budburst = b.Budburst,
            HarvestOe = must.Oe, HarvestTa = must.TaGL, HarvestPh = must.Ph, SeedMaturity = b.SeedMaturity, FrostLoss = b.FrostShootLoss, SunburnPct = b.SunburnFraction * 100,
            GreyRotPct = b.Disease.GreyRot * 100, NobleRotPct = b.Disease.NobleRot * 100, DownyLeafPct = b.Disease.DownyLeaf, IbmpNgL = b.Ibmp,
        };
    }

    // ================================================================================== wines
    private void CreateWine(Command c)
    {
        var parts = new List<(Lot lot, Provenance prov, double litres)>();
        foreach (var token in c.E.Split(';', StringSplitOptions.RemoveEmptyEntries))
        {
            var kv = token.Split(':');
            var lot = Lots.FirstOrDefault(l => l.Id == kv[0] && l.Phase == LotPhase.Ready);
            if (lot == null) continue;
            double litres = kv.Length > 1 && double.TryParse(kv[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var l0) ? Math.Min(l0, lot.VolumeL) : lot.VolumeL;
            parts.Add((lot, Provenance[lot.Id], litres));
        }
        if (parts.Count == 0) return;
        var wine = new Wine
        {
            Id = $"W{Wines.Count + 1}", Name = string.IsNullOrWhiteSpace(c.A) ? $"Wine {Wines.Count + 1}" : c.A,
            Closure = Enum.TryParse<Closure>(c.B, out var cl) ? cl : Closure.Screwcap,
            Filtration = Enum.TryParse<Filtration>(c.C, out var fi) ? fi : Filtration.Sterile,
            Fining = Enum.TryParse<Fining>(c.D, out var fn) ? fn : Fining.Bentonite,
        };
        foreach (var p in parts) wine.Components.Add(new Component(p.lot.Id, p.litres));
        wine.Blend = Blending.Combine(parts.Select(p => (p.lot, p.litres)), wine.Id);
        if (wine.Fining == Fining.BentoniteGelatine && wine.Blend.Red) { wine.Blend.SeedTannin *= 0.88; wine.Blend.SkinTannin *= 0.93; wine.Blend.Anthocyanin *= 0.95; }
        if (wine.Filtration == Filtration.Unfiltered) wine.Blend.LeesMonths += 0.5;
        wine.Bottled = Date;
        double litresTotal = parts.Sum(p => p.litres);
        wine.Bottles = (int)(litresTotal * 0.98 / 0.75);
        wine.Legal = Law.Evaluate(wine, parts, Plot, Date);
        var (vintageYear, vintageNote) = Law.VintageStatement(parts.Select(p => (p.lot.Vintage, p.litres)), Region.Id);
        wine.Vintage = vintageYear;
        if (vintageNote != null) wine.Legal.Notes.Add(vintageNote);
        wine.Legal = wine.Legal with { Label = vintageYear != null ? $"{vintageYear} {wine.Legal.Label}" : $"Non-vintage {wine.Legal.Label}" };
        wine.Sheet = TastingSheetGenerator.Generate(wine, parts, Date.AddMonths(3));
        wine.Sheet.Label = wine.Legal.Label; wine.Sheet.Category = wine.Legal.Category;
        wine.PricePerBottle = Math.Round(wine.Legal.BasePrice * Law.QualityMultiplier(wine.Sheet.Quality) * (wine.Vintage == FirstVintage ? 0.95 : 1), 2);
        wine.BottlingCost = wine.Bottles * EconomyTables.BottleCost(wine.Closure) + 150;
        wine.Revenue = wine.Sheet.Quality == "Faulty" ? wine.Bottles * 1.0 : wine.Bottles * wine.PricePerBottle;
        Ledger.Post(Date, "Bottling", -wine.BottlingCost, $"Bottling {wine.Name}: {wine.Bottles:N0} bottles ({wine.Closure})");
        Ledger.Post(Date, "Sales", wine.Revenue, $"{wine.Name}: {wine.Bottles:N0} × €{(wine.Sheet.Quality == "Faulty" ? 1.0 : wine.PricePerBottle):0.00} ({wine.Legal.Category}, {wine.Sheet.Quality}){(wine.Sheet.Quality == "Faulty" ? " — sold off in bulk" : "")}");
        foreach (var p in parts)
        {
            p.lot.VolumeL -= p.litres;
            if (p.lot.VolumeL < 5) { p.lot.Phase = LotPhase.Blended; p.lot.VolumeL = 0; }
        }
        Wines.Add(wine);
        Post("cellar", $"{wine.Name} is bottled: {wine.Legal.Label}", $"{wine.Bottles:N0} bottles. Legal category: {wine.Legal.Category}. Quality: {wine.Sheet.Quality}. Price €{wine.PricePerBottle:0.00} per bottle.\n{string.Join("\n", wine.Legal.Notes)}",
            "Open the Tasting sheet: every descriptor links back to the decision or condition that caused it.", "high", "bottled", stop: false).Actions.Add(("Open Wines", "goto", "wines"));
    }

    // ================================================================================== costs
    /// <summary>Wine volume the Cellar master is sized for: the Lots made, or ≈50 hL/ha before the harvest (UNVERIFIED planning figure).</summary>
    public double WineHlEstimate => Lots.Count > 0 ? Lots.Sum(l => l.GrapeKg) * 0.65 / 100.0 : Blocks.Sum(b => b.AreaHa) * 50;
    /// <summary>What a staff member costs per year on this estate: full salary × regional multiplier × part-time post (economy.md §7).</summary>
    public double StaffCostYear(string role, StaffLevel l) => EconomyTables.Salary(role, l) * EconomyTables.SalaryMultiplier(Region.Id) * EconomyTables.StaffPost(role, Plot, WineHlEstimate);

    private void DailyCosts()
    {
        double ha = Blocks.Sum(b => b.AreaHa);
        string region = Region.Id;
        bool season = Date.Month >= 3 && Date.Month <= 10;
        if (season)
        {
            double hours = EconomyTables.LabourHoursPerHa(Plot) * ha / 245.0;
            double canopyShare = 0.35 * (Ctx.Canopy switch { Tier.Low => 0.6, Tier.High => 1.6, _ => 1.0 });
            double labourMult = Ctx.Labour switch { Tier.Low => 0.85, Tier.High => 1.2, _ => 1.0 };
            Ledger.Post(Date, "Vineyard labour", -hours * (0.65 + canopyShare) * labourMult * EconomyTables.LabourRate(region), "Vineyard crew (pruning, canopy, floor, maintenance)");
            double materials = EconomyTables.MaterialsPerHaYear(region) * ha / 245.0 * (Ctx.Floor switch { Tier.Low => 0.8, Tier.High => 1.2, _ => 1.0 });
            Ledger.Post(Date, "Materials", -materials, "Canopy and floor materials, repairs, fuel");
        }
        if (Ctx.SprayPassesToday > 0)
        {
            double perPass = EconomyTables.SprayCostPerHaYear(Ctx.Spray, Plot.SlopePct >= 30) / EconomyTables.TypicalPasses(region, Ctx.Spray);
            double passFraction = (double)Ctx.SprayPassesToday / Math.Max(1, Blocks.Count);
            Ledger.Post(Date, "Sprays", -perPass * ha * passFraction, "Spray pass (materials + application)");
        }
        if (Ctx.FrostProtectionNights > 0) Ledger.Post(Date, "Frost protection", -600 * ha * Math.Min(1, (double)Ctx.FrostProtectionNights / Blocks.Count) * (Ctx.Frost == Tier.High ? 1.5 : 1), "Frost protection night (candles / wind machine)");
        if (Ctx.IrrigationLegal)
        {
            double mm = Blocks.Sum(b => b.IrrigationMmSeason);
            if (Date.Month == 10 && Date.Day == 31) Ledger.Post(Date, "Irrigation", -(300 * ha + 0.8 * mm), $"Irrigation water and system ({mm / Math.Max(1, Blocks.Count):0} mm per Block)");
        }
        if (Date.Day == 1)
        {
            Ledger.Post(Date, "Staff", -(StaffCostYear("vineyard", VineyardManager) + StaffCostYear("cellar", CellarMaster)) / 12.0, $"Salaries: Vineyard manager ({VineyardManager}, {EconomyTables.StaffPost("vineyard", Plot, WineHlEstimate) * 100:0} % post), Cellar master ({CellarMaster}, {EconomyTables.StaffPost("cellar", Plot, WineHlEstimate) * 100:0} % post)");
            double interest = EconomyTables.OverdraftInterest(Ledger.Cash);
            if (interest < 0) Ledger.Post(Date, "Interest", interest, $"Overdraft interest ({EconomyTables.OverdraftRate * 100:0} % a year)");
            if (Date.Month == 1) Ledger.Post(Date, "Overheads", -EconomyTables.TaxAndDuesPerHaYear(Plot) * ha, "Property tax, insurance, dues");
            // monthly cellar running costs
            foreach (var lot in Lots.Where(l => l.Phase is not (LotPhase.Blended or LotPhase.Received)))
                Ledger.Post(Date, "Cellar", -(lot.VolumeL / 100.0 * 3 + lot.VolumeL / 1000.0 * 6 * EconomyTables.SkilledRate(region) / 10), "Cellar running costs (cooling, labour)");
        }
        // barrels bought when a Lot goes into oak
        foreach (var lot in Lots.Where(l => l.Phase == LotPhase.Ageing && l.PhaseDay == 1))
        {
            var vp = WineryModel.Vessel(lot);
            if (vp.Litres > 0)
            {
                int n = (int)Math.Ceiling(lot.VolumeL / vp.Litres);
                Ledger.Post(Date, "Barrels", -n * vp.PricePer, $"{n} × {lot.Opt("Vessel").ToLowerInvariant()} for Lot {lot.Id}");
            }
        }
    }

    /// <summary>Overwintering inoculum follows last season's mildew (disease.md): multiplier on this season's primary inoculum only.</summary>
    public static double InoculumCarry(double peakLeafPct) => M.Clamp(0.85 + 0.015 * peakLeafPct, 0.85, 1.30);

    private void ApplyDiseaseCarryOver()
    {
        var last = Blocks.Select(b => b.Seasons.LastOrDefault()).Where(s => s != null && s.Year == Date.Year - 1 && s.Leaf >= 4).Select(s => s!).ToList();
        if (last.Count == 0) return;
        Ctx.DownyInoculum = BaseDownyInoculum * InoculumCarry(last.Average(s => s.DownyLeafPeak));
        Ctx.PowderyInoculum = BasePowderyInoculum * InoculumCarry(last.Average(s => s.PowderyLeafPeak));
    }

    // ================================================================================== save / load
    public string Save() => JsonSerializer.Serialize(new SaveFile { Setup = Setup, Commands = Commands, Date = Dates.Iso(Date) }, new JsonSerializerOptions { WriteIndented = true });
    public static GameSession Load(GameData data, string json)
    {
        var sf = JsonSerializer.Deserialize<SaveFile>(json)!;
        var s = new GameSession(data, sf.Setup);
        var target = DateOnly.Parse(sf.Date, System.Globalization.CultureInfo.InvariantCulture);
        s._replaying = true;
        var queue = new Queue<Command>(sf.Commands.OrderBy(c => c.Day));
        while (s.Date < target)
        {
            while (queue.Count > 0 && queue.Peek().Day <= s.Date.DayNumber) s.ApplyInternal(queue.Dequeue());
            s.StepDay();
        }
        while (queue.Count > 0) s.ApplyInternal(queue.Dequeue());
        s._replaying = false;
        s.Commands.AddRange(sf.Commands);
        return s;
    }

    // ================================================================================== messages
    public Message Post(string role, string subject, string body, string why, string priority, string kind, bool stop, string blockId = "")
    {
        string from = role switch { "mentor" => $"{MentorName} · Mentor", "vineyard" => $"{StaffName("vineyard", VineyardManager)} · Vineyard manager ({VineyardManager})", "cellar" => $"{StaffName("cellar", CellarMaster)} · Cellar master ({CellarMaster})", "weather" => "Weather service", _ => role };
        if (role == "mentor" && MentorRetired) from = $"{MentorName} · retired Mentor";
        string sender = role switch { "mentor" => MentorName, "vineyard" => StaffName("vineyard", VineyardManager), "cellar" => StaffName("cellar", CellarMaster), _ => "" };
        var m = new Message { Id = ++_msgId, Date = Date, From = from, Sender = sender, Role = role, Subject = subject, Body = body, Why = why, Priority = priority, Kind = kind, Stop = stop, BlockId = blockId };
        Inbox.Add(m);
        return m;
    }
}
