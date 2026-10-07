using TerroirEngine.Data;
using TerroirEngine.Util;
using TerroirEngine.Vineyard;
using TerroirEngine.Winery;

namespace TerroirEngine.Game;

public sealed partial class GameSession
{
    /// <summary>What a staff member can see ahead (spec §5.4): horizon and forecast skill by Staff level.</summary>
    public (int Horizon, double Skill) ForecastSkill(StaffLevel l) => l switch { StaffLevel.Senior => (14, 0.7), StaffLevel.Junior => (7, 1.3), _ => (10, 1.0) };

    /// <summary>Forecast for the days after <paramref name="issued"/> (default: for the next unsimulated day onwards).</summary>
    public List<Weather.Forecaster.ForecastDay> CurrentForecast(StaffLevel? level = null, DateOnly? issued = null)
    {
        var (h, s) = ForecastSkill(level ?? VineyardManager);
        var adj = Blocks.Count > 0 ? Blocks[0].Climate : null;
        return Forecaster.Issue(issued ?? Date.AddDays(-1), h, s, adj == null ? null : adj.Adjust);
    }

    /// <summary>Region-specific first harvest-window threshold (sugar g/L) — the lowest quality category worth waiting for.</summary>
    public double HarvestWindowSugar(BlockState b) => Region.Id switch
    {
        "mosel" => Units.SugarFromOe(b.Variety.Id == VarietyId.Chardonnay ? 76 : 73),
        "cote-dor" => 10.5 * 16.83,
        _ => Units.SugarFromBrix(b.Variety.Red ? 23.5 : 22),
    };

    public List<(string Name, double Oe)> StyleTargets(BlockState b) => Region.Id switch
    {
        "mosel" => b.Variety.Id == VarietyId.Chardonnay
            ? new() { ("Qualitätswein", 55), ("Kabinett", 73), ("Spätlese", 85), ("Auslese", 93) }
            : new() { ("Qualitätswein", 55), ("Kabinett", 73), ("Spätlese", 80), ("Auslese", 88), ("Beerenauslese", 110) },
        "cote-dor" => new() { ("Bourgogne min. (10–10.5 %)", Units.OeFromSugar(10.3 * 16.83)), ("Village min. (10.5 %)", Units.OeFromSugar(10.5 * 16.83)), ("Premier Cru min. (11 %)", Units.OeFromSugar(11 * 16.83)), ("Ripe (13 %)", Units.OeFromSugar(13 * 16.83)) },
        _ => new() { ("23 °Brix", Units.OeFromBrix(23)), ("25 °Brix", Units.OeFromBrix(25)), ("27 °Brix", Units.OeFromBrix(27)) },
    };

