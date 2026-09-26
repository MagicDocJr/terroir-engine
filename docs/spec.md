# Terroir Engine — MVP Specification

Status: agreed 2026-09-26 (grilling session). Vocabulary follows `CONTEXT.md`; deferred scope lives in `docs/backlog.md`; hard-to-reverse decisions in `docs/adr/`.

## 1. Vision

A realistic vineyard-founding and winemaking simulator for a private audience: the owner and a WSET Level 3 (Distinction) student heading for the Diploma. The player buys bare land, plants vines, runs the vineyard and makes wine. Every outcome comes from real viticultural and oenological science. The management layer is a dense, Football Manager-style dashboard. A realistic 3D view lets the player walk the vineyard and the Winery and watch what their decisions have done.

**Accuracy bar:** a player who learns from this game should be able to pass WSET Level 2, 3 and 4 on that knowledge, with no wrong information picked up along the way.

## 2. Audience and platform

- Private project. It runs only on the owner's PC (RTX 5080, Ryzen 7 9800X3D, 32 GB). No low-end graphics preset is needed.
- English UI, keeping terms native to each Region (Einzelpfahl, Kabinett, remontage, bâtonnage).
- Development is AI-first: Claude writes everything. Tooling is chosen for how well AI can build and verify it, and must be free.

## 3. Game structure

### 3.1 Start
1. Pick a **Region**: Mosel, Côte d'Or or Napa Valley.
2. Compare that Region's 4 **Plots** side by side (attribute grids like FM's player comparison), with the **Mentor** commenting. Buy one with starting capital.
3. Choose the **Planting** year (1990–2022). This fixes where the game starts on the **Timeline**.
4. Make the **Planting** decisions per **Block**: Variety, rootstock, density, row orientation and training system.
5. **Establishment** is fast-forwarded on Historical weather, with a summary report from the Mentor each year. Young-vine losses can happen (e.g. drought in the planting year), and replanting costs money.
6. Play the **4th-leaf Vintage** in full, flagged as "young vines".
7. Ferment, age and blend into up to about 3 **Wines**, then bottle. The Mentor retires, and the **MVP ends**.

### 3.2 End of MVP
For each Wine the player gets:
- a **Tasting sheet**: appearance, nose, palate and conclusions (Poor to Outstanding, reasoned from balance, length, intensity and complexity). Every descriptor is linked to the decision or condition that caused it.
- its **Legal category**
- a **P&L**: bottles × a price set by Legal category and quality, minus costs

There is no declared style target. The market rewards Legal category and quality.

### 3.3 Time
- The engine simulates **daily**. Fermentation and maceration run at an **hourly** sub-step.
- Time controls: +1 day, +1 week, "advance until…", and continuous play at an adjustable speed.
- **Alerts** stop time automatically (frost warning, disease-risk threshold crossed, a decision point, harvest window).
- The 3D view always shows the current simulated day.

### 3.4 Weather
- **Historical weather** comes from the Open-Meteo / ERA5 archive, baked in at build time, and covers every Timeline year the archive has. ERA5 is coarse (a ~9 km grid), so each Block adjusts it for elevation (≈ −0.6 °C per 100 m), slope, aspect and frost pockets. The calibration table tests these adjustments.
- **Synthetic weather** (seeded) takes over after the archive ends, built from recent climate plus the warming trend.
- The advisor may add **real vintage notes** (cited).
- Game simplifications, labelled in-game: every year uses EUR at 2026 price levels and today's wine law.

## 4. Content

### 4.1 Varieties
Riesling, Chardonnay, Pinot Noir, Cabernet Sauvignon. Any Variety can be planted anywhere; a poor match shows up as poor results, never as a blocked choice.

### 4.2 Regions and Plots
There are 4 fictional Plots per Region, modelled on real types. The Region names are real. Plots are 0.5–2 ha, in EUR with realistic price ratios. Starting capital covers a cheap or middle Plot plus one vintage of costs.

| Region | Cheap | Mid-low | Mid-high | Expensive |
|---|---|---|---|---|
| Mosel | Flat riverbank alluvium: fertile, vigorous, frost pocket | Gentle east-facing side valley, loess over slate, cool | Steep SW-facing blue Devonian slate | Very steep south-facing slate terraces: hand work only, high labour cost |
| Côte d'Or | Flat land below the slope, deep clay, frost-prone (Bourgogne AOC) | Hautes-Côtes plateau ~400 m, cool, late ripening | Village-level mid-slope, marl + limestone | Premier Cru mid-slope, thin limestone rubble, E/SE-facing |
| Napa | Valley-floor heavy loam: vigorous, frost in low spots | Carneros: cool, foggy, clay | Mountain hillside above the fog line: thin volcanic soil | Gravelly alluvial fan ("bench"), the benchmark Cabernet site |

