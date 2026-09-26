# Acids, pH, sulphur dioxide and must adjustments

## Purpose
Computes a Lot's and a Wine's titratable acidity (TA), pH, potassium bitartrate (KHT) stability and sulphur dioxide (SO₂) state from its acid and cation composition. It also covers the effects of the player's adjustments: chaptalisation, acidification, deacidification, malolactic fermentation (MLF), SO₂ additions and cold stabilisation. pH is **never** a linear function of TA. It comes from a charge-balance solver (spec A4). The same module serves musts (no ethanol) and wines (ethanol shifts the dissociation constants).

## 1. Acid composition (state per Lot)

| Species | Molar mass (g/mol) | Protons titrated | pKa₁ | pKa₂ | Source |
|---|---|---|---|---|---|
| Tartaric (H₂T) | 150.09 | 2 | 3.04 | 4.37 | Standard enology values in water at 25 °C, as used by Boulton (1980). Cited from memory, UNVERIFIED |
| Malic (H₂M) | 134.09 | 2 | 3.40 | 5.11 | Same as above (UNVERIFIED; literature ranges 3.40–3.46 / 5.05–5.20) |
| Lactic (HL) | 90.08 | 1 | 3.86 | — | Standard value (UNVERIFIED as sourced here) |
| Acetic (HA) | 60.05 | 1 | 4.76 | — | Standard value |
| Succinic (H₂Su) | 118.09 | 2 | 4.21 | 5.64 | Standard value (UNVERIFIED as sourced here) |
| Citric | 192.12 | 3 | 3.13 | 4.76 (pKa₃ 6.40) | Standard value; minor in wine |

- **Cations:** K⁺ (dominant), Na⁺, Ca²⁺, Mg²⁺. Must K⁺ comes from the vineyard model: soil, rootstock and warm-site uptake. Typical must K⁺ is ~1–2.5 g/L; UNVERIFIED, to be calibrated with the viticulture fork.
- **Ethanol effect:** dissociation constants shift upwards (weaker acids) in hydroalcoholic solution, by about +0.1 to +0.2 pKa units at 10–13 % vol. Boulton (1980) explicitly includes the ethanol effect on dissociation constants when predicting wine pH. The exact correction used in the game is ΔpKa = 0.012 × % vol. That is a **game simplification** fitted to this range and UNVERIFIED; a candidate source is Usseglio-Tomasset & Bosia (1984), cited from memory.

## 2. pH by charge balance
Solve for [H⁺] such that:
```
[H⁺] + [K⁺] + [Na⁺] + 2[Ca²⁺] + 2[Mg²⁺] = [OH⁻] + Σ_acids ( α₁·C + 2·α₂·C + 3·α₃·C )
```
where for a diprotic acid with total molar concentration C:
```
D  = [H⁺]² + Ka₁[H⁺] + Ka₁Ka₂
α₁ = Ka₁[H⁺]/D        α₂ = Ka₁Ka₂/D
```
- **Method:** bisection on pH ∈ [2.4, 4.8] to 1e−6. It is deterministic and cheap, so it can run hourly.
- **Activity:** an ionic-strength correction (Davies equation) turns concentration constants into apparent constants. Without it, predicted pH runs ~0.1 too low. Boulton (1980) reported that titration recovered only ~74 % of the protons expected from total acidity, which shows why a naive model overshoots. **Calibration factor:** a single empirical "buffer correction" per region is fitted so that golden musts hit their measured pH. **Game simplification.**
- **TA:** simulated titration with NaOH to the endpoint, expressed as g/L tartaric acid.
  - The display convention follows the Region: Germany and the EU titrate to pH 7.0, the US to pH 8.2. The difference is a few tenths of a g/L. The solver computes both. UNVERIFIED magnitude.
  - Boulton (1980) distinguishes total acidity (the sum of acid anion equivalents), titratable acidity and pH. The game keeps all three.

