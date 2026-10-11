# Canopy, fruit set, yield and vineyard labour

Status: draft, science pass (M1). Terms follow `CONTEXT.md`. `UNVERIFIED` marks numbers I could not confirm against a source in this pass.

## 1. Purpose

Model per Block:
- how much leaf area the vines carry and how exposed the fruit is (which drives ripening, aroma precursors, sunburn and disease)
- how many grapes set and grow (yield)
- how water stress changes both
- how many labour hours each vineyard task costs (for the labour and canopy Programmes)

## 2. Canopy

### 2.1 Leaf area

Leaf area per vine grows with shoot number and thermal time after budburst:

```
shoots          = buds_retained · budburst_fraction                       (budburst_fraction ≈ 0.85–0.95, UNVERIFIED)
leafArea_shoot  = LAmax_shoot · (1 − exp(−k_la · GDD_since_budburst))      m² per shoot (GDD base 10 °C)
leafArea_vine   = shoots · leafArea_shoot · (1 − defoliation) · (1 − diseaseLeafLoss) − hedgingRemoved
LAI             = leafArea_vine · vines_per_ha / 10 000                   m² leaf per m² ground
```

| Parameter | Value | Status |
|---|---|---|
| LAmax_shoot (primary + laterals, vigorous site) | 0.25–0.45 m² per shoot | `UNVERIFIED`; scales with vigour (soil water, rootstock) |
| k_la | ≈ 0.004 per °C·day | `UNVERIFIED`; tune so shoot growth levels off after flowering |
| Typical LAI, VSP / Einzelpfahl | 1–3 | `UNVERIFIED`, standard range |

**Vigour** multiplies `LAmax_shoot`: deep, fertile, moist soil or a vigorous rootstock (1103 Paulsen, 140 Ruggeri) raises it; shallow slate, drought, or a low-vigour rootstock (3309C, 101-14) lowers it (`UNVERIFIED` multipliers 0.7–1.3). The rootstock table lives in the Planting doc.

### 2.2 Leaf area to fruit ratio (the ripening capacity)

For single-canopy training systems (VSP, Guyot, Cordon, Einzelpfahl), **0.8–1.2 m² of leaf area per kg of fruit** gives maximum sugar, berry weight and colour at harvest. Horizontally divided canopies need 0.5–0.8 m²/kg (Kliewer & Dokoozlian 2005). The ripening doc scales sugar loading with this ratio:

```
LAFR = effectiveLeafArea_vine / crop_kg_vine
ripeningCapacity = clamp(LAFR / 1.0, 0.4, 1.1)          (1.0 m²/kg ≈ middle of the single-canopy range)
```

`ripeningCapacity` below 1 slows sugar loading and lowers the sugar plateau. That's why over-cropping ripens poorly, a core WSET lesson.

### 2.3 Fruit exposure and fruit-zone microclimate

Light reaching the bunches follows canopy density (Beer–Lambert extinction):

```
exposure = exp(−k_ext · LAI_fruitzone)        k_ext ≈ 0.5–0.7 (UNVERIFIED), LAI_fruitzone = leaf layers around the bunches
```

`exposure` (0–1) feeds:
- **Ripening doc:** TDN precursors (↑ with exposure), IBMP (↓ with pre-veraison exposure), anthocyanins (↑ with moderate exposure, ↓ when berries overheat), malic acid (↓ faster in exposed, warmer fruit)
- **Disease doc:** fruit-zone wetness multiplier `= 1 + 0.5 · (1 − exposure)` (`UNVERIFIED`)
- **Sunburn** (§2.5)

### 2.4 Canopy Programme tiers

**Game simplification:** one tier per Block bundles shoot thinning, shoot positioning and tying, hedging and fruit-zone leaf removal (spec §5.1). Leaf removal **side** and **timing** are explicit choices, since they're classic WSET decisions.

| Tier | Shoot thinning | Hedging | Fruit-zone leaf removal | Effect | Labour multiplier |
|---|---|---|---|---|---|
| Low | none | once | none | dense canopy, low exposure (~0.2), more disease, lower TDN, higher IBMP | 0.6 |
| Medium | light | twice | one side, moderate | exposure ~0.45 | 1.0 |
| High | thorough | as needed | both sides or targeted, early | exposure ~0.7, driest fruit zone, highest sunburn risk | 1.6 |

Exposure values and multipliers are `UNVERIFIED` placeholders for calibration.

**Leaf removal choices:**
- **Side.** In the northern hemisphere, the **morning (east) side** gets gentle morning sun, which is safe. The **afternoon (west) side** faces the hottest part of the day and carries the sunburn risk. On north–south rows this matters most. On east–west rows the exposed side is south-facing.
- **Timing.** Early (pre-bloom to fruit set) or late (around veraison). Early removal lets berries acclimate, with thicker skins and more protective compounds, so they tolerate exposure later. Late removal on shade-grown fruit before a heatwave is the classic sunburn scenario (Gambetta et al. 2021). Early removal also increases Riesling TDN potential more than late removal (Kwasniewski et al. 2010; ripening doc §7).

