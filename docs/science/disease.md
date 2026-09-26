# Vineyard disease models

Status: draft, science pass (M1). Terms follow `CONTEXT.md`. Anything marked `UNVERIFIED` is a number or claim I could not confirm against a source during this pass and must be checked before it becomes a calibration target.

## 1. Purpose

Turn a Block's hourly weather, growth stage, canopy and spray Programme into infection events, disease severity on leaves and bunches, and the consequences: less photosynthesis, yield loss, and lower fruit quality (off-flavours, rot fraction). Three diseases are in the MVP (spec §4.5): **downy mildew** (*Plasmopara viticola*), **powdery mildew** (*Erysiphe necator*, formerly *Uncinula necator*) and **botrytis bunch rot** (*Botrytis cinerea*), including its noble form on late-harvest Riesling.

The design goal is an infection *mechanism* whose inputs are observable in the game (rain, temperature, humidity, growth stage, spray timing), so that the advisor can explain every Alert ("3-10 rule met on 14 May: primary infection likely").

## 2. Shared machinery

### 2.1 Hourly weather from daily data

The engine ticks daily (spec §3.3), but infection depends on hours of wetness at a given temperature. For each day:

- **Hourly temperature:** reconstruct from Tmin/Tmax with a sine curve for daylight and an exponential decay at night. The standard sine-exponential reconstruction is adequate; the weather/phenology doc defines it.
- **Leaf wetness hours (LWH):** hours with rain > 0.2 mm, plus hours with RH ≥ 90 %. RH is reconstructed from daily mean RH and dew point, with the highest RH at dawn. **Game simplification:** real leaf wetness depends on canopy, wind and dew; a RH threshold is a widely used proxy, and the exact value (87–90 %) varies by study. `UNVERIFIED` exact threshold.
- **Wet periods:** consecutive wet hours, merged if interrupted by ≤ 2 dry hours. **Game simplification.**

### 2.2 Disease state per Block

For each disease and Block:

| Variable | Unit | Meaning |
|---|---|---|
| `inoculum` | 0–1 | Relative pressure from overwintering spores (oospores, chasmothecia, sclerotia). Starts from a Region default and scales with last season's severity (multi-vintage later). |
| `latent[]` | cohorts | Infections still incubating, each with its start day and progress 0→1 |
| `leafSeverity` | % leaf area | Visible, sporulating lesions |
| `bunchSeverity` | % bunches (or berries) affected | Drives yield and quality loss |
| `protection` | 0–1 | Current fungicide cover (§6) |

The infection efficiency of a wet period is always multiplied by `(1 − protection) × susceptibility(stage) × inoculum`.

## 3. Downy mildew

### 3.1 Primary infection (oospores in the soil)

**Trigger, the "3-10 rule":** primary infection is possible once **all three** hold:
- mean air temperature ≥ 10 °C
- ≥ 10 mm rain within 24–48 h
- shoots ≥ 10 cm long (roughly 3–4 unfolded leaves)

The 10 °C and 10 mm thresholds are reported as the classic conditions for primary infection (Gessler, Pertot & Perazzolli 2011). The rule is deliberately conservative: it flags *risk*, not certain infection.

A more mechanistic model exists (Rossi et al. 2008), simulating oospore maturation, germination, zoospore release and splash dispersal. **Game simplification:** the MVP uses the 3-10 rule to mark the start of the primary season and then treats each qualifying rain event as a primary infection attempt with efficiency from §3.2.

### 3.2 Infection efficiency of a wet period (primary and secondary)

Use the generic infection model of Magarey et al. (2005), with the downy mildew parameters fitted by Caffi et al. (2016) and reported in the 2021 model below.

Required wetness at temperature T:

```
f(T) = ((Tmax − T) / (Tmax − Topt)) · ((T − Tmin) / (Topt − Tmin)) ^ ((Topt − Tmin) / (Tmax − Topt))     for Tmin < T < Tmax, else 0
W(T) = Wmin / f(T)                        (hours; infinite when f = 0)
```

| Parameter | Value | Source |
|---|---|---|
| Tmin | 4.0 °C | Caffi et al. 2016, reported in *A weather-driven model for predicting infections of grapevines by sporangia of P. viticola* (2021) |
| Topt | 21.0 °C | same |
| Tmax | 30.2 °C | same |
| Wmin (at Topt) | 2 h | same |

An infection occurs when a wet period's length `LW ≥ W(T_mean_wet)`. **Game formula** for severity added per event:

