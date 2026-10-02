# The learning core — design

Status: direction agreed by the owner 2026-10-02 ("agree, go ahead as long as the UI still looks clean and not too
overcrowded. Each learning needs to actually be top quality and not something we just added for adding's sake. It needs to
earn its place with state-of-the-art quality and pedagogical approach"). Evidence: `docs/research/2026-09-30-*.md`
(track A learning science, B fun, C WSET alignment), cited below as A§n, B§n, C§n. Vocabulary follows `CONTEXT.md`; new
terms in §2.

## 1. Goal

Make the game a study tool that works the way the evidence says people learn durably, without making it feel like
homework or cluttering the screens.

**Success looks like**
- Every important cause in the simulation ("sun-exposed bunches + bottle age → petrol") is something the game teaches,
  checks, and brings back at spaced intervals until the player knows it, using a *new* Wine each time.
- Before any reveal (a Tasting-practice answer, the Tasting sheet of the player's own Wine) the player commits to an answer
  and a confidence; the feedback explains the cause, for right answers too.
- At every real decision in the game (planting, vineyard, cellar), one quiet "Learn" link opens a card of top quality:
  what the choice is, what it does to the wine and why, what it means on this site, and what the exam asks. When that
  choice's result shows up later, the game asks what the player thinks it did.
- Ranks and progress report what the player durably knows, not how much they clicked.
- The screens look as clean as today: one small affordance per choice, a side drawer instead of pop-ups, nothing forced.

**The quality bar (owner's brief, binding).** Nothing is added for its own sake. A learn card, a question or a feature ships
only if it passes the gate in §7.4. Fewer, better cards beat full coverage.

**Non-goals (later specs, already in the roadmap):** the Tasting-sheet conformance pass and quality recalibration
("Tasting sheet 2"), pair play, new Regions or grapes, sparkling and fortified, free-text answers, famous-vintage scenarios.

## 2. Glossary additions (`CONTEXT.md`)

- **Cause**: one cause→effect link the simulation models and the game teaches (e.g. "cool fermentation keeps fruity
  esters"). It has a chain of 2–4 steps from a condition or decision to what is in the glass.
- **Learn card**: the explanation shown at a decision, in one fixed structure (§7.1).
- **Review queue**: the Causes due to be checked again, by date.
- **Known**: a Cause answered right on three separate days (§4.3).
- **Confidence**: the player's "guess / think so / sure" before a reveal.
- **Weekly rhythm**: the study habit counter (days studied out of seven), replacing the daily streak.
- **Exam date**: the date the player is studying towards; it shapes the review schedule.

## 3. Pillar 1: Causes

### 3.1 The catalogue
`data/causes.json`, authored, each entry:
- `id`, `title` (plain words), `chain` (2–4 steps, condition → mechanism → effect in the grape or wine → in the glass)
- `topic`: the Level 3 learning-outcome area it serves, paraphrased (e.g. "LO1 winemaking: fermentation temperature"),
  and `level` (L3 or Diploma)
- `sources`: the `docs/science/` section(s) that back every step (no step without a source)
- `exercise`: which question forms can test it (§4.4)
- `pour`: hints for finding a Wine that shows it (Region, grape, style, vintage class), used by the review pours (§4.5)

**First catalogue, about 35 Causes**, limited to what the simulation models today and its docs back, for example:
- **Climate and vintage:** a cool season keeps malic acid; heat burns it off and raises potential alcohol; spring frost
  kills shoots and cuts yield; rain before harvest dilutes and invites rot; noble rot in misty-then-dry autumns.
- **Site:** a steep south slope gains heat; frost settles in low spots.
- **Canopy and crop:** sun on the bunches raises TDN precursors and lowers pyrazines; a low yield concentrates flavour.
- **Harvest:** picking date sets sugar, acid and pyrazines; seed ripeness and tannin quality.
- **Cellar:**
  - cool fermentation keeps esters; low YAN → H₂S
  - whole bunch → stem tannin and lift; extended maceration → more tannin
  - MLF → lower TA, buttery diacetyl; lees and bâtonnage → bread and texture
  - new French oak → vanilla and toast; American oak → coconut
  - stopping fermentation → sweetness; chaptalisation → alcohol
- **Age:** bottle age → tertiary aromas and garnet colour.
- **Faults:** Brett ← high pH, low molecular SO₂, used barrels; VA; oxidation.

### 3.2 Tagging in the simulation
`TastingSheetGenerator` already writes a "because" at every point where a descriptor is caused. Each of those points now
also tags the Cause id(s): `Descriptor.Causes`, `StructureLine.Causes`, `TastingSheet.Causes`. This is a structured
by-product of the existing logic, not a new model.

Tests:
- every tag exists in the catalogue
- every catalogue Cause is emitted by at least one reference pour
- tags are deterministic

### 3.3 Causes from the player's own Estate
Choices and events in a game (the frost night, the pick date, MLF blocked) produce the same tags on the player's Wines. At
bottling (§6) the Causes behind the player's own Wine enter the review queue as personal items ("your 2018 Block B
sunburn"): the strongest kind of example, because the player lived it.

## 4. Pillar 2: The review queue

### 4.1 Scheduling (A§1)
- A new or missed Cause comes back after **1, 3, 7, 16 and 35 days**. After that, a light FSRS-style model per Cause
  (stability, difficulty) schedules each review for a target recall of 0.88.
- Never re-test a Cause in the same sitting where it was learnt or missed; the first retrieval is the next session.
- An unsure right answer (Confidence "guess") is scheduled as harder than a sure right answer.
- A sure wrong answer comes back the next day (hypercorrection, A§3).

### 4.2 Exam date (A§1, §8)
- Optional, set on the Tasting-practice screen.
- Every catalogue Cause gets at least three spaced successful retrievals before the date.
- Late gaps stay at about 5–10 % of the remaining time; the last 2–3 weeks tighten to 3–5 days.
- A small coverage view shows Causes per topic: Known / learning / not seen.

### 4.3 Mastery (A§1, §8)
- A Cause is **Known** after three right answers on three separate days.
- It stops being Known if missed twice in a row after that.
- Ranks are recomputed from Known Causes as a share of the catalogue:
  - Cellar hand 15 %
  - Taster 40 % (opens blind Flights)
  - Senior taster 70 %
  - Fair judge 95 %
- XP stays only as a quiet tally, not the rank (B§2: rewards must report mastery).
- Replaying, volume or speed earn nothing.
- Medals at the Wine Fair stay; they mark a Flight's result.

### 4.4 Question forms (all exist or reuse existing marking)
- **Palate prediction:** cause-to-glass line, e.g. acidity of a cool-year Riesling.
- **Aroma family:** which family appears and why.
- **Chain fill-in:** one or two links of the Cause's chain blank, picked from options with plausible decoys. It fades from
  worked chain → one blank → two blanks → full prediction as the Cause matures (A§4).
- **Contrast pair:** two Wines differing in this one Cause: "which single cause separates them?" (A§2). Used once a Cause
  has been seen twice.

### 4.5 Review pours
A due Cause is checked with a **new Wine** that shows it (A§1: transfer, not item memory):
- the `pour` hints pick a candidate (another vintage, Block, producer)
- the lab pours it, and keeps it only if the Cause's tag appears on its sheet
- up to six tries; otherwise the review falls back to a chain fill-in
- miscalibrated years stay excluded (`PracticePours.Miscalibrated`)

### 4.6 Sessions
A Tasting-practice session mixes about **60 % due reviews, 25 % the weak spot, 15 % new** (A§2: no pure drilling of one
skill). Due items also seed the Glass of the day and one or two glasses of every Wine Fair Flight.

### 4.7 The weekly rhythm (A§8, B§2)
- Replaces the daily streak: "4 of 7 days this week".
- A missed day can be repaired by doing the reviews later that week.
- Wording stays neutral ("Your cellar waited for you"); nothing resets loudly.

## 5. Pillar 3: Commit, then reveal (Confidence and feedback)

- **Confidence before every reveal**: one tap, guess / think so / sure, on each marked item (A§3).
- **Four cases**, never right/wrong only:
  - *Sure and wrong:* a clear "surprise" card with the whole chain; the Cause comes back tomorrow.
  - *Guess and right:* the full explanation; scheduled as hard.
  - *Sure and right:* a short confirmation, with the chain one tap away.
  - *Guess and wrong:* the explanation, and the next attempt starts one fade step easier.
- **The "because" on right answers too.** An end-of-Flight recap re-shows only the misses (delayed feedback).
- **Label hidden until after judgement** at the Wine Fair (Morrot 2001; exam wines are blind). The Shown vintage remains for
  vintage stands, where the vintage *is* the theme.
- **Progress view**, replacing the XP-centred panels:
  - per-skill competence over time ("acidity calls 58 % → 74 %")
  - a calibration chart (confidence vs actual accuracy, plus one plain-language line: "When you are sure you are right
    88 % of the time")
  - Known Causes per topic
  It measures with delayed checks, never in-session accuracy (A pitfalls).

## 6. Pillar 4: Predict before reveal on the Estate

- **At bottling**, before a new Wine's Tasting sheet opens, a short prediction panel (B§1 idea 1, A§5):
  - acidity, alcohol band, the leading aroma family, and quality band, each with Confidence
  - then the sheet opens with the four-case verdicts beside the lines
  - at most four questions, skippable
- **Choice recall.** For up to two of the decisions the player made that season with a learn card behind them (§7), the
  reveal asks "what did your choice of X do in this Wine?" and points to the line it caused. Those Causes enter the queue
  as personal items.
- In a game the predictions count as study (they feed the queue and the Progress view) but never change the Wine or the
  score.

## 7. Pillar 5: Learn at the moment of choice

### 7.1 The card (one structure, always)
1. **What it is.** One or two sentences, plus a visual where the concept is visual (§7.3).
2. **What it does.** The Cause chain(s) from this choice to the glass, 2–4 steps each, written as "because → therefore".
3. **On this site.** One or two lines computed from the game's own data for the Block in front of the player, e.g. "Block A:
   58 % slope, no wires possible, so single-stake (Einzelpfahl)"; "your must has YAN 120 mg/L: below the 140–150 where
   yeast start making H₂S". This is what makes it more than a textbook.
4. **What the exam wants.** One short line on how a Level 3 question would probe it, in our own words, and the command-verb
   habit ("explain = cause → effect → style").
5. **Check yourself.** One retrieval question with options and an elaborated answer. Answering it adds the Cause to the
   queue; skipping is fine.
6. **Sources.** The `docs/science/` sections, one tap away.

Main text 120–180 words; a mastered card collapses to its one-line chain with "more". Two depths: *full* for a Cause the
player has not yet Known, *brief* (sections 2–3 only) once Known. No difficulty setting is needed; the Known state drives it
(expertise reversal, A§4).

### 7.2 Where cards appear (first set, chosen by how often the decision comes up and its exam weight)
1. **Planting:** training system, rootstock, density and row orientation, Variety on this site. These replace and upgrade the
   current Planting guide tabs, keeping its drawings.
2. **Vineyard:**
   - bud load at pruning
   - canopy and leaf removal
   - the spray Programme and disease pressure
   - green harvest and yield
   - harvest date
   - hand vs machine picking and sorting
3. **Cellar:**
   - destemming and whole bunch; cold soak; cap management; maceration length
   - yeast; nutrients; fermentation temperature
   - chaptalisation and acidification; stopping for sweetness
   - MLF; vessel and oak; toast; lees and bâtonnage; SO₂
   - fining and filtration; closures; blending

That is about 30 decision points. **The plan builds the 12 most valuable first** (training system, rootstock, harvest date,
canopy/leaf removal, yield, whole bunch, fermentation temperature, nutrients/YAN, MLF, vessel/oak, lees, stopping for
sweetness). The rest follow in the same pattern only as each passes the gate. Each card replaces the existing one-line
tooltip at that choice: the tooltip stays as a short summary, the card is the full lesson.

### 7.3 Visuals that earn their place
- **Training systems:** a live 3D turntable of the game's own vine model in Einzelpfahl, Guyot and Cordon, switchable
  between winter (pruned wood) and summer (canopy). The vine models already exist; the card renders them in a small
  viewport. The current 2D drawings stay as the fallback.
- **Rootstocks:** root depth and vigour diagram against this Block's soil profile, which the Plot screen already draws.
- **Canopy and leaf removal:** exposure of the fruit zone, morning vs afternoon side, tied to sunburn risk.
- **Harvest date:** the Block's own ripening curves (sugar, acid, pyrazines) with the pick window marked, from Ripeness.
- **MLF:** malic → lactic acid bar, with TA and pH before and after for this Lot.
- **Oak:** oak types and toast levels → aroma families (vanilla, coconut, smoke, clove), the families the sheet uses.
- No decorative pictures: a card with no visual that explains more than text could has no visual.

### 7.4 The quality gate (every card, every question; binding)
A card ships only if all of these hold:
1. It answers a decision the player faces at that moment.
2. Every step of its chain is backed by a cited `docs/science/` section and matches what the simulation does. A reference
   pour shows the effect.
3. It maps to a Level 3 learning-outcome area (or is tagged Diploma).
4. Its "On this site" line uses the player's actual data.
5. Its visual, if any, explains something text alone could not.
6. It has one retrieval question with plausible decoys and an explanatory answer.
7. It uses no WSET wording, grids or branding, and no `UNVERIFIED` claim in the main text. Game simplifications appear only
   as a labelled footnote.
8. It reads aloud in under a minute, at a 120–180 word budget.
9. It passes review twice:
   - a reviewer subagent scores it against a rubric (accuracy, causal clarity, site relevance, exam relevance, brevity,
     visual value), each 1–5; ship at ≥ 4 on every line
   - the owner sees screenshots, and the Level 3 partner is invited to review

A validator test enforces the mechanical parts: sources present and resolvable, word budget, chain length, a question
present, Cause ids existing.

### 7.5 Clean-UI rules (binding)
- One affordance per choice: a small "Learn" link (gold dot the first time the choice appears in the game), next to the
  choice label. No icons sprinkled through tables.
- The card opens in a **side drawer** (about 40 % width, right side), never a modal. The choice stays visible and usable;
  Esc or a click outside closes it. Drawers never stack: opening another card replaces it.
- No automatic pop-ups. The only new step in the flow is the bottling prediction panel, which is short and skippable.
- Existing screens get no new permanent panels. The Progress view lives in Tasting practice.
- Every touched screen is screenshot-reviewed against a clutter checklist: one new element per choice row at most; no
  text below 13 px; the 1920×1080 layout unchanged in density.

## 8. Architecture

**Sim (`TerroirEngine.Core/Learning/`)**
- `CauseCatalog`: loads and validates `data/causes.json`.
- Cause tags in `TastingSheetGenerator`.
- `ReviewScheduler`: ladder + FSRS-lite + exam date.
- `StudyRecord` v2: Causes with state, history and Confidence. It migrates the v1 Tasting-practice record losslessly,
  keeping XP, medals, cards and history.
- `SessionComposer`: due / weak / new mix and review pours with tag verification.
- `Predictions`: bottling predictions and choice recall for a game's Wine.
- `LearnCards`: loads `data/learn/*.json`, validates, and fills "On this site" from snapshot data.
- `PracticeSession`, `PracticeProgress` and `TastingMarker` extend to Confidence and Cause tags.
- ADR 0001: the sim decides, schedules and marks; the UI shows.

**Bridge:** LearnCard(id, context) → JSON; Due/Session start through the existing pour job; Predict/Reveal for a game's
Wine; Progress().

**UI:**
- `learn_drawer.gd`: drawer, card layout, 3D turntable viewport, diagrams.
- Learn links on planting, plot/programmes/ripeness and winery choices.
- Confidence row in the answer pickers.
- Bottling prediction panel on Wines.
- Progress view in Tasting practice.
- Weekly rhythm and exam-date controls.

## 9. Science and honesty
- Every card step and Cause step is cited in `docs/science/`. New facts needed for cards (e.g. training-system trade-offs
  beyond `canopy-and-yield.md`) are researched, cited and added to the science docs first.
- The game says plainly what it cannot train (the nose) on the Progress view (A§7).
- Counterfactual statements appear only where the model is calibrated.
- Exam framing is paraphrased; the game never claims WSET endorsement.

## 10. Testing
- **Sim:**
  - catalogue validation; tag coverage and determinism
  - scheduler: ladder intervals, no same-session re-test, hypercorrection rescheduling, mastery and loss of mastery, exam
    compression, FSRS update bounds
  - session mix
  - review pours show the tag, with the fallback
  - v1 → v2 migration, lossless and tolerant
  - predictions marked; choice recall picks the player's real choices
  - learn-card validator and "On this site" filling
- **UI:**
  - a `--learning` harness: open each first-set card from its screen, answer its check, run a review session with
    Confidence, bottle a Wine through the prediction panel, check the record
  - fuzz over the touched screens
  - screenshots of every card and touched screen, reviewed against the clutter checklist
- **Content:** the reviewer-subagent rubric pass over all shipped cards before merge; the owner's screenshot review.

## 11. Milestones (each shippable)
1. Causes: catalogue, tags, validation.
2. Review queue: scheduler, record v2 and migration, session mix, mastery ranks, weekly rhythm.
3. Commit then reveal: Confidence, four-case feedback, recap, hidden labels, the Progress view.
4. Estate: bottling predictions and choice recall.
5. Learn cards: drawer, the first 12 cards through the gate, the training-system 3D turntable.
6. Exam date and coverage view; docs (`CONTEXT.md`, science notes, README, backlog).