### 2.5 Sunburn

Sunburn is a heat-induced disorder that needs **direct exposure** plus a **high berry surface temperature**. Susceptibility depends on the berry's acclimation and the cultivar (Gambetta et al. 2021). Experiments found that for shade-grown berries early in development, a surface temperature of about **46–47 °C for > 60 min** was enough to cause damage. Longer exposure needed lower temperatures, but 60 and 90 minutes differed only marginally (47.8 vs 47.1 °C). Wind lowers bunch temperature, and vines under water deficit were *less* susceptible after defoliation (Frontiers in Plant Science 2023, 14:1145274).

**Game formula** (per sunny hour on the exposed side):

```
T_berry   = T_air + ΔT_sun · exposure_side · (1 − 0.08 · wind_ms)                 ΔT_sun ≈ 10–15 °C in full sun (UNVERIFIED)
threshold = 46 °C  (not acclimated)   |   48.5 °C  (acclimated by early leaf removal or since fruit set)     (UNVERIFIED acclimation offset)
damage   += fraction of exposed bunches · clamp((hours above threshold) / 2, 0, 1)
```

Sunburned berries lose weight and give bitter, "cooked" and phenolic off-characters. **Game rule:** they carry a quality penalty into the Lot unless sorted out.

### 2.6 Leaf shape by Variety (ampelography; look only)

The 3D vines draw each Variety's mature leaf from its ampelographic description (paraphrased; the official French
variety catalogue, Plantgrape: INRAE / Institut Agro Montpellier). Leaf shape is how growers tell varieties apart in
the field, a WSET-level curiosity that the 3D view lets you see:

