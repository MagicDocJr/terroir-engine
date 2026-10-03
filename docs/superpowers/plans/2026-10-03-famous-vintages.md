# Famous Vintages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** three replayable famous-vintage scenarios (Côte d'Or 2016, Mosel 2018, Napa 2011) with bronze, silver and gold
goals judged by the sim and a cited debrief.

**Architecture:**
- A scenario is data (`data/scenarios.json`) plus a normal `GameSession`, built from `Scenarios.Setup(id)` with
  `PlantingYear = vintage − 3`, so the game opens on 15 January with established vines. `GameSetup.ScenarioId` is saved,
  so loading replays it.
- `Scenarios.Evaluate(game)` judges typed criteria on the best Wine of the scenario vintage. `Scenarios.Debrief(game)`
  adds the cited vintage note and the growers' actions.
- The best medal per scenario is kept in the study record (`scenarios` field).
- The UI only renders the bridge JSON.

**Tech Stack:** C# (.NET 10, xUnit) sim; Godot 4.7 GDScript UI through the `SimBridge` autoload.

**Spec:** `docs/superpowers/specs/2026-10-03-famous-vintages-design.md`

## Global Constraints

- ADR 0001: the UI never computes outcomes; the sim judges medals.
- ADR 0002: the briefing gives only what a grower knew in January. It never names the year's defining event, and the
  debrief reveals it afterwards.
- Medals reward winemaking outcomes, never profit.
- Every debrief fact is cited in `docs/science/vintage-notes.md`, paraphrased. Unbacked lines are left out.
- No exam-board wording or branding; nothing copied from `reference/`.
- CONTEXT.md terms (Tasting sheet, Vintage, Block, Lot, Wine, Estate, Plot, Region).
- Build C# via `scripts/build-game.sh`. Sim tests: `cd sim && ~/.dotnet/dotnet test -v q`.
- Commits end with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`. Push only when the owner
  asks.

## Review Focus

1. **An old save with no `ScenarioId`** → loads as a normal game, with no scenario panel and no debrief. Pinned in Task 2
   (`OldSave_NoScenario`).
2. **Several Wines of the vintage, or a blend with another year** → the medal is judged on the best Wine whose label
   carries the scenario vintage. A non-vintage blend does not count. Pinned in Task 2 (`Evaluate_BestWineOfTheVintage`).
3. **Playing on past the scenario vintage** → later Vintages never change the scenario's medals. Pinned in Task 2
   (`LaterVintages_DoNotChangeTheMedal`).
4. **No Wine bottled yet** → status shows the goals "to be judged at bottling", with no debrief and no crash. Pinned in
   Task 2 (`Status_BeforeBottling`).
5. **A briefing or teaser that leaks the future** (frost, heat, fire, earthquake, a date) → the validator rejects it.
   Pinned in Task 2 (`Briefings_DoNotLeakTheYear`).

---

### Task 1: Debrief research (the growers' response, cited)

**Files:**
- Modify: `docs/science/vintage-notes.md`: a "What growers did" row per scenario year, with source keys.

- [ ] **Step 1:** Research with a subagent (WebFetch; read-only on the repo). For each year (Côte d'Or 2016, Mosel 2018,
  Napa 2011), find sourced actions by growers:
  - frost fighting;
  - sorting;
  - picking dates;
  - chaptalisation or deacidification;
  - yields reported;
  - quality outcome.

  Use the existing sources first ([DECANTER-2016], [COATES-2016], [DWI-2018], [NVV-2011]), then reputable new ones. The
  output is paraphrased facts with URLs, plus numbers usable for "your Wine against the real year" (harvest dates, must
  weights, yields).
- [ ] **Step 2:** Add the rows and sources to `vintage-notes.md`. Leave out any line without a source.
- [ ] **Step 3: Commit:** `docs: what growers did in 2016 Côte d'Or, 2018 Mosel and 2011 Napa`.

### Task 2: Scenario catalogue, setup, judging and debrief (sim)

