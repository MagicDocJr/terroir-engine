# Tasting practice and the Wine Fair — design

Status: design approved by the owner in conversation 2026-09-29 ("agree"). Vocabulary follows `CONTEXT.md` (new terms
below). Purpose: the game is a WSET Level 3 (later Diploma) study tool; this mode trains the tasting and the
vintage-knowledge parts of those exams with wines the simulation makes, so every descriptor can say why it is there.

## 1. Goal

**Success looks like**
- From the title screen (no Estate needed) or from a game, the player opens **Tasting practice** and is poured a
  simulated Wine; they work through an exercise and get marked against the Wine's Tasting sheet, where every line
  explains its cause.
- The **Wine Fair** offers themed **stands**, each pouring a **flight** of 3–4 Wines from real Regions and real
  vintages (1995–2025) side by side; the player fills in their Tasting sheet for each, answers a short **vintage
  quiz** built from the recorded weather, and sees the reveal.
- A running record per skill (e.g. acidity, readiness, vintage knowledge) shows progress over sessions.
- A flight is ready in a few seconds; nothing freezes the UI (the wines are made in the background).

**Non-goals** (backlog): real named producers or wines; Regions and grapes the simulation can't make; free-text notes;
a timed exam mode; a walkable 3D fair hall; sharing results.

## 2. Glossary additions (`CONTEXT.md`)

- **Tasting practice**: the study mode where the simulation pours Wines for the player to assess.
- **Wine Fair**: the part of Tasting practice with themed stands of flights.
- **Stand**: one theme at the Wine Fair (e.g. "Burgundy 2003, 2004, 2005").
- **Flight**: the Wines a stand pours side by side.
- **Your Tasting sheet**: the player's own assessment in the Tasting sheet's structure (not "tasting note").

## 3. Where the Wines come from (simulation)

- `TastingLab.Pour(data, spec, seed) → PouredWine` runs a headless scripted Estate like the CLI `play` loop: the
  Plot and Block, a planting year three years before the vintage, harvest at the spec's ripeness target, the spec's
  cellar choices, bottling, and a tasting date (months after bottling; older vintages "cellared" for their age, capped
  at the Tasting sheet's model range). The result carries the Wine, its Tasting sheet, and its **context**: Region,
  Plot, Variety, the vintage's weather summary (growing-degree days, summer mean maximum, rainfall around harvest,
  frost at budburst, heat spikes), harvest date and must, and the winemaking choices.
