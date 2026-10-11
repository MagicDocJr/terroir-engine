# 3D view (look-only MVP)

One walkable place: the Plot's vineyard, a farm track, and the winery building with the fermentation hall,
the stairs down and the vaulted barrel cellar. Everything is drawn from the simulation snapshot. Nothing here
computes an outcome (ADR 0001): stages, colours, disease cues, tank readouts, cask labels and the sounds of
fermentation all come from `Sim.Snapshot()`.

## Contract

`res://src/view3d/view3d.tscn` (root `Control`, script `view3d.gd`):

| member | meaning |
|---|---|
| `apply_snapshot(D: Dictionary)` | `D` = parsed `Sim.Snapshot()`. Call on entry and after every advance. Cheap, unless the Plot changed: then the landscape is rebuilt and the winery is moved and its GI re-baked (about 3–5 s). |
| `set_view(kind: String)` | `"vineyard"`, `"cellar"` or `"hall"`: teleports the walker to that place in the one world. `"drone"`: a free-flying camera above the Estate (the walker waits where it was). |
| `signal exit_requested` | Tab, or Esc while the mouse is not captured. |
| `signal task_chosen(id, value, timing)` | The player did a staff task in its close-up; the shell sends `task <id> do <value> <timing>`. |
| `signal advance_requested(days)` / `timelapse_set(on)` / `timelapse_speed(i)` / `timelapse_alert(subject)` | The time-lapse: the view asks for a day; the shell advances the sim (stopping at an Alert), hands the snapshot back with `apply_snapshot` in the next frame, and reports an Alert with `timelapse_alert`, which pauses it. |
| `focus_task(id)` | Puts the walker in front of that task's demonstration vine (or its Lot's tank). |
| `show_hud` | Small date/Block/weather overlay plus the key hint line (default on). |
| `sound_volume_db`, `sound_on` | Master volume of the view's sound (dB, 0 = as mixed) and on/off. M toggles it. |
| `D.shop.inUse` (the Winery look) | Cosmetic choices bought in the Shop and switched with `decor <key> <value>` (the sim decides what is owned and in use, and never reads it otherwise). `view3d.look_for(snap)` adds the Shop's preview on top and `winery.gd apply_style` shows it; older snapshots without "shop" fall back to `winery_style.gd resolve(region, decor)`. See "The Winery look" below. |
| `camera_preset(name, block)` / `set_camera(pos, target)` / `capture()` | Used by the test harness. The eye is put exactly there, and the walker waits until the next move key. |

Input is read only while the node is visible. Click to capture the mouse, then walk with WASD (or the arrow
keys). Shift runs. 1/2/3 jump to the vineyard, cellar or hall, 4 switches to the drone (and back), M turns the
sound on or off, Space runs the time-lapse, and Tab goes back. **Tasks:** near a task's marker the HUD shows "E …"; E opens the close-up (the mouse is
freed and WASD no longer walks): click a part or an option in the side panel, Enter confirms (a short animation, then `task_chosen`),
Esc goes back without deciding, and Tab leaves the view (no decision). Once confirmed the choice stands: Esc is ignored during the
animation, and Tab or closing the view sends it at once. Test: `scripts/tasktest.sh` (real key and mouse events: E, WASD, a click on
every cane, Enter → Esc → Tab, drone + E; plus Cordon and Einzelpfahl pruning screenshots); the shell path runs in `scripts/fuzz.sh`
("FUZZ task3d", "FUZZ taskcrew"). **Drone:** it orbits the Plot centre; drag with the mouse to orbit, WASD pans,
Q/E turn, the wheel changes height/distance, Shift goes faster. 4 again resumes walking where you left off; 1/2/3
teleport as usual.
The world renders in its own `SubViewport` with its own `World3D`. Rendering, physics and sound stop while the
view is hidden.

## Files

