# Vintage in review: the season replayed, and the causes behind your Wine

Status: draft for the owner's review (2026-10-03). Roadmap Phase 4 item 14 of
`docs/research/2026-09-30-fun-and-learning.md` (research track B §4), and the second item of the base-game order agreed
on 2026-10-03.

## 1. Intent

When a Vintage is fully in bottle, the game already opens its Vintage report: weather, key moments, Blocks, Wines,
money and "Next time". Vintage in review puts a new top section on that report:

1. **The season replayed.** An animated strip of the year: the temperature line against normal draws across the
   months, phenology markers appear (budburst, flowering, véraison, harvest), and pins appear for the season's events
   (frost night, heat spike, rain before harvest).
2. **6–8 cause cards**, each revealed as the sweep passes its date. A card shows:
   - what happened, in numbers ("26 April: −3.1 °C at Block A; 38 % of the young shoots killed");
   - what it did in your Wine: the Tasting-sheet line it shaped, with that line's own "because";
   - the Cause behind it, which joins your review queue with no answer counted.

**Why:** simulated stories land only when players can perceive the causes (research B §4). The sheet's why-links
already exist; this makes the year's chain visible at the moment the result arrives.

**Tone:** descriptive, never a verdict. "You picked on 12 September at 92 °Oe; the Wine has medium(+) acidity because…",
never "a mistake" or "should have". The existing "Next time" panel stays the place for suggestions.

**Success:**
- Every card is backed by simulation state and a Cause tagged on the Wine's sheet; no card without a link.
- The cards differ visibly between a frost year, a hot year and an easy year.
- The section adds about 10 seconds of watching, with a skip.
- No UI computation (ADR 0001).

## 2. Approaches considered

- **A (chosen): a new section at the top of the existing Vintage report.** One screen opens at the right moment (the
  report already opens once per fully bottled Vintage). The strip reuses the report's weekly temperature data.
- **B: a separate screen before the report.** Two screens in a row, and duplicated weather.
- **C: a 3D time-lapse replay of the Block.** The 3D view renders only the present state; replaying past states needs a
  history the game does not keep. Too costly for the gain.

## 3. Cause cards

**Source.**
- Cards come from the Causes tagged on the sheets of the Vintage's Wines (`TastingSheet.CauseLinks`), grouped by Cause.
- Each Cause is assigned to the moment it acted. Every card carries a date and evidence from simulation state:

  | Cause family | When | Evidence |
  |---|---|---|
  | `spring-frost-yield` | the frost night: the coldest night after budburst on which shoot loss rose | coldest temperature, shoot loss % per Block, yield hL/ha |
  | `cool-season-acid`, `warm-season-malic-loss` | véraison | growing-season temperature against the 1991–2020 normal |
  | `sunburn-cooked`, `sun-exposure-tdn`, `pyrazines-shade-cool` | the hottest day after véraison, or the leaf-removal date | Tmax, sunburned berries %, leaf removal side and timing, IBMP |
  | `noble-rot`, `grey-rot-taint` | the rain before harvest | rain in the three weeks before picking, rot % |
  | `ripeness-fruit-character`, `sugar-to-alcohol`, `seed-ripeness-tannin`, `yield-concentration` | the harvest date | °Oe, TA, pH, seed ripeness, yield |
  | Cellar Causes (`mlf-*`, `new-oak-*`, `old-oak-*`, `lees-*`, `whole-bunch-stems`, `stopped-ferment-sweetness`, `chaptalisation`, `acidification`, `cool-ferment-esters`, `extraction-colour-tannin`, `low-yan-h2s`) | the fermentation or bottling date | the Lot's choice, the measured value (malic and lactic, sugar left, YAN) |
  | Faults (`volatile-acidity`, `brett`, `oxidation`, `molecular-so2-ph`) | bottling | the measured value and its threshold |

- Each card shows the sheet line it is tagged on, with the line's level and "because" taken from the sheet (for
  example "Acidity: high — TA 8.2 g/L, pH 3.15: cool site and season kept malic acid").

**Selection.**
- At most 8 cards, at least the season's events present.
- Order of priority:
  1. faults;
  2. season events (frost, heat, rot);
  3. the harvest;
  4. cellar choices;
  5. the remaining Causes.
- Within each priority, chronological order.
- The cards come from the Vintage's best Wine, plus any season-event Causes on the Vintage's other Wines.
- A Vintage with fewer than 6 Causes shows what it has: an easy year honestly has fewer stories.

**Review queue.** The cards' Causes are enqueued once (`StudyRecord.Enqueue`), the first time the review is shown.

## 4. The season strip

- **Data:** the report's weekly temperatures (this year against normal); phenology dates from the season record of the
  best Wine's main Block; event pins from the cards' dates.
- **Animation:** a sweep from January to the harvest in about 6 seconds. The line draws, markers and pins appear, and each
  card fades in when the sweep passes its date. Skip and replay buttons are provided.
- **Capture and harness:** a `--report` run draws the final state (no animation) for screenshots.

## 5. Architecture

- **`sim/.../Game/VintageReview.cs`:** `Cards(GameSession g, int vintage) → JsonArray`, each card with id, cause, title,
  date, evidence lines, sheet line (attribute, level, because), wine, and priority; and `Strip(g, vintage) → JsonObject`
  (phenology dates, pins). It is pure and deterministic, and reads only state up to the bottling (ADR 0002).
- **`VintageReport.Json`** gains a `review` object (`cards`, `strip`) when the Vintage has bottled Wines.
- **Bridge:** `ReviewSeen(vintage)` enqueues the cards' Causes once (a game flag `review-seen-<vintage>` plus the study
  record).
- **UI:** `report.gd` gets the top section. The strip is a custom-drawn control (`learn_visuals.gd` style). The cards are
  panels in a flow.

## 6. Testing

- **Sim tests:**
  - frost year (Côte d'Or 2016): a frost card with the night's date and the shoot loss, linked to its sheet line;
  - hot year (Mosel 2018): a warm-season card;
  - every card's Cause is on a sheet of the Vintage;
  - at most 8 cards, sorted by priority then date;
  - no card text contains verdict words (mistake, should, wrong, bad, poor choice);
  - a Vintage with no bottled Wine has no review.
- **Harness:** the capture run screenshots the report with the review section, for a frost year and an easy year.

## 7. Out of scope (to the backlog)

- A 3D time-lapse replay.
- An Estate chronicle across Vintages.
- Cards for decisions that left no tagged Cause (they have no sheet link, by design).
- A "what if" re-run per card (roadmap Phase 4 item 16).
