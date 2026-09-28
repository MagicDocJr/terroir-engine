# Multi-vintage play Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After the first Vintage is bottled the game keeps running year after year on the same Estate, with vines that carry last year's decisions into the next, overlapping Vintages in the cellar, a Vintage report per year and a Vintage history.

**Architecture:** One continuous `GameSession` keeps stepping day by day; the one-shot phases `Vintage/Cellar/Finished` become `Running`, and everything year-bound is keyed by its Vintage year (Lots by harvest year, Block seasons archived as `SeasonRecord`s, gates suffixed with the year). Carry-over lives in `BlockState` (fruitfulness, reserves) and `VineyardContext` (disease inoculum), all exactly 1.0 in the first Vintage. Saves stay setup + command log.

**Tech Stack:** C# (.NET 8 core, .NET 10 xUnit tests), Godot 4.7.2 .NET with GDScript UI, bash scripts under WSL.

**Spec:** `docs/superpowers/specs/2026-09-28-multi-vintage-design.md`

## Global Constraints

- The simulation core stays headless and deterministic (ADR 0001); the Godot UI never computes outcomes. Build C# only with `scripts/build-game.sh` (WSL dotnet); run tests with `cd sim && ~/.dotnet/dotnet test`.
- All three carry-over factors are exactly 1.0 in the first Vintage; the 25 existing tests keep passing (only their loop condition changes from `GamePhase.Finished` to "first Vintage bottled").
- Save format unchanged: setup + commands + date.
- Every in-game fact is cited in `docs/science/`; design numbers are marked `UNVERIFIED`; game simplifications are labelled "Game simplification". Citations recalled rather than looked up are marked "(cited from memory)".
- Use CONTEXT.md terms exactly: say **Vintage**, never "season" or "year", in player-facing text (so the top bar reads "Vintage 2022 · 5th leaf", the January message is "Vintage 2022 begins"). Code identifiers may say `season`.
- `reference/` (WSET books) is never quoted.
- Commits end with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`. Do not push.
- Overdraft interest rate: 9 % a year, posted monthly (`UNVERIFIED`). Vintage statement: EU ≥ 85 %, Napa ≥ 95 %. No non-vintage price discount.
- Replay budget: a five-Vintage save loads in < 10 s on the owner's PC (tests assert < 30 s for CI headroom).

## Review Focus

1. **Player never harvests** (lets the December rule pick) for two Vintages running → a Lot still appears each Vintage and no message repeats daily. Pinned in Task 1 (`ForcedHarvest_EveryVintage_WithoutPlayerInput`).
2. **A Vintage's Lots are never bottled** → no report for that Vintage, but the next Vintage still runs, harvests and bottles normally. Pinned in Task 1 (`UnbottledVintage_DoesNotBlockTheNext`).
3. **Blending Lots of two Vintages through the real `wine` command** (not just the pure law function) → the wine is labelled non-vintage in Napa. Pinned in Task 5 (`CrossVintageBlend_InNapa_IsNonVintage`).
4. **Snapshot growth over many Vintages** (inbox, reports, history) → stays under 400 KB and builds in < 500 ms after five Vintages. Pinned in Task 6.
5. **Overdrawn for months** → interest posts once a month on the running negative balance, never while cash is positive. Pinned in Task 5.

---

## File structure

| File | Responsibility | Tasks |
|---|---|---|
| `sim/src/TerroirEngine.Core/Game/GameSession.cs` | continuous loop, phases, bottled Vintages, costs, carry-over hand-off, New-season message, wine Vintage | 1, 3, 4, 5 |
| `sim/src/TerroirEngine.Core/Game/GameSession.Advisor.cs` | per-year gates, seasonal sender after the Mentor retires | 1, 4 |
| `sim/src/TerroirEngine.Core/Vineyard/BlockState.cs` | `SeasonRecord`, carry-over fields | 2, 3 |
| `sim/src/TerroirEngine.Core/Vineyard/VineyardModel.cs` | season close/record, fruitfulness, reserves, climate normal | 2, 3 |
| `sim/src/TerroirEngine.Core/Winery/Winery.cs` | `Lot.Vintage` | 1 |
| `sim/src/TerroirEngine.Core/Tasting/Wine.cs` | `Wine.Vintage`, `Provenance.Budburst`, `Law.VintageStatement` | 1, 5 |
| `sim/src/TerroirEngine.Core/Game/Economy.cs` | overdraft interest | 5 |
| `sim/src/TerroirEngine.Core/Game/VintageReport.cs` | report per Vintage, history row | 2, 6 |
| `sim/src/TerroirEngine.Core/Game/Snapshot.cs` | phase/season/quiet, reports, history, years, vintage fields | 1, 2, 6 |
| `sim/src/TerroirEngine.Cli/Program.cs` | `play` over N Vintages (`TE_VINTAGES`) | 1 |
| `sim/tests/TerroirEngine.Core.Tests/CoreTests.cs` | fixture + existing tests' loop condition | 1 |
| `sim/tests/TerroirEngine.Core.Tests/MultiVintageTests.cs` (new) | all new tests | 1–6 |
| `game/src/ui/shell.gd`, `screens/{report,estate,winery,blending}.gd`, `onboarding.gd` | UI | 7 |
| `docs/science/{canopy-and-yield,disease,law,economy}.md`, `CONTEXT.md`, spec | science and glossary | 3, 5 |
| `docs/playtest/2026-09-28-multi-vintage.md` (new), `docs/backlog.md` | report, backlog | 8 |

---

### Task 1: Continuous Timeline engine

The session no longer stops after the first Vintage: vines step every day, yearly costs recur, seasonal gates fire once per year, and each Vintage is marked bottled when all its Lots are in bottle.

**Files:**
- Modify: `sim/src/TerroirEngine.Core/Game/GameSession.cs`
- Modify: `sim/src/TerroirEngine.Core/Game/GameSession.Advisor.cs`
- Modify: `sim/src/TerroirEngine.Core/Winery/Winery.cs` (class `Lot`, ~line 59)
- Modify: `sim/src/TerroirEngine.Core/Tasting/Wine.cs` (class `Provenance`, ~line 9)
- Modify: `sim/src/TerroirEngine.Core/Game/Snapshot.cs` (`Build`, `StageLabel`, `WeatherObj`)
- Modify: `sim/src/TerroirEngine.Cli/Program.cs` (`play` command, ~line 92)
- Modify: `sim/tests/TerroirEngine.Core.Tests/CoreTests.cs`
- Create: `sim/tests/TerroirEngine.Core.Tests/MultiVintageTests.cs`

**Interfaces:**
- Produces: `enum GamePhase { Establishment, Running }`; `int GameSession.FirstVintage`; `int GameSession.Vintage` (current season year, `Date.Year` once Running); `bool GameSession.IsVintageBottled(int vintage)`; `IReadOnlyCollection<int> GameSession.BottledVintages`; `List<Wine> GameSession.WinesOf(int vintage)`; `int Lot.Vintage`; `DateOnly? Provenance.Budburst`; `DateOnly? GameSession.FinishedDate` (date the **first** Vintage was fully bottled); message kinds `"finished"` (first Vintage) and `"vintage-bottled"` (later Vintages); `Fixture.PlayVintages(plotId, plantingYear, targetOe, vintages, onStart?)`.

- [ ] **Step 1: Update the test fixture and existing tests to the new loop condition**

In `sim/tests/TerroirEngine.Core.Tests/CoreTests.cs`, replace the body of `Fixture.Play` with a multi-Vintage player:

```csharp
    /// <summary>Scripted player over several Vintages: harvest at a target, default cellar choices, bottle each Lot on its own,
    /// until the last requested Vintage is in bottle.</summary>
    public static GameSession PlayVintages(string plotId, int plantingYear, double targetOe, int vintages, Action<GameSession>? onStart = null)
    {
        var g = new GameSession(Data, new GameSetup { PlotId = plotId, PlantingYear = plantingYear });
        onStart?.Invoke(g);
        int last = g.FirstVintage + vintages - 1, guard = 0;
        while (!g.IsVintageBottled(last) && guard++ < 400 * vintages)
        {
            g.Advance(30);
            if (g.Vintage <= last)
                foreach (var b in g.Blocks.Where(b => !b.Harvested && !b.Picking && b.Veraison != null))
                    if (Chemistry.MustFromBlock(b).Oe >= targetOe || b.LeafFall != null) g.Apply(new Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Table" });
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Ready).ToList()) g.Apply(new Command { Type = "wine", A = lot.Id, E = lot.Id });
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Stuck).ToList()) g.Apply(new Command { Type = "restart", A = lot.Id });
        }
        return g;
    }

    /// <summary>Scripted player for the first Vintage only.</summary>
    public static GameSession Play(string plotId, int plantingYear, double targetOe, Action<GameSession>? onStart = null) => PlayVintages(plotId, plantingYear, targetOe, 1, onStart);
```

Then make these edits in the same file (the vines now keep growing after the first Vintage, so tests must look at the first Vintage's fruit only):

- `LawTests.Chaptalisation_ForbidsPradikat_OnTheMosel`: change `while (g2.Phase != GamePhase.Finished && guard++ < 400)` to `while (!g2.IsVintageBottled(g2.FirstVintage) && guard++ < 400)`; wrap the harvest `foreach` in `if (g2.Vintage == g2.FirstVintage)`; change `Assert.All(g.Wines, ...)` to `Assert.All(g.WinesOf(g.FirstVintage), ...)`, `Assert.All(g2.Wines, ...)` to `Assert.All(g2.WinesOf(g2.FirstVintage), ...)` and `g2.Wines.SelectMany` to `g2.WinesOf(g2.FirstVintage).SelectMany`.
- `LawTests.Riesling_InBurgundy_IsVinDeFrance`: same loop change (`!g.IsVintageBottled(g.FirstVintage)`), harvest `foreach` inside `if (g.Vintage == g.FirstVintage)`, and assert on `g.WinesOf(g.FirstVintage)` (both `NotEmpty` and `All`).
- `VineyardCalibrationTests.Mosel_Riesling_HarvestComposition_IsInRange`: `foreach (var p in g.Provenance.Values.Where(p => p.Vintage == g.FirstVintage))`.
- `VineyardCalibrationTests.Napa_Cabernet_IsLowAcidHighPh_AndRipensInAutumn`: iterate `g.Provenance.Values.Where(p => p.Vintage == g.FirstVintage)`, and replace the last assert with
  `Assert.All(g.Provenance.Values.Where(p => p.Vintage == g.FirstVintage), p => Assert.InRange(p.Budburst!.Value.Month, 3, 4));`
- `VineyardCalibrationTests.VeryRipeMust_CannotFermentBeyondYeastTolerance`: both `Assert.All(g.Lots, ...)` become `Assert.All(g.Lots.Where(l => l.Vintage == g.FirstVintage), ...)`.
- `GameLoopTests.FullGame_ReachesBottling_WithTastingSheets`: replace `Assert.Equal(GamePhase.Finished, g.Phase);` with `Assert.True(g.IsVintageBottled(g.FirstVintage));` and iterate `foreach (var w in g.WinesOf(g.FirstVintage))` instead of `g.Wines`; `Assert.NotEmpty(g.WinesOf(g.FirstVintage));`.

- [ ] **Step 2: Write the new failing tests**

Create `sim/tests/TerroirEngine.Core.Tests/MultiVintageTests.cs`:

```csharp
using TerroirEngine.Data;
using TerroirEngine.Game;
using TerroirEngine.Tasting;
using TerroirEngine.Util;
using TerroirEngine.Vineyard;
using TerroirEngine.Weather;
using TerroirEngine.Winery;

namespace TerroirEngine.Tests;

public class MultiVintageLoopTests
{
    [Theory]
    [InlineData("mosel-seitental", 2014, 80)]
    [InlineData("cotedor-village", 2013, 95)]
    [InlineData("napa-carneros", 2016, 104)]
    public void ThreeVintages_BackToBack(string plot, int year, double target)
    {
        var g = Fixture.PlayVintages(plot, year, target, vintages: 3);
        for (int v = g.FirstVintage; v < g.FirstVintage + 3; v++)
        {
            Assert.True(g.IsVintageBottled(v), $"Vintage {v} is not in bottle");
            Assert.NotEmpty(g.WinesOf(v));
            Assert.All(g.Lots.Where(l => l.Vintage == v), l => Assert.StartsWith($"{v % 100:00}-", l.Id));
        }
        Assert.Single(g.Inbox, m => m.Kind == "finished");
        Assert.Equal(2, g.Inbox.Count(m => m.Kind == "vintage-bottled"));
        Assert.True(g.MentorRetired);
    }

