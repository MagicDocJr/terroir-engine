# Aroma compounds and wine faults

## Purpose
Tracks about 20 named marker compounds per Lot and Wine (spec A6). It turns their concentrations into perceived aromas via **odour activity values** (OAV = concentration ÷ odour threshold). It also detects faults. These are the main inputs to the Tasting sheet (`tasting-sheet.md`). Every descriptor on the sheet traces back to one or more compounds here, and each compound traces back to the vineyard or cellar history that produced it.

## Perception model
```
OAV_c        = C_c / threshold_c
perceived_c  = 0                               if OAV_c < 1
             = log10(OAV_c) + 1                 otherwise   (Stevens-type compression)
family_f     = Σ_c∈f perceived_c · weight_c
```
- **Masking:** a strong family suppresses weaker ones. For example, high oak lactone masks red fruit, which Waterhouse Lab notes for whisky lactone. High ethanol (> 14 % vol) mutes esters.
- Masking is `perceived_c *= 1 / (1 + m · Σ other strong families)`, with m a **game simplification** (UNVERIFIED).
- **Normal mode** shows descriptors. **Hard mode** (backlog) shows OAVs.

## Marker compounds

| Compound | Descriptor | Threshold (matrix) | Formed by (model hook) | Source for threshold |
|---|---|---|---|---|
| Isoamyl acetate | banana, pear drop | 30 µg/L | fermentation; more at cool temperature and with adequate YAN; hydrolyses over months | Ferreira, López & Cacho 2000 (value cited from memory of their table, UNVERIFIED) |
| Ethyl hexanoate | green apple, fruity | 14 µg/L | fermentation (fatty-acid ethyl esters) | Ferreira et al. 2000 (UNVERIFIED value) |
| Ethyl octanoate | fruity, sweet | 5 µg/L | fermentation | Ferreira et al. 2000 (UNVERIFIED value) |
| β-Damascenone | cooked apple, honeyed, rose | 0.05 µg/L | grape carotenoid precursor, released by fermentation and age | Ferreira et al. 2000 (UNVERIFIED value) |
| Linalool | floral, citrus (Riesling terpenes) | 25 µg/L | grape (free + bound terpenes, released over time) | Ferreira et al. 2000 / Guth 1997 (UNVERIFIED value) |
| Geraniol | rose | ~30 µg/L | grape | UNVERIFIED |
| **TDN** (1,1,6-trimethyl-1,2-dihydronaphthalene) | petrol / kerosene (Riesling) | **2 µg/L** detection (model and neutral white wine); consumers detect ~18–21 µg/L; consumer rejection 82–157 µg/L depending on vintage and country | carotenoid-derived precursors (more with fruit sun exposure and water stress), released slowly with bottle age | Sacks et al. 2012 (J. Agric. Food Chem.); Ross et al. 2014 (Aust. J. Grape Wine Res.) |
| **IBMP** (3-isobutyl-2-methoxypyrazine) | green bell pepper, herbaceous (Cabernet) | **15 ng/L** in red wine (organoleptic threshold) | grape, degraded by sunlight and heat during ripening (vineyard model) | Roujou de Boubée, Van Leeuwen & Dubourdieu 2000 |
| **3MH** (3-mercaptohexan-1-ol) | grapefruit, passion fruit | **60 ng/L** | grape precursors released by yeast during fermentation | Tominaga et al. 1998 |
| **3MHA** (3-mercaptohexyl acetate) | passion fruit, box tree | **4 ng/L** | yeast acetylation of 3MH | Tominaga et al. 1998 (range 0.8–60 ng/L for the thiol group) |
| **4MMP** (4-mercapto-4-methylpentan-2-one) | box tree, blackcurrant bud | **0.8 ng/L** | grape precursor released by yeast | Tominaga et al. 1998; Guth 1997 (4MMP drives Scheurebe) |
| **Rotundone** | black pepper | **8 ng/L** in water | grape; cool seasons (mostly Syrah, minor in our Varieties) | Wood et al. 2008 |
| cis-Oak lactone | coconut, woody | **74 µg/L** in red wine (20 µg/L in 12 % ethanol) | oak (`extraction-and-oak.md`), higher from *Q. alba* | UC Davis Waterhouse Lab "Oak Lactones" |
| trans-Oak lactone | woody | **320 µg/L** in red wine (130 µg/L in 12 % ethanol) | oak | UC Davis Waterhouse Lab |
| Vanillin | vanilla | ~60 µg/L | oak (peaks at medium toast) | UNVERIFIED |
| Guaiacol | smoky, toast | ~10 µg/L | oak (heavy toast); also smoke taint (backlog) | UNVERIFIED |
| Eugenol | clove | ~6 µg/L | oak | UNVERIFIED |
| Furfural | toast, caramel | mg/L range | oak toast | UNVERIFIED |
| Diacetyl | butter | ~0.2–2.8 mg/L (strongly matrix dependent) | MLF (`acid-ph-so2.md`), more with citrate metabolism and early SO₂-free lees | UNVERIFIED |

