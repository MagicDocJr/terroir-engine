# Famous vintages: replay a real year with three medals and a debrief

Status: draft for the owner's review (2026-10-03). Roadmap Phase 4 item 12 of
`docs/research/2026-09-30-fun-and-learning.md`, and the first item of the base-game order agreed on 2026-10-03 (next
up: Vintage in review).

## 1. Intent

You play one real, famous vintage on an established Estate, with three goals of rising difficulty: bronze, silver and
gold. When the Wine is in bottle, a debrief shows:
- which medals you earned, and why;
- what really happened that year;
- what real growers did;
- how your Wine compares.

The fun is a clear goal inside the full simulator. The learning is that weather, choices and law meet in one concrete
year.

**Success:**
- Each scenario plays in one sitting, from January to bottling.
- Bronze is reachable by sensible default play. Silver needs one good decision. Gold needs the right decisions for that
  year.
- Every medal, and every line of the debrief, is judged or cited by the simulation and `docs/science`, never by the UI
  (ADR 0001).

## 2. Constraints

- **ADR 0002 (no future knowledge).**
  - The briefing gives only what a grower knew in January: the place, the vines, the goals, and that the weather is the
    real weather of that year.
  - It never names the event that made the year famous. Forecasts stay as short as in normal play.
  - The debrief reveals everything afterwards.
  - The scenario's title names only the year and the Region, with a neutral teaser.
- **Only years the simulation reproduces.** Checked on 2026-10-03 with practice pours on the scenario plots:

  | Year | Simulation result | Real year |
  |---|---|---|
  | Côte d'Or 2016 | 66 % frost loss, a cool year, high acidity | catastrophic frost on 26–27 April |
  | Côte d'Or 2021 | 88 % frost loss, late harvest | frost on 6–9 April |
  | Mosel 2018 | earliest harvest (23 August), little rot | very hot, dry, healthy |
  | Napa 2011 | cool year, picked on 13 October | cool, late |

  Not reproduced, so not scenarios yet:
  - Mosel 2010 (crop size);
  - Côte d'Or 2003 (harvest timing);
  - Napa 2011's tiny crop (fruit set);
  - the Napa fires and the 2014 earthquake.
- **Medals reward winemaking outcomes, never profit** (research track B §3).
- **No wording or branding from the exam materials. Debrief facts are paraphrased, with their sources.**

## 3. The scenarios (first set: one per Region)

| Id | Title and teaser | Plot and grape | Bronze | Silver | Gold |
|---|---|---|---|---|---|
| `cotedor-2016` | **2016, Côte d'Or**: "a spring growers still talk about" | Village plot, Pinot Noir | bottle a Village AOC Wine | no fault and Good or better | picked ripe (natural ≥ 189 g/L sugar, the Premier Cru minimum, with no chaptalisation) and Very good or better |
| `mosel-2018` | **2018, Mosel**: "a summer to remember" | Blauschiefer, Riesling | bottle a Prädikat Wine | a Kabinett with acidity medium(+) or higher (a fresh wine from a hot year) | silver, plus balance met and Very good or better |
| `napa-2011` | **2011, Napa Valley**: "an unusual year in the valley" | Valley floor, Cabernet Sauvignon | bottle a Napa Valley AVA Wine | no rot taint and ripe tannin (seeds ripe at harvest) | silver, plus Very good or better |

**Final goals after tuning (2026-10-03):**
- Côte d'Or 2016: gold is Very good. "No chaptalisation" and natural ≥ 189 g/L were dropped: growers chaptalised a little
  that year, and every simulated Pinot clears 189 g/L.
- Mosel 2018: gold is balanced and Good.
- Napa 2011: silver is ripe seeds, no rot and balanced; gold is at most 15.0 % vol. Default play reaches silver here.

Full table and tuning evidence: `docs/science/famous-vintages.md`.

**Côte d'Or 2021** is the next scenario to add: its frost is reproduced, but it needs its own debrief research.

**Goal thresholds** are tuned during implementation so that:
- bronze is reached by the default scripted player;
- silver and gold are each reached by a scripted strategy that makes the year's right decisions;
- gold is not reached by default play.

The final values are recorded in the spec and pinned by tests.

