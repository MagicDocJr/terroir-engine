# The Tasting sheet

## Purpose
Turns a finished Wine's chemistry and history into a structured assessment (spec §3.2, §9, Q32): appearance, nose, palate, conclusions. **Every descriptor carries a "why" link** back to the compound or measurement that produced it, and from there to the decisions and conditions that caused it. For example: "petrol ← TDN 6 µg/L ← high fruit sun exposure (canopy Programme: High) + 8 years in bottle".

- Depth: WSET Level 3, shown in **Normal mode**.
- **IP rule (spec §9):** the structure follows the common systematic-tasting pattern, but **all wording is our own**. The WSET SAT text is not reproduced and the WSET name is not used. Numeric band boundaries are facts about wine, chosen to match common educational conventions. They're flagged for the reviewer to confirm.

## Inputs
From the other models:
- **Chemistry:** % vol, residual sugar (RS), TA, pH, glycerol (estimated), dry extract, total tannin and its origin split (skin/seed/stem/oak), anthocyanins and polymeric pigment, colour absorbances.
- **Compounds:** the concentration vector and OAVs (`aroma-and-faults.md`).
- **Faults:** fault flags.
- **History:** age, oak exposure, lees months, MLF, oxygen dose.
- **Style context:** Variety, Region, Legal category.

## 1. Appearance
- **Clarity:** clear, or hazy if a protein or KHT fault, refermentation, or no filtration with visible lees.
- **Intensity** (pale / medium / deep):
  - whites: from phenolics + oxidation + age
  - reds: from colour density CD = A420 + A520 (+ A620), computed from anthocyanins + polymeric pigment, with the pH effect (higher pH → less red flavylium form → lower intensity and bluer hue)
  - Band cut-offs are a **game calibration** (UNVERIFIED), to be tuned so that young Pinot Noir reads pale–medium and young Cabernet deep.
- **Colour:**
  - whites: lemon-green → lemon → gold → amber → brown, with browning from oxygen dose and age (brown when oxidised)
  - reds: purple → ruby → garnet → tawny → brown, driven by hue = A420/A520 rising with age and polymerisation (tawny after
    about ten years or with oxygen; brown when oxidised)
  - Mapping thresholds UNVERIFIED (game calibration).
- **Other observations** (noted, not marked; the systematic approach lists legs, deposit and a slight spritz as notes
  [UW-2016 p. 3]): deposit (a red with four or more years in bottle and firm tannin, or an unfiltered wine), pronounced legs
  (≥ 14 % vol or ≥ 45 g/L sugar), possible spritz (sugar and live yeast in bottle). Tartrate crystals are not modelled.

## 2. Nose
- **Condition:** clean, or faulty if any fault exceeds its detection threshold. The fault is named, with its why-link (e.g. "reduced (rotten egg) ← H₂S ← YAN 95 mg/L at 23 °Brix, no nutrient added").
- **Intensity** (light / medium(−) / medium / medium(+) / pronounced): 0.55 × the strongest family + 0.17 × the next three,
  the fruit counted once however many fruit families it is split into.
- **Development:** youthful / developing / fully developed / tired. Tired means older than the Wine's drinking window
  (§4).
- **Simple:** a nose of very few aromas [UW-2016 p. 4]: nothing from oak, lees, malolactic or age (fermentation esters
  allowed), at most one clear family besides the fruit, and no fault: few aromas, mostly fruit. In the aroma-list answer
"simple" counts as a family:
  right on a simple nose, wrong otherwise. About 9 % of random practice pours, all young unoaked Chardonnay (game
  calibration).
- **Fruit ripeness** (unripe / fresh / ripe / dried or cooked): from harvest ripeness; noble rot reads dried, sunburn
  cooked, and very ripe reds (≥ 110 °Oe) cooked or jammy. Warm-climate black fruit is commonly described as cooked or jammy
  [LBTL p. 51]. Thresholds are game calibration (UNVERIFIED).
- **Aroma families** (only compounds or pools above OAV 1 appear):

