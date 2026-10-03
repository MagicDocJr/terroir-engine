# Terroir Engine

A private, realistic vineyard-founding and winemaking simulator. You buy bare land in the Mosel, the Côte d'Or or Napa Valley, plant it Block by Block, and farm Vintage after Vintage on the weather that really happened. Then you make the wine with WSET-level cellar choices and read a Tasting sheet that explains every descriptor.

- **Play (Windows):** double-click `play.bat`, or from WSL run `scripts/play.sh`.
- **Standalone Windows build:** `scripts/export-windows.sh` writes `build/TerroirEngine/` (double-click `TerroirEngine.exe`, no Godot or dotnet needed) and `build/TerroirEngine.zip`. It needs the Godot 4.7.2 .NET export templates.
- **Building C#:** always through `scripts/build-game.sh` (WSL dotnet). Windows Application Control blocks Godot's unsigned source generators in Windows `dotnet`, which leaves a game that cannot load its C# scripts.
- **Simulation core:** `sim/`, a headless, deterministic C# library. Test it with `cd sim && dotnet test` (ADR 0001).
- **Game:** `game/`, Godot 4.7 .NET plus Blender-built 3D (ADR 0003). The 3D assets are not in git; rebuild them with `game/tools/sync_assets3d.sh`.
- **Checks:** `scripts/fuzz.sh` presses every button through a whole Vintage. `scripts/capture.sh <plot>` plays a scripted game and screenshots every screen.
- **Tasting practice and the Wine Fair:** from the title screen or the game's menu. The simulation pours real-vintage Wines for four exercises, themed Stands with vintage quizzes, ranks, medals and a Cellar book (`docs/science/tasting-practice.md`). `scripts/practice.sh` drives it headlessly; the CLI has `pour <plot> <vintage> …` and `fair [stand] [seed]`.
- **Learning:** Tasting practice runs a daily session of about six questions on Causes (why a Wine tastes as it does), spaced over days and weeks until each is Known, with Confidence before every reveal and an optional exam date. New Wines on the Estate open with a prediction first, and Learn links beside key choices open learn cards for the player's own Block or Lot (`docs/science/learning-core.md`). `scripts/learning.sh` drives it headlessly.
- **Famous vintages:** replay Côte d'Or 2016, Mosel 2018 or Napa 2011 from the title screen, with three medals judged on your Wine and a cited debrief of what really happened and what growers did (`docs/science/famous-vintages.md`). `scripts/scenarios.sh` drives it headlessly.
- **Read first:** `docs/spec.md`, `CONTEXT.md` (glossary), `docs/adr/`, `docs/backlog.md`, `docs/science/` (every in-game fact is cited there).
