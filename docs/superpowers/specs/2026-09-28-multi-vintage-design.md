# Multi-vintage play — design

Status: design approved in conversation 2026-09-28; this spec awaits owner review. Vocabulary follows `CONTEXT.md`.
Backlog item: "First expansion — Multi-vintage play on the Timeline" (`docs/backlog.md`). Decisions it builds on: ADR 0001 (headless deterministic core), ADR 0002 (continuous historical Timeline: "all state must be built to carry over between years").

## 1. Goal

After the first Vintage is bottled, the game goes on: the same Estate, year after year, on the continuous Timeline. The vines remember last year, cash and wine carry over, and Vintages overlap in the cellar. The player learns real vintage variation by living through it and comparing years side by side.

**Success looks like**
- A player can play three or more Vintages in a row without a restart, with no dead ends and no phase that stops the clock for good.
- Decisions made in one year (bud load, green harvest, spray tier, harvest date) visibly change the next year's crop, and the game says why.
- Each Vintage gets its own Vintage report; a Vintage history table compares all years.
- The first Vintage plays exactly as it does today: its calibration and all 25 existing tests still hold.
- Old save files still load.

**Non-goals** (stay in `docs/backlog.md`): phylloxera, replanting or top-grafting, selling wine over time (stock, markets, distribution), loans, hail, winter freeze damage, a fixed end or win condition.

## 2. Approach

One continuous `GameSession` that keeps stepping day by day. Everything that belongs to one year is keyed by its Vintage year. The save stays "setup + command log", replayed on load (spec §10).

Rejected:
- *A new session per year, seeded from last year's state:* needs full state serialisation and breaks "replaying the log reproduces the game exactly".
- *A turn-based year-end screen that skips time:* loses the daily simulation the game is built on.

## 3. Timeline and the yearly loop

### 3.1 Current Vintage instead of the one Vintage
- `GameSession.Vintage` (today fixed at `PlantingYear + 3`) becomes the **current season year**: after Establishment it equals `Date.Year`. A new read-only `FirstVintage => PlantingYear + 3` keeps the first-year logic (young-vine flag, Mentor storyline).
- Every place that asks "is this the Vintage year" (`StepDay`'s `vineYear`, `DailyCosts`' season/spray/irrigation checks, `Snapshot.WeatherObj`, the young-vine price rule, `VintageReport`) is rewritten against the current season year, or against the Vintage of the Lot/Wine it concerns.
- `Lot` gets a `Vintage` field (set at harvest). Lot ids already carry the year (`21-A`) and stay unique per Vintage. `Provenance.Vintage` already exists.

