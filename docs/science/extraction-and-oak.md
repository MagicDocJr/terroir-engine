# Extraction (red maceration), oak, lees, fining and filtration

## Purpose
- Models how colour, tannin and body get into a red Lot during maceration, and what the cap management decisions change.
- Models what oak contributes during ageing: aroma compounds, oak tannin and oxygen.
- Models lees contact and bâtonnage, and fining and filtration.

These are the core WSET Level 3 winemaking choices listed in spec §5.2 (destem vs whole bunch, cold soak, fermentation temperature, cap management, vessel, time in oak, lees stirring, fining/filtration).

## 1. Red maceration: extraction kinetics

### Pools (per Lot, mg/L in the wine)

| Pool | Origin | Behaviour |
|---|---|---|
| Anthocyanins (A) | skins | Extract early and fast (water-soluble). They peak within the first days of fermentation and then **decline** as they adsorb to solids and yeast and react with tannins into polymeric pigments |
| Skin tannin (Tsk) | skins | Extracts early to mid-maceration. Softer, larger polymers |
| Seed tannin (Tsd) | seeds | Extracts later and needs ethanol to dissolve the seed cuticle. Smaller, harsher, more astringent, especially from unripe (green, unlignified) seeds |
| Stem tannin (Tst) | stems, only with whole bunch | Green, astringent if stems are unripe. Stems also release K⁺, which raises pH |
| Polymeric pigment (PP) | A + T reaction | Stable colour that forms over maceration and ageing |

### Model
For each pool i:
```
dC_i/dt = k_i(T, E, M) · (C_i,max − C_i) − λ_i · C_i
k_i     = k_i,ref · θ_i^((T − 25)/10) · g_i(E) · M_i
```
- **C_i,max:** the extractable potential from the vineyard model: berry anthocyanin and tannin concentrations, seed maturity (lignification index), skin:juice ratio and destemming ratio.
- **θ_i** (temperature coefficient, Q₁₀-like): higher fermentation temperatures (28–32 °C) extract more phenolics than cool ones. Sacchi, Bisson & Adams (2005) list fermentation temperature among the variables consistently shown to increase phenolic concentration. The Q₁₀ values themselves are UNVERIFIED.
- **g_i(E), the ethanol dependence:** g = 1 for anthocyanins and skin tannin. For seed tannin, g = E/(E + E₅₀), because seed tannin extraction increases once ethanol has built up. That's the qualitative finding summarised in Sacchi et al. (2005). The functional form and E₅₀ are UNVERIFIED.
- **λ_A, anthocyanin loss** (adsorption and polymerisation): it produces the rise-then-fall anthocyanin curve.
- **M_i, the cap management multiplier** (a Cellar decision):

| Technique | Model effect | Notes |
|---|---|---|
| Pump-over (remontage), 1–3×/day | M ≈ 1.0 per daily frequency step, gentle | Also aerates (yeast health) and evens out cap temperature |
| Punch-down (pigeage) | M ≈ 1.2, stronger on skins | Traditional for Pinot Noir. Risk of over-extracting seed tannin if very frequent late in fermentation |
| Délestage (rack-and-return) | M ≈ 1.3 once, also removes part of the seeds (lower Tsd,max) | Seed removal is the reason winemakers use it |
| None / gentle | M ≈ 0.5 | Low extraction, risk of VA in a dry cap |

  The multiplier values are a **game simplification** (UNVERIFIED magnitudes). The direction of each effect is per standard practice (Sacchi et al. 2005, and WSET-level winemaking texts cited from memory).

**Pre-fermentation cold soak (5–10 °C, 2–7 days):** extracts water-soluble anthocyanins before ethanol. The literature is **inconsistent** on lasting colour benefits; Sacchi et al. (2005) do not list cold soak among the techniques that reliably increase phenolics. The game gives a small anthocyanin gain, a small fruit-aroma gain, and a VA/spoilage risk if SO₂ and temperature are poorly managed. The magnitude is UNVERIFIED.

**Extended maceration (post-fermentation):** raises seed tannin and polymerisation, and lowers free anthocyanins. It's in the Sacchi et al. (2005) list of techniques that increase phenolic concentration.

**Whole bunch (destemming ratio d ∈ [0, 1]; 0 = fully destemmed):**
- adds Tst ∝ (1 − d) × stem ripeness penalty
- adds K⁺ → pH rises (via `acid-ph-so2.md`)
- slightly lowers colour (stems adsorb anthocyanins)
- adds an intracellular-fermentation "fresh red fruit / spice" aroma credit for Pinot Noir

  Magnitudes are UNVERIFIED.

