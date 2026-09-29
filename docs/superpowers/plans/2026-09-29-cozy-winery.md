# Cozy, customizable winery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A warm, regional-default winery (hall, cellar, outside) whose look the player changes from a short menu, saved with the game and without any effect on outcomes.

**Architecture:** A shared GDScript catalogue (`winery_style.gd`) defines elements, options and regional defaults; the sim only stores `decor <key> <value>` commands (replayed with saves, shown as `decor` in the snapshot); `winery.gd apply_style()` swaps materials, light colours/fixtures and prop groups; a Winery-screen panel edits the choices.

**Tech Stack:** C# sim (one command, one snapshot key), Godot 4.7 GDScript, Poly Haven CC0 assets (fetched by `game/tools/fetch_assets3d.py`).

**Spec:** `docs/superpowers/specs/2026-09-29-cozy-winery-design.md`

## Global Constraints

- Cosmetic only: no effect on any simulated value, cost or message; the UI says "Cosmetic: no effect on the wine or the accounts".
- ADR 0001 holds: the sim stores the choice but never interprets it.
- Assets are Poly Haven CC0 and credited in `CREDITS.txt`; no other sources.
- Hall frame time within 10 % of today's on the same camera (`--perf`).
- Build with `scripts/build-game.sh`; checks: sim tests, `scripts/fuzz.sh`, `scripts/capture.sh`, the `--winerylook` harness, screenshot review.
- Commits end with the Co-Authored-By line; no push.

## Review Focus

1. **A `decor` key or value the game doesn't know** (from an older or newer build) → stored, ignored by the 3D view, no error. Pinned in Task 1 (`Decor_UnknownKeys_AreStoredAndHarmless`).
2. **Switching style repeatedly** (fuzz presses every option) → no duplicated props, no leaked lights. Pinned in Task 3 (harness step `restyle_twice_same_node_count`).
3. **A save made before this feature** (no `decor` commands) → the regional defaults show. Pinned in Task 1 (`Decor_EmptyByDefault`) and Task 3 (default renders).
4. **The 3D view not yet opened when the style changes** → the change applies on the next open. Pinned in Task 3 (harness applies a style before the first `apply_snapshot`).
5. **Frame time with the tasting corner and chandeliers** → within 10 %. Pinned in Task 3 (`--winerylook --perf`).

---

### Task 1: `decor` command and snapshot key (sim)

**Files:** `GameSession.cs` (command, `Decor` dictionary), `Snapshot.cs` (`decor`), `sim/tests/.../TaskTests.cs` → new `DecorTests.cs`.

- [ ] **Step 1: Failing tests**

```csharp
using TerroirEngine.Game;
namespace TerroirEngine.Tests;

public class DecorTests
{
    [Fact]
    public void Decor_EmptyByDefault() => Assert.Empty(Snapshot.Build(new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2014 }))["decor"]!.AsObject());

    [Fact]
    public void Decor_IsStored_AndReplays_AndChangesNothingElse()
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2014 });
        var before = Snapshot.Build(g); before.Remove("decor");
        g.Apply(new Command { Type = "decor", A = "walls", B = "brick" });
        var after = Snapshot.Build(g);
        Assert.Equal("brick", after["decor"]!["walls"]!.GetValue<string>());
        after.Remove("decor");
        Assert.Equal(before.ToJsonString(), after.ToJsonString());
        var g2 = GameSession.Load(Fixture.Data, g.Save());
        Assert.Equal("brick", Snapshot.Build(g2)["decor"]!["walls"]!.GetValue<string>());
    }

    [Fact]
    public void Decor_UnknownKeys_AreStoredAndHarmless()
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-seitental", PlantingYear = 2014 });
        g.Apply(new Command { Type = "decor", A = "hologram", B = "on" });
        Assert.Equal("on", Snapshot.Build(g)["decor"]!["hologram"]!.GetValue<string>());
    }
}
```

- [ ] **Step 2: Run** → FAIL (`decor` missing).
- [ ] **Step 3: Implement** — `public Dictionary<string, string> Decor { get; } = new();` next to `Flags`; `case "decor": if (!string.IsNullOrWhiteSpace(c.A)) Decor[c.A] = c.B; break;`; snapshot `["decor"] = DecorObj(g)` with keys sorted.
- [ ] **Step 4: Run all tests** → pass. **Step 5: Commit** `feat(sim): cosmetic decor choices stored and replayed`.

### Task 2: Catalogue and the Winery-look panel (2D)

