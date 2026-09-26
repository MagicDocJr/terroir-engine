# Soil and water: soil water balance, vine water status, rootstocks, lime-induced chlorosis, Establishment

Science pass, part 1. Status: **draft for review**. Every number has a source or is marked `UNVERIFIED`. Game simplifications are labelled.

## 1. Purpose in the game

Each **Block** has its own soil. From the daily weather this model computes:

- **Root-zone water depletion**, and from it a **water-stress coefficient Ks** and a **stem water potential Ψstem** (the number the Vineyard manager reports and the dashboard shows).
- The effects of water status on growth, yield, berry size and ripening, which feed the vineyard and ripening models.
- **Lime-induced chlorosis risk** from soil chemistry and the chosen rootstock.
- **Young-vine behaviour** during Establishment (shallow roots, sensitivity to drought, reduced crop).

Rootstock choice at Planting changes rooting depth, drought tolerance, vigour and lime tolerance. This is the rootstock lesson from the spec.

## 2. Inputs

| Input | From | Unit |
|---|---|---|
| Daily Tmax, Tmin, Tmean, precipitation P | Historical weather / Synthetic weather, adjusted per Block (see `weather-and-climate.md`) | °C, mm |
| Daily reference evapotranspiration ET0 | Section 4 | mm/day |
| Canopy size (shaded-area fraction or LAI) | Vineyard model (Planting density, training system, canopy Programme) | fraction / m²·m⁻² |
| Irrigation I | Irrigation Programme (only where legal; see the law doc) | mm |
| Soil per Block: texture class, stone fraction, rooting depth, active CaCO₃, easily extractable Fe | Plot data (authored per Block) | class, vol %, m, %, mg/kg |
| Rootstock | Planting | enum |

## 3. Total and readily available water

FAO-56 defines total available water in the root zone as (Allen et al. 1998, eq. 82):

```
TAW = 1000 · (θFC − θWP) · Zr                    [mm]
```

- θFC, θWP: volumetric water content at field capacity and at wilting point [m³·m⁻³]
- Zr: rooting depth [m]

Readily available water is (eq. 83):

```
RAW = p · TAW
```

p is the fraction of TAW a crop can extract before stress starts. For **wine grapes p = 0.45** (FAO-56 Table 22), adjusted for evaporative demand as `p = p_table + 0.04 · (5 − ETc)`, limited to 0.1 ≤ p ≤ 0.8, with ETc in mm/day (FAO-56 ch. 8).

**Stones.** Slate and gravel fragments hold almost no plant-available water. The game scales TAW by the fine-earth fraction:

```
TAW_block = 1000 · (θFC − θWP) · Zr · (1 − f_stone)
```

Game simplification: coarse fragments are treated as holding no available water. This is standard practice, but I have not fetched a primary citation for the linear correction (`UNVERIFIED` citation).

### 3.1 Soil water characteristics by texture

FAO-56 Table 19 gives ranges of θFC and θWP per texture class. **I could not retrieve Table 19 through the web tools**, so the values below are my best recollection of that table and are `UNVERIFIED` until someone checks them against the FAO-56 PDF.

| Texture | θFC (m³/m³) | θWP (m³/m³) | θFC − θWP | Status |
|---|---|---|---|---|
| Sand | 0.07–0.17 | 0.02–0.07 | 0.05–0.11 | UNVERIFIED |
| Loamy sand | 0.11–0.19 | 0.03–0.10 | 0.06–0.12 | UNVERIFIED |
| Sandy loam | 0.18–0.28 | 0.06–0.16 | 0.11–0.15 | UNVERIFIED |
| Loam | 0.20–0.30 | 0.07–0.17 | 0.13–0.18 | UNVERIFIED |
| Silt loam | 0.22–0.36 | 0.09–0.21 | 0.13–0.19 | UNVERIFIED |
| Silty clay loam | 0.30–0.37 | 0.17–0.24 | 0.13–0.18 | UNVERIFIED |
| Silty clay | 0.30–0.42 | 0.17–0.29 | 0.13–0.19 | UNVERIFIED |
| Clay | 0.32–0.40 | 0.20–0.24 | 0.12–0.20 | UNVERIFIED |

The game uses the midpoint of each range per Block. The Plot author can move the value within the range to express local variation.

### 3.2 Rooting depth

FAO-56 Table 22 gives a maximum effective root depth of **1.0–2.0 m** for wine grapes. The game uses Zr = 1.0–2.0 m for mature vines, set per Block by soil depth to rock and modified by rootstock (section 6). Vines on fissured slate can root deeper than the soil layer itself; the game represents that as a larger effective Zr with a high stone fraction (Game simplification).

