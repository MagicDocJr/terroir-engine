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
  - whites: lemon-green → lemon → gold → amber, with browning from oxygen dose and age
  - reds: purple → ruby → garnet → tawny, driven by hue = A420/A520 rising with age and polymerisation
  - Mapping thresholds UNVERIFIED (game calibration).

## 2. Nose
- **Condition:** clean, or faulty if any fault exceeds its detection threshold. The fault is named, with its why-link (e.g. "reduced (rotten egg) ← H₂S ← YAN 95 mg/L at 23 °Brix, no nutrient added").
- **Intensity** (light / medium / pronounced): from the sum of perceived family scores.
- **Development:** youthful / developing / fully developed / past its best. It comes from the ratio of tertiary to primary family scores and from ester hydrolysis.
- **Aroma families** (only compounds or pools above OAV 1 appear):

| Family (our wording) | Examples on the sheet | Driven by |
|---|---|---|
| Primary: green fruit, citrus, stone fruit, tropical | apple, lemon, peach, passion fruit | esters, thiols (3MH, 3MHA, 4MMP), terpenes, Variety fruit profile |
| Primary: red and black fruit | redcurrant, cherry, blackcurrant | Variety profile × ripeness (vineyard), esters |
| Primary: floral | blossom, rose | linalool, geraniol, β-damascenone |
| Primary: herbaceous | green bell pepper, grass | IBMP, green stems (whole bunch unripe) |
| Primary: spice | black pepper | rotundone |
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
| Sweetness | dry / off-dry / medium / sweet | RS, with perceived sweetness adjusted for acidity. The legal label term (e.g. trocken, feinherb, Kabinett style) is shown separately via the law model | EU label terms for still wine are cited from memory (Reg. (EU) 2019/33 Annex III Part B): dry ≤ 4 g/L, or ≤ 9 g/L if TA ≥ RS − 2; medium dry ≤ 12 g/L, or ≤ 18 g/L if TA ≥ RS − 10; medium ≤ 45 g/L; sweet ≥ 45 g/L. **UNVERIFIED** |
| Acidity | low / medium(−) / medium / medium(+) / high | TA and pH (pH weighted for reds). White cut-offs are TA < 5, 5–6, 6–7, 7–8.5, > 8.5 g/L; reds shift down ~0.5 g/L | game calibration, UNVERIFIED |
| Tannin, level (reds) | low → high | total tannin mg/L CE | game calibration, UNVERIFIED |
| Tannin, nature (reds) | ripe/soft · fine-grained · green/coarse | seed:skin ratio, seed maturity, stem share, polymerisation, oak tannin share | direction per Sacchi et al. 2005; cut-offs UNVERIFIED |
| Alcohol | low / medium / high | % vol: < 11 low, 11–13.9 medium, ≥ 14 high | matches common educational banding; reviewer to confirm |
| Body | light / medium / full | f(% vol, RS, glycerol, dry extract, tannin, lees polysaccharides) | game calibration |
| Flavour intensity | light / medium / pronounced | as the nose intensity, plus sweetness and tannin contribution | game calibration |
| Flavour characteristics | as the nose families | same compounds | — |
| Finish (length) | short / medium / long | f(flavour intensity, dry extract, phenolics, acidity); "length seconds" proxy | game calibration |

## 4. Conclusions
The **quality level** is assessed on four criteria. The game computes each as pass/fail with a reason:

1. **Balance:** are sweetness, acidity, alcohol, tannin (reds) and fruit in proportion *for the style*? Each component has an ideal window relative to the others. Examples: high acidity is balanced by residual sugar in a Mosel Kabinett; high tannin needs fruit intensity and body. **Fail** if any component falls outside its window: the "too hot", "flabby", "tart", "hollow" and "drying/astringent" checks. The window definitions are a **game calibration**, UNVERIFIED, and the core item for review #2.
2. **Length:** passes if the finish is at least "medium(+)" by the proxy above.
3. **Intensity:** passes if flavour intensity is at least "medium(+)".
4. **Complexity:** passes if ≥ 3 distinct families are above threshold, including at least one secondary or tertiary family, or ≥ 4 primary families of layered character.

| Criteria met (none can be a fault) | Quality level |
|---|---|
| any fault above rejection | **Faulty** |
| 0 | Poor |
| 1 | Acceptable |
| 2 | Good |
| 3 | Very good |
| 4 | Outstanding |

This follows the widely taught "BLIC" approach (balance, length, intensity, complexity). The mapping of count to level is our own and must be confirmed by the reviewer.

**Readiness for drinking / ageing potential:** "drink now, not for ageing" / "can drink now, with potential to improve" / "too young". It's estimated from structure (acidity, tannin, RS, extract, intensity) vs development. Riesling with high acidity and RS ages well; low-acid, low-extract wines don't. **Game heuristic**, UNVERIFIED.

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
- The quality level is a count of four criteria, the same rule every time.
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
