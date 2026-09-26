# Terroir Engine MVP: morning report (27 Sep 2026)

## TL;DR

You can play the MVP from start to finish. Pick a Region, compare its Plots, plant every Block, then play the fourth-leaf Vintage day by day on the real Historical weather. Harvest each Block when you choose, make every cellar decision, blend and bottle, and read a Tasting sheet that explains each descriptor. The Mentor retires once everything is in bottle.

Everything runs through the headless C# simulation (22 tests pass). The Godot dashboard only displays snapshots and sends commands. I played scripted games on all 12 Plots, and played the full game through the real UI in all three Regions. A robot also pressed every button on every screen across a whole Vintage, with no script errors. Save and load reproduce the game exactly.

The 3D vineyard and winery are merged in and follow the game state. Press Tab to open them. See [3D status](#3d-status).

## How to run

**Easiest:** double-click `play.bat` in the repo root. It builds the C# code and opens the game.

Other ways to start it:
- From WSL: `scripts/play.sh`
- In the Godot editor: open `game/project.godot` in the **.NET** Godot build (`Godot_v4.7.2-stable_mono_win64.exe`) and press F5.

The game autosaves after every time step. **Load** on the title screen picks up where you left off. Ctrl+S makes a manual save.

### Controls

| Key | Does |
|---|---|
| 1–9, 0 | Switch screens (Inbox, Estate, Plot & Blocks, Weather, Programmes, Ripeness, Winery, Blending, Wines, Glossary) |
| Space | +1 day |
| P | Play / pause. Time runs at 4, 8 or 16 days a second and stops at the next Alert |
| Enter | Continue: run until the next Alert (at most 60 days) |
| Tab | 3D view (Tab or Esc again to leave) |
| Ctrl+S | Save |

### A good first session (about 30 minutes)

1. Choose **Mosel → Blauschiefer-Hang**, keep the Mentor's Planting, and leave the planting year at 2015. Your first Vintage is then 2018, a very hot, early year.
2. In January, open **Programmes** and **Plot & Blocks** and try a few choices (bud load, leaf-removal side).
3. Press **P** and let the season run. Alerts stop time: budburst, frost warnings, flowering, heatwaves, véraison, the harvest window and weekly samples.
4. From late August, open **Ripeness**. Pick some Blocks early (Kabinett) and let others hang (Spätlese/Auslese), and compare.
5. In the **Winery**, change a few choices per Lot (for example stop one Lot off-dry). Blend or bottle in **Blending**, then read the **Wines** screen.

## What is in the MVP

**Before the game**
- Title screen with New game and Load (lists your saves).
- Region picker.
- Plot comparison: FM-style 1–20 ratings for Heat, Frost safety, Water reserve, Drainage, Workability, Prestige and Value. It also shows the cost up to the first sale, an affordability warning, the Mentor's comments and every Block's soil.
- Planting per Block: Variety, rootstock, training, density and row orientation. Rows are locked downhill on steep Plots, and a warning appears if the rootstock risks lime chlorosis.
- Planting year (1990–2022), both staff levels with their part-time cost, and the estate name.

**During the game** (ten screens)
- **Inbox**: messages from staff and the Mentor. Each has a **Why** box and action buttons (open a screen, raise frost protection, harvest, restart a ferment…). Alerts stop time.
- **Estate**: cash tiles and a cash chart, P&L (this Vintage and since founding), a ledger grouped per month, hiring staff, the Establishment history, and an end-of-game summary.
- **Plot & Blocks**: a Block table (stage, health, water stress, disease risks, crop, must). For the selected Block: a soil column, vine state, per-Block choices (bud load, leaf-removal side and timing, green harvest) and a harvest order (hand or machine, sorting level).
- **Weather**: the staff forecast (horizon depends on staff level), heat accumulation and weekly temperature against the 1991–2020 normal, monthly rain against normal, disease-risk history, season indices and phenology.
- **Programmes**: six Low/Medium/High tiers, each with its effect and cost.
- **Ripeness**: a harvest planner with every Block's must and the highest style its must weight reaches, plus sugar charts against style bands and acidity charts.
- **Winery**: one tab per Lot, live analysis tiles, fermentation and temperature curves, cellar choices (🔒 once they can no longer change) and the cellar log. A stuck ferment can be restarted or stopped where it is.
- **Blending**: pick 0–100 % of each ready Lot, then name the wine, choose the closure, filtration and fining, and bottle.
- **Wines**: the Tasting sheet (appearance, nose with aroma families, palate, conclusions). Every line says *because…*. It also shows the four quality criteria, readiness, legal category and notes, price, and the lab analysis at bottling.
- **Glossary**: read live from `CONTEXT.md`, plus the controls.

## Fixes made during playtesting

Playing through the real UI showed several things that were wrong. All of these are fixed and committed:

| Problem seen | Fix |
|---|---|
| A whole Block picked at 111 °Oe was labelled **Beerenauslese** and sold €577k from 1.2 ha | BA/TBA now need noble rot (game rule: ≥ 30 % / ≥ 60 %). A dry Auslese is priced below a sweet one. A Mosel site factor stops flat riverbank wine selling at steep-slope prices |
| Staff cost €78k a year on a 1.2 ha estate | Staff are now **part-time posts** sized to the estate, as `economy.md §7` already specified, with the regional salary multiplier |
| Every Côte d'Or wine had **Brett** | The default SO₂ now adjusts to pH (molecular 0.8 for whites, 0.5 for reds). A fixed 30 mg/L at pH 3.9 gave almost no protection |
| Every ferment smelled of **H₂S** | H₂S now depends on how short the must was of its nitrogen requirement. DAP tops the must up to that requirement |
| Côte d'Or harvests ran two weeks late in drought years, and acidity collapsed | Water stress now slows ripening only when it is severe, as `ripening.md` says |
| Côte d'Or yields of 58–66 hL/ha, so wines were declassified | The Mentor prunes short (Low bud load) in the Côte d'Or. Yields are now 43–50 hL/ha and inside the AOC limits |
| A 15.7 % dry Riesling was "Outstanding" | Hot-alcohol rule for the Balance criterion, and a rescaled acidity perception (reds were always "low") |
| A 28.5 °Brix Cabernet fermented to 17.7 % | Yeast now have an alcohol tolerance (16.8 % cultured, 15.5 % ambient, 18 % for a restart culture). Stuck Lots can be restarted once or stopped with their residual sugar, so a Lot can no longer be left with no way forward |
| Napa Cabernet pH 3.2–3.5, below the target | Napa soil potassium factor, plus acidification proposed for high-pH musts |
| The spec's single-event override and 7-day forecast in the top bar were missing | Added "Spray today (extra pass)" and a compact 6-day forecast in the top bar |
| The fruit-set message said "Crop estimate 0.8 t/ha" | The estimate now uses the full berry size (6–9 t/ha), with one message for all Blocks |

## Scripted playthroughs: all 12 Plots

These use the Mentor's Planting, Medium Programmes and planting year 2015, so the first Vintage is 2018. A scripted player picks each Block at a regional sugar target.

| Plot | Wines (category / quality) | Sales | Cash at end (start €600k) |
|---|---|---|---|
| Mosel Uferflur | 2 Auslese Good, 1 Spätlese Good | €137k | €582k |
| Mosel Seitental | Auslese Good / Very good / Outstanding, Spätlese Good | €199k | €655k |
| Mosel Blauschiefer | 2 Auslese Very good, 1 Auslese Good, 2 Spätlese Good | €178k | €537k |
| Mosel Terrassen | 2 Auslese Outstanding, 2 Auslese Very good | €179k | €587k |
| Côte d'Or Plaine | 2 Bourgogne Acceptable, 1 Very good | €88k | €404k |
| Côte d'Or Hautes-Côtes | 4 Bourgogne Hautes-Côtes de Beaune Acceptable | €98k | €456k |
| Côte d'Or Village | Village AOC: 2 Acceptable, 1 Good, 1 Very good | €102k | €169k |
| Côte d'Or Premier Cru | 3 Premier Cru Good, 1 Very good | €219k | **−€512k** (land alone costs more than the capital) |
| Napa Valley floor | 2 Good, 1 Very good | €415k | €423k |
| Napa Carneros | 2 Acceptable, 2 Good | €226k | €266k |
| Napa Mountain | 3 Very good, 1 Good | €499k | €590k |
| Napa Rutherford bench | 3 Very good, 1 Good | €730k | €548k |

## Known gaps and limitations

Most of these need a decision or a source from you. None of them block play.

**Calibration**
- **Napa** now gets a soil-potassium factor of 1.2 (`UNVERIFIED`). Harvest pH is 3.3–3.7 and TA 5.2–6.7, which is at or near the low end of the 3.6–3.9 pH target. The Napa Cellar master proposes tartaric acidification for high-pH musts, which is normal practice there.
- In very hot years (2018, 2019) **Côte d'Or acidity** falls below the typical-year range (TA 4.5–5.8, pH 3.6–3.8 for late picks). That may be realistic for 2018, but nothing sourced confirms it.
- **Economy balance**: Napa earns far more than the other Regions (Rutherford: €730k from 1 ha in year one). The Côte d'Or Premier Cru is unaffordable. There are no loans. Every price is `UNVERIFIED` (`economy.md §9–10`).
- **Côte d'Or Pinot Noir** mostly rates "Acceptable". Young vines and a single clearly perceived aroma family mean it rarely meets the complexity or intensity criteria. That may be right for fourth-leaf vines, but it deserves a look.

**Missing against the spec**
- The only single-event override is **Spray today**, from the Programmes screen and from disease alerts. Other overrides (for example "skip this pass") are not built.
- No sound yet (spec milestone 9).
- Nothing caps the number of Wines at the spec's "about three". You can bottle each Lot on its own.

**UI**
- The first UI pass is functional and consistent, but not polished. The tables are fixed-width, and a long variety name gets cut off in the Plot table.
- The Inbox gets busy after véraison, because weekly samples stop time while a Block is in the harvest window.

## 3D status

The 3D views are merged and part of the game. Press **Tab**, or use the buttons on Plot & Blocks ("Walk the vineyard in 3D") and on the Winery ("See the hall in 3D", "Barrel cellar in 3D").

In the 3D view: click to look around, WASD to move, Shift to run, 1/2/3 to switch between vineyard, barrel cellar and fermentation hall, and Tab or Esc to go back.

**What the 3D shows:**
- **Vineyard:** your real Plot on its real slope and aspect, one area per Block, trained as Einzelpfahl, Guyot or Cordon. The vines follow the growth stage from pruned wood to leaf fall. Bunches change colour with ripeness and disappear when picked. Disease, chlorosis, drought droop and rot are visible, and the weather and sun follow the simulated day.
- **Winery:** tank screens with the real Lots (temperature, sugar, curve) and chalk labels on the barrels.

**Assets:** the 3D assets (CC0 textures from Poly Haven, plus models built with headless Blender) sit in `game/assets3d/` and are not in git. Rebuild them with `game/tools/sync_assets3d.sh`. They are already in place on your machine.

**Limits:**
- Full-summer Mosel close-ups ran at 53–59 fps, measured while another process was using the GPU. Please check the FPS on an idle machine.
- The far landscape is generic per Region.
- Light rain (1 mm) draws puddles that are too big.
- 3D screenshots: `game/shots/*_08b_3d_vineyard.png`, `*_10b_3d_hall.png`, plus the agent's set in `.claude/worktrees/agent-a90e45a30d0593e03/game/shots/3d_*.png`.

## Feedback questions

### For you: the game

1. Does the first 30 minutes make sense without a tutorial? At what point were you unsure what to do?
2. Is the **Alert rhythm** right? Too many stops (weekly samples, heatwaves) or too few?
3. Is **Continue** (up to the next Alert) or **Play** (P) the way you want to move through time?
4. Is the **harvest decision** interesting enough? Did you pick Blocks at different times on purpose?
5. Which cellar choices felt meaningful, and which felt like noise?
6. Does the **Tasting sheet** make you want to play another Vintage and do better?
7. Is the dashboard look right, or should the next round be denser (FM) or airier?
8. Should the economy be harder (loans, market prices, no guaranteed sales), or stay minimal for now?

### For your girlfriend (WSET L3): a 10-minute check, ✓/✗ plus a comment

**Use the review page: <https://claude.ai/artifact/PqqJ2CGJXf6qUj3Wvtm9HD>** (private to your account, so open it on your computer). It shows five real tasting sheets, the harvest chemistry table and the law rules, each with Correct / Something's wrong / Not sure buttons and a comment box. Answers save automatically and I can read them back. The questions behind the page:

1. Tasting sheet: are the words right (clarity, intensity, colour, aroma families, the palate scale, the quality levels)?
2. Do the *because…* lines explain things correctly?
3. Does a Riesling at 15.9 % alcohol that is "hot but long and complex" deserve "Very good"?
4. Mosel labels: Spätlese/Auslese **trocken**, and a single-vineyard name only at ≥ 85 % Riesling. Correct?
5. Burgundy: the "at most 8 buds per vine" rule for Village and Premier Cru. Is it 8, or 10 eyes including the spur?
6. Harvest chemistry on the Ripeness screen (°Oe, TA, pH, malic): does it look plausible for each Region?
7. Is anything simply wrong?

### For expert game designers

1. **Core loop and pacing**: the Vintage runs for about 16 in-game months, from January to bottling. Where does it sag? The cellar months, the wait for ageing?
2. **Decision density**: roughly 25 meaningful decisions a Vintage (Programmes, per-Block choices, harvest dates, about 12 cellar choices per Lot, blending). Too many, too few, or badly spread?
3. **Legibility of consequences**: every descriptor names its cause. Is the feedback loop from decision to outcome readable, or is it too delayed (harvest choices pay off 8 months later)?
4. **Information design**: FM-style tables and charts. Is the Inbox the right hub? What would you cut?
5. **Failure states**: stuck ferments, Brett, declassification and debt are all possible. Are they fair and telegraphed? Is anything a trap?
6. **Replayability**: the same Plot with a different planting year gives a different real vintage (1990–2025, synthetic after 2025). Is that enough variety to justify replaying, before multi-vintage play exists?
7. **Staff levels**: Junior staff report facts only, while Experienced and Senior staff give longer forecasts and advice. Does that make hiring feel worth it?

## Verification done

- `dotnet test`: 22/22 pass, including calibration, the law, save/replay determinism and yeast tolerance.
- CLI playthroughs of all 12 Plots, in about 0.3 s each.
- `scripts/capture.sh <plot>` plays the full game through the real UI (new game → Planting → Vintage → harvest → cellar → bottling) and saves 17 screenshots per Region to `game/shots/`. I looked at every screenshot for Mosel, Côte d'Or and Napa.
- `scripts/fuzz.sh` presses every button and dropdown on every screen at four points in the Vintage, tests the keys and continuous play, and checks for script errors. It found none.
- The save → load round trip gives identical cash and wine count.
