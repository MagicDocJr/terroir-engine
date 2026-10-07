# Winery Shop Implementation Plan

> Inline execution with TDD per task, then one whole-branch review on the most capable model.

**Goal:** a Shop where the Estate's cash buys cozy winery looks (walls, floor, lights, corner, plants, cellar, facade,
shutters, outside), previewed in 3D and switchable once owned.

**Spec:** `docs/superpowers/specs/2026-10-07-equipment-shop-design.md` (revised: the Winery shop)

## Global constraints
- Cosmetic only: the sim never reads it (ADR 0001).
- Purchases are replayable commands.
- No pressure mechanics.
- Prices are `UNVERIFIED` design values in data.
- Verify with `scripts/check.sh`. 3D with `scripts/winerylook.sh`.

## Review Focus
1. **Old saves** → their current look is owned free; nothing disappears.
2. **Buying with too little cash** → refused with the gap shown. Overdraft is allowed only as for other spending (the
   existing ledger rules).
3. **`decor` with an item not owned** (from an old command or the harness) → refused, and the look keeps its current
   value.
4. **Preview in 3D** → never changes the save or the cash.
5. **The facade on a Plot with a different building footprint, or another Region** → the materials apply without
   missing nodes.

## Tasks
1. **Sim:**
   - `data/winery_shop.json` and `WineryShop.cs`, the `buy` command, ownership, the decor gate, the old-save migration,
     and the snapshot;
   - tests (purchase and replay, gate, migration, new-game start set, price band).
2. **3D:**
   - new elements in `winery_style.gd` and `winery.gd`: facade paint and panels, shutters, string lights, the sign;
   - the `winerylook` harness renders them;
   - the thumbnail script and the committed thumbnails.
3. **UI:**
   - the `shop.gd` screen, nav entry, intro card, and the "Your winery" panel;
   - the inbox line after the first sale, preview in 3D, and harness steps;
   - screenshots reviewed through the layout check and the visual diff.
4. **Docs, checks, review, merge:** docs (economy/winery notes, CONTEXT, README, backlog), `scripts/check.sh`, the final
   review, the fix pass, and a local merge.
