# The learning core: Causes, the review queue and learn cards

How the game teaches, which learning research each mechanism rests on, and which numbers are design choices rather than
values from studies. This file holds method, not wine facts: every wine fact a Cause or learn card states is cited in the
other `docs/science/` files it links to. Design: `docs/superpowers/specs/2026-10-02-learning-core-design.md`. Evidence
review: `docs/research/2026-09-30-a-learning-science.md` (track A). Code: `sim/src/TerroirEngine.Core/Learning/`.

**Design numbers.** The ladder, the session mix, the Known rule, the rank thresholds, the exam caps and the word limits are
design choices *informed* by the evidence; no study gives these exact values. They are marked **UNVERIFIED** below.
Track A's own note on uncertainty says the same.

## 1. Causes: what is learnt

- A **Cause** is one cause chain from a choice, a site, a vintage or a fault to what it does in the glass (for example "cool
  fermentation → yeast keeps more fruity esters → pear and banana on the nose"). The catalogue is `data/causes.json`
  (34 Causes). Each one carries the Tasting sheet line it explains, its chain of 2–4 steps, its area and a source heading in
  `docs/science/` that the tests resolve (`CauseCatalog.SourceResolves`).
- The Tasting sheet tags every line whose "because" shows a Cause (`TastingSheet.CauseLinks`). Tags mirror the conditions
  that write the "because" text; tests guard that the two never drift apart.
- **Why chains rather than descriptors.** Expertise in wine is largely conceptual and verbal: experts outperform novices
  on knowledge of what causes a character and on naming it, far more than on raw smell thresholds [HUGHSON-2002],
  [PARR-2002], [CROIJMANS-2016]. A game can train that knowledge; it cannot train the nose (§9).
- `reviewBy: chain`: Causes no practice pour can show yet (faults, sunburn, noble rot, grey rot, H₂S, steep-slope labour,
  lime chlorosis) are reviewed as chain questions only. **Game simplification:** they are learnt as reasoning, not seen in a
  glass.

## 2. The review queue

Retrieval with feedback beats re-reading [ROEDIGER-2006], [ROWLAND-2014], [ADESOPE-2017]; spaced retrieval beats massed
retrieval [CEPEDA-2006], [LATIMIER-2021]; the best gap grows with how long the knowledge must last [CEPEDA-2008].
Expanding and equal gaps both work over the long term [KANG-2014], [KARPICKE-2007], so the schedule starts on an
expanding ladder and then hands over to a stability model of the kind used by modern schedulers [FSRS-ABC], [YE-2022].

`ReviewScheduler.Review` (**UNVERIFIED** parameter values):

| Rule | Value |
|---|---|
| Ladder for a new or missed Cause | 1, 3, 7, 16, 35 days |
| After the ladder | stability starts at 35 days and grows by ×(1 + gain) per right answer, gain = 0.3 / 0.8 / 1.2 for guess / think so / sure, × (11 − difficulty) / 10, at least ×1.1 |
| Difficulty | 1–10, starts at 5; +1 on a miss, +0.5 on a guessed right answer on the ladder, −0.3 / −0.1 on sure / think-so right answers |
| A miss | due the next day, ladder restarts, stability halved (at least 1 day) |
| A right answer marked "guess" on the ladder | repeats the previous rung instead of climbing (it was not yet retrieved reliably) |
| Same day | one sitting counts once: a further right answer on a day already reviewed is recorded, not rewarded |
| Clock going backwards | the last seen date is used, so nothing is scheduled into the past |
| Longest interval | 3,650 days |

A wrong answer is followed by the right one and its explanation at once; feedback after an error matters most
[BUTLER-ROEDIGER-2008], [HATTIE-2007], [WISNIEWSKI-2020].

## 3. Known and Taster rank

- **Known** (**UNVERIFIED**): right on three separate days; two misses in a row return it to learning. Spaced successes
  rather than one correct answer, because a single success right after study overstates retention [SODERSTROM-2015],
  [RAWSON-2011].
- **Taster rank** follows the share of the catalogue the player Knows: 0, 15, 40, 70 and 95 % (**UNVERIFIED**). It replaced
  the XP thresholds so that rank measures what is still known, not how much was answered; XP, medals and Vintage cards stay
  as records of play. Rewards tied to mastery rather than volume protect intrinsic motivation [DECI-1999],
  [RYAN-DECI-2000]; gamification works best when its elements inform about competence [SAILER-2020].
- A v1 study record (the Tasting-practice release) migrates without loss; ranks are recomputed from Known Causes.

## 4. Sessions: what a day's review contains

- About six items: 60 % due Causes, 25 % from the weakest skill, 15 % new (**UNVERIFIED** mix), filled from Causes still
  being learnt when the due list is short (`SessionComposer`).
- **Interleaving.** Causes from different areas are mixed in one session; interleaving helps most when the categories are
  easily confused [BRUNMAIR-2019], [KORNELL-BJORK-2008], [CARVALHO-2014]. **Contrast pairs** set two Wines side by side
  that differ in the one Cause under review.
- **Fading.** A new Cause is met as a chain with one step blanked; the next review blanks two; from the third it is
  checked by predicting a real Wine. Worked examples first and fading support later suit novices, while full support slows
  down learners who already know the material [RENKL-2003], [KALYUGA-2003], [SWELLER-2019].
- **Wine items.** A mature Cause is checked by a poured Wine: read its site, vintage and winemaking, predict the line, then
  see the sheet. Predicting first, even wrongly, improves learning from the answer [KORNELL-2009], [RICHLAND-2009],
  [PAN-CARPENTER-2023].
- When no Wine can show a due Cause (an early game's locked years, a miscalibrated vintage), the session falls back to a
  chain question for it; a session is never empty.

## 5. Confidence and the four cases

- Every answer carries a Confidence: guess, think so, sure. The reveal sorts answers into four cases: sure and right,
  guessed and right, sure and wrong, guessed and wrong.
- Feedback on right answers given with low confidence improves their retention [BUTLER-2008]; errors made with high
  confidence are corrected especially well once the right answer is shown [BUTTERFIELD-2001], [METCALFE-2017]. So the
  sure-and-wrong case gets the most prominent explanation.
- A guessed right answer counts as right for Known but is scheduled like a near miss. Half credit counts as right but is
  scheduled like a guess.
- **Calibration** (Progress view): accuracy per confidence level. Over-confidence leads learners to stop studying too early
  [DUNLOSKY-RAWSON-2012]; showing the gap is the corrective.

## 6. The weekly rhythm

- The goal is five study days in each Monday-to-Sunday week (**UNVERIFIED**). A missed day can be repaired: every five
  reviews beyond the first five on a day repair one missed day of that week.
- **Why not a daily streak.** Broken streaks make people disengage [SILVERMAN-2023], and habits form over weeks to months
  with large individual spread [LALLY-2010]. A forgiving weekly target keeps the habit without punishing one missed day.
  The Glass of the day still counts its own run of days for those who want it.

## 7. The exam date

- Optional, set on Tasting practice (three dropdowns; the sim checks the date exists, is after today and is within five
  years).
- With a date set, gaps are capped at about a tenth of the days left (at least 3), and at 3–5 days in the last three weeks
  (**UNVERIFIED**). This follows the ridgeline finding that the best gap shrinks as the test comes closer [CEPEDA-2008].
- After the date has passed, the cap no longer applies, and the screen asks the player to set the next date or clear it.

## 8. Predict, then reveal, on the Estate

- Before a new Wine's Tasting sheet opens, the player predicts its acidity, alcohol, the aroma family that will stand out
  besides fruit, and its quality, each with a Confidence. The player may skip.
- The player then recalls what up to two of their own choices did in this Wine (choice recall). The game asks only about
  choices whose Cause is tagged on the Wine's sheet.
- Answers update the review queue like session answers. Generating an answer before seeing it, and then explaining it,
  strengthens learning [BERTSCH-2007], [BISRA-2018], [CHI-1994].
- Marking reads the Wine's own sheet and never changes the Wine (ADR 0001). No prediction uses anything the player could
  not know yet (ADR 0002).

## 9. Learn cards at the moment of choice

- Twelve cards (`data/learn/*.json`) open in a side drawer from the choice they explain: training system, rootstock, harvest
  date, leaf removal, green harvest, whole bunch, fermentation temperature, yeast nitrogen, malolactic, oak, lees, stopping
  for sweetness. The screen behind stays usable.
- **Fixed structure:**
  - what it is, with a visual drawn from simulation data, not from a stock picture;
  - what it does in the wine, as cause chains;
  - on this site, a line computed from the player's own Block or Lot by the sim's own rules (`LearnCards.SiteLine`);
  - when to choose what;
  - what the exam wants;
  - a check question with Confidence, which adds the card's Causes to the review queue;
  - the card's sources.
- **Why at the moment of choice.** Instruction tied to a decision the learner is about to make supports learning in
  simulations and games; unguided discovery does not [WOUTERS-2013B], [KIRSCHNER-2006], [MAYER-2019]. Relating a choice
  to the player's own site works as elaborative interrogation (asking why this holds here) [DUNLOSKY-2013].
- **Quality gate** (`LearnCards.Problems`, run by the tests):
  - 120–180 words of prose (**UNVERIFIED** limit, to keep cognitive load low [SWELLER-2019]);
  - 1–3 chains of 2–4 steps;
  - every source resolves to a heading in `docs/science/`;
  - a complete check question;
  - no exam-board wording and no UNVERIFIED claim.

  All twelve cards also passed an independent review against a teaching rubric before shipping.
- A card whose Causes are all Known opens in its brief form: the full card would now slow the learner down (expertise
  reversal [KALYUGA-2003]).

## 10. What the game cannot teach (labelled in the game)

- Smell and taste recognition need real glasses. Training with real samples improves experts' thresholds and
  identification [TEMPERE-2012], [TEMPERE-2016]; reading descriptions does not replace it. The Progress view says so in
  one line.
- **Game simplification:** Causes are taught as the simulation models them. Where the model and the literature disagree,
  the Cause is withheld or reviewed by chain only, and the gap is in `docs/backlog.md`.

## Sources

Full entries with DOIs (checked against Crossref) are in `docs/research/2026-09-30-a-learning-science.md`, References.

- [ADESOPE-2017] Adesope, Trevisan & Sundararajan (2017), Review of Educational Research 87, 659–701. https://doi.org/10.3102/0034654316689306
- [BERTSCH-2007] Bertsch, Pesta, Wiscott & McDaniel (2007), Memory & Cognition 35, 201–210. https://doi.org/10.3758/BF03193441
- [BISRA-2018] Bisra, Liu, Nesbit, Salimi & Winne (2018), Educational Psychology Review 30, 703–725. https://doi.org/10.1007/s10648-018-9434-x
- [BRUNMAIR-2019] Brunmair & Richter (2019), Psychological Bulletin 145, 1029–1052. https://doi.org/10.1037/bul0000209
- [BUTLER-2008] Butler, Karpicke & Roediger (2008), JEP: LMC 34, 918–928. https://doi.org/10.1037/0278-7393.34.4.918
- [BUTLER-ROEDIGER-2008] Butler & Roediger (2008), Memory & Cognition 36, 604–616. https://doi.org/10.3758/MC.36.3.604
- [BUTTERFIELD-2001] Butterfield & Metcalfe (2001), JEP: LMC 27, 1491–1494. https://doi.org/10.1037/0278-7393.27.6.1491
- [CARVALHO-2014] Carvalho & Goldstone (2014), Memory & Cognition 42, 481–495. https://doi.org/10.3758/s13421-013-0371-0
- [CEPEDA-2006] Cepeda, Pashler, Vul, Wixted & Rohrer (2006), Psychological Bulletin 132, 354–380. https://doi.org/10.1037/0033-2909.132.3.354
- [CEPEDA-2008] Cepeda, Vul, Rohrer, Wixted & Pashler (2008), Psychological Science 19, 1095–1102. https://doi.org/10.1111/j.1467-9280.2008.02209.x
- [CHI-1994] Chi, De Leeuw, Chiu & LaVancher (1994), Cognitive Science 18, 439–477. https://doi.org/10.1207/s15516709cog1803_3
- [CROIJMANS-2016] Croijmans & Majid (2016), PLOS ONE 11, e0155845. https://doi.org/10.1371/journal.pone.0155845
- [DECI-1999] Deci, Koestner & Ryan (1999), Psychological Bulletin 125, 627–668. https://doi.org/10.1037/0033-2909.125.6.627
- [DUNLOSKY-2013] Dunlosky, Rawson, Marsh, Nathan & Willingham (2013), Psychological Science in the Public Interest 14, 4–58. https://doi.org/10.1177/1529100612453266
- [DUNLOSKY-RAWSON-2012] Dunlosky & Rawson (2012), Learning and Instruction 22, 271–280. https://doi.org/10.1016/j.learninstruc.2011.08.003
- [FSRS-ABC] "ABC of FSRS", open-spaced-repetition project wiki. https://github.com/open-spaced-repetition/awesome-fsrs/wiki/ABC-of-FSRS
- [HATTIE-2007] Hattie & Timperley (2007), Review of Educational Research 77, 81–112. https://doi.org/10.3102/003465430298487
- [HUGHSON-2002] Hughson & Boakes (2002), Food Quality and Preference 13, 463–472. https://doi.org/10.1016/S0950-3293(02)00051-4
- [KALYUGA-2003] Kalyuga, Ayres, Chandler & Sweller (2003), Educational Psychologist 38, 23–31. https://doi.org/10.1207/S15326985EP3801_4
- [KANG-2014] Kang, Lindsey, Mozer & Pashler (2014), Psychonomic Bulletin & Review 21, 1544–1550. https://doi.org/10.3758/s13423-014-0636-z
- [KARPICKE-2007] Karpicke & Roediger (2007), JEP: LMC 33, 704–719. https://doi.org/10.1037/0278-7393.33.4.704
- [KIRSCHNER-2006] Kirschner, Sweller & Clark (2006), Educational Psychologist 41, 75–86. https://doi.org/10.1207/s15326985ep4102_1
- [KORNELL-2009] Kornell, Hays & Bjork (2009), JEP: LMC 35, 989–998. https://doi.org/10.1037/a0015729
- [KORNELL-BJORK-2008] Kornell & Bjork (2008), Psychological Science 19, 585–592. https://doi.org/10.1111/j.1467-9280.2008.02127.x
- [LALLY-2010] Lally, van Jaarsveld, Potts & Wardle (2010), European Journal of Social Psychology 40, 998–1009. https://doi.org/10.1002/ejsp.674
- [LATIMIER-2021] Latimier, Peyre & Ramus (2021), Educational Psychology Review 33, 959–987. https://doi.org/10.1007/s10648-020-09572-8
- [MAYER-2019] Mayer (2019), Annual Review of Psychology 70, 531–549. https://doi.org/10.1146/annurev-psych-010418-102744
- [METCALFE-2017] Metcalfe (2017), Annual Review of Psychology 68, 465–489. https://doi.org/10.1146/annurev-psych-010416-044022
- [PAN-CARPENTER-2023] Pan & Carpenter (2023), Educational Psychology Review 35. https://doi.org/10.1007/s10648-023-09814-5
- [PARR-2002] Parr, Heatherbell & White (2002), Chemical Senses 27, 747–755. https://doi.org/10.1093/chemse/27.8.747
- [RAWSON-2011] Rawson & Dunlosky (2011), JEP: General 140, 283–302. https://doi.org/10.1037/a0023956
- [RENKL-2003] Renkl & Atkinson (2003), Educational Psychologist 38, 15–22. https://doi.org/10.1207/S15326985EP3801_3
- [RICHLAND-2009] Richland, Kornell & Kao (2009), JEP: Applied 15, 243–257. https://doi.org/10.1037/a0016496
- [ROEDIGER-2006] Roediger & Karpicke (2006), Psychological Science 17, 249–255. https://doi.org/10.1111/j.1467-9280.2006.01693.x
- [ROWLAND-2014] Rowland (2014), Psychological Bulletin 140, 1432–1463. https://doi.org/10.1037/a0037559
- [RYAN-DECI-2000] Ryan & Deci (2000), American Psychologist 55, 68–78. https://doi.org/10.1037/0003-066X.55.1.68
- [SAILER-2020] Sailer & Homner (2020), Educational Psychology Review 32, 77–112. https://doi.org/10.1007/s10648-019-09498-w
- [SILVERMAN-2023] Silverman & Barasch (2023), Journal of Consumer Research 49, 1095–1117. https://doi.org/10.1093/jcr/ucac029
- [SODERSTROM-2015] Soderstrom & Bjork (2015), Perspectives on Psychological Science 10, 176–199. https://doi.org/10.1177/1745691615569000
- [SWELLER-2019] Sweller, van Merriënboer & Paas (2019), Educational Psychology Review 31, 261–292. https://doi.org/10.1007/s10648-019-09465-5
- [TEMPERE-2012] Tempere, Cuzange, Bougeant, de Revel & Sicard (2012), Chemosensory Perception 5, 205–213. https://doi.org/10.1007/s12078-012-9120-1
- [TEMPERE-2016] Tempere, Hamtat, de Revel & Sicard (2016), Australian Journal of Grape and Wine Research 22. https://doi.org/10.1111/ajgw.12192
- [WISNIEWSKI-2020] Wisniewski, Zierer & Hattie (2020), Frontiers in Psychology 10, 3087. https://doi.org/10.3389/fpsyg.2019.03087
- [WOUTERS-2013B] Wouters & van Oostendorp (2013), Computers & Education 60, 412–425. https://doi.org/10.1016/j.compedu.2012.07.018
- [YE-2022] Ye, Su & Cao (2022), Proc. 28th ACM SIGKDD, 4381–4390. https://doi.org/10.1145/3534678.3539081
