# Alcoholic fermentation

## Purpose
Turns a Lot's must into wine inside the Winery: sugar consumption, ethanol production, yeast growth and death, heat release and tank temperature, and the emergent failure states (sluggish or stuck fermentation, H₂S). The model also covers the player's decision to stop fermentation early for residual sugar, as in Mosel Kabinett and feinherb styles. It runs on the hourly sub-step (spec §3.3) for every Lot being fermented.

Related models: `acid-ph-so2.md` (SO₂, pH, MLF), `extraction-and-oak.md` (red maceration runs in parallel), `aroma-and-faults.md` (esters, H₂S, VA formed here).

## Conventions and conversions

| Quantity | Formula | Notes |
|---|---|---|
| Must weight °Oechsle | °Oe = (SG₂₀ − 1) × 1000 | SG = specific gravity at 20 °C. Definition. |
| °Brix from °Oe (game approximation) | °Brix ≈ 0.22 × °Oe + 1.7 | Linear fit, valid ±0.3 °Brix over 60–130 °Oe (80 °Oe → 19.3 °Brix, 100 °Oe → 23.7 °Brix). **Game simplification**: the real relation follows the ICUMSA sucrose tables. UNVERIFIED: re-check the fit against a published °Oe/°Brix table before calibration. |
| Sugar g/L from °Brix | S ≈ 10 × SG × °Brix − 25 | Removes ~non-sugar solids. Gives ~183 g/L at 19.3 °Brix and ~236 g/L at 23.7 °Brix. **Game simplification**, UNVERIFIED rule of thumb. |
| Potential alcohol (% vol) | PA = S / 16.83 | The EU convention: 16.83 g/L sugar per 1 % vol. The exact regulatory article is UNVERIFIED; the factor itself is widely used in EU wine law and practice. |
| Actual ethanol yield | E (g/L) = Y_ES × ΔS; % vol = E / 7.89 | Gay-Lussac theoretical yield is 0.511 g/g. Practical yields of ~0.44–0.48 g/g include losses to biomass, glycerol, CO₂ stripping and by-products. Ethanol density 0.789 g/mL → 7.89 g/L per % vol. The practical-yield range is UNVERIFIED as a sourced number. |

## Kinetic model
The structure follows the nitrogen-limited, temperature-dependent model of Coleman, Fish & Block (2007), which extends Boulton (1980). Its state variables per Lot are:

- X: active yeast biomass (g/L)
- N: yeast-assimilable nitrogen (YAN, g N/L)
- S: fermentable sugar (glucose + fructose, g/L)
- E: ethanol (g/L)
- T: must temperature (°C)

```
μ      = μ_max(T) · N / (K_N + N)                    # growth is limited by nitrogen
dX/dt  = μ · X − k_d(T) · E · X                        # growth minus ethanol-driven inactivation
dN/dt  = − μ · X / Y_XN                               # nitrogen is consumed into biomass
dS/dt  = − β_max(T) · X · S / (K_S + S)                # sugar uptake by active cells (Michaelis–Menten)
dE/dt  = − Y_ES · dS/dt
```

- Coleman et al. found that only μ_max, β_max and k_d vary strongly with temperature. Y_XN, Y_ES, K_N and K_S do not vary significantly with temperature.
- The temperature functions are fitted curves over 11–35 °C. The model reproduces the transition from sluggish (cold) to normal to stuck (hot) fermentation.
- Exact parameter values and temperature fits must be taken from Coleman et al. 2007, Tables 1–2. **UNVERIFIED** until transcribed: the table below gives structure and plausible magnitudes only, and must be replaced by the paper's values before calibration.

### Parameters

| Symbol | Meaning | Value used | Source |
|---|---|---|---|
| μ_max(T) | max specific growth rate | fitted function of T | Coleman et al. 2007 (values UNVERIFIED until transcribed) |
| β_max(T) | max specific sugar uptake rate | fitted function of T | Coleman et al. 2007 (UNVERIFIED) |
| k_d(T) | ethanol-dependent inactivation constant | fitted function of T; rises steeply above ~30 °C | Coleman et al. 2007 (UNVERIFIED) |
| K_N | Monod constant for N | temperature-independent | Coleman et al. 2007 (UNVERIFIED value) |
| K_S | Michaelis constant for sugar transport | temperature-independent | Coleman et al. 2007 (UNVERIFIED value) |
| Y_XN | biomass yield on nitrogen | temperature-independent | Coleman et al. 2007 (UNVERIFIED value) |
| Y_ES | ethanol yield on sugar | 0.47 g/g default, strain range 0.44–0.48 | Theory 0.511 (Gay-Lussac); practical range UNVERIFIED |
| X₀ | inoculum biomass | cultured: ~0.1–0.2 g/L (~10⁶ cells/mL); ambient: ~10× lower, with a longer lag | UNVERIFIED magnitudes |