### 3.2 Phases
- `GamePhase` becomes `{ Establishment, Running }`. `Vintage`, `Cellar` and `Finished` are removed as phases.
- Derived, per-year states replace them in the snapshot:
  - `season`: `Dormant`, `Growing`, `Harvest`, `PostHarvest` (from Block stages);
  - `quiet`: true when no Block is growing or being picked and no Lot is fermenting. The UI uses it for bigger "Continue" steps (today's 120-day Cellar step).
- The clock never stops for good. Play pauses only at Alerts, as now.

### 3.3 Year turnover
- Vines already step through leaf fall and winter chill (`NextSeasonChill`). `VineyardModel.StartSeason` already resets the season on 1 January; it now also applies the carry-over factors from §4.
- Before the reset, the session writes a `SeasonRecord` per Block into `History[year]`: budburst, flowering, véraison, harvest and leaf-fall dates, yield, frost loss, rot, Winkler, the carry-over factors computed for next year. The Vintage report and the Vintage history read from these records, because `BlockState` itself is reset.
- A Block not picked by 31 December is still force-picked by the late-harvest rule that exists today.
- `RiskSeries` and the weekly ripeness `Samples` hold the current year only (already true for `Samples`); `CashSeries` keeps growing (weekly points, small).

### 3.4 Once-per-year alerts
- `Gate(key)` keys today are one-shot for the whole game ("budburst", "flowering", "window-A"). Seasonal gates get the year appended (`budburst-2022`). One-shot gates that must stay one-shot (`overdrawn`, onboarding) keep their keys. Lot-level gates are already unique (the Lot id carries the year).

### 3.5 The January "New season" message
Each 15 January from the second Vintage on, the Vineyard manager posts **"The {year} season"** (stop: true), with:
- vine age ("5th leaf"), and the young-vine note while it applies;
- the **bud-dissection estimate**: expected bunches per shoot against normal, from the fruitfulness factor (§4.1), in words and percent;
- vine reserves in words (e.g. "the vines went into winter tired after the big crop and the early leaf loss"), from §4.2;
- disease carry-over in words, when raised (§4.3);
- then the pruning decision (the same bud-load choice as today, with an action to Plot & Blocks). The Senior's version adds a recommendation (e.g. "prune one step lower than last year to let the vines recover").

Why text: bud dissection is how growers forecast crop in winter; the estimate is a forecast, not the truth (fruit set is still to come).

## 4. What the vines carry over

Direction and mechanism come from the literature; the sizes are design values marked `UNVERIFIED` in `docs/science/canopy-and-yield.md` until the science review. All three factors are exactly 1.0 for the first Vintage, so the MVP calibration is untouched.

### 4.1 Bud fruitfulness (`FruitfulnessNext`)
Inflorescence primordia form in the latent buds around flowering of the *previous* season; warmth and light on the buds then set next year's bunches per shoot (Buttrose 1969, 1974; Keller, *The Science of Grapevines*). `canopy-and-yield.md` §3.2 already reserves "±15 % from the previous season's weather once multi-vintage play exists".

- Recorded at flowering + 20 days, per Block:
  `T_anom` = mean `Tmean` (Block microclimate) over flowering −10 … +20 days, minus the 1991–2020 mean of the same calendar window for that Block;
  `E` = mean fruit-zone exposure over the same window (today's `Exposure`, 0.45 = typical).
- `FruitfulnessNext = clamp(1 + 0.04·T_anom + 0.30·(E − 0.45), 0.85, 1.15)` (`UNVERIFIED`).
- Applied next season as a multiplier on `ClustersPerShoot` in the fruit-set calculation.

### 4.2 Carbohydrate reserves (`Reserves`)
Stored starch in roots and trunk feeds budburst, early shoot growth and flowering. An over-large crop for the leaf area, a late harvest, and early leaf loss (downy mildew, drought, frost) lower reserves and reduce next year's shoot growth, inflorescence number and fruit set (Bennett et al. 2005; Holzapfel, Smith & co-workers on post-harvest canopy and reserves; Keller).

- Computed at leaf fall, per Block:
  - `cropLoad` = kg fruit per m² leaf area at harvest (Kliewer & Dokoozlian 2005: ~0.8–1.2 kg/m² is balanced);
  - `postHarvestDays` = days of functional canopy between harvest and leaf fall;
  - `defol` = fraction of leaf area lost early (max downy leaf %, frost at leaf fall, severe water stress days).
  - `seasonR = clamp(1 − 0.20·max(0, cropLoad/1.2 − 1) − 0.10·max(0, 1 − postHarvestDays/30) − 0.30·defol + 0.05·max(0, 1 − cropLoad/0.6), 0.70, 1.05)`
  - `Reserves = clamp(0.4·Reserves_prev + 0.6·seasonR, 0.70, 1.05)` (partial recovery year to year).
  - All coefficients `UNVERIFIED`.
- Applied next season: shoot and leaf-area growth × `(0.8 + 0.2·Reserves)`, fruit-set ratio × `Reserves` (capped at 1.0 for set).

### 4.3 Disease carry-over
A severe mildew season leaves more overwintering inoculum (downy oospores; powdery mildew chasmothecia), raising next spring's primary pressure (Gadoury & Pearson; Rossi et al. on oospore dynamics).
- `DownyCarry`, `PowderyCarry` = `clamp(0.85 + 0.015·peakLeafPct, 0.85, 1.30)` from the season's peak leaf infection (`UNVERIFIED`), averaged over Blocks.
- Applied as a multiplier on `Ctx.DownyInoculum` and `Ctx.PowderyInoculum` for the next season only (not cumulative).

### 4.4 Vine age
- The young-vine table continues unchanged (`canopy-and-yield.md` §3.5): 4th leaf 0.8 of a full crop, 5th leaf onwards 1.0. Root depth keeps following leaf age (it already does).
- No "old vines make better wine" bonus. The evidence for a quality effect of vine age is weak and confounded (Grigg et al. 2018); the Glossary and the New-season message say so. This is a deliberate science decision, not an omission.

### 4.5 Unchanged
Soil water refills to field capacity each winter (existing game simplification, stays labelled). Vine survival losses stay a first-leaf drought effect.

## 5. Cellar and law across Vintages

- Lots from several Vintages share the cellar. Long ageing choices (10 and 18 months) naturally overlap the next harvest. Tank capacity is not limited (existing simplification).
- Blending across Vintages is allowed. `Law.Evaluate` adds the **vintage statement rule**:
  - EU (Mosel, Côte d'Or): the label may state a year if ≥ 85 % of the grapes were harvested that year (Reg. (EU) 2019/33, Art. 49).
  - USA (Napa): ≥ 95 % when the label names an AVA (Napa Valley is one), 85 % otherwise (27 CFR 4.27).
  - Below the threshold the wine is non-vintage: the label drops the year and a legal note explains why.
  - Price: no non-vintage discount in this version (no source for a size). Correction to the conversation design, which said it would cost label value.
- `Wine` gets a `Vintage` (the year stated on the label, or null for non-vintage). The young-vine price rule applies to wines whose stated Vintage is the first Vintage.
- The Winery and Blending screens group Lots by Vintage. A multi-Vintage blend shows its vintage shares next to the variety shares.

## 6. Money

- The Ledger already runs continuously. Every yearly cost now recurs each year: vineyard labour, materials, sprays, irrigation, frost protection, staff salaries, overheads, cellar running costs, barrels.
- Wine is still sold at bottling (existing simplification, stays labelled "Game simplification").
- **Overdraft interest:** on the 1st of each month, if cash < 0, post `−cash × 9 % / 12` as "Interest" (`UNVERIFIED` design value; typical euro-area small-business overdraft rates are high single digits). The existing overdraft message is updated to mention it. Loans stay in the backlog.

## 7. Mentor and advice

- The Mentor retires when the **first** Vintage is fully bottled (as today). The farewell message no longer says the game ends; it says the Estate is yours and play continues.
- After retirement, the seasonal messages the Mentor sends today (budburst, flowering, véraison, late-harvest picking) come from the Vineyard manager. Advice stays correct at every Staff level (spec §5.4):
  - Junior: the message and the action, no "why" section;
  - Experienced: adds the "why";
  - Senior: adds the "why" and a recommendation where one exists (e.g. harvest-window timing against the forecast).
- Hiring (the existing `staff` command) therefore matters more from year two on.

## 8. Screens

- **Top bar:** date plus "{year} season · {n}th leaf".
- **Inbox:** unchanged (it already pages older messages).
- **Winery, Blending:** Lots grouped under Vintage headings, newest first.
- **Vintage report:** `VintageReport.Build(g, vintage)` reads `History[vintage]`. A report becomes available when every Lot of that Vintage is bottled; a message with an "Open the Vintage report" action announces it and the shell opens it once. The report screen gets a Vintage selector. The Mentor farewell panel appears only on the first Vintage's report.
- **Estate:** the "finished" panel is replaced by a **Vintage history** table, one row per Vintage: heat (Winkler vs normal), rain, budburst and harvest dates, yield hL/ha, wines with quality, bottles, sales. Below it a per-calendar-year P&L (costs, sales, interest, cash at year end).
- **Weather:** shows the current season year (today it caps at the one Vintage).
- **Onboarding (Mentor's plan):** first Vintage only; it stays hidden afterwards.
- **3D:** no change needed; it draws whatever snapshot it gets. Tanks and barrels show all Lots in the cellar.

## 9. Saves and replay

- The save format is unchanged: setup + commands + date. `Load` loses its `Phase != Finished` stop condition and simply replays to the saved date.
- Old MVP saves load: their commands still apply, and a save dated after the first bottling now replays into a running game.
- Replay cost grows with years played. Budget: loading a five-Vintage save takes < 10 s on the owner's PC (measured, not assumed; if exceeded, add periodic in-memory checkpoints in a follow-up, not a new save format).

## 10. Testing

New tests in `sim/tests` (xUnit, headless):
1. **Three Vintages back to back:** a scripted player (the CLI `play` logic moved into a reusable test helper) harvests, vinifies and bottles three Vintages on one Plot per Region. Asserts: no exceptions, three Vintage reports, wines from each Vintage, cash continuous.
2. **First Vintage unchanged:** the existing golden tests keep passing untouched; plus a check that all carry-over factors are 1.0 in the first Vintage.
3. **Reserves:** High bud load + Low spray tier in a wet year gives `Reserves < 1` and a smaller crop next year than Low bud load + High spray tier on the same weather.
4. **Fruitfulness:** a warmer-than-normal flowering window gives `FruitfulnessNext > 1`, bounded by 0.85–1.15.
5. **Vintage statement:** a 90/10 blend is a vintage wine in the Mosel and non-vintage in Napa; 80/20 is non-vintage in both.
6. **Save/load two Vintages in:** save, load, and compare snapshots byte-for-byte.
7. **Seasonal gates:** budburst and harvest-window alerts fire once in each of two years.
8. **Overdraft interest:** posted monthly only while cash is negative.
9. **Replay budget:** loading a five-Vintage save stays under the §9 budget (reported, and asserted with CI headroom).

Game-side checks: `scripts/fuzz.sh` runs across a year boundary; `scripts/capture.sh` gains a second-Vintage pass (New-season message, Vintage history, report selector) for screenshot review.

## 11. Science documentation

- `docs/science/canopy-and-yield.md`: new sections for fruitfulness carry-over and reserves (formulas, citations, calibration expectations, `UNVERIFIED` marks), and the vine-age quality stance.
- `docs/science/disease.md`: inoculum carry-over.
- `docs/science/law.md`: vintage statement rules (EU 85 %, US 85/95 %).
- `docs/science/economy.md`: overdraft interest as a labelled design value.
- Calibration expectation to verify during implementation: over 10 consecutive simulated Vintages with Balanced bud load and Medium tiers, mean yield stays within the existing per-Region ranges, and the year-to-year coefficient of variation is in a realistic band (roughly 15–30 % for these regions; source to be confirmed, else `UNVERIFIED`).

## 12. Build order

1. Engine: current Vintage, phases, recurring costs, gates, `History`/`SeasonRecord`, Lot/Wine Vintage, save/load (tests 1, 2, 6, 7, 9).
2. Carry-over science: fruitfulness, reserves, disease carry-over, New-season message (tests 3, 4) and science docs.
3. Law and money: vintage statement, overdraft interest (tests 5, 8).
4. UI: top bar, grouped Lots, report selector, Vintage history, onboarding gating, shell phase logic; fuzz and capture across two Vintages.
5. Standalone build refreshed (`scripts/export-windows.sh`), playtest report.
