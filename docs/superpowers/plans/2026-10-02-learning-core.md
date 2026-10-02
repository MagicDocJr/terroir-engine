# The learning core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teach every modelled Cause through spaced, confidence-rated retrieval on new Wines, predictions before reveals on
the Estate, and top-quality learn cards at every real decision, with ranks that report durable mastery and screens that stay
clean.

**Architecture:**
- A new `TerroirEngine.Core/Learning/` namespace holds the Cause catalogue, the scheduler, session composition, predictions
  and learn cards.
- The Tasting-sheet generator tags Cause ids where it already writes its "because" lines.
- The study record (v1 Tasting-practice JSON) migrates to v2 with per-Cause state.
- The bridge passes JSON. The UI adds a confidence row, a Progress view, a bottling prediction panel and a side learn drawer
  (with a 3D vine turntable).

**Tech Stack:** C# sim (xUnit), Godot 4.7 .NET GDScript, JSON data files.

**Spec:** `docs/superpowers/specs/2026-10-02-learning-core-design.md`

## Global Constraints

- **Quality bar (owner, binding):** nothing added for its own sake; every learn card and question passes the gate (spec §7.4).
  Fewer, better cards beat coverage.
- **Clean UI (binding, spec §7.5):**
  - one "Learn" link per choice; a side drawer, never a modal; drawers never stack
  - no automatic pop-ups; no new permanent panels on existing screens
  - the bottling prediction is the only new step; text ≥ 13 px
- **ADR 0001:** the sim schedules, marks and decides; the UI shows. **ADR 0002:** inside a game, only harvested vintages.
- **Science:**
  - every Cause step and card step cites `docs/science/`
  - no `UNVERIFIED` claim in a card's main text
  - no WSET wording, grids or branding
  - the game never implies it trains the nose
- **Glossary** (`CONTEXT.md`): Cause, Learn card, Review queue, Known, Confidence, Weekly rhythm, Exam date. Never
  "tasting note".
- **Determinism:** pours and scheduling are functions of their inputs and dates; no process-randomised hashing.
- **Checks:** sim tests; `scripts/practice.sh`; a new `scripts/learning.sh` harness; fuzz; capture SAVE/LOAD; screenshots
  reviewed.
- **Build and commits:** build C# via `scripts/build-game.sh`. Commits end with the Co-Authored-By line; push only when asked.

## Review Focus

1. **A v1 study record from the Tasting-practice release** (XP, medals, cards, skills, daily) → migrates to v2 without losing
   anything; ranks are recomputed from Known Causes, and medals and cards stay. Pinned in Task 2
   (`Migration_V1RecordKeepsEverything`).
2. **The system clock goes backwards, or several sessions fall on one day, or weeks are skipped** → no negative or past
   intervals, no same-session re-test, nothing lost. Pinned in Task 2 (`Scheduler_ToleratesClockJumps`).
3. **A due Cause for which no Wine can show it** (inside an early game, a Cause tied to a Region whose years are locked, a
   miscalibrated year) → the session falls back to a chain fill-in for that Cause, never an empty session or a stuck queue.
   Pinned in Task 3 (`DueCause_WithoutAShowingWine_FallsBackToChainFillIn`).
4. **A learn card opened without its context** (pre-game with no Block chosen, a Lot not yet received, a Block of another
   Variety) → the general version of "On this site", no crash. Pinned in Task 6 (`Card_SiteLine_MissingContext_General`).
5. **A Wine bottled before this release (old save), or a blend of several Lots** → old Wines count as revealed (no surprise
   prediction panel); a blend uses the blend's own sheet and tags. Pinned in Task 5 (`Predictions_OldWinesRevealed_BlendsUseBlendSheet`).

---

### Task 1: Causes: catalogue and tags (sim)

**Files:**
- Create:
  - `data/causes.json`
  - `sim/src/TerroirEngine.Core/Learning/CauseCatalog.cs`
- Modify: `sim/src/TerroirEngine.Core/Tasting/TastingSheet.cs`, to add `CauseLinks` and tag at the "because" sites.
- Test: `sim/tests/TerroirEngine.Core.Tests/CauseTests.cs`

**Interfaces:**
- **Produces:**
  - `record Cause(string Id, string Title, string[] Chain, string Topic, string Level, string[] Sources, string[] Exercise,
    CausePour Pour)`
  - `record CausePour(string? Region, string? Variety, string? Style, string? VintageClass)`
  - `CauseCatalog.All(GameData) → IReadOnlyList<Cause>` and `CauseCatalog.Get(GameData, id)`
  - `TastingSheet.CauseLinks : List<(string Cause, string Line)>`, where Line is `"appearance"`, `"aroma:<family>"`,
    `"palate:<Attribute>"`, `"fault"` or `"quality"`, and `TastingSheet.Causes` gives the distinct ids
