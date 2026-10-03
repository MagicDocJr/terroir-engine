# Famous vintages

How the famous-vintage scenarios work, what each medal judges, how the goals were tuned, and what is simplified. Design:
`docs/superpowers/specs/2026-10-03-famous-vintages-design.md`. Data: `data/scenarios.json`. Code:
`sim/src/TerroirEngine.Core/Game/Scenarios.cs`.

## 1. What a scenario is

- **A normal game.**
  - The scenario's Plot is planted three years before the vintage, with the default planting on every Block. The game
    therefore opens on 15 January of the vintage with established vines (the establishment years are simulated first).
  - The weather is the Region's archived weather for that year (ADR 0002).
  - The setup carries the scenario id, so saves replay it.
- **No future knowledge.**
  - The briefing gives only what a grower knew in January: the place, the vines and the goals.
  - A validator rejects briefings and teasers that name weather events, months or dates.
  - The debrief reveals the year.
- **Medals:**
  - Bronze, silver and gold; each medal needs the ones below it.
  - Judged by the sim on the best bottled Wine of the scenario's grape labelled with the scenario vintage. Other grapes
    and later Vintages never count.
  - Medals reward winemaking outcomes, never profit.

## 2. The scenarios and their goals (final values, 2026-10-03)

| Scenario | Bronze | Silver | Gold | The lesson |
|---|---|---|---|---|
| Côte d'Or 2016, Pinot Noir | Village AOC | no fault, Good or better | Very good or better | A frost-thinned, cool year still gives concentrated reds with a riper pick and fuller extraction [INSIDEBURGUNDY-2016] |
| Mosel 2018, Riesling | a Prädikat Wine | Kabinett with acidity medium(+) or higher | balanced, Good or better | In a hot year most wines came out ripe and soft; racy Kabinett took an early pick [MFW-2018] |
| Napa 2011, Cabernet Sauvignon | Napa Valley AVA | no rot taint, ripe seeds, balanced | at most 15.0 % vol | Flavours came at lower sugar that year, giving lower-alcohol wines [NVV-2011] |

Sources and the "what growers did" lines: `vintage-notes.md`, section "What growers did".

## 3. Tuning (how the thresholds were set)

The goals were tuned with the scripted player `Scenarios.Autoplay`. It harvests at a target must weight, sets cellar choices
on each new Lot, and bottles each Lot. `ScenarioBalanceTests` pins the results:

| Scenario | Default play (region's default pick, default cellar) | The year's right calls |
|---|---|---|
| Côte d'Or 2016 | bronze (Pinot Acceptable) | gold: pick at 100 °Oe, malolactic, punch-down, extended maceration, 30 °C, new oak, 10 months (one Very good Pinot) |
| Mosel 2018 | bronze (picked at Spätlese weight) | silver: pick at 75 °Oe (a true Kabinett); gold: stop the ferment at about 35 g/L |
| Napa 2011 | silver (ripe and balanced, but 15.2 % vol) | gold: pick at 103 °Oe with first-fill rather than new oak (14.7 % vol, balanced) |

The tuning changed only the scenario data, never the simulation.

Findings that shaped the goals:
- **No natural-sugar goal in the Côte d'Or.** Every simulated 2016 Pinot clears 189 g/L natural sugar, so it tests
  nothing. The research also shows growers chaptalised a little that year to keep the acid balance, so "no chaptalisation"
  would teach the wrong lesson.
- **Mosel gold is "Good", not "Very good".** Riesling's finish barely varies in the model (Tasting sheet 2 backlog).
- **Napa default reaches silver.** In the simulation, a Good Napa 2011 Wine under 15 % with balance is not reachable,
  because its intensity comes mostly from new oak. Gold therefore rewards the earlier pick and gentler oak.

## 4. Game simplifications

- The scenario Estate starts in the vintage year with vines planted three years earlier; there is no older vineyard.
- Frost protection (candles, wind machines) is not a player action, so the 2016 frost cannot be fought in the game. The
  debrief notes that real candles did not stop it [DECANTER-2016].
- Napa 2011's shatter and autumn botrytis are not reproduced: the simulated crop is near normal and nearly rot-free.
- Medals are judged at bottling; there is no live verdict before the Wine exists.
