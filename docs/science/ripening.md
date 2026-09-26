# Ripening: sugar, acids, phenolics, aroma precursors, and the harvest decision

Status: draft, science pass (M1). Terms follow `CONTEXT.md`. `UNVERIFIED` marks numbers I could not confirm against a source in this pass.

## 1. Purpose

From veraison to harvest, compute daily per Block:
- sugar concentration and sugar per berry
- berry weight
- malic and tartaric acid, TA, potassium (pH is computed in the winemaking/acid doc)
- phenolic ripeness: seeds, skin tannin, anthocyanins in red Varieties
- aroma precursors: IBMP (pyrazine), TDN precursors (Riesling), thiol precursors

The player uses these to choose a **harvest date per Block**, the central explicit decision of the vintage (spec §5.2). In Normal mode, lab values are exact and free, updated weekly while the grapes ripen (spec §6).

## 2. Timeline inputs

- **Veraison date** comes from the phenology doc (GFV model, Parker et al.).
- **Thermal time** here means growing degree days, base 0 °C, counted from veraison, unless stated otherwise. That matches the base used by Parker's GFV and GSR models.
- **Calibration of ripening speed per Variety:** the **Grapevine Sugar Ripeness (GSR)** model gives, for 65 cultivars, the thermal time (base 0 °C, from 1 April in the northern hemisphere) needed to reach target sugar concentrations of 170–220 g/L (Parker et al. 2020). The engine is tuned so that under average conditions each Variety reaches 200 g/L at its GSR thermal time.

## 3. Sugar

### 3.1 Sugar loading per berry

Sugar arrives through the phloem from veraison until loading stops at a plateau. In a berry population the accumulation curve is sigmoid, because veraison is not uniform across berries (the berry sugar-loading concept, Deloire and co-workers). After the plateau, **°Brix can keep rising only because the berry loses water**. A rising °Brix doesn't prove the berry is still importing sugar (*Active and passive changes in sugar concentration during grape ripening*, AJEV 76(2), 2025).

**Game model:**

```
S(t)   = S_max · ripeningCapacity · waterFactor / (1 + exp(−k_s · (TT − TT50)))       g sugar per berry
W(t)   = berry fresh weight (g): grows after veraison to W_peak, then declines once loading stops (§3.3)
C(t)   = S(t) / W(t) · juiceFactor                                                     → g/L sugar in juice
```

| Parameter | Meaning | Value | Status |
|---|---|---|---|
| S_max | sugar per berry at plateau under ideal conditions | Variety berry weight × ~0.24 g/g | `UNVERIFIED` |
| TT50 | thermal time from veraison to half of the plateau | tuned per Variety to match GSR 200 g/L timing | GSR values `UNVERIFIED`, see §9 |
| k_s | steepness | ≈ 0.006 per °C·day | `UNVERIFIED` |
| ripeningCapacity | leaf area to fruit ratio (canopy doc §2.2), 0.4–1.1 | | canopy doc |
| waterFactor | 1 for none to moderate stress; 0.4 when severe (canopy doc §4) | | canopy doc |
| juiceFactor | converts g/g of berry to g/L of juice | ≈ 1.1–1.2 | `UNVERIFIED` |

**Temperature:** loading slows in cool weather (the thermal-time clock runs slower) and in extreme heat (> 35 °C days pause loading, `UNVERIFIED`). Cloudy weather lowers photosynthesis: **Game rule:** `k_s` scales with daily radiation relative to normal, 0.7–1.1 (`UNVERIFIED`).

### 3.2 Units

The acid/must doc owns the exact conversions. For the dashboard: °Oe = (SG − 1) × 1000. The Brix↔SG relation used in brewing and winemaking is SG = 1 + Brix / (258.6 − (Brix / 258.2) × 227.1) (standard formula, `UNVERIFIED` source to cite in the must doc). A useful rule of thumb: 80 °Oe ≈ 19.3 °Brix, 90 °Oe ≈ 21.6 °Brix, 100 °Oe ≈ 23.8 °Brix.

### 3.3 Dehydration after the plateau (hang time)

Once net import stops, water loss through the skin and back-flow to the vine shrink the berry. That raises °Brix/°Oe (the "concentration" effect) while **the amount of juice falls**:

```
dW/dt = −W · r_dehyd          r_dehyd = r0 · (1 + a · VPD_kPa) · f(berry shrivel onset)       %/day
r0 ≈ 0.1–0.3 %/day (cool, humid Mosel autumn) · rises to ≈ 0.5–1 %/day (hot, dry Napa)      UNVERIFIED
```