| Variety | Mature leaf (paraphrased) | How the game draws it |
|---|---|---|
| Riesling | circular, five or seven lobes, deep U-shaped lateral sinuses, petiole-sinus lobes overlapping, medium teeth, slightly goffered | five clearly separated lobes, closed petiole sinus |
| Chardonnay | circular, entire or with five lobes, slightly open petiole sinus whose edge is often formed by the bare veins, short straight-sided teeth | an almost entire blade with shallow notches and an open U-shaped petiole sinus |
| Pinot Noir | dark green, entire or three to five lobes, petiole sinus slightly open or closed, short teeth, strongly blistered and twisted | a rounder, darker, heavily blistered blade with shallow lobes |
| Cabernet Sauvignon | circular, seven or nine lobes, club- or U-shaped lateral sinuses, petiole-sinus lobes slightly overlapping, convex teeth, blistered | deeply cut lobes with club-shaped sinuses; the game draws the upper sinuses closed over near the rim, leaving a hole (**game's drawing**: the "hole-punched" look is often described for this variety, but the cited catalogue entry does not describe it) |

Popular summaries sometimes call the Riesling leaf "more or less entire"; the game follows the official catalogue.
**Game simplification:** one idealised leaf per Variety; real leaves vary on a vine, with vigour and between clones,
and older varieties such as Pinot Noir vary a lot in lobing (Tassie 2010). Generated by
`game/tools/blender/build_leaf_atlas.py`.

### 2.7 Training systems: Einzelpfahl, Guyot and Cordon

The training system is a Planting choice: it lays out the vine's permanent wood for its whole life (spec §4.3).

- **Einzelpfahl (Moselpfahl, single stake).** Each vine gets its own wooden stake, 1.5–1.8 m tall, on a trunk of about 50 cm. One to four canes are bent into round bows and tied to the stake; two bows make the typical "heart". Three to five summer shoots are tied up to become next year's canes and the others are topped just above the bunches. The system survives on the steep slopes of the Mosel, Ahr and Mittelrhein, where growers now cut only one or two bows for quality reasons (Weincampus Neustadt, *Historische Rebzeile*). It needs no wires. Where the slope is beyond tractors (direct traction stops at about 60 %), every task is done by hand: about 1,600 h/ha a year on terraced steep slopes against about 400 h/ha with direct traction (§6, Olejnizak).
- **Cane pruning (Guyot) and spur pruning (Cordon).** Spur pruning cuts one-year canes back to short spurs of one or two buds along a permanent horizontal arm (the cordon). Cane pruning lays a new one-year cane along the fruiting wire every winter, from the vine's head. Spur pruning is easy to mechanise completely; cane pruning is difficult to mechanise, needs fewer cuts, and the canes must be tied to the wire (Hickey & Hatch 2021).
- **Bud fruitfulness by position.** The basal (non-count) buds of *Vitis vinifera* cultivars are often not fruitful, and in French cultivars (Chardonnay, Pinot noir, Cabernet franc, Merlot) bud fertility was greater at positions 4–10 than at positions 1–3 (Hickey & Hatch 2021, summarising recent research). Spur pruning keeps only basal buds, so a variety whose basal buds bear poorly is cane-pruned.
- **Law.** Côte d'Or village and Premier Cru rules allow Guyot simple or spur/cordon pruning, with at most 8 buds per vine (law doc §3).
- **Ripening capacity does not depend on the system's name.** All three are single canopies, which need 0.8–1.2 m² of leaf per kg of fruit to ripen it fully (§2.2, Kliewer & Dokoozlian 2005). Horizontally divided canopies, not offered in the game, need less.
- **Textbook cross-check.** A cordon is easier to mechanise but slower to establish; cane pruning needs a large skilled workforce [UW-2016 p. 34]. Staking canes up a single stake opens the fruit to light and air, and on the steepest slopes kit is hauled by winch [UW-2016 p. 108].

**Game model.** The training system sets (1) the maximum buds per vine (Einzelpfahl 26, Guyot 24, Cordon 24; design values from the §3.1 ranges, `UNVERIFIED`; Guyot's 24 is a double Guyot of two canes of up to 12, so at low densities the three bud loads stay apart: before 2026-10-10 the cap was 16, and at Carneros' 3,800 vines/ha Low, Balanced and High all gave 16 buds), (2) whether machine harvesting is possible (never on Einzelpfahl or on slopes of 30 % or more, a game threshold more cautious than the 60 % direct-traction limit; economy doc §4.3) and (3) the planting cost (economy doc §3). **Game simplification:** bud fruitfulness by position and differences in canopy microclimate between systems are not modelled; for the same leaf area and crop, Guyot and Cordon vines ripen alike.

## 3. Yield components

```
crop_kg_vine = shoots · clusters_per_shoot · berries_per_cluster · berry_weight_g / 1000
yield_kg_ha  = crop_kg_vine · vines_per_ha · (1 − bunchLoss_disease) · (1 − sunburnLoss) · youngVineFactor
wine_hl_ha   ≈ yield_kg_ha · juice_yield_L_per_kg / 100             juice_yield ≈ 0.65–0.75 L/kg (UNVERIFIED; winemaking doc owns press yields)
```

### 3.1 Bud load at pruning (explicit choice, spec §5.2)

| Training system | Typical buds per vine | Notes |
|---|---|---|
| Einzelpfahl (single stake, two bows) | 2 bows × 8–12 buds | Mosel steep slopes; `UNVERIFIED` range |
| Guyot (cane, VSP) | single: 1 cane × 8–12 + 1–2 spur buds; double: 2 canes | `UNVERIFIED` |
| Cordon (spur, VSP) | 6–10 spurs × 2 buds | `UNVERIFIED` |

The player picks **Low / Balanced / High** bud load, translated into buds per vine for the Block's density and system. Higher bud load means more yield, a lower leaf-area-to-fruit ratio (§2.2), and slower, lower sugar.

### 3.2 Fruitfulness (clusters per shoot)

Inflorescence primordia form in the latent buds **during the previous season**, around flowering. Temperature and light on the buds then set next year's fruitfulness. **Model:** `FruitfulnessNext = clamp(1 + 0.04·T_anom + 0.30·(E − 0.45), 0.85, 1.15)`, where `T_anom` is the Block's mean temperature from flowering to 25 days after, minus its 1991–2020 mean for the same days, and `E` is the mean fruit-zone exposure over the same window. It multiplies next season's clusters per shoot. Direction from Buttrose (1969): bunch primordia per bud rise with light intensity, and with temperature from barren buds at 20 °C to a maximum between 30 and 35 °C (controlled conditions). Coefficients `UNVERIFIED`. The first Vintage uses 1.0 (no previous cropping season). Growers estimate fruitfulness in winter by dissecting buds; the game's January message reports this factor as that estimate.

### 3.3 Variety table

| Variety | Clusters per shoot | Berries per cluster | Berry weight at harvest (g) | Cluster weight (g) | Compactness | Status |
|---|---|---|---|---|---|---|
| Riesling | 1.5–2.0 | 70–110 | 1.2–1.5 | 80–150 | compact | `UNVERIFIED` |
| Chardonnay | 1.5–2.0 | 80–120 | 1.2–1.6 | 100–180 | medium-compact | `UNVERIFIED` |
| Pinot Noir | 1.5–2.0 | 70–110 | 1.0–1.4 | 80–130 | compact | `UNVERIFIED` |
| Cabernet Sauvignon | 1.3–1.8 | 90–130 | 0.9–1.2 | 100–150 | loose | `UNVERIFIED` |

These are standard-reference orders of magnitude, cited from memory (Robinson, Harding & Vouillamoz, *Wine Grapes*; Keller, *The Science of Grapevines*).

**Model values (calibrated 2026-09-28):** Pinot Noir 1.5 bunches per shoot × 75 berries (≈ 90 g bunches at 1.2 g berries), Chardonnay 1.55 × 85 (≈ 120 g). Burgundy anchors: a typical Côte d'Or Pinot Noir bunch weighs about 100 g, ≈ 130 g in a generous year such as 2023 (Robert Parker Wine Advocate, Côte d'Or 2022–23 report); at 10,000 vines/ha three 100 g bunches per vine make ≈ 22 hL/ha, and a 35 hL/ha grand cru is ≈ 0.5 kg of fruit per vine (Robert Parker Wine Journal, *What is a yield*). The per-shoot figures sit at the low end of the ranges above because Burgundy growers thin out surplus shoots (ébourgeonnage) on high-density vines. Riesling and Cabernet Sauvignon are unchanged. The qualitative points are standard WSET knowledge: Cabernet has small, thick-skinned berries; Pinot Noir has thin skins and compact bunches.