| Family (our wording) | Examples on the sheet | Driven by |
|---|---|---|
| Primary: green fruit / citrus fruit / stone fruit / tropical fruit (whites, one or two shown) | apple, lemon, peach, pineapple | Variety fruit profile × ripeness; the terms are grouped into the exam's fruit families |
| Primary: red fruit / black fruit (reds) | redcurrant, cherry; blackcurrant, plum | Variety profile × ripeness (vineyard) |
| Primary: floral | blossom, rose | linalool, geraniol, β-damascenone |
| Primary: herbaceous | green bell pepper, grass | IBMP, green stems (whole bunch unripe) |
| Secondary: fermentation | banana, pear drop | isoamyl acetate (cool fermentation, young wine) |
| Secondary: MLF | butter, cream | diacetyl |
| Secondary: lees | bread, biscuit | lees months × bâtonnage |
| Secondary: oak | vanilla, toast, coconut, clove, smoke | vanillin, furfural, oak lactones, eugenol, guaiacol |
| Tertiary: bottle-aged white | petrol/kerosene (Riesling), honey, toast | TDN, β-damascenone, age |
| Tertiary: bottle-aged red | dried fruit, leather, earth, forest floor | age, polymerisation, oxygen dose |
| Tertiary: oxidative | nutty, bruised apple | acetaldehyde (below fault level: "developed"; above: "oxidised") |

- **Fruit character by Variety:** a base profile per Variety (e.g. Riesling: citrus/green fruit → stone fruit when ripe; Cabernet: blackcurrant, with green pepper if unripe). It's scaled by the vineyard ripeness index and the Region's climate. The profile tables belong to the vineyard/Variety model; here they are only consumed.

## 3. Palate

