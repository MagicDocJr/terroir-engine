# More fun, more learning: research synthesis and roadmap (2026-09-30)

The owner asked for a deep analysis of how to make Terroir Engine more fun and more gamified while keeping its simulator
feel, and how to make it help the player learn as much as possible. Three research tracks, each with verified sources:

- **A. Learning science and wine expertise:** `2026-09-30-a-learning-science.md` (references checked against Crossref)
- **B. Fun and gamification in simulation games:** `2026-09-30-b-fun-and-gamification.md`
- **C. WSET Level 3 and Diploma alignment:** `2026-09-30-c-wset-exam-alignment.md` (public WSET documents, paraphrased)

This page is the synthesis: what the evidence says, what to change in what already exists, and a ranked roadmap. It is a
proposal; nothing here is built yet.

---

## 1. The thesis in five lines

1. **One loop everywhere: predict → commit with confidence → reveal the cause.** It is the best-evidenced learning
   technique here (retrieval practice with elaborated feedback, g ≈ 0.5–0.7; A §1, §3). It is also the anticipation-and-reveal
   loop that makes sims fun (B §1). Put it on the estate (before every Tasting sheet, barrel sample, harvest) as well as in
   Tasting practice.
2. **Schedule causes, not Wines.** The thing to remember is "sun-exposed bunches + age → petrol", not "the 2011 Seitental
   glass". Each review should pour a *new* Wine with the same cause, spaced over days and weeks (A §1). Re-pouring the same
   Wine teaches the item, not the cause.
3. **Rewards must report mastery, not pay for activity.** Expected rewards for doing things undermine motivation
   (d ≈ −0.3); informational feedback raises it (d ≈ +0.33; Deci et al. 1999). A badges-and-leaderboard class lost
   motivation *and* exam marks (Hanus & Fox 2015). Ranks should mean "causes you know durably".
4. **Study together, cooperatively.** Answer individually, reveal side by side, discuss only the disagreements, then answer
   a fresh isomorphic question alone (A §9, B §5). A two-person leaderboard always makes one person lose.
5. **The biggest exam lever is breadth, the biggest unique lever is cause and effect.** Level 3 gives 56 % of the
   multiple-choice marks and 70 % of the written marks to regions (C §1). No flashcard app can teach the "because" chains the
   simulation already produces (C §5). Grow breadth without losing depth.

What the game cannot do: train the nose. Expert perception needs real glasses (Parr et al. 2002; A §7). The game trains the
schemas, the reasoning, the vocabulary and the systematic approach, which the literature says is a large part of expertise,
and it should organise real tasting (taste-along, comparison flights).

## 2. What we already do right

- A "because" on every descriptor. That is elaborated feedback, the strongest feedback type in computer-based learning
  (0.49 vs 0.05 for right/wrong; A §3).
- Real weather as evidence, vintage flights, and the Mosel ripeness ladder: vintage variation is exactly what Level 3 and D3
  reward (C §4).