### Yeast choice (a Cellar decision)
- **Cultured S. cerevisiae:** full X₀ immediately, lag ≈ 0.5–1 day, reliable completion, lower VA.
- **Ambient (spontaneous):** a mixed non-Saccharomyces population dominates early and S. cerevisiae takes over as ethanol rises. The game models this as a lag of +1–3 days, β_max × 0.8 during the first ~5 % vol, higher VA and ethyl acetate formation (`aroma-and-faults.md`), a complexity bonus in the Tasting sheet, and a higher risk of a stuck or sluggish finish. **Game simplification** (a single-population model with modifiers). Supporting review: Jolly, Varela & Pretorius (2014), cited from memory, UNVERIFIED.

## Yeast-assimilable nitrogen (YAN)
- Bely, Sablayrolles & Barre (1990) linked the early maximum CO₂ production rate to assimilable nitrogen. They proposed ~140 mg N/L as the threshold below which nitrogen deficiency slows fermentation (1.3 g CO₂/L·h at 24 °C).
- **Requirement grows with sugar.** The game uses YAN_target = 140 mg/L at 20 °Brix + 25 mg/L per additional °Brix. **Game heuristic, UNVERIFIED**: to be checked against AWRI guidance before calibration.
- **Additions (DAP):** the player may add diammonium phosphate at the start of fermentation or up to ~1/3 sugar depletion. N rises by the addition's nitrogen content (DAP ≈ 21 % N by mass, from the formula (NH₄)₂HPO₄: 28/132). EU and US legal maxima are UNVERIFIED and belong to the law model.

## Heat and tank temperature
The fermentation enthalpy is taken as ≈ −100 kJ per mol hexose fermented. The value is commonly cited (Williams 1982, AJEV); the citation is from memory and UNVERIFIED.

Derived:
- 1 °Brix ≈ 10 g/L sugar ≈ 0.0555 mol/L → ≈ 5.5 kJ per litre per °Brix.
- Must heat capacity ≈ 3.9–4.0 kJ/(L·K) → an **adiabatic rise of ≈ 1.3–1.4 °C per °Brix fermented**. Practical winemaking sources quote ~1.3 °C (2.3 °F) per °Brix without heat loss, and ~0.5 °C per °Brix when ~40 % of the heat escapes (WineMaker Magazine, "Controlling Fermentation Temperature").

Tank energy balance per hour:
```
C_tank · dT/dt = q_ferm − UA_jacket · (T − T_coolant) · u_ctrl − UA_env · (T − T_room)
q_ferm = ΔH · (−dS/dt) · V / M_hexose
u_ctrl ∈ [0,1]  (the controller opens the glycol valve when T > setpoint + deadband)
```
- The basic Winery tanks (spec §5.3) are temperature-controlled. UA_jacket is sized so that a 5,000 L tank can hold 16 °C during peak white fermentation. **UNVERIFIED** magnitude, a design assumption rather than a sourced value.
- A red cap is warmer than the juice beneath it (+2–5 °C typical). The game reports cap temperature separately for red Lots. UNVERIFIED range.
- **Cellar master Staff level** sets the controller deadband: Junior ±1.5 °C, Experienced ±0.8 °C, Senior ±0.3 °C (spec §5.4). **Game simplification.**

## Emergent failure states
All of these come from the equations and are never rolled:
- **Sluggish:** the rate |dS/dt| stays below 1 g/L/day for 3 days while S > 10 g/L. Typical causes: T < 12 °C (low μ_max, β_max), low YAN, high sugar.
- **Stuck:** |dS/dt| < 0.2 g/L/day with S > 2 g/L after the active phase. Typical causes: T > ~32 °C combined with high ethanol (k_d spikes), N exhausted early, very high initial sugar (> 260 g/L).
- Bisson (1999) reviews the causes: nutrient limitation, ethanol and temperature stress, and toxic substances. She also describes the physiological mechanism, a loss of hexose transport capacity. The kinetic model captures that mechanism through β and the inactivation of X.
- **Recovery actions:** re-inoculation with an acclimatised yeast starter, nutrient addition (limited effect once ethanol is high), warming or cooling towards 20–22 °C. Success depends on the state variables.
- **H₂S risk index:** rises when N falls below the requirement while S is still high, and with high temperature and certain strains. H₂S output feeds `aroma-and-faults.md`. The functional form is a **game simplification** (UNVERIFIED shape).

## Stopping fermentation for residual sugar
This is a Cellar decision on white Lots, typical of Mosel Kabinett and feinherb.

