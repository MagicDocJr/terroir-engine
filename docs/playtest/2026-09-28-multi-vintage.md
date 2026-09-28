# Multi-vintage play — playtest report (2026-09-28)

Spec: `docs/superpowers/specs/2026-09-28-multi-vintage-design.md` · Plan: `docs/superpowers/plans/2026-09-28-multi-vintage.md` · Branch: `feat/multi-vintage`

## What changed for the player

- **The game goes on.** After the first Vintage is bottled, the Mentor retires and the clock keeps running: the vines grow into the next Vintage, costs recur, and alerts fire again each year. There is no end screen.
- **15 January, every later Vintage:** the Vineyard manager's "Vintage {year} begins" message reports vine age, a bud-dissection estimate of this year's bunches, the vines' stored reserves and any extra mildew pressure, then asks for the pruning decision (`game/shots/mosel_17_newseason.png`).
- **The vines remember.** Warm, bright flowering gives more bunches next year (±15 %); a big crop, a late harvest or early leaf loss runs down the reserves and weakens the next spring; a bad mildew year raises next spring's inoculum. All neutral in the first Vintage.
- **Your staff take over the Mentor's seasonal advice** after the first Vintage. A Junior gives the same correct advice without the explanation.
- **Vintage history** on the Estate screen: heat and rain against the normal, budburst and harvest dates, yield, wines and sales per Vintage, plus money by calendar year (`mosel_18_history.png`).
- **Vintage report per Vintage**, opened automatically once, with a selector for earlier years (`mosel_19_report_selector.png`).
- **Lots grouped by Vintage** in the Winery and Blending screens; blending across Vintages shows the Vintage shares.
- **Labels carry the year.** A blend with too little of one year is sold as **Non-vintage** (EU ≥ 85 %, Napa AVA ≥ 95 %).
- **Overdraft interest:** 9 % a year, charged monthly (a labelled design value).

## Verification

- 52 simulation tests pass (25 existing unchanged apart from the "first Vintage bottled" loop condition, 27 new). Highlights: three Vintages back to back in each Region; save → load two Vintages in reproduces the snapshot byte for byte; a hard first year (High bud load, Low spraying) gives lower reserves and fewer berries the next year than a careful one on the same weather; vintage statement thresholds; monthly overdraft interest.
- UI: the click-every-button check runs five rounds through the second Vintage's harvest with no script errors; the scripted capture plays two full Vintages and the save/load round trip matches.
- Replay: a 5-Vintage save loads in **280 ms**, a 10-Vintage save in **569 ms** (budget 10 s). Snapshot: **203 KB** at 5 Vintages, **330 KB** at 10 (about +30 KB per Vintage).
- Screen build times unchanged (inbox 28 ms, plot 67 ms, cached tab switch 9 ms).

## Ten-Vintage calibration (2011–2020, Medium tiers, scripted harvest)

| Plot | Mean yield (hL/ha) | Year-to-year CV |
|---|---|---|
| Mosel Seitental | 72 | 20 % |
| Mosel Blauschiefer | 67 | 13 % |
| Côte d'Or Village | 53 | 19 % |
| Côte d'Or Premier Cru | 52 | 18 % |
| Napa Rutherford Bench | 84 | 4 % |
| Napa Carneros | 69 | 7 % |

Low years have weather causes (Mosel 2017 spring frost, Côte d'Or 2020 heat and drought). Irrigated Napa varies least, as expected.

## Findings for the science review

1. **Mature Côte d'Or yields sit above the AOC limits in generous years.** From the 5th leaf the Côte d'Or Blocks average ≈ 53 hL/ha and reach 63–65 hL/ha in some years, above the Premier Cru (56) and Bourgogne/Village (58) limits, so a player who never green-harvests gets Vin de France (seen for 2016–2017 in a 4-Vintage Premier Cru run). The yield alert at véraison offers the green harvest, so the lever exists, but `canopy-and-yield.md` §7 expects 35–50 hL/ha. The single-Vintage game hid this behind the 4th-leaf crop factor. Not caused by the carry-over; needs a calibration decision (clusters per shoot, set, or bud numbers for Burgundy Guyot).
2. **Burgundy 2016 frost is not reproduced on the mid-slope Plots** (the 27 April 2016 frost cut real Côte de Beaune yields hard; the model gives 64 hL/ha). The existing frost test covers the 2021 frost pocket only.
3. The carry-over coefficients are `UNVERIFIED` design values, bounded (fruitfulness 0.85–1.15, reserves 0.70–1.05, inoculum 0.85–1.30). The directions are cited and web-verified (Buttrose 1969; Bennett et al. 2005; Holzapfel et al. 2010; Gadoury & Pearson 1990; Rossi et al. 2008).

## Known limits (labelled in-game)

- Wine is still sold the moment it is bottled; no stock, markets or loans.
- Soil water refills every winter.
- No replanting, top-grafting or phylloxera yet.

## Three things to try

1. Put one Block on **High** bud load and skip the green harvest in a warm year, then read the next 15 January message and compare that Block's crop with the others.
2. In Napa, keep a Lot unbottled until the next Vintage's Lot is ready, blend them 50/50, and see the label turn **Non-vintage**.
3. Plant in 2020 and play past 2025 into Synthetic weather: the Vintage history shows how the warming trend moves harvest dates.