```
efficiency = clamp((LW − W(T)) / W(T), 0, 1)                          (0 at threshold, 1 at double the required wetness)
newLatent  = efficiency · susceptibility(stage) · (1 − protection) · source
source     = inoculum (primary)   or   leafSeverity · sporulated (secondary)
```

`efficiency` scaling is a **Game simplification** chosen to give a smooth response; the threshold itself comes from the source model.

Cross-check: UC IPM gives an optimum of 20–25 °C with extremes of 10–29 °C for disease development, and notes the infection process can take under 90 minutes (UC IPM Grape Guidelines). A separate study found zoospore release and infection highest at 15–20 °C, with most infections within 3 h (same 2021 Frontiers paper).

### 3.3 Incubation

Symptoms (oil spots) appear after an incubation period that shortens with temperature. UC IPM gives **about 4 days** under favourable conditions; Cornell IPM gives **7–12 days** after infection. Model incubation as a development rate summed per day:

```
progress += 1 / D(T_mean_day)        cohort becomes visible (and can sporulate) when progress ≥ 1
```

| T mean (°C) | D (days) |
|---|---|
| ≤ 10 | 16 |
| 13 | 12 |
| 17 | 8 |
| 21 | 5 |
| 24 | 4 |
| 27 | 5 |
| ≥ 30 | 8 |

`UNVERIFIED`: this table is interpolated to agree with both sources (≈ 4 days at the optimum, 7–12 days in cooler weather). Replace with a published incubation table (Goidanich or equivalent) when available.

### 3.4 Sporulation and secondary cycles

Visible lesions sporulate during a **night-time moist period of ≥ 3 h at 10–30 °C**, where "moist" means RH ≥ 80 %, rain > 0 mm, or leaf wetness > 30 min (Caffi et al. 2013a, as reported in the 2021 Frontiers model). Sporangia released that night can infect during the next wet period (§3.2), with `source = leafSeverity`. **Game simplification:** sporangia survival (a VPD-dependent mortality in Brischetto et al. 2020) is replaced by "sporangia expire at the end of the next dry day".

Cornell IPM also gives 13–30 °C and high humidity for sporulation; the model's 10 °C lower limit comes from the Caffi rule.

### 3.5 Susceptibility by growth stage

| Stage | Leaves | Bunches |
|---|---|---|
| Budburst → shoots 10 cm | not yet (primary rule not met) | – |
| Shoots 10 cm → flowering | high (young leaves most susceptible) | inflorescences susceptible |
| Flowering → 3 weeks after flowering | high | **highest risk period for bunches** |
| > 3 weeks after flowering | moderate (older leaves less susceptible) | **berries resistant** (rachis and pedicels can still be infected) |

Cornell IPM: berries become resistant about 3 weeks after bloom; the most critical control period runs from 2 weeks before bloom to 3 weeks after.

### 3.6 Consequences

- **Leaves:** `leafSeverity` reduces effective leaf area (canopy doc): photosynthesis and sugar loading fall, and severe defoliation stalls ripening.
- **Bunches:** infected inflorescences and young bunches are lost. **Game rule:** bunch yield loss = `bunchSeverity`.
- **Quality:** no direct off-flavour. The damage works through reduced ripening and yield.

## 4. Powdery mildew

### 4.1 Risk index (Gubler-Thomas, "UC Davis Powdery Mildew Risk Index")

Powdery mildew does not need rain or leaf wetness; conidia infect in dry conditions, and **temperature** drives the epidemic. The UC Davis index (Gubler, Rademacher, Vasquez & Thomas 1999; now in UC IPM guidelines) tracks it. The literature also calls it the Gubler-Thomas index.

**Epidemic start (after ascospore infections have been found):** 3 consecutive days with ≥ 6 continuous hours between 21 and 29 °C (70–85 °F).

**Daily index update (0–100, clamped):**

| Condition on the day | Points |
|---|---|
| ≥ 6 continuous hours at 21–29 °C | +20 |
| < 6 continuous hours at 21–29 °C | −10 |
| Temperature reached ≥ 35 °C (95 °F) for > 15 min | −10 |

**Pressure:**

| Index | Pressure | UC IPM spray interval (varies by product class) |
|---|---|---|
| 0–30 | low | 7–21 days |
| 40–50 | moderate | 7–17 days |
| ≥ 60 | high | 7–14 days |

The thresholds, points and intervals are quoted from UC IPM Pest Management Guidelines: Grape (Publication 3448).