Steps and model effects:
1. **Chill** the tank to ≤ 6 °C. The rate drops with μ_max(T) and β_max(T). Tank cooling capacity limits how fast T falls, so a large, fast-fermenting Lot "overshoots" and loses a few g/L of residual sugar before it stops.
2. **Add SO₂** to reach molecular SO₂ ≥ 0.8 mg/L (`acid-ph-so2.md`). X is inactivated at a rate that rises with molecular SO₂.
3. **Rack or clarify** to remove yeast (X → ~0).
4. **Sterile-filter before bottling.** If this is skipped for a wine with residual sugar > 4 g/L, there is a refermentation risk in bottle. That is a fault state (CO₂ spritz, haze) whose probability rises with residual sugar, time and low molecular SO₂.

Target calibration: a Mosel Kabinett feinherb in the range of 8–10 % vol with residual sugar ~20–45 g/L. That range is UNVERIFIED; the law model sets the legal residual-sugar terms, see `tasting-sheet.md`.

## Inputs and outputs
- **Inputs from the harvest:** sugar S₀, YAN₀, malic and tartaric acid, K⁺, pH, precursor pools, Lot volume.
- **Player decisions:** yeast (ambient or cultured), fermentation temperature setpoint, DAP, stop for residual sugar, SO₂.
- **Staff:** Cellar master level.
- **Outputs:** S(t), E(t), X(t), N(t), T(t), fermentation duration, final residual sugar and % vol, H₂S index, VA formation (with `aroma-and-faults.md`), heat log for the 3D tank readouts.

## Calibration
The scripted golden-vintage runs must land inside these ranges.

| Check | Expected | Source |
|---|---|---|
| Duration of a white fermentation at 14–16 °C, cultured yeast, adequate YAN | ~10–21 days to dryness | UNVERIFIED (practice range) |
| Duration of a red fermentation at 25–30 °C | ~5–10 days | UNVERIFIED (practice range) |
| Must at 88 °Oe (≈ 21 °Brix) fermented dry | ≈ 12.0–12.5 % vol | Derived from the conversions above |
| YAN < 100 mg/L at 23 °Brix | sluggish or stuck in most runs unless DAP is added | Consistent with Bely et al. 1990 threshold (UNVERIFIED as a run outcome) |
| Uncooled 22 °Brix must starting at 15 °C | would exceed 35 °C, so fermentation stalls | Derived (≈ 1.3 °C/°Brix) |
| Fermentation curve shape | lag → exponential → linear → decline (the Boulton/Coleman shape) | Boulton 1980; Coleman et al. 2007 |

## Game simplifications
- One yeast population. Ambient fermentation is represented by modifiers, not a multi-species model.
- Sugar is one pool. Glucose is consumed faster than fructose in reality, which matters for sweet stuck wines. Kept for Hard mode.
- No oxygen, sterol or survival-factor modelling.
- Heat capacity and density are constant. There is no CO₂ evaporative-cooling term beyond UA_env.
- Every "UNVERIFIED" parameter above must be transcribed or sourced before M4 calibration.

## Open questions
- Transcribe Coleman et al. (2007) parameter tables and temperature fits (needed for M3/M4).
- Source a published YAN-requirement-vs-°Brix guideline (AWRI or UC Davis) to replace the heuristic.
- The legal DAP maximum (EU and US) belongs to the law model.

## Sources
- Coleman, M.C., Fish, R., Block, D.E. (2007). Temperature-dependent kinetic model for nitrogen-limited wine fermentations. *Applied and Environmental Microbiology* 73(18). https://journals.asm.org/doi/10.1128/aem.00670-07 (open access: https://pmc.ncbi.nlm.nih.gov/articles/PMC2074923/)
- Boulton, R. (1980). The prediction of fermentation behavior by a kinetic model. *Am. J. Enol. Vitic.* 31(1):40–45. https://www.ajevonline.org/content/31/1/40
- Bely, M., Sablayrolles, J.M., Barre, P. (1990). Automatic detection of assimilable nitrogen deficiencies during alcoholic fermentation in oenological conditions. *J. Fermentation and Bioengineering* 70(4):246–252. https://www.sciencedirect.com/science/article/abs/pii/0922338X90900574
- Bisson, L.F. (1999). Stuck and sluggish fermentations. *Am. J. Enol. Vitic.* 50(1):107–119. https://www.ajevonline.org/content/50/1/107
- WineMaker Magazine, "Controlling Fermentation Temperature" (practitioner source for °C per °Brix). https://winemakermag.com/articles/controlling-fermentation-temperature
- Williams, L.A. (1982). Heat release in alcoholic fermentation (AJEV). Cited from memory, **UNVERIFIED**.
- Jolly, N.P., Varela, C., Pretorius, I.S. (2014). Not your ordinary yeast: non-Saccharomyces yeasts in wine production uncovered. *FEMS Yeast Research* 14. Cited from memory, **UNVERIFIED**.