- **Winemaker styles** (a seeded choice within each Region's norms): harvest early / typical / late; steel or oak;
  malolactic yes/no for whites; dry / off-dry for Mosel Riesling; cap management for reds. Occasionally (a few per
  cent) a fault is allowed to develop (volatile acidity, Brett, cork taint) because spotting faults is part of the
  exam. The style is shown only in the reveal. **Game simplification:** invented producers and a scripted cellar.
- Determinism: a pour is a function of (spec, seed); the same seed gives the same Wine (tests pin this).
- Cost: ≈ 0.5–0.7 s per Wine (measured for a full scripted Vintage); a flight runs on a background thread in the
  bridge and the UI shows "Pouring…".

## 4. Exercises (Tasting practice)

1. **Conclusions (WSET 3 tasting):** shown appearance, nose and palate; the player picks quality, which of balance,
   length, intensity and complexity are met, and readiness.
2. **Cause to glass (WSET 3 theory):** shown the context (site, vintage weather, harvest, winemaking); the player
   predicts sweetness, acidity, tannin (reds), alcohol and body.
3. **Identify (Diploma-style):** shown the full Tasting sheet; the player names the Variety, the Region and whether
   the vintage was cool, moderate or warm.

## 5. The Wine Fair

- **Stands** are data (`data/fair_stands.json`): title, blurb, Region, Plot, Variety, vintages or style ladder, and
  the quiz topics. First set (all within our three Regions and four Varieties):
  - Burgundy (Côte d'Or Pinot Noir) 2003 · 2004 · 2005 — heat, cool, classic.
  - The 2016 frost — the same Côte d'Or site in 2015 · 2016 · 2017.
  - Mosel ripeness ladder — Kabinett · Spätlese · Auslese from one vintage (style ladder by harvest ripeness).
  - Mosel cool and warm — Riesling from a cool and a warm vintage.
  - Napa Cabernet — a cool year against a hot year.
  - Chardonnay: steel or oak — the same site and vintage, two cellar styles.
  The vintages for "cool/warm" stands are picked from the weather record (coolest and warmest growing-degree days
  in the range), not hard-coded claims.
- **At a stand:** for each Wine in the flight, the player fills in **their Tasting sheet** with pickers in the Tasting
  sheet's structure: clarity; colour intensity and colour; nose intensity; development; aroma families (multi-select
  from the families the model uses); sweetness; acidity; tannin (reds); alcohol; body; flavour intensity; finish;
  quality; readiness.
- **Vintage quiz** (3–5 questions per stand) generated from the Wines' contexts and the weather record, e.g. which
  vintage had the hottest summer, which lost crop to frost and when, why one Wine is lower in acidity, which Wine
  was picked first. Answers come only from simulated or recorded data.
- **Reveal:** the Tasting sheet beside the player's, item by item, with the "because" lines and a mark per item; the
  quiz answers with their evidence (e.g. "2003: 1 540 growing-degree days, the highest of 1995–2025 in the record").

## 6. Marking

- Ordered scales (sweetness … finish, quality) score 1 for an exact match, ½ for one step off, 0 otherwise;
  categorical items (clarity, colour, development, readiness, Variety, Region) 1 or 0; aroma families by overlap
  (Jaccard) of the chosen and the actual families.
- Marking is done in the simulation (`TastingMarker.Mark(sheet, answers)`), not in the UI (ADR 0001).
- **Record:** per skill, a running score (last 20 answers) stored in `user://tasting_record.json` by the game (a study
  record, separate from any Estate save).

## 7. Architecture

- **Sim (`TerroirEngine.Core/Tasting/Practice/`):** `TastingLab` (pour), `WinemakerStyle`, `VintageFacts`
  (weather-record summaries per Region and vintage), `FairStands` (load stands, resolve cool/warm picks),
  `VintageQuiz` (questions + answers + evidence), `TastingMarker`. JSON in/out via `PracticeJson`.
- **Bridge:** `PourFlight(requestJson)` starts a background job; `PourStatus()` / `PourResult()`; `Mark(json)`;
  `FairStands()`. The bridge never decides anything.
- **UI:** a **Tasting practice** screen (exercise picker, one Wine at a time) and a **Wine Fair** screen (stands as
  cards; the stand view with the flight as columns, your Tasting sheet pickers, the quiz, the reveal); a
  **Record** panel. Reachable from the title screen and from the in-game navigation.

## 8. Science and honesty

- Tasting terms are the standard systematic-approach vocabulary; the notes come from our own cited model
  (`docs/science/tasting-sheet.md`, `aroma-and-faults.md`). Nothing is copied from the WSET books.
- Vintage facts come from the ERA5 weather record already cited in `docs/science/weather-and-soil.md`; quiz
  answers quote the numbers.
- Labelled game simplifications: invented producers, scripted cellar styles, the tasting-age cap, the fault rate.

## 9. Testing

- Sim: deterministic pours; each style yields a bottled Wine with a sheet for every Region; the 2016 stand's quiz
  finds the frost; the cool/warm picks match the record; marking scores exact / one-off / wrong as specified.
- UI: fuzz presses every button of both screens; a harness pours a stand, fills a sheet, marks it and checks the
  record file.
- Performance: a four-Wine flight in the background leaves the UI responsive (frame times logged).

## 10. Documentation

`docs/science/tasting-practice.md` (what is simulated, the quiz facts and marking, simplifications); `CONTEXT.md`
entries; README/backlog follow-ups (3D fair hall, more Regions, timed mode, free text).