| file | what |
|---|---|
| `view3d.gd` | Viewport, HUD, input and the contract. Works out where the eye is (zone) and switches the camera's environment, the interior lights/GI, the sun and the sound with it. |
| `vineyard.gd` | Terrain (+ collision mesh), Blocks and vines, neighbours, trees, river and weather. It also decides where the winery stands (`_layout_estate`): pad, yard, farm track and, in the Mosel, the river road. |
| `winery.gd` | The building: exterior shell, hall with tanks and screens (`tank_panel.gd`), stairs and cellar. Also builds the collision boxes, occluders, VoxelGI and the per-room environments. |
| `player.gd` | Capsule walker (`CharacterBody3D`): gravity, slopes up to ~50°, and stairs (a ramp collider under the steps). |
| `ambience.gd` | Ambient sound per Region and place (see below). |
| `workers.gd` | People and machines at work, staged from the snapshot (see below). One MultiMesh for all people, posed in `shaders/worker.gdshader`. |
| `tasks3d.gd` | Staff tasks: a stake with a ribbon and label at each open task's demonstration vine (the real vine nearest the headland on the Block's middle row) or above its Lot's tank; the close-up parts (pruning: the vine as the pruner finds it in January, drawn here while the real one is hidden with `vineyard.gd hide_vines_near`, with each option's cut marked by a ring at its bud count and a tag, a gold/red preview of what stays and goes, and on confirm the prunings falling and the kept canes tied to the wire or bent into bows, see canopy-and-yield.md §3.7; lobed leaves on the morning / afternoon side, berry bunches, cellar tools), picking (collision layer 20, a physics ray on the parts) and the confirm animations. |
| `winery_style.gd` | The Winery look catalogue mirrored from `data/shop.json` (the winerylook harness checks they match): elements, options, blurbs, each Region's look from before the Shop and `resolve()`. |
| `view3d_test.gd` | Test harness: screenshots, FPS, the walk test and the LOD probe. |

## Time-lapse and the sky

- **Keys:** Space plays or pauses; `[` and `]` change the speed: **Day** (one day ≈ 8 s with the whole sun cycle, the
  night compressed to 1 s), **Days** (a day per second, afternoon light), **Weeks** (7 days per second). The strip at
  the top shows the speed and date, or the Alert that paused it (Tab then opens it in the Inbox). Leaving the view
  pauses it; the 2D screens rebuild once with the new date.
- **Smoothness** (measured on Mosel Blauschiefer in June, display on): per day ≈ 0.2 ms sim step + 1 ms snapshot +
  0.8 ms parse (one frame) and ≈ 2.5 ms 3D update (the next frame). Stage changes swap vine meshes a few per frame,
  every stage's meshes are prepared in the background after the world loads, task markers rebuild only when tasks
  change, and one hidden marker keeps the text set-up alive (the first label cost 65 ms). Weeks speed: low-1 %
  78–100 fps, worst frame 24–27 ms, none over 40 ms; the still view on the same camera: low-1 % 120–144 fps.
- **Sky** (`shaders/sky.gdshader`): single-scattering Rayleigh + Mie atmosphere from the true sun (`_solar`: the
  Plot's latitude, day of year and solar hour), horizon whitening for multiple scattering, a cloud dome (fbm + warp)
  whose cover follows the day's clear-sky fraction (the snapshot's `weather.today.clear`, FAO-56), rain clouds darker,
  drift animated in the shader (a per-frame uniform change rebuilt the radiance map every frame: −20 fps), stars and
  a faint Milky Way at night. `vineyard.gd`: `daytime` / `set_daytime(h)` / `default_hour(doy)`; the moon (a cool
  weak directional) takes over below −4°; ambient and exposure lift the night to a readable blue dark; the winery's
  office windows and door lamp light up after dusk. Test: `--skytest` (3 Regions × dawn to night, cloud / rain / fog,
  the yard at night; `--perf`, `--diag`) and `--timelapse` (speeds, the hour animating, pause on an Alert, frame
  times, leaving stops it); the shell path in `scripts/fuzz.sh` ("FUZZ timelapse").

## Vine leaves, grass and wind (look only)