**Pressing:** free-run vs press fraction. The press fraction is higher in tannin and K⁺ and lower in acid. It's blendable (the Blending decision).

### Units and ranges

| Quantity | Typical finished red range | Source |
|---|---|---|
| Total tannin, Pinot Noir | low (roughly 100–500 mg/L catechin eq.) | UNVERIFIED (Harbertson–Adams assay ranges; to source) |
| Total tannin, Cabernet Sauvignon | high (roughly 400–1,500 mg/L catechin eq.) | UNVERIFIED |
| Anthocyanins, young Cabernet | ~300–700 mg/L (malvidin-3-glucoside eq.) | UNVERIFIED |
| Anthocyanins, young Pinot Noir | ~100–300 mg/L; no acylated anthocyanins in Pinot | UNVERIFIED (the absence of acylated anthocyanins is a well-known varietal trait, but uncited here) |
| Anthocyanin peak | within ~3–6 days of the start of fermentation | Qualitative; Sacchi et al. 2005 (exact days UNVERIFIED) |

## 2. Oak ageing

### Vessel parameters (a Cellar decision: vessel, species, toast, fill/age, duration)
**Surface-to-volume** (computed from our shared cask models: `barrique.glb`, `fuder.glb`):
- barrique 225 L: inner area ≈ 2.4 m² → **S/V ≈ 10.8 m²/m³**
- Mosel Fuder 1,000 L: ≈ 5.5 m² → **S/V ≈ 5.5 m²/m³**

A Fuder therefore extracts roughly half as fast per litre as a barrique, and it's usually old and neutral. That's why Mosel Riesling aged in Fuder tastes of fruit, not oak. Derived from geometry.

**Species:**
- *Quercus alba* (American oak) gives much higher whisky-lactone levels, with a higher cis:trans ratio, than *Q. petraea* (UC Davis Waterhouse Lab, "Oak Lactones").
- European oaks give more ellagitannins, especially *Q. robur*, and finer-grained *Q. petraea* is the classic barrique wood. The ellagitannin comparison is cited from memory and UNVERIFIED.

**Toast level** (L / M / M+ / H) shifts the compound profile:
- Lactones decrease with heavier toast (thermal degradation).
- Vanillin rises from light to medium toast, then falls.
- Furanic aldehydes (furfural, 5-methylfurfural; "toast/caramel") rise with toast.
- Guaiacol and 4-methylguaiacol ("smoky") rise strongly with heavy toast.
- Eugenol ("clove") is present at all toasts, peaking around medium.
- Oak ellagitannins decrease with toast.

  These directions are standard cooperage chemistry, cited from memory (Chatonnet and others). The **per-level multipliers are UNVERIFIED**.

**Fill (barrel age):** extraction potential per fill: new 1.0, 1st fill 0.5, 2nd fill 0.3, neutral (3rd+) 0.1. UNVERIFIED **game simplification**.