## How each compound is produced (hooks)
- **Esters:** formed during fermentation; the formation rate rises at 12–16 °C and with adequate YAN, and falls at > 20 °C (volatilisation, lower retention). Acetate esters hydrolyse towards equilibrium over 6–18 months of age (the fresh fruitiness of a young wine fades). Rates UNVERIFIED (**game simplification**).
- **Varietal thiols** (3MH, 4MMP): released from S-conjugate precursors by yeast β-lyase. The conversion yield is low, ~1–5 % (UNVERIFIED). Oxidation and copper destroy them.
- **TDN:** C_TDN(bottle age) = P_TDN · (1 − e^(−k·age_years)). P_TDN rises with fruit sun exposure (canopy Programme, leaf removal) and warm, dry seasons (vineyard model). Young Riesling usually sits below 2 µg/L; aged Riesling can exceed it. The age behaviour is qualitative (Sacks 2012; Ross 2014); k is UNVERIFIED.
- **IBMP:** comes entirely from the vineyard. The cellar only dilutes it (and whole-bunch Cabernet adds it; UNVERIFIED).
- **Terpenes, β-damascenone:** grape-derived, released by acid hydrolysis over time.

## Faults
Each fault has a formation model and a detection rule. A fault above its rejection level forces "Faulty" in the Tasting sheet conclusion.

| Fault | Marker(s) | Detection / legal level | Formation model (drivers) | Source |
|---|---|---|---|---|
| **Volatile acidity** | acetic acid; ethyl acetate | Acetic noticeable from ~0.7 g/L (UNVERIFIED). **EU legal maximum: 18 meq/L (≈ 1.08 g/L as acetic) for white and rosé, 20 meq/L (≈ 1.20 g/L) for red**, with derogations. Ethyl acetate noticeable at ~12 mg/L, spoiled > ~150 mg/L (UNVERIFIED) | acetic bacteria (oxygen, high pH, low SO₂, warm cellar, dry red cap, poor topping), stressed yeast (high sugar), ambient fermentation (ethyl acetate) | Regulation (EU) 2019/934, Annex I Part C |
| **Brettanomyces** | 4-ethylphenol (4-EP), 4-ethylguaiacol (4-EG) | 4-EP threshold range **230–650 µg/L** (preference threshold 650 µg/L); 4-EP : 4-EG ≈ 10 : 1 in contaminated Bordeaux reds | *Brettanomyces/Dekkera* growth: pH > 3.6, molecular SO₂ < 0.5 mg/L, residual sugar > ~0.3 g/L, warm cellar, old barrels, long ageing; hydroxycinnamic acids as precursors | Chatonnet et al. 1992 (JSFA) |
| **Oxidation** | acetaldehyde; browning | acetaldehyde noticeable ~100 mg/L (UNVERIFIED); "bruised apple, nutty"; white colour → gold/brown | oxygen dose (headspace, racking, poor topping, barrel OTR) exceeding free-SO₂ protection; low phenolic buffer in whites | UNVERIFIED |
| **Reduction** | H₂S; methanethiol | H₂S ~1 µg/L; methanethiol ~2 µg/L (UNVERIFIED) | low YAN in fermentation (`fermentation.md` H₂S index); heavy lees without stirring; low oxygen; cured by early aeration or copper | UNVERIFIED |
| **Cork taint** | 2,4,6-trichloroanisole (TCA) | tainted perception possible from **1–2 ng/L**; < 0.5 ng/L negligible; reported olfactometry thresholds 4–10 ng/L (white) and higher in red | only with natural cork closures (a closure choice, see spec A7); per-bottle incidence rate UNVERIFIED | IntechOpen review "State-of-the-Art Knowledge about TCA…" (2022); ScienceDirect topic summary |
| **Refermentation in bottle** | CO₂, haze | any visible haze or spritz | residual sugar > 4 g/L + viable yeast (no sterile filtration) + low molecular SO₂ | `fermentation.md` (derived) |
| **Tartrate crystals** | KHT | visible deposit | KHT unstable and chilled | `acid-ph-so2.md` (derived) |

**Descriptors (textbook cross-check).** Reduction reads as rotten egg, boiled cabbage or drains, and very low levels can add pleasant complexity; an acrid smell of a just-extinguished match points to excess SO₂, not to H₂S. Volatile acidity reads as vinegar or nail-varnish remover [UW-2016 p. 4]. The game names the reduction fault "rotten egg / drains" and slight reduction "flint".

**Deterministic TCA:** spec A7 requires faults to emerge, not be rolled. TCA is inherently a per-bottle event, so it's modelled as an expected **proportion of affected bottles** tied to closure choice and cork grade. It reduces sale value by that fraction and is reported in the P&L, not as a random tasting outcome. **Game simplification.**