    [Fact]
    public void SeasonalAlerts_FireOncePerYear()
    {
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 2);
        var budbursts = g.Inbox.Where(m => m.Kind == "budburst").Select(m => m.Date.Year).ToList();
        Assert.Equal(new[] { g.FirstVintage, g.FirstVintage + 1 }, budbursts.Take(2));
        Assert.Equal(budbursts.Count, budbursts.Distinct().Count());
        var windows = g.Inbox.Where(m => m.Kind == "harvest-window").GroupBy(m => (m.Date.Year, m.BlockId)).ToList();
        Assert.All(windows, grp => Assert.Single(grp));
        Assert.Contains(windows, grp => grp.Key.Year == g.FirstVintage + 1);
    }

    [Fact]
    public void SaveAndLoad_TwoVintagesIn_ReproducesTheSnapshot()
    {
        var g = Fixture.PlayVintages("mosel-terrassen", 2016, 86, vintages: 2);
        var g2 = GameSession.Load(Fixture.Data, g.Save());
        Assert.Equal(Snapshot.Json(g), Snapshot.Json(g2));
    }

    [Fact]
    public void ForcedHarvest_EveryVintage_WithoutPlayerInput()
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2014 });
        while (g.Date < new DateOnly(g.FirstVintage + 2, 1, 1)) g.Advance(60, stopAtAlerts: false);
        Assert.Contains(g.Lots, l => l.Vintage == g.FirstVintage);
        Assert.Contains(g.Lots, l => l.Vintage == g.FirstVintage + 1);
        var forced = g.Inbox.Where(m => m.Kind == "forced-harvest").ToList();
        Assert.Equal(forced.Count, forced.Select(m => (m.Date.Year, m.BlockId)).Distinct().Count());
    }

    [Fact]
    public void UnbottledVintage_DoesNotBlockTheNext()
    {
        // never bottle the first Vintage; bottle everything from the second
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2014 });
        int guard = 0;
        while (!g.IsVintageBottled(g.FirstVintage + 1) && guard++ < 800)
        {
            g.Advance(30);
            foreach (var b in g.Blocks.Where(b => !b.Harvested && !b.Picking && b.Veraison != null && (Chemistry.MustFromBlock(b).Oe >= 80 || b.LeafFall != null)))
                g.Apply(new Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Table" });
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Ready && l.Vintage > g.FirstVintage).ToList()) g.Apply(new Command { Type = "wine", A = lot.Id, E = lot.Id });
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Stuck).ToList()) g.Apply(new Command { Type = "restart", A = lot.Id });
        }
        Assert.True(g.IsVintageBottled(g.FirstVintage + 1));
        Assert.False(g.IsVintageBottled(g.FirstVintage));
        Assert.False(g.MentorRetired);   // the Mentor stays until the first Vintage is in bottle
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator/sim && ~/.dotnet/dotnet test -v q 2>&1 | tail -5`
Expected: build FAILS with errors such as `'GameSession' does not contain a definition for 'FirstVintage'` / `'IsVintageBottled'` / `'WinesOf'`, `'Lot' does not contain a definition for 'Vintage'`.

- [ ] **Step 4: Add `Lot.Vintage` and `Provenance.Budburst`**

In `Winery.cs`, class `Lot`, after `public DateOnly Harvested { get; set; }` add:

```csharp
    /// <summary>The Vintage this Lot belongs to: its harvest year (the December rule picks every Block within its year).</summary>
    public int Vintage => Harvested.Year;
```

In `Wine.cs`, class `Provenance`, after `public DateOnly HarvestDate;` add:

```csharp
    public DateOnly? Budburst;
```

In `GameSession.cs` `CaptureProvenance`, add `Budburst = b.Budburst,` next to `HarvestDate = Date,`.

- [ ] **Step 5: Make the session continuous**

In `GameSession.cs`:

1. Replace `public enum GamePhase { Establishment, Vintage, Cellar, Finished }` with:

```csharp
/// <summary>Establishment is fast-forwarded at game start; after it the game runs year after year on the Timeline (ADR 0002).</summary>
public enum GamePhase { Establishment, Running }
```

2. Update the class summary to: `/// <summary>One game: an Estate on one Plot, from bare land through Establishment, then Vintage after Vintage on the Timeline (spec §3; multi-vintage design).</summary>`

3. Replace `public int Vintage => Setup.PlantingYear + 3;` with:

```csharp
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
```

4. Change the `FinishedDate` declaration comment: `/// <summary>The day the first Vintage was fully bottled (the Mentor retires).</summary>` above `public DateOnly? FinishedDate { get; private set; }`.

5. In `RunEstablishment`: `for (int year = Setup.PlantingYear; year < Vintage; year++)` → `for (int year = Setup.PlantingYear; year < FirstVintage; year++)`; `Phase = GamePhase.Vintage;` → `Phase = GamePhase.Running;`; `Date = new DateOnly(Vintage, 1, 15);` → `Date = new DateOnly(FirstVintage, 1, 15);`; `for (var d = new DateOnly(Vintage, 1, 1); ...` → `for (var d = new DateOnly(FirstVintage, 1, 1); ...`.

6. Replace `Advance` with:

```csharp
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
```

7. In `StepDay`: delete `bool vineYear = Date.Year == Vintage;`; replace `if (vineYear) foreach (var b in Blocks) VineyardModel.Step(b, w, Ctx, Setup.Seed);` with `foreach (var b in Blocks) VineyardModel.Step(b, w, Ctx, Setup.Seed);`; replace `if (Ledger.Cash < 0 && Phase != GamePhase.Finished && Gate("overdrawn"))` with `if (Ledger.Cash < 0 && Gate("overdrawn"))`; replace the `RiskSeries` block with

```csharp
        if (Date.Month >= 4 && Date.Month <= 10)
        {
            if (Date.Month == 4 && Date.Day == 1) RiskSeries.Clear();   // the risk chart shows the current Vintage only
            RiskSeries.Add((Date, Blocks.Average(b => b.Disease.DownyRiskToday), Blocks.Average(b => b.Disease.PowderyIndex), Blocks.Average(b => b.Disease.BotrytisRiskToday)));
        }
```

and replace `UpdatePhase();` with `CheckBottledVintages();`.

8. Replace the whole `UpdatePhase` method with:

```csharp
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
```

9. In `DailyCosts`: `bool season = Date.Month >= 3 && Date.Month <= 10 && Date.Year == Vintage;` → `bool season = Date.Month >= 3 && Date.Month <= 10;`; `if (Ctx.SprayPassesToday > 0 && Date.Year == Vintage)` → `if (Ctx.SprayPassesToday > 0)`; `if (Ctx.IrrigationLegal && Date.Year == Vintage)` → `if (Ctx.IrrigationLegal)`.

10. In `CreateWine`, replace `(wine.Blend.Harvested.Year == Vintage && Blocks.Any(b => b.Leaf(Vintage) == 4) ? 0.95 : 1)` with `(wine.Blend.Harvested.Year == FirstVintage ? 0.95 : 1)`.

11. In `Load`, replace `while (s.Date < target && s.Phase != GamePhase.Finished)` with `while (s.Date < target)`.

- [ ] **Step 6: Per-year gates and the Advisor in every Vintage**

In `GameSession.Advisor.cs`:

- `Gate("budburst")` → `Gate($"budburst-{Date.Year}")`; `Gate("flowering")` → `Gate($"flowering-{Date.Year}")`; `Gate("veraison")` → `Gate($"veraison-{Date.Year}")`; `Gate("downy-primary")` → `Gate($"downy-primary-{Date.Year}")`; `Gate($"yield-{b.Data.Id}")` → `Gate($"yield-{b.Data.Id}-{Date.Year}")`; `Gate($"window-{b.Data.Id}")` → `Gate($"window-{b.Data.Id}-{Date.Year}")`.
- Replace the first line of `Advisor()` (`if (Phase != GamePhase.Vintage || Date.Year != Vintage) return;`) with:

```csharp
        if (Phase != GamePhase.Running) return;
        if (!Blocks.Any(b => b.Budburst != null && !b.Harvested)) return;   // nothing growing: no vineyard advice (saves a forecast per winter day)
```

- In the late-season loop change the filter to `Blocks.Where(b => !b.Harvested && !b.Picking && b.Veraison != null && Date >= new DateOnly(Date.Year, 12, 1))` (a Block with no véraison cannot be picked, and would otherwise post daily).

- [ ] **Step 7: Snapshot and CLI compile fixes**

In `Snapshot.cs`:
- `["report"] = g.Phase == GamePhase.Finished ? VintageReport.Build(g) : null,` → `["report"] = g.IsVintageBottled(g.FirstVintage) ? VintageReport.Build(g) : null,` (Task 2 replaces this).
- In `StageLabel`, replace the two lines `if (g.Phase == GamePhase.Finished) ...` and `if (g.Phase == GamePhase.Cellar) ...` with `if (g.Blocks.All(x => x.Harvested)) return g.Lots.Any(l => l.Phase != LotPhase.Blended) ? "After the harvest · wine in the cellar" : "After the harvest";`
- In `WeatherObj`: `int year = Math.Min(g.Date.Year, g.Vintage);` → `int year = g.Date.Year;`; `var end = g.Date.Year > g.Vintage ? new DateOnly(g.Vintage, 12, 31) : g.Date.AddDays(-1);` → `var end = g.Date.AddDays(-1);`; `var fc = g.Phase == GamePhase.Finished ? new List<Forecaster.ForecastDay>() : g.CurrentForecast();` → `var fc = g.CurrentForecast();`.

In `Program.cs` `play`: read the Vintage count and loop until the last one is bottled:

```csharp
    int vintages = int.TryParse(Environment.GetEnvironmentVariable("TE_VINTAGES"), out var nv) ? Math.Max(1, nv) : 1;
    int lastVintage = g.FirstVintage + vintages - 1;
```

(placed after `bool verbose = ...`), change the loop header to `while (!g.IsVintageBottled(lastVintage) && guard++ < 3000 * vintages)`, wrap the harvest `foreach` in `if (g.Vintage <= lastVintage)`, change the finish line to

```csharp
    Console.WriteLine($"{vintages} Vintage(s) bottled by {g.Date} (first on {g.FinishedDate}) after {stops} stops, {sw.ElapsedMilliseconds} ms. Inbox {g.Inbox.Count} messages.");
```

and change `vintage {g.Vintage}` in the first `Console.WriteLine` to `first Vintage {g.FirstVintage}`.

Then check nothing else references the removed phases:

Run: `grep -rn "GamePhase\.\(Vintage\|Cellar\|Finished\)" /mnt/c/Users/Aleksander/src/repos/winegamesimulator/sim /mnt/c/Users/Aleksander/src/repos/winegamesimulator/game/src/bridge`
Expected: no output.

- [ ] **Step 8: Run all tests**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator/sim && ~/.dotnet/dotnet test -v q 2>&1 | tail -5`
Expected: `Failed: 0` with 32 tests passed (25 existing + 7 new cases). If `SaveAndLoad_TwoVintagesIn_ReproducesTheSnapshot` fails, diff the two JSON strings (write both to `$CLAUDE_JOB_DIR/tmp` and `diff` them): a difference is a real determinism bug to fix, never a reason to weaken the test.

- [ ] **Step 9: Smoke-run the CLI over three Vintages**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator/sim && TE_VINTAGES=3 ~/.dotnet/dotnet run --project src/TerroirEngine.Cli -- play mosel-seitental 2014 2>&1 | grep -E "Vintage\(s\) bottled|Save/replay|==" | head`
Expected: a line `3 Vintage(s) bottled by ...`, a `Save/replay: ... cash match True` line, and `==` wine lines from three Vintages.

- [ ] **Step 10: Commit**

