# Probes

Single-file C# apps for exploring the simulation from the command line (.NET 10 file-based apps). Each runs the real sim
core and prints plain text, for an AI or a person to read. They are the tools that found the oak bug, tuned the scenario
medals and checked which famous vintages the sim reproduces. Keep useful ones here instead of throwing them away.

| Probe | What it answers | Example |
|---|---|---|
| `quality-spread.cs` | How do quality verdicts spread over random pours, per grape, and why? | `dotnet run tools/probes/quality-spread.cs 150` |
| `scenario-grid.cs` | Which picking target and cellar choices earn which medal in a famous vintage? | `dotnet run tools/probes/scenario-grid.cs napa-2011 100,103,106 '{"Vessel":3}'` |
| `review-cards.cs` | What cause cards does a Vintage in review show? | `dotnet run tools/probes/review-cards.cs cotedor-2016 94` |
| `vintage-check.cs` | Does the sim reproduce a real year (frost, harvest, yield, rot)? | `dotnet run tools/probes/vintage-check.cs cotedor-village:2016:Pinot_Noir:classic` |

**Writing a new one:**
- Copy the three `#:` header lines and the `GameData` line, which finds `data/` relative to the probe.
- Print one line per case.
- The first run compiles the sim core (about 20 s); later runs are faster.
