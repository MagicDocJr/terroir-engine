# Cozy, customizable winery — design

Status: approved by the owner in conversation 2026-09-28 ("go ahead, don't ask more questions"). Owner answers: **looks first** (purely cosmetic, the simulation is unaffected) and **regional character** (each Region looks like its tradition, customization within it). Vocabulary follows `CONTEXT.md`.

## 1. Goal

The winery stops being a plain concrete building. Each Region gets a warm, characterful default, and the player can change the look of the fermentation hall, the barrel cellar and the outside from a short menu, then walk in and see it.

**Success looks like**
- A new game's hall looks regional and lived-in: Mosel slate and dark timber, Burgundy limestone and oak beams, Napa redwood and terracotta.
- A "Winery look" panel on the Winery screen changes walls, floor, ceiling, lights, a tasting corner, plants and outside details; the 3D view shows the change at once.
- Choices are saved with the game and replay exactly; they have no effect on any wine, cost or outcome (labelled "Cosmetic").
- The hall still runs at the same frame rate on the owner's PC (no more than two extra shadowed lights; props are low-poly Poly Haven CC0 models).

**Non-goals** (backlog): buying and placing equipment (tanks, barrels, presses: the "Build and equip the Winery" item), building extensions or a separate tasting room interior, day/night lighting, player-placed free furniture.

## 2. The options

Each element has 3–5 options; the Region's default is marked ★. All textures and models are Poly Haven CC0 (added to `game/tools/fetch_assets3d.py` and `CREDITS.txt`).

| Element | Options (texture / model) | Mosel ★ | Côte d'Or ★ | Napa ★ |
|---|---|---|---|---|
| Walls (hall) | Plain render (`grey_plaster_02`, today's) · Slate stone (`castle_wall_slates`) · Limestone blocks (`white_sandstone_blocks_02`) · Whitewashed brick (`whitewashed_brick`) · Redwood boards (`brown_planks_07`) | Slate stone | Limestone blocks | Redwood boards |
| Floor (hall) | Polished concrete (`concrete_floor_worn_001`, today's) · Stone flags (`monastery_stone_floor`) · Slate flags (`slate_floor_03`) · Terracotta tiles (`terracotta_floor_tiles`) · Herringbone brick (`herringbone_brick`) | Slate flags | Stone flags | Terracotta tiles |
| Ceiling | Steel trusses (today's) · Oak beams (`dark_wood` on the trusses and roof underside) | Oak beams | Oak beams | Oak beams |
| Lights | Workshop lamps (today's, neutral white) · Warm pendants (same lamps at 2700 K, a warm fill) · Lantern chandeliers (`lantern_chandelier_01`, warm) | Warm pendants | Lantern chandeliers | Warm pendants |
| Tasting corner (south-east corner of the hall) | None · Tasting table (`dining_table`, four `gallinera_chair`, `wine_bottles_01`, a `wine_barrel_01` side table, `Lantern_01`) · Lounge (`Sofa_01`, two `ArmChair_01`, `WoodenTable_01` coffee table, `WoodenTable_02` side table, a rug) | Tasting table | Tasting table | Lounge |
| Plants | Off · On (`potted_plant_01/02` by the door and the corner; `planter_box_01` under the outside windows) | On | On | On |
| Outside | Plain · Cosy (a bench `painted_wooden_bench`, window boxes, two `wooden_lantern_01` by the doors, warm window glow) | Cosy | Cosy | Cosy |
| Cellar | Plain · Candlelit (`wooden_candlestick` and `Lantern_01` on the racks, a warm unshadowed light every 6 m) | Candlelit | Candlelit | Candlelit |

The outside render, roof and plinth keep their existing regional materials (`winery.gd _region_material`).

## 3. Architecture

- **Catalogue:** `game/src/view3d/winery_style.gd` (new, shared by the 2D panel and the 3D view): element → options `{value, label, blurb}` and the regional defaults. Look only, so it lives in the game layer (ADR 0001 is about outcomes).
- **Persistence:** a new sim command `decor <key> <value>` stores a cosmetic choice in `GameSession.Decor` (a dictionary; recorded in the command log like `flag`), and the snapshot carries `decor: {key: value}`. The sim does not interpret it. Unknown keys and values are stored as given (the game layer ignores what it doesn't know), so old saves and future options stay compatible.
- **3D:** `winery.gd apply_style(style: Dictionary)` swaps material parameters (walls, floor, trusses/roof underside), switches light colour/energy and fixture models, and shows or hides prop groups (tasting corner, plants, outside set, cellar candles), built once on first use. `view3d.apply_snapshot` passes the resolved style (defaults + `decor`). The GI of the hall is re-baked only when walls, floor or ceiling change (cheap probe refresh otherwise).
- **2D:** a "Winery look" panel on the Winery screen: one segmented control per element (current value highlighted, ★ marks the regional default), a one-line blurb, "Reset to the regional look", and "Walk in to see it" (opens the 3D hall). A line says "Cosmetic: no effect on the wine or the accounts".

## 4. Testing
- Sim: `decor` stores and replays (save → load → same snapshot `decor`); decor commands change nothing else (snapshot equality apart from `decor`).
- 3D harness `view3d_test.gd --winerylook`: renders the hall, the cellar and the outside for each Region's default, plus two non-default combinations, into `game/shots/3d_look_*.png` for review; checks the frame time in the hall stays within 10 % of today's (`--perf` on the same camera).
- UI: `scripts/fuzz.sh` presses every option.

## 5. Documentation
- `game/src/view3d/README.md`: the style contract and options.
- `game/assets3d/CREDITS.txt` (generated by `fetch_assets3d.py`): the new CC0 assets.
- `docs/backlog.md`: follow-ups (equipment, tasting room interior, day/night).
