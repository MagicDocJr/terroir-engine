# Terroir Engine

Realistic vineyard-founding and winemaking simulator. Private project.

- Read first: `docs/spec.md` (the agreed MVP), `CONTEXT.md` (glossary; use its terms exactly), `docs/adr/` (decisions not to undo without discussion), `docs/backlog.md` (deliberately deferred scope; don't build it early).
- The owner writes no code. Claude builds, tests and verifies everything. Optimise tooling for AI verification: text-based, CLI-drivable, headless-testable.
- The simulation core is headless and deterministic (ADR 0001): a plain C# library, tested with `dotnet test`. The game is Godot 4.7 .NET plus Blender (ADR 0003). Godot never computes outcomes.
- Drive Godot from the CLI (Windows exe from WSL, Windows paths via `wslpath -w`, env vars only reach it if listed in `WSLENV`). LightmapGI needs the editor; use VoxelGI or SDFGI. The prototype branch `prototype/engine-demo` has working examples: capture mode, smoke test, perf mode, dashboard.
- Science accuracy is non-negotiable: every in-game fact is cited in `docs/science/`, simulated values stay inside the calibration ranges, unbacked numbers are marked `UNVERIFIED`, and game simplifications are labelled as such.
- `reference/` holds the owner's purchased WSET books. It is gitignored. Paraphrase only, never copy text into the game or the docs.
- Verify with `scripts/check.sh`. It runs the build, the sim tests, the layout self-test and every harness in parallel (about 85 s), prints a summary table, and fails on any script error or layout issue.
  - Every harness screenshot runs a layout check: collapsed wrapped labels, labels with no width.
  - It ends with a visual change report against `game/shots_baseline/` (`game/shots/diff/report.html`). Review only the changed screens, then approve with `scripts/check.sh --approve`.
  - Explore the sim with the probes in `tools/probes/` (`dotnet run tools/probes/<probe>.cs`); keep new useful ones there.
  - Record a harness as video with `scripts/record.sh <harness> [frames-per-screen]` (Godot Movie Maker, saved to `game/shots/video/`).
- Environment: WSL2 on Windows. Blender 5.2 LTS is at `C:\Program Files\Blender Foundation\Blender 5.2\`. Godot 4.7.2 **.NET** is at `C:\Users\Aleksander\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\` (the standard build, used by the prototype, sits beside it). The .NET 10 SDK is installed on both Windows (`dotnet.exe`) and WSL (`~/.dotnet`). `csharp-ls` and Git LFS are installed in WSL. The project stays on `/mnt/c`, because Godot, Blender and Chrome are Windows apps. WSL uses mirrored networking so it can reach Blender MCP on Windows. The official Blender Lab MCP add-on (port 9876) needs Blender to be open.