```bash
cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator
git add sim/src sim/tests
git commit -m "feat(sim): continuous Timeline — the game runs Vintage after Vintage

Phases become Establishment/Running; vines step every day, yearly costs
recur, seasonal alerts fire once per year, and each Vintage is marked
bottled when all its Lots are. The Mentor still retires after the first.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Season records and a Vintage report per Vintage

`BlockState` is reset every 1 January, so each closed season is archived as a `SeasonRecord`; the Vintage report reads those records and can be built for any Vintage.

**Files:**
- Modify: `sim/src/TerroirEngine.Core/Vineyard/BlockState.cs`
- Modify: `sim/src/TerroirEngine.Core/Vineyard/VineyardModel.cs` (`StartSeason`, new `Record`)
- Modify: `sim/src/TerroirEngine.Core/Game/GameSession.cs` (new `Season`)
- Modify: `sim/src/TerroirEngine.Core/Game/VintageReport.cs`
- Modify: `sim/src/TerroirEngine.Core/Game/Snapshot.cs` (`report`, `reports`)
- Test: `sim/tests/TerroirEngine.Core.Tests/MultiVintageTests.cs`

**Interfaces:**
- Consumes: `GameSession.FirstVintage`, `IsVintageBottled`, `BottledVintages`, `WinesOf`, `Lot.Vintage` (Task 1).
- Produces: `sealed class SeasonRecord` with init properties `Year, Leaf, Budburst, Flowering, Veraison, HarvestDate, LeafFall, YieldKgHa, FrostShootLoss, GreyRotPct, Winkler, RainSeason`; `List<SeasonRecord> BlockState.Seasons`; `static SeasonRecord VineyardModel.Record(BlockState b)`; `SeasonRecord? GameSession.Season(BlockState b, int year)`; `JsonObject VintageReport.Build(GameSession g, int vintage)` with keys `vintage, plot, region, verdict, weather, weekly, meant, events, blocks, wines, money, next, farewell`; snapshot keys `report` (newest bottled Vintage) and `reports` (all bottled, newest first). Task 3 adds more `SeasonRecord` properties.

- [ ] **Step 1: Write the failing test**

Append to `MultiVintageTests.cs`:

```csharp
public class VintageReportTests
{
    [Fact]
    public void VintageReports_ArePerVintage_FromSeasonRecords()
    {
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 2);
        var r1 = VintageReport.Build(g, g.FirstVintage);
        var r2 = VintageReport.Build(g, g.FirstVintage + 1);
        Assert.Equal(g.FirstVintage, r1["vintage"]!.GetValue<int>());
        Assert.Equal(g.FirstVintage + 1, r2["vintage"]!.GetValue<int>());
        Assert.NotEqual(r1["weather"]!["winkler"]!.GetValue<double>(), r2["weather"]!["winkler"]!.GetValue<double>());
        foreach (var r in new[] { r1, r2 })
            foreach (var b in r["blocks"]!.AsArray()) { Assert.NotNull(b!["harvest"]); Assert.NotNull(b["wine"]); }
        Assert.True(r1["farewell"]!.GetValue<bool>());
        Assert.False(r2["farewell"]!.GetValue<bool>());
        Assert.NotEmpty(r2["weekly"]!.AsArray());
        Assert.All(g.Blocks, b => Assert.Contains(b.Seasons, s => s.Year == g.FirstVintage && s.HarvestDate != null && s.YieldKgHa > 0));
        var snap = Snapshot.Build(g);
        Assert.Equal(2, snap["reports"]!.AsArray().Count);
        Assert.Equal(g.FirstVintage + 1, snap["report"]!["vintage"]!.GetValue<int>());
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator/sim && ~/.dotnet/dotnet test -v q --filter VintageReportTests 2>&1 | tail -5`
Expected: build FAILS: `No overload for method 'Build' takes 2 arguments`, `'BlockState' does not contain a definition for 'Seasons'`.

- [ ] **Step 3: Add `SeasonRecord` and archive seasons**

In `BlockState.cs`, after the `RipenessSample` record add:

```csharp
/// <summary>One closed season of a Block, archived on 1 January because BlockState itself is reset (multi-vintage design §3.3).</summary>
public sealed class SeasonRecord
{
    public int Year { get; init; }
    public int Leaf { get; init; }
    public DateOnly? Budburst { get; init; }
    public DateOnly? Flowering { get; init; }
    public DateOnly? Veraison { get; init; }
    public DateOnly? HarvestDate { get; init; }
    public DateOnly? LeafFall { get; init; }
    public double YieldKgHa { get; init; }
    public double FrostShootLoss { get; init; }
    public double GreyRotPct { get; init; }
    public double Winkler { get; init; }
    public double RainSeason { get; init; }
}
```

In class `BlockState`, after `public List<RipenessSample> Samples { get; } = new();` add:

```csharp
    /// <summary>Closed seasons, oldest first (Establishment years included).</summary>
    public List<SeasonRecord> Seasons { get; } = new();
```

In `VineyardModel.cs`, add below `StartSeason`:

```csharp
    /// <summary>The Block's current season as a record (also used for the live season in reports).</summary>
    public static SeasonRecord Record(BlockState b) => new()
    {
        Year = b.SeasonYear, Leaf = b.Leaf(b.SeasonYear), Budburst = b.Budburst, Flowering = b.Flowering, Veraison = b.Veraison, HarvestDate = b.HarvestDate, LeafFall = b.LeafFall,
        YieldKgHa = b.Harvested ? b.PickedKg / Math.Max(0.01, b.AreaHa) : 0, FrostShootLoss = b.FrostShootLoss, GreyRotPct = b.Disease.GreyRot * 100, Winkler = b.Winkler, RainSeason = b.RainSeason,
    };
```

and make the first line of `StartSeason` (before `b.SeasonYear = year;`):

```csharp
        if (b.SeasonYear > 0) b.Seasons.Add(Record(b));
```

In `GameSession.cs`, after `WinesOf` add:

```csharp
    /// <summary>A Block's season for <paramref name="year"/>: the live state for the current season, else the archived record.</summary>
    public SeasonRecord? Season(BlockState b, int year) => b.SeasonYear == year ? VineyardModel.Record(b) : b.Seasons.LastOrDefault(s => s.Year == year);
```

- [ ] **Step 4: Rewrite `VintageReport` to take a Vintage**

Replace `sim/src/TerroirEngine.Core/Game/VintageReport.cs` with:

```csharp
using System.Text.Json.Nodes;
using TerroirEngine.Util;
using TerroirEngine.Vineyard;
using TerroirEngine.Weather;

namespace TerroirEngine.Game;

/// <summary>The year in review for one Vintage: its weather against the 1991–2020 normal and what it meant for the grapes,
/// the key events, each Block's result, the wines, the money, and suggestions for next time.
/// Thresholds for the wording (hot/cool, wet/dry) are game presentation choices, not science claims.</summary>
public static class VintageReport
{
    private static readonly Dictionary<string, (double wi, double gst, double rainSeason, double rainAutumn, double heatDays, double frostNights)> NormalCache = new();
    private static readonly Dictionary<string, double[]> WeeklyNormalCache = new();

    private record YearStats(double Wi, double Gst, double RainSeason, double RainAutumn, int HeatDays, int FrostNights);

    /// <summary>April–October statistics for a year, never looking past yesterday (the current Vintage is partial).</summary>
    private static YearStats Stats(GameSession g, int year, DateOnly? budburst)
    {
        var clim = g.Blocks[0].Climate;
        double wi = 0, tsum = 0, rain = 0, rainAut = 0; int n = 0, heat = 0, frost = 0;
        var bb = budburst ?? new DateOnly(year, 4, 15);
        var end = new DateOnly(year, 10, 31);
        if (end >= g.Date) end = g.Date.AddDays(-1);
        for (var d = new DateOnly(year, 4, 1); d <= end; d = d.AddDays(1))
        {
            var w = clim.Adjust(g.Weather.Get(d));
            wi += Math.Max(0, w.Tmean - 10); tsum += w.Tmean; n++;
            rain += w.Precip;
            if (d.Month >= 9) rainAut += w.Precip;
            if (w.Tmax >= 35) heat++;
            if (d >= bb && d <= new DateOnly(year, 5, 20) && w.Tmin <= -1) frost++;
        }
        return new YearStats(wi, n > 0 ? tsum / n : 0, rain, rainAut, heat, frost);
    }

    private static (double wi, double gst, double rainSeason, double rainAutumn, double heatDays, double frostNights) Normal(GameSession g)
    {
        if (NormalCache.TryGetValue(g.Plot.Id, out var c)) return c;
        var list = new List<YearStats>();
        for (int y = 1991; y <= 2020; y++)
            if (g.Weather.Archive.Has(new DateOnly(y, 1, 1))) list.Add(Stats(g, y, new DateOnly(y, 4, 20)));
        c = (list.Average(s => s.Wi), list.Average(s => s.Gst), list.Average(s => s.RainSeason), list.Average(s => s.RainAutumn), list.Average(s => s.HeatDays), list.Average(s => s.FrostNights));
        NormalCache[g.Plot.Id] = c;
        return c;
    }

    /// <summary>1991–2020 mean temperature per week of the year (Block A microclimate).</summary>
    private static double[] WeeklyNormal(GameSession g)
    {
        if (WeeklyNormalCache.TryGetValue(g.Plot.Id, out var wn)) return wn;
        var clim = g.Blocks[0].Climate;
        var sum = new double[53]; var cnt = new int[53];
        for (int y = 1991; y <= 2020; y++)
        {
            if (!g.Weather.Archive.Has(new DateOnly(y, 1, 1))) continue;
            for (var d = new DateOnly(y, 1, 1); d.Year == y; d = d.AddDays(1)) { int wk = Math.Min(52, (d.DayOfYear - 1) / 7); sum[wk] += clim.Adjust(g.Weather.Archive.Get(d)).Tmean; cnt[wk]++; }
        }
        for (int i = 0; i < 53; i++) sum[i] = cnt[i] > 0 ? sum[i] / cnt[i] : 0;
        WeeklyNormalCache[g.Plot.Id] = sum;
        return sum;
    }

    private static List<SeasonRecord> Records(GameSession g, int vintage) =>
        g.Blocks.Select(b => g.Season(b, vintage)).Where(r => r != null).Select(r => r!).ToList();

    public static JsonObject Build(GameSession g, int vintage)
    {
        var recs = Records(g, vintage);
        var y = Stats(g, vintage, recs.Select(r => r.Budburst).Where(d => d != null).Min());
        var n = Normal(g);
        double heatAnom = y.Wi / Math.Max(1, n.wi) - 1, rainAnom = y.RainSeason / Math.Max(1, n.rainSeason) - 1, autAnom = y.RainAutumn / Math.Max(1, n.rainAutumn) - 1;
        string heatWord = heatAnom > 0.12 ? "hot" : heatAnom > 0.04 ? "warm" : heatAnom < -0.12 ? "cold" : heatAnom < -0.04 ? "cool" : "average-warmth";
        string rainWord = rainAnom > 0.3 ? "wet" : rainAnom > 0.1 ? "rather wet" : rainAnom < -0.3 ? "dry" : rainAnom < -0.1 ? "rather dry" : "normal-rainfall";
        string verdict = $"A {heatWord}, {rainWord} year";
        double worstFrost = recs.Count > 0 ? recs.Max(r => r.FrostShootLoss) : 0;

        var meant = new List<string>();
        if (heatAnom > 0.04) meant.Add($"More heat than normal ({heatAnom * 100:+0;-0} %) made sugar rise fast while the grapes burned off malic acid: ripe, fuller wines, but acidity was the thing to protect. Picking a little earlier keeps freshness.");
        else if (heatAnom < -0.04) meant.Add($"Less heat than normal ({heatAnom * 100:+0;-0} %) meant slow ripening: lighter, fresher wines with high acidity. Waiting for ripeness had to be weighed against autumn rot.");
        else meant.Add("Heat was close to normal: a balanced season for ripening.");
        if (y.FrostNights > 0) meant.Add($"{y.FrostNights} frost night(s) after budburst" + (worstFrost > 0.05 ? $" killed up to {worstFrost * 100:0} % of the young shoots in the worst Block." : ", but damage stayed small."));
        if (y.HeatDays > 0) meant.Add($"{y.HeatDays} day(s) reached 35 °C: sunburn risk on exposed bunches and a pause in ripening on the hottest days.");
        if (autAnom > 0.3) meant.Add($"A wet autumn ({autAnom * 100:+0} % rain in Sept–Oct) raised the grey-rot pressure at harvest; sorting and timing mattered.");
        else if (autAnom < -0.3) meant.Add("A dry autumn let the grapes hang healthily: harvest timing was your choice, not the weather's.");
        if (rainAnom < -0.3) meant.Add("Little rain over the season: shallow soils and young vines felt water stress, which concentrates flavour but can stall ripening.");

        var blocks = new JsonArray();
        foreach (var b in g.Blocks)
        {
            var r = g.Season(b, vintage);
            string lotId = $"{vintage % 100:00}-{b.Data.Id}";
            g.Provenance.TryGetValue(lotId, out var p);
            var wine = g.Wines.FirstOrDefault(w => w.Components.Any(c => c.LotId == lotId));
            blocks.Add(new JsonObject
            {
                ["id"] = b.Data.Id, ["variety"] = p?.Variety ?? b.Variety.Name, ["budburst"] = D(r?.Budburst), ["flowering"] = D(r?.Flowering), ["veraison"] = D(r?.Veraison), ["harvest"] = D(r?.HarvestDate),
                ["oe"] = p == null ? null : Math.Round(p.HarvestOe), ["ta"] = p == null ? null : Math.Round(p.HarvestTa, 1), ["ph"] = p == null ? null : Math.Round(p.HarvestPh, 2),
                ["yieldHl"] = p == null ? null : Math.Round(p.YieldHlHa), ["rot"] = p == null ? null : Math.Round(p.GreyRotPct, 1), ["frost"] = Math.Round((r?.FrostShootLoss ?? 0) * 100),
                ["wine"] = wine?.Name, ["quality"] = wine?.Sheet?.Quality,
            });
        }

        var vintageWines = g.WinesOf(vintage);
        var wines = new JsonArray();
        foreach (var w in vintageWines.OrderByDescending(w => w.Revenue))
            wines.Add(new JsonObject { ["name"] = w.Name, ["label"] = w.Legal?.Label, ["category"] = w.Legal?.Category, ["quality"] = w.Sheet?.Quality, ["bottles"] = w.Bottles, ["price"] = w.PricePerBottle, ["revenue"] = Math.Round(w.Revenue) });

        // money: the costs of the calendar year plus bottling done later, against the sales of this Vintage's wines
        var cats = g.Ledger.ByCategory(new DateOnly(vintage, 1, 1), new DateOnly(vintage, 12, 31));
        double revenue = vintageWines.Sum(w => w.Revenue);
        double costs = cats.Where(kv => kv.Value < 0).Sum(kv => -kv.Value) + vintageWines.Where(w => w.Bottled?.Year != vintage).Sum(w => w.BottlingCost);
        var topCosts = new JsonArray();
        foreach (var kv in cats.Where(kv => kv.Value < 0).OrderBy(kv => kv.Value).Take(5)) topCosts.Add(new JsonObject { ["category"] = kv.Key, ["amount"] = Math.Round(-kv.Value) });

        // suggestions: look at what happened and point at the lever that addresses it (teaching, not scoring)
        var next = new List<string>();
        var ps = g.Provenance.Values.Where(p => p.Vintage == vintage).ToList();
        if (ps.Any(p => p.GreyRotPct > 5)) next.Add("Some fruit came in with more than 5 % grey rot. Try a higher spray tier, morning-side leaf removal to dry the bunches, rigorous sorting, or picking before forecast rain.");
        if (worstFrost > 0.1) next.Add("Frost cost you crop. Watch the frost warnings after budburst and raise frost protection on the nights they forecast.");
        if (ps.Any(p => p.HarvestTa < 5.5) && heatAnom > 0) next.Add("Acidity ended up low in the heat. Pick earlier, or (where legal) let the Cellar master acidify.");
        if (ps.Any(p => p.HarvestTa > 9.5) && g.Region.Id != "mosel") next.Add("Acidity was high: the grapes may have needed more hang time or more fruit exposure.");
        if (vintageWines.Any(w => w.Sheet?.Quality is "Poor" or "Acceptable")) next.Add("For your weaker wines, open the Tasting sheet and look at which quality criteria failed: intensity and length usually come from lower yields (Low bud load, green harvest) and riper fruit.");
        if (vintageWines.Any(w => w.Legal?.Declassified == true)) next.Add("A wine was declassified. Check the legal notes: yields, buds per vine or chaptalisation limits are the usual causes.");
        if (next.Count == 0) next.Add("A clean year. Next time, experiment: split a Block's harvest dates, or try a different vessel or yeast on one Lot and compare the Tasting sheets.");

        var events = new JsonArray();
        foreach (var m in g.Inbox.Where(m => m.Date.Year == vintage && m.Priority == "high" && m.Kind is "frost" or "frost-warning" or "downy" or "botrytis" or "veraison" or "budburst" or "ferment-stuck" or "overdrawn" or "bottled" or "newseason").OrderBy(m => m.Id).Take(14))
            events.Add(new JsonObject { ["date"] = Dates.Short(m.Date), ["text"] = m.Subject, ["kind"] = m.Kind });

        // weekly temperature, March to November (or yesterday), against the weekly normal
        var clim = g.Blocks[0].Climate;
        var wn = WeeklyNormal(g);
        var weekly = new JsonArray();
        double ws = 0; int wc = 0;
        var wEnd = new DateOnly(vintage, 11, 30);
        if (wEnd >= g.Date) wEnd = g.Date.AddDays(-1);
        for (var d = new DateOnly(vintage, 3, 1); d <= wEnd; d = d.AddDays(1))
        {
            ws += clim.Adjust(g.Weather.Get(d)).Tmean; wc++;
            if (d.DayOfWeek == DayOfWeek.Sunday || d == wEnd)
            {
                int wk = Math.Min(52, (d.DayOfYear - 1) / 7);
                weekly.Add(new JsonObject { ["date"] = Dates.Short(d), ["tmean"] = Math.Round(ws / wc, 1), ["tmeanNormal"] = Math.Round(wn[wk], 1) });
                ws = 0; wc = 0;
            }
        }

        return new JsonObject
        {
            ["vintage"] = vintage, ["plot"] = g.Plot.Name, ["region"] = g.Region.Name, ["verdict"] = verdict, ["farewell"] = vintage == g.FirstVintage,
            ["weather"] = new JsonObject
            {
                ["winkler"] = Math.Round(y.Wi), ["winklerNormal"] = Math.Round(n.wi), ["heatAnomalyPct"] = Math.Round(heatAnom * 100),
                ["gst"] = Math.Round(y.Gst, 1), ["gstNormal"] = Math.Round(n.gst, 1),
                ["rain"] = Math.Round(y.RainSeason), ["rainNormal"] = Math.Round(n.rainSeason), ["rainAnomalyPct"] = Math.Round(rainAnom * 100),
                ["rainAutumn"] = Math.Round(y.RainAutumn), ["rainAutumnNormal"] = Math.Round(n.rainAutumn),
                ["heatDays"] = y.HeatDays, ["heatDaysNormal"] = Math.Round(n.heatDays, 1), ["frostNights"] = y.FrostNights, ["frostNightsNormal"] = Math.Round(n.frostNights, 1),
                ["historical"] = g.Weather.IsHistorical(new DateOnly(vintage, 6, 1)),
            },
            ["weekly"] = weekly,
            ["meant"] = new JsonArray(meant.Select(s => (JsonNode)s).ToArray()),
            ["events"] = events, ["blocks"] = blocks, ["wines"] = wines,
            ["money"] = new JsonObject { ["revenue"] = Math.Round(revenue), ["costs"] = Math.Round(costs), ["result"] = Math.Round(revenue - costs), ["topCosts"] = topCosts },
            ["next"] = new JsonArray(next.Select(s => (JsonNode)s).ToArray()),
        };
    }