## 3. Must adjustments (Cellar decisions, subject to the Region's rulebook)
Legal limits belong to the law model. The numbers here are the chemistry.

**Chaptalisation (enrichment):**
- ≈ 17 g/L sucrose raises potential alcohol by 1 % vol. The EU convention is 16.83 g/L of fermentable sugar per % vol; sucrose inverts to glucose + fructose (342 → 360 g/mol, ×1.053), so slightly less sucrose is needed per % vol in theory, but practical rules of thumb run 17–18 g/L because of yield losses. UNVERIFIED as a sourced rule of thumb.
- EU enrichment limits by wine-growing zone (A: +3 % vol, B: +2 % vol, C: +1.5 % vol) and the ban on enrichment for German Prädikatswein are **cited from memory (Reg. (EU) 1308/2013 Annex VIII; German wine law), UNVERIFIED**, and belong to the law model.
- **California does not permit sugar addition**; grape concentrate is allowed, and water additions are allowed within federal limits. Practitioner sources: Wine Spectator; WineMaker Magazine. The primary legal citation is UNVERIFIED.

**Acidification (tartaric acid):**
- Adds H₂T. The solver gives the ΔpH, typically −0.1 to −0.15 per 1 g/L added in a buffered must (UNVERIFIED rule of thumb).
- Part of the addition later precipitates as KHT during cold stabilisation, reducing K⁺ and tartaric acid together.
- EU zone restrictions and limits are UNVERIFIED (law model).

**Deacidification:**
- **KHCO₃** (100.12 g/mol): neutralises 1 H⁺. 1 g/L removes 0.01 eq/L, which is 0.75 g/L TA as tartaric. It precipitates more KHT, and the total practical TA drop is often quoted near 1 g/L per g/L. UNVERIFIED.
- **CaCO₃** (100.09 g/mol): neutralises 2 H⁺. 1 g/L removes 0.02 eq/L, which is 1.5 g/L TA as tartaric. Calcium tartrate precipitates slowly (a late-instability risk).
- The game applies stoichiometry in the solver plus precipitation via the KHT model (§5).

## 4. Malolactic fermentation (MLF)
- **Reaction:** L-malic acid → L-lactic acid + CO₂ (by *Oenococcus oeni*).
- **Mass:** 1 g malic (134.09 g/mol) → 0.672 g lactic (90.08 g/mol) + 0.328 g CO₂.
- **TA effect, as tartaric equivalents** (75.04 g per equivalent):
  - 1 g/L malic = 2 eq × (1/134.09) = 0.01492 eq/L = **1.119 g/L tartaric-equivalent**.
  - 0.672 g/L lactic = 1 eq × (0.672/90.08) = 0.00746 eq/L = **0.560 g/L tartaric-equivalent**.
  - **Net ΔTA ≈ −0.56 g/L (as tartaric) per g/L malic converted.** This is derived from stoichiometry.
- **pH rises:** it emerges from the solver when malic is swapped for lactic. The typical result is **+0.1 to +0.3 pH units** (UNVERIFIED practice range, used as a calibration check).
- **Progress model:** logistic bacterial growth then malate consumption:
```
dB/dt = r(T, pH, SO₂mol, EtOH) · B · (1 − B/B_max)
dMal/dt = − v · B · Mal / (K_M + Mal)
```
  Inhibition multipliers:
  - T < 15 °C strongly slows it; the optimum is ~18–22 °C.
  - pH < 3.2 slows it strongly.
  - Molecular SO₂ > ~0.2–0.3 mg/L inhibits it; total SO₂ > ~40–50 mg/L effectively blocks it.
  - Ethanol > ~14 % vol slows it.

  All thresholds are UNVERIFIED practice values, to be sourced before calibration.