- Prediction-style exercises (Cause to glass, the Fair's own Tasting sheet) and marking with partial credit.
- Science discipline: `UNVERIFIED`, calibration signals shown honestly, miscalibrated years kept out of practice.
- A serious tone with a cozy cellar: the right mood for adult learners (B §1).

## 3. What to change in what already exists (quick corrections)

These rework Tasting practice as built on 2026-09-29, informed by the research:

| # | Change | Why (evidence) | Effort |
|---|---|---|---|
| Q1 | **Confidence 1–3 before every reveal**; a "surprise" card for confident errors; full explanation for unsure correct answers | Hypercorrection; feedback doubles retention of low-confidence correct answers (A §3) | S |
| Q2 | **Show the "because" on correct answers too**, plus an end-of-Flight recap of the misses | Elaborated feedback; delayed re-exposure (A §3) | S |
| Q3 | **Mixed sessions** (about 60 % due reviews, 25 % weak spot, 15 % new) instead of always serving the weakest skill | Drilling one weak skill is blocking and feels punishing; interleaving g = 0.42 for similar categories (A §2) | S |
| Q4 | **Weekly rhythm instead of a daily streak** (5 of 7 days, repair by doing reviews, neutral wording) | Broken streaks cut engagement, repair softens it (Silverman & Barasch 2023); habits survive a missed day (Lally 2010) | S |
| Q5 | **Ranks from durable mastery**: an item is *Known* after 3 correct answers on 3 separate days; XP becomes a secondary tally | Rewards as information, not payment (Deci 1999); 3 + 3 relearning (Rawson & Dunlosky 2011) | S–M |
| Q6 | **Hide the label until after the judgement** at the Fair (producer, vintage and site revealed after Conclusions) | Expectation bias (Morrot et al. 2001); exam wines are blind | S |
| Q7 | **Competence graphs and a calibration curve** in place of XP totals ("acidity calls 58 % → 74 %"; confidence vs accuracy) | Performance graphs raise felt competence (Sailer 2017); calibration training (A §3) | S |
| Q8 | **Tasting-sheet conformance** with the systematic approach: readiness with four options (add too young / too old), brown colours, deposit and pétillance, split the white fruit family (green / citrus / stone / tropical), a pepper family for reds, credit for "simple", fresh/cooked and ripeness qualifiers, flavours asked separately | Stops teaching habits the exam penalises (C §2) | S–M |
| Q9 | **Quality as an argument, not a count**: positive and negative evidence and "why not the level above"; mark quality in bands and credit a justified neighbour; recalibrate the high skew with the Level 3 reviewer | The four-check count is a community heuristic, not WSET policy (C §2); judges are unreliable at points (Hodgson 2008) | M |
| Q10 | **Absolute climate class beside the relative one** ("a warm year for the Mosel, in a cool climate") | WSET uses absolute classes (C §4) | S |
| Q11 | Doc fixes: `tasting-sheet.md` still describes 3/4-step scales; the alcohol bands can now cite the WSET Diploma Tasting Guidance | Doc drift (C §2) | S |

## 4. The roadmap, ranked

Ranked by learning gain × fun ÷ effort, with dependencies. Each block is a candidate spec.

### Phase 1 — The learning core (highest value; mostly reshapes what exists)
1. **Cause items and a spaced review queue.**
   - Every descriptor's why-link becomes a reviewable *cause item*, mapped to a Level 3 topic.
   - Scheduling: a new or failed item comes back after 1, 3, 7, 16 and 35 days, then a light FSRS-style model per item
     (target retention 0.85–0.9). Never re-test in the same sitting.
   - Due items drive the Glass of the day and seed 1–2 glasses into every Stand.
   - Causes from the player's own Estate ("your 2018 Block B sunburn") become personal items. (A §1)
2. Quick corrections **Q1–Q7** above.
3. **Predict before reveal on the estate.** At every bottling, predict acidity, alcohol band, one key aroma family and
   quality, with confidence, before the Tasting sheet opens. It turns the core farming loop into generation practice.
   (A §5, B §1)
4. **Exam-date mode.**
   - Enter the exam date; the scheduler guarantees at least three spaced successes per syllabus item before it.
   - Late gaps are about 5–10 % of the remaining time (Cepeda et al. 2008); the last two to three weeks are tighter.
   - A syllabus coverage map, paraphrased. (A §1, §8)

### Phase 2 — Tasting-sheet conformance and quality reasoning
5. **Q8–Q11**, together with the reviewer calibration already in the backlog.
6. **Faded cause chains:** worked chain → one link blank → two links blank → full prediction, placed per topic by a short
   pretest. The Level 3 partner starts further along than the owner (expertise reversal). (A §4)
7. **Contrast Flights:** two Wines that differ in exactly one cause (same Block 2010 vs 2011, oaked vs unoaked, whole bunch
   vs destemmed): "which single cause separates them?" Blocked for the first 3–4 examples of a new category, then
   interleaved with confusable neighbours. (A §2)

### Phase 3 — Playing together
8. **Tasting duet** (pair Flight protocol):
   - The same Flight; each partner locks answers with confidence.
   - A side-by-side reveal, with "disagreement hotspots" to talk through.
   - Each partner then gets an isomorphic follow-up glass alone.
   - A team score, not head-to-head. (A §9, B §5)
9. **Explain-it cards:** one partner explains a cause chain aloud, the game shows the true chain; roles rotate (teaching
   helps the teacher; Fiorella & Mayer 2013).
10. **Parallel Vintages:** a seed code fixes Region, year and Block. Each partner makes their own Wine, then pours the other's
    blind, writes a Tasting sheet on it, and sees a diff of the decisions next to the descriptors they caused. (B §5)
11. **Taste-along and a comparison shopping list:**
    - Buy a real bottle matching a style; both partners fill in their Tasting sheet from the real glass.
    - Compare with the simulation's style prototype, showing honest bottle-variation bands.
    - Suggested real pairs isolate one cause (unoaked vs oaked Chardonnay, young vs aged Riesling for petrol, a cool vs a
      warm vintage of one appellation). A logged real tasting counts as a review.
    - The only route to the perceptual side of expertise. (A §7, B §8)

### Phase 4 — Simulator fun that teaches
12. **Famous-vintage scenarios with three medals and a debrief** (backlog shortlist):
    - Bronze: bottle a legal Wine in the 2016 Côte d'Or. Silver: keep Village level. Gold: hit a target structure.
    - Then a cited "what the real growers did" page. Goals are winemaking outcomes, never profit. (B §3)
13. **Blind-vintage mode:** play a hidden real year; the year and Region are revealed at bottling ("This was Mosel 2010").
    Needs the calibration fixes for the years it can draw. (B §3)
14. **Vintage in review:**
    - At bottling, a time-lapse of the Block, then 6–8 cause cards (the frost night, the heat spike, your pick date against
      the ripening curve).
    - Each card links to the descriptor it caused; they feed the review queue.
    - Descriptive, never a moral verdict. (B §4)
15. **Staged reveals in the cellar:** must numbers, then a barrel sample at 3 and 9 months (backlog), then bottling. Each is a
    predict-then-reveal moment. (B §1)
16. **"What if" with the simulation as the oracle:**
    - "If this Block had been leaf-plucked less, what changes in the glass?"
    - The model re-runs with one choice changed and shows the Tasting-sheet difference.
    - Only inside calibration ranges. Unique to a deterministic engine. (A §5)
17. **Discovery codex ("Terroirpedia"):** the first frost night, the first botrytis, the first stuck fermentation each open a
    cited page linked to the screen where you act. The unlock is the knowledge itself. (B §2)
18. **Instruments and a cellar log:**
    - a refractometer in the Region's unit, a hydrometer, a pH meter, a printed lab report
    - a dated cellar log for every operation (B §7)
19. **A label designer bound by real label law:** mandatory terms per Region, legality checked with cited reasons. Label law,
    learnt by making something you are proud of. (B §6)
20. **Assist levels that change information, not rules:**
    - *Guided* (hints, long forecasts), *Standard*, *True to life* (lab numbers only, sampling error, short forecasts)
    - Extends the backlog's Hard mode. (B §3)

### Phase 5 — Exam breadth (Level 3 first, then the Diploma)
21. **Chain-builder short answers** generated from the why-links: assemble factor → mechanism → effect → style from tiles
    with decoys. Marked exactly against the simulation, in 2–7-mark parts like the exam. Free-text answers get a rubric that
    needs cause and effect linked in one sentence, plus a self-marking checklist. (C §6)
22. **Rosé and carbonic / semi-carbonic maceration** as cellar options (Pinot Noir works for both); **Eiswein and
    Süssreserve** in the Mosel (the frost nights are already in the weather data). (C §7)
23. **More regions that reuse the four grapes:** Chablis and Mâconnais, Rheingau and Pfalz, Sonoma and Willamette,
    Marlborough and Central Otago, Coonawarra and Margaret River. Law and label multiple-choice bank as data. (C §7)
24. **A service desk:** storage, serving temperatures, decanting, food pairing, "a customer asks" scenarios; high-SO₂ and
    out-of-condition faults. About 14 % of Level 3 theory marks for little simulation work. (C §1, §7)
25. **New grapes:** Sauvignon Blanc, Merlot, Syrah/Shiraz, Grenache; then Chenin Blanc, Sangiovese, Nebbiolo, Tempranillo.
26. **Sparkling and fortified:**
    - Traditional-method sparkling simulated on the existing Chardonnay, Pinot and lees models.
    - Tank, Asti, Port, Sherry and Muscat as study cards.
27. **Diploma mode:**
    - A Diploma tasting format: texture, "will it improve or just hold", a seven-indicator quality argument, the
      2/6/10–12/6/3 marks.
    - Themed blind Flights with identification and reasons.
    - An evaluate/compare essay trainer using counterfactual runs.
    - Climate-trend analytics 1990–2025. (C §3, §7)

### Prerequisites (already in the backlog, now more urgent)
- The quality verdict skews high (blocks Q9, own-Wine shows, meaningful Conclusions practice).
- Côte d'Or frost is too frequent in 2019–2022, and Mosel 2010 is not reproduced (blocks blind-vintage mode and some
  scenarios).