**Ascospore phase (season start).** The index needs an ascospore infection first. **Game simplification:** after budburst, the first day with rain ≥ 2.5 mm and mean temperature ≥ 10 °C starts ascospore infections. `UNVERIFIED`: that ascospore rule is from memory of the UC Davis model and must be checked against Gubler et al. 1999 before calibration.

### 4.2 Infection and severity

```
dailyInfection = (index / 100) · susceptibility(stage) · (1 − protection) · inoculum · k_pm
```

`k_pm` is the calibration constant (`UNVERIFIED`, fit so that a High-index season without protection gives heavy bunch infection). Incubation is short in warm weather (about 5–7 days, `UNVERIFIED`). **Game simplification:** a fixed 6-day delay before new infections count as visible.

### 4.3 Susceptibility by growth stage

Berries are highly susceptible from fruit set and become resistant (**ontogenic resistance**) about 3–4 weeks after bloom. Leaves stay susceptible all season, with young leaves most at risk. Source: Gadoury et al. 2003, cited from memory (`UNVERIFIED` exact timing).

### 4.4 Consequences

- Infected berries **crack** as they expand, giving entry to botrytis and sour rot (§5.4: cracking raises botrytis susceptibility).
- Infected fruit gives musty/mouldy off-flavours. **Game rule:** bunch severity above ~3 % adds an off-flavour penalty on the Tasting sheet (`UNVERIFIED` threshold).
- Leaf infection reduces photosynthesis, the same way as downy mildew.
- Powdery mildew is the dominant disease in dry-summer California. The UC Davis index was built for it, and APSnet describes powdery mildew as the most enduring disease problem for California *V. vinifera* growers (Gubler et al. 1999). Downy mildew is rare there because summers are dry.

## 5. Botrytis bunch rot and noble rot

### 5.1 Infection model (Broome et al. 1995)

Broome, English, Marois, Latorre & Aviles (1995) fitted infection of berries as a function of **wetness duration W (h)** and **temperature T (°C)**. They inoculated berries and incubated them for 4–20 h of wetness. The model is a logistic regression:

```
ln( Y / (1 − Y) ) = b0 + b1·W + b2·W·T + b3·W·T²          Y = proportion of berries infected
```

| Coefficient | Value | Source |
|---|---|---|
| b0 | −2.647866 | Broome et al. 1995 |
| b1 | −0.374927 | Broome et al. 1995 |
| b2 | 0.061911 | Broome et al. 1995 |
| b3 | −0.001023 | Broome et al. 1995 |

`UNVERIFIED`: the functional form and the paper are confirmed (Phytopathology 85:97–102), but the coefficients are reproduced from memory; the original abstract page returned 403. Check them against the paper before calibration. Sanity check with these numbers: T = 20 °C, W = 12 h gives logit ≈ −2.65 − 4.50 + 14.86 − 4.91 ≈ 2.80, so Y ≈ 0.94. That is plausible for inoculated berries under long wetness at the optimum. Field infection is far lower because inoculum is limited, which is handled by `inoculum` and `susceptibility`.

**Game formula:**

```
newRot = Y(W, T) · susceptibility(stage, variety, cracking) · (1 − protection_botrytis) · inoculum · k_bot
```

### 5.2 Susceptibility windows

González-Domínguez et al. (2015) model two main infection windows:
1. **Flowering**, when inflorescences are more susceptible than at earlier stages. Infections can stay latent in the berry until ripening.
2. **Veraison → ripening**, when berry susceptibility increases steadily as sugar rises and skins soften.

Between fruit set and bunch closure, susceptibility decreases. **Game rule:**

| Stage | susceptibility |
|---|---|
| Flowering | 0.4 |
| Fruit set → bunch closure | 0.1 |
| Bunch closure → veraison | 0.05 |
| Veraison → harvest | rises linearly 0.2 → 1.0 with sugar (°Oe/Brix progress) |

`UNVERIFIED` numbers; only the shape comes from the source.

### 5.3 Latent infections

A fraction of flowering-time infections (`UNVERIFIED`, 30 %) becomes active bunch rot after veraison. That links spring weather to autumn rot, a real and teachable effect, not just a harvest-time lottery.

### 5.4 Modifiers