    private void HandleEvents()
    {
        var events = Ctx.Events.ToList();
        Ctx.Events.Clear();
        foreach (var grp in events.GroupBy(e => e.Kind))
        {
            var list = grp.ToList();
            var e = list[0];
            string blocks = string.Join(", ", list.Select(x => x.BlockId).Distinct());
            switch (e.Kind)
            {
                case "budburst":
                    if (Gate($"budburst-{Date.Year}")) Post(SeasonalRole, "Budburst — the season has started", $"The first buds have burst in Block {blocks}. From now until the shoots are ~15 cm long, a radiation frost below about −2 °C can kill the young shoots. {FrostAdvice()}",
                        SeasonalWhy("Critical temperatures rise from about −2.2 °C at budburst to about −1 °C at four leaves (UMD Extension; Gardea 1987)."), "high", "budburst", stop: true);
                    break;
                case "frost":
                    var worst = list.MaxBy(x => x.Value)!;
                    Post("vineyard", $"Frost damage in Block {string.Join(", ", list.Select(x => x.BlockId))}", Detail(VineyardManager, $"Frost last night damaged young shoots.", worst.Text + (Ctx.Frost == Tier.Low ? " We had no frost protection running." : "")),
                        "Secondary buds push after frost, but they carry less fruit (≈30–50 %) and ripen later.", "high", "frost", stop: true, blockId: worst.BlockId);
                    break;
                case "flowering":
                    if (Gate($"flowering-{Date.Year}")) Post(SeasonalRole, "Flowering", e.Text + " Rain and cold now mean a small, uneven crop. There's nothing to spray against the weather — but it tells you what to expect at harvest.",
                        SeasonalWhy("Fruit set is best at ≥ 15–17 °C and dry weather" + (Blocks.Any(b => b.Variety.Id == VarietyId.Chardonnay) ? "; Chardonnay is prone to millerandage." : Blocks.Any(b => b.Variety.Id == VarietyId.PinotNoir) ? "; Pinot Noir is moderately prone to coulure and millerandage." : ".")), "normal", "flowering", stop: true);
                    break;
                case "fruitset":
                    // one report for all Blocks; set and crop numbers are observations, so every Staff level reports them
                    Post("vineyard", $"Fruit set finished in Block {blocks}", string.Join("\n", list.Select(x => "• " + x.Text)), "Coulure and millerandage follow cold, wet flowering weather.",
                        list.Any(x => x.Severity >= 2) ? "high" : "normal", "fruitset", stop: false);
                    break;
                case "veraison":
                    if (Gate($"veraison-{Date.Year}")) Post(SeasonalRole, "Véraison: ripening has begun", $"Véraison in {blocks}. From now on your Vineyard manager takes weekly berry samples. Watch three things: sugar (°Oe), acidity (malic acid falls fast in warm weather) and {(Blocks.Any(b => b.Variety.Red) ? "the seeds — they must turn brown before the tannins taste ripe" : "flavour")}. Grey rot risk rises as sugar rises.",
                        SeasonalWhy("Technological ripeness (sugar, acid) and phenolic ripeness (seeds, skins, tannin) don't arrive together — the harvest date is a trade-off."), "high", "veraison", stop: true).Actions.Add(("Open Ripeness", "goto", "ripeness"));
                    break;
                case "downy-primary":
                    if (Gate($"downy-primary-{Date.Year}"))
                    {
                        var m = Post("vineyard", "3-10 rule met: downy mildew season has started", Detail(VineyardManager, "Downy mildew risk is rising.", e.Text + $" We're on the {Ctx.Spray} spray programme ({(Ctx.Spray == Tier.Low ? "every ~17 days, skipped in rain" : Ctx.Spray == Tier.High ? "every ~8 days plus extra after rain" : "every ~12 days")})."),
                            "Primary infection needs ≥ 10 °C, ≥ 10 mm rain and shoots ≥ 10 cm (Gessler et al. 2011). Protective sprays must be on the leaves before the next rain.", "high", "downy", stop: true);
                        m.Actions.Add(("Spray today (extra pass)", "spraynow", ""));
                        m.Actions.Add(("Open Programmes", "goto", "programmes"));
                    }
                    break;
                case "downy-symptoms":
                case "powdery":
                case "botrytis":
                case "sunburn":
                    foreach (var x in list.GroupBy(x => x.BlockId).Select(g => g.First()))
                    {
                        string key = $"{e.Kind}-{x.BlockId}-{(e.Kind == "botrytis" ? Date.DayNumber / 7 : Date.DayNumber / 14)}";
                        if (!Gate(key)) continue;
                        var dm = Post("vineyard", e.Kind switch { "downy-symptoms" => $"Downy mildew visible in Block {x.BlockId}", "powdery" => $"Powdery mildew on bunches, Block {x.BlockId}", "botrytis" => $"Grey rot spreading, Block {x.BlockId}", _ => $"Sunburn in Block {x.BlockId}" },
                            Detail(VineyardManager, x.Text.Split(':')[0] + ".", x.Text), e.Kind switch
                            {
                                "botrytis" => "Botrytis infects when berries stay wet for hours at 15–25 °C; compact bunches, split berries and dense canopies make it worse (Broome et al. 1995).",
                                "sunburn" => "Shade-grown berries burn at ≈ 46–47 °C surface temperature; leaf removal on the afternoon side before a heatwave is the classic mistake.",
                                "powdery" => "Powdery mildew needs warm, dry-ish weather rather than rain; berries are only susceptible until ~4 weeks after flowering.",
                                _ => "Visible lesions sporulate on humid nights and spread the disease in the next rain.",
                            }, x.Severity >= 3 ? "high" : "normal", e.Kind, stop: x.Severity >= 3 || e.Kind == "botrytis", blockId: x.BlockId);
                        if (e.Kind != "sunburn") dm.Actions.Add(("Spray today (extra pass)", "spraynow", ""));
                    }
                    break;
                case "leaffall":
                    foreach (var x in list) if (Blocks.First(b => b.Data.Id == x.BlockId) is var bb && !bb.Harvested)
                            Post("vineyard", $"Leaf fall in Block {x.BlockId} — fruit still hanging", x.Text + " Pick soon: the grapes now only dehydrate and rot.", "Without leaves there is no more sugar loading; only water loss concentrates the berries.", "high", "leaffall", stop: true, blockId: x.BlockId);
                    break;
                case "ferment-start":
                    foreach (var x in list) Post("cellar", $"Fermentation started: Lot {LotOf(x)}", x.Text, "", "low", e.Kind, stop: false, blockId: x.BlockId);
                    break;
                case "ferment-stuck":
                case "ferment-hot":
                case "ferment-h2s":
                    foreach (var x in list)
                    {
                        var m = Post("cellar", e.Kind == "ferment-stuck" ? $"STUCK fermentation: Lot {LotOf(x)}" : e.Kind == "ferment-hot" ? $"Fermentation overheating: Lot {LotOf(x)}" : $"Reduction (H₂S): Lot {LotOf(x)}",
                            Detail(CellarMaster, "There is a problem in the cellar.", x.Text), e.Kind switch
                            {
                                "ferment-stuck" => "Stuck fermentations follow low yeast-available nitrogen (< 140 mg/L), very high sugar, overheating (> 32 °C) or rot; restarting needs a robust yeast and nutrients.",
                                "ferment-hot" => "Fermentation releases ~1.3 °C per °Brix; without enough cooling a tank runs away above 32 °C where yeast die.",
                                _ => "Yeast short of nitrogen make hydrogen sulfide; early aeration or copper fixes it, but neglected it becomes a lasting fault.",
                            }, "high", e.Kind, stop: true, blockId: x.BlockId);
                        if (e.Kind == "ferment-stuck") { m.Actions.Add(("Restart fermentation", "restart", LotOf(x))); m.Actions.Add(("Stop here, keep the sugar", "acceptstuck", LotOf(x))); }
                        m.Actions.Add(("Open Winery", "goto", "winery"));
                    }
                    break;
                case "ferment-done":
                case "ferment-stopped":
                case "mlf-done":
                    foreach (var x in list) Post("cellar", e.Kind == "mlf-done" ? $"MLF finished: Lot {LotOf(x)}" : $"Fermentation finished: Lot {LotOf(x)}", x.Text, "", "normal", e.Kind, stop: false, blockId: x.BlockId);
                    break;
                case "lot-ready":
                    foreach (var x in list)
                    {
                        var m = Post("cellar", $"Lot {LotOf(x)} is ready to bottle", x.Text + " Decide whether to bottle it on its own or blend it with other Lots (up to 3 Wines).", "Blending Lots from different Blocks can balance acidity, body and flavour; keeping a special Block separate can earn a higher category.", "high", e.Kind, stop: true, blockId: x.BlockId);
                        m.Actions.Add(("Open Blending", "goto", "blending"));
                    }
                    break;
            }
        }
    }