- **Leaves** are alpha-tested cards (8 triangles near, 2 far) showing the Variety's leaf from `models/leaf_atlas.png`
  (albedo + coverage) and `leaf_normal.png` (relief + vein mask), generated by `tools/blender/build_leaf_atlas.py`
  (`sync_assets3d.sh leaves`) from the official catalogue's descriptions (`docs/science/canopy-and-yield.md` §2.6):
  Riesling five deep U-sinused lobes, Chardonnay almost entire with the open naked petiole sinus, Pinot Noir round,
  dark and blistered, Cabernet Sauvignon deep lobes with the punched holes. Each Block's leaf material sets
  `variety_cell`; neighbours use the Region's usual Variety. The alpha threshold drops with distance (mipmaps would
  otherwise thin the canopy) and the normal frame comes from screen derivatives (the vine meshes carry no tangents).
- **Berries** carry a waxy bloom: a pale, rough, view-angle sheen once they colour (blue-grey on red grapes), partly
  washed off by rain.
- **Grass** (`vineyard.gd _grass_step`, `shaders/grass_blade.gdshader`): six-blade clumps, 26 per m², in 6 m chunks
  built as the camera approaches (two per frame, a 9 × 9 chunk window) and freed behind it; where the ground is
  grassed (alleys of grassed rows, headlands, verges; not under the vines, on tracks, the yard or bare stake-trained
  slate); tinted by the season (`grass_tint` global, like the terrain) and shrinking away by 23 m; no shadows.
- **Wind:** travelling gusts shared by the leaves and the grass; their strength follows the day's wind speed, their
  direction (`wind_dir`) is a per-day pattern (**game simplification**: the weather data carry no wind direction).
  The moon is a weak, cool light opposite the sun at 35° (**game simplification**: no lunar orbit or phases).
- **Near trees** turn yellow-brown in the five weeks before leaf fall (deciduous kinds).
- **Meshes without GPU read-back:** vine meshes are built from the importer's CPU arrays (`A.glb_surfaces`); duplicating
  uploaded ArrayMeshes read the GPU back (~9 ms each) and made the background preparation stutter.
- **Measured** (2026-09-29, display on, `--capture3d … --perf`, low-1 % fps): Mosel véraison close 110, Côte d'Or rows
  120–144, Napa rows 140–160, Mosel estate 135, leaf fall 157; before this work 99 / 119 / 160 / 120 / 153.

## Ground cover, working gear and near trees (look only)

- **Ground cover** (`vineyard.gd _build_groundcover`): dandelion, lesser celandine, fern and dry branches in clumps of 3–8
  on the verges within 6 m of the Plot and on the headlands between Blocks (never between the rows, on the track, in
  the yard or where neighbours are planted). Mix per Region: Mosel dandelion, celandine, fern, a few branches; Côte d'Or
  dandelion, celandine, branches; Napa dry branches and a few dandelions. Flowers show only in season (dandelion day
  90–285, celandine day 55–150; look only). Sources are Poly Haven CC0 scans, split into variants and decimated to ≤ 800
  triangles by `tools/blender/build_groundcover.py` (`sync_assets3d.sh groundcover`) into `models/gc_*.glb`. 26 m
  visibility range, no shadows; the scanned leaves are made matte (they read silvery in the sun).
- **Working gear** (`winery.gd _build_working_props`, always there): wicker harvest baskets by the sorting table,
  compost bags under the lean-to, a garden hose on the east gable, a clay pot by the office door, a hand truck by the
  crate stack. The candlelit cellar also gets a bottle display shelf at the far end.
- **Near trees** (`vineyard.gd _build_near_trees`): hedgerow clusters of 2–4 trees, 10–55 m from the Plot (the far
  tree cards start at 70 m). Mosel and Côte d'Or: a slender deciduous broadleaf (`tree_small_02`), bare from leaf fall
  to leaf-out (day 110–305 in leaf; look only). Napa: gnarled evergreen coastal trees (`island_tree_01–03`), which read
  like the olive trees kept around Napa wineries. `tools/blender/build_trees3d.py` (`sync_assets3d.sh trees`) makes a
  near model (lod0, ~45–60k triangles: bark decimated, leaf cards thinned to a few percent and each kept card grown so
  the canopy stays full; decimating leaf cards melts them into blobs) and a mid model (lod1, ~15k). Each tree switches
  at 45 m, is gone by 150 m, and only lod0 casts shadows.
