# Post-MVP backlog

Things deliberately left out of the MVP, to deep-dive once the core loop is locked.

## Shortlist: what to build next (agreed with the owner 2026-09-29; check here first when asked "what's next")
- **Famous-vintage challenges**: replay the 2016 Burgundy frost as an authored scenario (the sim already reproduces it); the hot 2003 needs a yearly Côte de Beaune flowering/véraison series first (see Simulation and science).
- **More work types in 3D**: shoot thinning, bâtonnage, a barrel sample with the thief, tasting berries for harvest timing, tying down; they build on the Tasks system.
- Also open: the tasting-review page for the WSET L3 reviewer (see Build and review).

## First expansion (top priority after MVP)
- ~~Multi-vintage play on the Timeline~~ — done 2026-09-28 (spec `docs/superpowers/specs/2026-09-28-multi-vintage-design.md`, report `docs/playtest/2026-09-28-multi-vintage.md`). Follow-ups: selling wine over time (stock and markets), replanting and top-grafting, phylloxera on own-rooted vines, dropping bottled Lots from the snapshot, in-memory replay checkpoints if long games load slowly, mature Côte d'Or yield calibration.

## Gameplay
- ~~Staff tasks in 3D (prune, pull leaves, green-harvest, work the cap)~~ — done 2026-09-28 (spec `docs/superpowers/specs/2026-09-28-tasks-in-3d-design.md`). Follow-ups: more task kinds (debudding / shoot thinning, tying down, bâtonnage, topping up barrels, tasting berries, digging a soil pit, a barrel sample with the thief), doing the work yourself saving wages, harvesting in 3D, skill differences between player and crew.
- ~~3D time-lapse with a speed control~~ — done 2026-09-29 (spec `docs/superpowers/specs/2026-09-29-timelapse-and-visuals-design.md`: Space and `[ ]` in the 3D view; physically based sky, day and night, variety leaves, bloom, grass, gusts). Follow-ups: continuous leaf growth between growth-stage meshes, moon phases, snow, player-placed lights; the shared gusts for the ground cover and near trees (they still sway on their own or not at all); the leaf-removal close-up drawing the Variety's own leaf; the hall's fog and aerial settings follow the outside only once a day (frozen through a Day-speed night); wind direction from real data if a source is added.
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
- ~~A cosy, customisable winery look~~ — done 2026-09-29 (spec `docs/superpowers/specs/2026-09-29-cozy-winery-design.md`; cosmetic only). Follow-ups: a separate tasting room interior, the Winery-look lanterns lighting up at night (day/night came with the time-lapse; the office windows and door lamp already do), player-placed furniture, more options per element (e.g. a stone vault for the cellar, painted steel for the trusses), and a look for the office.

## Depth
- Fuller legal rulebooks per Region (the MVP rulebooks are simplified, and must be built so they can be extended)
- Full economics (loans, market prices, distribution, reputation). **Not planned:** the owner decided (2026-09-29) that the game is a WSET 3/4 study tool, so economics stays a light constraint (bottled Wine sells on bottling day at its category-and-quality price). A sales design with channels, offers and reputation was drafted and set aside.
- Detailed Programmes instead of Low/Medium/High tiers, e.g. spray product choice (contact vs systemic, organic copper/sulphur vs conventional), timing and water volume
- Hard mode: lab samples cost money and come with sampling error, and Diploma-level detail is exposed
- Exam-style blind tasting: the player fills in the tasting sheet and is graded against the engine's profile

## Known issues and small follow-ups
Found while building or reviewing; not urgent, but not to be forgotten. Remove a line when it is fixed.

