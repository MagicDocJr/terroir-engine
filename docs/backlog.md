# Post-MVP backlog

Things deliberately left out of the MVP, to deep-dive once the core loop is locked.

## First expansion (top priority after MVP)
- ~~Multi-vintage play on the Timeline~~ — done 2026-09-28 (spec `docs/superpowers/specs/2026-09-28-multi-vintage-design.md`, report `docs/playtest/2026-09-28-multi-vintage.md`). Follow-ups: selling wine over time (stock and markets), replanting and top-grafting, phylloxera on own-rooted vines, dropping bottled Lots from the snapshot, in-memory replay checkpoints if long games load slowly, mature Côte d'Or yield calibration.

## Gameplay
- Hands-on tasks in 3D (pull a leaf, taste berries, dig a soil pit, punch down, thief a barrel sample)
- Staff-assigned tasks done in 3D: the Vineyard manager says "go out and prune Block B" (or pull leaves, green-harvest, punch down) and the player does it in the 3D world or delegates it (owner request, 27 Sep 2026)
- 3D time-lapse with a speed control (watching the days pass is where 1×/2×/4× belongs)
- Famous-vintage challenges (e.g. Burgundy 2021 frost, the hot 2003) as authored replay
- Barrel-sample tasting notes during ageing, and a Senior's occasional "clever idea" messages
- Tractors and machinery driven by the player
- Buying an established estate (planted vines, higher price) instead of bare land
- Top-grafting: change the Variety on existing roots, losing one vintage
- Picking a location anywhere on a real map (global soil and climate data)
- More Varieties and Regions

## Hazards
- Hail and wildfire smoke taint, as rare seeded events labelled "Game simplification"
- Phylloxera (needs multi-vintage play), grape moth and other pests

## Winery
- Build and equip the Winery yourself (tank count, cooling capacity, press type), with in-game guidance on what to buy and why
- Custom-crush option (rent space at a shared facility)

## Depth
- Fuller legal rulebooks per Region (the MVP rulebooks are simplified, and must be built so they can be extended)
- Full economics (loans, market prices, distribution, reputation)
- Detailed Programmes instead of Low/Medium/High tiers, e.g. spray product choice (contact vs systemic, organic copper/sulphur vs conventional), timing and water volume
- Hard mode: lab samples cost money and come with sampling error, and Diploma-level detail is exposed
- Exam-style blind tasting: the player fills in the tasting sheet and is graded against the engine's profile

## Known issues and small follow-ups
Found while building or reviewing; not urgent, but not to be forgotten. Remove a line when it is fixed.

### Simulation and science (for the science review)
- The 27 April 2016 Burgundy frost is not reproduced on the mid-slope Côte d'Or Plots (only the 2021 frost pocket is tested).
- Côte d'Or ripening spread between years is too small: 2003 reaches 200 g/L on 5 Sep in the game, the real harvest began ≈ 19 Aug; GFV flowering runs about a week late (Parker F* kept as published).
- Napa year-to-year yield variation is 4–7 %; check against the Napa County crush reports.
- Multi-vintage carry-over coefficients (fruitfulness, reserves, inoculum, 20 % leaf-loss tolerance) are `UNVERIFIED`.
- The vintage-statement share is computed from wine litres, not grape weight: label it a game simplification or switch to grape kg.
- Reserves ignore frost at leaf fall (spec §4.2 lists it).
- A harvest still running on 31 December is wiped on 1 January (the December rule finishes picks on 2 December, so this is rare).
- The weekly grey-rot alert is the most frequent message in hands-off play; check whether it is too noisy.

### Engine and performance
- Static caches (`VintageReport` normals, `Snapshot` normals) are plain `Dictionary`s used by parallel tests; switch to `ConcurrentDictionary`.
- The snapshot grows ≈ 30 KB per Vintage (330 KB after 10): drop bottled Lots, drop the duplicate `report` (the UI reads `reports`), consider trimming old wines' full Tasting sheets.
- Replay checkpoints if long games load slowly (10 Vintages load in 0.6 s today).

### Screens
- Vintage history: the current Vintage shows "0 (normal …)" before April; a past Vintage with no Lots would stay "Growing".
- Vintage history has no bottles column (spec §8).
- Glossary "show the Mentor's plan again" does nothing once the Mentor has retired: hide or relabel it.
- `blending.gd` hard-codes the 85 / 95 % vintage thresholds; send them in the snapshot instead.
- Lots grouped by Vintage were not seen in a screenshot (Mosel Lots never overlap); add a capture with overlapping Vintages (e.g. Napa Cabernet, 18 months in oak).

### Build and review
- The Windows build is unsigned: SmartScreen warns on first start, and a PC with Application Control may block it.
- Windows `dotnet` cannot build the game (Application Control blocks Godot's source generators); build through WSL (`scripts/build-game.sh`).
- The tasting review page for the WSET L3 reviewer is still empty: https://claude.ai/artifact/PqqJ2CGJXf6qUj3Wvtm9HD

## Ideas (not decided)
- January message: a Senior Vineyard manager adds a per-Block breakdown and a bud-load suggestion per Block.
- Bud dissection as an optional paid winter lab test in Hard mode, with sampling error.
- Vine age as drought resilience (older vines root deeper) rather than a quality bonus, if the literature supports a size.
- Report: overlay two Vintages' ripening curves to compare years.
- Green-harvest alert mentions that thinning also protects next year's reserves.
- Plot screen shows each Block's carry-over (fruitfulness, reserves) with a tooltip.
- A WSET-style vintage chart (one rating per Vintage) once several Vintages have been played.