Each Plot has 3–6 Blocks, each with its own soil profile and microclimate.

### 4.3 Planting options
- **Variety:** the 4 above.
- **Rootstock:** own-rooted (with a phylloxera warning), 3309C, SO4, 1103 Paulsen, Fercal.
- **Density:** low / medium / high (~2,500 / 5,000 / 10,000 vines/ha).
- **Row orientation:** N–S or E–W. On steep slopes rows are locked to run straight downhill.
- **Training system:** Einzelpfahl (steep slopes only), Guyot (cane, VSP), Cordon (spur, VSP).

### 4.4 Legal rulebooks (simplified, built to be extended)
- **Mosel:** Prädikat categories by must weight. Chaptalisation is only allowed for Qualitätswein.
- **Côte d'Or:** a Plot's **Classification** caps its Legal category. Varieties are restricted: anything not permitted can only be sold as Vin de France.
- **Napa:** AVA rules. A varietal label needs ≥75% of that variety, and ≥85% of the fruit must come from the AVA.

### 4.5 Hazards in the MVP
Everything here is derived from weather and soil:
- spring frost, heatwave/sunburn, drought/water stress
- rain at harvest → botrytis
- downy and powdery mildew
- poor fruit set (coulure/millerandage)
- lime-induced chlorosis (soil + rootstock)

Hail, smoke taint and pests are in the backlog.

## 5. Decisions and management

### 5.1 Tiered Programmes (Low / Medium / High)
Spraying, canopy work, floor/weed management, labour crew size, irrigation (where legal), frost protection. Staff carry them out daily. The player can override any single event.

Cutting spend has consequences through the simulation:
- a lower spray tier → more infection gets through
- a smaller crew → tasks done late, harvest stretched over more days (ripeness drift, rot risk)

### 5.2 Explicit choices (these are the teaching content)
- **Vineyard:** Planting; bud load at pruning; **harvest date per Block**; hand vs. machine picking; sorting.
- **Cellar:** destem vs. whole bunch; cold soak; yeast (ambient vs. cultured); fermentation temperature; cap management; MLF yes/no; vessel (steel / old oak / new oak, French vs. American, toast); time in oak; lees stirring; stopping fermentation for sweetness; chaptalisation/acidification (subject to law); fining/filtration; blending Lots into Wines.

### 5.3 Economy (minimal)
Starting capital, plot prices, running costs (labour, sprays, barrels priced by origin, grain, toast and new vs. used), staff salaries, and sale of the bottled Wine. A **basic Winery** comes with the Estate: temperature-controlled steel tanks, a press and a cellar.

### 5.4 Staff
A **Vineyard manager** and a **Cellar master**, each hired at a **Staff level** (Junior / Experienced / Senior) with matching salary.
- **Advice is correct at every level.** Higher levels give more detail, earlier warnings and better ideas, and explain concepts in depth.
- **Execution** is better at higher levels: sprays timed better, crew hours used better, fermentation temperature controlled more tightly, fewer faults.
- **What staff can know:** only what a real person would know that day. That means the weather so far, climate normals, lab values, their own observations, and a forecast with realistic uncertainty. Seniors get a sharper and longer forecast (≈10–14 days vs. 7), lessons from the Region's climate history ("after a warm March, frost after budburst is common here"), and they test more options against more possible weather outcomes. **Nobody reads the real future.** Seniors can be wrong about the weather, never about the science.

### 5.5 Mentor (storyline and onboarding)
- One local, named expert per Region, about to retire.
- Guides the player from Plot purchase through Planting, Establishment, the first Vintage, ageing and bottling, then retires. The MVP ends there.
- Gives Senior-level advice with full explanations, but does **no work**. The player still hires their own staff.
- Free. There is no separate tutorial; the Glossary is always one click away.

## 6. Modes
- **Normal mode** (MVP): concepts shown at WSET Level 3 depth. Lab values are exact, free and updated weekly while the grapes ripen.
- **Hard mode** (backlog): Diploma-level detail, lab costs and sampling error.
- The engine always simulates at full depth. The mode only changes what the player is shown.