### 3.4 Fruit set, coulure and millerandage

A normal share of flowers set as berries. Poor weather during flowering causes:
- **Coulure:** flowers or young berries drop. It follows cold, cloudy, rainy weather (or out-of-season heat) that leaves the vine short of carbohydrate during flowering.
- **Millerandage:** berries set but stay small and seedless ("hens and chicks"), giving clusters with mixed berry sizes. Yield falls, but the small berries concentrate sugar, acid and phenolics.

Flowering goes best at around 15 °C or warmer and dry (the coulure summaries cited below).

**Game formula** (over the flowering window from the phenology doc):

```
set_fraction = base_set_variety · f_temp · f_rain · f_carb
f_temp  = clamp((T_mean_flowering − 10) / (17 − 10), 0.3, 1.0)                 (UNVERIFIED shape: poor below ~15 °C, good ≥ 17 °C)
f_rain  = 1 − 0.04 · rain_days_in_window  (floor 0.6)                          (UNVERIFIED)
f_carb  = clamp(0.6 + 0.4 · leafArea_at_flowering / leafArea_needed, 0.6, 1) (UNVERIFIED)
berries_per_cluster = nominal · set_fraction / base_set_variety
millerandage_share  = 0.5 · (1 − f_temp) · (variety_millerandage_prone)       (shot berries: ~⅓ normal weight, higher sugar, UNVERIFIED)
```

| Variety | base_set | Prone to coulure / millerandage | Status |
|---|---|---|---|
| Riesling | 0.5 | low / low | `UNVERIFIED` |
| Chardonnay | 0.45 | medium / **high** (millerandage is well known in Chardonnay) | `UNVERIFIED` |
| Pinot Noir | 0.45 | medium / medium | `UNVERIFIED` |
| Cabernet Sauvignon | 0.5 | low / low | `UNVERIFIED` (classic coulure varieties are Merlot and Grenache, not in the MVP) |

### 3.5 Young vines (Establishment)

Leaf 1 is the planting year. **Game simplification** (spec §3.1), using typical grower practice (`UNVERIFIED`):

| Leaf | youngVineFactor (share of full crop) | Quality modifier |
|---|---|---|
| 1–2 | 0 (fruit removed) | – |
| 3 | 0.3–0.5 (the first crop is often thinned) | concentration −10 % |
| 4 | 0.8 | concentration −5 %, flagged "young vines" |
| ≥ 5 | 1.0 | no quality bonus for older vines |

**Vine age and quality:** the game does not make older vines give better wine. In a Barossa Shiraz study, well-maintained old and young vines in the same vineyard did not differ in yield or basic grape composition (Grigg et al. 2018), so a bonus would teach something the evidence does not support.

A drought in the planting year kills a share of the young vines (`UNVERIFIED`: 10–30 % losses without irrigation in a dry first summer). Replanting costs money and delays those vines.

### 3.6 Carbohydrate reserves (multi-vintage)

Starch stored in roots and trunk feeds budburst, early shoot growth and flowering until the new leaves export sugar. A crop that is large for the leaf area, a harvest so late that the leaves have little time to refill the reserves, and early leaf loss (downy mildew, drought, frost) all deplete them. In defoliated Chardonnay, lower root and trunk reserves went with up to 50 % fewer inflorescences per shoot and flowers per inflorescence the next year (Bennett et al. 2005; review: Holzapfel et al. 2010).

