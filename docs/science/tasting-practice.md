# Tasting practice and the Wine Fair

What the study mode simulates, where its facts come from, how it marks, and what is a game simplification. Design:
`docs/superpowers/specs/2026-09-29-tasting-practice-and-wine-fair-design.md`. Code: `sim/src/TerroirEngine.Core/Tasting/Practice/`.

## 1. Where the Wines come from

- **A scripted Estate per glass** (`TastingLab`): the Plot's Block is planted three years before the vintage and farmed on
  that year's recorded weather by the full simulation. It is picked by hand when the must reaches the style's ripeness
  target, earlier if grey rot passes 8 % (within 10 °Oe of the target), and at leaf fall at the latest. The style's cellar
  choices are applied, a stuck fermentation is restarted, and the Wine is bottled when ready. The Tasting sheet is the
  normal one (`tasting-sheet.md`), so every descriptor keeps its "because".
- **Ripeness targets** (game calibration): Mosel 84 °Oe, Côte d'Or 22.5 °Brix, Napa 25 °Brix, ± 3 °Oe seeded, plus the
  style's offset (light −8, extracted +10, new oak +3). The **Mosel ripeness ladder** uses fixed targets just above the
  legal minimums in `law.md` (Kabinett ≥ 73, Spätlese ≥ 80, Auslese ≥ 88 °Oe): 76, 83 and 95 °Oe.
- **Winemaker styles** (`WinemakerStyle`), shown only in the reveal. Riesling: dry, off-dry, and the Kabinett, Spätlese and
  Auslese ladder. Chardonnay: steel (no malolactic), old barriques, new French oak with lees stirring. Reds: the Region's
  classic way, light (earlier, gentler, cooler, old wood), extracted (later, warmer, longer, new oak). About 5 % of random
  pours get a **rustic cellar** (ambient yeast, low sulphur, long in old casks, natural cork) where faults can develop,
  because spotting faults is part of tasting exams. **Game simplification:** invented producers, a handful of scripted
  styles, a fixed fault rate.
- **When it is tasted:** "today" (2026), aged since the harvest but **at most 8 years**, and at least three months after
  bottling. **Game simplification:** the Tasting sheet's ageing model is not calibrated beyond 8 years, so older vintages are
  tasted as 8-year-old Wines.
- Determinism: a glass is a function of (Plot, Block, Variety, vintage, style, seed). Tests pin it.

## 2. Vintage facts (the weather record)

From the Region's ERA5 grid cell (`data/weather/README.md`, `weather-and-climate.md`), 1995 to the end of the record:

| Fact | Definition |
|---|---|
| Growing-degree days | Winkler index, April–October, daily mean above 10 °C (`weather-and-climate.md` §4.1) |
| Summer maximum | mean daily maximum, June–August |
| Hot days | days with a maximum ≥ 30 °C, June–August |
| Autumn rain | total precipitation, September–October |
| Coldest spring night | the lowest minimum, April–May, and its date |
| Rank | the vintage's place among the record's years by growing-degree days (1 = warmest) |

- The grid cell is the Region's reference weather, not a slope: frost lies colder in low spots, and the quiz says so.
- **Cool, moderate or warm** (Identify, Vintage cards): the warmest third of the record's years counts as warm, the coolest
  third as cool. **Game simplification:** relative to the Region's own record, not an absolute climate class.
- The 2016 Côte d'Or frost night comes out of the record on 27 April (−0.5 °C at the grid cell), matching the real frost of
  26–27 April (`vintage-notes.md`).

## 3. Wine Fair stands

Data in `data/fair_stands.json`; hosts and producers are invented. Each stand pours one site (fixed Plot and Block) so the
vintage or the cellar is the only difference:

- Burgundy 2003 · 2004 · 2005, the 2016 frost (2015 · 2016 · 2017), the Mosel ripeness ladder (2018), Chardonnay steel or
  oak (2018), Mosel 2002 · 2003 · 2004, Côte d'Or whites 2017 · 2018 · 2021.
- **Cool and warm stands** pick the years with the fewest and the most growing-degree days in the record (Mosel 1996 and
  2018, Napa 2010 and 2020), not hard-coded claims.
- A stand is only built where the simulation reproduces the real vintage. Mosel 2010 (tiny crop, very high acidity) and
  Côte d'Or 2019–2022 frost years are left out until they are calibrated (`docs/backlog.md`).

## 4. The vintage quiz