    private static string? D(DateOnly? d) => d == null ? null : Dates.Short(d.Value);
}
```

In `Snapshot.cs` `Build`, replace the `["report"]` line with:

```csharp
            ["report"] = g.BottledVintages.Count > 0 ? VintageReport.Build(g, g.BottledVintages.Max()) : null,
            ["reports"] = Arr(g.BottledVintages.OrderByDescending(v => v).Select(v => (JsonNode)VintageReport.Build(g, v))),
```

- [ ] **Step 5: Run all tests**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator/sim && ~/.dotnet/dotnet test -v q 2>&1 | tail -3`
Expected: `Failed: 0`.

- [ ] **Step 6: Commit**

```bash
cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator
git add sim/src sim/tests
git commit -m "feat(sim): season records and a Vintage report for every Vintage

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Vine carry-over — fruitfulness, reserves, disease inoculum

Last year's flowering weather sets this year's bunches per shoot; last year's crop load, harvest timing and leaf loss set this year's reserves; last year's mildew sets this spring's inoculum. All neutral in the first Vintage.

**Files:**
- Modify: `sim/src/TerroirEngine.Core/Vineyard/BlockState.cs`
- Modify: `sim/src/TerroirEngine.Core/Vineyard/VineyardModel.cs`
- Modify: `sim/src/TerroirEngine.Core/Game/GameSession.cs`
- Modify: `docs/science/canopy-and-yield.md`, `docs/science/disease.md`, `CONTEXT.md`, `docs/superpowers/specs/2026-09-28-multi-vintage-design.md`
- Test: `sim/tests/TerroirEngine.Core.Tests/MultiVintageTests.cs`

**Interfaces:**
- Consumes: `SeasonRecord`, `VineyardModel.Record`, `BlockState.Seasons` (Task 2).
- Produces: `BlockState.Fruitfulness`, `FruitfulnessNext`, `Reserves`, `ClimNormalTmean`, `LeafAreaPeak`, `DownyLeafPeak`, `PowderyLeafPeak`; `static double VineyardModel.FruitfulnessFrom(double tAnomC, double exposure)`; `static double VineyardModel.SeasonReserves(double cropLoad, int postHarvestDays, double defoliation)`; `static (double CropLoad, int PostHarvestDays, double Defoliation) VineyardModel.CarryInputs(BlockState b)`; `static double[] VineyardModel.ClimNormalTmean(BlockState b, WeatherArchive archive)`; `static double GameSession.InoculumCarry(double peakLeafPct)`; new `SeasonRecord` properties `DownyLeafPeak, PowderyLeafPeak, CropLoadKgM2, PostHarvestDays, Defoliation, FruitfulnessNext, ReservesAfter`; `double GameSession.BaseDownyInoculum` (read by Task 4).

- [ ] **Step 1: Write the failing tests**

Append to `MultiVintageTests.cs`:

```csharp
public class CarryOverTests
{
    [Fact]
    public void FirstVintage_HasNeutralCarryOver()
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2014 });
        Assert.All(g.Blocks, b => { Assert.Equal(1.0, b.Fruitfulness); Assert.Equal(1.0, b.Reserves); Assert.Equal(1.0, b.FruitfulnessNext); });
        Assert.All(g.Blocks, b => Assert.NotNull(b.ClimNormalTmean));
    }

    [Fact]
    public void Fruitfulness_FollowsFloweringWarmthAndLight_AndIsBounded()
    {
        Assert.Equal(1.0, VineyardModel.FruitfulnessFrom(0, 0.45), 6);
        Assert.True(VineyardModel.FruitfulnessFrom(2, 0.45) > 1.05);
        Assert.True(VineyardModel.FruitfulnessFrom(-2, 0.45) < 0.95);
        Assert.True(VineyardModel.FruitfulnessFrom(0, 0.65) > 1.05);
        Assert.Equal(1.15, VineyardModel.FruitfulnessFrom(10, 0.9), 6);
        Assert.Equal(0.85, VineyardModel.FruitfulnessFrom(-10, 0.1), 6);
    }

    [Fact]
    public void SeasonReserves_DropWithBigCropLateHarvestAndLeafLoss()
    {
        double balanced = VineyardModel.SeasonReserves(1.0, 40, 0);
        Assert.InRange(balanced, 0.99, 1.01);
        Assert.True(VineyardModel.SeasonReserves(1.8, 40, 0) < balanced - 0.05);    // over-cropped
        Assert.True(VineyardModel.SeasonReserves(1.0, 0, 0) < balanced - 0.05);     // picked at leaf fall
        Assert.True(VineyardModel.SeasonReserves(1.0, 40, 0.4) < balanced - 0.1);   // mildew defoliation
        Assert.True(VineyardModel.SeasonReserves(0.3, 40, 0) > balanced);           // light crop: vines recover
        Assert.Equal(0.70, VineyardModel.SeasonReserves(5, 0, 0.9), 6);
    }

    [Fact]
    public void InoculumCarry_RisesWithLastYearsMildew()
    {
        Assert.Equal(0.85, GameSession.InoculumCarry(0), 6);
        Assert.True(GameSession.InoculumCarry(20) > 1.1);
        Assert.Equal(1.30, GameSession.InoculumCarry(80), 6);
    }

    private static GameSession YearTwoAfter(string budLoad, string spray)
    {
        // Mosel 2016 was a heavy downy-mildew year in Germany (cited in disease.md)
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2013 });
        foreach (var b in g.Blocks) g.Apply(new Command { Type = "block", A = b.Data.Id, B = "budload", C = budLoad });
        g.Apply(new Command { Type = "programme", A = "spray", B = spray });
        while (g.Date.Year == g.FirstVintage)
        {
            g.Advance(7, stopAtAlerts: false);
            foreach (var b in g.Blocks.Where(b => !b.Harvested && !b.Picking && b.Veraison != null && (Chemistry.MustFromBlock(b).Oe >= 80 || b.LeafFall != null)))
                g.Apply(new Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Table" });
        }
        // the second Vintage is farmed identically in both games
        foreach (var b in g.Blocks) g.Apply(new Command { Type = "block", A = b.Data.Id, B = "budload", C = "Balanced" });
        g.Apply(new Command { Type = "programme", A = "spray", B = "Medium" });
        while (g.Blocks.Any(b => b.SetFraction < 0)) g.Advance(7, stopAtAlerts: false);
        return g;
    }

    [Fact]
    public void HardYear_ShrinksNextYearsCrop_ComparedWithACarefulYear()
    {
        var hard = YearTwoAfter("High", "Low");
        var careful = YearTwoAfter("Low", "High");
        Assert.True(hard.Blocks.Average(b => b.Reserves) < careful.Blocks.Average(b => b.Reserves));
        Assert.True(hard.Blocks.Average(b => b.Reserves) < 1.0);
        Assert.True(hard.Blocks.Sum(b => b.BerriesPerVine) < careful.Blocks.Sum(b => b.BerriesPerVine));
        Assert.All(hard.Blocks, b => Assert.Contains(b.Seasons, s => s.Year == hard.FirstVintage && s.ReservesAfter == b.Reserves));
    }
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator/sim && ~/.dotnet/dotnet test -v q --filter CarryOverTests 2>&1 | tail -5`
Expected: build FAILS: `'BlockState' does not contain a definition for 'Fruitfulness'`, `'VineyardModel' does not contain a definition for 'FruitfulnessFrom'`.

- [ ] **Step 3: Add the carry-over state**

In `BlockState.cs`, class `BlockState`, after `public double Chlorosis;` add:

```csharp
    // multi-vintage carry-over (canopy-and-yield.md §3.2 and §3.6; disease.md §8). All 1.0 until the first cropping season closes.
    public double Fruitfulness { get; set; } = 1.0;       // this season's bunches-per-shoot factor, set by last season's flowering weather
    public double FruitfulnessNext { get; set; } = 1.0;   // being set this season, 25 days after flowering
    public double Reserves { get; set; } = 1.0;           // carbohydrate reserves the vine went into this season with
    /// <summary>1991–2020 mean daily Tmean for this Block's microclimate, indexed by day of year (1–366). Null in bare model tests.</summary>
    public double[]? ClimNormalTmean { get; set; }
    public double FlowerWindowAnomSum, FlowerWindowExpSum; public int FlowerWindowDays;
    public double LeafAreaPeak, DownyLeafPeak, PowderyLeafPeak;
```

In class `SeasonRecord` add:

```csharp
    public double DownyLeafPeak { get; init; }
    public double PowderyLeafPeak { get; init; }
    public double CropLoadKgM2 { get; init; }
    public int PostHarvestDays { get; init; }
    public double Defoliation { get; init; }
    public double FruitfulnessNext { get; init; }
    public double ReservesAfter { get; init; }
```

- [ ] **Step 4: Implement the model**

In `VineyardModel.cs`:

1. Replace the first line of `StartSeason` (`if (b.SeasonYear > 0) b.Seasons.Add(Record(b));`) with:

```csharp
        if (b.SeasonYear > 0)
        {
            if (b.Leaf(b.SeasonYear) >= 4) CloseCarryOver(b);   // Establishment years drop their fruit and leave the vines neutral
            b.Seasons.Add(Record(b));
        }
        b.Fruitfulness = b.FruitfulnessNext; b.FruitfulnessNext = 1.0;
        b.FlowerWindowAnomSum = b.FlowerWindowExpSum = 0; b.FlowerWindowDays = 0;
        b.LeafAreaPeak = b.DownyLeafPeak = b.PowderyLeafPeak = 0;
```

2. Extend `Record` with the new properties (append inside the initializer):

```csharp
        DownyLeafPeak = b.DownyLeafPeak, PowderyLeafPeak = b.PowderyLeafPeak, CropLoadKgM2 = CarryInputs(b).CropLoad, PostHarvestDays = CarryInputs(b).PostHarvestDays,
        Defoliation = CarryInputs(b).Defoliation, FruitfulnessNext = b.FruitfulnessNext, ReservesAfter = b.Reserves,