**Model (at 1 January, for Blocks in their 4th leaf or older):**
- `cropLoad` = kg fruit per vine ÷ (0.55 × peak leaf area per vine), the inverse of the ripening model's leaf-area-to-fruit ratio (§2.2); ≈ 1.0 is balanced (Kliewer & Dokoozlian 2005: 0.8–1.2 m² per kg).
- `postHarvestDays` = days from harvest to leaf fall.
- `defoliation` = peak downy leaf % + 0.4 × peak powdery leaf % (as fractions) **before harvest or leaf fall**, + 0.01 per severe water-stress day, capped at 0.9. Late-season infection after the harvest does not count against the reserves (it still counts for next spring's inoculum, disease.md §10).
- `seasonR = clamp(1 − 0.20·max(0, cropLoad/1.2 − 1) − 0.10·max(0, 1 − postHarvestDays/30) − 0.60·max(0, defoliation − 0.20) + 0.05·max(0, 1 − cropLoad/0.6), 0.70, 1.05)`. Vines compensate for moderate leaf loss through lateral growth and higher photosynthesis in the remaining leaves (Candolfi-Vasconcelos & Koblet 1990), so leaf loss only counts above 20 % (`UNVERIFIED` threshold); normal farming (Balanced bud load, Medium tiers, timely harvest) then keeps reserves near 1.0.
- `Reserves = clamp(0.4·Reserves_prev + 0.6·seasonR, 0.70, 1.05)`: vines recover over more than one year.
- Next season: shoot leaf-area growth × (0.8 + 0.2·Reserves); fruit-set ratio × min(1, Reserves).

All coefficients `UNVERIFIED`. **Calibration (measured 2026-09-28 after the review fix, 10 consecutive Vintages 2011–2020, Balanced bud load except the Côte d'Or's Low, Medium tiers, scripted harvest):**

| Plot | Mean yield (hL/ha) | Year-to-year CV |
|---|---|---|
| Mosel Seitental | 75 | 20 % |
| Mosel Blauschiefer | 70 | 15 % |
| Côte d'Or Village | 37 | 23 % |
| Côte d'Or Premier Cru | 38 | 22 % |
| Napa Rutherford Bench | 84 | 4 % |
| Napa Carneros (Pinot Noir, Chardonnay) | 68 | 6 % |

Carneros re-measured 2026-10-10 (`sim yieldcheck napa-carneros 2008 10`, Vintages 2011–2020) after the Guyot cap rose from 16 to 24 buds per vine: Balanced is now 21 buds per vine (two canes) instead of the capped 16, and the mean went from 53 to 68 hL/ha (2.0 → 2.6 kg per vine, ≈ 9.4 t/ha), inside the valley-floor range of §7. The other rows are unchanged (their Balanced bud loads were below the cap). The Mosel and Côte d'Or spreads fall in the expected 15–30 % band (`UNVERIFIED` band); irrigated Napa varies less, as expected. The low years have causes in the weather (Mosel 2017 frost, Côte d'Or 2020 heat and drought). The Côte d'Or overshoot found here (≈ 56 hL/ha) was fixed by the Pinot Noir and Chardonnay yield components (§3.3); the table shows the recalibrated values.

### 3.7 Task windows (game simplification)

The staff turn the explicit choices into dated **Tasks** (tasks-in-3d design). The windows follow standard practice; the exact day counts are game simplifications (`UNVERIFIED`):

| Task | Opens | Due (the plan applies if the player does nothing) | Why this window |
|---|---|---|---|
| Winter pruning | 15 January | 1 March, or budburst if earlier | pruning is done in dormancy and must be finished before the buds burst |
| Leaf removal | the Block's fruit set | fruit set + 25 days (≈ bunch closure) | the early window of §2.4 runs from pre-bloom to fruit set; commercial fruit-zone leaf removal usually continues to bunch closure (Keller 2020, cited from memory). The game opens the task at fruit set and closes it at about bunch closure, all before véraison, so it counts as the early option; "later, at véraison" is the late option. **Game simplification:** no pre-bloom task. |
| Green harvest | the Block's véraison | véraison + 21 days, or harvest | thinning at véraison, when the crop can be judged and the rest still ripens |

The pruning options use the words of the Block's training system (§3.1 bud table): Guyot canes, Cordon spurs (the buds per vine shown as two-bud spurs, buds ÷ 2), Einzelpfahl bows. The 3D close-up draws the three options fanned from the demonstration vine's head, each with the option's buds per vine at a fixed spacing (7.5 cm of cane per bud, a look value), so more buds is visibly more wood: Guyot as one cane of up to 12 buds or, above that, two canes one each way along the wire (double Guyot), with a renewal spur of 2 buds at the head; Cordon as the two permanent arms (0.6 m each) carrying the option's two-bud spurs, half on each arm and evenly spaced, so more spurs sit closer together; Einzelpfahl as two bows sharing the buds. The labels name the bud load and what it means on this vine ("Balanced · 2 canes · 8 + 8 buds"), because the sim's words (short, medium, long cane) depend on the density. **Game simplification:** the alternatives are fanned up from the head so they can be compared and clicked; the chosen cane is laid on the fruiting wire on confirm, the others fall.