- **Consumes:** existing `TastingSheetGenerator.Generate`, `TastingLab.Pour`.

- [ ] **Tests first:**
  - `Catalogue_IsValid`: unique ids; 2–4 chain steps each; every source names an existing `docs/science/*.md` file and a
    heading text found in it; topics non-empty.
  - `Tags_AllExistInCatalogue`: across about 40 varied pours, every tag exists.
  - `EveryCause_IsShownByItsReferencePour`: each Cause's `pour` hints, poured with up to 6 seeds, produce at least one sheet
    tagged with it.
  - `Tags_AreDeterministic`.
  - `CoolSeason_TagsHighAcid_WarmSeason_TagsMalicLoss`: Mosel 1996 vs 2018.
- [ ] **Implement:**
  - About 35 Causes from the spec §3.1 list, each with its sources, for example:
    - `ripening.md` §4.1 (malic)
    - `canopy-and-yield.md` §2.3 / §2.5
    - `fermentation.md` (esters, H₂S, YAN)
    - `extraction-and-oak.md` (oak, maceration, whole bunch)
    - `acid-ph-so2.md` (MLF, SO₂)
    - `aroma-and-faults.md` (TDN, Brett, VA, oxidation)
    - `phenology.md` (frost)
    - `disease.md` (rot)
  - Tag inside the generator at the branches that already build each "because".
- [ ] **Commit** `feat(sim): Causes catalogue and Cause tags on Tasting sheets`.

### Task 2: Study record v2, scheduler, mastery and the weekly rhythm (sim)

**Files:**
- Create:
  - `sim/src/TerroirEngine.Core/Learning/ReviewScheduler.cs`
  - `sim/src/TerroirEngine.Core/Learning/StudyRecord.cs`
- Modify: `Tasting/Practice/PracticeProgress.cs` (ranks from Known share; the weekly rhythm; Apply updates Cause states).
- Test: `sim/tests/TerroirEngine.Core.Tests/SchedulerTests.cs`

**Interfaces:**
- **Produces:**
  - `record CauseState(string Id, int Step, double Stability, double Difficulty, DateOnly? Due, DateOnly? LastSeen,
    List<CauseAnswer> History, bool Known)`
  - `record CauseAnswer(DateOnly Date, bool Right, int Confidence)`
  - `ReviewScheduler.Review(CauseState? s, string id, bool right, int confidence, DateOnly today, DateOnly? examDate) → CauseState`
  - `ReviewScheduler.Due(JsonObject record, DateOnly today) → IReadOnlyList<string>` (ids, most overdue first)
  - `StudyRecord.Migrate(JsonObject v1) → JsonObject v2` (version 2; keeps every v1 field)
  - `StudyRecord.Causes(JsonObject) → Dictionary<string, CauseState>`
  - `PracticeProgress.Summary` gains `known`, `knownShare`, `rhythm {daysThisWeek, target, repairable}`, `examDate` and
    `coverage[topic]`
  - Ranks by Known share: 0 / 15 / 40 / 70 / 95 %
- **Consumes:** event items now carry `causes: [id]` and `confidence: 1–3`.

- [ ] **Tests first:**
  - `Ladder_1_3_7_16_35_ThenStability`
  - `NoRetestInTheSameSitting`: a miss today is due tomorrow at the earliest.
  - `SureAndWrong_DueTomorrow`
  - `GuessAndRight_ScheduledHarderThanSure`
  - `Known_After3RightOn3Days`
  - `Known_LostAfterTwoMisses`
  - `ExamDate_CompressesLateGaps_AndCoversEveryCauseThrice`
  - `RanksFromKnownShare`
  - `WeeklyRhythm_CountsDays_RepairWithinWeek`
  - `Migration_V1RecordKeepsEverything`
  - `Scheduler_ToleratesClockJumps`: today earlier than LastSeen; many sessions in one day; a 200-day gap.
- [ ] **Implement:** FSRS-lite (stability grows on right answers in proportion to difficulty and confidence, shrinks on
  misses; the next interval sets recall to 0.88 under an exponential forgetting curve). The exam date caps intervals at
  max(3 days, 10 % of the days left), ensures three successes before the date, and caps at 5 days in the last 21 days.
- [ ] **Commit** `feat(sim): spaced review of Causes, mastery ranks and the weekly rhythm`.

### Task 3: Sessions, review pours, Confidence and question forms (sim)

**Files:**
- Create:
  - `sim/src/TerroirEngine.Core/Learning/SessionComposer.cs`
  - `sim/src/TerroirEngine.Core/Learning/ChainQuestion.cs`