- **Duration** under good conditions: ~2–8 weeks (UNVERIFIED).
- **Blocking MLF** (typical for Riesling): keep it cold, add SO₂ early, and sterile-filter before bottling. Partial MLF is allowed by stopping it when Mal reaches a target.
- **Sensory outputs** to `aroma-and-faults.md`: diacetyl (buttery), a softer acid perception, and loss of some primary fruit freshness.

## 5. KHT (cream of tartar) stability
```
CP = [K⁺] · [HT⁻]        (mol²/L², [HT⁻] from α₁ × tartaric total at the solver pH)
```
- The wine is **unstable** if CP exceeds the saturation product at the storage temperature and ethanol level. A saturation table is interpolated over T ∈ [−4, 20] °C and ethanol ∈ [8, 15] % vol. Table values: UNVERIFIED; Berg & Keefer (1958, AJEV) is cited from memory as the classic source.
- **Cold stabilisation** (−4 °C for 1–3 weeks): precipitate the excess until CP = K_sp(−4 °C). K⁺ and tartaric fall and pH shifts: down if the wine's pH is below ~3.65, up above it, because of the HT⁻ fraction removed. That pH pivot is from memory and UNVERIFIED.
- **Fault:** if the wine is bottled unstable and chilled, tartrate crystals ("wine diamonds") form. It's harmless but a presentation fault in the Tasting sheet appearance.

## 6. Sulphur dioxide
Species: molecular SO₂ (antimicrobial), bisulfite HSO₃⁻ (dominant at wine pH), sulphite SO₃²⁻ (negligible). Free SO₂ = molecular + HSO₃⁻ + SO₃²⁻.
```
molecular SO₂ = free SO₂ / (1 + 10^(pH − 1.81))
free SO₂ needed = target molecular × (1 + 10^(pH − 1.81))
```
- pKa₁ = 1.81 (widely used in enology calculators; AWRI "Understanding molecular SO₂"). The same formula is used by UC Davis-derived calculators.
- **Targets:** ~0.8 mg/L molecular for whites and low-tannin wines. It traces back to Beech et al. (1979) and was popularised by UC Davis (Boulton) as the maintenance level against microbes. Reds are often managed at ~0.5–0.6 mg/L because anthocyanins and tannins bind and protect; that red target is UNVERIFIED as sourced here.
- **Worked example:** at pH 3.5, free SO₂ needed = 0.8 × (1 + 10^1.69) ≈ 0.8 × 50 ≈ **40 mg/L** free SO₂. At pH 3.8 it's ≈ 0.8 × 100 ≈ 80 mg/L, which is why high-pH warm-site wines are hard to protect.
- **Binding** (bound SO₂):
  - **Acetaldehyde:** near-stoichiometric. 1 mg acetaldehyde binds 64/44 ≈ **1.45 mg SO₂**. Acetaldehyde comes from yeast (more with early SO₂ and oxygen) and from oxidation.
  - Weaker binders (pyruvate, α-ketoglutarate, anthocyanins, sugars) use equilibrium constants. The constants are UNVERIFIED and to be sourced (candidate: Ribéreau-Gayon *Handbook of Enology* Vol. 1, cited from memory).
- **Losses:** free SO₂ declines through oxidation (per mg O₂ consumed ≈ 4 mg SO₂, by stoichiometry of SO₂ with H₂O₂ from the coupled oxidation cascade; UNVERIFIED as a practical number), through volatilisation, and through binding over time.
- **Temperature and ethanol** also shift the pKa. Ignored in Normal mode; noted for Hard mode.
- **Legal maxima for total SO₂** (EU: red 150 mg/L, white and rosé 200 mg/L, higher for residual-sugar and Prädikat wines; US 350 mg/L) are cited from memory (Reg. (EU) 2019/934 Annex I Part B), **UNVERIFIED**, and belong to the law model.

## Inputs and outputs
- **Inputs:** acids and cations from harvest (`viticulture` models), fermentation outputs (`fermentation.md`), player additions (tartaric, KHCO₃, CaCO₃, sucrose, SO₂), MLF choice, storage temperature.
- **Outputs:** pH, TA (in the regional convention), total acidity, malic and lactic, free, bound, molecular and total SO₂, KHT stability flag, and the MLF state for the 3D readouts.