### Simulation and science (for the science review)
- Côte d'Or ripening spread between years is too small: 2003 reaches 200 g/L on 4 Sep in the game, the real harvest began ≈ 19 Aug. Diagnosed in `phenology.md` §9: GFV flowering responds too weakly to warm springs (observed 1991–2003 flowering spread 25 days, model 14) and the post-véraison drought brake slows the hot, dry years. Needs a yearly Côte de Beaune flowering/véraison series to refit, and 2003 Ψstem data. Tools: `sim ripecheck`, `sim frostcheck`, `sim yieldcheck`.
- Napa year-to-year yield variation is 4–7 %; check against the Napa County crush reports.
- Multi-vintage carry-over coefficients (fruitfulness, reserves, inoculum, 20 % leaf-loss tolerance) are `UNVERIFIED`.
- Reserves ignore frost at leaf fall (spec §4.2 lists it).
- At 5,000 vines/ha a Guyot Block's High bud load (11 buds/m² = 22 buds per vine) hits the Guyot cap of 16 buds per vine, so High gives the same crop as Balanced; decide whether the cap should allow a double Guyot (≈ 2 × 10 buds) or the options should say so.
- Napa Bench Cordon Blocks get 8–12 two-bud spurs per vine (16–24 buds), while the §3.1 bud table says 6–10 spurs × 2 buds; check whether the table means per arm (bilateral cordon) and align the table or the bud-load conversion.
- A harvest still running on 31 December is wiped on 1 January (the December rule finishes picks on 2 December, so this is rare).

### Engine and performance
- The snapshot still grows with every Wine (full Tasting sheets); bottled Lots and the duplicate report are already dropped. Consider sending old Vintages' Tasting sheets on demand.
- Replay checkpoints if long games load slowly (10 Vintages load in 0.6 s today).

### Screens

### Build and review
- The Napa screenshot run logs Godot "RID allocations leaked at exit" (text-shaping buffers) when it quits; harmless at exit, but check it is not a leak during play.
- The screenshot run's first-Vintage bottling loop does not harvest, so in Napa (18-month ageing) the second Vintage is picked by the December rule; give the scripted player the harvest step there too.
- Two Vintages' Lots side by side in the Winery were not yet seen in a screenshot (the Lot tabs now wrap, so eight or more Lots fit).
- Saves made before the tasks-in-3D change: the new task messages shift the Inbox message ids, so an old save can show a few messages as unread again (read marks are stored by id). Harmless; no migration written.
- The Tasks strip's "at véraison" box takes effect with the next option click (it sends nothing by itself); consider sending the plan with the new timing when it is toggled.
- An `assets3d/` folder fetched before the Winery look lacks its props and textures: the 3D view then shows grey walls, empty prop groups and floating candle glows with only a console warning. Rerun `game/tools/fetch_assets3d.py`; consider a HUD hint or adding one new asset to `assets3d.gd available()`.
- The Windows build is unsigned: SmartScreen warns on first start, and a PC with Application Control may block it.
- Windows `dotnet` cannot build the game (Application Control blocks Godot's source generators); build through WSL (`scripts/build-game.sh`).
- The tasting review page for the WSET L3 reviewer: the first page (claude.ai artifact) no longer exists (found 2026-09-29); make a new one when that work starts.

## Ideas (not decided)
- January message: a Senior Vineyard manager adds a per-Block breakdown and a bud-load suggestion per Block.
- Bud dissection as an optional paid winter lab test in Hard mode, with sampling error.
- Vine age as drought resilience (older vines root deeper) rather than a quality bonus, if the literature supports a size.
- Report: overlay two Vintages' ripening curves to compare years.
- Green-harvest alert mentions that thinning also protects next year's reserves.
- Plot screen shows each Block's carry-over (fruitfulness, reserves) with a tooltip.
- 3D pruning close-up for a bilateral Cordon: show both arms of the real vine with the spurs split between them, and Einzelpfahl's two bows as a heart.
- Leaf-removal close-up: after a "later, at véraison" choice, the tagged leaves could come off in the world when the crew does it at véraison.
- ~~Autumn colour on the near trees~~ — done 2026-09-29.
- Near trees: a proper European species for the Mosel and Côte d'Or (walnut, cherry, oak) and a real olive or valley oak for Napa when a CC0 scan exists (Poly Haven has none today); the thinned canopies are open rather than dense.
- Ground cover: a meadow grass scan light enough to scatter (Poly Haven's are 0.2–1.6M triangles), (autumn colour on the near trees: done).
- A WSET-style vintage chart (one rating per Vintage) once several Vintages have been played.