- A cited bottle-ageing model before any vertical tastings or "too old" readiness.

## 5. Guardrails (what not to do)

- **No profit or estate value as the score**, no XP or currency for everything, no loot-style random rewards.
- **No outcome previews on sliders.** They kill the reveal and let players reverse-engineer numbers instead of learning.
- **No head-to-head leaderboards for two**; use team goals and decision diffs.
- **No punitive streaks or nag notifications.**
- **No re-pouring the same Wine as "review"**, and no items so hard that success stays under half without feedback.
- **Don't judge learning by in-session accuracy**; measure it with delayed checks. Players will prefer massed, blocked
  practice and rate it as better, so the scheduler decides, and explains why.
- **No narrative verdicts not grounded in the simulation's causes**, and no storyteller tampering with real weather.
- **No precise-looking numbers the calibration does not back** (verticals, show medals) until the model supports them.
- **No implying the game trains the nose.**
- **No WSET wording, grids or branding**; original questions in the exam's style are fine (C §8).
- **Don't invest in narrative polish expecting learning gains**: it is flavour (Adams et al. 2012). Put the effort into
  instructional support (Wouters & van Oostendorp 2013).

## 6. Recommendation: what to build next

1. **"Learning core" spec** (Phase 1 + Q1–Q7): cause items, the spaced queue, confidence before reveal, mixed sessions,
   mastery ranks, the weekly rhythm, predict-before-reveal on the estate, competence and calibration graphs. It reshapes
   what exists, carries the largest evidence-backed gain, and every later feature feeds the same queue.
2. **"Tasting sheet 2" spec** (Q8–Q11 + the quality recalibration with the Level 3 reviewer). It makes every existing
   exercise exam-faithful.
3. **"Play together" spec** (Tasting duet, explain-it cards, taste-along). It turns two people studying in parallel into
   studying together, which is where the research sees the biggest motivation gains for adults.

After those, famous-vintage scenarios and Vintage in review make the estate itself more fun; the Phase 5 breadth work is
the long road to the exam.