    private string LotOf(VineEvent e) => e.LotId != "" ? e.LotId : Blocks.FirstOrDefault(b => b.Data.Id == e.BlockId)?.LotId ?? e.BlockId;
    private bool Gate(string key) => _gates.Add(key);
    /// <summary>Who sends the seasonal advice: the Mentor in the first Vintage, then your own Vineyard manager (multi-vintage design §7).</summary>
    private string SeasonalRole => MentorRetired ? "vineyard" : "mentor";
    /// <summary>Advice is correct at every Staff level; a Junior gives it without the explanation (spec §5.4).</summary>
    private string SeasonalWhy(string why) => MentorRetired && VineyardManager == StaffLevel.Junior ? "" : why;

    /// <summary>Junior staff report briefly; Experienced add the numbers; Senior add numbers, a recommendation and their reasoning.</summary>
    private static string Detail(StaffLevel level, string brief, string full) => level switch
    {
        StaffLevel.Junior => brief,
        _ => full,
    };

    /// <summary>What frost protection we have (the Shop's frost equipment) and whether it is on.</summary>
    public string FrostKit() => OwnsEquipment("sprinklers") && ShopUnavailable("sprinklers") == "" ? "overhead sprinklers"
        : OwnsEquipment("wind-machine") && ShopUnavailable("wind-machine") == "" ? "a wind machine, with candles for the hardest nights" : "frost candles";

    /// <summary>Better frost equipment the Shop can still sell for this Plot.</summary>
    public bool FrostUpgradeForSale => !LegacyShop && !OwnsEquipment("sprinklers") && new[] { "wind-machine", "sprinklers" }.Any(id => !OwnsEquipment(id) && ShopUnavailable(id) == "");