- Modify:
  - `Tasting/Practice/TastingMarker.cs` (MarkItem gains `Confidence`, `Case`, `Causes`)
  - `Tasting/Practice/PracticeSession.cs` (kind `session`; Confidence; chain and contrast items; label hidden until reveal at stands)
  - `PracticePours.cs` (pour for a Cause with tag verification)
- Test: `sim/tests/TerroirEngine.Core.Tests/SessionTests.cs`

**Interfaces:**
- **Produces:**
  - `SessionComposer.Compose(GameData, JsonObject record, DateOnly today, int? maxVintage, int size = 6, int seed) → List<SessionItem>`
  - `record SessionItem(string Kind /* wine|chain|contrast */, string Cause, string Reason /* due|weak|new */, PourSpec? Spec, PourSpec? Spec2)`
  - `PracticePours.ForCause(GameData, Cause, int seed, int? maxVintage) → PouredWine?` (keeps a pour only if its sheet is
    tagged with the Cause; up to 6 tries)
  - `ChainQuestion.For(Cause, int blanks, int seed, IReadOnlyList<Cause> all) → {Steps, Blanks, Options, Answers}`
  - `MarkItem.Case ∈ {"sure-wrong","guess-right","sure-right","guess-wrong","no-confidence"}`
- **Consumes:** Task 1 tags; Task 2 scheduler and `Due`.

- [ ] **Tests first:**
  - `Session_MixesDueWeakNew`: about 60/25/15 over 6 items with ties resolved.
  - `Session_NeverRepeatsACauseWithinIt`
  - `ReviewPour_ShowsTheCause_NewWineEachTime`
  - `DueCause_WithoutAShowingWine_FallsBackToChainFillIn`
  - `ChainFillIn_FadesWithStep`
  - `ContrastPair_DiffersInOneCause`
  - `Confidence_DrivesTheFourCases`
  - `Mark_UpdatesCauseStatesFromTaggedItems`
  - `StandLabel_HiddenUntilMarked`: the session JSON for a stand has no producer or site before marking.
