# Phenology: budburst, flowering, véraison, sugar ripeness, frost damage by stage

Science pass, part 1. Status: **draft for review**. Every number has a source or is marked `UNVERIFIED`. Game simplifications are labelled.

## 1. Purpose in the game

Phenology sets **when** everything happens on each Block:
- the Alerts that stop time (frost risk after budburst, flowering, véraison, harvest window)
- the window for each Programme (e.g. canopy work between flowering and véraison)
- how far the fruit gets before autumn

It is also the mechanism behind "any grape anywhere" (section 7). A Variety that needs more heat than the Plot gives reaches its stages late and never gets ripe.

## 2. Stages

Stages are named on the modified Eichhorn-Lorenz (E-L) system (Coombe 1995):

| Game stage | E-L | Definition used by the game |
|---|---|---|
| Dormant | 1 | Winter bud |
| Budburst | 4 | Green tip visible; the model's "budburst date" is when 50% of buds reach it |
| Leaves unfolding | 7–12 | First leaves through 5 separated leaves |
| Flowering | 23 | 50% of caps off (full bloom) |
| Fruit set | 27 | Berries set |
| Bunch closure | 32 | Berries touching |
| Véraison | 35 | Berries begin to colour and soften (50%) |
| Harvest ripe | 38 | The player's picking date; not a model output |

## 3. Budburst: chilling + forcing (BRIN)

Budburst uses the **BRIN** model (García de Cortázar-Atauri et al. 2009), a sequential chilling-forcing model. It chains Bidabe's cold-action model (endodormancy) with Richardson's growing-degree model (ecodormancy).

1. **Chilling (endodormancy release).** Chill units accumulate daily from t0_chill until the requirement C_c is met:
   ```
   CU_day = Q10^(−Tmax/10) + Q10^(−Tmin/10)          (Bidabe's action, as used in BRIN)
   ```
   Costafreda-Aumedes et al. (2025) start chilling models on DOY 244 (1 September) of the previous year.
2. **Forcing (ecodormancy).** After C_c is met, forcing units accumulate. They are degree-days (or hours) between a lower and an upper cardinal temperature (Richardson). Budburst happens when the sum reaches G_hc.

| Parameter | Meaning | Value | Status |
|---|---|---|---|
| t0_chill | Start of chilling | 1 Sep, previous year | Costafreda-Aumedes et al. 2025 |
| Q10 | Temperature response of chilling | 2.17 | UNVERIFIED (recalled from García de Cortázar-Atauri 2009) |
| C_c | Chilling requirement per Variety | — | UNVERIFIED |
| T_low | Lower forcing threshold | 5 °C | UNVERIFIED (García de Cortázar-Atauri et al. 2009 report the base temperature as the main driver; 5 °C is also their GDD comparison base) |
| T_high | Upper forcing threshold | 25 °C | UNVERIFIED |
| G_hc | Forcing requirement per Variety | — | UNVERIFIED |

**Relative earliness** (Costafreda-Aumedes et al. 2025): **Chardonnay** is among the earlier ("warm-adapted") varieties for budbreak; **Riesling and Cabernet Sauvignon** are among the later ("cold-adapted") ones. Pinot noir is early (`UNVERIFIED`, no source fetched). An early budburst means more exposure to spring frost. This is the Chardonnay-in-Chablis or Côte d'Or frost lesson.