Consequences shown to the player:
- sugar concentration up
- yield (kg and L) down by the same factor
- acid also concentrates, but continued respiration (§4) usually wins in warm weather
- botrytis susceptibility keeps rising (disease doc §5.2)

Noble rot (disease doc §5.5) speeds up dehydration strongly. That's the route to Beerenauslese and TBA sugar levels.

## 4. Acids and potassium

### 4.1 Malic acid

Malic acid builds up before veraison, then falls during ripening as the berry respires it. The fall is faster in warm conditions. Malic enzyme activity rose steadily with temperature between 10 and 46 °C, while malic accumulation in immature berries peaked at 20–25 °C (Lakso & Kliewer 1975). Elevated temperature speeds up malate loss in ripening berries via NAD-dependent malic enzyme (Sweetman et al. 2014, Shiraz). This is why **cool nights and a large diurnal range keep malic acid**, and why warm sites give flabby, low-acid grapes unless picked early.

**Game model** (malic per berry, g):

```
dM/dt = −k_m · M · Q10 ^ ((T_hourly − 20) / 10)          integrated hourly (or with daily mean plus a night-temperature term)
k_m ≈ 0.02 per day at 20 °C;  Q10 ≈ 2.0                      UNVERIFIED (tune to calibration §9)
malic_g_L = M / W · juiceFactor
```

The Q10 form captures the published direction (faster loss when warmer). The parameter values are `UNVERIFIED` and must be tuned to the harvest calibration targets.

**Exposure effect:** sun-exposed bunches run warmer than shaded ones, so their malic acid falls faster (canopy doc §2.3 `exposure` → a berry temperature offset).

### 4.2 Tartaric acid

Tartaric acid is made before veraison and is **roughly constant per berry** during ripening. Its concentration falls mainly through dilution as the berry grows, then rises slightly with dehydration. (Standard viticulture; Keller 2020, cited from memory.)

```
tartaric_g_L = T_berry_g / W · juiceFactor              T_berry_g fixed at veraison per Variety
```

### 4.3 Titratable acidity

TA (g/L as tartaric) ≈ tartaric + malic × 1.12, because malic acid's equivalent weight is 67.04 vs 75.04 for tartaric. Both acids are diprotic; the acid doc's charge-balance solver refines TA at the endpoint used. **Potassium** partially neutralises the acids (it forms salts), which lowers TA and **raises pH**.

### 4.4 Potassium and pH

Berry potassium accumulates during ripening. High soil K, vigorous rootstocks, shaded canopies and hot conditions give **high-K, high-pH** musts. Warm sites combine that with low malic acid, so Napa Cabernet reaches pH 3.6–3.9 at harvest, while Mosel Riesling stays around 2.9–3.2.

```
K_berry(t) = K_veraison · (1 + k_k · TT_from_veraison) · rootstockKFactor · soilK
```

`UNVERIFIED` parameters. The acid doc computes pH from tartaric, malic, K and the other ions.

## 5. Phenolic ripeness

### 5.1 Seeds

Seeds turn from green to brown after veraison as their tannins oxidise and polymerise. Their extractable tannin **decreases markedly**: Kennedy, Matthews & Waterhouse (2000) found that seed tannin quantity falls following second-order kinetics during ripening (Shiraz). Green seeds give harsh, green, astringent tannin in the wine; brown, lignified seeds give much less.

```
seedMaturity (0 green → 1 brown/lignified) = 1 − 1 / (1 + k_seed · TT_from_veraison)          (second-order-like decay of extractable seed tannin)
seedTanninExtractable = seedTannin_veraison · (1 − seedMaturity)
```

`k_seed` is `UNVERIFIED`. Tune it so that seeds are ~brown when sugar is near the Variety's typical harvest level in a normal year.

### 5.2 Skin tannin

Skin tannin is mostly formed before veraison. During ripening its **extractability** and softness increase, which is why tannins taste riper in late-picked fruit. **Game model:** `skinTanninExtractability = 0.4 + 0.6 · ripenessProgress` (`UNVERIFIED`).

### 5.3 Anthocyanins (Pinot Noir, Cabernet Sauvignon)

Anthocyanins start at veraison and accumulate towards a plateau, sometimes declining late. Heat reduces them: at a 35 °C daily maximum, total anthocyanins in Cabernet Sauvignon fell to less than half of those at a 25 °C maximum (Mori et al. 2007). Moderate sun exposure and moderate post-veraison water deficit increase them.

