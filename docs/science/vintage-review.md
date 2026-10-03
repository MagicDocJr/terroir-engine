# Vintage in review

The season replay and the cause cards at the top of the Vintage report. Design:
`docs/superpowers/specs/2026-10-03-vintage-in-review-design.md`. Code: `sim/src/TerroirEngine.Core/Game/VintageReview.cs`,
`game/src/ui/review_strip.gd`, `game/src/ui/screens/report.gd`.

## What it shows

- **The season strip.** The Vintage's weekly mean temperature (Block A microclimate) against the 1991–2020 normal, from
  March to November.
  - Phenology markers come from the best Wine's main Block: budburst, flowering, véraison, harvest.
  - Numbered pins mark the cause cards.
  - A 6-second sweep runs the first time the review is shown, with skip and replay.
- **Cause cards (at most 8).**
  - Each card is a moment of the year, with one or more Causes tagged on the Vintage's Wines (`TastingSheet.CauseLinks`).
  - Each card shows what happened, in numbers from the simulation, and the Tasting-sheet lines it shaped, with each
    line's own "because".
  - Order: faults, then season events, the harvest, cellar choices, the rest; chronological within each.
  - Cards come from the best Wine, plus season events and faults on the Vintage's other Wines.
- **Review queue.** The first showing enqueues the cards' Causes with no answer counted (the same rule as learn-card
  checks and scenario debriefs).

## Moments and their evidence

| Moment | Causes | Evidence |
|---|---|---|
| The frost night | spring-frost-yield | the coldest night after budburst up to 20 May at the best Wine's Block; shoots killed per Block; yield |
| The season's warmth | cool-season-acid, warm-season-malic-loss | the picked Block's April–September mean (the measure that tags the Cause: cool below 15.5 °C, warm above 18 °C), with the Region's April–October mean against the 1991–2020 normal for context; TA and pH at picking |
| The hottest day | sunburn-cooked | the highest maximum between véraison and harvest; sunburned berries; leaf removal |
| Sun and shade on the bunches | sun-exposure-tdn, pyrazines-shade-cool | leaf removal side and timing, canopy programme, IBMP at harvest |
| Rain before the harvest | noble-rot, grey-rot-taint | rain at the Block (its climate adjustment, as the rot model sees it) in the three weeks before picking; rot % |
| The harvest | ripeness-fruit-character, sugar-to-alcohol, seed-ripeness-tannin, yield-concentration, riesling-terpenes | date, °Oe, TA, pH, seed ripeness, yield, alcohol |
| Each cellar choice | MLF, barrels, lees, whole bunch, stopping, chaptalisation, acidification, temperature, extraction, skin contact | the Lot's choice and its measured result (malic and lactic, sugar left, added % vol) |
| Faults | volatile-acidity, brett, oxidation, molecular-so2-ph, low-yan-h2s | the fault and its measured value |

## Rules and simplifications

- **Descriptive, never a verdict:** a test bans verdict words in card text. Suggestions stay in the report's "Next
  time" panel.
- **Only state up to the bottling is read** (ADR 0002). The review is computed, not stored, so old saves show it too.
- **The frost night** is a game presentation choice: the season record keeps the shoot loss, not the night, so the card
  names the coldest night after budburst at the best Wine's Block.
- **Decisions that left no tagged Cause get no card**, by design: every card must link to a sheet line, and a card with no evidence is dropped.
- **Wines of the Vintage** are those whose largest component is a Lot of that Vintage, so a topped-up non-vintage Wine still gets its review.
- **Fault cards** show the Cause's own fault entry; low molecular SO₂ shows its measured value.
- **Known simplifications:** the cellar card dates are the harvest plus one day (fermentation) or the bottling (barrels, lees), not the exact day of malolactic conversion; each Cause shows the first sheet line it is tagged on.
