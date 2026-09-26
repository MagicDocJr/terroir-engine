# PROTOTYPE — Engine demo (throwaway)

**Question:** Which engine gets closer to "feeling like I'm there" on a steep Mosel slate slope, and how well can AI build and verify it: **Three.js (WebGPU)** or **Godot 4.7**?

Both scenes use exactly the same Blender-made assets and layout. Only the engine differs. The verdict goes into an ADR on `main`; this branch keeps the code as a record.

## Run

```bash
./fetch_assets.sh      # CC0 textures + sky from Poly Haven (once)
./build_assets.sh      # headless Blender → assets/models/*.glb, layout.json, heights.bin
# Three.js:  cd threejs && npm install && npm run dev   → open http://localhost:5173
# Godot:     ./godot/run.sh                             → opens the Godot window
```

Controls (both engines): **WASD** walk, **mouse** look (click to capture), **Shift** run, **1–5** camera presets, **F** toggles an FPS readout.

## Shared scene spec (both engines must follow this)

- **Coordinates:** glTF convention: Y up, metres, **+Z is downslope (south)**, +X is east. The vineyard block is centred on the origin, ±13.8 m in X and ±14.4 m in Z, on a ~35° south-facing slope. The river's north bank is at z = 110, the water surface at y = 0, and the opposite bank starts at z = 240.
- **Assets** (`assets/models/`):
  - `terrain_near.glb`: 160 × 160 m, 0.5 m grid. UVs are world/3 m. COLOR_0.r is a grass mask (0 = slate soil, 1 = grass).
  - `terrain_far.glb`: 3.6 × 2.8 km. COLOR_0 is the albedo (forest, fields, other vineyards).
  - `water.glb`.
  - `vine_{0..3}.glb` (full detail) and `vine_{0..3}_lod1.glb` (low detail). Materials: `vine_wood` (stake), `vine_bark`, `vine_leaf` (COLOR_0 albedo, double-sided), `vine_berry` (COLOR_0 albedo).
  - `slate_{0..4}.glb`: unit-size flat slate chips.
  - `grass_{0..2}.glb`: unit-height tufts, COLOR_0 albedo, double-sided.
- **Layout** (`assets/models/layout.json`):
  - `vines.items`: `[variant, x, y, z, yaw, scale]` (506 vines).
  - `slate.items`: `[variant, x, y, z, qx, qy, qz, qw, scale]` (45k).
  - `grass.items`: `[variant, x, y, z, yaw, scale]` (7k).
  - `sun.direction`: the vector *towards* the sun (elevation 20°, azimuth 240° WSW, i.e. late afternoon in September).
  - `cameras`: 5 named presets `{position, target}`: row_downhill, uphill, valley_view, drone, vine_close.
- **Walking height:** `heights.bin` is float32 little-endian, 321 × 321, row-major by Z. Origin x0 = z0 = −80, step 0.5 (see `layout.near`). Use bilinear lookup, eye height 1.7 m.
- **Vine LOD:** full detail within **20 m** of the camera, `_lod1` beyond. Re-bucket when the camera has moved more than 1 m.
- **Materials:**
  - Near terrain: blend `textures/rock_ground` (tinted cool blue-grey, like Devonian slate) with `textures/grass_ground` using the COLOR_0.r mask.
  - Bark and stake: `textures/bark_willow_02` (stake lighter and greyer).
  - Leaves: double-sided, roughness about 0.55, with backlit translucency if the engine has it cheaply.
  - Water: dark and glossy, reflecting the sky.
- **Lighting:** HDRI `assets/hdri/sky.hdr` as sky and ambient light. A warm directional sun (≈ rgb 1.0, 0.85, 0.68) along `sun.direction`, with cascaded shadows out to about 150 m.
- **Atmosphere:** distance haze so the opposite bank (0.5–2 km away) reads as far away.
- **Post-processing:** AO, subtle bloom, filmic tonemapping (AgX or ACES), anti-aliasing.
- **Screenshot protocol:** 1920 × 1080, one PNG per camera preset at `shots/<engine>_<preset>.png`, taken after the scene has settled (≥ 60 frames). Also write `shots/<engine>_perf.json` with the average and 1%-low FPS over 5 s per preset, with vsync off.