```

3. Add these methods below `Record`:

```csharp
    /// <summary>Next season's bunches per shoot from the weather while the buds initiate inflorescences: warmth relative to the Block's
    /// normal and fruit-zone light (Buttrose 1969, 1974; canopy-and-yield.md §3.2). Coefficients UNVERIFIED.</summary>
    public static double FruitfulnessFrom(double tAnomC, double exposure) => M.Clamp(1 + 0.04 * tAnomC + 0.30 * (exposure - 0.45), 0.85, 1.15);

    /// <summary>Inputs to next season's reserves (canopy-and-yield.md §3.6). Crop load is kg fruit per m² of effective leaf area,
    /// the inverse of the ripening model's leaf-area-to-fruit ratio (0.55 × peak leaf area; balanced ≈ 1.0).</summary>
    public static (double CropLoad, int PostHarvestDays, double Defoliation) CarryInputs(BlockState b)
    {
        double cropPerVine = b.Harvested ? b.PickedKg / Math.Max(1, b.Vines) : b.CropKgPerVine;
        double cropLoad = cropPerVine / Math.Max(0.1, 0.55 * b.LeafAreaPeak);
        int post = b.HarvestDate != null && b.LeafFall != null ? Math.Max(0, b.LeafFall.Value.DayNumber - b.HarvestDate.Value.DayNumber) : 0;
        double defol = M.Clamp(b.DownyLeafPeak / 100 + 0.4 * b.PowderyLeafPeak / 100 + 0.01 * b.SevereStressDays, 0, 0.9);
        return (cropLoad, post, defol);
    }

    /// <summary>Reserves a season leaves behind (Bennett et al. 2005; Holzapfel et al. 2010): over-cropping, a short post-harvest canopy
    /// and early leaf loss deplete them; a light crop lets them recover. Coefficients UNVERIFIED.</summary>
    public static double SeasonReserves(double cropLoad, int postHarvestDays, double defoliation) =>
        M.Clamp(1 - 0.20 * Math.Max(0, cropLoad / 1.2 - 1) - 0.10 * Math.Max(0, 1 - postHarvestDays / 30.0) - 0.30 * defoliation + 0.05 * Math.Max(0, 1 - cropLoad / 0.6), 0.70, 1.05);

    private static void CloseCarryOver(BlockState b)
    {
        var (load, post, defol) = CarryInputs(b);
        b.Reserves = M.Clamp(0.4 * b.Reserves + 0.6 * SeasonReserves(load, post, defol), 0.70, 1.05);
    }

    /// <summary>1991–2020 mean Tmean per day of year for the Block's microclimate (the reference for the fruitfulness anomaly).</summary>
    public static double[] ClimNormalTmean(BlockState b, WeatherArchive archive)
    {
        var sum = new double[367]; var n = new int[367];
        for (int y = 1991; y <= 2020; y++)
        {
            if (!archive.Has(new DateOnly(y, 1, 1))) continue;
            for (var d = new DateOnly(y, 1, 1); d.Year == y; d = d.AddDays(1)) { sum[d.DayOfYear] += b.Climate.Adjust(archive.Get(d)).Tmean; n[d.DayOfYear]++; }
        }
        for (int i = 1; i <= 366; i++) sum[i] = n[i] > 0 ? sum[i] / n[i] : sum[i - 1];
        return sum;
    }
```

4. In `Step`, canopy section: change `double laShoot = 0.35 * vigour * (1 - 0.4 * stressMean) * ...` to `double laShoot = 0.35 * vigour * (0.8 + 0.2 * b.Reserves) * (1 - 0.4 * stressMean) * ...` (keep the rest of the expression).

5. In `Step`, right after the canopy `if (b.Budburst != null && b.LeafFall == null) { ... }` block closes, add:

```csharp
        // next season's fruitfulness: the weather while this season's buds initiate inflorescences, flowering → +25 days (canopy-and-yield.md §3.2)
        if (b.Flowering != null && leaf >= 4 && b.ClimNormalTmean != null)
        {
            int relF = date.DayNumber - b.Flowering.Value.DayNumber;
            if (relF >= 0 && relF <= 25) { b.FlowerWindowAnomSum += w.Tmean - b.ClimNormalTmean[doy]; b.FlowerWindowExpSum += b.Exposure; b.FlowerWindowDays++; }
            if (relF == 25 && b.FlowerWindowDays > 0) b.FruitfulnessNext = FruitfulnessFrom(b.FlowerWindowAnomSum / b.FlowerWindowDays, b.FlowerWindowExpSum / b.FlowerWindowDays);
        }
```

6. In the fruit-set block: change `b.SetFraction = v.BaseSet * fTemp * fRain * fCarb * coulure / Math.Max(0.3, 0.85);` to `b.SetFraction = v.BaseSet * fTemp * fRain * fCarb * coulure / Math.Max(0.3, 0.85) * Math.Min(1.0, b.Reserves);` and `b.BerriesPerVine = fruitfulShoots * v.ClustersPerShoot * v.BerriesPerCluster * setRatio;` to `b.BerriesPerVine = fruitfulShoots * v.ClustersPerShoot * b.Fruitfulness * v.BerriesPerCluster * setRatio;`.

7. At the very end of `Step`, after `Disease(b, w, ctx, seed);`, add:

```csharp
        b.LeafAreaPeak = Math.Max(b.LeafAreaPeak, b.LeafAreaPerVine);
        b.DownyLeafPeak = Math.Max(b.DownyLeafPeak, b.Disease.DownyLeaf);
        b.PowderyLeafPeak = Math.Max(b.PowderyLeafPeak, b.Disease.PowderyLeaf);
```

In `GameSession.cs`:

1. After the `foreach (var bd in Plot.Blocks) { ... }` loop in the constructor, add `foreach (var b in Blocks) b.ClimNormalTmean = VineyardModel.ClimNormalTmean(b, archive);`.
2. Declare `public double BaseDownyInoculum { get; } ` and `public double BasePowderyInoculum { get; }` next to `Ctx`, and after the `Ctx.PowderyInoculum = ...` line in the constructor set `BaseDownyInoculum = Ctx.DownyInoculum; BasePowderyInoculum = Ctx.PowderyInoculum;`.
3. In `StepDay`, directly after `foreach (var b in Blocks) VineyardModel.Step(b, w, Ctx, Setup.Seed);` add `if (Date.Month == 1 && Date.Day == 1) ApplyDiseaseCarryOver();`.
4. Add the methods (e.g. under `DailyCosts`):

```csharp
    /// <summary>Overwintering inoculum follows last season's mildew (disease.md §8): multiplier on this season's primary inoculum only.</summary>
    public static double InoculumCarry(double peakLeafPct) => M.Clamp(0.85 + 0.015 * peakLeafPct, 0.85, 1.30);

    private void ApplyDiseaseCarryOver()
    {
        var last = Blocks.Select(b => b.Seasons.LastOrDefault()).Where(s => s != null && s.Year == Date.Year - 1 && s.Leaf >= 4).Select(s => s!).ToList();
        if (last.Count == 0) return;
        Ctx.DownyInoculum = BaseDownyInoculum * InoculumCarry(last.Average(s => s.DownyLeafPeak));
        Ctx.PowderyInoculum = BasePowderyInoculum * InoculumCarry(last.Average(s => s.PowderyLeafPeak));
    }
```

- [ ] **Step 5: Run all tests**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator/sim && ~/.dotnet/dotnet test -v q 2>&1 | tail -3`
Expected: `Failed: 0` (the 25 original tests prove the first Vintage is unchanged).

- [ ] **Step 6: Calibration check over ten Vintages**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator/sim && for p in "mosel-seitental 2008" "cotedor-village 2008" "napa-bench 2008"; do TE_VINTAGES=10 ~/.dotnet/dotnet run --project src/TerroirEngine.Cli -- play $p 2>&1 | grep -E "Vintage\(s\) bottled"; done`
First add a per-Vintage yield summary to the CLI `play` command in `Program.cs`, directly after the `foreach (var b in g.Blocks) { ... }` block that prints Block lines:

```csharp
    foreach (var grp in g.Provenance.Values.GroupBy(p => p.Vintage).OrderBy(x => x.Key))
        Console.WriteLine($" Vintage {grp.Key}: mean yield {grp.Average(p => p.YieldHlHa):0} hL/ha, {grp.Average(p => p.HarvestOe):0} °Oe, rot {grp.Average(p => p.GreyRotPct):0.0} %");
    var ys = g.Provenance.Values.GroupBy(p => p.Vintage).Select(x => x.Average(p => p.YieldHlHa)).ToList();
    if (ys.Count > 1) { double mean = ys.Average(), sd = Math.Sqrt(ys.Average(v => (v - mean) * (v - mean))); Console.WriteLine($" Yield over {ys.Count} Vintages: mean {mean:0} hL/ha, CV {sd / mean * 100:0} %"); }
```

and re-run the loop above with `grep -E "Vintage\(s\) bottled|Yield over|^ Vintage"`. Expected: mean yields inside the per-Region ranges of `canopy-and-yield.md` §7, CV roughly 15–30 %, and no Vintage below 50 % of the ten-year mean without a frost or disease cause in its report. If a factor drives yields outside the ranges, narrow its coefficient (never widen the clamps) and record the change in the doc.

- [ ] **Step 7: Science documentation and glossary**

Verify the citations with WebSearch where possible (Buttrose 1969 *Bot. Gaz.* 130:166–173; Buttrose 1974 *Hort. Abstracts* 44:319–326; Bennett et al. 2005 *AJEV* 56:386–393; Holzapfel et al. 2010 *Hort. Reviews* 37:143–211; Grigg et al. 2018 *AJGWR* 24:75–87; Gadoury & Pearson 1990 *Phytopathology* 80:393–401; Rossi et al. 2008 *Ecol. Modelling* 212:480–491). Any you cannot confirm get "(cited from memory)".

In `docs/science/canopy-and-yield.md`:
- In §3.2 replace the "Game simplification (MVP)" sentence with: "**Model:** `FruitfulnessNext = clamp(1 + 0.04·T_anom + 0.30·(E − 0.45), 0.85, 1.15)`, where `T_anom` is the Block's mean temperature from flowering to 25 days after, minus its 1991–2020 mean for the same days, and `E` is mean fruit-zone exposure over the same window. It multiplies next season's clusters per shoot. Direction from Buttrose (1969, 1974): warmer and brighter conditions during inflorescence initiation raise fruitfulness. Coefficients `UNVERIFIED`. The first Vintage uses 1.0 (no previous season)."
- In §3.5, replace the `≥ 5` row's quality text with "1.0 — no quality bonus for older vines" and add below the table: "**Vine age and quality:** the game does not make older vines give better wine. Studies separating vine age from site and clone find mixed and small effects (Grigg et al. 2018), so a bonus would teach something the evidence does not support."
- Add a new section:

```markdown
### 3.6 Carbohydrate reserves (multi-vintage)

Starch stored in roots and trunk feeds budburst, early shoot growth and flowering until the new leaves export sugar. A crop that is large for the leaf area, a harvest so late that the leaves have little time to refill the reserves, and early leaf loss (downy mildew, drought, frost) all deplete them; the next season then has weaker shoots, fewer inflorescences and poorer fruit set (Bennett et al. 2005; Holzapfel et al. 2010).

**Model (at 1 January, for Blocks in their 4th leaf or older):**
- `cropLoad` = kg fruit per vine ÷ (0.55 × peak leaf area per vine), the inverse of the ripening model's leaf-area-to-fruit ratio; ≈ 1.0 is balanced (Kliewer & Dokoozlian 2005: 0.8–1.2 m² per kg).
- `postHarvestDays` = days from harvest to leaf fall.
- `defoliation` = peak downy leaf % + 0.4 × peak powdery leaf % (as fractions) + 0.01 per severe water-stress day, capped at 0.9.
- `seasonR = clamp(1 − 0.20·max(0, cropLoad/1.2 − 1) − 0.10·max(0, 1 − postHarvestDays/30) − 0.30·defoliation + 0.05·max(0, 1 − cropLoad/0.6), 0.70, 1.05)`
- `Reserves = clamp(0.4·Reserves_prev + 0.6·seasonR, 0.70, 1.05)`: vines recover over more than one year.
- Next season: shoot leaf-area growth × (0.8 + 0.2·Reserves); fruit-set ratio × min(1, Reserves).

All coefficients `UNVERIFIED`. **Calibration expectation:** over ten consecutive Vintages at Balanced bud load and Medium tiers, mean yields stay in the §7 ranges and the year-to-year coefficient of variation is roughly 15–30 % (`UNVERIFIED` band; record the measured values here).
```

In `docs/science/disease.md`, add a section (numbered after the last existing one):

```markdown
## Inoculum carry-over between Vintages

Downy mildew overwinters as oospores in fallen leaves and soil; powdery mildew as chasmothecia on the bark. A severe season leaves more of both, and the next spring's primary infections start from a larger source (Gadoury & Pearson 1990; Rossi et al. 2008).

**Model:** at 1 January the Region's primary inoculum for the new season is multiplied by `clamp(0.85 + 0.015 × peak leaf infection %, 0.85, 1.30)`, averaged over the Blocks, separately for downy and powdery mildew. It is not cumulative: each season starts again from the Region's base value. Coefficients `UNVERIFIED`. The first Vintage uses the base value.
```

In `CONTEXT.md`, under `### Management` (append at the end of that section), add:

```markdown
**Bud fruitfulness**:
How many bunches each shoot carries. It is set inside the buds around flowering of the previous Vintage, so warm, bright flowering weather means more bunches next year. Growers estimate it in winter by cutting buds open (bud dissection).
_Avoid_: Bud fertility, bud potential

**Vine reserves**:
The starch a vine stores in its roots and trunk after the harvest. It feeds the next spring's growth. A big crop, a late harvest or early leaf loss runs it down.
_Avoid_: Vine energy, vine health
```

In the spec (`docs/superpowers/specs/2026-09-28-multi-vintage-design.md`) §4.1, change "flowering −10 … +20 days" to "flowering … +25 days (the flowering date is only known once it happens)" and "Recorded at flowering + 20 days" to "Recorded at flowering + 25 days". In §3.5 and §8 replace "season" in player-facing strings: the message subject becomes "Vintage {year} begins" and the top bar "Vintage {year} · {n}th leaf" (CONTEXT.md: avoid "season").