## 4. Reference evapotranspiration ET0

### 4.1 FAO Penman-Monteith (when full weather is available)

FAO-56 equation 6:

```
ET0 = [0.408 Δ (Rn − G) + γ · 900/(T + 273) · u2 · (es − ea)] / [Δ + γ (1 + 0.34 u2)]
```

The variables and their units are as defined in FAO-56 ch. 2:
- ET0: mm/day
- Rn: net radiation at the crop surface; G: soil heat flux density (both MJ·m⁻²·day⁻¹)
- T: mean daily air temperature at 2 m (°C)
- u2: wind speed at 2 m (m/s)
- es, ea: saturation and actual vapour pressure (kPa)
- Δ: slope of the vapour pressure curve; γ: psychrometric constant (both kPa/°C)

For daily steps G ≈ 0 (FAO-56 ch. 3).

Supporting equations (FAO-56 ch. 3):
- Atmospheric pressure from elevation z (m): `P = 101.3 · ((293 − 0.0065 z)/293)^5.26` [kPa] (eq. 7)
- Psychrometric constant: `γ = 0.665·10⁻³ · P` [kPa/°C] (eq. 8)

### 4.2 Hargreaves fallback (temperature only)

FAO-56 equation 52:

```
ET0 = 0.0023 · (Tmean + 17.8) · (Tmax − Tmin)^0.5 · Ra        [mm/day, Ra in mm/day equivalent]
```

Ra is extraterrestrial radiation (FAO-56 eq. 21, 23–25; J = day of year, φ = latitude in radians):

```
Ra = (24·60/π) · Gsc · dr · [ωs sin φ sin δ + cos φ cos δ sin ωs]   [MJ·m⁻²·day⁻¹]
Gsc = 0.0820 MJ·m⁻²·min⁻¹
dr  = 1 + 0.033 cos(2πJ/365)
δ   = 0.409 sin(2πJ/365 − 1.39)
ωs  = arccos(−tan φ · tan δ)
```