`VintageQuiz` asks 3–5 questions per Flight, each answered by one glass: hottest summer, warmest or coolest season, frost
loss (with the frost night), smallest crop, most or least acidic must, earliest picking, ripest or least ripe, sweetest,
most rain before harvest, which glass saw new oak, old oak or no wood. The evidence quotes the numbers for every glass.
A topic is skipped when its answer is not clear-cut in that Flight. **Design choice, not a science claim:** the margins are
0.8 °C summer maximum, 60 growing-degree days, 10 points of frost loss, 5 hL/ha, 0.5 g/L acidity, 3 days, 3 °Oe, 5 g/L
sugar and 15 mm rain.

The two explanatory lines in the acidity questions ("cooler seasons and earlier picking leave more malic acid", "heat burns
malic acid off") restate the ripening model's cited behaviour (`ripening.md` §4.1: warm conditions speed up malic acid loss).

## 5. Marking

`TastingMarker` marks against the Wine's own Tasting sheet:

- ordered scales (intensities, sweetness, acidity, tannin, alcohol, body, finish, quality): 1 for an exact match, ½ one
  step off, 0 otherwise
- categorical items (clarity, colour, development, readiness, grape, Region, cool/moderate/warm, each quality criterion):
  1 or 0
- aroma families: shared families over all families named (Jaccard overlap)
- a hint costs ½ mark; nothing picked scores 0 and still shows the answer and its "because"

Picker options come from the model's own vocabulary, so the player can always pick exactly what the sheet says.

## 6. Progression (why it is shaped this way)

Every reward is earned by a marked answer. Design rationale, not in-game facts: gamification means game design elements in
a non-game context [DETERDING-2011]; spaced practice and retrieval practice improve long-term retention [CEPEDA-2006],
[ROEDIGER-2006], hence the daily glass, the quizzes and the reveal that explains each answer.

- **XP:** 10 per full mark (5 for half), −5 per hint; medal bonuses (bronze 20, silver 40, gold 80, paid once per
  improvement); Glass of the day +25.
- **Taster ranks:** Novice taster 0, Cellar hand 300, Taster 1,500 (opens blind Flights), Senior taster 5,000, Fair judge
  12,000 XP. Paced for months of study: a Flight at half marks earns roughly 250 XP.
- **Medals:** bronze, silver, gold at 50, 70 and 85 % of a stand's marks; the best is kept. One medal opens the second tier
  of stands, three open the third.
- **Glass of the day:** the same Wine for everyone on a date, Identify format; days in a row count consecutive daily
  glasses, and a missed day resets the run without costing rank.
- **Adaptive practice:** the weakest skill (lowest average of the last 20 answers, at least three answers) picks the next
  Wine: a red for tannin or appearance, Riesling across the sweetness range for sweetness, and so on.
- The study record is `user://tasting_record.json`, separate from any Estate save, and tolerant of missing or unknown fields.

## 7. No future knowledge (ADR 0002)

- From the title screen every vintage from 1995 to the end of the record can be poured.
- Inside a game only vintages whose harvest is over on its Timeline: this year's from 1 December, otherwise last year's.
  **Game simplification:** one cut-off date for every Region and style.
- A stand with a later vintage is locked and hides its theme ("The 2016 frost" would itself be future knowledge); Vintage
  cards for later years stay hidden in that game.
- Real vintage notes (`vintage-notes.md`, mirrored in `data/vintage_notes.json`) show only in reveals and the Cellar book,
  only with a source, and never as a prediction. Where the simulated Wine differs from the note, the reveal shows both:
  that is a calibration signal, not something to hide.

## 8. Known gaps (calibration, tracked in `docs/backlog.md`)

- Côte d'Or spring frost is too frequent for early-budding vines (2019, 2020, 2022 losses far above reality).
- Mosel 2010's small crop and very high acidity are not reproduced.
- Côte d'Or 2003 is picked in mid-September; the real harvest began in August.
- The Tasting sheet's quality verdict skews high (mostly Very good and Outstanding), which makes the Conclusions exercise
  easier than it should be.

## Sources

- [DETERDING-2011] Deterding, S., Dixon, D., Khaled, R. & Nacke, L. (2011). From game design elements to gamefulness:
  defining "gamification". Proceedings of the 15th International Academic MindTrek Conference, ACM, pp. 9–15.
  https://www.researchgate.net/publication/230854710_From_Game_Design_Elements_to_Gamefulness_Defining_Gamification
- [CEPEDA-2006] Cepeda, N. J., Pashler, H., Vul, E., Wixted, J. T. & Rohrer, D. (2006). Distributed practice in verbal recall
  tasks: a review and quantitative synthesis. Psychological Bulletin 132(3), 354–380.
  https://digitalcommons.usf.edu/psy_facpub/1771/
- [ROEDIGER-2006] Roediger, H. L. & Karpicke, J. D. (2006). Test-enhanced learning: taking memory tests improves long-term
  retention. Psychological Science 17(3), 249–255. https://journals.sagepub.com/doi/10.1111/j.1467-9280.2006.01693.x
