# Tasting practice and the Wine Fair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A fun, progression-driven study mode: the simulation pours real-vintage Wines; the player practises the WSET systematic approach alone or at themed Wine Fair stands, earns ranks, medals and vintage cards, and learns why each Wine tastes as it does.

**Architecture:** A new `TerroirEngine.Core/Tasting/Practice/` namespace makes Wines headlessly (a scripted Estate per pour), builds vintage facts, quizzes and marks, and computes progression from a record; the bridge runs pours on a background thread and passes JSON; two new Godot screens (Tasting practice, Wine Fair) plus a Cellar book show it.

**Tech Stack:** C# sim (xUnit), Godot 4.7 GDScript, JSON data files.

**Spec:** `docs/superpowers/specs/2026-09-29-tasting-practice-and-wine-fair-design.md`

## Global Constraints

- ADR 0001: the sim pours, marks and computes progression; the UI shows and stores the record file only.
- ADR 0002: inside a game only vintages already harvested on its Timeline are poured; `UNVERIFIED` vintage notes are never shown.
- Science: tasting terms from our cited model; quiz answers only from simulated or recorded data; invented producers, scripted cellar styles, tasting-age cap and fault rate labelled game simplifications; `docs/science/tasting-practice.md`.
- Glossary: "Tasting practice", "Wine Fair", "Stand", "Flight", "your Tasting sheet" (never "tasting note").
- Fun serves learning: every reward is earned by an assessed answer.
- UI never freezes: pours run in the background.
- Build via `scripts/build-game.sh`; checks: sim tests, fuzz, a `--practice` harness, capture.
- Commits end with the Co-Authored-By line; push only when asked.

## Review Focus

1. **A pour that fails to bottle** (rot, stuck ferment, frost-wiped crop) → the lab retries with another seed or style, never returns an empty flight. Pinned in Task 1 (`Pour_AlwaysBottles_AcrossRegionsAndHardVintages`).
2. **A record file from an older build or corrupted** → progress loads what it can, defaults the rest, never crashes. Pinned in Task 3 (`Progress_ToleratesMissingAndUnknownFields`).
3. **Leaving the screen while a flight is pouring** → the job finishes or is dropped; coming back shows the flight or pours again, no double pours. Pinned in Task 4 (harness).
4. **Inside a game, a stand with a future vintage** → locked with its unlock year; never poured. Pinned in Task 2 (`Stands_InAGame_LockFutureVintages`).
5. **Picking nothing for an item** → scored 0 with the answer shown, no crash. Pinned in Task 3 (`Mark_EmptyAnswers_ScoreZeroAndShowTheSheet`).

---

### Task 1: The pour (sim)
**Files:** create `sim/src/TerroirEngine.Core/Tasting/Practice/TastingLab.cs`, `WinemakerStyle.cs`, `PracticeJson.cs`; tests `sim/tests/TerroirEngine.Core.Tests/PracticeTests.cs`.
**Produces:** `PourSpec(PlotId, BlockId?, Vintage, Style?, Ripeness?)`, `TastingLab.Pour(GameData, PourSpec, int seed) → PouredWine { Wine, Sheet, Context }`, `WinemakerStyle.Pick(regionId, variety, seed)`, `PracticeJson.Poured(PouredWine) → JsonObject`.
- [ ] Tests first: deterministic (same spec+seed → identical sheet JSON); one pour per Region bottles a Wine with a sheet; hard vintages (Côte d'Or 2016, 2021; Mosel 2010) still bottle (retry); ripeness ladder yields Kabinett < Spätlese < Auslese categories for Mosel; context carries weather summary (GDD, summer Tmax, harvest rain, frost-at-budburst flag), harvest date, must Oe, style.
- [ ] Implement: a scripted `GameSession` (planting = vintage − 3, one Block, harvest at the style's ripeness target, cellar choices from the style, restart stuck ferments, bottle, tasting date bottling + months capped). Faults: small seeded chance of a style that lets VA / Brett / TCA develop.
- [ ] Commit `feat(sim): tasting lab pours real-vintage Wines`.

### Task 2: Vintage facts, stands, quiz, real notes (sim)
**Files:** `VintageFacts.cs`, `FairStands.cs`, `VintageQuiz.cs`, `data/fair_stands.json`, `data/vintage_notes.json` (the sourced rows of `docs/science/vintage-notes.md`); tests.
**Produces:** `VintageFacts.For(data, regionId, year) → {Gdd, SummerTmax, HarvestRain, FrostAtBudburst, …}`, `FairStands.All(data, maxVintage?) → [Stand {Id, Title, Blurb, Host, Pours: [PourSpec], Locked, UnlockYear}]`, `VintageQuiz.For(stand, poured[]) → [Question {Text, Options, Answer, Evidence}]`.
- [ ] Tests first: cool/warm picks equal the min/max GDD of 1995–2025; the 2016 stand's quiz has a frost question answered 2016 with the frost date; `Stands_InAGame_LockFutureVintages`; only sourced notes load.
- [ ] Implement; commit `feat(sim): Wine Fair stands, vintage facts and quizzes`.

### Task 3: Marking and progression (sim)
**Files:** `TastingMarker.cs`, `PracticeProgress.cs`; tests.
**Produces:** `TastingMarker.Mark(PouredWine, answersJson) → MarkResult {Items: [{Key, Yours, Actual, Score, Because}], Total, Max}`, `PracticeProgress.Apply(recordJson, event) → recordJson` (XP, rank, medals, unlocks, cards, daily glass, days-in-a-row, per-skill history), `PracticeProgress.Summary(recordJson) → JSON` (rank, next rank, weakest skills, unlocked stands, cards).
- [ ] Tests first: ordered scales exact 1 / one-off ½ / else 0; categorical 1/0; aroma Jaccard; `Mark_EmptyAnswers_ScoreZeroAndShowTheSheet`; medals at 50/70/85 %; best medal kept; unlocks after medals; days-in-a-row increments on consecutive dates, resets after a gap; `Progress_ToleratesMissingAndUnknownFields`; adaptive picks target the lowest skill.
- [ ] Implement; commit `feat(sim): tasting marks, ranks, medals, cards and adaptive practice`.

### Task 4: Bridge + Tasting practice screen
**Files:** `game/src/bridge/SimBridge.cs` (PourFlight, PourStatus, PourResult, Mark, FairStands, Progress*, GlassOfTheDay), `game/src/ui/screens/practice.gd`, title-screen entry, nav entry in a game, `user://tasting_record.json`, `view3d_test`-style harness `--practice` in the shell.
- [ ] Background pour job (System.Threading.Tasks) with a status poll; the screen: exercise picker, glass of the day, adaptive suggestion, one Wine at a time, pickers, reveal with per-item verdicts, XP gain, rank badge.
- [ ] Harness: pour, answer, mark, record updated; leaving mid-pour. Commit `feat(game): Tasting practice screen`.

### Task 5: Wine Fair screen and Cellar book
**Files:** `game/src/ui/screens/fair.gd`, `game/src/ui/screens/cellar_book.gd`, sounds.
- [ ] Stands grid (host portrait, medal, lock/unlock), stand view (flight columns, your Tasting sheet pickers per Wine, quiz, animated reveal with streaks, medal), Cellar book (cards per Region and vintage, real notes with sources).
- [ ] Harness + fuzz + screenshots reviewed. Commit `feat(game): the Wine Fair and the Cellar book`.

### Task 6: Docs, checks, review
- [ ] `docs/science/tasting-practice.md`, `CONTEXT.md`, README, backlog (3D fair hall, more Regions, timed mode, free text); all suites; final review subagent; fix pass; merge locally.