## 7. Measurement
In Normal mode, measured values are exact. The 3D view adds qualitative cues: leaf colour, wilting, seed colour, cap and foam.

## 8. Presentation

### 8.1 Dashboard (primary interface)
- **Top bar:** date, vine stage, weather now + 7-day forecast, cash, time controls, Alert counter.
- **Left menu:** Inbox (Alerts + staff and Mentor messages), Estate, Plot & Blocks, Weather, Programmes, Ripeness, Winery, Blending, Wines, Glossary, 3D (Tab toggles).
- Aim for FM-level density without a spreadsheet feel: colour-coded cells, sparklines, soil-profile and vine-stage diagrams, and staff reports with their reasoning.
- UI design is **iterative**: a first-pass clickable prototype with fake data right after the engine demo, then another round once the game runs on real data.

### 8.2 3D view (look-only in the MVP)
- **Vineyard:** the owned Plot and its Blocks, with the full season on the vines (budburst → leaf fall), weather (rain, fog, frost), a real solar path (one solar module shared with the simulation), and soil and stones that differ per Block.
- **Processes you can watch:** crews doing the current task, and a sprayer tractor driving the rows on its own.
- **Winery:** fermentation tanks with the cap visible and pump-overs running; the barrel room with barrels marked by oak and toast; readouts shown in the scene.
- **Cameras:** first-person walking (WASD + mouse), plus a drone view of the whole Plot.
- **Ambient sound** per Region and place.
- Hands-on tasks are in the backlog.

## 9. Science and accuracy
- `docs/science/*.md` has one file per model (phenology, water balance, disease, ripening, fermentation, acid/pH/SO₂, extraction, aroma, oak, law, economy), each with formulas and citations. Sources: open literature (UC Davis / UC IPM, AWRI, peer-reviewed papers, the California Grape Crush Report, German harvest statistics), standard references (flagged as cited from memory), and the owner's WSET L2/L3 books in `reference/` (gitignored; paraphrased, never copied).
- **Rules:**
  1. Every factual statement in the game is literature-correct and cited.
  2. Simulated numbers stay within real-world ranges (the calibration table).
  3. Deliberate game simplifications are labelled "Game simplification".
  4. Anything that isn't backed by a source is marked `UNVERIFIED`.
- **Human review:** the WSET L3 student checks the calibration table and Tasting sheets at this computer. Reviews must be short, non-technical and easy (about 10 minutes, ✓/✗ plus a comment).
- No WSET name or logo in the game, and the SAT is not reproduced verbatim. The Tasting sheet uses our own wording in the same structure.

## 10. Architecture principles
- The **simulation core is a pure, headless, deterministic library** with no engine or UI dependency, tested from the command line (ADR 0001).
- A save file is the starting parameters plus the player's decision log. Replaying the log reproduces the game exactly, and any bug report becomes a test case.
- Every state is modelled with multi-vintage continuation in mind (ADR 0002), even though the MVP plays one vintage.
- **Engine:** Godot 4.7 (.NET) for the 3D views and the dashboard. The simulation core is a plain C# library tested with `dotnet test` (ADR 0003).
- Assets: Blender 5.2 LTS through Blender MCP, plus CC0/CC-BY textures and sounds with credits.

## 11. Milestones
0. **Engine demo** ✅ done: Godot chosen (ADR 0003; prototype on branch `prototype/engine-demo`). Next: the first **UI prototype** with fake data.
1. **Science pass:** `docs/science/`, calibration table → **review #1**.
2. **Simulation core:** weather ingest, vine stages (phenology), water balance, soil per Block. A season runs from the command line.
3. **Vineyard:** Programmes, disease, frost, ripening, yield, Planting, Establishment.
4. **Winery:** fermentation, MLF, extraction, oak, blending, Legal category.
5. **Tasting sheet + P&L** → **review #2**.
6. **Dashboard:** a full vintage playable without 3D (second UI round).
7. **3D vineyard** tied to the simulation state.
8. **3D Winery.**
9. **Polish:** post-processing, sound, performance → **playtest**.

## 12. Verification
- Every model has unit tests, plus property tests for conservation laws (sugar and ethanol mass balance, acid and pH consistency, SO₂ bounds).
- Calibration tests: scripted "golden" vintages must land inside literature ranges.
- A scripted player plays whole vintages end to end.
- 3D: screenshots from fixed camera positions at fixed simulated times, which Claude inspects, plus draw-call and instance-count checks. The owner checks FPS on the real machine.