```
dA/dt = r_a(T_berry) · (A_max_variety − A) · lightFactor · waterFactor_post − degradation(T_berry > 35 °C)
r_a(T) peaks at 15–25 °C berry temperature and falls towards zero at 35 °C          (UNVERIFIED shape, consistent with Mori et al. 2007)
```

| Variety | A_max (mg/g berry) | Status |
|---|---|---|
| Pinot Noir | ≈ 0.5–0.9 (and only non-acylated anthocyanins, so colour is less stable) | `UNVERIFIED` values; the acylation fact is standard |
| Cabernet Sauvignon | ≈ 1.0–1.8 | `UNVERIFIED` |

## 6. Methoxypyrazines (IBMP): green pepper and leafy character

IBMP (3-isobutyl-2-methoxypyrazine) matters in **Cabernet Sauvignon** (and Sauvignon Blanc and Cabernet Franc, outside the MVP). It is negligible in Riesling, Chardonnay and Pinot Noir. Key findings:
- IBMP accumulates **before veraison** and declines afterwards. The concentration two weeks before veraison correlated highly with the level at harvest, which suggests that **cluster light exposure mainly affects accumulation, not the post-veraison breakdown** (Ryona et al. 2008, Cabernet Franc).
- Light intensity **before**, not during, ripening determines IBMP at harvest in Cabernet Sauvignon (Koch et al. 2012).
- Cool seasons and dense, shaded canopies give more IBMP. Warm seasons give less. (Standard; see also the 2012 AJEV modelling paper in Sources.)

The sensory threshold is in the low ng/L range: ~2 ng/L in water and higher in red wine (`UNVERIFIED` exact value, often quoted ~10–15 ng/L in red wine).

**Game model:**

```
IBMP_veraison = IBMP_base_variety · (1 + 1.5 · (1 − exposure_preveraison)) · coolFactor      coolFactor = 1 + 0.03 · (20 − T_mean_preveraison)   (UNVERIFIED)
IBMP(t)       = IBMP_veraison · exp(−k_p · TT_from_veraison)                                  k_p is NOT increased by post-veraison leaf removal (Ryona 2008)
```

| Variety | IBMP_base (ng/L juice) | Status |
|---|---|---|
| Cabernet Sauvignon | 20–40 at veraison, 2–15 at harvest | `UNVERIFIED` |
| Others in the MVP | ≈ 0 | standard |

**Teaching point for the advisor:** "Leaf removal *before* veraison lowers green-pepper character in Cabernet; stripping leaves in September does little for pyrazines, but it does risk sunburn."

## 7. TDN precursors (Riesling "petrol")

TDN (1,1,6-trimethyl-1,2-dihydronaphthalene) comes from carotenoid breakdown. The grape holds bound precursors, and free TDN mostly develops in the **bottle with age and low pH** (winemaking doc). Vineyard factors that raise the **precursor potential**:
- **sun exposure of the bunches**, especially early in the season: leaf removal timing changed C13-norisoprenoid and carotenoid concentrations in Riesling (Kwasniewski et al. 2010)
- warm, sunny sites and water stress (standard; `UNVERIFIED` magnitudes)

```
TDNpotential = TDN_base · (1 + 1.2 · exposure_early + 0.5 · exposure_late) · (1 + 0.3 · stressIndex) · warmthFactor        (UNVERIFIED coefficients; early > late per Kwasniewski 2010)
```

The Tasting sheet links a petrol note back to this cause ("petrol note ← high fruit-zone exposure after early leaf removal", spec §3.2).

## 8. Thiol precursors

Volatile thiols (3MH, 3MHA: grapefruit, passion fruit) are released from odourless precursors during fermentation. Among the MVP Varieties, Riesling can show some 3MH. Precursors rise late in ripening and respond to vine nitrogen status and stress. **Game simplification:** a single `thiolPotential` per Block, from Variety × nitrogen status × late-ripening days. Magnitudes are `UNVERIFIED`; this is a minor effect for the MVP Varieties, and the release happens in the winemaking doc.

## 9. Per-Variety parameters

