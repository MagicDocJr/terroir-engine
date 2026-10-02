# Tasting sheet 2: closer to the exam, and quality that spreads

Status: approved by the owner 2026-10-02 ("go ahead and implement … don't ask questions till done"). Roadmap items Q8–Q11
of `docs/research/2026-09-30-fun-and-learning.md`, revised against the owner's coursebooks (`reference/`, cited as
[UW-2016] and [LBTL]).

## 1. Intent

The Tasting sheet is the base of every exercise, of the daily sessions and of the estate predictions. Where it differs
from the systematic approach the exam uses, the game trains habits the exam marks down. Its quality verdict also runs
high, so Conclusions practice and quality predictions mean little.

Success means:
- every line a Level 3 candidate writes exists on the sheet, with the same scale;
- the quality verdict spreads like a real mixed line-up and always explains itself;
- the climate is shown on the absolute scale the exam uses, beside the game's relative one.

All of this must stay inside the project's rules: the simulation decides (ADR 0001), and nothing is copied from the books
or the exam materials.

## 2. What the books changed in the roadmap

- **Quality.** The Level 3 coursebook itself teaches the four-criteria count (balance, intensity, length, complexity:
  outstanding is positive on all four, very good on three, down to poor on none), and says a Level 3 candidate gives no
  reasons [UW-2016 pp. 8–9]. So the count stays, as the Level 3 method. Research track C's "not policy" note holds only for
  the Diploma, where quality is argued from positive and negative evidence. The sheet therefore keeps the count and adds the
  argument as a learning aid.
- **The book's balance includes integration.** Alcohol, oak and acidity must be integrated, not just present
  [UW-2016 p. 8]. The balance check gains integration tests.
- **Simplicity is not always negative.** Purity of expression can make a wine great [UW-2016 p. 9]. A pure, intense,
  long, primary-led wine can meet complexity without oak or age.
- **No pepper family.** The simulation has no rotundone, and none of its four grapes is a peppery variety. This goes to the
  backlog with Syrah.
- **Readiness has four options**, and "too old" and "too young" have clear rules [UW-2016 pp. 9–10].

## 3. The sheet, line by line (changes only)

### 3.1 Appearance
- **Colour adds brown.** White: lemon-green → lemon → gold → amber → **brown**. Red: purple → ruby → garnet → **tawny** →
  **brown**. Brown comes from oxidation or great age.
- **Other observations** (display only, with a "because"):
  - deposit: a red with several years in bottle and firm tannin, or an unfiltered wine;
  - tartrate crystals: where KHT is unstable;
  - pronounced legs: high alcohol or high sugar;
  - slight spritz: a refermentation fault.

  These are not marked: the exam treats them as notes, not scored lines.

### 3.2 Nose and palate
- **Fruit split.**
  - Whites: green fruit, citrus fruit, stone fruit, tropical fruit. A wine shows one or two, chosen from ripeness.
  - Reds: red fruit and black fruit, replacing the single "red and black fruit" family.
  - The families keep their terms and their "because".
- **Fruit ripeness**, a new scored line in the full-sheet exercise:
  - scale: unripe (green) / fresh / ripe / dried or cooked;
  - taken from harvest ripeness, plus sunburn or noble rot (dried or cooked).
- **"Simple."** When the nose shows few clear families (at most two, all primary), the sheet says "simple". In the
  aroma-list answer the player may tick "simple": it counts as a family, right on a simple wine and wrong otherwise.
- **Flavour characteristics**, a new scored line in the full-sheet exercise:
  - asked separately from the nose;
  - the families clearly perceived on the palate: the nose families at medium or above, without the smell-only notes
    (volatile, reductive);
  - marked like the aroma list.
- **Development adds "tired"** (past its best): age beyond the style's drinking window.

### 3.3 Conclusions
- **Readiness, four options**:
  - too young;
  - can drink now, has potential for ageing;
  - drink now, not for (further) ageing;
  - too old.

  The rules:
  - the drinking window comes from structure (acid, tannin, sugar, concentration); simple light wines get 2–3 years and
    structured ones up to 15–20 (**UNVERIFIED** design values);
  - too young: a firm structure in its first years, which would be wasted now (a tannic young red, a young sweet Riesling
    of high acid);
  - too old: beyond the window, or past its best;
  - a faulty wine has no readiness, and its line is skipped in marking.
- **Quality argument.** Every criterion records its evidence. The "because" becomes an argument with three parts:
  - **For:** the criteria met, with their evidence;
  - **Against:** the criteria missed, with their evidence;
  - **Not <the level above> because:** the missing criterion, or for Outstanding, "the top level".
- **Balance with integration.** Not balanced when:
  - the alcohol is hot (existing rule);
  - the oak dominates: oak is the most intense family and the wine has only light or medium(−) fruit;
  - the acidity is harsh: tart (existing rule);
  - the tannin is green or coarse (existing rule);
  - the wine is flabby or thin (existing rules).
- **Recalibration.**
  - Thresholds are tuned so that random practice pours spread roughly: Outstanding ≤ 10 %, Very good 20–30 %, Good
    25–35 %, Acceptable 20–30 %, Poor ≥ 3 % (**UNVERIFIED** target, for the Level 3 reviewer to confirm).
  - Today: 61 % are Very good or better, and Cabernet is almost always so.
  - The levers are the intensity and length thresholds (positive only at medium(+) with support, or pronounced/long), the
    complexity rule, and the integration tests.
  - A test pins the spread on a fixed sample of seeds.

### 3.4 Climate (Identify and Vintage cards)
- The region's absolute class comes from its average April–October temperature over the record years: cool ≤ 16.5 °C,
  moderate 16.5–18.5, warm 18.5–21, hot > 21 [UW-2016 p. 30].
- It is shown beside the relative class: "a warm year for the Mosel, in a cool climate (average 15.1 °C)".
- The Identify answer stays relative (the vintage question). The absolute class is shown in the "because" and on the
  Vintage card.

## 4. Marking and the learning core
- New scored lines (fruit ripeness, flavours) join the full-sheet exercise only. Shorter exercises keep their lines.
- Readiness options and the quality "because" change for every exercise and for the estate predictions.
- Cause tags follow the split families:
  - `ripeness-fruit-character` tags whichever fruit family is shown;
  - the aroma-family lists for questions, decoys and predictions use the new families;
  - "simple" is never a decoy.
- Pre-mark JSON keeps hiding answers; the new lines are stripped too.

## 5. Docs (Q11)
- `docs/science/tasting-sheet.md`:
  - the real scales;
  - the four readiness options, brown colours, other observations, the fruit split, simple, flavours, the quality
    argument and integration;
  - the calibration target and the new climate class.
- The alcohol bands are already the systematic approach's bands; this is confirmed by the coursebook [UW-2016 p. 7].

## 6. Out of scope
- The pepper family and Syrah.
- Rosé colours (the game has no rosé).
- The mousse line (no sparkling wine).
- Fortified alcohol bands.
- Tannin nature stays (it is ahead of Level 3).

## 7. Risks
- **Recalibration moves every quality verdict.** Practice records and Vintage cards don't store verdicts (pours are
  regenerated), and saves replay from commands, so nothing stored goes stale.
- **More scored lines make the full sheet longer.** It is already the long exercise, and two lines is acceptable.
- **The wording of readiness options sits close to the exam's.** The game stays private, and the options are reworded
  (research track C §8).