**Calibration approach** (the variety parameters aren't in the open sources I could reach):
fix Q10, T_low and T_high; fit C_c and G_hc per Variety so that simulated mean budburst dates (1991–2020, Block-adjusted Historical weather) fall inside these windows:

| Region / Variety | Target mean budburst (1991–2020) | Status |
|---|---|---|
| Mosel, Riesling | mid to late April | UNVERIFIED |
| Côte d'Or, Chardonnay / Pinot noir | early to mid April | UNVERIFIED |
| Napa (Oakville), Cabernet Sauvignon | late March to early April | UNVERIFIED |

Fallback, labelled Game simplification: if BRIN proves unstable in warm Synthetic weather (Costafreda-Aumedes et al. 2025 report that chilling-forcing models can fail to reach budburst under high temperatures), use a pure forcing model: GDD above 5 °C from 1 January to a per-Variety F*.

## 4. Flowering and véraison: GFV

The **Grapevine Flowering Véraison model** (Parker et al. 2011) is a spring-warming model:

```
S(t) = Σ_{DOY=t0}^{t} max(0, Tmean − Tb)       with t0 = DOY 60 (1 March, Northern Hemisphere), Tb = 0 °C
stage reached when S(t) ≥ F*
```

Per-variety F* (°C·day) from Parker et al. (2013), fitted on the French and European phenology database:

| Variety | Flowering F* | Véraison F* | Flowering RMSE (days) | Véraison RMSE (days) | Source |
|---|---|---|---|---|---|
| Chardonnay | 1217 | 2547 | 4.9 | 6.5 | Parker et al. 2013, Tables 1–2 |
| Pinot noir | 1219 | 2511 | 5.1 | 7.8 | Parker et al. 2013, Tables 1–2 |
| Riesling | 1249 | 2590 | 5.9 | 6.8 | Parker et al. 2013, Tables 1–2 |
| Cabernet Sauvignon | 1299 | 2689 | 5.2 | 6.9 | Parker et al. 2013, Tables 1–2 |

Southern Hemisphere is not needed for the MVP; Napa is Northern Hemisphere.

## 5. Sugar ripeness: GSR

The **Grapevine Sugar Ripeness model** (Parker et al. 2020) uses the same structure. It characterises the thermal time to six target sugar concentrations (**170, 180, 190, 200, 210 and 220 g/L**) for 65 cultivars, summing Tmean above **0 °C from DOY 91 (1 April)** in the Northern Hemisphere (as described in Parker et al. 2020b). Prediction errors are within about 7–10 days for new datasets (Parker et al. 2020b).

**The per-variety F* for each sugar target is behind a paywall and `UNVERIFIED`.** Planned calibration: fit F*₂₀₀ per Variety so the simulation on Historical weather reproduces known harvest timing:
- **Côte d'Or:** in Beaune, picking started on average from 28 September over 1354–1987, and about **13 days earlier over 1988–2018** (Labbé et al. 2019). Target: Pinot noir / Chardonnay reach ~200 g/L around mid-September in 1988–2018.
- **Mosel Riesling:** traditionally picked in October (`UNVERIFIED`). Target: 190–200 g/L around early to mid October in 1991–2020.
- **Napa Cabernet Sauvignon:** reaches 220 g/L+ from late September (`UNVERIFIED`).

Interface to the ripening model: phenology exposes the GSR thermal sum `S_GSR(t)`. The ripening model (other doc) turns it into a daily sugar concentration, and adds dilution by rain and concentration by water stress (Game simplification: thermal time drives mean sugar; water and crop load modify it).

## 6. Frost damage by stage

Radiation frosts in spring kill young green tissue. Critical temperatures fall towards 0 °C as the shoot develops.

University of Maryland Extension (Grapevine Frost/Freeze Damage I):

| Stage | Critical temperature |
|---|---|
| Dormant bud | < 20 °F (< −6.7 °C) |
| Dormant swollen | 26 °F (−3.3 °C) |
| Burst bud | 28 °F (−2.2 °C) |
| One leaf unfolded | 28–29 °F (−2.2 to −1.7 °C) |
| Two leaves unfolded | 29–32 °F (−1.7 to 0 °C) |

Pinot noir LT50 (the temperature that kills 50% of tissue), as reported by Growing Produce citing Gardea (1987): green swollen buds 26 °F (−3.3 °C), budburst 28 °F (−2.2 °C), two-leaf 29 °F (−1.7 °C), four-leaf 30 °F (−1.1 °C). The original Gardea (1987) source was not fetched (`UNVERIFIED` via secondary).

Game model:

```
damage_fraction = clamp((T_crit(stage) + 1.0 − T_min_block) / 2.0, 0, 1)     # linear from 0% (1 °C above T_crit) to 100% (1 °C below). UNVERIFIED shape
```

- T_min_block is the Block's night minimum, including frost-pocket cooling on clear, calm nights (see `weather-and-climate.md`).
- Killed primary shoots are partly replaced by secondary buds, with lower fruitfulness: the game assumes 30–50% of normal crop on damaged shoots (`UNVERIFIED`). Replacement shoots are ~10 days behind (`UNVERIFIED`).
- **Frost protection** (the frost Programme is off or on; on, it uses the best equipment the Estate owns from the Shop; `VineyardModel.FrostProtection`). It acts on nights forecast within 2 °C of T_crit:
  - **Candles** (owned from the start): about 400–500 per ha lift the vine-level minimum by **+2.2 °C** on radiation nights (375 heaters/ha gave +2.2 °C at 1.1 m, Parsons et al. 1967 in [FAO-2005] ch. 7; +2–3 °C at 400–500/ha, [REUSSIR-GEL-2023]). Not on windy nights. They fail in severe frosts (Rully 2021, −3 to −6 °C with snow: [DECANTER-2021]).
  - **Wind machine:** gain = **⅓ of the inversion** (≈ 30 % of the 2–10 m inversion, [FAO-2005] ch. 2; ⅓–½, [OMAFA-FANS]). It is useless above about 2.5 m/s wind and in advective frost ([FAO-2005]). **Game simplifications:** the weather data has no upper-air temperature, so the inversion is 1.5 °C plus up to 3 °C more on clear, still nights (`UNVERIFIED` range; FAO advises a fan only where frost-night inversions are usually ≥ 1.5 °C); the data has only the daily mean wind, which overstates night wind, so the fan runs on every radiation night (daily mean below 11 km/h) with a weaker inversion as that wind rises. When the fan alone leaves the buds within 1.5 °C of T_crit, the crew lights candles too and the gains add (`UNVERIFIED`; FAO notes heaters and fans together beat either alone). It is not offered on slopes of 30 % or more (cold air drains off steep slopes; terrain decides placement, [OMAFA-FANS]; Beine judged fans unsuitable for its terrain, [REUSSIR-BEINE-2021]; the 30 % line is `UNVERIFIED`).
  - **Overhead sprinklers:** water freezing on the shoots releases 334.5 kJ/kg, holding the buds near **0 °C** as long as ice keeps forming ([FAO-2005] ch. 7). They protect down to about **−6 °C** air in any frost type, radiative or advective ([FAO-2005]: to about −7 °C; −6 °C, [REUSSIR-GEL-2023]; −7 °C, IFV via [LARVF-2021]). Below −6 °C the game lets the protection give way degree for degree (`UNVERIFIED`; FAO warns a failing or under-rated system does more harm than none, not modelled). Under sprinklers the wet-bud rule below does not apply (the ice-water coat is the protection). Not offered on the steep Mosel slate (no water supply; `UNVERIFIED`). Water limits (Beine's reservoir holds about 100 hours a season, [REUSSIR-BEINE-2021]) are not modelled.
- **Wet young buds** (≥ 1 mm of rain the day before) freeze 1 °C warmer during the first 14 days after budburst: `T_crit += 1.0`. Young buds survive light frosts by supercooling (dry shoots at budburst resisted frosts above about −3 °C, and −3 to −3.5 °C killed about 60 %: Fuller & Telli 1999); ice forming on surface water ends that supercooling (standard frost physics, FAO *Frost protection* manual, Snyder & de Melo-Abreu 2005, cited from memory). Older, water-rich shoots have little supercooling left to lose, so the rule stops after 14 days. Size `UNVERIFIED`.
- **Validation, 27 April 2016:** rain on the 26th froze on the young shoots at about −4 °C in places; the Côte d'Or lost about half its crop, including well-exposed mid-slope sites (BBR 2016 Burgundy vintage report; Jasper Morris, *Inside Burgundy* 2016 overview). ERA5 gives only −0.5 °C at grid level, and without the wet-bud rule the model left the mid-slope untouched; with it the mid-slope Village Plot loses ≈ 54 % of its shoots (test `Burgundy2016_AprilFrost_AfterRain_HitsTheMidSlopeToo`). 2017 (frost four weeks after an early budburst, largely fought off with fires in the Côte d'Or) stays a generous Vintage.
- The Côte d'Or April 2021 frost Vintage is the calibration case: widespread damage after an early, warm March–April budburst (`UNVERIFIED` description, to be checked by the regions/vintage-notes work).

## 7. "Any grape anywhere": how the wrong Variety fails

The game never blocks a Variety. It lets the season run out.

1. **Late stages.** With too little heat, GFV véraison slips into September and GSR sugar targets move past the end of the season.
2. **End of season.** Ripening stops at the earlier of (a) the first autumn frost (T_min_block ≤ −2 °C after véraison) and (b) 31 October (Game simplification, `UNVERIFIED` cut-off). Fruit keeps whatever sugar it reached, with high acidity and green (pyrazine) character (ripening model).
3. **Heat indices as a sanity check.** Huglin's minimum heat for each variety (`weather-and-climate.md`): Riesling, Chardonnay and Pinot noir ~1700; Cabernet Sauvignon ~1900–2000. The Jones (2010) growing-season-temperature niches (Pinot noir 14.0–16.0 °C, Cabernet Sauvignon 16.8–20.2 °C) tell the same story.

Worked expectation (see Calibration): at Bernkastel, Cabernet Sauvignon's GFV véraison lands 8–10 days after Riesling's on average, and in cool years not until October. Its sugar target can't be reached in most years, so "Cabernet on the Mosel" gives thin, green, acidic wine at low must weight. The Mentor warns about this at Planting.

## 8. Per-Variety parameter summary

| Variety | Budburst timing | GFV flowering F* | GFV véraison F* | GSR F*₂₀₀ | Huglin minimum (Huglin table) | GST niche (Jones 2010) |
|---|---|---|---|---|---|---|
| Riesling | Later (Costafreda-Aumedes 2025) | 1249 | 2590 | UNVERIFIED | 1700–1800 | UNVERIFIED (not in the text I could read) |
| Chardonnay | Earlier (Costafreda-Aumedes 2025) | 1217 | 2547 | UNVERIFIED | 1700–1800 | UNVERIFIED |
| Pinot noir | Early (UNVERIFIED) | 1219 | 2511 | UNVERIFIED | 1700–1800 | 14.0–16.0 °C |
| Cabernet Sauvignon | Later (Costafreda-Aumedes 2025) | 1299 | 2689 | UNVERIFIED | 1900–2000 | 16.8–20.2 °C |

Rootstock phenology shifts are in `soil-and-water.md` §7.

## 9. Calibration

See `docs/science/data/climate_indices.json`, produced by `tools/science/climate_indices.py`. GFV is applied to NASA POWER (MERRA-2) **grid-cell** temperatures, without the Block adjustments of `weather-and-climate.md` §3. Grid-cell elevations: Bernkastel 387 m, Beaune 283 m, Oakville 266 m.

| Site | Period | Variety | GFV flowering (mean date, DOY range) | GFV véraison (mean date, DOY range) |
|---|---|---|---|---|
| Bernkastel (Mosel) | 1981-2000 | Chardonnay | 06 Jul (176–203) | 27 Sep (256–303) |
| Bernkastel (Mosel) | 1981-2000 | Pinot noir | 07 Jul (177–203) | 24 Sep (253–299) |
| Bernkastel (Mosel) | 1981-2000 | Riesling | 08 Jul (179–205) | 01 Oct (258–310) |
| Bernkastel (Mosel) | 1981-2000 | Cabernet Sauvignon | 11 Jul (183–208) | 11 Oct (264–330) |
| Bernkastel (Mosel) | 2001-2020 | Chardonnay | 29 Jun (170–195) | 14 Sep (235–278) |
| Bernkastel (Mosel) | 2001-2020 | Pinot noir | 29 Jun (170–195) | 11 Sep (233–274) |
| Bernkastel (Mosel) | 2001-2020 | Riesling | 01 Jul (172–197) | 17 Sep (237–281) |
| Bernkastel (Mosel) | 2001-2020 | Cabernet Sauvignon | 04 Jul (175–200) | 25 Sep (244–293) |
| Beaune (Côte d'Or) | 1981-2000 | Chardonnay | 23 Jun (168–188) | 01 Sep (232–263) |
| Beaune (Côte d'Or) | 1981-2000 | Pinot noir | 23 Jun (168–188) | 30 Aug (231–260) |
| Beaune (Côte d'Or) | 1981-2000 | Riesling | 25 Jun (170–190) | 04 Sep (235–267) |
| Beaune (Côte d'Or) | 1981-2000 | Cabernet Sauvignon | 28 Jun (172–192) | 10 Sep (239–275) |
| Beaune (Côte d'Or) | 2001-2020 | Chardonnay | 18 Jun (160–182) | 23 Aug (218–252) |
| Beaune (Côte d'Or) | 2001-2020 | Pinot noir | 18 Jun (160–182) | 21 Aug (217–249) |
| Beaune (Côte d'Or) | 2001-2020 | Riesling | 19 Jun (162–184) | 26 Aug (220–255) |
| Beaune (Côte d'Or) | 2001-2020 | Cabernet Sauvignon | 22 Jun (164–187) | 31 Aug (223–262) |
| Oakville (Napa) | 1981-2000 | Chardonnay | 05 Jun (147–166) | 05 Aug (208–228) |
| Oakville (Napa) | 1981-2000 | Pinot noir | 05 Jun (147–166) | 04 Aug (206–227) |
| Oakville (Napa) | 1981-2000 | Riesling | 07 Jun (148–167) | 07 Aug (210–231) |
| Oakville (Napa) | 1981-2000 | Cabernet Sauvignon | 09 Jun (150–170) | 12 Aug (214–235) |
| Oakville (Napa) | 2001-2020 | Chardonnay | 04 Jun (146–168) | 05 Aug (208–234) |
| Oakville (Napa) | 2001-2020 | Pinot noir | 04 Jun (146–168) | 03 Aug (207–232) |
| Oakville (Napa) | 2001-2020 | Riesling | 05 Jun (148–170) | 07 Aug (210–236) |
| Oakville (Napa) | 2001-2020 | Cabernet Sauvignon | 08 Jun (150–172) | 11 Aug (213–240) |

What the table shows:
- **Ordering is right everywhere:** Pinot noir ≤ Chardonnay < Riesling < Cabernet Sauvignon, as in Parker et al. (2013).
- **Warming is visible:** Beaune véraison moves about 9 days earlier and Bernkastel about 13–16 days earlier between the two periods, in the same direction and of similar size to the harvest advance in Labbé et al. (2019).
- **The raw Mosel grid cell is too cold.** GFV Riesling véraison on 17 September (2001–2020) is far too late for a Mosel slope. Riesling véraison there is usually in August (`UNVERIFIED` exact timing). This is the same bias as in `weather-and-climate.md` §5.1: the cell is at 387 m, not on a 150 m south slope. **Acceptance check:** with Block adjustments applied (lapse rate plus slope heat), the Mosel steep-south Block must place Riesling véraison in the second half of August (1991–2020 mean) (`UNVERIFIED` target, to be confirmed by review).

**GSR thermal sums at fixed dates** (Tmean above 0 °C from 1 April, grid cells) give provisional starting values for the per-Variety sugar F*:

| Site | Period | Thermal sum at 15 Sep | at 1 Oct | at 15 Oct |
|---|---|---|---|---|
| Bernkastel (Mosel) | 1981-2000 | 2294 (2063–2469) | 2495 (2232–2700) | 2634 (2370–2825) |
| Bernkastel (Mosel) | 2001-2020 | 2464 (2296–2842) | 2663 (2468–3052) | 2806 (2607–3235) |
| Beaune (Côte d'Or) | 1981-2000 | 2621 (2396–2791) | 2858 (2595–3033) | 3025 (2742–3226) |
| Beaune (Côte d'Or) | 2001-2020 | 2783 (2527–3201) | 3014 (2768–3465) | 3191 (2939–3633) |
| Oakville (Napa) | 1981-2000 | 3159 (2930–3402) | 3476 (3236–3701) | 3723 (3475–3942) |
| Oakville (Napa) | 2001-2020 | 3151 (2822–3420) | 3474 (3163–3778) | 3723 (3400–4074) |

**Provisional GSR F*₂₀₀ (derived here, not published; `UNVERIFIED`):**
- **Pinot noir / Chardonnay ≈ 2750.** Beaune's recent harvests start around mid-September (Labbé et al. 2019), and the 15 September thermal sum there averages ~2780 in 2001–2020.
- **Game calibration (28 Sep 2026, `UNVERIFIED`):** with the game's sugar-loading curve (ripening.md §3) and Block climate, the model reached 200 g/L on 19 Sep (Pinot noir) and 24 Sep (Chardonnay) on average over 1990–2018 at the Village Plot, against the sourced mid-September (Labbé et al. 2019). The model's F*₂₀₀ is now **2645 (Pinot noir)** and **2615 (Chardonnay)**, which gives a 15 Sep mean for both. Known limit: the model spreads the years too little. Very hot years are still late (2003: 5 Sep simulated against a 19 August start of harvest) and some cool years are early. GFV flowering on this grid averages 15–16 June, about a week later than the 100-day rule implies; the published Parker F* values are kept unchanged.
- **Diagnosis of the compressed spread (28 Sep 2026, `sim ripecheck cotedor-village`):** the model's 200 g/L dates span DOY 243–271 (SD 7.3 days) over 1990–2020. Two causes, both measured:
  1. *Phenology responds too weakly to warm springs.* Observers at Beaune recorded flowering 25 days apart between 1991 and 2003 (Changement climatique : impacts sur la phénologie du Pinot noir en Bourgogne, ResearchGate 280891472); the model's GFV gives 22 June and 8 June, only 14 days apart. With véraison on 4 August in 2003 (observed around 20–25 July, `UNVERIFIED`), the model's 31 days from véraison to 200 g/L end on 4 September.
  2. *The drought brake.* After véraison the severe-stress factor slows sugar loading by 28 % on average in 2003 and 2018 and 19 % in 2020, exactly the hot, dry years that should be earliest; the heat brake above 35 °C is small (3 % in 2003).
  - Ruled out: a cold grid (the Village Blocks' Winkler 1338–1350 is at or above the Beaune table in `weather-and-climate.md`); the daily-mean definition ((Tn+Tx)/2 − 24 h mean = −0.06 °C on the Côte d'Or grid); stress-limited berry swelling after véraison (Ojeda et al. 2001 find post-véraison deficit has little effect on berry size, so it was not added).
  - Needed to fix it properly: a yearly series of observed Pinot noir flowering and véraison dates for the Côte de Beaune (Chambre d'agriculture / BIVB network, or the paper above) to fit the phenology model, and field Ψstem data for 2003 to check the severity of the drought brake.
- **Riesling ≈ 2900.** On a Block-adjusted Mosel slope (about +250 °C·day by 1 October from the lapse-rate correction alone), 200 g/L then falls in early October, matching the traditional October Mosel harvest (`UNVERIFIED`).
- **Cabernet Sauvignon ≈ 3100.** In Oakville that gives 200 g/L around mid-September, leaving time to reach the 230–250 g/L typical of Napa picking (`UNVERIFIED`).

Replace these with Parker et al. (2020) Table 2 values when obtained.

Acceptance checks:
- **GFV's own error:** RMSE of about 5–8 days in the calibration data (Parker et al. 2013), so ±1 week is the tolerance.
- **Côte d'Or:** 1988–2018 is about 13 days earlier than the long-term mean (Labbé et al. 2019). The simulated ripeness date should show an advance of similar size between 1981–2000 and 2001–2020 (GFV véraison at Beaune advances ~9 days on the grid data).
- **Ordering:** Pinot noir ≤ Chardonnay < Riesling < Cabernet Sauvignon for véraison at every site.

## 10. Game simplifications

1. One mean date per stage per Block. Real bud populations spread over days.
2. GSR thermal time sets the mean sugar trajectory; crop load and water status only modify it.
3. Ripening stops on 31 October or at the first hard autumn frost.
4. Secondary-bud crop after frost is a fixed fraction.

## 11. Open questions

- Obtain GSR F* values (Parker et al. 2020, Table 2) and BRIN per-variety parameters (García de Cortázar-Atauri et al. 2009, or supplementary tables), or fit them against observed dates.
- Get observed budburst dates for Moselle Riesling (the Luxembourg series 1971–2018 used by Costafreda-Aumedes et al. 2025) and for Napa.

## Sources

- Fuller MP, Telli G (1999). *An investigation of the frost hardiness of grapevine (*Vitis vinifera*) during bud break.* Annals of Applied Biology 135:589–595.
- Snyder RL, de Melo-Abreu JP (2005). *Frost protection: fundamentals, practice and economics.* FAO Environment and Natural Resources Series 10. [FAO-2005] ch. 2: https://www.fao.org/4/y7223e/y7223e08.htm; ch. 7: https://www.fao.org/4/y7223e/y7223e0d.htm
- [OMAFA-FANS] Ontario Ministry of Agriculture, Food and Agribusiness, *Wind machines for minimizing cold injury to horticultural crops* (updated 2026): https://www.ontario.ca/page/wind-machines-minimizing-cold-injury-horticultural-crops
- [REUSSIR-GEL-2023] Réussir Vigne (2023), *Comment lutter contre le gel de la vigne : 7 choses à savoir*: https://www.reussir.fr/vigne/comment-lutter-contre-le-gel-de-la-vigne-7-choses-savoir-absolument
- [REUSSIR-BEINE-2021] Réussir Vigne (9 Mar 2021), *Beine : 40 ans d'aspersion gérée en collectif*: https://www.reussir.fr/vigne/beine-40-ans-daspersion-geree-en-collectif
- [LARVF-2021] La Revue du vin de France (14 Apr 2021), *Face au gel dans les vignes, que peuvent faire les vignerons ?*: https://www.larvf.com/face-au-gel-dans-les-vignes-que-peuvent-faire-les-vignerons,4740902.asp
- [DECANTER-2021] Decanter (Apr 2021), frost live report: https://www.decanter.com/wine-news/fears-of-frost-damage-in-french-vineyards-456120/
- Berry Bros & Rudd, *Burgundy 2016: vintage report.* https://www.bbr.com/articles/wine/burgundy-2016-vintage-report
- Jasper Morris, *Inside Burgundy: 2016 vintage overview.* https://insideburgundy.com/overview/2016-vintage-overview/
- Coombe, B.G. (1995). Adoption of a system for identifying grapevine growth stages. *Australian Journal of Grape and Wine Research* 1, 104–110.
- García de Cortázar-Atauri, I., Brisson, N., Gaudillère, J.-P. (2009). Performance of several models for predicting budburst date of grapevine (*Vitis vinifera* L.). *International Journal of Biometeorology* 53, 317–326. [Springer](https://link.springer.com/article/10.1007/s00484-009-0217-4)
- Costafreda-Aumedes, S., Leolini, L., Menz, C., Yang, C., Argenti, G., Dibari, C., Bindi, M., Fraga, H., Santos, J., Molitor, D., Torres-Matallana, J.A., Simeunović, M., Moriondo, M. (2025). Uncertainties in predicting the medium-term future occurrence of grapevine budburst in Europe: the role of phenological models and climate scenarios. *OENO One* 59(2). [doi:10.20870/oeno-one.2025.59.2.8056](https://oeno-one.eu/article/view/8056)
- Parker, A.K., García de Cortázar-Atauri, I., van Leeuwen, C., Chuine, I. (2011). General phenological model to characterise the timing of flowering and veraison of *Vitis vinifera* L. *Australian Journal of Grape and Wine Research* 17, 206–216. [Wiley](https://onlinelibrary.wiley.com/doi/10.1111/j.1755-0238.2011.00140.x)
- Parker, A., García de Cortázar-Atauri, I., Chuine, I., Barbeau, G., Bois, B., Boursiquot, J.-M., et al. (2013). Classification of varieties for their timing of flowering and veraison using a modelling approach: A case study for the grapevine species *Vitis vinifera* L. *Agricultural and Forest Meteorology* 180, 249–264. [PDF](https://www-iuem.univ-brest.fr/wapps/letg/adviclim/BDX/PDF/PI_49_Parker_Flow_Ver_Classification_AgForMet_2013.pdf)
- Parker, A., García de Cortázar-Atauri, I., Gény, L., Spring, J.-L., Destrac, A., Schultz, H., Molitor, D., Lacombe, T., Graça, A., Monamy, C., Stoll, M., Storchi, P., Trought, M.C.T., Hofmann, R., van Leeuwen, C. (2020). Temperature-based grapevine sugar ripeness modelling for a wide range of *Vitis vinifera* L. cultivars. *Agricultural and Forest Meteorology* 285–286, 107902. [doi:10.1016/j.agrformet.2020.107902](https://ira.agroscope.ch/en-US/publication/43744)
- Parker, A.K., García de Cortázar-Atauri, I., Trought, M.C.T., Destrac, A., Agnew, R., Sturman, A., van Leeuwen, C. (2020b). Adaptation to climate change by determining grapevine cultivar differences using temperature-based phenology models. *OENO One* 54(4). [doi:10.20870/oeno-one.2020.54.4.3861](https://oeno-one.eu/article/view/3861)
- Labbé, T., Pfister, C., Brönnimann, S., Rousseau, D., Franke, J., Bois, B. (2019). The longest homogeneous series of grape harvest dates, Beaune 1354–2018, and its significance for the understanding of past and present climate. *Climate of the Past* 15, 1485–1501. [Copernicus](https://cp.copernicus.org/articles/15/1485/2019/)
- University of Maryland Extension. [Grapevine Frost/Freeze Damage I: Background and Prevention](https://extension.umd.edu/resource/grapevine-frostfreeze-damage-i-background-and-prevention)
- Growing Produce. [How to Avoid Frost Injury in Vineyards](https://www.growingproduce.com/fruits/grapes/how-to-avoid-frost-injury-in-vineyards/) (cites Gardea 1987 LT50 values for Pinot noir)
- Jones, G.V. (2010). Climate, grapes, and wine: structure and suitability in a variable and changing climate. *Proceedings of the VIII International Terroir Congress*, Soave, Italy. [PDF](https://ives-openscience.eu/wp-content/uploads/2021/11/Climate_Grape_Wine_Jones.pdf)