| Factor | Effect | Basis |
|---|---|---|
| Cluster compactness (variety) | Compact bunches (Riesling, Pinot Noir, Chardonnay) are more susceptible than loose ones (Cabernet Sauvignon): berries touch, water stays trapped, berries split | Standard viticulture; `UNVERIFIED` multipliers: Riesling 1.3, Pinot Noir 1.4, Chardonnay 1.2, Cabernet Sauvignon 0.8 |
| Berry cracking | Rain after a dry spell and powdery-mildew damage make berries crack; rot spreads berry to berry | González-Domínguez 2015 model includes berry-to-berry spread |
| Canopy density | Dense canopies keep the fruit zone humid and add wetness hours | Canopy doc: fruit-zone wetness multiplier |
| Leaf removal around the bunches | Faster drying, better spray coverage, fewer wetness hours | Canopy doc |

### 5.5 Noble rot (*Edelfäule*) vs grey rot

The same fungus gives **noble rot** when it infects **fully ripe, intact berries** in weather that alternates humid mornings (mist, dew) with dry, sunny afternoons. The berries dehydrate and concentrate sugar and acid, the basis of Beerenauslese and Trockenbeerenauslese. In persistent wet weather, or on split, unripe berries, it becomes **grey rot**, which destroys quality.

**Game rule** (a Game simplification; the physiology is standard WSET content):
- If a botrytis infection lands on berries at ≥ 80 °Oe with no cracking, **and** the next 5 days include at least 3 days with afternoon RH < 60 %, the infection becomes **noble**. It raises sugar concentration (through dehydration, ripening doc §3.3) and TDN and honey characters, lowers yield, and gives no grey-rot off-flavour.
- Otherwise it is **grey rot**: yield loss, plus off-flavour and a volatile-acidity risk passed to the winery.

`UNVERIFIED`: the thresholds 80 °Oe, 3 of 5 days and 60 % RH.

### 5.6 Consequences

- Yield loss = bunch rot fraction, adjustable by sorting at harvest (hand picking removes most).
- Grey rot carried into the Winery adds laccase, a browning and oxidation risk. It's also a volatile-acidity and off-flavour risk, handled in the winemaking doc.

## 6. Spray Programme tiers

**Game simplification:** a single spray Programme per Block covers all three diseases (spec §5.1). Product choice (contact vs systemic; organic copper and sulphur vs conventional) is in the backlog.

| Tier | Interval target | Spray days skipped in rain | Initial protection P0 | Protection half-life | Labour (h/ha per pass, flat, mechanised) | Materials (€/ha per pass) |
|---|---|---|---|---|---|---|
| Low | 14 days | yes | 0.70 | 6 days | 1.0 | 25 |
| Medium | 10 days | reschedules within 2 days | 0.85 | 7 days | 1.0 | 40 |
| High | 7 days, plus an extra spray after an Alert | reschedules same or next day | 0.92 | 8 days | 1.0 | 60 |

All values are `UNVERIFIED` placeholders. The economy doc owns the costs; labour is doubled on steep hand-worked plots (canopy doc §6).

**Protection dynamics:**

```
protection(t) = P0 · 0.5 ^ (days_since_spray / half_life) · washoff · newGrowth
washoff   = 0.5  if rain since the spray ≥ 25 mm (contact products lose cover)        UNVERIFIED
newGrowth = unsprayed leaf area fraction lowers cover for leaves (shoots grow ~ 2–3 leaves a week in spring)   UNVERIFIED
```

- Spraying *before* a forecast infection period is protective. After infection only the (implicit) systemic share works, and only within ~2 days. **Game simplification:** a spray within 48 h after an infection event removes 50 % of that event's latent cohort. `UNVERIFIED`.
- Botrytis protection is weaker than mildew protection (`P0 × 0.6`). Leaf removal and canopy work matter more for botrytis. `UNVERIFIED` factor.
- **Staff level** (spec §5.4) improves execution: a Senior Vineyard manager times sprays just before infection periods using the forecast. **Game rule:** Senior gets an effective +0.05 protection at infection events; Junior −0.05 (`UNVERIFIED`).

## 7. Inputs

Hourly temperature, RH, rain and leaf wetness (reconstructed from daily Historical or Synthetic weather), growth stage (phenology doc), leaf area and fruit-zone density (canopy doc), sugar level (ripening doc), Variety (compactness), spray Programme tier and Staff level, forecast (for staff advice only; staff never see the real future, ADR 0002).

## 8. Calibration