- Test: `scripts/worldtest.sh` (checks + `game/shots/3d_world_*.png`; `--checks` skips the screenshots; `--perf` times
  the vineyard walk and verge views with the new plants on vs off). Measured 2026-09-29, display on, June: Mosel walk
  0.99 (119.5 → 118.0 fps), Mosel verge 0.96, Côte d'Or and Napa 1.00 (at the ~161 fps cap). Shadows on the mid trees
  cost the Mosel walk view 18 %, so lod1 casts none.

## The Winery look (cosmetic)

Specs: `docs/superpowers/specs/2026-09-29-cozy-winery-design.md`, then the Shop (`2026-10-07-equipment-shop-design.md`). A new
Estate starts with its Region's walls and floor and the plain working winery; everything else is bought in the Shop and then
switched on the Winery screen's "Your winery" panel. The Region columns below are the full cozy look games from before the
Shop keep. Nothing here affects the simulation. The Shop's item pictures (`game/shop_thumbs/*.jpg`) are rendered by
`scripts/shop_thumbs.sh` (`view3d_test.gd --shopthumbs`).

Shop additions: interior paint (`paint-*` on the hall's plaster, tinted); facade (`region` · `paint-*` · `timber` ·
`shingle` · `ashlar`: the shared `facade` material swapped in place, cladding triplanar); shutters (louvred leaves beside
the south windows and the office window, painted with the office door); string lights (festoons from the east gable's
corners to two poles and along the south wall, one glow each); the sign (`on`: gold letters and two sconces over the board).

| Element | Options | Mosel | Côte d'Or | Napa | How it is drawn |
|---|---|---|---|---|---|
| walls | render · slate · limestone · brick · redwood | slate | limestone | redwood | surface override on hall.glb's `hall_wall` (triplanar in the mesh frame, so blocks keep their size) |
| floor | concrete · stone · slate · terracotta · herringbone | slate | stone | terracotta | override on `hall_floor` |
| ceiling | steel · oak | oak | oak | oak | oak: `dark_wood` on hall.glb's `hall_beam` (the roof trusses) and `hall_ceiling` surfaces; the catwalk, rails and stair nosings stay steel |
| lights | workshop · warm · chandelier | warm | chandelier | warm | the 12 spot colours/energies (kept near 3000 K so the steel tanks still read as stainless); chandelier hides the pendants and hangs a `lantern_chandelier_01` at each pendant point |
| corner | none · table · lounge | table | table | lounge | a prop group east of the last tank pair by the south wall (`CORNER`) |
| plants | off · on | on | on | on | pots by the roller door and the corner; planter boxes along the south wall outside |
| outside | off · on | on | on | on | a bench and two lanterns at the east gable; the office windows glow |
| cellar | off · on | on | on | on | a candlestick on every fourth top-tier barrique, lanterns at both ends, a warm glow every 6 m |

Furniture, plants and the bench are solid (a StaticBody3D of boxes per group, disabled while the group is hidden).
Prop groups are built the first time they are shown and then only hidden or shown, so switching back and forth never
duplicates props or lights. Their glows join the room's light list, so they switch off with the room (`set_active`); none
casts shadows. The hall GI is re-baked only when walls, floor or ceiling change. `view3d.apply_snapshot` places the building and
applies the look before any GI bake, so a first open or a Plot change bakes once. Test: `scripts/winerylook.sh` (checks + `game/shots/3d_look_*.png`),
`scripts/winerylook.sh --perf` (hall frame rate, draw calls and primitives, regional look vs the plain one). Measured
2026-09-29 with the display on, hall camera: Mosel 151.7 → 145.4 fps (0.96; 274 → 361 draw calls, 3.80 → 4.46 M
primitives), Côte d'Or 160.9 → 155.7 fps (0.97; 239 → 370, 3.07 → 3.66 M). Within the spec's 10 %. Heavy scans are
avoided: the candles are built from cylinders (the scanned candlestick is 213k triangles) and the tall `potted_plant_01`
(176k) is not used.

## The Estate layout

- **Steep Mosel Plots (slope ≥ 30 %)**: the winery stands on the valley floor at the foot of the slope, beside the
  river road. Its cellar runs back into the hill. A farm track zig-zags up from the yard to a headland track
  along the bottom of the Blocks. The Moselle lies beyond the road.
