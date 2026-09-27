# Terroir Engine

A private, realistic vineyard-founding and winemaking simulator. You buy bare land in the Mosel, the Côte d'Or or Napa Valley, plant it Block by Block, and farm a Vintage on the weather that really happened. Then you make the wine with WSET-level cellar choices and read a Tasting sheet that explains every descriptor.

- **Play (Windows):** double-click `play.bat`, or from WSL run `scripts/play.sh`.
- **Simulation core:** `sim/`, a headless, deterministic C# library. Test it with `cd sim && dotnet test` (ADR 0001).
- **Game:** `game/`, Godot 4.7 .NET plus Blender-built 3D (ADR 0003). The 3D assets are not in git; rebuild them with `game/tools/sync_assets3d.sh`.
- **Checks:** `scripts/fuzz.sh` presses every button through a whole Vintage. `scripts/capture.sh <plot>` plays a scripted game and screenshots every screen.
- **Read first:** `docs/spec.md`, `CONTEXT.md` (glossary), `docs/adr/`, `docs/backlog.md`, `docs/science/` (every in-game fact is cited there).
