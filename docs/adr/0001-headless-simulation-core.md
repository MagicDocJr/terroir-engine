# Simulation core is a headless library with no engine dependency

All viticulture, oenology, weather and economy logic lives in one pure, deterministic library. It has no rendering, UI or engine imports and is tested from the command line. Most of the project's value and risk sits in the science, and Claude has to verify it without human eyes. A headless core can be tested exhaustively and replayed from a save file's decision log. It also lets us choose (or later swap) the 3D engine without rewriting the simulation.

## Consequences
- The 3D view and the dashboard only ever *read* simulation state and *send* player decisions. Neither computes any outcome.
- The core's language must be one that the chosen front-end can call. It is fixed together with the engine choice after the demo (milestone 0).
