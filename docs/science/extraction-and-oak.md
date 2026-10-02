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

  **Evidence (Pinot Noir).** Cool-climate Pinot Noir was microvinified destemmed, with 100 % of the stems added back, and with 30 %, 60 % and 100 % whole bunches. The stems-added, 60 % and 100 % wines had significantly more tannin and monomeric phenolics but less anthocyanin, and more compounds with green/vegetative, spicy, woody and medicinal aromas (IBMP, IPMP, eugenol, ethyl cinnamate, phenol). The 30 % whole-bunch wine showed no significant rise in methoxypyrazines, and the tannin rise is reported only for the stems-added, 60 % and 100 % wines (Wimalasiri et al. 2021). The potassium/pH and intracellular-fermentation effects listed above remain uncited.
  **Textbook cross-check.** Uncrushed berries partly ferment inside the berry, which gives fresher, brighter fruit and a silkier texture, and the stems must be ripe, or their tannin tastes bitter and green [UW-2016 p. 64]. The game models only the stem side (game simplification, labelled on the learn card).

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

### Oak evidence: size, reuse, toast and oxygen
From the review by Carpena et al. (2020) and the studies it cites:
- Large barrels exchange fewer compounds with the wine, because they have less wood surface per volume of wine.
- Use exhausts a barrel. The compounds most depleted are furanic aldehydes, phenolic alcohols and aldehydes (vanillin among them) and oak lactones; even after only 6–9 months, wines aged in new and in once-used barrels differ clearly in most oak compounds. A barrel's oxygen transfer also falls with each use as the wood's pores clog.
- Toasting adds smoky flavour as its intensity rises, by breaking down carbohydrates (to furanic compounds) and lignin (to volatile phenols). Data on light toasting and lactones are contradictory. In French, American and Spanish oak, toasting strongly raised volatile phenols, furanic aldehydes and phenyl ketones, while its effect on oak lactones depended on species and origin (Cadahía et al. 2003).
- American oak (*Q. alba*) is the classic source of whisky (oak) lactones, which give coconut and woody aromas.
- Barrels let a little oxygen in (first estimates 15–45 mg/L a year). This natural micro-oxygenation drives polymerisation and condensation of flavonoids, stabilising colour and modifying astringency.

**Game model note:** the toast multipliers in the Winery model (vanillin highest at medium-plus, oak lactone lower at heavy toast, guaiacol and furfural rising with toast) follow these directions; their sizes are `UNVERIFIED`.

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
- **Evidence (review by Fornairon-Bonnefond et al. 2002):**
  - Dead yeast in the lees break down by autolysis, slowly under wine conditions (in traditional-method sparkling wine only after a 6–12 month lag). They release peptides, amino acids, polysaccharides (mainly mannoproteins), lipids and nucleic acids; stirred lees release even more mannoproteins.
  - Lees are strongly reductive: wine kept on its total lees soon develops reduced, sulphury smells unless it is clarified, and this is harder to manage in large vats than in barrels. Stirring re-balances a barrel's redox potential by dissolving oxygen, preventing both reduction near the lees and oxidation at the surface.
  - Lees consume oxygen (up to about 4 mg/L in a model wine with 4 % lees) and act as antioxidants, also in reds.
  - Lees-aged white wines are more stable against protein haze (a mannoprotein fragment, MP32) and tartrate crystals.
  - Lees fix some wood aromas (volatile phenols, oak lactones), and yeast enzymes transform vanillin, so lees limit the "woody" character of barrel-aged wine.
  - Winemakers credit lees with "body" and "roundness", but a direct effect of the yeast polysaccharides on roundness has never been shown conclusively.
  - Textbook teaching is plainer: fine-lees contact and stirring give a richer, rounder texture [UW-2016 pp. 49, 61–62]. The learn card and Cause name texture as the practical effect and say its mechanism is still debated.
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

## Cap-management task (game simplification)

When a red Lot starts fermenting, the Cellar master posts a cap-management **Task**: the player works the cap at the tank in 3D (pump-over, punch-down, délestage, gentle) or keeps the plan. It is due 2 days after fermentation start (`UNVERIFIED` window); the choice sets the Lot's existing `Cap management` option, which stays changeable during the fermentation (§1).

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
- Wimalasiri, P.M., Olejar, K.J., Harrison, R., Hider, R.C., Tian, B. (2021). Whole bunch fermentation and the use of grape stems: effect on phenolic and volatile aroma composition of *Vitis vinifera* cv. Pinot Noir wine. *Australian Journal of Grape and Wine Research* 28(3):395–406. doi:10.1111/ajgw.12535
- Carpena, M., Pereira, A.G., Prieto, M.A., Simal-Gandara, J. (2020). Wine aging technology: fundamental role of wood barrels. *Foods* 9(9):1160. doi:10.3390/foods9091160 (open access, PMC7555037)
- Cadahía, E., Fernández de Simón, B., Jalocha, J. (2003). Volatile compounds in Spanish, French, and American oak woods after natural seasoning and toasting. *J. Agric. Food Chem.* 51:5923–5932. doi:10.1021/jf0302456
- Fornairon-Bonnefond, C., Camarasa, C., Moutounet, M., Salmon, J.-M. (2002). New trends on yeast autolysis and wine ageing on lees: a bibliographic review. *Journal International des Sciences de la Vigne et du Vin* 36(2):49–69. doi:10.20870/oeno-one.2002.36.2.974
- Chatonnet, P. et al., cooperage and toasting studies (1990s). Cited from memory, **UNVERIFIED**.
- del Alamo-Sanza, M., Nevares, I., barrel oxygen transmission studies. Cited from memory, **UNVERIFIED**.
- [UW-2016] Wine & Spirit Education Trust (2016). *Understanding Wines: Explaining Style and Quality*. London: WSET. ISBN 978-1-905819-39-3. A standard textbook, used to cross-check the learn cards and Causes; page numbers are the printed ones. Paraphrased, never quoted.
