# 3D views (look-only MVP)

The vineyard, the barrel cellar and the fermentation hall, drawn from the simulation snapshot. Nothing here
computes an outcome (ADR 0001): stages, colours, disease cues, tank readouts and cask labels all come from
`Sim.Snapshot()`.

## Contract

`res://src/view3d/view3d.tscn` (root `Control`, script `view3d.gd`):

| member | meaning |
|---|---|
| `apply_snapshot(D: Dictionary)` | `D` = parsed `Sim.Snapshot()`. Call on entry and after every advance. Cheap unless the Plot changed (then the landscape is rebuilt, ~1–2 s). |
| `set_view(kind: String)` | `"vineyard"`, `"cellar"` or `"hall"`. The first visit to a winery room builds it and bakes VoxelGI (~1–2 s). |
| `signal exit_requested` | Tab, or Esc while the mouse is not captured. |
| `show_hud` | small date/Block/weather overlay (default on). |
| `camera_preset(name, block)` / `set_camera(pos, target)` / `capture()` | used by the test harness; also usable for cut-aways. |

Input is only read while the node is visible: click to capture the mouse, WASD, Shift to run, 1/2/3 switch
views. The world renders in its own `SubViewport` (own `World3D`), which stops rendering while hidden.

## What the vineyard shows (per Block, from `D.blocks`)

- **Growth**: Dormant → pruned wood; Budburst → rosettes; Shoots → short shoots (longer once LAI > 1);
  Flowering/FruitSet → inflorescences; later → full canopy with bunches. Picking removes the picked share of
  bunches; Harvested shows none; LeafFall colours and drops the leaves (red varieties turn red, white yellow).
- **Bunch colour**: véraison starts at ~22 °Oe and is complete by ~60 °Oe (each berry turns at its own moment);
  red: red → blue-black, white: green → golden. *Game simplification (display only)*.
- **Training**: Einzelpfahl = single stake with two heart-shaped bows on a square grid; Guyot/Cordon = VSP rows
  with posts and wires. Spacing follows `density`; rows run down the slope when the Plot is ≥ 30 %, otherwise
  north–south (the sim's default, which the snapshot does not expose yet).
- **Cues**: downy mildew oil spots (`downyLeaf`), interveinal lime chlorosis (`chlorosis`), pale drooping leaves
  under moderate–severe/severe water stress (`waterClass`), grey rot / powdery / sunburn / noble-rot berries,
  fruit-zone leaf removal (`leafSide`), frost losses thin the bunches.
- **Plot & Region**: slope and aspect from `D.plot` (the sun is rotated into the slope's frame, so a south slope
  gets the southern sun), per-Block slopes, soil look per Region (blue-grey slate / pale limestone-marl /
  brown loam), stones from `soilProfile.stones`, Moselle river only in the Mosel.
- **Weather**: `D.weather.today.icon` (sun / cloud / rain / fog), rain amount and wind; afternoon sun for the
  date and latitude.

## Assets and tools

- `game/tools/sync_assets3d.sh` downloads CC0 textures, skies and props (Poly Haven) and builds all models with
  headless Blender into `game/assets3d/` (gitignored, has `.gdignore`). Generators: `game/tools/blender/`.
- `game/tools/shot3d.sh [names] [--perf]` plays real games and writes `game/shots/3d_*.png`
  (+ `3d_perf.json`). Harness: `view3d_test.tscn` (`--capture3d`, `--perf`, `--breakdown`).