**Files:** create `game/src/view3d/winery_style.gd`, `game/src/ui/winery_look_panel.gd`; modify `screens/winery.gd` (panel at the bottom; also shown when there are no Lots).

- [ ] **Step 1: Catalogue** — `const ELEMENTS := [{key, label, options: [{value, label, blurb}]}]` for walls, floor, ceiling, lights, corner, plants, outside, cellar (values: walls `render|slate|limestone|brick|redwood`; floor `concrete|stone|slate|terracotta|herringbone`; ceiling `steel|oak`; lights `workshop|warm|chandelier`; corner `none|table|lounge`; plants/outside/cellar `off|on` with labels per spec); `const DEFAULTS := {"mosel": {...}, "cote-dor": {...}, "napa": {...}}`; `static func resolve(region: String, decor: Dictionary) -> Dictionary` (defaults overlaid with known keys/values only).
- [ ] **Step 2: Panel** — title "Winery look", subtitle "Cosmetic: no effect on the wine or the accounts"; per element a label + `UI.segmented` (★ after the regional default's label) sending `Sim.Command("decor", key, value, …)` then `shell.refresh()`; the chosen option's blurb; buttons "Reset to the regional look" (sends decor for every key = "", i.e. follow the default) and "Walk in to see it" (`shell.toggle_3d("hall")`).
- [ ] **Step 3: Build + fuzz** — no `SCRIPT ERROR`. **Step 4: Commit** `feat(game): Winery look panel and style catalogue`.

### Task 3: 3D — materials, lights, prop groups; harness

**Files:** `winery.gd` (`apply_style`, prop groups, light switching), `view3d.gd` (pass the resolved style), `view3d_test.gd` (`--winerylook`), README.

- [ ] **Step 1: Harness first** — `--winerylook`: for each Region (Mosel Blauschiefer, Côte d'Or Village, Napa Bench) start a game, apply the default style, render `hall`, `hall_stairs`, `cellar` and the outside `door` preset to `3d_look_<region>_<cam>.png`; then two variants (Mosel with brick + chandeliers + lounge; Napa with render + workshop + none) for `hall`; step `restyle_twice_same_node_count` (apply A, B, A → the winery's child count equals after the first A); `--perf` mode times 300 frames on the `hall` camera for today's look vs the regional default.
- [ ] **Step 2: Materials** — `apply_style`: `hall_wall` ← the wall texture (uv 0.35–0.5 per texture so blocks are life-size), `hall_floor` ← the floor texture, `hall_steel` and `roof_under` ← `dark_wood` when ceiling = oak (albedo tint warm brown, metallic 0); keep the current materials for "render"/"concrete"/"steel".
- [ ] **Step 3: Lights** — workshop: today's colour/energy; warm: colour (1.0, 0.78, 0.55), energy ×0.85, plus the hall's GI; chandelier: hide the industrial lamp props, place `lantern_chandelier_01` at the same hanging points (6 of the 12, over the aisle), light colour (1.0, 0.74, 0.5).
- [ ] **Step 4: Prop groups** (Node3D groups built lazily, shown/hidden): tasting corner at hall (8.5, 0, 4.8) facing the south windows: table, four chairs, bottles on the table, barrel side table, lantern with a small warm OmniLight3D (unshadowed); lounge at the same place: sofa, two armchairs, coffee table, a rug (QuadMesh with a warm woven colour); plants: two pots by the roller door inside, two in the corner, planter boxes under the south windows outside; outside: bench by the office door, two wooden lanterns with warm omni lights (unshadowed) by the doors, window-glow emission on `window_dark` (warm, low); cellar: a candlestick on every third rack and a lantern at each end, warm OmniLight3D every 6 m (unshadowed).
- [ ] **Step 5: GI** — re-bake the hall VoxelGI only when walls/floor/ceiling change (`bake_gi`), otherwise refresh probes.
- [ ] **Step 6: Run harness; review every screenshot** with the Read tool; tune texture scale, light colour and prop placement until each Region reads warm and distinct; `--perf` within 10 %.
- [ ] **Step 7: Commit** `feat(3d): cozy regional winery — wall/floor/ceiling looks, warm lights, tasting corner, plants, cellar candles`.

### Task 4: Checks and docs
- [ ] Sim tests; fuzz; capture (SAVE/LOAD ok); `--perf`; README style section; backlog follow-ups; CREDITS regenerated by the fetch script. Commit `docs: winery look`.