| Parameter | Riesling | Chardonnay | Pinot Noir | Cabernet Sauvignon | Status |
|---|---|---|---|---|---|
| GSR thermal time to 200 g/L (°C·d, base 0 °C from 1 April) | ≈ 2,850 | ≈ 2,700 | ≈ 2,650 | ≈ 3,050 | `UNVERIFIED` (my estimate; take real values from Parker et al. 2020, Table S) |
| Ripening group | mid-late | early-mid | early | late | standard |
| Tartaric at veraison (g/L equiv.) | 7–9 | 6–8 | 6–8 | 6–7 | `UNVERIFIED` |
| Malic retention (lower k_m multiplier) | high (×0.8) | medium (×1.0) | medium (×1.0) | medium-low (×1.1) | `UNVERIFIED` |
| Anthocyanin potential | – | – | low | high | standard direction |
| IBMP potential | ≈ 0 | ≈ 0 | ≈ 0 | high | standard |
| TDN potential | high | low | low | low | standard (TDN is characteristic of Riesling) |
| Botrytis compactness multiplier | 1.3 | 1.2 | 1.4 | 0.8 | disease doc, `UNVERIFIED` |

"Plant any Variety anywhere" (spec §4.1) works through these numbers. Cabernet Sauvignon on the Mosel won't reach its GSR thermal time in most years, so it stays high in acid and IBMP, with low sugar and green seeds. That is the correct, science-based failure.

## 10. The harvest decision

Every day in the harvest window, the dashboard shows for each Block:

| Signal | What it measures | Direction with hang time |
|---|---|---|
| **Technological ripeness** | °Oe/°Brix vs the target for the intended style and Legal category; TA; (pH from the acid doc) | sugar ↑ (import, then dehydration); TA ↓ (malic respiration) |
| **Phenolic ripeness** (red Varieties, plus seed and skin maturity for whites) | seedMaturity, skin-tannin extractability, anthocyanin plateau, IBMP below threshold | ↑ then plateau; anthocyanins may drop in heat |
| **Aroma** | TDN potential (Riesling), fresh-fruit vs ripe-fruit balance | Game simplification: aroma ripeness peaks near phenolic ripeness |
| **Risk** | botrytis probability over the forecast (disease doc), rain forecast, sunburn in heatwaves, yield lost to dehydration | ↑ |
| **Logistics** | crew hours needed vs available; Winery tank space | – |

In warm sites sugar often runs ahead of phenolic ripeness. Waiting for ripe seeds means high sugar (high alcohol), low acid and high pH. In cool sites and years it's the opposite: waiting for sugar risks rot and autumn rain. The staff advisor explains that trade-off using only the uncertain forecast (ADR 0002, spec §5.4).

**Staff advice formula (Game model).** For candidate harvest days d = today … today + 10, run the Block forward on forecast ensembles and score:

```
score(d) = w_style · styleMatch(sugar, TA, pH at d)
         + w_phen  · phenolicRipeness(d)
         − w_rot   · E[rot fraction at d]
         − w_yield · E[yield loss from dehydration and rot]
         − w_logistics · crewShortfall(d)
```

A Senior staff member evaluates more ensemble members and a longer horizon than a Junior (spec §5.4). The weights depend on the declared **style target** of the eventual Wine. `UNVERIFIED` weights; this is a design tool, not a physical model.

## 11. Calibration targets (harvest composition, typical years)

| Region / Variety / style | Sugar | TA (g/L) | pH | Status |
|---|---|---|---|---|
| Mosel Riesling, Kabinett style | 70–85 °Oe | 8–10 | 2.9–3.1 | `UNVERIFIED`; the legal minimum must weights are in the law doc |
| Mosel Riesling, Spätlese / Auslese | 80–100+ °Oe | 7.5–9.5 | 3.0–3.2 | `UNVERIFIED` |
| Côte d'Or Chardonnay | 21–23 °Brix (≈ 12.5–13.5 % potential alcohol) | 6–8.5 | 3.2–3.4 | `UNVERIFIED` |
| Côte d'Or Pinot Noir | 21.5–23.5 °Brix | 5.5–7.5 | 3.3–3.6 | `UNVERIFIED` |
| Napa Cabernet Sauvignon (valley floor or bench) | 24–27 °Brix | 5.5–7 | 3.6–3.9 | `UNVERIFIED`; check against the California Grape Crush Report (District 4 average °Brix) |
| Veraison → harvest, cool climate | 45–65 days | | | `UNVERIFIED` |
| Veraison → harvest, warm climate | 40–55 days | | | `UNVERIFIED` |
| Heat effect on anthocyanins | a 35 °C maximum gives < ½ the anthocyanins of a 25 °C maximum | | | verified, Mori et al. 2007 |