**How a medal is judged:**
- The simulation evaluates each goal on the player's best Wine of the scenario vintage.
- Each goal is a typed criterion:
  - legal category in a set;
  - quality at least a level;
  - no fault;
  - no chaptalisation;
  - natural sugar or must weight at least a value;
  - acidity line at least a level;
  - a quality criterion met (balance);
  - seed ripeness at harvest;
  - no rot taint.
- Each criterion returns met or not, with its evidence (for example "natural 183 g/L, below 189").

## 4. Flow

1. **Title screen → Famous vintages.**
   - Cards for each scenario, showing the medal already earned. The best medal is kept in the study record, under a new
     field.
   - Starting one opens the briefing: place, vines, the three goals, and a reminder that the weather is the real
     weather.
2. **The game.**
   - A normal game, started from the scenario's setup: planted three years before the vintage, so it opens on 15 January
     with established vines. The default planting is kept for every Block.
   - The goals stay visible in a small Scenario panel: on the Estate screen, and on a HUD chip that opens it. Goals show
     "to be judged at bottling"; there is no live verdict before the Wine exists.
   - Inbox messages and all systems work as usual.
3. **Debrief**, when the first Wine of the vintage is bottled, and updated if a better one follows:
   - your medals, each criterion with its evidence;
   - "What happened in <year>": the cited vintage note;
   - "What real growers did": cited actions, researched for each scenario;
   - "Your Wine against the real year": harvest date, must weight and yield beside what was reported, where a source
     gives numbers;
   - the year's Causes (for example spring frost and yield, cool season and acidity) join the review queue, with no
     answer counted (as learn-card checks do).

   The Vintage card for the year opens in the Cellar book.
4. **After the debrief:** keep playing the Estate as a normal game, or return to the title screen. Saves work as usual.
   The setup records the scenario id, so a loaded scenario game shows its panel and debrief.

## 5. Architecture

- **`data/scenarios.json`:** id, region, plot, variety, vintage, title, teaser, briefing, goals (typed criteria per
  medal), the debrief's "what real growers did" paragraphs with source keys, and the comparison numbers with sources.
- **`sim/.../Game/Scenarios.cs`:**
  - `Catalog(data)`, with a validator: every source key resolves to `docs/science/vintage-notes.md`, every criterion
    type is known, and the plot and variety exist;
  - `Setup(scenario) → GameSetup` (adds `ScenarioId`);
  - `Evaluate(game) → medals with evidence`;
  - `Debrief(game) → JSON`;
  - `RecordMedal(studyRecord, id, medal)`.
- **Bridge:**
  - `ScenarioList()` (with best medals);
  - `NewScenarioGame(id)`;
  - `ScenarioStatus()` (goals; the debrief once bottled);
  - `ScenarioDebriefSeen()`.
- **UI:**
  - the title-screen list and briefing;
  - a Scenario panel on the Estate screen plus the HUD chip;
  - a debrief screen;
  - medal chips.

  The UI reads JSON only.
- **Harness:** `scripts/scenarios.sh` plays each scenario with the default and the "right decisions" scripted players,
  checks the medals and screenshots the briefing, panel and debrief.

## 6. Debrief research

For each scenario, sourced facts on what growers actually did that year (for example frost fighting, sorting,
chaptalisation or acidity choices, picking dates) are added to `docs/science/vintage-notes.md`.

Rules:
- Paraphrased, with URLs.
- Unbacked lines are left out, not marked.
- If a scenario has too little sourced grower action, the debrief shows only the sourced outcome.

## 7. Out of scope (to the backlog)

- **Frost protection** as a player action (candles, wind machines, sprinklers). Track C lists it as an exam topic. It
  would make the frost scenarios richer, but it is its own feature.
- **Blind-vintage mode** (a hidden year, revealed at bottling).
- **Côte d'Or 2003, Mosel 2010 and the Napa fire years.** These need simulation fixes first.
- **Scenario leaderboards or timers.**

## 8. Risks

- **Too easy or too hard.** The thresholds are tuned with scripted players, and the tests pin that bronze is reachable by
  default and gold is not.
- **Debrief accuracy.** Only sourced lines are shown, under the same rule as the Vintage cards.
- **A scenario game is a normal save,** so a player could keep it running for years. The medal judges only the scenario
  vintage.