Only the Vintage's first message of each task kind stops time; later openings of the same kind (other Blocks, other Lots) arrive as normal messages. Ordering a Block's harvest closes its open green-harvest task: once picking has started there is nothing left to thin.

After a decision the estate's vineyard crew (two or three people: 12 / 16 / 24 hours a day at Low / Medium / High labour) works the Block for `ceil(area × hours per ha / crew hours)` days (1–10), with 80 h/ha for pruning, 40 for leaf removal and 30 for green harvest (`UNVERIFIED` design values; visual only, the effect of the choice is immediate).

### 3.8 Green harvest: what thinning can and cannot do

Cluster thinning raises the leaf area per kg of fruit, so it helps ripening only where the vine is over-cropped: once the ratio is inside the 0.8–1.2 m²/kg range of §2.2, more leaf per kg adds little. In a three-year Finger Lakes Riesling trial (thinned to 1, 1.5 or 2 clusters per shoot, against unthinned vines), thinning raised soluble solids at harvest (18.2 °Brix unthinned vs 22.3 °Brix at one cluster per shoot in 2008), but had little or no effect on berry size, pH, titratable acidity, pruning weight or cluster light exposure. Consumers sorted the low-crop wines apart by aroma in 2008 and 2009. The grower's net return fell sharply: grape prices would have had to rise by up to 143 % to recoup the loss (Preszler, Schmit & Vanden Heuvel 2013).

**Textbook cross-check.** Thinning is done shortly after véraison. Mistimed, the vine can enlarge the remaining berries, which partly restores the yield and dilutes the flavour, and a firm link between low yield and quality is hard to show [UW-2016 p. 37]. Too few buds push vigour; too many leave the crop unripe [UW-2016 p. 37].

**Game model:** thinning at véraison removes 20 % or 40 % of the berries per vine (§3.7), which raises the leaf-area-to-fruit ratio and so `ripeningCapacity`, up to its cap of 1.1 (§2.2). Thinning is also a legal tool: Côte d'Or village and Premier Cru wines have yield limits (law doc §3).

## 4. Water stress

Vine water status comes from the soil water balance (weather/soil doc). Measured as midday **stem water potential (Ψstem)**, it is the best field indicator (Choné et al. 2001). The classification for wine grapes (van Leeuwen et al. 2009):

| Ψstem (MPa) | Water constraint |
|---|---|
| > −0.6 | none |
| −0.6 to −0.9 | weak |
| −0.9 to −1.1 | weak to moderate |
| −1.1 to −1.4 | moderate to severe |
| < −1.4 | severe |

**Effects by timing (Game formula; the directions are standard viticulture, the multipliers `UNVERIFIED`):**

| Period | Effect of stress | Multiplier |
|---|---|---|
| Flowering → veraison | Berry cell expansion is reduced, so **berries stay smaller for good**. Shoot growth slows (less vigour, more open canopy) | final berry weight × (1 − 0.25 · stressIndex_pre) |
| Veraison → harvest, weak to moderate | Little effect on sugar loading; red Varieties gain colour and concentration; balance improves | anthocyanin × (1 + 0.15 · stressIndex_post), until stress turns severe |
| Any time, severe (< −1.4 MPa) | Stomata close, **photosynthesis and sugar loading stall**, leaves yellow and drop, sunburn risk rises with less canopy cover | ripeningCapacity × 0.4; leaf loss 1 %/day |

```
stressIndex = clamp((−0.6 − Ψstem) / (1.4 − 0.6), 0, 1)       0 at −0.6 MPa, 1 at −1.4 MPa
```

Irrigation (where legal) is the lever. Napa can irrigate; Mosel and Côte d'Or are effectively rain-fed in the MVP, and the law doc owns the exact rules.

## 5. Inputs

Budburst and phenology dates, daily weather, soil water (Ψstem), rootstock and vigour, Planting density and training system, bud load, canopy Programme tier with leaf-removal side and timing, disease leaf loss, Variety parameters, vine age (leaf).

## 6. Labour (for the labour Programme)

Steep-slope viticulture is far more labour-intensive. A German study reports about **1,600 h/ha per year for terraced steep slopes vs about 400 h/ha where tractors can work in direct traction**. Direct traction stops at around 60 % slope even in good conditions (Olejnizak, FH Mainz diploma thesis, via landentwicklung.de). That gap is why the "very steep slate terraces" Plot is expensive to run.

**Per-task breakdown (Game model; the totals are anchored to the source, the split is `UNVERIFIED`):**