- **Everywhere else**: the winery stands beside the Plot, west of the first Block, with its door facing the Blocks.
  A headland track runs along the Plot's edge, with a spur to the yard.
- **Building frame** (`build_winery.py`, `winery.json`): the hall floor is at y = 0 and the hall is 24 × 14 × 7 m,
  with the roller door in the east gable, high windows to the north and five windows to the south. At the west end
  a straight flight of 30 steps goes down 5.25 m, then a short corridor passes under the north wall to the cellar
  door. The vaulted slate cellar (22 × 6.2 m) lies behind the hall, under at least ~0.9 m of ground (the terrain
  is raised over it where needed).
- **Outside detail** (`build_winery.py` → `yard.glb`, `tractors.glb`): gutters and downpipes, a painted sign over
  the roller door with the estate name from the snapshot (`estate`, a Label3D fitted to the board), an office /
  tasting-room door and window with a bench, a lamp by the doors, a lean-to canopy on the south side with a
  basket press and a destemmer-crusher, stacked half-tonne picking bins, crates on a pallet, and a parked
  tractor: a tracked steep-slope crawler in the Mosel, a straddle tractor in the Côte d'Or, a compact tractor in
  Napa. All low-poly (≈1 300 triangles in total) with collision.
- **Regional outside**: Mosel has white render, a slate roof and a slate plinth. Côte d'Or has cream render,
  flat brown tiles and limestone. Napa has stucco and clay barrel tiles. *Game simplification (look only).*
- **Row orientation**: rows are drawn as planted (snapshot `rows`: DownSlope / NorthSouth / EastWest), and the sun
  is placed using the Plot's aspect (`aspectDeg`).

## Performance measures

- The environment is picked by zone: the outside sky environment, a hall environment (same sky, interior
  settings, auto exposure) or the dark cellar environment.
- The interior lights and VoxelGI run only near or inside the building (hall: within 45 m; cellar/stairs: when
  inside). Only two key lights per room cast shadows (cellar: the two ceiling bulbs; hall: one spot over each
  tank row), with dual-paraboloid omni shadows; the rest light without. Shadows are on only in the room you are
  in. Interior lights fade out with distance. VoxelGI uses subdivision 64. The tank screens re-render at 5 Hz,
  and only in the hall.
- Near vines (≤ 3 m) draw the LOD0 bunches on the LOD1 leaves and wood (the full LOD0 foliage cost ~3 ms at arm's
  length). LOD1 to 13 m, far-LOD shadows to 38 m, sun shadows to 70 m.
- Indoors, the sun's shadow reaches only 40 m and uses 2 splits. It is switched off in the cellar.
- Occlusion culling (`viewport.use_occlusion_culling`): box occluders sit inside the hall walls and roof and in
  the rock around the cellar. From inside, the vineyard is culled; from outside, the interior is culled except
  through the door and windows.
- Rain particles and their heightfield exist only outdoors.
- Vine LODs share exact visibility thresholds (no hysteresis margin; that margin made the nearest vines vanish).

## People at work (spec §8.2 "processes you can watch")

Everything is read from the snapshot; `workers.gd` only stages it.

| snapshot | what you see |
|---|---|
| Block `picking` (+ `pickedPct`) with `harvestMethod` "hand" | A picking crew at the picking front: pickers bent at the vines, a step along the row now and then, one in four carrying buckets to two picking bins at the row end. The Region's tractor waits on the headland with a trailer of bins. The front's position across the Block follows `pickedPct`; rows behind it carry no bunches (`pick_plane` in `berry.gdshader`). |
| labour Programme (`programmes` → `labour`) | Crew size: Low 6, Medium 9, High 12 people (the Programme text says 8/12/20 pickers; the view shows a readable share). |
| `harvestMethod` "machine" | A harvester (drawn with the straddle-tractor model) going up and down the front row, a trailer of bins and one person. *Game simplification: no dedicated harvester model.* |
| `sorting` Table / Rigorous while any Block is hand-picked | A sorting table under the winery's lean-to with 2 (Table) or 4 (Rigorous) people. |
| `daysSinceSpray` ≤ 1 | The spray pass (the snapshot is the morning after the simulated day): tractor + air-blast sprayer in the alleys; a straddle tractor over the rows in the Côte d'Or and in narrow rows; a person with a backpack sprayer on steep Mosel slopes and on stake-trained vines. |
| date + Block stage | Dec–Mar (dormant): 3 pruners in one Block; May–Jul: a canopy crew of 3 in one Block. *Game simplification: the sim books pruning and canopy work as labour hours, not as dated tasks, so the view picks the months and the Block.* |

