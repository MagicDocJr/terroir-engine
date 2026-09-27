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
| `set_view(kind: String)` | `"vineyard"`, `"cellar"` or `"hall"`. It teleports the walker to that place in the one world. |
| `signal exit_requested` | Tab, or Esc while the mouse is not captured. |
| `show_hud` | Small date/Block/weather overlay plus the key hint line (default on). |
| `sound_volume_db`, `sound_on` | Master volume of the view's sound (dB, 0 = as mixed) and on/off. M toggles it. |
| `camera_preset(name, block)` / `set_camera(pos, target)` / `capture()` | Used by the test harness. The eye is put exactly there, and the walker waits until the next move key. |

Input is read only while the node is visible. Click to capture the mouse, then walk with WASD (or the arrow
keys). Shift runs. 1/2/3 jump to the vineyard, cellar or hall, M turns the sound on or off, and Tab goes back.
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
| `view3d_test.gd` | Test harness: screenshots, FPS, the walk test and the LOD probe. |

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
- **Regional outside**: Mosel has white render, a slate roof and a slate plinth. Côte d'Or has cream render,
  flat brown tiles and limestone. Napa has stucco and clay barrel tiles. *Game simplification (look only).*
- **Row orientation**: rows are drawn as planted (snapshot `rows`: DownSlope / NorthSouth / EastWest), and the sun
  is placed using the Plot's aspect (`aspectDeg`).

## Performance measures

- The environment is picked by zone: the outside sky environment, a hall environment (same sky, interior
  settings, auto exposure) or the dark cellar environment.
- The interior lights and VoxelGI run only near or inside the building (hall: within 45 m; cellar/stairs: when
  inside). Light shadows are on only in the room you are in, and the tank screens re-render only in the hall.
- Indoors, the sun's shadow reaches only 40 m and uses 2 splits. It is switched off in the cellar.
- Occlusion culling (`viewport.use_occlusion_culling`): box occluders sit inside the hall walls and roof and in
  the rock around the cellar. From inside, the vineyard is culled; from outside, the interior is culled except
  through the door and windows.
- Rain particles and their heightfield exist only outdoors.
- Vine LODs share exact visibility thresholds (no hysteresis margin; that margin made the nearest vines vanish).

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
  noble-rot berries, fruit-zone leaf removal (`leafSide`), and thinner bunches after frost losses.
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
- LOD probe: `view3d_test.tscn -- --capture3d none --trellis`. The picture at a place must not depend on the
  direction you walked there from; `--trellis-old` restores the old bug to show the difference.