| Task | Flat, mechanised (h/ha) | Steep, manual Einzelpfahl (h/ha) |
|---|---|---|
| Winter pruning + removing prunings | 60 | 250 |
| Tying bows or canes | 25 | 150 |
| Shoot thinning, positioning, tying up | 50 | 300 |
| Hedging / topping | 10 | 120 |
| Leaf removal (Medium tier) | 15 | 100 |
| Spraying (10 passes; steep: monorack, helicopter or drone) | 15 | 120 |
| Floor / weed management | 25 | 150 |
| Harvest, hand picking | 150 | 350 |
| Harvest, machine (flat only) | 5 | – |
| Maintenance (stakes, wires, repairs) | 50 | 60 |
| **Total (hand harvest)** | **≈ 400** | **≈ 1,600** |

Crew hours available per week come from the labour Programme tier. When a task isn't finished in its window, the model applies the consequences the spec describes (spec §5.1):
- late shoot thinning → denser canopy (lower exposure) and less effective spraying
- slow harvest → grapes hang longer (dehydration, acid loss, botrytis risk)

Staff level scales efficiency (Junior −10 %, Senior +10 %, `UNVERIFIED`).

## 7. Calibration

| Target | Range | Status |
|---|---|---|
| Leaf-area-to-fruit ratio for full ripening, single canopy | 0.8–1.2 m²/kg | Kliewer & Dokoozlian 2005 (verified) |
| Mosel Riesling, balanced bud load, 4th leaf+ | ≈ 60–110 hl/ha (steep slopes lower than flat riverbank) | `UNVERIFIED`; the law doc sets the legal maximum |
| Côte d'Or Village / Premier Cru Pinot Noir, mature vines | ≈ 38–50 hl/ha mean (base yield for village reds 40 hl/ha; 0.5–0.65 kg per vine at 10,000 vines/ha) | base yield: BIVB appellation sheets; per-vine figures: Robert Parker Wine Journal. Test `CoteDor_MatureVines_AverageNearTheBaseYield` (frost-free mature Vintages, ≈ 41 hl/ha); all 2012–2020 Vintages including frost years ≈ 37 hl/ha |
| Napa valley-floor Cabernet | ≈ 3–5 short tons/acre (≈ 7–11 t/ha) | `UNVERIFIED` |
| Sunburn onset (shade-grown berries, > 60 min) | ≈ 46–47 °C berry surface | verified, Frontiers 2023 |
| Coulure year (cold, wet flowering) | yield −20 to −50 % in prone Varieties | `UNVERIFIED` |

## 8. Game simplifications

1. One canopy Programme tier bundles several operations; leaf-removal side and timing are separate choices.
2. Fruitfulness is an initial condition in the MVP.
3. Young-vine yields follow a fixed table.
4. Labour per task uses fixed hours per hectare anchored to published totals.

## Sources

