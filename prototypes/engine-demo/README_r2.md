# PROTOTYPE — Engine demo, round 2: push the limits

**Question:** When the scenes get hard (weather, time of day, dim interiors, in-world information, a dense data dashboard), which engine gives the more convincing result, and how hard was it for an AI to get there: **Three.js (WebGPU)** or **Godot 4.7**?

Round 1 (`README.md`) is the baseline, with the same slope, assets and controls. Round 2 adds three scenes. Both engines use the same shared assets and must hit every shot listed below.

## Shared assets (read-only for engine builders)

```bash
./fetch_assets.sh && python3 fetch_assets_r2.py     # CC0 downloads (Poly Haven)
./build_assets.sh && ./build_assets_r2.sh           # headless Blender
```

- `assets/models/…`: round-1 vineyard, unchanged.
- `assets/models_r2/layout_r2.json`: **the source of truth** for round 2. It contains:
  - `vineyard_presets`: clear_afternoon, misty_sunrise, rain_morning, dusk. Each preset sets time of day, sun elevation and azimuth, weather, rain 0–1, wetness 0–1, cloud cover, fog density, the height of the valley-fog top, and a suggested sky HDRI.
  - `shots`: 11 named shots (scene + preset + camera). Vineyard shots reuse the round-1 camera names.
  - `cellar`: barrique and Fuder placements with **chalk-label data**, lamp positions, colours and lumens, and material hints.
  - `hall`: tank placements with **live readout data** (`oe_series`, temperatures, phase, notes), the readout panel's position on each tank (`tankInfo.panel`), hanging-lamp lights, and props.
  - `trees`: impostor forest for the far hills (`trees.json`, 97k instances, `trees_atlas.png` with 4 cells, `tree_card.glb`).
- **Models:** `barrique.glb`, `fuder.glb` (with cradle), `tank.glb` (~5,000 L stainless, legs, manway, valves, cooling jacket, glycol lines), `cellar.glb` (a 22 × 6.2 m vaulted slate cellar with racks), `hall.glb` (24 × 14 × 7 m, a ribbon of windows, an open roller door on +X, trusses, a catwalk).
- **Poly Haven props** in `assets/polyhaven_models/*/` (glTF): `industrial_caged_sconce`, `hanging_industrial_lamp`, `plastic_crate_01`, `ladder_sectioned_01`, `modular_industrial_pipes_01`.
- **Textures** in `assets/textures/`: `castle_wall_slates` (cellar vault), `cobblestone_floor_04`, `concrete_floor_worn_001`, `grey_plaster_02`, `oak_veneer_01`, `rusty_metal_02`, plus round 1's textures. All UVs on the rooms are **in metres**.
- **Skies** in `assets/hdri/`: `kloofendal_misty_morning_puresky`, `kloofendal_overcast_puresky`, `qwantani_sunrise_puresky`, `qwantani_dusk_2_puresky`, `sky.hdr`.
- `assets/models_r2/dashboard_data.json`: fake but plausible Mosel data for the dashboard (5 Blocks, weekly °Oe/TA/pH, 7-day forecast, inbox including the Mentor).

## What each engine must build (push hard, this is the point)

### A. Vineyard: weather and time of day
- **Continuous time of day** (latitude 49.9° N, 26 September), with a sky that matches the sun: blend the HDRIs or use a physical/procedural sky with clouds. Pressing **T** advances time; pressing **P** cycles presets with a smooth transition of about 5 s.
- **Rain:** GPU particles, dense near the camera and scaling with `rain`. Splashes are a bonus. **Wetness:** darker albedo and much lower roughness on slate, stakes and leaves, droplet sparkle on leaves, puddles in low spots with ripples.
- **Fog:** volumetric or height fog, a valley-fog layer below `valleyFogTopY`, and **light shafts through the mist** at sunrise.
- **Far forest:** instanced tree impostors from `trees.json` (alpha-tested, fading with distance, lit consistently with the sun).
- **Wind** that varies by weather (stronger in rain).

### B. Winery
- **Cellar:** a slate vault (castle_wall_slates), cobbled floor (damp sheen), oak barrels (oak_veneer + vertex colour) and dark steel hoops. Put the caged sconce model at each light position, with an emissive bulb and **real shadowed point lights**. Add **indirect/bounce light** by whatever this engine does best (real-time GI, baked GI, or light baked in Blender). Say which one you used and why. Add subtle haze in the light cones. **Chalk labels on every barrel head** (text from the layout), plus carved Fuder heads.
- **Hall:** daylight through the high windows and the open door, the hanging lamps (model + light), and brushed-stainless tanks with believable reflections.
- **Live tank readout panels** placed at `tankInfo.panel`: contents, phase and day, temperature vs setpoint, °Oe with a sparkline of `oe_series`, and the note. Values tick slowly, and the controller LED blinks. Add the crates and the ladder.

### C. Dashboard: a Football Manager-style "Vineyard" screen at 1920×1080 from `dashboard_data.json`
- **Top bar:** date, stage, cash, time controls (+1 day / +1 week / Continue), Alert badge. **Left navigation.** **Block table:** sortable by clicking a header, colour-coded cells (e.g. botrytis risk, water stress, °Oe), hover tooltips. **Ripeness chart:** °Oe and TA per Block over the weeks, with the Block selectable. **7-day forecast strip.** **Inbox panel** with the Mentor's message.
- It should look like a polished management game, not a spreadsheet: dark theme, strong typography and hierarchy.
- **Three.js side:** web UI (HTML/CSS/JS; a small chart library from npm is fine). **Godot side:** Godot's own Control nodes, themes and custom-drawn charts only, **no embedded web view**. This is the test of whether Godot's UI is good enough.

## Shots (1920×1080) → `shots/r2/<engine>_<shot>.png`

rain_row · rain_close · mist_valley · sunrise_drone · dusk_uphill · cellar_aisle · cellar_heads · cellar_fuder · hall_overview · hall_panel · dashboard

**Performance:** implement a perf mode (average and 1%-low FPS over 5 s per shot → `shots/r2/<engine>_perf.json`), but **don't run it**. Both engines are being built at the same time on the same GPU, so the parent runs all perf measurements at the end, one engine at a time.

## Rules for builders
- Only edit your own engine folder (`threejs/` or `godot/`). Treat shared assets as read-only. If a shared asset is wrong, report it to the parent; don't patch it.
- Extra CC0 assets are allowed (Poly Haven, ambientCG). Put them in `assets/extra_<engine>/`, record them in `assets/extra_<engine>/SOURCES.md`, and note the licence.
- Look at every screenshot yourself and iterate. The goal is the *most* convincing result this engine can reasonably reach, not "it renders".