## 12. Game simplifications

1. Sigmoid sugar loading per berry with a single plateau, plus a separate dehydration term.
2. Malic respiration uses a Q10 temperature law.
3. Seed maturity is one index, not individual seed chemistry.
4. Aroma precursors are single indices per Block.
5. The harvest-advice score is a design heuristic.

## Sources

- Parker AK, García de Cortázar-Atauri I, Gény L, et al. (2020). *Temperature-based grapevine sugar ripeness modelling for a wide range of Vitis vinifera L. cultivars.* Agricultural and Forest Meteorology 285–286:107902. (The GSR model: base 0 °C from 1 April, thermal time to 170–220 g/L for 65 cultivars. The author list after the first two and the page are cited from memory.)
- Parker AK et al. (2020). *Adaptation to climate change by determining grapevine cultivar differences using temperature-based phenology models.* OENO One. https://oeno-one.eu/article/view/3861
- *Active and passive changes in sugar concentration during grape ripening* (2025). American Journal of Enology and Viticulture 76(2). https://www.ajevonline.org/content/76/2/0760019
- Deloire A. et al. *The concept of berry sugar loading.* https://www.researchgate.net/publication/284691480_The_concept_of_berry_sugar_loading (bibliographic details to confirm)
- Lakso AN, Kliewer WM (1975). *The influence of temperature on malic acid metabolism in grape berries. I. Enzyme responses.* Plant Physiology 56(3):370–372. doi:10.1104/pp.56.3.370. https://academic.oup.com/plphys/article/56/3/370/6074448
- Sweetman C, Sadras VO, Hancock RD, Soole KL, Ford CM (2014). *Metabolic effects of elevated temperature on organic acid degradation in ripening Vitis vinifera fruit.* Journal of Experimental Botany 65(20):5975–5988. https://academic.oup.com/jxb/article/65/20/5975/2485421
- Kennedy JA, Matthews MA, Waterhouse AL (2000). *Changes in grape seed polyphenols during fruit ripening.* Phytochemistry 55:77–85. https://www.sciencedirect.com/science/article/abs/pii/S0031942200001965
- Mori K, Goto-Yamamoto N, Kitayama M, Hashizume K (2007). *Loss of anthocyanins in red-wine grape under high temperature.* Journal of Experimental Botany 58(8):1935–1945. doi:10.1093/jxb/erm055
- Ryona I, Pan BS, Intrigliolo DS, Lakso AN, Sacks GL (2008). *Effects of cluster light exposure on 3-isobutyl-2-methoxypyrazine accumulation and degradation patterns in red wine grapes (Vitis vinifera L. cv. Cabernet Franc).* Journal of Agricultural and Food Chemistry 56:10838–10846. https://pubmed.ncbi.nlm.nih.gov/18942833 (the co-author list after Ryona and the page range are cited from memory)
- Koch A, Ebeler SE, Williams LE, Matthews MA (2012). *Fruit ripening in Vitis vinifera: light intensity before and not during ripening determines the concentration of 2-methoxy-3-isobutylpyrazine in Cabernet Sauvignon berries.* Physiologia Plantarum. https://onlinelibrary.wiley.com/doi/10.1111/j.1399-3054.2012.01572.x
- *Modeling impacts of viticultural and environmental factors on 3-isobutyl-2-methoxypyrazine in Cabernet franc grapes* (2012). American Journal of Enology and Viticulture 63(1):94. https://www.ajevonline.org/content/63/1/94
- Kwasniewski MT, Vanden Heuvel JE, Pan BS, Sacks GL (2010). *Timing of cluster light environment manipulation during grape development affects C13 norisoprenoid and carotenoid concentrations in Riesling.* Journal of Agricultural and Food Chemistry 58(11):6841–6849. https://pubs.acs.org/doi/abs/10.1021/jf904555p
- Waterhouse Lab, UC Davis. *TDN (1,1,6-trimethyl-1,2-dihydronaphthalene).* https://waterhouse.ucdavis.edu/whats-in-wine/tdn-116-trimethyl-12-dihydronapthalene (page returned 403 in this pass; used only as a pointer)
- Standard references, cited from memory: Keller M., *The Science of Grapevines* (3rd ed., 2020); Jackson RS, *Wine Science* (5th ed.); Ribéreau-Gayon P. et al., *Handbook of Enology* Vol. 1–2.