| Attribute | Scale (our wording) | Computed from | Band source |
|---|---|---|---|
| Sweetness | dry / off-dry / medium-dry / medium-sweet / sweet / luscious | RS, with perceived sweetness adjusted for acidity. The legal label term (e.g. trocken, feinherb, Kabinett style) is shown separately via the law model | EU label terms for still wine (Commission Delegated Regulation (EU) 2019/33, Annex III Part B; checked against the retained text at https://www.legislation.gov.uk/eur/2019/33/annex/III on 2026-10-02): dry ≤ 4 g/L, or ≤ 9 g/L if TA ≥ RS − 2; medium dry ≤ 12 g/L, or ≤ 18 g/L if TA ≥ RS − 10; medium ≤ 45 g/L; sweet ≥ 45 g/L |
| Acidity | low / medium(−) / medium / medium(+) / high | TA and pH (pH weighted for reds). White cut-offs are TA < 5, 5–6, 6–7, 7–8.5, > 8.5 g/L; reds shift down ~0.5 g/L | game calibration, UNVERIFIED |
| Tannin, level (reds) | low → high | total tannin mg/L CE | game calibration, UNVERIFIED |
| Tannin, nature (reds) | ripe/soft · fine-grained · green/coarse | seed:skin ratio, seed maturity, stem share, polymerisation, oak tannin share | direction per Sacchi et al. 2005; cut-offs UNVERIFIED |
| Alcohol | low / medium / high | % vol: < 11 low, 11–13.9 medium, ≥ 14 high | the coursebook's bands [UW-2016 p. 8] |
| Body | light / medium(−) / medium / medium(+) / full | f(% vol, RS, glycerol, dry extract, tannin, lees polysaccharides) | game calibration |
| Flavour intensity | light / medium(−) / medium / medium(+) / pronounced | the nose intensity + sugar (up to 100 g/L ÷ 250) + 0.1 for tannin > 700 mg/L | game calibration |
| Flavour characteristics | the nose families felt on the palate: the fruit always, the rest at medium or above, without smell-only notes (volatile, reductive) | same compounds; asked separately from the nose in the full-sheet exercise | — |
| Finish (length) | short / medium(−) / medium / medium(+) / long | 0.15 + 0.8 × flavour + 0.25 × (body − 1) + acidity (0.3 high, 0.15 medium(+)) + sugar (up to 90 g/L ÷ 200) + tannin above 600 mg/L ÷ 2500 + noble rot | game calibration, UNVERIFIED |

## 4. Conclusions
The **quality level** is assessed on four criteria. The game computes each as pass/fail with a reason:

1. **Balance:** are sweetness, acidity, alcohol, tannin (reds) and fruit in proportion *for the style*? Each component has an ideal window relative to the others. Examples: high acidity is balanced by residual sugar in a Mosel Kabinett; high tannin needs fruit intensity and body. **Fail** if any component falls outside its window: the "too hot", "flabby", "tart", "hollow" and "drying/astringent" checks. The window definitions are a **game calibration**, UNVERIFIED, and the core item for review #2.
   Balance also needs **integration**: the oak may not dominate the fruit (oak the strongest note while the fruit is light)
   [UW-2016 p. 9].
2. **Length:** passes at a long finish, or at medium(+) carried by pronounced flavour (intense wines generally have a long
   finish [UW-2016 p. 9]).
3. **Intensity:** passes if flavour intensity is at least "medium(+)".
4. **Complexity:** layers across categories: ≥ 4 clearly perceived families (the fruit counted once) across ≥ 2
   categories, or 3 with a clear note of age (tertiary) [UW-2016 p. 9; thresholds game calibration, UNVERIFIED].

| Criteria met (none can be a fault) | Quality level |
|---|---|
| any fault above rejection | **Faulty** |
| 0 | Poor |
| 1 | Acceptable |
| 2 | Good |
| 3 | Very good |
| 4 | Outstanding |

This is the coursebook's own method for Level 3: outstanding is positive on all four criteria, very good on three, good on
two, acceptable on one, poor on none [UW-2016 p. 9]. At Level 3 no reasons are asked; at Diploma level quality is argued
from evidence. The sheet therefore also writes the **argument**: *For* (the criteria met, with their evidence), *Against*
(those missed) and *Not <the level above>, because …*.

**Calibration of the spread** (Tasting sheet 2, 2026-10-02): over 150 random practice pours the verdict was 61 % Very good
or better; after fixing three inflations (the oak family summed four compounds' strengths, the split fruit counted twice,
the finish leaned on body and tannin) and requiring layers for complexity, it is Outstanding 7 %, Very good 29 %, Good
33 %, Acceptable 27 %, Poor 3 %. The
target bands are **UNVERIFIED**, for the Level 3 reviewer; `TerroirEngine.Cli qualitysweep [n]` reports the spread per
variety. Known gaps: Riesling's finish barely varies (the nose model is narrow), so a Riesling never reaches Outstanding;
the extracted Pinot Noir style (riper, longer maceration, new oak) is reliably Outstanding while classic and light are
Good, so per grape the verdict follows the style more than it should (guarded by a test, backlog).

**Readiness for drinking:** too young / can drink now, has potential for ageing / drink now, not for (further) ageing /
too old [UW-2016 pp. 9–10]. A drinking window comes from structure carried by concentration:
window = 1.5 + 5 × (acid + tannin + sugar parts) × (0.4 + 0.15 × flavour-intensity step), 2–20 years (**UNVERIFIED**
design values). Too old beyond 1.3 × the window; drink now beyond 0.7 × the window or when the window is under 6 years; too
young under a quarter of the window with firm tannin (≥ 1000 mg/L) or high sugar with high acid. A faulty Wine has no
readiness. The sheet explains the verdict: the window, what structure sets it, and the age at tasting.
- **Fruit ripeness with age:** a fully developed or tired Wine, or a red with bottle-age character, reads "dried or
  cooked" [UW-2016 p. 4]. Earlier text, kept for its reasoning: It's estimated from structure (acidity, tannin, RS, extract, intensity) vs development. Riesling with high acidity and RS ages well; low-acid, low-extract wines don't. **Game heuristic**, UNVERIFIED.

## 5. "Why" links (causal trail)
- Every sheet line is `{descriptor, evidence: [compound or measurement with value], causes: [event IDs]}`.
- Causes are resolved from the decision log (event sourcing, spec §10) and the sim history: Programme tiers, harvest date, cellar decisions, weather events, Block soil and aspect.
- The explanation text is **generated from templates per cause type**, and every template sentence must be backed by `docs/science/` (spec §9 rule 1).
- Example templates:
  - *"Green bell pepper: IBMP {x} ng/L is above its ~15 ng/L threshold. Low sunlight on the fruit (canopy Programme Low) and an early harvest (Block B, {date}) left pyrazines undegraded."*
  - *"Firm, slightly coarse tannin: seed tannin makes up {p} % of total tannin. Seeds were still green at harvest (seed maturity {m}), and the 21-day extended maceration extracted them."*
  - *"Petrol note: TDN {x} µg/L is above the ~2 µg/L detection threshold, from high fruit sun exposure and {n} years in bottle."*

## Calibration
The checks for review #2 by the WSET L3 reviewer, done at this computer:

| Wine scenario | Expected sheet |
|---|---|
| Mosel Riesling Kabinett feinherb, steep slate, 8.8 % vol, RS 38 g/L, TA 8.6 g/L | pale lemon-green; medium(+) intensity, citrus/green apple/blossom; off-dry–medium sweetness, high acidity, low alcohol, light body; long finish; Very good if balanced |
| Riesling harvested too early, cool vintage, chaptalised Qualitätswein | pale; light intensity; dry, high (tart) acidity; Acceptable (balance fails) |
| Napa Cabernet, ripe, 18 months in new French oak | deep ruby; pronounced blackcurrant, vanilla, toast; dry, medium acidity, high ripe tannin, high alcohol, full body; long; Very good–Outstanding |
| Cabernet planted on the flat Mosel riverbank, harvested unripe | pale–medium ruby; green bell pepper; high acidity, green tannin; Poor/Acceptable (balance and intensity fail) |
| High-pH red with little SO₂ in old barrels | Faulty (Brett: barnyard, sticking plaster) if 4-EP exceeds the rejection level |

## Game simplifications
- Fixed thresholds and bands. Real tasters differ.
- The quality level is a count of four criteria, the same rule every time (the coursebook's Level 3 method).
- No pepper family: the simulation has no rotundone, and none of its grapes is a peppery variety.
- Variety fruit profiles are table-driven, not modelled from compounds (most fruit aromas are not single compounds).

## Open questions
- Confirm all band cut-offs with the reviewer (review #2).
- Confirm the EU sweetness terms (Reg. (EU) 2019/33) and the German Prädikat / feinherb usage with the law model.
- Decide whether Exam mode's player-filled sheet (backlog) reuses these bands for grading.

## Sources
- Sacchi, K.L., Bisson, L.F., Adams, D.O. (2005). *Am. J. Enol. Vitic.* 56:197–206 (tannin nature vs extraction choices).
- Compound thresholds: see `aroma-and-faults.md` (Roujou de Boubée 2000; Tominaga 1998; Sacks 2012; Ross 2014; Chatonnet 1992; Waterhouse Lab; Ferreira 2000; Guth 1997).
- Commission Delegated Regulation (EU) 2019/33, Annex III Part B (sweetness terms). Cited from memory, **UNVERIFIED**.
- Systematic tasting structure: the common educational pattern (appearance, nose, palate, conclusions; BLIC quality reasoning). Written in our own words; no WSET text is reproduced.
- [UW-2016] Wine & Spirit Education Trust (2016). *Understanding Wines: Explaining Style and Quality*. London: WSET. ISBN 978-1-905819-39-3. Page numbers are the printed ones. Paraphrased, never quoted.
- [LBTL] Wine & Spirit Education Trust. *Looking Behind the Label* (introductory course companion). London: WSET. Printed page numbers (PDF page − 5). Paraphrased, never quoted.