| Target | Range | Status |
|---|---|---|
| Napa, dry summer, Medium spray | downy ≈ 0; powdery index regularly ≥ 60 in mild coastal-influenced periods; bunch powdery < 2 % | shape from UC IPM; numbers `UNVERIFIED` |
| Napa, harvest-time rain (e.g. 2011) | botrytis becomes the main risk; bunch rot 5–20 % unprotected | `UNVERIFIED` |
| Mosel, wet season (e.g. 2021), Low spray | heavy downy pressure; bunch loss 20–50 % | `UNVERIFIED` (a wet, high-pressure year in Germany; confirm with DWD/Geisenheim reports) |
| Mosel, normal season, Medium spray | downy bunch loss < 5 %; botrytis 2–10 % at harvest, more in compact Riesling on the wettest Blocks | `UNVERIFIED` |
| Côte d'Or, typical season, Medium spray | downy and powdery both present; bunch loss < 5 % | `UNVERIFIED` |
| No spraying at all in a humid European season | downy can destroy most of the crop (historical pre-fungicide losses) | qualitative, standard history |

## 9. Game simplifications (labelled in-game in Normal mode)

1. Leaf wetness estimated from RH and rain.
2. The 3-10 rule starts the primary downy season; oospore biology is not simulated.
3. A single spray Programme protects against all three diseases, with fixed efficacy numbers per tier.
4. Noble vs grey rot is decided by a weather rule, not simulated fungal physiology.
5. Other diseases and pests (black rot, phomopsis, trunk diseases, grape moth) are left out (backlog).

## Sources

- Gessler C, Pertot I, Perazzolli M (2011). *Plasmopara viticola: a review of knowledge on downy mildew of grapevine and effective disease management.* Phytopathologia Mediterranea 50:3–44. (10 mm / 10 °C primary infection conditions)
- Rossi V, Caffi T, Giosuè S, Bugiani R (2008). *A mechanistic model simulating primary infections of downy mildew in grapevine.* Ecological Modelling 212:480–491. Cited from memory, not re-checked in this pass.
- Magarey RD, Sutton TB, Thayer CL (2005). *A simple generic infection model for foliar fungal plant pathogens.* Phytopathology 95:92–100. Cited from memory; its parameterisation for *P. viticola* is reported in the next source.
- *A weather-driven model for predicting infections of grapevines by sporangia of Plasmopara viticola* (2021). Frontiers in Plant Science 12:636607. https://www.frontiersin.org/journals/plant-science/articles/10.3389/fpls.2021.636607/full (reports the Caffi et al. 2016 parameters, the Caffi et al. 2013a sporulation rule and Brischetto et al. 2020 survival)
- Lalancette N, Ellis MA, Madden LV (1988). *Development of an infection efficiency model for Plasmopara viticola on American grape based on temperature and duration of leaf wetness.* Phytopathology 78:794–800.
- Lalancette N, Madden LV, Ellis MA (1988). *A quantitative model for describing the sporulation of Plasmopara viticola on grape leaves.* Phytopathology 78:1316–1321.
- UC IPM Pest Management Guidelines: Grape, UC ANR Publication 3448 (Smith, Bettiga, Gubler, Eskalen). Downy mildew: https://ipm.ucanr.edu/agriculture/grape/downy-mildew/ · Powdery mildew: https://ipm.ucanr.edu/agriculture/grape/powdery-mildew/
- Cornell IPM. *Grapevine Downy Mildew fruit fact sheet.* https://cals.cornell.edu/integrated-pest-management/grapevine-downy-mildew-plasmopara-viticola-fruit-fact-sheet
- Gubler WD, Rademacher MR, Vasquez SJ, Thomas CS (1999). *Control of powdery mildew using the UC Davis powdery mildew risk index.* APSnet Feature, doi:10.1094/APSnetFeature-1999-0199. https://www.apsnet.org/edcenter/apsnetfeatures/Pages/UCDavisRisk.aspx
- Gadoury DM, Seem RC, Ficke A, Wilcox WF (2003). *Ontogenic resistance to powdery mildew in grape berries.* Phytopathology 93:547–555. Cited from memory.
- Broome JC, English JT, Marois JJ, Latorre BA, Aviles JC (1995). *Development of an infection model for Botrytis bunch rot of grapes based on wetness duration and temperature.* Phytopathology 85:97–102. https://www.apsnet.org/publications/phytopathology/backissues/Documents/1995Abstracts/Phyto_85_97.htm
- González-Domínguez E, Caffi T, Ciliberti N, Rossi V (2015). *A mechanistic model of Botrytis cinerea on grapevines that includes weather, vine growth stage, and the main infection pathways.* PLOS ONE 10(10):e0140444. https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0140444