    private string FrostAdvice() => Ctx.Frost == Tier.Low
        ? $"We have no frost protection running. Our kit: {FrostKit()}. If the forecast shows a clear, calm night near freezing, switch the frost Programme on" +
          (OwnsEquipment("wind-machine") || OwnsEquipment("sprinklers") ? "." : $" (candles: about €{EconomyTables.CandlesPerHaNight:N0} per ha per night{(FrostUpgradeForSale ? "; the Shop sells equipment that is cheaper to run" : "")}).")
        : $"Frost protection is on, with {FrostKit()}. " + (OwnsEquipment("sprinklers") && ShopUnavailable("sprinklers") == ""
            ? "They hold the buds near 0 °C down to about −6 °C, on clear or windy nights."
            : "It helps only on clear, calm nights, when the cold air settles under warmer air.");

    private void Advisor()
    {
        if (Phase != GamePhase.Running) return;
        if (!Blocks.Any(b => b.Budburst != null && !b.Harvested)) return;   // nothing growing: no vineyard advice (saves a forecast per winter day)
        var fc = CurrentForecast(issued: Date);
        var (horizon, _) = ForecastSkill(VineyardManager);
        bool afterBudburst = Blocks.Any(b => b.Budburst != null && b.Flowering == null);
        // frost warning (spring)
        if (afterBudburst)
        {
            var cold = fc.Take(3).Where(f => f.Tmin <= -0.5).OrderBy(f => f.Tmin).FirstOrDefault();
            if (cold != null && Gate($"frostwarn-{cold.Date.DayNumber}"))
            {
                var m = Post("vineyard", $"Frost warning for {Dates.Short(cold.Date)}",
                    VineyardManager == StaffLevel.Junior ? $"It might freeze on {Dates.Short(cold.Date)}." :
                    $"Forecast minimum {cold.Tmin:0.0} °C (±{cold.TminSpread:0.0}) on {Dates.Short(cold.Date)} — the buds are out. {FrostAdvice()}" +
                    (VineyardManager == StaffLevel.Senior ? $" The frost-pocket Blocks ({string.Join(", ", Blocks.Where(b => b.Data.Microclimate.FrostPocket > 0.5).Select(b => b.Data.Id).DefaultIfEmpty("none"))}) run 2–4 °C colder than the forecast on clear, calm nights." : ""),
                    "Radiation frosts form on clear, calm nights when cold air drains into hollows and valley floors.", "high", "frost-warning", stop: true);
                if (Ctx.Frost == Tier.Low) m.Actions.Add(("Switch frost protection on", "programme", "frost:Medium"));
                if (FrostUpgradeForSale) m.Actions.Add(("Frost equipment in the Shop", "goto", "shop-equipment"));
            }
        }
        // heatwave warning (sunburn)
        if (Blocks.Any(b => b.FruitSet != null && !b.Harvested))
        {
            var hot = fc.Take(5).FirstOrDefault(f => f.Tmax >= 34);
            if (hot != null && Gate($"heat-{hot.Date.DayNumber / 10}"))
                Post("vineyard", $"Heatwave coming: {hot.Tmax:0} °C forecast on {Dates.Short(hot.Date)}", Detail(VineyardManager, "A hot spell is coming.", $"Up to {hot.Tmax:0} °C. Exposed bunches on the afternoon side can pass 46 °C at the berry surface and burn. {(Blocks.Any(b => b.LeafSide is LeafRemovalSide.Afternoon or LeafRemovalSide.Both) ? "Some Blocks have afternoon-side leaf removal — consider switching to the morning side." : "Our leaf removal is on the morning side, which is the safe choice.")}"),
                    "Sunburn needs direct exposure plus high berry temperature; berries acclimated by early leaf removal tolerate more.", "normal", "heat", stop: false);
        }
        // crop estimate vs legal yield limits, once per Block at véraison (the green-harvest decision)
        foreach (var b in Blocks.Where(b => b.Veraison != null && !b.Harvested && b.CropThinning == 0))
        {
            double maxHl = Region.Id switch
            {
                "mosel" => 125,
                "cote-dor" => Plot.Id switch { "cotedor-premiercru" => 56, "cotedor-village" => 58, _ => b.Variety.Red ? 58 : 66 },
                _ => 999,
            };
            double estHl = b.YieldKgHa * (b.Variety.Red ? 0.72 : 0.62) / 100.0;
            if (estHl > maxHl * 0.97 && Gate($"yield-{b.Data.Id}-{Date.Year}"))
            {
                var m = Post(Region.Id == "cote-dor" ? SeasonalRole : "vineyard", $"Block {b.Data.Id}: crop estimate {estHl:0} hL/ha — over the {maxHl:0} hL/ha limit",
                    $"The bunches have been counted. Block {b.Data.Id} carries about {b.YieldKgHa / 1000:0.0} t/ha, which is roughly {estHl:0} hL/ha of wine. The {(Region.Id == "cote-dor" ? Plot.Classification : "Mosel PDO")} limit is {maxHl:0} hL/ha: above it, the wine is declassified. A green harvest now (cutting off bunches at véraison) brings the crop down and helps the rest ripen.",
                    "Green harvesting lowers yield and raises the leaf-area-to-fruit ratio; the remaining bunches ripen faster and more completely (Kliewer & Dokoozlian 2005).", "high", "yield", stop: true, blockId: b.Data.Id);
                m.Actions.Add(("Light green harvest (−20 %)", "block", $"{b.Data.Id}:thinning:1"));
                m.Actions.Add(("Heavy green harvest (−40 %)", "block", $"{b.Data.Id}:thinning:2"));
            }
        }
        // harvest window & lab reports
        foreach (var b in Blocks.Where(b => b.Veraison != null && !b.Harvested && !b.Picking))
        {
            if (b.SugarGL >= HarvestWindowSugar(b) && Gate($"window-{b.Data.Id}-{Date.Year}"))
            {
                var must = Chemistry.MustFromBlock(b);
                var m = Post("vineyard", $"Harvest window open: Block {b.Data.Id} at {must.Oe:0} °Oe",
                    Detail(VineyardManager, $"Block {b.Data.Id} could be picked.", $"Block {b.Data.Id} ({b.Variety.Name}) has reached {must.Oe:0} °Oe / {must.Brix:0.0} °Brix, TA {must.TaGL:0.0} g/L, pH {must.Ph:0.00}{(b.Variety.Red ? $", seeds {b.SeedMaturity * 100:0} % brown" : "")}. Grey rot {b.Disease.GreyRot * 100:0} %."),
                    "Every week of hang time adds sugar (and, after the plateau, concentrates by dehydration) but burns acid and raises rot risk.", "high", "harvest-window", stop: true, blockId: b.Data.Id);
                m.Actions.Add(($"Harvest Block {b.Data.Id}", "harvest", b.Data.Id));
                m.Actions.Add(("Open Ripeness", "goto", "ripeness"));
            }
        }
        if (Date.DayOfWeek == DayOfWeek.Monday && Blocks.Any(b => b.Veraison != null && !b.Harvested))
        {
            var lines = Blocks.Where(b => b.Veraison != null && !b.Harvested).Select(b =>
            {
                var m = Chemistry.MustFromBlock(b);
                return $"• Block {b.Data.Id}: {m.Oe:0} °Oe ({m.Brix:0.0} °Bx), TA {m.TaGL:0.0}, pH {m.Ph:0.00}, malic {m.MalicGL:0.0}{(b.Variety.Red ? $", seeds {b.SeedMaturity * 100:0} %" : "")}, rot {b.Disease.GreyRot * 100:0} %";
            });
            bool inWindow = Blocks.Any(b => !b.Harvested && b.SugarGL >= HarvestWindowSugar(b));
            var rain = fc.Take(horizon).Where(f => f.RainProb >= 0.5).Sum(f => f.RainMm);
            string advice = VineyardManager == StaffLevel.Senior && inWindow
                ? (rain > 20 ? $"\n\nMy advice: {rain:0} mm of rain is likely in the next {horizon} days. The Blocks already in the window and prone to rot should be picked before it." : "\n\nMy advice: the forecast is settled — the Blocks in the window can hang for more ripeness.")
                : VineyardManager == StaffLevel.Experienced && rain > 20 ? $"\n\nRain likely ({rain:0} mm in the next {horizon} days)." : "";
            Post("vineyard", $"Weekly berry samples — {Dates.Short(Date)}", "200-berry samples, analysed today:\n" + string.Join("\n", lines) + advice,
                "In Normal mode lab values are exact and free. Weekly samples are how growers decide when to pick: sugar up, acid down, seeds browning, rot creeping in.", inWindow ? "high" : "normal", "lab", stop: inWindow).Actions.Add(("Open Ripeness", "goto", "ripeness"));
        }
        // late season: force a decision
        foreach (var b in Blocks.Where(b => !b.Harvested && !b.Picking && b.Veraison != null && Date >= new DateOnly(Date.Year, 12, 1)))
        {
            Apply(new Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Rigorous" }, record: false);
            Post(SeasonalRole, $"I had Block {b.Data.Id} picked", "It's December — anything left would rot or be eaten by birds. I sent the crew in with rigorous sorting. (Game rule: unpicked fruit is harvested on 1 December.)", SeasonalWhy("Game rule: unpicked fruit is harvested on 1 December."), "high", "forced-harvest", stop: true, blockId: b.Data.Id);
        }
    }
}
