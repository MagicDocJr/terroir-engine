# Godot 4 (.NET) and Blender, with the simulation core in C#

We build the game in **Godot 4.7 (.NET build)**. The 3D views and the Football Manager-style dashboard both use Godot's own nodes; there is no embedded web UI. Assets come from **Blender 5.2**, driven by scripts and the official Blender MCP. The headless simulation core (ADR 0001) is a **plain C# library** with no Godot dependency, tested with `dotnet test` from the command line. Godot references that library.

The choice rests on a two-round prototype (branch `prototype/engine-demo`, `shots/r2/compare_r2.html`). The same Blender assets were built in Three.js (WebGPU) and in Godot, and each engine was measured on its own on the target PC (RTX 5080). In the easy scene the two looked about equal. In the hard scenes (rain and mist on the slope, the lamp-lit barrel cellar) Godot was faster and far smoother:

| Scene | Three.js average (slowest 1%) | Godot average (slowest 1%) |
|---|---|---|
| Vineyard in weather | 42–55 fps (31–37) | 56–64 fps (48–60) |
| Barrel cellar | 72–80 fps (46–50) | 127–144 fps (95–120) |

Godot also has more of the needed features built in: volumetric fog and light shafts, GPU particles with collision, and VoxelGI bounce light baked at runtime.

## Considered options
- **Three.js / web.** Rejected. Web UI is easiest for dashboards and the stack is the most AI-friendly, but the hard scenes stuttered, and features Godot ships built in had to be assembled by hand.
- **Unity, Unreal.** Rejected without a prototype. Both are editor-centric with binary or GUID-linked assets, which is hard for an AI to build and verify alone. Unreal also has slow C++ builds and royalty terms.

## Consequences
- The simulation core's language is settled as **C#**. Game code that only presents data may use C# or GDScript. Simulation logic lives only in the core library.
- Charts in the dashboard are custom-drawn Control nodes, about 1.5–2× the effort of a web chart library. Tables and layout cost about the same as on the web.
- LightmapGI can only be baked in the editor. Use VoxelGI or SDFGI (both work from the CLI), or bake light in Blender.
- Verification runs Godot from the CLI: screenshots from fixed camera shots, a scripted smoke test and a perf mode. Capture runs open a window on the owner's desktop.