### Model
For each oak compound j:
```
C_j(t) = C_j,pot · f_species,j · f_toast,j · f_fill · (S/V)/(S/V)_barrique · (1 − e^(−k_j · t))
```
- k_j gives most extraction in the first ~6–12 months (UNVERIFIED).
- **Oak tannin** adds to the Wine's tannin total (texture), and a "wood tannin" descriptor appears if it's high relative to fruit.
- **Oxygen ingress through wood and bung:** OTR_barrique ≈ 20–40 mg O₂/L/year (**UNVERIFIED**; candidate sources are del Alamo-Sanza & Nevares studies). It scales with S/V and fill, and consumes free SO₂ (`acid-ph-so2.md`). It softens tannins (polymerisation) and stabilises colour (polymeric pigment) in reds; excess means oxidation risk.
- **Evaporative loss** (the angels' share, ~2–5 %/year) means headspace unless topped up. Topping is an automatic Staff task whose quality is set by Staff level. UNVERIFIED range.

### Oak aroma thresholds
Thresholds are listed in `aroma-and-faults.md`.
- cis-oak lactone: ~74 µg/L in red wine; trans: ~320 µg/L. In 12 % ethanol solution: 20 µg/L (cis), 130 µg/L (trans). Source: UC Davis Waterhouse Lab, "Oak Lactones", figures via search snippet; the page itself returned 403 to our fetcher, so re-check.

## 3. Lees ageing and bâtonnage
- **Fine lees contact** (weeks to months): releases mannoproteins and polysaccharides. That adds body and roundness, reduces perceived astringency and oak tannin, and consumes oxygen (it protects against oxidation), with a reduction risk (H₂S) if the lees are not stirred.
- **Bâtonnage** (stirring, e.g. weekly): increases the release rate and cuts the reduction risk, but adds some oxidative exposure.
- **Autolysis aromas** ("bread, biscuit, brioche") build up over months. They're strongest in sparkling wine; subtle in still wine.
- **Model:** `body += a · lees_months · (1 + b·stir)`. Reduction risk ∝ lees_depth × months × (1 − stir). Coefficients UNVERIFIED (**game simplification**).

## 4. Fining and filtration
| Treatment | Purpose | Model effect | Notes |
|---|---|---|---|
| Bentonite | protein (heat) stability in whites | removes protein haze risk; small aroma loss | whites need a protein-stability decision before bottling |
| Gelatin / egg white / PVPP | reduce harsh tannin or phenolics | tannin −5–15 %, colour slightly lower (reds) | magnitudes UNVERIFIED |
| Copper (Cu²⁺) | remove H₂S / mercaptans | cures reduction if applied early | legal limits belong to the law model |
| Coarse / fine filtration | clarity | clarity = bright | — |
| Sterile filtration (0.45 µm) | remove yeast and bacteria | removes refermentation and Brett risk in bottle | essential for wines with residual sugar or no MLF (`fermentation.md`) |

A possible slight aroma or body loss from heavy filtration is debated and modelled as tiny (**game simplification**).

## Inputs and outputs
- **Inputs:** berry phenolic potential and seed maturity from the vineyard, Lot volume, fermentation T(t) and E(t), player decisions (destemming ratio, cold soak days, cap management schedule, extended maceration days, press fraction, vessel/species/toast/fill/months, lees/bâtonnage, fining/filtration).
- **Outputs:** anthocyanins, tannin totals by origin, polymeric pigment, colour density and hue inputs, oak compound concentrations, oxygen dose and body index for the Tasting sheet.

## Calibration

| Check | Expected | Source |
|---|---|---|
| Anthocyanin curve during red fermentation | rises, peaks early, then declines | Sacchi et al. 2005 (qualitative) |
| Seed tannin vs time | small early, grows with ethanol and extended maceration | Sacchi et al. 2005 (qualitative) |
| Riesling 12 months in an old Fuder | oak compounds below thresholds (no oak descriptors) | Derived (S/V ½ of a barrique, fill 0.1) |
| Cabernet 18 months, 60 % new French oak, medium toast | clear vanilla/toast/spice descriptors, oak lactone above threshold | Waterhouse Lab thresholds; concentration ranges UNVERIFIED |
| American vs French oak, same toast | higher lactone ("coconut") with American oak | UC Davis Waterhouse Lab |

## Game simplifications
- Phenolics are five pools. Tannin structure (mDP, galloylation) is not modelled; "grippy vs silky" is a proxy from the seed:skin ratio and polymerisation.
- The oak compound profile uses multipliers, not cooperage-specific data.
- The oxygen transmission rate is constant per vessel type and fill.
- No carbonic maceration model beyond the whole-bunch credit.

## Open questions
- Source red tannin and anthocyanin ranges per variety (Harbertson–Adams data; AWRI).
- Source oak compound concentration ranges by species and toast (candidates: Chatonnet toast studies; AWRI oak trials).
- Source the barrel oxygen transmission rate and the evaporation rate.
- Source cold-soak evidence for the effect size.

## Sources
- Sacchi, K.L., Bisson, L.F., Adams, D.O. (2005). A review of the effect of winemaking techniques on phenolic extraction in red wines. *Am. J. Enol. Vitic.* 56(3):197–206. doi:10.5344/ajev.2005.56.3.197. https://www.ajevonline.org/content/56/3/197.article-info
- UC Davis Waterhouse Lab, "Oak Lactones" (What's in wine). https://waterhouse.ucdavis.edu/whats-in-wine/oak-lactones (threshold figures taken from the indexed page text; the direct fetch was blocked, re-check)
- Waterhouse, A.L., Sacks, G.L., Jeffery, D.W. (2016). *Understanding Wine Chemistry*. Wiley. Standard text for phenolics and oak chemistry; specific numbers not transcribed here are marked UNVERIFIED.
- Chatonnet, P. et al., cooperage and toasting studies (1990s). Cited from memory, **UNVERIFIED**.
- del Alamo-Sanza, M., Nevares, I., barrel oxygen transmission studies. Cited from memory, **UNVERIFIED**.
