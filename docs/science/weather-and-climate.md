# Weather and climate: Block microclimate, viticultural climate indices

Science pass, part 1. Status: **draft for review**. Every number has a source or is marked `UNVERIFIED`. Game simplifications are labelled.

## 1. Purpose in the game

The simulation reads one daily weather series per Region: **Historical weather** (archived observations or reanalysis) or **Synthetic weather** (seeded, after the archive ends). This model does two things:

1. **Turns regional weather into Block weather.** Each Block has its own elevation, slope, aspect and topographic position, so its temperatures differ from the regional series. This is what makes the steep south-facing slate slope warmer than the flat riverbank, and the riverbank frostier.
2. **Computes the classic viticultural climate indices** per Vintage and per Block. They are shown on the Weather screen, used by the Mentor when comparing Plots, and form the calibration anchors for the other models.

## 2. Inputs

| Input | Unit | Source |
|---|---|---|
| Daily Tmax, Tmin, Tmean at 2 m | °C | Weather series (Region grid cell or station) |
| Daily precipitation | mm | Weather series |
| Daily solar radiation, humidity, wind (optional) | MJ·m⁻², %, m/s | Weather series (enables Penman-Monteith ET0, see `soil-and-water.md`) |
| Cloud cover or clear-sky fraction (derived from radiation where missing) | 0–1 | Weather series |
| Reference elevation of the weather series | m | Weather-series metadata (e.g. the grid cell's elevation) |
| Per Block: elevation, slope angle β, aspect azimuth γ, frost-pocket index 0–1 | m, °, °, — | Plot data |
| Latitude | ° | Region |

## 3. From regional weather to Block weather

### 3.1 Elevation (lapse rate)

```
T_block = T_series − Γ · (z_block − z_series)
```

**Γ = 6.5 °C/km.** This is the standard-atmosphere lapse rate, also embedded in FAO-56's pressure-from-altitude equation (P uses 0.0065 K/m; Allen et al. 1998, eq. 7).

The brief quotes ~0.6 °C per 100 m, which agrees. Real near-surface lapse rates vary by season and between Tmax and Tmin. Game simplification: one Γ for all temperatures (`UNVERIFIED` for surface air in valleys, where night-time inversions can reverse the sign; see 3.3).

**Why it matters: calibration.** The reanalysis grid cell used for Bernkastel sits at **387 m**, while the Mosel vineyards run from the river at ~110 m up to ~300 m (Plot data). Moving from 387 m to a Block at 150 m warms Tmean by ~1.5 °C. Over 1 April–30 September that adds roughly 1.5 × 183 × 1.06 ≈ **+290 Huglin units** before any slope effect (section 7).

### 3.2 Slope and aspect (radiation and daytime warmth)

Direct-beam radiation on a tilted surface follows standard solar geometry (Duffie & Beckman 2013, ch. 1). The angle of incidence θ on a surface with slope β and surface azimuth γ (0° = south, west positive):

```
cos θ = sin δ sin φ cos β − sin δ cos φ sin β cos γ
      + cos δ cos φ cos β cos ω + cos δ sin φ sin β cos γ cos ω + cos δ sin β sin γ sin ω
```

δ is the solar declination (FAO-56 eq. 24), φ the latitude, ω the hour angle.

The game integrates cos θ (only when cos θ > 0 and the sun is above the horizon) over each day, in 15-minute steps, and does the same for a horizontal surface. That gives a daily **beam ratio** R_b = beam_slope / beam_flat. Diffuse radiation is treated as isotropic, weighted by the sky-view factor (1 + cos β)/2 (Duffie & Beckman 2013; formula `UNVERIFIED` against the book in this pass).

Temperature effect (empirical, `UNVERIFIED` coefficients):

```
ΔTmax_block = a_T · (R_total − 1) · clear_fraction
ΔTmin_block = b_T · ΔTmax_block          (warm soil and slate release heat at night; b_T ≈ 0.2)
```

**Calibration target (sourced):** vineyards on south-facing slopes in Germany gain **150–300 Huglin degree-days** compared with the flat terrain the index was designed for (DWD, German Climate Atlas). In Franconia in 2010, two steep south sites at different elevations differed by almost 300 Huglin units (Maaß & Schwab 2011). Fit a_T so a 30–35° south-facing Block at 50° N gains about +200 to +250 HI over flat ground at the same elevation, and west- or east-facing slopes proportionally less.

Aspect also shifts the time of day of peak heating. West- and south-west-facing slopes get their strongest sun in the warm afternoon, so they end up warmer than east-facing slopes with the same total radiation (`UNVERIFIED` qualitative; represented in the game by weighting afternoon beam radiation by 1.2).

### 3.3 Cold-air drainage and frost pockets (night-time)

On clear, calm nights, cold air drains downslope like water and pools in hollows and valley floors. It forms an inversion with warmer air above: the "thermal belt" on mid-slopes (SJV Trees and Vines / UCCE, 2022). Choosing sites above the surrounding land, on convex landforms, lets the coldest air move away from the vines (search summary of extension sources, `UNVERIFIED` primary).

Game model (radiation nights only: clear_fraction > 0.7 and wind < 2 m/s, where wind is available):

```
ΔTmin_block = − k_pocket · pocket_index + k_belt · belt_index
```

| Parameter | Meaning | Value | Status |
|---|---|---|---|
| pocket_index | 0 (convex, free-draining) to 1 (closed hollow or river-flat frost pocket) | Plot data | authored |
| belt_index | 0–1, mid-slope thermal-belt position | Plot data | authored |
| k_pocket | Extra night cooling in a full frost pocket | 3.0 °C | UNVERIFIED |
| k_belt | Night warming in the thermal belt | 1.5 °C | UNVERIFIED |

This drives the **cheap flat riverbank Plot = frost pocket** lesson (Mosel and Côte d'Or cheap Plots), together with the stage thresholds in `phenology.md` §6.

### 3.4 Other local effects (`UNVERIFIED`, qualitative)

- **Rivers** (the Mosel) moderate night minima on adjacent slopes and add fog on autumn mornings, which favours botrytis. Game: a small Tmin bonus (+0.5 °C) on Blocks within ~300 m of the river, plus a morning-fog flag used by the disease model (other doc).
- **Stone and slate surfaces** absorb heat and re-radiate it at night; included in b_T above.
- **Napa Carneros / fog line:** marine fog lowers Tmax on low, south Napa Plots; the mountain Plot sits above the fog line. Represented by a per-Plot Tmax offset in the Plot data (`UNVERIFIED` magnitudes).

## 4. Climate indices (computed per Vintage and per Block)

All indices use Northern Hemisphere periods (all MVP Regions are northern).

### 4.1 Winkler index (growing degree-days)

Amerine & Winkler (1944):

```
WI = Σ_{1 Apr}^{31 Oct} max(0, Tmean − 10)        [°C·day]
```

Regions, original limits in °F (Amerine & Winkler 1944, via the Lodi Winegrape Commission) and °C limits as revised by Jones et al. (2010):

| Region | Original (°F·day) | Jones et al. 2010 (°C·day) |
|---|---|---|
| I | ≤ 2500 | ≤ 1389 |
| II | 2501–3000 | 1390–1667 |
| III | 3001–3500 | 1668–1944 |
| IV | 3501–4000 | 1945–2222 |
| V | > 4000 | > 2223 |

Jones et al. (2010) found Napa Valley to be predominantly Region III (56% of its area) and Region IV (30%) (via the Lodi Winegrape Commission).

### 4.2 Huglin heliothermal index

Huglin (1978); formula as given by the Wikipedia summary and DWD:

```
HI = k · Σ_{1 Apr}^{30 Sep} [ (Tmean − 10) + (Tmax − 10) ] / 2
```

The day-length coefficient k is **1.02 at 40° and 1.06 at 50°** latitude. The game interpolates linearly between them and uses 1.00 below 40° (Napa at 38.4° N → 1.00). Game simplification: Huglin's original stepwise table is replaced by linear interpolation (`UNVERIFIED` against Huglin 1978).

**Variety heat requirements** (Huglin, as tabulated in the Wikipedia summary and by DWD):

| HI | Varieties (Huglin) |
|---|---|
| 1500–1600 | Müller-Thurgau, Blauer Portugieser |
| 1600–1700 | Pinot blanc, Pinot gris, Aligoté, Gamay noir, Gewürztraminer |
| **1700–1800** | **Riesling, Chardonnay, Pinot noir**, Silvaner, Sauvignon blanc, Grüner Veltliner |
| 1800–1900 | Cabernet franc |
| **1900–2000** | Chenin blanc, **Cabernet Sauvignon**, Merlot, Sémillon, Welschriesling |
| 2000–2100 | Ugni blanc |
| 2100–2200 | Grenache, Syrah, Cinsaut |
| 2200–2300 | Carignan |
| 2300–2400 | Aramon |

The Bavarian State Institute for Viticulture found that for Franconian conditions the scale needs local adjustment. In their table, Riesling and Chardonnay sit at **1800** and Cabernet Sauvignon at **2000** (Maaß & Schwab 2011). The game uses the Huglin table as the "thermal minimum" and treats the band edges as soft, because water status and site also accelerate or delay ripening (Maaß & Schwab 2011).

**Classes** (Tonietto & Carbonneau 2004, the MCC system):

| Class | HI |
|---|---|
| HI−3 very cool | ≤ 1500 |
| HI−2 cool | 1500–1800 |
| HI−1 temperate | 1800–2100 |
| HI+1 temperate warm | 2100–2400 |
| HI+2 warm | 2400–3000 |
| HI+3 very warm | > 3000 |

The 1500, 2100–2400 and > 3000 bounds are confirmed by a secondary source. The 1800 and 2400/3000 splits are recalled and `UNVERIFIED` against the paper.

### 4.3 Cool night index

Tonietto & Carbonneau (2004): **mean minimum temperature of September** (Northern Hemisphere) (xclim documentation; OIV index list in ClimClass).

| Class | CI (°C) |
|---|---|
| CI+2 very cool nights | ≤ 12 |
| CI+1 cool nights | 12–14 |
| CI−1 temperate nights | 14–18 |
| CI−2 warm nights | > 18 |

The 12, 14–18 and > 18 bounds are confirmed by a secondary source; the 12–14 split is `UNVERIFIED` against the paper. Cool ripening nights are associated with fresher acidity and aroma retention; that link lives in the ripening doc.

### 4.4 Growing-season temperature (GST)

**Mean temperature over 1 April–31 October** (Jones 2010).
- Viticulture is broadly viable between **12 and 22 °C**; high-quality production is more realistically limited to **13–21 °C**.
- Below 13 °C, production is typically limited to hybrids or very early varieties.
- Variety niches (Jones 2010): **Pinot noir 14.0–16.0 °C**, Cabernet franc 15.4–19.8 °C, **Cabernet Sauvignon 16.8–20.2 °C**.
- Riesling and Chardonnay niches: Jones' Fig. 2 values weren't readable in the extracted text (`UNVERIFIED`).

### 4.5 Diurnal temperature range and continentality

- **DTR** = mean(Tmax − Tmin) over 1 April–31 October, and separately over the 30 days before ripeness, when it's most relevant to ripening (Game simplification).
- **Continentality** = mean temperature of the warmest month minus that of the coldest month (Gladstones 1992, as a climate descriptor).

Both are displayed; the ripening doc owns any effect on fruit.

## 5. Calibration anchors (real data)

Computed with `tools/science/climate_indices.py` from **NASA POWER daily data (MERRA-2)**. Full output is in `docs/science/data/climate_indices.json`.

These are **grid-cell values at the grid cell's elevation**, not Block values. Grid cells are ~50 km across, and the Mosel cell is at 387 m, well above the vineyards. This is expected to under-represent the heat of the actual vineyard slopes. (An ERA5 run via Open-Meteo was attempted, but the free API's hourly quota was exhausted overnight; rerun it for a second source when convenient.)

Format: mean (min–max across years).

| Site (grid-cell elevation) | Period | Winkler GDD₁₀ Apr–Oct | Huglin HI | Cool night index (Sep Tmin, °C) | GST Apr–Oct (°C) | DTR Apr–Oct (°C) | Continentality (°C) | Rain Apr–Oct (mm) |
|---|---|---|---|---|---|---|---|---|
| Bernkastel (Mosel) (387 m) | 1981-2000 | 808 (596–947) | 1244 (974–1447) | 8.6 (6.1–11.8) | 12.8 (11.7–13.7) | 9.9 (8.6–11.0) | 20.4 (16.4–25.1) | 496 (304–664) |
| Bernkastel (Mosel) (387 m) | 2001-2020 | 947 (810–1310) | 1420 (1217–1841) | 8.7 (6.6–11.3) | 13.7 (12.7–15.7) | 10.3 (9.5–11.4) | 20.6 (15.9–26.0) | 449 (314–561) |
| Bernkastel (Mosel) (387 m) | 1991-2020 | 915 (693–1310) | 1384 (1188–1841) | 8.6 (6.1–11.8) | 13.5 (12.3–15.7) | 10.2 (9.1–11.4) | 20.6 (15.9–26.0) | 452 (304–664) |
| Beaune (Côte d'Or) (283 m) | 1981-2000 | 1138 (891–1351) | 1602 (1325–1882) | 10.3 (6.9–13.1) | 14.8 (13.5–16.0) | 10.5 (9.3–12.0) | 20.2 (16.7–24.5) | 542 (359–778) |
| Beaune (Côte d'Or) (283 m) | 2001-2020 | 1286 (1067–1716) | 1768 (1459–2355) | 10.3 (8.0–13.0) | 15.7 (14.4–17.4) | 10.9 (9.6–12.6) | 20.6 (16.1–25.8) | 509 (317–709) |
| Beaune (Côte d'Or) (283 m) | 1991-2020 | 1248 (939–1716) | 1734 (1452–2355) | 10.3 (6.9–13.1) | 15.4 (14.0–17.4) | 10.9 (9.6–12.6) | 20.4 (16.1–25.8) | 511 (317–709) |
| Oakville (Napa) (266 m) | 1981-2000 | 1833 (1606–2053) | 2431 (2118–2730) | 13.0 (10.4–15.0) | 18.5 (17.3–19.6) | 16.2 (14.5–17.5) | 16.5 (13.9–19.0) | 128 (44–245) |
| Oakville (Napa) (266 m) | 2001-2020 | 1847 (1537–2225) | 2425 (2078–2750) | 13.5 (11.5–15.3) | 18.6 (17.0–20.4) | 16.0 (14.9–17.0) | 16.0 (13.3–17.5) | 114 (36–243) |
| Oakville (Napa) (266 m) | 1991-2020 | 1839 (1537–2225) | 2416 (2078–2750) | 13.5 (11.5–15.3) | 18.5 (17.0–20.4) | 16.0 (14.5–17.1) | 16.0 (13.3–18.5) | 121 (36–243) |

### 5.1 Reading the anchors (acceptance checks for the Block model)

- **Napa (Oakville): consistent with the literature.** WI 1839 is Winkler **Region III** (Jones et al. 2010 limits), matching Jones et al.'s finding that Napa is predominantly Region III. GST 18.5 °C is inside the Cabernet Sauvignon niche of 16.8–20.2 °C (Jones 2010). HI ≈ 2400 is "warm". Summers are nearly rainless (~120 mm April–October) with a large DTR of ~16 °C: Mediterranean. Block adjustments should stay small (fog line and elevation only).
- **Côte d'Or (Beaune): plausible.** GST rose from 14.8 to 15.7 °C, which puts the recent period at and above the top of the Pinot noir niche (14.0–16.0 °C, Jones 2010). This fits the Beaune harvest-date series, which shows picking starting about 13 days earlier in 1988–2018 than in 1354–1987 (Labbé et al. 2019). HI 1734 (1991–2020) sits in Huglin's Pinot noir/Chardonnay band. Mid-slope Blocks around 250–300 m are near the grid-cell elevation, so adjustments should be modest (slope/aspect and chlorosis-relevant soils matter more).
- **Mosel (Bernkastel): the raw grid is too cold, as expected.** Grid HI 1384 and GST 13.5 °C would put Riesling below its Huglin band (1700–1800). Correcting to a 150 m riverside slope adds ~+290 HI (lapse rate, §3.1). A steep south-facing slope adds +150–300 HI (DWD), for a total of **~1800–2000 HI (1991–2020)** on the best Blocks. That's at or just above Riesling's band, matching the game's premise that the steep south slate Plot is premium and the flat, high or north-facing Plots are marginal. **Acceptance check:** after adjustments, the Mosel steep-south Block must reach HI 1750–2000 (1991–2020 mean), and the flat riverbank frost-pocket Block about 1500–1650 (`UNVERIFIED` target band derived from the sources above).
- **Warming is visible everywhere in Europe:** Mosel HI +176 and Beaune HI +166 between 1981–2000 and 2001–2020. For scale, Würzburg's HI rose from 1452 (1961–1990) to 1600 (1981–2010) (Maaß & Schwab 2011). The continuous historical Timeline (ADR 0002) reproduces this automatically.

### 5.2 Block-model calibration results (27 Sep 2026, `sim climcheck`)

The grid-cell elevations in the data are Mosel **106 m**, Côte d'Or **224 m** and Napa **45 m**. That is lower than the station elevations assumed in §3.1, so the Mosel Blocks get no lapse-rate warming. Two calibration terms were added, both `UNVERIFIED` fits. Rerun `sim climcheck` after any climate change.

- **South-slope warmth** (`SiteWarmthC` = 1.2 °C on Tmax, half on Tmin, scaled by how south-facing the Block is and by slope/60 %). The beam-ratio term alone gave steep south slopes only about +10 HI. With the new term, the steep south Mosel Blocks reach **HI 1700–1790** (Terrassen 1702–1791, Blauschiefer 1662–1755) and the flat riverbank frost pocket **1544–1572**, which meets the §5.1 acceptance check.
- **Napa correction revised.** The region correction was −3.2/−1.6 °C (Tmax/Tmin), with fog −2.5 °C × fog frequency. That double-counted the bias and put the valley floor at about 1,250–1,450 Winkler (Region I–II). It is now −1.0/−0.5 °C for the region, fog −2.0 °C × frequency, and a sea breeze of −3.0 °C × wind exposure (only where fog reaches). 1991–2020 Winkler: floor **1546–1739**, Rutherford bench **1708–1819** (Region III), Carneros **1569–1594** (Region II, coolest), mountain **1468–1770**.
- **Night inversion.** Blocks above the grid elevation in the thermal belt escape part of the lapse-rate cooling at night (Game simplification).

## 6. Synthetic weather (interface only)

Synthetic weather must reproduce, per Region, the recent-climate distributions of the table above (1991–2020 means and year-to-year range), plus the warming trend beyond 2025. Its generator is out of scope for this doc; these anchors are its acceptance tests.

## 7. Game simplifications

1. One lapse rate for all temperatures, with inversions handled only by the frost-pocket term.
2. Slope heat from a radiation ratio with an empirical temperature coefficient, not an energy-balance model.
3. Huglin k interpolated linearly.
4. Per-Plot fixed offsets for fog and river effects.

## 8. Open questions

- Verify the Tonietto & Carbonneau (2004) class boundaries against the paper, and Huglin's stepwise k table.
- Rerun the anchors with ERA5 (Open-Meteo) and, where possible, station data (DWD Bernkastel-Kues or Trier; Météo-France Beaune; CIMIS Oakville) to quantify the grid bias.
- Fit a_T and the frost-pocket coefficients against measured Block microclimate data if any can be found (e.g. Mosel slope-vs-valley studies).

## Sources

- Allen, R.G., Pereira, L.S., Raes, D., Smith, M. (1998). *Crop evapotranspiration.* FAO Irrigation and Drainage Paper 56. [ch. 3](https://www.fao.org/4/x0490e/x0490e07.htm) (eq. 7, 24).
- Amerine, M.A., Winkler, A.J. (1944). Composition and quality of musts and wines of California grapes. *Hilgardia* 15, 493–675. (Region limits via Lodi Winegrape Commission.)
- Jones, G.V., Duff, A.A., Hall, A., Myers, J.W. (2010). Spatial analysis of climate in winegrape growing regions in the western United States. *American Journal of Enology and Viticulture* 61, 313–326. [AJEV](https://www.ajevonline.org/content/61/3/313)
- Lodi Winegrape Commission. [Revised degree-day classification](https://www.lodiwine.com/blog/Revised-degree-day-classification--or--can-we-stop-describing-Lodi-as-a-desert--) (original and Jones et al. region limits; Napa distribution)
- Jones, G.V. (2010). Climate, grapes, and wine: structure and suitability in a variable and changing climate. *Proceedings of the VIII International Terroir Congress*, Soave. [PDF](https://ives-openscience.eu/wp-content/uploads/2021/11/Climate_Grape_Wine_Jones.pdf)
- Huglin, P. (1978). Nouveau mode d'évaluation des possibilités héliothermiques d'un milieu viticole. *C. R. Acad. Agric. France* 64, 1117–1126. Formula, k end points and variety table via [Wikipedia: Huglin index](https://en.wikipedia.org/wiki/Huglin_index) and [DWD German Climate Atlas: Huglin index](https://www.dwd.de/EN/ourservices/germanclimateatlas/explanations/elements/_functions/faqkarussel/huglin.html)
- DWD (Deutscher Wetterdienst), German Climate Atlas, [Huglin index explanation](https://www.dwd.de/EN/ourservices/germanclimateatlas/explanations/elements/_functions/faqkarussel/huglin.html) (south-facing slopes: +150 to 300 degree-days)
- Maaß, U., Schwab, A. (2011). Klimawandel und Sortenwahl: Der Huglin-Index und der Wärmeanspruch von Rebsorten. *Das deutsche Weinmagazin* 10/2011. Bayerische Landesanstalt für Weinbau und Gartenbau. [PDF](https://amper.ped.muni.cz/gw/clanky/vino/odkazy/huglin_anspruch.pdf)
- Tonietto, J., Carbonneau, A. (2004). A multicriteria climatic classification system for grape-growing regions worldwide. *Agricultural and Forest Meteorology* 124, 81–97. [ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0168192304000115) (class boundaries partly via secondary sources; see text)
- xclim documentation, [indices](https://xclim.readthedocs.io/en/stable/indices.html) (cool night index definition); ClimClass R package, [OIV bioclimatic indices](https://search.r-project.org/CRAN/refmans/ClimClass/html/oiv_ind.html)
- Gladstones, J. (1992). *Viticulture and Environment.* Winetitles, Adelaide.
- Duffie, J.A., Beckman, W.A. (2013). *Solar Engineering of Thermal Processes*, 4th ed. Wiley. (Incidence-angle equation.)
- Labbé, T., Pfister, C., Brönnimann, S., Rousseau, D., Franke, J., Bois, B. (2019). The longest homogeneous series of grape harvest dates, Beaune 1354–2018. *Climate of the Past* 15, 1485–1501. [Copernicus](https://cp.copernicus.org/articles/15/1485/2019/)
- SJV Trees and Vines / UC Cooperative Extension (2022). [Passive measures to reduce impacts of late spring frosts](https://www.sjvtandv.com/blog/passive-measures-to-reduce-impacts-of-late-spring-frosts)
- NASA POWER Project, [Daily API](https://power.larc.nasa.gov) (MERRA-2 based data), accessed 2026-09-26.