Harvests in the sim are fast (a 0.15–0.4 ha Block is usually picked in the one simulated day after the order;
`view3d_test --pickrates` prints the rates), so the crew is mostly seen on the order day (`pickedPct` 0, crew at
the first rows) and occasionally at ~97 %. The parked tractor in the yard is hidden while it is out in the
vineyard. The HUD shows "At work: …". Camera preset `crew` looks at whoever is working. Cost: ≤ 32 people in one
MultiMesh (≈ 90 triangles each, posed in the vertex shader) plus a few machine meshes; it is only animated while
the view is shown.

## Sound

Every loop runs through two runtime audio buses. `View3D` is the master (volume and mute). `View3DOutside` is
low-passed and turned down indoors. A third bus, `View3DRoom`, has a small reverb for the hall and cellar.

| place | what plays | driven by |
|---|---|---|
| outside | wind in leaves | `weather.today.wind` (km/h), with a slow gust modulation |
| outside | birds | day of year: full in spring/summer, fading through autumn, none in winter; quieter in rain/fog; none at night (the view always shows the afternoon). *Game simplification, UNVERIFIED seasonal curve.* |
| outside | rain | `weather.today` rain amount; in the hall you hear it muffled, as on the roof |
| outside (Mosel) | river murmur | positional, from the nearest point of the bank |
| outside | a tractor now and then | during the season (days 90–290) on dry days, a 34 s pass in the neighbours' rows. *Game simplification.* |
| hall | bubbling at each tank whose Lot is fermenting (softer in malolactic), CO₂ puffs | Lot `phase` per tank (the same mapping as the tank screens) |
| hall | glycol chiller hum; a must pump now and then while Lots ferment | *Game simplification: not tied to simulated pump-overs.* |
| cellar | quiet room tone, the odd drip | positional drips in the vault |
| everywhere | footsteps | soil/gravel outside, concrete/stone indoors |

The files are built by `game/tools/sync_assets3d.sh audio` (`fetch_audio.py`) into `assets3d/audio/`, together
with `audio.json` (levels and sources) and `CREDITS.md`. All the recordings are CC0:

- [BigSoundBank](https://bigsoundbank.com/licenses.html), recorded by Joseph Sardin. Used for wind in shrub,
  forest birds, small stream, tractor and rollers, broth in a pot and water bubbles, fridge, electric pump,
  steps on gravel, steps on concrete, and an air leak.
- [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Light_Rain_Distant_Thunder_July_5th_2016.wav)
  "Light Rain Distant Thunder July 5th 2016" by kvgarlic.

The cellar room tone and the drips are synthesised by the script. Stand-ins: the river is a small stream with a
low-pass filter, and the fermentation is a simmering pot plus bubbles blown through liquid.

## What the vineyard shows (per Block, from `D.blocks`)

- **Growth**: Dormant → pruned wood; Budburst → rosettes; Shoots → short shoots (longer once LAI > 1);
  Flowering/FruitSet → inflorescences; later → full canopy with bunches. Picking removes the picked share of
  bunches. Harvested shows none. LeafFall colours and drops the leaves (red varieties turn red, white ones yellow).
- **Bunch colour**: véraison starts at ~22 °Oe and is complete by ~60 °Oe, with each berry turning at its own
  moment. Red goes from red to blue-black; white goes from green to golden. *Game simplification (display only).*
- **Training**: Einzelpfahl = single stake with two heart-shaped bows on a square grid. Guyot/Cordon = VSP rows
  with posts and wires. Spacing follows `density`.
- **Cues**: downy mildew oil spots (`downyLeaf`), interveinal lime chlorosis (`chlorosis`), and pale drooping
  leaves under moderate–severe/severe water stress (`waterClass`). Also grey rot, powdery mildew, sunburn and
  noble-rot berries, fruit-zone leaf removal (`leafSide`: `leaf.gdshader` drops 0.9 of the basal leaves on the chosen side;
  each leaf carries the way it faces out from its vine as a 16-sector code in the whole-number part of UV2.x, turned into the
  world and compared with `east_dir`, so Morning pulls the east-facing leaves; shots `3d_cotedor_leaves_east/_west`), and
  thinner bunches after frost losses.
- **Buds and berries**: dormant wood (growth 0) carries its winter buds (LOD 0–1, `build_vineyard.py dormant_bud`), so the
  count buds on a cane or spur can be seen. Berries and the workers' heads are spheres wound outward (`common.berry_sphere`;
  before 2026-10-10 they were wound inside out and lit from below). `common.export` warns `INWARD` for any closed part wound
  inward (rooms seen from inside are exempt; the scanned plants and trees are not checked), and `sync_assets3d.sh` shows it;
  the winery's vertical cylinders, rack beams and cellar door leaf were inward until 2026-10-11. Red berries' bloom is a
  dusky blue haze (it was a pale lilac).