**Files:**
- Create: `data/scenarios.json`, `sim/src/TerroirEngine.Core/Game/Scenarios.cs`
- Modify: `sim/src/TerroirEngine.Core/Game/GameSession.cs` (`GameSetup.ScenarioId`),
  `sim/src/TerroirEngine.Core/Learning/ReviewScheduler.cs` (`StudyRecord.Enqueue`)
- Test: `sim/tests/TerroirEngine.Core.Tests/ScenarioTests.cs`

**Interfaces:**
- Produces:
  - `record Scenario(string Id, string Region, string Plot, string Variety, int Vintage, string Title, string Teaser,
    string Briefing, IReadOnlyList<Medal> Medals, IReadOnlyList<SourcedLine> Growers, IReadOnlyList<SourcedLine>
    Compare, IReadOnlyList<string> Causes)`
  - `record Medal(string Name, IReadOnlyList<Criterion> Criteria)` (Name is bronze, silver or gold; each medal includes
    the one below)
  - `record Criterion(string Type, JsonNode? Value)`, with Type one of:
    - `category` (string[])
    - `qualityAtLeast` (string)
    - `noFault`
    - `noChaptalisation`
    - `naturalSugarAtLeast` (g/L)
    - `acidityAtLeast` (scale word)
    - `balanceMet`
    - `seedsRipe` (≥ 0.62)
    - `noRotTaint` (grey rot ≤ 6 %)
  - `Scenarios.Catalog(GameData)`
  - `Scenarios.Problems(GameData, Scenario) → List<string>`
  - `Scenarios.Setup(GameData, string id) → GameSetup`
  - `Scenarios.Evaluate(GameSession) → JsonObject {judged, wine, medal, medals:[{name, met, criteria:[{text, met,
    evidence}]}]}`
  - `Scenarios.Status(GameSession) → JsonObject` (goals; the debrief when judged)
  - `Scenarios.Debrief(GameSession) → JsonObject` (`note`, `growers`, `compare` with the player's numbers, `causes`)
  - `Scenarios.RecordMedal(JsonObject rec, string id, string medal) → JsonObject` (keeps the best)
  - `StudyRecord.Enqueue(JsonObject rec, IEnumerable<string> causeIds, DateOnly today, GameData data) → JsonObject` (due
    tomorrow, no history; existing states untouched)

- [ ] **Step 1: Write the failing tests** in `ScenarioTests.cs`:
  - `Catalog_ThreeScenarios_PassTheValidator`;
  - `Setup_OpensOnJanuary15_WithEstablishedVines`: `new GameSession(data, Scenarios.Setup(data, "cotedor-2016"))` →
    the date is 2016-01-15 and the phase is Running;
  - `Briefings_DoNotLeakTheYear`: `Problems` rejects a briefing or teaser containing frost, heat, hot, fire, smoke,
    earthquake, rain, a month name or a digit date, and the shipped ones pass;
  - `Status_BeforeBottling`: `judged == false`, three medals, criteria text present;
  - `Evaluate_BestWineOfTheVintage`: play `mosel-2018` with the default scripted player to bottling, then `judged`, with
    medal at least bronze, and `wine` naming the 2018 Wine;
  - `LaterVintages_DoNotChangeTheMedal`: continue into 2019, bottle again, and the medal is unchanged;
  - `OldSave_NoScenario`: `GameSession.Load` of a save JSON without ScenarioId → `Scenarios.Status` returns
    `{scenario:null}`;
  - `RecordMedal_KeepsTheBest`;
  - `Enqueue_AddsCausesWithoutHistory`.
- [ ] **Step 2:** Run `cd sim && ~/.dotnet/dotnet test -v q --filter ScenarioTests`. Expected: compile errors (the types
  do not exist yet).
- [ ] **Step 3: Implement:**
  - `GameSetup.ScenarioId` (`string?`, serialized with the save automatically);
  - `data/scenarios.json` with the three scenarios from spec §3, with briefings written for January knowledge only;
  - `Scenarios.cs` (loader cached per data root, the validator, Setup, Evaluate, Status, Debrief, RecordMedal);
  - `StudyRecord.Enqueue` (refactor `LearnCards.Check` to call it).

  Evidence strings are plain, for example "natural sugar 183 g/L (needs 189)".
- [ ] **Step 4:** Run the tests. Expected: all pass, and the full suite stays green.
- [ ] **Step 5: Commit:** `feat(sim): famous-vintage scenarios, judged medals and the debrief`.

### Task 3: Medal tuning with scripted players

**Files:**
- Test: `sim/tests/TerroirEngine.Core.Tests/ScenarioBalanceTests.cs` (scripted players: `Default` harvests at the
  region's default target with default cellar choices; `RightCalls(id)` makes that year's right decisions — 2016: wait
  for full natural ripeness, no chaptalisation, classic extraction; 2018: pick early for Kabinett freshness; 2011: wait
  for ripe seeds, pick before rot)
- Modify: `data/scenarios.json` thresholds; spec §3 records the final values.

- [ ] **Step 1: Write the failing tests:**
  - `Default_EarnsBronze_NotGold` (for each scenario);
  - `RightCalls_EarnGold` (for each scenario).
- [ ] **Step 2:** Run. Expected: some fail until the thresholds and strategies are tuned.
- [ ] **Step 3:** Tune the thresholds in the data (never the sim physics) until both pass. Ledger every change.
- [ ] **Step 4:** Run the full suite. Expected: green.
- [ ] **Step 5: Commit:** `feat(sim): tune famous-vintage medals with scripted players`.

### Task 4: Bridge and UI

**Files:**
- Modify: `game/src/bridge/SimBridge.cs`:
  - `ScenarioList()`: each scenario, plus the best medal from the study record;
  - `NewScenarioGame(id)`;
  - `ScenarioStatus()`: on first judging, records the medal and enqueues the Causes;
  - `ScenarioDebriefSeen()`
- Create: `game/src/ui/screens/scenarios.gd` (list and briefing), `game/src/ui/screens/debrief.gd`
- Modify:
  - `game/src/ui/screens/pregame.gd`: a "Famous vintages" button;
  - `game/src/ui/screens/estate.gd` (or its equivalent screen): the Scenario panel;
  - `game/src/ui/shell.gd`: a HUD chip; the debrief opens when judged and not yet seen; a `--scenarios` harness

- [ ] **Step 1:** Implement the bridge methods, each wrapped in try/catch like the existing ones.
- [ ] **Step 2:** Build the screens:
  - list cards with medal chips;
  - a briefing with three goals and a Start button;
  - the Scenario panel (goals, "judged at bottling");
  - the debrief (medals with evidence, the vintage note, what growers did, your Wine against the year, the Causes
    added).
- [ ] **Step 3:** Add `scripts/scenarios.sh`. It starts each scenario, plays it with the scripted default player to
  bottling, checks that the debrief is judged, and screenshots the list, briefing, panel and debrief.
- [ ] **Step 4:** Run `bash scripts/build-game.sh` (0 errors) and `bash scripts/scenarios.sh` (`SCENARIOS DONE
  ok=true`), and review the screenshots.
- [ ] **Step 5: Commit:** `feat(game): famous vintages on screen`.

### Task 5: Docs, checks, review, merge

- [ ] **Step 1:** Docs:
  - `docs/science/famous-vintages.md`: method, scenarios, thresholds with their tuning evidence, ADR 0002 handling, and
    simplifications;
  - CONTEXT.md entry "Famous vintage";
  - README line;
  - backlog: Côte d'Or 2021 next, frost protection, blind-vintage mode, unreproduced years.
- [ ] **Step 2:** Run all suites, `practice.sh`, `learning.sh`, `scenarios.sh`, `capture.sh` and `fuzz.sh`.
- [ ] **Step 3:** Final whole-branch review subagent on the most capable model, then one fix pass with TDD.
- [ ] **Step 4:** Merge locally into main, delete the workspace, and write the final report. Do not push unless asked.