- [ ] **Implement:**
  - Wine items: due Causes first, then the weak skill's Causes, then unseen Causes in catalogue order (foundations first).
  - Chain items: for Causes not yet at fade step 3.
  - Contrast items: for Causes seen twice.
  - Due Causes also seed the Glass of the day (a due wine-kind item replaces the random daily pour). Wine Fair Flights keep their themes (ruling: changing a stand's glasses would break its theme).
- [ ] **Commit** `feat(sim): mixed review sessions, confidence and chain and contrast questions`.

### Task 4: Tasting-practice UI: Confidence, four-case reveal, Progress view (game)

**Files:**
- Modify:
  - `game/src/bridge/SimBridge.cs` (session start through the pour job; Progress)
  - `game/src/ui/tasting_ui.gd` (confidence row; four-case verdicts; recap; chain and contrast items)
  - `game/src/ui/screens/practice.gd` ("Today's session" card first; Progress view; weekly rhythm; ranks)
  - `game/src/ui/screens/fair.gd` (label hidden until the reveal)
  - `game/src/ui/shell.gd` (harness)
- Create: `scripts/learning.sh`

- [ ] **Confidence and verdicts:**
  - The confidence row (guess / think so / sure) sits under each item's picker. It is required before marking, with a
    gentle prompt if missing.
  - Four-case verdict styling:
    - surprise card for sure-wrong
    - full explanation for guess-right
    - short line plus "why" toggle for sure-right
    - explanation for guess-wrong
  - "Because" on right answers.
  - An end-of-Flight recap of the misses.
- [ ] **Progress view and lobby:**
  - Competence over time per skill: a small sparkline per skill.
  - A calibration chart (three bars, confidence vs accuracy) plus one plain line.
  - Known Causes per topic.
  - The line "The game trains reasoning and vocabulary; your nose needs real glasses."
  - The weekly rhythm replaces days-in-a-row. The rank badge shows Known share.
- [ ] **Harness** (`--learning`):
  - a session with all three item kinds and Confidence
  - the record updated; due dates set
  - screenshots
- [ ] **Commit** `feat(game): sessions with confidence, the four-case reveal and the Progress view`.

### Task 5: Predict before reveal on the Estate (sim + game)

**Files:**
- Create: `sim/src/TerroirEngine.Core/Learning/Predictions.cs`
- Modify:
  - `SimBridge.cs` (PredictionFor(wineId), RevealWine(wineId, answers))
  - `game/src/ui/screens/wines.gd` (prediction panel for unrevealed Wines)
- Test: `sim/tests/TerroirEngine.Core.Tests/PredictionTests.cs`

**Interfaces:**
- **Produces:**
  - `Predictions.For(GameSession g, string wineId) → {items: [acidity, alcohol, leading family, quality band], recall:
    [≤2 {choice, cause, question, options}]}`
  - `Predictions.Mark(GameSession g, string wineId, JsonObject answers) → (result, causes)`
  - Revealed state is a game flag `revealed_<wineId>`. Wines bottled before this release count as revealed (flag set on
    load).
- **Consumes:** Task 1 tags, Task 2 record (via the bridge).

- [ ] **Tests first:**
  - `Predictions_FourItems_MarkedAgainstTheSheet`
  - `ChoiceRecall_PicksThePlayersRealChoices`: e.g. MLF blocked → its Cause.
  - `Predictions_NeverChangeTheWine`
  - `Predictions_OldWinesRevealed_BlendsUseBlendSheet`
- [ ] **UI:**
  - On the Wines screen an unrevealed Wine shows the panel: four pickers with Confidence, up to two recall questions, and
    "Reveal".
  - Then the normal sheet opens with verdicts beside the predicted lines.
  - "Skip" reveals directly.
  - Harness: bottle in a game and predict.
- [ ] **Commit** `feat: predict your own Wine before its Tasting sheet, and recall what your choices did`.

### Task 6: Learn cards (science, data, drawer, 3D turntable)

**Files:**
- Create:
  - `data/learn/*.json` (12 cards)
  - `sim/src/TerroirEngine.Core/Learning/LearnCards.cs`
  - `game/src/ui/learn_drawer.gd`
  - `game/src/ui/learn_visuals.gd` (diagrams, vine turntable)
- Modify:
  - `docs/science/canopy-and-yield.md` (training-system trade-offs, cited)
  - other science docs as each card needs
  - `SimBridge.cs` (LearnCard(id, contextJson))
  - `planting_guide.gd`, `plot.gd`, `ripeness.gd`, `winery.gd` (one Learn link per choice)
- Test: `sim/tests/TerroirEngine.Core.Tests/LearnCardTests.cs`

**Interfaces:**
- **Produces:**
  - `LearnCards.All(GameData)`
  - `LearnCards.Card(GameData, id, JsonObject context, JsonObject record) → JSON {title, what, chains:[...], site, exam,
    check:{question, options, answer, why}, sources:[...], visual, depth: full|brief}`
  - Context keys: `plot`, `block`, `variety`, `lot` (each optional).
- **Card set and visuals:**
  - training system (3D turntable)
  - rootstock (root/soil diagram)
  - harvest date (the Block's ripening curves)
  - canopy and leaf removal (exposure diagram)
  - yield / green harvest
  - whole bunch
  - fermentation temperature
  - nutrients / YAN
  - MLF (acid bar)
  - vessel and oak (oak → families chart)
  - lees and bâtonnage
  - stopping for sweetness

- [ ] **Tests first:**
  - `Cards_PassTheMechanicalGate`: sources resolve to science headings; main text 120–180 words; chains of 2–4 steps
    referencing catalogue Causes; one check question with three or more options and an explanation; no "WSET" string;
    no "UNVERIFIED" in the main text.
  - `Card_SiteLine_UsesPlayerData`: YAN card with a Lot at 120 mg/L.
  - `Card_SiteLine_MissingContext_General`
  - `Card_Brief_WhenItsCausesAreKnown`
- [ ] **Content:** research and cite any missing facts into `docs/science/` first, then write each card to the template.
- [ ] **UI:**
  - The side drawer: about 40 % width; Esc and outside click close it; replaced, never stacked.
  - Learn links with a first-seen gold dot.
  - The turntable: SubViewport, the game's vine models for each training system, winter/summer switch, slow rotation,
    fallback to the 2D drawing.
  - Diagrams drawn in `_draw`.
- [ ] **Quality gate:**
  - A reviewer subagent scores every card on the spec §7.4 rubric; any line under 4 is rewritten.
  - Screenshots of each card and each touched screen are checked against the clutter checklist.
- [ ] **Commit** `feat: learn cards at the moment of choice`.

### Task 7: Exam date, coverage view, docs, checks, review

- [ ] **Exam date and coverage:**
  - Exam-date control on Tasting practice (sim already supports it): a date picker of three dropdowns (year, month, day).
  - A coverage view of Causes by topic (Known / learning / not seen).
- [ ] **Docs and backlog:**
  - `docs/science/learning-core.md`: methods and citations from research track A; the scheduler parameters; simplifications.
  - `CONTEXT.md` entries; README; backlog (the remaining ~18 card decision points; contrast pairs for vintage Causes; FSRS
    tuning from real history).
- [ ] **Checks and merge:**
  - all suites, the practice and learning harnesses, fuzz, capture
  - the final review subagent (most capable model)
  - a fix pass; merge locally