- **Training-system learn card** (`game/src/ui/training_model.gd`): three of these vines on the vineyard's trellis (posts and
  the six wires of `_build_trellis`), with the vineyard's own materials (`vineyard.gd make_mat`), the Block's Variety leaf,
  winter (growth 0), spring (2) and summer (4, fruit-zone leaves pulled), and the parts named in a 2D overlay.
- **Plot & Region**: slope and aspect come from `D.plot`, per-Block slopes, a soil look per Region (blue-grey
  slate / pale limestone-marl / brown loam), and stones from `soilProfile.stones`. The Moselle and its road
  appear only in the Mosel.
- **Weather**: `D.weather.today.icon` (sun / cloud / rain / fog), rain amount and wind, plus afternoon sun for the
  date and latitude.

## Assets and tools

- `game/tools/sync_assets3d.sh` downloads CC0 textures, skies and props (Poly Haven) and builds all models with
  headless Blender into `game/assets3d/`. That folder is gitignored and has a `.gdignore`. Generators live in
  `game/tools/blender/`, and the sounds come from `game/tools/fetch_audio.py`.
- `game/tools/shot3d.sh [names] [--perf] [--breakdown]` plays real games and writes `game/shots/3d_*.png`, plus
  `3d_perf.json` with `--perf`. The Estate shots are `mosel_estate`, `mosel_estate_high`, `mosel_track`,
  `mosel_door`, `hall`, `hall_stairs`, `stairs_down`, `stairs_up`, `cellar`, `cellar_door`, and
  `cotedor_*` / `napa_*`. The log also prints the sound mix per shot (`sound: {...}`); the bus is muted unless
  `--sound` is given.
- Walk test: `view3d_test.tscn -- --capture3d none --walktest [mosel|cotedor|napa|terrassen|napa-mountain]`. It walks the capsule
  (real physics) from the vineyard along the track, through the door and the hall, down the stairs into the
  cellar and back up, then checks that sound stops when the view is hidden. It prints `WALK PASS/FAIL` and
  `SOUND PASS/FAIL`.
- Work shots: `mosel_harvest_crew`, `mosel_harvest_late`, `mosel_harvest_wide`, `mosel_sorting`,
  `cotedor_harvest_crew`, `cotedor_sorting`, `napa_harvest_machine`, `napa_harvest_crew`, `mosel_pruning`,
  `cotedor_canopy`, `mosel_spray`, `cotedor_spray`, `napa_spray` (the log prints `at work: …`).
- Drone shots: `mosel_drone`, `cotedor_drone`, `napa_drone`; yard shots: `mosel_yard`, `mosel_leanto`,
  `cotedor_yard`, `napa_yard`. The walk test starts with a drone round trip (4 on, 4 off) and checks the walker
  did not move, then hides and shows the view without `set_view` (as the UI does on Tab) and checks the drone,
  the walker's spot and the sound resume (`RESUME PASS`).
- LOD probe: `view3d_test.tscn -- --capture3d none --trellis`. The picture at a place must not depend on the
  direction you walked there from; `--trellis-old` restores the old bug to show the difference.