- Weincampus Neustadt (DLR Rheinpfalz / Hochschule), *Historische Rebzeile: alte Reberziehungen vor Einführung des Drahtrahmens* (2021), slide "Einzelpfahlerziehung (Moselpfahl)". https://www.weincampus-neustadt.de/fileadmin/user_upload/Historische_Erziehungsformen.pdf (read 2026-10-02)
- Hickey C, Hatch T (2021, updated 28 June 2021). *Dormant Cane and Spur Pruning in Bunch Grape Vineyards.* Penn State Extension. https://extension.psu.edu/dormant-cane-and-spur-pruning-in-bunch-grape-vineyards (read 2026-10-02)
- Preszler T, Schmit TM, Vanden Heuvel JE (2013). *Cluster thinning reduces the economic sustainability of Riesling production.* American Journal of Enology and Viticulture 64(3):333–341. doi:10.5344/ajev.2013.12123
- Robert Parker Wine Journal, *What is a yield?* https://winejournal.robertparker.com/what-is-a-yield (bunches per vine and hl/ha at Burgundy densities)
- Robert Parker Wine Advocate, *Burgundy: the Côte d'Or's 2023 and 2022 vintages.* https://www.robertparker.com/articles/2cydkNouFEz7YC24D/burgundy-the-cte-dors-2023-and-2022-vintages (≈ 100 g typical bunch, ≈ 130 g in 2023)
- Bourgogne wines (BIVB), appellation sheets: base yield 40 hl/ha for village reds (e.g. Beaune). https://www.bourgogne-wines.com
- Buttrose MS (1969). *Fruitfulness in grapevines: effects of light intensity and temperature.* Botanical Gazette 130(3):166–173. https://www.journals.uchicago.edu/doi/10.1086/336486
- Bennett J, Jarvis P, Creasy GL, Trought MCT (2005). *Influence of defoliation on overwintering carbohydrate reserves, return bloom, and yield of mature Chardonnay grapevines.* American Journal of Enology and Viticulture 56(4):386–393. https://www.ajevonline.org/content/56/4/386
- Holzapfel BP, Smith JP, Field SK, Hardie WJ (2010). *Dynamics of carbohydrate reserves in cultivated grapevines.* Horticultural Reviews 37:143–211. https://onlinelibrary.wiley.com/doi/10.1002/9780470543672.ch3
- Candolfi-Vasconcelos MC, Koblet W (1990). *Yield, fruit quality, bud fertility and starch reserves of the wood as a function of leaf removal in* Vitis vinifera *— evidence of compensation and stress recovering.* Vitis 29(4):199–221. https://ojs.openagrar.de/index.php/VITIS/article/view/5455
- Grigg D, Methven D, De Bei R, Rodríguez López CM, Dry P, Collins C (2018). *Effect of vine age on vine performance of Shiraz in the Barossa Valley, Australia.* Australian Journal of Grape and Wine Research 24(1):75–87. https://onlinelibrary.wiley.com/doi/10.1111/ajgw.12312
- Kliewer WM, Dokoozlian NK (2005). *Leaf area/crop weight ratios of grapevines: influence on fruit composition and wine quality.* American Journal of Enology and Viticulture 56(2):170–181. doi:10.5344/ajev.2005.56.2.170. https://www.ajevonline.org/content/56/2/170
- van Leeuwen C, Tregoat O, Choné X, Bois B, Pernet D, Gaudillère JP (2009). *Vine water status is a key factor in grape ripening and vintage quality for red Bordeaux wine. How can it be assessed for vineyard management purposes?* Journal International des Sciences de la Vigne et du Vin 43(3):121–134. https://oeno-one.eu/article/view/798 (the thresholds are verified; the full author list is cited from memory)
- Choné X, van Leeuwen C, Dubourdieu D, Gaudillère JP (2001). *Stem water potential is a sensitive indicator of grapevine water status.* Annals of Botany 87:477–483. (Volume and pages cited from memory.)
- Plantgrape, the catalogue of grapevine varieties and clones cultivated in France (INRAE, Institut Agro Montpellier, IFV): Riesling https://www.plantgrape.fr/en/varieties/fruit-varieties/236 · Chardonnay …/60 · Pinot noir …/218 · Cabernet-Sauvignon …/43 (adult-leaf identification descriptions, accessed 2026-09-29)
- Tassie E (2010). *Vine identification – knowing what you have.* Fact sheet, Grape and Wine Research and Development Corporation (Australia), August 2010. https://www.wineaustralia.com/getmedia/21669eff-05de-41d9-9ef8-283b1e01edcb/201008-Vine-identification.pdf (leaf descriptors: lobes, sinuses, teeth, naked petiole sinus of Chardonnay; lobing varies within Pinot Noir)
- Gambetta JM, Holzapfel BP, Stoll M, Friedel M (2021). *Sunburn in grapes: a review.* Frontiers in Plant Science 11:604691. https://pmc.ncbi.nlm.nih.gov/articles/PMC7819898/
- *Wind speed, sun exposure and water status alter sunburn susceptibility of grape berries* (2023). Frontiers in Plant Science 14:1145274. https://www.frontiersin.org/journals/plant-science/articles/10.3389/fpls.2023.1145274/full
- Kwasniewski MT, Vanden Heuvel JE, Pan BS, Sacks GL (2010). *Timing of cluster light environment manipulation during grape development affects C13 norisoprenoid and carotenoid concentrations in Riesling.* Journal of Agricultural and Food Chemistry 58(11):6841–6849. https://pubs.acs.org/doi/abs/10.1021/jf904555p
- Olejnizak S. Diploma thesis, Fachhochschule Mainz (Geoinformatik und Vermessung), on terracing in steep-slope viticulture. https://www.landentwicklung.de/fileadmin/sites/Landentwicklung/Dateien/Forschung/Diplomarbeit_Stephan_Olejnizak.pdf (1,600 h/ha terraced steep slope vs 400 h/ha direct traction; 60 % slope limit for direct traction)
- Coulure and millerandage summaries: https://en.wikipedia.org/wiki/Coulure (definitions and weather causes; a tertiary source to replace with a primary one, see open questions)
- Standard references, cited from memory: Keller M., *The Science of Grapevines* (3rd ed., 2020); Smart R., Robinson M., *Sunlight into Wine* (1991); Robinson J., Harding J., Vouillamoz J., *Wine Grapes* (2012).
- [UW-2016] Wine & Spirit Education Trust (2016). *Understanding Wines: Explaining Style and Quality*. London: WSET. ISBN 978-1-905819-39-3. A standard textbook, used to cross-check the learn cards and Causes; page numbers are the printed ones. Paraphrased, never quoted.