## Calibration

| Check | Expected | Source |
|---|---|---|
| Mosel Riesling must, 80–90 °Oe | TA 8–11 g/L, pH 2.9–3.1 | Consistent with the dashboard dataset; source UNVERIFIED (German harvest statistics to be cited by the viticulture fork) |
| Napa Cabernet must at harvest | pH 3.6–3.8, TA 5.5–6.5 g/L | Spec calibration range; UNVERIFIED source (California Grape Crush Report doesn't give pH; needs UC Davis extension data) |
| MLF of 3 g/L malic | TA −1.7 g/L; pH +0.1 to +0.3 | Stoichiometry (derived); practice range UNVERIFIED |
| Molecular SO₂ at pH 3.5, free 40 mg/L | ≈ 0.8 mg/L | Formula (AWRI) |
| Solver vs measured pH on golden musts | within ±0.05 pH after the regional correction | Game target |

## Game simplifications
- One empirical buffer correction per Region instead of full activity modelling in Normal mode.
- No temperature dependence of pKa values. Ethanol shift is linear.
- Weak SO₂ binders are lumped into one pool with a single equilibrium constant.
- The KHT saturation table is interpolated; there's no nucleation kinetics (instant precipitation during cold stabilisation over the chosen duration).
- Calcium tartrate instability is flagged but not simulated in time.

## Open questions
- Confirm the pKa set (in water and wine) from a primary source (Boulton 1980 tables, or Usseglio-Tomasset & Bosia 1984).
- Source KHT saturation data (Berg & Keefer 1958 or a modern replacement).
- Source the MLF inhibition thresholds (AWRI MLF guidance, or Lonvaud-Funel).
- Confirm the regional TA endpoint conventions (Germany pH 7.0 as tartaric; US pH 8.2) against official methods (OIV-MA-AS313-01).

## Sources
- Boulton, R. (1980). The relationships between total acidity, titratable acidity and pH in wine. *Am. J. Enol. Vitic.* 31(1):76–80. https://www.ajevonline.org/content/31/1/76. UC Davis research summary: https://wineserver.ucdavis.edu/sites/g/files/dgvnsk2676/files/research-summaries/220%20relationship%20between%20total%20acidity,%20TA,%20and%20pH%20.pdf
- AWRI, "Ask the AWRI: Understanding molecular SO₂". https://www.awri.com.au/s1886/ (pKa 1.81 formula; page fetched as PDF, contents cross-checked against calculators)
- Beech, F.W., Burroughs, L.F., Timberlake, C.F., Whiting, G.C. (1979). Progrès récents sur l'aspect chimique et l'action antimicrobienne de l'anhydride sulfureux. *Bull. OIV*. Origin of the 0.8 mg/L molecular target via UC Davis. Bibliographic details from memory, UNVERIFIED.
- UC Davis Viticulture & Enology, Titratable Acidity (method page). https://wineserver.ucdavis.edu/industry-info/enology/methods-and-techniques/winery-lab-techniques/titratable-acidity
- Waterhouse, A.L., Sacks, G.L., Jeffery, D.W. (2016). *Understanding Wine Chemistry*, Chapter "Acids". Wiley. https://onlinelibrary.wiley.com/doi/abs/10.1002/9781118730720.ch3 (standard text; specific values cited from memory are marked UNVERIFIED above)
- Regulation (EU) 2019/934 (authorised oenological practices; SO₂ and VA limits). https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32019R0934 (the SO₂ limit numbers quoted above are UNVERIFIED against the annex text)
- Wine Spectator, "Do California winemakers ever add sugar to their wine? Is that legal?" https://www.winespectator.com/articles/do-california-winemakers-ever-add-sugar-to-their-wine-is-that-legal