- [ ] **Step 8: Commit**

```bash
cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator
git add sim docs/science CONTEXT.md docs/superpowers/specs
git commit -m "feat(sim): vines carry fruitfulness, reserves and mildew inoculum into the next Vintage

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: The January message and staff advice after the Mentor retires

**Files:**
- Modify: `sim/src/TerroirEngine.Core/Game/GameSession.cs`
- Modify: `sim/src/TerroirEngine.Core/Game/GameSession.Advisor.cs`
- Test: `sim/tests/TerroirEngine.Core.Tests/MultiVintageTests.cs`

**Interfaces:**
- Consumes: `BlockState.Fruitfulness`, `Reserves`, `GameSession.BaseDownyInoculum` (Task 3); `FinishedDate`, `MentorRetired` (Task 1).
- Produces: message kind `"newseason"` from role `"vineyard"` on 15 January of every Vintage after the first; after `MentorRetired`, seasonal messages (kinds `budburst`, `flowering`, `veraison`, `forced-harvest`, Côte d'Or `yield`) come from role `"vineyard"`, with an empty `Why` when the Vineyard manager is Junior.

- [ ] **Step 1: Write the failing tests**

Append to `MultiVintageTests.cs`:

```csharp
public class StaffAdviceTests
{
    [Fact]
    public void LaterVintages_BeginWithTheVineyardManagersMessage()
    {
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 2);
        var ns = g.Inbox.Single(m => m.Kind == "newseason" && m.Date == new DateOnly(g.FirstVintage + 1, 1, 15));
        Assert.Equal("vineyard", ns.Role);
        Assert.StartsWith($"Vintage {g.FirstVintage + 1} begins", ns.Subject);
        Assert.Contains("buds", ns.Body);
        Assert.Contains(ns.Actions, a => a.Action == "goto" && a.Arg == "plot");
        Assert.DoesNotContain(g.Inbox, m => m.Kind == "newseason" && m.Date.Year == g.FirstVintage);
    }

    [Fact]
    public void AfterRetirement_SeasonalAdviceComesFromStaff_JuniorsWithoutTheWhy()
    {
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 3);
        var later = g.Inbox.Where(m => m.Date > g.FinishedDate && m.Kind is "budburst" or "flowering" or "veraison").ToList();
        Assert.NotEmpty(later);
        Assert.All(later, m => Assert.Equal("vineyard", m.Role));
        Assert.All(later, m => Assert.Equal("", m.Why));   // default staff are Junior
        Assert.DoesNotContain(g.Inbox, m => m.Date > g.FinishedDate && m.Role == "mentor" && m.Kind is "budburst" or "flowering" or "veraison" or "forced-harvest" or "yield");
    }
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator/sim && ~/.dotnet/dotnet test -v q --filter StaffAdviceTests 2>&1 | tail -5`
Expected: FAIL — `Sequence contains no matching element` (no `newseason` message) and role `mentor` found after retirement.

- [ ] **Step 3: Seasonal sender and Junior brevity**

In `GameSession.Advisor.cs` add, next to `Gate`:

```csharp
    /// <summary>Who sends the seasonal advice: the Mentor in the first Vintage, then your own Vineyard manager (multi-vintage design §7).</summary>
    private string SeasonalRole => MentorRetired ? "vineyard" : "mentor";
    /// <summary>Advice is correct at every Staff level; a Junior gives it without the explanation (spec §5.4).</summary>
    private string SeasonalWhy(string why) => MentorRetired && VineyardManager == StaffLevel.Junior ? "" : why;
```

Then in `HandleEvents`, for the `budburst`, `flowering` and `veraison` posts change `Post("mentor", ...` to `Post(SeasonalRole, ...` and wrap their `why` argument in `SeasonalWhy(...)`. In `Advisor()`, change the yield post's role expression `Region.Id == "cote-dor" ? "mentor" : "vineyard"` to `Region.Id == "cote-dor" ? SeasonalRole : "vineyard"`, and the forced-harvest `Post("mentor", ...` to `Post(SeasonalRole, ...` with its why wrapped in `SeasonalWhy(...)`.

- [ ] **Step 4: The January message**

In `GameSession.cs`, in `StepDay` directly before `Advisor();` add:

```csharp
        if (Phase == GamePhase.Running && Date.Month == 1 && Date.Day == 15 && Date.Year > FirstVintage && Gate($"newseason-{Date.Year}")) NewSeasonMessage();
```

and add the method (e.g. below `IntroMessages`):

```csharp
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
            SeasonalWhy("Next year's bunches form inside the buds around this year's flowering, so warm, bright flowering weather means more bunches next year (Buttrose 1974). Stored starch feeds the spring flush; a heavy crop, a late harvest or early leaf loss runs it down (Bennett et al. 2005). Once vines are mature, age alone does not make better wine: the evidence is mixed (Grigg et al. 2018)."),
            "high", "newseason", stop: true);
        m.Actions.Add(("Open Plot & Blocks", "goto", "plot"));
    }
```

- [ ] **Step 5: Run all tests**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator/sim && ~/.dotnet/dotnet test -v q 2>&1 | tail -3`
Expected: `Failed: 0`.

- [ ] **Step 6: Commit**

```bash
cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator
git add sim
git commit -m "feat(sim): January bud-dissection message; staff take over the Mentor's seasonal advice

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Vintage statement on the label, and overdraft interest

**Files:**
- Modify: `sim/src/TerroirEngine.Core/Tasting/Wine.cs` (`Wine`, `Law`)
- Modify: `sim/src/TerroirEngine.Core/Game/GameSession.cs` (`CreateWine`, `DailyCosts`, overdraft message)
- Modify: `sim/src/TerroirEngine.Core/Game/Economy.cs` (`EconomyTables`)
- Modify: `docs/science/law.md`, `docs/science/economy.md`, `CONTEXT.md`
- Test: `sim/tests/TerroirEngine.Core.Tests/MultiVintageTests.cs`

**Interfaces:**
- Consumes: `Lot.Vintage`, `FirstVintage` (Task 1).
- Produces: `int? Wine.Vintage`; `static (int? Year, string? Note) Law.VintageStatement(IEnumerable<(int Vintage, double Litres)> parts, string regionId)`; labels prefixed `"{year} "` or `"Non-vintage "`; `const double EconomyTables.OverdraftRate = 0.09`; `static double EconomyTables.OverdraftInterest(double cash)`; ledger category `"Interest"`.

- [ ] **Step 1: Write the failing tests**

Append to `MultiVintageTests.cs`:

```csharp
public class VintageLawAndMoneyTests
{
    [Theory]
    [InlineData("mosel", 0.90, true)]
    [InlineData("napa", 0.90, false)]
    [InlineData("cote-dor", 0.80, false)]
    [InlineData("napa", 0.96, true)]
    [InlineData("mosel", 1.00, true)]
    public void VintageStatement_FollowsEuAndUsThresholds(string region, double share, bool vintage)
    {
        var parts = share >= 1 ? new[] { (2020, 100.0) } : new[] { (2020, share * 100), (2019, (1 - share) * 100) };
        var (year, note) = Law.VintageStatement(parts, region);
        Assert.Equal(vintage ? 2020 : (int?)null, year);
        Assert.Equal(vintage, note == null);
    }

    [Fact]
    public void CrossVintageBlend_InNapa_IsNonVintage()
    {
        // hold the first Vintage's Lots unbottled until the second Vintage's are ready, then blend 50/50
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "napa-carneros", PlantingYear = 2016 });
        int guard = 0;
        while (!g.Lots.Any(l => l.Vintage == g.FirstVintage + 1 && l.Phase == LotPhase.Ready) && guard++ < 60)
        {
            g.Advance(30, stopAtAlerts: false);
            foreach (var b in g.Blocks.Where(b => !b.Harvested && !b.Picking && b.Veraison != null && (Chemistry.MustFromBlock(b).Oe >= 100 || b.LeafFall != null)))
                g.Apply(new Command { Type = "harvest", A = b.Data.Id, B = "hand", C = "Table" });
            foreach (var lot in g.Lots.Where(l => l.Phase == LotPhase.Stuck).ToList()) g.Apply(new Command { Type = "restart", A = lot.Id });
        }
        var a = g.Lots.First(l => l.Vintage == g.FirstVintage && l.Phase == LotPhase.Ready);
        var b2 = g.Lots.First(l => l.Vintage == g.FirstVintage + 1 && l.Phase == LotPhase.Ready);
        double litres = Math.Min(a.VolumeL, b2.VolumeL);
        g.Apply(new Command { Type = "wine", A = "Two-Vintage blend", E = FormattableString.Invariant($"{a.Id}:{litres:0.0};{b2.Id}:{litres:0.0}") });
        var w = g.Wines.Last();
        Assert.Null(w.Vintage);
        Assert.StartsWith("Non-vintage", w.Legal!.Label);
        Assert.Contains(w.Legal.Notes, n => n.Contains("non-vintage"));
    }

    [Fact]
    public void SingleVintageWine_StatesItsYear()
    {
        var g = Fixture.Play("mosel-seitental", 2014, 80);
        Assert.All(g.WinesOf(g.FirstVintage), w => { Assert.Equal(g.FirstVintage, w.Vintage); Assert.StartsWith($"{g.FirstVintage} ", w.Legal!.Label); });
    }

    [Fact]
    public void OverdraftInterest_IsChargedMonthly_OnlyWhileOverdrawn()
    {
        Assert.Equal(0.0, EconomyTables.OverdraftInterest(1000));
        Assert.Equal(-75.0, EconomyTables.OverdraftInterest(-10000), 6);   // 9 % a year on €10,000, one month
        // the Premier Cru Plot costs more than the starting capital: overdrawn from day one
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "cotedor-premiercru", PlantingYear = 2015 });
        g.Advance(100, stopAtAlerts: false);
        double running = 0; int n = 0;
        foreach (var e in g.Ledger.Entries)
        {
            if (e.Category == "Interest") { Assert.True(running < 0); Assert.Equal(running * EconomyTables.OverdraftRate / 12, e.Amount, 0); n++; }
            running += e.Amount;
        }
        Assert.InRange(n, 3, 4);
        var rich = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2015 });
        rich.Advance(100, stopAtAlerts: false);
        Assert.DoesNotContain(rich.Ledger.Entries, e => e.Category == "Interest");
    }
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator/sim && ~/.dotnet/dotnet test -v q --filter VintageLawAndMoneyTests 2>&1 | tail -5`
Expected: build FAILS: `'Law' does not contain a definition for 'VintageStatement'`, `'EconomyTables' does not contain a definition for 'OverdraftInterest'`.

- [ ] **Step 3: Implement the vintage statement**

In `Wine.cs`, class `Wine`, after `public double BottlingCost { get; set; }` add `public int? Vintage { get; set; }   // the year on the label; null = non-vintage`.

In class `Law`, above `QualityMultiplier`, add:

```csharp
    /// <summary>May the label state a vintage year? EU: ≥ 85 % of the grapes harvested that year (Reg. (EU) 2019/33, Art. 49).
    /// USA: ≥ 95 % when the label names an AVA, else 85 % (27 CFR 4.27); every Napa label here names an AVA.</summary>
    public static (int? Year, string? Note) VintageStatement(IEnumerable<(int Vintage, double Litres)> parts, string regionId)
    {
        var list = parts.ToList();
        double total = Math.Max(1e-9, list.Sum(p => p.Litres));
        var top = list.GroupBy(p => p.Vintage).Select(g => (year: g.Key, share: g.Sum(x => x.Litres) / total)).OrderByDescending(x => x.share).First();
        double need = regionId == "napa" ? 0.95 : 0.85;
        if (top.share >= need - 1e-9) return (top.year, null);
        return (null, $"Only {top.share * 100:0} % of this wine is from {top.year}: a vintage year on the label needs ≥ {need * 100:0} % from that year ({(regionId == "napa" ? "US rules for a wine naming an AVA" : "EU rules")}). It is sold as non-vintage.");
    }
```

In `GameSession.cs` `CreateWine`, directly after `wine.Legal = Law.Evaluate(wine, parts, Plot, Date);` add:

```csharp
        var (vintageYear, vintageNote) = Law.VintageStatement(parts.Select(p => (p.lot.Vintage, p.litres)), Region.Id);
        wine.Vintage = vintageYear;
        if (vintageNote != null) wine.Legal.Notes.Add(vintageNote);
        wine.Legal = wine.Legal with { Label = vintageYear != null ? $"{vintageYear} {wine.Legal.Label}" : $"Non-vintage {wine.Legal.Label}" };
```

and change the price's young-vine factor from `(wine.Blend.Harvested.Year == FirstVintage ? 0.95 : 1)` to `(wine.Vintage == FirstVintage ? 0.95 : 1)`.

- [ ] **Step 4: Implement overdraft interest**

In `Economy.cs`, class `EconomyTables`, add:

```csharp
    /// <summary>Overdraft interest, a year rate charged monthly (economy.md §10; UNVERIFIED design value — euro-area business overdrafts run in the high single digits).</summary>
    public const double OverdraftRate = 0.09;
    public static double OverdraftInterest(double cash) => cash < 0 ? cash * OverdraftRate / 12 : 0;
```

In `GameSession.DailyCosts`, inside `if (Date.Day == 1) { ... }`, after the Staff post add:

```csharp
            double interest = EconomyTables.OverdraftInterest(Ledger.Cash);
            if (interest < 0) Ledger.Post(Date, "Interest", interest, $"Overdraft interest ({EconomyTables.OverdraftRate * 100:0} % a year)");
```