To convert MJ·m⁻²·day⁻¹ to mm/day, multiply by 0.408 (FAO-56 ch. 3; `UNVERIFIED` in this pass, but it's the same 0.408 as in eq. 6).

Game choice: use Penman-Monteith when the Historical weather source supplies radiation, humidity and wind, and Hargreaves otherwise (e.g. simple Synthetic weather).

## 5. Crop coefficient and daily water balance

### 5.1 Crop coefficient

FAO-56 Table 12, wine grapes: **Kc ini = 0.30, Kc mid = 0.70, Kc end = 0.45**, maximum crop height 1.5–2 m. Table and raisin grapes have Kc mid = 0.85.

Vineyard canopies vary far more than the FAO standard crop. Williams & Ayars (2005) showed that grapevine water use and Kc are **linear functions of the shaded area measured beneath the canopy** (and of LAI). The game therefore scales Kc with the canopy:

```
Kc = Kc_soil + b · shaded_fraction_percent
```

`b` (Kc per % shaded area) is **`UNVERIFIED`**. The value 0.017 is widely quoted as Williams & Ayars' slope, but I couldn't open the paper or a source quoting the equation.

The shaded fraction comes from the vineyard model (canopy size at the current stage, row spacing, training system). As a check, a standard VSP vineyard at full canopy should give Kc ≈ 0.7, close to the FAO value.

The inter-row floor adds its own transpiration. A mown cover crop adds `Kc_cover` (`UNVERIFIED`: 0.1–0.3 depending on the floor-management tier); bare cultivated soil adds only surface evaporation after rain (Game simplification).

### 5.2 Daily root-zone balance

FAO-56 equation 85, expressed as depletion Dr (mm below field capacity):

```
Dr,i = Dr,i−1 − (P − RO)i − Ii − CRi + ETc,i + DPi
ETc  = Ks · Kc · ET0
```

- Deep percolation after heavy rain (eq. 88): `DPi = (Pi − ROi) + Ii − ETc,i − Dr,i−1 ≥ 0`
- Capillary rise CR = 0 for vineyard sites (Game simplification).
- Runoff RO: simple infiltration cap `RO = max(0, P − Icap)`, with Icap reduced on steep, bare, clay-rich Blocks (`UNVERIFIED` parameters, tuned so heavy summer storms on the Mosel steep slope partly run off).

### 5.3 Water-stress coefficient

FAO-56 equation 84, for Dr > RAW (Ks = 1 otherwise):

```
Ks = (TAW − Dr) / (TAW − RAW) = (TAW − Dr) / ((1 − p) · TAW)
```

## 6. Vine water status: stem water potential

Players and staff talk in **Ψstem** (midday stem water potential, MPa), because that's what growers measure.

### 6.1 Classes (van Leeuwen et al. 2009)

| Ψstem (MPa) | Water deficit class |
|---|---|
| > −0.6 | None |
| −0.6 to −0.9 | Weak |
| −0.9 to −1.1 | Weak to moderate |
| −1.1 to −1.4 | Moderate to severe |
| < −1.4 | Severe |

van Leeuwen et al. (2009) found that vine water status is a key factor in ripening and vintage quality for red Bordeaux. Weak-to-moderate deficits favour red-wine quality; severe deficits harm it.

### 6.2 From soil water to Ψstem

Suter et al. (2019) showed that Ψstem is explained mostly by soil water availability (via pre-dawn leaf water potential, 66% of variance) plus climatic demand (Tmax) and seasonality. Together these explained 80% of the variance across three cultivars. I don't reproduce their fitted coefficients here, because I could not verify them. The game uses the same structure with its own `UNVERIFIED` coefficients:

```
Ψpd    = Ψpd_wet + (Ψpd_dry − Ψpd_wet) · max(0, (Dr − RAW)/(TAW − RAW))^a
Ψstem  = Ψpd − c_T · max(0, Tmax − 20)
```

| Parameter | Value | Status |
|---|---|---|
| Ψpd_wet | −0.1 MPa | UNVERIFIED |
| Ψpd_dry | −1.2 MPa | UNVERIFIED |
| a | 1.5 | UNVERIFIED |
| c_T | 0.03 MPa/°C | UNVERIFIED |

Calibrate against the classes above. A mature vine on deep soil in a normal Mosel summer should stay in "none" to "weak". A shallow, stony Block in a dry, hot year (e.g. 2018, 2022) should reach "moderate to severe" by August. Unirrigated Napa on shallow hillside soils should reach "moderate to severe" in late summer (all `UNVERIFIED` targets, to be checked by review).

### 6.3 Effects

Direction of each effect: sourced where noted. **Magnitudes are `UNVERIFIED`** and owned by the vineyard and ripening models.

| Ψstem class | Shoot growth | Photosynthesis / sugar loading | Berry size | Notes |
|---|---|---|---|---|
| None | Full; vigorous canopies can over-shade fruit | Normal | Large | Higher botrytis risk through dense canopy (vineyard doc) |
| Weak | Slowing | Normal | Slightly smaller | Favourable for red quality (van Leeuwen et al. 2009) |
| Weak to moderate | Stops | Slightly reduced | Smaller | Favourable for red quality (van Leeuwen et al. 2009) |
| Moderate to severe | Stopped | Reduced | Clearly smaller | Sunburn risk rises on exposed fruit (UNVERIFIED) |
| Severe | Stopped, basal leaf loss | Strongly reduced; **ripening can stall** | Much smaller | Yield loss; lower quality (van Leeuwen et al. 2009) |

## 7. Rootstocks

Rootstocks come from American *Vitis* species that co-evolved with phylloxera. That's why grafted vines resist it (Cox, GWRDC fact sheet). The five MVP choices:

| Rootstock | Parentage | Vigour | Drought tolerance | Active lime tolerated (% CaCO₃) | Max chlorosis index (IPC) | Phylloxera |
|---|---|---|---|---|---|---|
| Own-rooted (*V. vinifera*) | — | Moderate (`UNVERIFIED`) | Moderate (`UNVERIFIED`) | High (`UNVERIFIED`) | — | **Susceptible**: roots are destroyed over years (backlog, multi-vintage) |
| 3309C | *V. riparia* × *V. rupestris* | Low to moderate (Cox) | **Susceptible** (Cox) | 11 (Pavloušek) | 10 (Pavloušek) | Resistant |
| SO4 | *V. berlandieri* × *V. riparia* | Moderate to high (Cox) | Moderately susceptible (Cox); "resistant" (Pavloušek) | 17 (Pavloušek) | 30 (Pavloušek) | Resistant |
| 1103 Paulsen | *V. berlandieri* × *V. rupestris* | Moderate to high (Cox) | **Tolerant** (Cox; Pavloušek) | 17 (Pavloušek) | 30 (Pavloušek) | Resistant |
| Fercal | *V. berlandieri* hybrid (`UNVERIFIED` parentage) | Moderate (`UNVERIFIED`) | Less resistant (Pavloušek) | not given (Pavloušek); commonly quoted as ~40 (`UNVERIFIED`) | **120** (Pavloušek) | Resistant |

**Sources disagree on SO4's drought tolerance.** Pavloušek (2013) lists it as resistant; the GWRDC fact sheet (Cox) lists it as moderately susceptible. The game uses **low to moderate**, which suits the fact sheet's framing of riparia hybrids for cool climates and free-draining soils of moderate depth.

Game parameters derived from the table (magnitudes `UNVERIFIED`):

| Rootstock | Rooting-depth factor on Zr | Drought response (shifts Ψpd_dry) | Vigour factor on shoot growth |
|---|---|---|---|
| Own-rooted | 1.0 | 0 | 1.0 |
| 3309C | 0.8 (fine, shallow roots per Cox) | −0.2 MPa (stresses sooner) | 0.85 |
| SO4 | 0.9 | −0.1 | 1.15 |
| 1103P | 1.25 (thick, plunging roots per Cox) | +0.2 | 1.15 |
| Fercal | 1.0 | 0 | 1.0 |

Riparia × rupestris rootstocks can **hasten ripening** and suit cool climates and moist soils, while berlandieri × rupestris rootstocks have a long vegetative cycle and suit warm, dry sites (Cox). The game applies a small phenology shift: 3309C −2 days, 1103P +2 days to véraison (`UNVERIFIED` magnitudes).

## 8. Lime-induced chlorosis

Iron chlorosis appears on calcareous soils when a rootstock cannot take up enough iron. Its severity depends on active lime and on available iron. The **Indice de Pouvoir Chlorosant** (Juste & Pouget 1972, as given by IFV Occitanie):

```
IPC = 10 000 · (active CaCO₃, %) / (easily extractable Fe, mg/kg)²
```

Risk bands (Triple Performance wiki): **IPC ≤ 10 low**, **10–30 moderate**, **> 30 high to very high**.

Game model (Burgundy limestone Blocks are the main case):

```
r         = IPC_block / IPC_max(rootstock)
chlorosis = clamp((r − 0.8) / 0.8, 0, 1)        # 0 = none, 1 = severe (UNVERIFIED shape)
```

- Chlorosis is aggravated by cold, wet springs, applied as a factor on budburst-to-flowering days with a waterlogged root zone (`UNVERIFIED`).
- Effects: leaf yellowing (visible in 3D), reduced photosynthesis, so less growth, yield and sugar (magnitudes `UNVERIFIED`, owned by the vineyard model).
- Own-rooted *V. vinifera* is treated as lime-tolerant (IPC_max = 60, `UNVERIFIED`).

**The lesson:** 3309C (IPC_max 10) planted in active-lime marl turns yellow; Fercal (IPC_max 120) doesn't.

## 9. Establishment (young vines)

- **Years 1–2:** no usable crop. Year 1 is unlikely to yield grapes. Year 2 brings some fruit, "usually … very small, sour berries that aren't suitable for making wine" (Wine Spectator, Q&A).
- **Year 3 ("third leaf"):** "growers can expect to get a proper yield" (Wine Spectator). On weak vines and low-vigour sites, extension guidance advises reducing the third-leaf crop so the vine establishes well (University of Maryland Extension, via search summary; page not fully read).
- **Quality:** young-vine fruit is often kept out of top wines. Some premium wineries don't use vines younger than about a decade for their top wine (Wine Spectator).

Game model (`UNVERIFIED` numbers, to be reviewed):

| Leaf (year) | Effective rooting depth | Yield fraction of mature potential | Concentration penalty |
|---|---|---|---|
| 1 | 0.3 m | 0 | — |
| 2 | 0.5 m | 0 (fruit removed) | — |
| 3 | 0.8 m | 0.5 | −10% |
| 4 (MVP played Vintage) | 1.0 m or the Block's Zr if smaller | 0.85 | −5% ("young vines" flag) |
| 5+ | Block Zr | 1.0 | 0 |

**Young-vine drought mortality:** if Ψstem < −1.4 MPa for more than 10 days in leaf 1, a fraction of vines dies (`UNVERIFIED`: 2% per extra day, capped at 30%). The replacement cost goes to the P&L. The Mentor mentions it in the Establishment report.

## 10. Calibration

- **Kc:** a full VSP canopy gives Kc ≈ 0.70 (FAO-56 Table 12 standard for wine grapes).
- **ET0 plausibility:** summer Hargreaves ET0 of roughly 3–4 mm/day in the Mosel and 5–7 mm/day in Napa (`UNVERIFIED` ranges; check against Penman-Monteith ET0 from the weather archive).
- **Ψstem trajectories:** see section 6.2 (`UNVERIFIED` targets).
- **Chlorosis:** 3309C on a Côte d'Or marl Block with active lime ≥ 15% must show clear chlorosis; Fercal on the same Block must not.

## 11. Game simplifications (labelled in Study/Normal mode text)

1. One soil layer per Block, with a single TAW. Real soils are layered.
2. Stones hold no available water.
3. No capillary rise, no water table.
4. Runoff is a simple infiltration cap.
5. Ψstem is derived from the soil water balance and Tmax, not from a plant hydraulics model.
6. Phylloxera damage to own-rooted vines is only a warning in the MVP; the multi-year decline is in the backlog.

## 12. Open questions

- Verify FAO-56 Table 19 values against the PDF.
- Verify Williams & Ayars' (2005) Kc-versus-shade slope.
- Find a primary source for Fercal's active-lime tolerance and parentage, and for own-rooted *V. vinifera* lime tolerance.
- Author per-Block soils for the 12 Plots (the regions/law fork owns Plot data).

## Sources

- Allen, R.G., Pereira, L.S., Raes, D., Smith, M. (1998). *Crop evapotranspiration: Guidelines for computing crop water requirements.* FAO Irrigation and Drainage Paper 56. FAO, Rome. Chapters used: [ch. 2](https://www.fao.org/4/x0490e/x0490e06.htm), [ch. 3](https://www.fao.org/4/x0490e/x0490e07.htm), [ch. 6 (Table 12)](https://www.fao.org/4/x0490e/x0490e0b.htm), [ch. 8 (eq. 82–88, Table 22)](https://www.fao.org/4/x0490e/x0490e0e.htm).
- Williams, L.E., Ayars, J.E. (2005). Grapevine water use and the crop coefficient are linear functions of the shaded area measured beneath the canopy. *Agricultural and Forest Meteorology* 132, 201–211. [ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S016819230500153X)
- van Leeuwen, C., Trégoat, O., Choné, X., Bois, B., Pernet, D., Gaudillère, J.-P. (2009). Vine water status is a key factor in grape ripening and vintage quality for red Bordeaux wine. How can it be assessed for vineyard management purposes? *J. Int. Sci. Vigne Vin* 43(3), 121–134. [OENO One](https://oeno-one.eu/article/view/798)
- Suter, B., Triolo, R., Pernet, D., Dai, Z., van Leeuwen, C. (2019). Modeling stem water potential by separating the effects of soil water availability and climatic conditions on water status in grapevine (*Vitis vinifera* L.). *Frontiers in Plant Science* 10:1485. [doi:10.3389/fpls.2019.01485](https://www.frontiersin.org/articles/10.3389/fpls.2019.01485/full)
- Pavloušek, P. (2013). Tolerance to lime-induced chlorosis and drought in grapevine rootstocks. In Vahdati, K., Leslie, C. (eds), *Abiotic Stress: Plant Responses and Applications in Agriculture*. IntechOpen. [Chapter](https://www.intechopen.com/chapters/41400) (Table 4: active lime and CPI; Table 5: drought tolerance)
- Cox, C. (n.d.). *Rootstocks as a management strategy for adverse vineyard conditions.* Fact Sheet, Module 14. Phylloxera and Grape Industry Board of South Australia / GWRDC Water & Vine. [PDF](https://www.wineaustralia.com/getmedia/b6f9712e-d735-432f-95a1-bc82e808771c/Rootstocks-as-a-management-strategy-for-adverse-conditions.pdf)
- Juste, C., Pouget, R. (1972). Appréciation du pouvoir chlorosant des sols par un nouvel indice faisant intervenir le calcaire actif et le fer facilement extractible. *C. R. Acad. Agric. France* 58, 352–357. Cited via IFV Occitanie, [La chlorose ferrique](https://www.vignevin-occitanie.com/fiches-pratiques/la-chlorose-ferrique/) (formula), and AFNOR FD X31-146 (standard method).
- Triple Performance (wiki). [Indice de pouvoir chlorosant (IPC)](https://wiki.tripleperformance.fr/wiki/Indice_de_pouvoir_chlorosant_(IPC)) (risk bands)
- Wine Spectator. [How long does it take a new vineyard to yield grapes?](https://www.winespectator.com/articles/how-long-does-it-take-a-new-vineyard-to-yield-grapes)
- University of Maryland Extension. [Crop Management](https://extension.umd.edu/resource/crop-management) (third-leaf crop reduction on weak vines)