## Inputs and outputs
- **Inputs:** vineyard precursor pools (TDN precursor, IBMP, thiol precursors, terpenes), fermentation history (T(t), YAN, yeast type), MLF, oak exposure, lees history, oxygen and SO₂ history, pH, closure, bottle age.
- **Outputs:** a concentration vector, OAVs, perceived families, fault flags with severity, and a cause trail for each compound (the decision and condition IDs from the event log) for the Tasting sheet's "why" links.

## Calibration

| Check | Expected | Source |
|---|---|---|
| Young Mosel Riesling, TDN | < 2 µg/L (no petrol note) in most runs | Sacks et al. 2012 (young Riesling concentrations reported; exact distribution UNVERIFIED) |
| Riesling from a heavily leaf-stripped canopy, 8+ years in bottle | TDN above detection (petrol note) | Qualitative, Sacks 2012 / Ross 2014 |
| Cool-site Cabernet harvested early | IBMP > 15 ng/L (green pepper) | Roujou de Boubée et al. 2000 |
| Warm-site ripe Cabernet | IBMP < 15 ng/L | Roujou de Boubée et al. 2000 (environment effect) |
| High-pH red (3.8), 0.3 mg/L molecular SO₂, 18 months in old barrels | Brett risk flagged (4-EP rising towards threshold) | Chatonnet et al. 1992 drivers (quantitative growth UNVERIFIED) |
| VA in normal runs | < 0.6 g/L; legal limits reached only with neglect | EU 2019/934 limits; normal-range UNVERIFIED |

## Game simplifications
- About 20 compounds, not hundreds. Families aggregate them.
- Thresholds are fixed per matrix (white or red). Real thresholds vary between people and with the wine.
- Masking and synergy use one coefficient.
- No smoke taint (backlog), no mousiness, no geosmin.

## Open questions
- Transcribe the Ferreira et al. (2000) and Guth (1997) threshold tables to verify the ester and terpene rows.
- Source thresholds for vanillin, guaiacol, eugenol, diacetyl, acetaldehyde, H₂S and methanethiol.
- Source a cork-TCA incidence figure for the closure model (or keep TCA in the backlog for the MVP).

## Sources
- Ferreira, V., López, R., Cacho, J.F. (2000). Quantitative determination of the odorants of young red wines from different grape varieties. *J. Sci. Food Agric.* 80:1659–1667.
- Guth, H. (1997). Identification of character impact odorants of different white wine varieties. *J. Agric. Food Chem.* 45(8):3022–3026. https://pubs.acs.org/doi/abs/10.1021/jf9608433. Also: Quantitation and sensory studies of character impact odorants of different white wine varieties. 45(8):3027–3032. https://pubs.acs.org/doi/10.1021/jf970280a
- Sacks, G.L. et al. (2012). Sensory threshold of 1,1,6-trimethyl-1,2-dihydronaphthalene (TDN) and concentrations in young Riesling and non-Riesling wines. *J. Agric. Food Chem.* https://pubs.acs.org/doi/abs/10.1021/jf205203b (PubMed 22397689)
- Ross, C.F. et al. (2014). Odour detection threshold and consumer rejection of TDN in 1-year-old Riesling wines. *Aust. J. Grape Wine Res.* 20(3):335–339.
- TDN sensory thresholds in Riesling wine (2020), *Foods* 9(5):606. https://doi.org/10.3390/foods9050606
- Roujou de Boubée, D., Van Leeuwen, C., Dubourdieu, D. (2000). Organoleptic impact of 2-methoxy-3-isobutylpyrazine on red Bordeaux and Loire wines. *J. Agric. Food Chem.* 48(10):4830–4834.
- Tominaga, T., Furrer, A., Henry, R., Dubourdieu, D. (1998). Identification of new volatile thiols in the aroma of *Vitis vinifera* L. var. Sauvignon blanc wines. *Flavour Fragr. J.* 13(3):159–162.
- Wood, C. et al. (2008). From wine to pepper: rotundone, an obscure sesquiterpene, is a potent spicy aroma compound. *J. Agric. Food Chem.* 56(10):3738–3744. https://pubs.acs.org/doi/10.1021/jf800183k
- Chatonnet, P., Dubourdieu, D., Boidron, J.N., Pons, M. (1992). The origin of ethylphenols in wines. *J. Sci. Food Agric.* 60(2). https://scijournals.onlinelibrary.wiley.com/doi/10.1002/jsfa.2740600205
- UC Davis Waterhouse Lab, "Oak Lactones". https://waterhouse.ucdavis.edu/whats-in-wine/oak-lactones
- Regulation (EU) 2019/934, Annex I Part C (maximum volatile acidity). https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32019R0934
- "State-of-the-Art Knowledge about 2,4,6-Trichloroanisole (TCA) and Strategies to Avoid Cork Taint in Wine", IntechOpen. https://www.intechopen.com/chapters/81659
- [UW-2016] Wine & Spirit Education Trust (2016). *Understanding Wines: Explaining Style and Quality*. London: WSET. ISBN 978-1-905819-39-3. A standard textbook, used to cross-check the learn cards and Causes; page numbers are the printed ones. Paraphrased, never quoted.