In `StepDay`'s overdraft message, replace "In this version the bank carries the debt until the wine is sold, but lower Programme tiers or cheaper staff reduce what you spend." with "The bank carries the debt, but charges {EconomyTables.OverdraftRate * 100:0} % a year interest every month until you are back in credit. Lower Programme tiers or cheaper staff reduce what you spend." and its why text with "Game simplification: an overdraft with a fixed rate instead of loans (backlog: full economics). The rate is a design value (UNVERIFIED)."

- [ ] **Step 5: Run all tests**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator/sim && ~/.dotnet/dotnet test -v q 2>&1 | tail -3`
Expected: `Failed: 0`.

- [ ] **Step 6: Documentation**

Verify with WebSearch: Commission Delegated Regulation (EU) 2019/33, Article 49 (vintage year, 85 %); 27 CFR 4.27 (vintage wine: 95 % with a viticultural area, 85 % otherwise). Mark anything unconfirmed "(cited from memory)".

In `docs/science/law.md` add:

```markdown
## Vintage statement (multi-vintage)

- **EU (Mosel, Côte d'Or):** a label may show a harvest year only if at least 85 % of the grapes were harvested in that year (Commission Delegated Regulation (EU) 2019/33, Art. 49).
- **USA (Napa):** a vintage date needs at least 95 % of the wine from that year when the label names an American Viticultural Area, 85 % otherwise (27 CFR 4.27). Every Napa wine in the game names an AVA, so 95 % applies.
- Below the threshold the wine is **non-vintage**: the label drops the year and a legal note explains why. No price discount is modelled (no source for its size).
```

In `docs/science/economy.md` add a section "Overdraft interest": "Game simplification: a negative cash balance is carried by the bank at 9 % a year, charged monthly on the balance at the start of the month (`UNVERIFIED` design value; euro-area small-business overdraft rates are typically in the high single digits). Loans stay in the backlog."

In `CONTEXT.md`, under `### Time and weather` after **Vintage**, add:

```markdown
**Non-vintage**:
A Wine blended from more than one Vintage, with too little of any one year to put a year on the label (EU: under 85 %; a Napa AVA wine: under 95 %).
_Avoid_: NV blend, multi-year wine
```

- [ ] **Step 7: Commit**

```bash
cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator
git add sim docs/science CONTEXT.md
git commit -m "feat(sim): vintage statement on labels (EU 85 %, US AVA 95 %) and monthly overdraft interest

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Snapshot for multi-vintage play, and the replay budget

**Files:**
- Modify: `sim/src/TerroirEngine.Core/Game/VintageReport.cs` (new `HistoryRow`)
- Modify: `sim/src/TerroirEngine.Core/Game/Snapshot.cs`
- Test: `sim/tests/TerroirEngine.Core.Tests/MultiVintageTests.cs`

**Interfaces:**
- Consumes: everything above.
- Produces snapshot keys: `phase` (`"Establishment"`/`"Running"`), `firstVintage` (int), `seasonLabel` (`"Vintage 2022 · 5th leaf"`), `season` (`"Dormant"|"Growing"|"Harvest"|"PostHarvest"`), `quiet` (bool), `bottledVintages` (int array), `history` (array of `{vintage, winkler, winklerNormal, rain, rainNormal, budburst, harvest, yieldHl, status, wines:[{name, quality, bottles, revenue}], sales}`, newest first; `status` ∈ `"In bottle"|"In the cellar"|"Growing"`), `years` (array of `{year, costs, sales, interest, cashEnd}`), `lots[].vintage`, `wines[].vintage` (int or null).

- [ ] **Step 1: Write the failing tests**

Append to `MultiVintageTests.cs`:

```csharp
public class MultiVintageSnapshotTests
{
    [Fact]
    public void Snapshot_HasHistoryYearsAndVintagedLots()
    {
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 2);
        var s = Snapshot.Build(g);
        Assert.Equal("Running", s["phase"]!.GetValue<string>());
        Assert.Equal(g.FirstVintage, s["firstVintage"]!.GetValue<int>());
        Assert.StartsWith($"Vintage {g.Vintage} · ", s["seasonLabel"]!.GetValue<string>());
        var hist = s["history"]!.AsArray();
        Assert.Equal(g.Vintage - g.FirstVintage + 1, hist.Count);
        Assert.Equal(g.Vintage, hist[0]!["vintage"]!.GetValue<int>());
        Assert.Contains(hist, h => h!["vintage"]!.GetValue<int>() == g.FirstVintage && h["status"]!.GetValue<string>() == "In bottle" && h["wines"]!.AsArray().Count > 0);
        Assert.Equal(new[] { g.FirstVintage, g.FirstVintage + 1 }, s["bottledVintages"]!.AsArray().Select(x => x!.GetValue<int>()));
        Assert.All(s["lots"]!.AsArray(), l => Assert.InRange(l!["vintage"]!.GetValue<int>(), g.FirstVintage, g.Vintage));
        Assert.All(s["wines"]!.AsArray(), w => Assert.NotNull(w!["vintage"]));
        var years = s["years"]!.AsArray();
        Assert.Equal(g.Setup.PlantingYear, years[0]!["year"]!.GetValue<int>());
        Assert.Equal(Math.Round(g.Ledger.Cash), years[^1]!["cashEnd"]!.GetValue<double>(), 0);
    }

    [Fact]
    public void FiveVintageSave_LoadsWithinBudget_AndSnapshotStaysSmall()
    {
        var g = Fixture.PlayVintages("mosel-seitental", 2014, 80, vintages: 5);
        var sw = System.Diagnostics.Stopwatch.StartNew();
        var g2 = GameSession.Load(Fixture.Data, g.Save());
        long loadMs = sw.ElapsedMilliseconds;
        Assert.True(loadMs < 30_000, $"five-Vintage load took {loadMs} ms (budget 10 s on the owner's PC, 30 s CI headroom)");
        sw.Restart();
        string json = Snapshot.Json(g2);
        long snapMs = sw.ElapsedMilliseconds;
        Assert.True(json.Length < 400_000, $"snapshot is {json.Length / 1024} KB");
        Assert.True(snapMs < 500, $"snapshot took {snapMs} ms");
    }
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator/sim && ~/.dotnet/dotnet test -v q --filter MultiVintageSnapshotTests 2>&1 | tail -5`
Expected: FAIL — `NullReferenceException` / `firstVintage` missing.

- [ ] **Step 3: History row**

In `VintageReport.cs` add:

```csharp
    /// <summary>One row of the Vintage history table (Estate screen): weather against normal, dates, yield, wines and sales.</summary>
    public static JsonObject HistoryRow(GameSession g, int vintage)
    {
        var recs = Records(g, vintage);
        var y = Stats(g, vintage, recs.Select(r => r.Budburst).Where(d => d != null).Min());
        var n = Normal(g);
        var wines = g.WinesOf(vintage);
        var lots = g.Lots.Where(l => l.Vintage == vintage).ToList();
        double ha = Math.Max(0.01, g.Blocks.Sum(b => b.AreaHa));
        double hl = lots.Sum(l => l.GrapeKg * (l.Red ? 0.72 : 0.62) / 100.0) / ha;
        string status = g.IsVintageBottled(vintage) ? "In bottle" : lots.Count > 0 ? "In the cellar" : "Growing";
        return new JsonObject
        {
            ["vintage"] = vintage, ["winkler"] = Math.Round(y.Wi), ["winklerNormal"] = Math.Round(n.wi), ["rain"] = Math.Round(y.RainSeason), ["rainNormal"] = Math.Round(n.rainSeason),
            ["budburst"] = D(recs.Select(r => r.Budburst).Where(d => d != null).Min()), ["harvest"] = D(recs.Select(r => r.HarvestDate).Where(d => d != null).Max()),
            ["yieldHl"] = lots.Count > 0 ? Math.Round(hl) : null, ["status"] = status,
            ["wines"] = new JsonArray(wines.Select(w => (JsonNode)new JsonObject { ["name"] = w.Name, ["quality"] = w.Sheet?.Quality, ["bottles"] = w.Bottles, ["revenue"] = Math.Round(w.Revenue) }).ToArray()),
            ["sales"] = Math.Round(wines.Sum(w => w.Revenue)),
        };
    }
```

- [ ] **Step 4: Snapshot keys**

In `Snapshot.cs` `Build`, after `["vintage"] = g.Vintage,` add:

```csharp
            ["firstVintage"] = g.FirstVintage,
            ["seasonLabel"] = $"Vintage {g.Vintage} · {Ordinal(g.Vintage - g.Setup.PlantingYear + 1)} leaf",
            ["season"] = SeasonState(g),
            ["quiet"] = Quiet(g),
            ["bottledVintages"] = Arr(g.BottledVintages.Select(v => (JsonNode)v)),
            ["history"] = Arr(Enumerable.Range(g.FirstVintage, Math.Max(0, g.Vintage - g.FirstVintage + 1)).Reverse().Select(v => (JsonNode)VintageReport.HistoryRow(g, v))),
            ["years"] = YearsObj(g),
```

Add these helpers to `Snapshot`:

```csharp
    private static string SeasonState(GameSession g) =>
        g.Blocks.Any(b => b.Picking) ? "Harvest" : g.Blocks.All(b => b.Budburst == null) ? "Dormant" : g.Blocks.All(b => b.Harvested) ? "PostHarvest" : "Growing";

    /// <summary>Nothing growing, being picked or fermenting: the UI may take bigger steps.</summary>
    private static bool Quiet(GameSession g) =>
        g.Blocks.All(b => b.Budburst == null || b.Harvested) && !g.Blocks.Any(b => b.Picking)
        && !g.Lots.Any(l => l.Phase is LotPhase.Received or LotPhase.ColdSoak or LotPhase.Fermenting or LotPhase.Stuck or LotPhase.PostMaceration or LotPhase.Malolactic);

    /// <summary>Money by calendar year: costs (without interest), wine sales, overdraft interest and cash at the year's end.</summary>
    private static JsonArray YearsObj(GameSession g)
    {
        var arr = new JsonArray(); double cash = 0;
        foreach (var grp in g.Ledger.Entries.GroupBy(e => e.Date.Year).OrderBy(x => x.Key))
        {
            cash += grp.Sum(e => e.Amount);
            arr.Add(new JsonObject
            {
                ["year"] = grp.Key, ["costs"] = R(grp.Where(e => e.Amount < 0 && e.Category != "Interest").Sum(e => -e.Amount), 0),
                ["sales"] = R(grp.Where(e => e.Category == "Sales").Sum(e => e.Amount), 0), ["interest"] = R(grp.Where(e => e.Category == "Interest").Sum(e => -e.Amount), 0), ["cashEnd"] = R(cash, 0),
            });
        }
        return arr;
    }
```

In `LotObj` add `["vintage"] = l.Vintage,`; in `WineObj` add `["vintage"] = w.Vintage,`.

- [ ] **Step 5: Run all tests and record the load time**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator/sim && ~/.dotnet/dotnet test -v q 2>&1 | tail -3`
Expected: `Failed: 0`.
Then: `TE_VINTAGES=5 ~/.dotnet/dotnet run --project src/TerroirEngine.Cli -- play mosel-seitental 2014 2>&1 | grep -E "Save/replay|Snapshot JSON"` and note the replay ms and snapshot KB for the playtest report (Task 8). If replay exceeds 10 s, stop and report: the spec's fallback (in-memory checkpoints) is a follow-up, not part of this plan.

- [ ] **Step 6: Commit**

```bash
cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator
git add sim
git commit -m "feat(sim): snapshot carries Vintage history, yearly money, bottled Vintages and per-Lot Vintage

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: The screens

**Files:**
- Modify: `game/src/ui/shell.gd` (`advance`, `continue_days`, `toggle_play`, `_play_tick`, `_topbar`, `_run_capture`, `_run_fuzz`)
- Modify: `game/src/ui/screens/report.gd`, `game/src/ui/screens/estate.gd`, `game/src/ui/screens/winery.gd`, `game/src/ui/screens/blending.gd`, `game/src/ui/onboarding.gd`
- Test: `scripts/fuzz.sh`, `scripts/capture.sh`, screenshots in `game/shots/`

**Interfaces:**
- Consumes: the snapshot keys from Tasks 2 and 6; sim `flag` command (persists UI state in the save).
- Produces: UI flag `report_<vintage>` (report auto-opened once per Vintage); `shell.state["report_vintage"]` (selected Vintage on the report screen).

- [ ] **Step 1: Shell time controls and report auto-open**

In `shell.gd` `advance()`, replace

```gdscript
	if String(D.get("phase", "")) == "Finished" and not state.get("report_shown", false):
		state["report_shown"] = true
		_build_chrome(); show_screen("report")
		return false
```

with

```gdscript
	# open each Vintage report once, the first time its Vintage is fully bottled (the flag lives in the save)
	var fl: Array = D.get("flags", [])
	for bv in D.get("bottledVintages", []):
		var key := "report_%d" % int(bv)
		if not fl.has(key):
			Sim.Command("flag", key, "", "", "", "")
			D = JSON.parse_string(Sim.Snapshot())
			state["report_vintage"] = int(bv)
			_build_chrome(); show_screen("report")
			return false
```

Replace `continue_days()`'s body with `return 120 if D.get("quiet", false) else 60` and its comment with `## Continue jumps further when nothing is growing or fermenting (design review §1).`

In `toggle_play()`: `playing = not playing and String(D.get("phase", "")) != "Finished"` → `playing = not playing`. In `_play_tick()`: `if alert or String(D.get("phase", "")) == "Finished":` → `if alert:`.

In `_topbar()`: delete `var finished: bool = String(D.get("phase", "")) == "Finished"` and the three `... .disabled = finished` / `b.disabled = finished` assignments. Change the stage label line to

```gdscript
	var st := UI.label("%s · %s" % [String(D.get("seasonLabel", "")), String(D.get("stage", ""))], 13, UI.INK2); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; dv.add_child(st)
```

In `blending.gd` (the bottle button handler), replace the `if String(shell.D.get("phase", "")) == "Finished" and not shell.state.get("report_shown", false): ...` block with nothing: the report now opens from `advance()` (next time step) — and add, before `shell.show_screen("wines")`, the same once-per-Vintage check so bottling the last Lot opens the report immediately:

```gdscript
			var fl2: Array = shell.D.get("flags", [])
			for bv in shell.D.get("bottledVintages", []):
				if not fl2.has("report_%d" % int(bv)):
					Sim.Command("flag", "report_%d" % int(bv), "", "", "", "")
					shell.D = JSON.parse_string(Sim.Snapshot())
					shell.state["report_vintage"] = int(bv)
					shell._build_chrome(); shell.show_screen("report")
					shell.notify("That was the last Lot of the %d Vintage: here is its report." % int(bv))
					return
```

Run: `grep -rn '"Finished"\|"Cellar"\|report_shown' /mnt/c/Users/Aleksander/src/repos/winegamesimulator/game/src`
Expected: no output (other than the capture loop fixed in Step 5).

- [ ] **Step 2: Report screen with a Vintage selector**

In `report.gd` `build()`, replace the first lines up to `var W: Dictionary = R["weather"]` with:

```gdscript
	var reps: Array = D.get("reports", [])
	var v := UI.vbox(16)
	if reps.is_empty():
		v.add_child(UI.page_header("Vintage report", "A Vintage's report appears when every one of its Lots is in bottle."))
		return v
	var want := int(shell.state.get("report_vintage", int(reps[0]["vintage"])))
	var R: Dictionary = reps[0]
	for r in reps:
		if int(r["vintage"]) == want: R = r
	if reps.size() > 1:
		var labels := []
		for r in reps: labels.append(str(int(r["vintage"])))
		v.add_child(UI.segmented(labels, str(int(R["vintage"])), func(x): shell.state["report_vintage"] = int(x); shell.show_screen("report"), 90))
	var W: Dictionary = R["weather"]
```

Change the weekly chart source from `D.get("weather", {}).get("weekly", [])` to `R.get("weekly", [])`. Change the money panel subtitle `"this Vintage"` to `"costs in %d, sales of its wines" % int(R["vintage"])`. Wrap the Mentor's farewell panel (the `fp` block through `v.add_child(fp)`) in `if R.get("farewell", false):`.

- [ ] **Step 3: Estate — Vintage history and money by year**

In `estate.gd`, replace `if String(D.get("phase", "")) == "Finished": v.add_child(_finished(D, shell))` with

```gdscript
	if D.get("history", []).size() > 0 and D.get("bottledVintages", []).size() > 0: v.add_child(_history(D, shell))
```

update the file's first comment to `# Estate: cash, P&L by category, ledger, staff, Establishment history, and the Vintage history across the years.`, and replace the `_finished` function with:

```gdscript
static func _history(D: Dictionary, shell) -> Control:
	var p: Array = UI.panel("Vintage history", "every Vintage on this Estate, newest first")
	var g := GridContainer.new(); g.columns = 9; g.add_theme_constant_override("h_separation", 22); g.add_theme_constant_override("v_separation", 8)
	for h in ["Vintage", "Heat (Winkler)", "Rain Apr–Oct", "Budburst", "Harvest", "hL/ha", "Wines", "Sales", ""]:
		g.add_child(UI.label(h, 13, UI.MUTED, UI.f_body_b))
	for r in D.get("history", []):
		var vin := int(r["vintage"])
		g.add_child(UI.num(str(vin), 16))
		g.add_child(UI.num("%d (normal %d)" % [int(r["winkler"]), int(r["winklerNormal"])], 14, UI.INK2))
		g.add_child(UI.num("%d mm (normal %d)" % [int(r["rain"]), int(r["rainNormal"])], 14, UI.INK2))
		g.add_child(UI.num(String(r["budburst"]) if r["budburst"] != null else "—", 14, UI.INK2))
		g.add_child(UI.num(String(r["harvest"]) if r["harvest"] != null else "—", 14, UI.INK2))
		g.add_child(UI.num(str(int(r["yieldHl"])) if r["yieldHl"] != null else "—", 14))
		var wl := []
		for w in r["wines"]: wl.append("%s · %s" % [w["name"], w["quality"]])
		var wlab := UI.label(", ".join(wl) if wl.size() > 0 else "—", 13, UI.INK2, null, true); wlab.custom_minimum_size = Vector2(300, 0)
		g.add_child(wlab)
		g.add_child(UI.num(UI.euro(int(r["sales"])) if int(r["sales"]) > 0 else "—", 14))
		if String(r["status"]) == "In bottle":
			var rb := UI.button("Report", false, 13)
			rb.pressed.connect(func(): shell.state["report_vintage"] = vin; shell.show_screen("report"))
			g.add_child(rb)
		else:
			g.add_child(UI.label(String(r["status"]), 13, UI.MUTED))
	p[1].add_child(g)
	p[1].add_child(UI.divider())
	p[1].add_child(UI.label("Money by calendar year", 14, UI.INK, UI.f_body_b))
	for y in D.get("years", []):
		var extra := (" · interest %s" % UI.euro(int(y["interest"]))) if float(y["interest"]) > 0 else ""
		p[1].add_child(UI.kv(str(int(y["year"])), "costs %s · sales %s%s · cash at year end %s" % [UI.euro(int(y["costs"])), UI.euro(int(y["sales"])), extra, UI.euro(int(y["cashEnd"]))]))
	return p[0]
```

- [ ] **Step 4: Lots grouped by Vintage; onboarding only in the first Vintage**

In `winery.gd` `build()`, directly after the `for l in D.get("lots", []): if ...: lots.append(l)` loop, add:

```gdscript
	lots.sort_custom(func(a, b): return int(a["vintage"]) > int(b["vintage"]) or (int(a["vintage"]) == int(b["vintage"]) and String(a["id"]) < String(b["id"])))
```

and in the tab loop (`for l in lots:` that builds `tabs`), declare `var last_v := -1` before it and add at the top of the loop body:

```gdscript
		if int(l["vintage"]) != last_v:
			last_v = int(l["vintage"])
			var vl := UI.label(str(last_v), 14, UI.GOLD, UI.f_body_b); vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tabs.add_child(vl)
```

In `blending.gd`, sort `ready` the same way right after it is built, add the same Vintage heading inside `for l in ready:` (into `lp[1]`, using `UI.label(str(last_v), 14, UI.GOLD, UI.f_body_b)`), and in the composition block (after `comp` is filled) add vintage shares:

```gdscript
		var vins := {}
		for l in ready:
			var shv := int(B["parts"].get(l["id"], 0))
			if shv > 0: vins[int(l["vintage"])] = float(vins.get(int(l["vintage"]), 0.0)) + float(l["volume"]) * shv / 100.0
		if vins.size() > 1:
			var vt := []
			for yv in vins: vt.append("%d %% %d" % [roundi(100.0 * float(vins[yv]) / total), yv])
			bp[1].add_child(UI.kv("Vintages", ", ".join(vt)))
			notes.append("A year on the label needs ≥ %d %% of the wine from that Vintage; otherwise it is sold as non-vintage." % (95 if String(D["region"]["id"]) == "napa" else 85))
```

(place the `vins` block before `for n in notes:` so the note is shown). In "Bottled so far", prefix each line with the Vintage: `wp[1].add_child(UI.kv(String(w["name"]), ...))` → `UI.kv("%s %s" % [str(int(w["vintage"])) if w.get("vintage") != null else "NV", String(w["name"])], ...)`.

In `onboarding.gd`, replace `enabled()`'s body with:

```gdscript
	return not flags(D).has("plan_hidden") and not bool(D.get("mentor", {}).get("retired", false))
```

and its doc comment with `## The Mentor's plan belongs to the first Vintage only.`

- [ ] **Step 5: Capture and fuzz across two Vintages**

In `shell.gd` `_run_capture`, change `while String(D.get("phase", "")) != "Finished" and guard < 40:` to `while D.get("bottledVintages", []).is_empty() and guard < 40:`. After the `show_screen("glossary"); await _shot(...)` line and before the save/load round trip, add a second-Vintage pass:

```gdscript
	# second Vintage: the January message, the history, and a report selector with two Vintages
	for m in D.get("inbox", []):
		if String(m.get("kind", "")) == "newseason": state["inbox_sel"] = int(m["id"])
	_build_chrome(); show_screen("inbox"); await _shot("%s_17_newseason" % prefix)
	guard = 0
	while D.get("bottledVintages", []).size() < 2 and guard < 40:
		guard += 1
		Sim.Advance(30, false); D = JSON.parse_string(Sim.Snapshot())
		for b in D["blocks"]:
			if not b["harvested"] and not b["picking"] and (b.get("inWindow", false) or String(b.get("stage", "")) == "Leaf fall"):
				Sim.Command("harvest", b["id"], "hand", "Table", "", "")
		for l in D["lots"]:
			if l.get("ready", false): Sim.Command("wine", "%s %s" % [l["variety"], l["block"]], "Screwcap", "Sterile", "Bentonite", l["id"])
			if l.get("stuck", false): Sim.Command("acceptstuck" if l.get("restarted", false) else "restart", l["id"], "", "", "", "")
		D = JSON.parse_string(Sim.Snapshot())
	_build_chrome()
	show_screen("estate"); await _shot("%s_18_history" % prefix)
	state["report_vintage"] = int(D["firstVintage"])
	show_screen("report"); await _shot("%s_19_report_selector" % prefix)
	show_screen("winery"); await _shot("%s_20_winery_vintages" % prefix)
```

In `_run_fuzz`, change `for stop_at in [0, 200, 60, 200]:` to `for stop_at in [0, 200, 60, 200, 300]:` so the fuzz presses every button in the second Vintage's harvest season too.

- [ ] **Step 6: Build and run the UI checks**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator && ./scripts/build-game.sh && ./scripts/fuzz.sh 2>&1 | tail -15`
Expected: `FUZZ round done` five times, `FUZZ DONE`, no `SCRIPT ERROR` lines.
Run: `./scripts/capture.sh mosel-seitental 2014 2>&1 | grep -E "SAVE/LOAD|CAPTURE DONE|ERROR"`
Expected: `SAVE/LOAD ok`, `CAPTURE DONE`, no `ERROR`.
Open and inspect with the Read tool: `game/shots/mosel_17_newseason.png`, `mosel_18_history.png`, `mosel_19_report_selector.png`, `mosel_20_winery_vintages.png`, and the top bar in any shot. Check: the January message reads cleanly; the history table fits without overlapping columns; the selector shows two Vintages and the first one's farewell panel; Lots show Vintage headings. Fix layout problems before committing.
Run: `timeout 120 ./scripts/godot.sh -- --perf 2>&1 | tr -d '\r' | grep PERF` and confirm screen builds stay near the earlier numbers (inbox ≈ 35 ms, plot ≈ 106 ms).

- [ ] **Step 7: Commit**

```bash
cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator
git add game/src
git commit -m "feat(game): multi-vintage screens — Vintage history, report selector, Lots by Vintage

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Standalone build and playtest report

**Files:**
- Create: `docs/playtest/2026-09-28-multi-vintage.md`
- Modify: `docs/backlog.md`, `README.md`

- [ ] **Step 1: Full test and UI pass**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator/sim && ~/.dotnet/dotnet test -v q 2>&1 | tail -2` — expected `Failed: 0`.
Run the CLI across Regions: `for p in "mosel-blauschiefer 2012" "cotedor-premiercru 2012" "napa-bench 2012"; do TE_VINTAGES=4 ~/.dotnet/dotnet run --project src/TerroirEngine.Cli -- play $p 2>&1 | grep -E "Vintage\(s\) bottled|Save/replay|== "; done` and keep the output for the report.

- [ ] **Step 2: Rebuild the Windows build**

Run: `cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator && ./scripts/export-windows.sh 2>&1 | tail -3`
Then smoke-test the exe: `cd build/TerroirEngine && timeout 120 ./TerroirEngine.exe --log-file "$(wslpath -w $CLAUDE_JOB_DIR/tmp)\\exe.log" -- --perf >/dev/null 2>&1; tr -d '\r' < $CLAUDE_JOB_DIR/tmp/exe.log | grep -E "PERF tab|ERROR"`
Expected: a `PERF tab switch` line and no `ERROR`.

- [ ] **Step 3: Write the playtest report and update the backlog**

Create `docs/playtest/2026-09-28-multi-vintage.md` with: what changed for the player (continuous play, January message, Vintage history, report selector, non-vintage blends, overdraft interest); the ten-Vintage calibration numbers from Task 3 Step 6 (mean yield and CV per Region); the replay time and snapshot size from Task 6; screenshots referenced by path; known limits (carry-over coefficients `UNVERIFIED`, wine still sold at bottling, no loans, soil refills every winter); and three things for the owner to try (e.g. over-crop one Block with High bud load and watch the next January message; blend two Vintages in Napa; play past 2025 into Synthetic weather).

In `docs/backlog.md`, replace the "First expansion" bullet with: "- ~~Multi-vintage play on the Timeline~~ — done 2026-09-28 (spec `docs/superpowers/specs/2026-09-28-multi-vintage-design.md`). Follow-ups: selling wine over time (stock and markets), replanting and top-grafting, phylloxera on own-rooted vines, in-memory replay checkpoints if long games load slowly."

In `README.md`, in the first paragraph, change "and farm a Vintage on the weather that really happened" to "and farm Vintage after Vintage on the weather that really happened".

- [ ] **Step 4: Commit**

```bash
cd /mnt/c/Users/Aleksander/src/repos/winegamesimulator
git add docs/playtest docs/backlog.md README.md
git commit -m "docs: multi-vintage playtest report; backlog and README updated

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```
