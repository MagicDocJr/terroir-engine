# Research track A — Learning science for the study mode

Part of the 2026-09-30 fun-and-learning research (synthesis: `2026-09-30-fun-and-learning.md`). Written by a research agent; references checked against Crossref.


**Method.** I checked every reference below against Crossref (DOI, authors, year, venue, volume, pages). I took effect sizes from abstracts I retrieved through OpenAlex/Crossref, or from publisher, ERIC or PubMed-indexed summaries. Where I could not confirm a number, I left it out. No repository files were changed.

**Strength labels.** *Strong* means several meta-analyses or many replications. *Moderate* means one meta-analysis, or consistent experiments in a narrower domain. *Weak* means few studies, or an inference from a neighbouring domain.

**A general caveat.** Most spacing and testing research uses verbal facts and vocabulary. Studies of causal, multi-step knowledge like "weather → vine → must → wine → glass" are fewer. So "strong" below means strong for fact retention and moderate for causal transfer.

---

## 1. Retrieval practice, spacing and schedules

**Key findings**
- **Retrieval practice beats restudy (strong).**
  - Rowland (2014): g ≈ 0.50 against restudy. With feedback the effect was 0.73; without it, 0.39. There was no testing effect when initial success was ≤50% and no corrective feedback was given.
  - Adesope et al. (2017): +0.51 against restudy and +0.93 against filler or no activity.
  - Testing also transfers (Pan & Rickard 2018: d = 0.40). Transfer is largest for application and inference questions and when retrieval is *elaborated*. After correcting for publication bias, transfer is often near zero when none of these moderators are present.
- **Spacing beats massing (strong).**
  - Cepeda et al. (2006) synthesised the verbal-recall literature.
  - Cepeda et al. (2008), N > 1,350, retention intervals up to a year: the best gap between study sessions grows with the retention interval. As a share of that interval it *shrinks*: about 20–40% for a 1-week test, about 5–10% for a 1-year test.
- **Spaced retrieval vs massed retrieval (moderate–strong).** Latimier, Peyre & Ramus (2021): g = 0.74.
- **Expanding vs equal intervals: no reliable difference (moderate).**
  - Latimier et al. (2021): g = 0.034, not significant.
  - Karpicke & Roediger (2007): what matters is *delaying the first retrieval*. Expanding the later gaps adds little.
  - Kang et al. (2014): over 4 weeks of training, final recall at 8 weeks was equal. But the expanding schedule kept recall much higher *during* training, so learners fail less often.
- **Criterion plus relearning (moderate).** Rawson & Dunlosky (2011) used conceptual material and tested 1–4 months later. Their recommendation: recall each item correctly 3 times in the first session, then relearn it 3 times at widely spaced sessions. Relearning brought large durability gains for few extra trials.
- **Personalised scheduling (moderate).**
  - Lindsey et al. (2014), a semester-long course: personalised review gave +16.5% retention over massed study and +10.0% over a one-size-fits-all spaced schedule.
  - Model-based schedulers exist and are published: Tabibian et al. 2019 (PNAS); Ye, Su & Cao 2022 (KDD), which underlies FSRS.
  - FSRS models Difficulty, Stability and Retrievability, and schedules each review for a target recall probability. Its documentation suggests a target retention of 70–97%.
- **Learners misjudge spacing (strong).** Kornell (2009): spacing beat massing for 90% of participants, yet 72% believed massing had worked better.

**Design implications for Terroir Engine**
1. **Schedule causes, not Wines.** The unit of review should be a *cause→effect item*, such as "TDN/petrol ← sun-exposed bunches + bottle age", "cool vintage → high acid, lower alcohol, green notes" or "2003 heat → low acid, jammy". Each review pours a *new* Wine that shows the same cause, with a different vintage, Block or producer. This turns retrieval into transfer, which is where Pan & Rickard found the largest gains.
2. **Default ladder, then an adaptive model.** A new or failed item reappears after about 1, 3, 7, 16 and 35 days. After that, a light FSRS-style model per item with target retention around 0.85–0.90 takes over. Equal and expanding gaps are equivalent, so choose expanding: it keeps in-training success higher, which is good for motivation (Kang 2014).
3. **Never re-test within the same sitting.** The first retrieval of a newly learned item should come in the *next* session, not three questions later (Karpicke & Roediger 2007).
4. **Mastery rule.** An item is "Known" only after 3 correct answers spread across at least 3 separate days (Rawson & Dunlosky's 3+3). Only Known items count toward Taster rank.
5. **Exam-date mode.** The player enters a WSET exam date. For a 3–12 month horizon, the scheduler keeps late-stage gaps at about 5–10% of the remaining time (Cepeda 2008). It makes sure every syllabus item gets ≥3 spaced successful retrievals before the date, and in the final 2–3 weeks it shortens gaps (for example, 3–5 days).
6. **Put reviews into the game loop, not a flashcard screen.**
   - Due items drive the daily glass.
   - Due items seed Wine Fair Flights: each Stand includes 1–2 due causes.
   - When a Vintage card is due, it reopens as a *question* ("What did the 2016 frost do to yield and concentration?"), not as reading.
   - Notable causes from the player's own estate ("your 2018 Block B sunburn") become personal review items.
7. **Keep scheduling automatic, and explain it** (see §8). Learners would choose massed practice if left to themselves.

## 2. Interleaving vs blocking; desirable difficulties

**Key findings**
- **Interleaving helps inductive category learning (strong).**
  - Brunmair & Richter (2019), 59 studies: g = 0.42 overall. Paintings g = 0.67; maths g = 0.34; words g = −0.39.
  - Effects are larger when categories are *similar to each other*, when exemplars *vary within* a category, and when material is complex. The authors advise caution with expository texts and words.
- **Interleaving works through contrast, and depends on category structure (moderate).**
  - Kornell & Bjork (2008): learning painters' styles benefited from interleaving, yet participants rated blocking as more effective even after their own results showed the opposite.
  - Carvalho & Goldstone (2014): interleaving helps *highly similar* categories through between-category comparison. Blocking helps *dissimilar* categories through within-category comparison.
- **The belief that blocking is better is stubborn (moderate).** Yan, Bjork & Bjork (2016) only shifted it by showing learners their own blocked and interleaved scores *separately*, combined with an explanation.
- **Variability in training examples supports generalisation (moderate, review).** Raviv, Lupyan & Green (2022).
- **Desirable difficulties can backfire.**
  - Performance during training is a poor measure of learning (Soderstrom & Bjork 2015).
  - Difficulty backfires when learners cannot succeed at all and get no feedback (Rowland 2014, above).
  - It also backfires when novices face high element interactivity without guidance (Chen, Kalyuga & Sweller 2015; §4).

**Design implications**
1. **Block first, then interleave.** The first 3–4 exemplars of a new category, such as "Mosel Riesling structure", come as a short block. After that, the Identify exercise always mixes confusable neighbours: Côte d'Or vs Napa Pinot or Chardonnay, cool vs warm vintage of the same site, young vs aged Riesling.
2. **Contrast Flights.** Pour two Wines that differ in exactly *one* cause, side by side: same Block with 2010 vs 2011, oaked vs unoaked, whole bunch vs destemmed. Ask "What single cause separates these?" This is the between-category comparison mechanism in its purest form.
3. **Fix the weak-spot rule.** Serving only the lowest-average skill (the current rule: lowest average of the last 20 answers) is effectively blocking, and it is demoralising. Mix each session instead, for example 60% due reviews, 25% weak spot and 15% new.
4. **Show the player the evidence.** Keep interleaved and blocked accuracy separate in the Cellar book, and show both on delayed checks (the Yan et al. debiasing method).

## 3. Feedback, confidence, hypercorrection and calibration

**Key findings**
- **Feedback overall (strong).** Wisniewski, Zierer & Hattie (2020): d = 0.48. Effects depend strongly on how much information the feedback carries.
- **Computer-based feedback types (moderate).** Van der Kleij et al. (2015): elaborated or explanatory feedback 0.49; correct answer shown 0.32; right/wrong only 0.05. Elaborated feedback is especially strong for higher-order outcomes.
- **Timing (mixed).**
  - Lab studies often favour delayed feedback because it adds a spaced re-exposure (Butler, Karpicke & Roediger 2007; Metcalfe, Kornell & Finn 2009).
  - Van der Kleij found immediate feedback better for lower-order outcomes and delayed feedback better for higher-order ones, but the interaction was not significant.
- **Feedback on correct answers matters (moderate).** Butler, Karpicke & Roediger (2008): feedback *doubled* retention of correct answers given with low confidence.
- **Feedback prevents multiple-choice lures from being learned (moderate).** Butler & Roediger (2008).
- **Hypercorrection (moderate–strong).** Errors made with high confidence are more likely to be corrected after feedback (Butterfield & Metcalfe 2001; reviewed in Metcalfe 2017).
- **Calibration (moderate).**
  - Overconfidence makes learners stop studying too early, which lowers later retention (Dunlosky & Rawson 2012).
  - Delaying judgments of learning greatly improves their accuracy: g = 0.93 for relative accuracy (Rhodes & Tauber 2011).

**Design implications**
1. **Confidence before reveal.** On every marked answer, ask for confidence on a 1–3 scale ("guess / think so / sure"). It costs one tap.
2. **React to the four cases.**
   - *Sure and wrong:* a prominent "surprise" card with the full causal chain, and the item rescheduled for tomorrow.
   - *Guess and right:* still show the full explanation, and treat the item as "hard" in the scheduler.
   - *Sure and right:* a short confirmation, with the chain available on tap.
   - *Guess and wrong:* feedback plus a scaffolded hint the next time.
3. **Always give elaborated feedback.** The existing "descriptor ← cause ← condition" chain is already elaborated feedback, the strongest type in computer-based settings. Show it for *correct* answers as well.
4. **Two feedback moments.** Give immediate elaborated feedback for each answer. Then add an end-of-Flight recap that re-shows only the misses a few minutes later, which captures the delayed-feedback benefit.
5. **Calibration display.** The Cellar book shows a calibration curve per skill (confidence level vs actual accuracy) and a single Brier-style number. Occasionally ask a delayed judgment: "Will you get this cause right next week?" Score the prediction when the item comes due.
6. **Distractors.** Multiple-choice distractors in Identify should be plausible neighbours, which also serves interleaving. They must always be followed by feedback (Butler & Roediger 2008).

## 4. Worked examples, fading, cognitive load, expertise reversal

**Key findings**
- **Worked examples beat unguided problem solving for novices on high element-interactivity material (strong).** Sweller, van Merriënboer & Paas (2019); Kirschner, Sweller & Clark (2006).
- **Expertise reversal (strong).** Guidance that helps novices can become redundant, or even harmful, for more knowledgeable learners (Kalyuga et al. 2003).
- **Fading (moderate).** Gradually replacing worked steps with steps the learner must complete eases the move from studying examples to solving problems (Renkl & Atkinson 2003).
- **Element interactivity reconciles two effects (moderate).** Chen, Kalyuga & Sweller (2015): the generation effect holds for low-interactivity material. The worked-example effect holds for high-interactivity material, and it disappears or reverses as expertise grows.

**Design implications**
1. **Treat causal chains as high-interactivity material.** Several interacting factors (site × weather × canopy × harvest × cellar × age) are exactly what cognitive load theory warns about. A novice's first exposure should be a full *worked chain*.
2. **Four-step fading ladder per cause item.** Mastery moves the learner along it.
   - Step 1: the worked chain.
   - Step 2: one link blanked ("petrol ← ? ← sun-exposed bunches + age").
   - Step 3: two links blanked.
   - Step 4: full Cause-to-glass prediction.
3. **Adapt to each player.** The partner (Level 3) should start at step 3–4 and the owner at step 1–2, set by a short placement pretest per topic, not a global level. Worked chains stay available on tap, never forced (avoids expertise reversal).
4. **Limit chain length by mode.** Keep Normal mode (Level 3 depth) to about 3–4 interacting links per question. Save longer, multi-factor chains for Hard (Diploma) mode.

## 5. Generation, pretesting, self-explanation, elaborative interrogation

**Key findings**
- **Generation effect (strong).** d ≈ 0.40 across 86 studies (Bertsch et al. 2007).
- **Errorful generation and pretesting (moderate).**
  - Failed retrieval attempts followed by the answer improve learning (Kornell, Hays & Bjork 2009; Richland, Kornell & Kao 2009).
  - Wrong guesses did not impair learning in Kang et al. (2011). That paper's DOI was checked; its details were not reviewed further.
  - Pan & Carpenter (2023) conclude that pretesting often helps, but by an amount that varies with procedure.
- **Self-explanation prompts (strong).** g = 0.55 across 69 effect sizes (Bisra et al. 2018). The foundational study is Chi et al. (1994).
- **Utility ratings (review).** Dunlosky et al. (2013) rated practice testing and distributed practice *high* utility, and self-explanation and elaborative interrogation *moderate*.
- **Problem solving before instruction (moderate).** "Productive failure" gives g = 0.36 for conceptual learning (Sinha & Kapur 2021), except for young learners and domain-general skills.

**Design implications**
1. **Predict before reveal, on the estate.** At every bottling, before the player sees the Tasting sheet for their own Wine, ask for 2–3 predictions: acidity level, alcohol band and one key aroma family. Mark them against the sheet. This turns the core farming loop into generation practice at no extra content cost.
2. **Pretest at each Stand.** Pose the Stand's questions *before* the player reads the Vintage card, then show the card as feedback.
3. **"Why?" prompts, marked by menu.** After roughly one in three correct answers, ask "Which cause produced this?" Offer a choice among nodes of the causal graph. Choosing nodes can be marked reliably; free-text self-explanation cannot.
4. **Counterfactual self-explanation, with the simulation as the oracle.** Ask "If this Block had been leaf-plucked less, what changes in the glass?" Answer by actually re-running the model with that one parameter changed and showing the difference in the Tasting sheet. This is a unique affordance of the deterministic engine. Only use it where outputs stay inside the calibration ranges.

## 6. Learning from simulations and serious games

**Key findings**
- **Serious games vs conventional instruction (moderate).** Wouters et al. (2013): learning d = 0.29, retention d = 0.36. Motivation d = 0.26 was *not* significant. Games did better when supplemented with other instruction and when they ran over multiple sessions.
- **Digital games meta-analysis (moderate).** Clark, Tanner-Smith & Killingsworth (2016): games vs non-game g = 0.33. Augmented vs standard game designs g = 0.34, so design features matter beyond the medium.
- **Instructional support inside games (moderate).** Wouters & van Oostendorp (2013): d = 0.34 overall; 0.62 for skills; 0.46 for support that helps learners select the relevant information.
- **Simulation games in training (moderate).** Sitzmann (2011): declarative knowledge +11%, procedural +14%, retention +9%. Effects were stronger when the game was active, freely re-accessible and used as a supplement. There was strong evidence of publication bias.
- **Learner control (moderate).** Vogel et al. (2006): games and simulations won when learners navigated themselves, not when the computer dictated the sequence.
- **Promising value-added features (moderate).** Mayer (2019) lists modality, personalisation, pretraining, coaching and self-explanation.
- **Narrative (weak).** Adams et al. (2012): narrative games under 2 hours did worse than a matched slideshow, and removing the narrative theme did not hurt learning. The authors note there is no evidence either way for longer play.
- **Confusion (moderate).** D'Mello et al. (2014): confusion that learners go on to resolve can benefit learning.

**Design implications**
1. **Position the game as a supplement, and expect modest gains.** Its role is to support the WSET course and books, and expected gains are around 0.3 SD. Map each cause item to a WSET Level 3 syllabus topic, paraphrased only, so the player can see the coverage.
2. **Add pretraining.** Before a player's first Vintage, run a short glossary pass covering the Tasting sheet terms.
3. **Coaching.** The mentor or advisor should explain a cause at the moment it happens in the estate ("The rain at véraison diluted the must").
4. **Keep the player in control of pace and navigation.** Automate only the scheduling of what is due.
5. **Keep narrative decorative.** Use it as flavour; don't spend build time on it expecting learning gains.
6. **Use confusion on purpose.** An occasional "paradox Wine" (a hot vintage that is high in acid because of an early harvest) followed by a resolving explanation.

## 7. Wine expertise: what can and cannot be trained without tasting

**Key findings**
- **Experts' advantage is largely knowledge and schemas (moderate).**
  - Hughson & Boakes (2001) conclude that expert performance "may rely heavily on explicit knowledge".
  - Hughson & Boakes (2002): experts recalled descriptions typical of a grape variety better than novices, but *not* random descriptions. This is a schema effect.
- **Perception improves, but not sensitivity (moderate).**
  - Parr, Heatherbell & White (2002): experts' olfactory thresholds matched novices'. Experts were better at *recognising* odours but not at *naming* them.
  - Explicit training with real odorants improved detection thresholds (Tempere et al. 2011, 2012).
  - Experts identify odours more accurately but more slowly (Tempere et al. 2016).
  - Untutored drinking experience improves recognition (Hughson & Boakes 2009).
  - These perceptual gains need real stimuli.
- **Language (moderate).**
  - Lawless (1984): experts matched descriptions to wines better, but only modestly: 2.6 vs 1.8 correct out of 6. Most terms were used by only one person.
  - Solomon (1990): expert–novice differences in matching descriptions written by others.
  - Croijmans & Majid (2016): wine experts described wines more consistently. Both expert groups used source-based terms ("vanilla") where novices used evaluative ones ("nice"). The advantage is modest and domain-specific, and "a matter not only of perceptual training, but specific linguistic training too".
- **Categorisation (moderate).** Ballester et al. (2008): experts sorted white wines by grape variety and agreed on typicality ratings. Novices sorted by surface cues such as sweetness and fruitiness.
- **Verbal overshadowing (weak–moderate, mixed).**
  - Melcher & Schooler (1996): describing a wine impaired later recognition only in *untrained regular drinkers*, whose perception was ahead of their vocabulary.
  - Hughson & Boakes (2009) found description *helped* both novices and intermediate drinkers.
- **Expectation biases (moderate).**
  - White wine dyed red drew red-wine descriptors (Morrot, Brochet & Dubourdieu 2001).
  - Wine descriptors are organised around wine-type prototypes (Brochet & Dubourdieu 2001).
- **Other findings (moderate).**
  - A wine course increased the vividness of wine imagery (Croijmans et al. 2020).
  - Judge reliability is low: only about 10% of competition judges repeated their score within a single medal band (Hodgson 2008).
  - Spence (2020) gives an overview.

**Design implications**
1. **What the game can train well, without tasting:**
   - the schema side: typicality prototypes per grape, region and vintage style;
   - cause→effect knowledge;
   - the WSET Systematic Approach to Tasting (SAT) structure and its fixed lexicon;
   - deductive "blind-tasting logic" from structure to origin;
   - quality reasoning using balance, length, intensity and complexity.
   The literature says this is a large part of what makes an expert.
2. **What it cannot train:** thresholds, odour recognition and flavour memory. State this plainly in the game.
3. **Marking free descriptors.** Mark against SAT-lexicon synonym sets, never by exact string match. Vocabulary is idiosyncratic even among experts (Lawless 1984).
4. **Taste-along mode.** The player buys a real bottle that matches a Stand's style, fills in Your Tasting sheet from the real glass, then compares it with the simulation's *style prototype* for that style and vintage. Show honest uncertainty bands for bottle variation.
5. **Comparison-flight shopping list.** Suggest real pairs that isolate one cause:
   - unoaked vs oaked Chardonnay;
   - young vs 8+-year-old Riesling, for TDN;
   - a cool vs a warm vintage from the same appellation;
   - Côte d'Or vs Napa Pinot Noir.
   Each pair links to the relevant cause items, so real tasting feeds the review scheduler: a real tasting logged counts as a review.
6. **Recognition tasks as well as naming.** Include "pick the 3 descriptors that fit" alongside free naming. Experts beat novices at recognition more than at naming.
7. **Hide identity until after the judgement.** Reveal label and region *after* Conclusions. Sometimes hide Appearance in Identify, to teach deducing from structure and to illustrate the expectation effect (Morrot 2001).
8. **Quality as bands, not points.** Mark quality in bands (for example, acceptable / good / very good / outstanding) and credit a justified adjacent band. Human judges themselves are unreliable at point scores (Hodgson 2008).

## 8. Motivation for long-term self-study

**Key findings**
- **Self-determination theory (strong theory, broad support).** Autonomy, competence and relatedness sustain intrinsic motivation (Ryan & Deci 2000).
- **Rewards (strong).** Deci, Koestner & Ryan (1999): expected rewards contingent on engagement, completion or performance undermined free-choice intrinsic motivation (d = −0.40, −0.36 and −0.28). Positive informational feedback *enhanced* it (d = +0.33).
- **Gamification works on average (moderate).**
  - Sailer & Homner (2020): cognitive g = 0.49 (stable in the rigorous studies), motivational 0.36, behavioural 0.25. Game fiction, and competition *combined with* collaboration, helped behavioural outcomes.
  - Hamari, Koivisto & Sarsa (2014): mostly positive but dependent on context and user.
- **Harms (moderate, single field study).** Hanus & Fox (2015), 16 weeks: a leaderboard plus badges *lowered* intrinsic motivation, satisfaction and empowerment. Lower motivation mediated lower final exam scores.
- **Streaks (moderate).** Silverman & Barasch (2023), seven studies: intact logged streaks increase continued engagement and broken ones reduce it. The drop is worse when the break is self-attributed and smaller when the streak can be *repaired*.
- **Habits (moderate).** Lally et al. (2010): automaticity took 18–254 days to plateau, and missing one day "did not materially affect" habit formation.
- **Goals and plans.**
  - Specific, challenging goals plus feedback raise performance (Locke & Latham 2002; strong).
  - If–then implementation intentions: d = 0.65 across 94 studies (Gollwitzer & Sheeran 2006; strong).

**Design implications**
1. **Replace the daily streak with a forgiving weekly rhythm.** Count "5 of 7 days" as the streak. Earn repair tokens by completing reviews. Word a missed day neutrally ("Your cellar waited for you"), never with a reset alarm.
2. **Make rewards informational, not transactional.** Medals and Taster rank should reflect *durable mastery*: Known items and delayed accuracy. They should never be paid per pour or per replay. This also blocks metric gaming.
3. **No public leaderboards.** The only social comparison should be the cooperative pair view (§9).
4. **Exam goal plus if–then plan.** At onboarding, set an exam goal and a weekly target, and write one if–then plan ("After dinner on weekdays, I pour the daily glass"). Show progress against the WSET syllabus map.
5. **Autonomy support.** Explain *why* the scheduler serves mixed, spaced items, and let the player choose among themed Stands. Keep the scheduling itself automatic, because learners' own choices trend toward massing (Kornell 2009).

## 9. Studying as a pair

**Key findings**
- **Collaborative memory (moderate).**
  - Groups recall less than the same people recalling separately and pooling their answers (collaborative inhibition; Weldon & Bellinger 1997).
  - Collaboration can spread errors (social contagion; Roediger, Meade & Bergman 2001).
  - It can improve later *individual* memory under the right conditions, for example through re-exposure and pruning of errors (Rajaram & Pereira-Pasarin 2010).
- **Peer discussion (moderate).** Smith et al. (2009): discussion improved performance on a new, *isomorphic* question answered individually, "even when none of the students in a discussion group originally knows the correct answer".
- **Teaching (moderate).**
  - Expecting to teach improved recall and organisation of knowledge (Nestojko et al. 2014).
  - Actually explaining produced more durable learning than only expecting to teach (Fiorella & Mayer 2013).
  - The ICAP framework ranks interactive > constructive > active > passive engagement (Chi & Wylie 2014; strong as a framework, moderate as evidence).

**Design implications**
1. **Pair Flight protocol.** Each partner answers *individually* with a confidence rating. Answers are revealed side by side, and the pair discusses only the disagreements. Each partner then gets an isomorphic follow-up Wine to answer individually. This follows Smith et al. and avoids both collaborative inhibition and error contagion.
2. **Explain-it cards.** One partner explains a cause chain aloud, and the game shows the true chain for checking. Rotate roles: the Level 3 partner benefits from teaching, and the owner benefits from explaining too.
3. **Cooperative goals over competition.** Use a joint weekly goal and a shared Cellar book. Any head-to-head play should be optional and weighted by rank (Sailer & Homner: competition works best combined with collaboration).
4. **Shared taste-along.** Taste one real bottle together, each fills in their own Tasting sheet, then compare both with the simulation's prototype.

---

## Top 12 learning-maximising changes, ranked by expected gain per build effort

1. **Cause-level spaced review queue.** Each review is a new Wine showing the same cause. Default ladder 1-3-7-16-35 days, then FSRS-lite at about 0.85–0.9 target retention. Feed the daily glass and the Stands from it. *Highest gain; medium effort; reuses the existing adaptive infrastructure.*
2. **Confidence 1–3 before every reveal.** Surprise cards for confident errors, full feedback for unsure correct answers, and scheduler weighting by confidence. *Low effort.*
3. **Elaborated feedback on every answer, including correct ones, plus an end-of-Flight recap of misses.** *Low effort; the causal chains already exist.*
4. **Mixed session composition** (about 60% due / 25% weak spot / 15% new) replacing pure weakest-skill pours. *Low effort.*
5. **Predict before reveal at every bottling on the estate.** *Low–medium effort; turns the core loop into generation practice.*
6. **Mastery-based ranks and medals.** Known = 3 correct on ≥3 separate days. No rewards for volume or replay. *Low effort; prevents gaming the metric.*
7. **Contrast Flights** that differ in one cause, blocked for the first 3–4 exemplars of a new category and then interleaved with confusable neighbours. *Medium effort.*
8. **Faded cause-chain items** (fill in the missing link), adapted per topic from a placement pretest. *Medium effort.*
9. **Exam-date mode** plus a syllabus coverage map. *Medium effort.*
10. **Forgiving weekly streak with repair, plus an if–then habit prompt.** *Low effort; mainly protects long-term retention of the player.*
11. **Pair Flight protocol and Explain-it cards.** *Medium effort.*
12. **Taste-along mode, comparison-flight shopping list, and "why?"/counterfactual prompts using the simulation as oracle.** *Medium–high effort. This is the only route to the perceptual side of expertise, and a unique use of the engine.*

## Pitfalls to avoid

- **Re-pouring the same Wine.** The player memorises the item, not the cause, and transfer collapses.
- **Items so hard that success is ≤50% with no feedback.** Retrieval then gives no benefit (Rowland 2014).
- **Drilling only the weakest skill.** It amounts to blocking and feels punishing.
- **Judging learning by in-session accuracy.** Measure it by delayed probes instead (Soderstrom & Bjork 2015; Kang 2014).
- **Letting fluency drive design.** Players will prefer blocked, massed practice and rate it as better (Kornell & Bjork 2008; Kornell 2009; Yan et al. 2016).
- **Public leaderboards, badges for volume, and expected rewards per pour.** Risk of undermining motivation (Hanus & Fox 2015; Deci et al. 1999).
- **Streaks with punitive resets.** Broken streaks reduce engagement, especially when there is no repair (Silverman & Barasch 2023).
- **Long multi-factor chains for novices, and forced worked examples for the Level 3 partner** (cognitive load; expertise reversal).
- **Investing in narrative polish expecting learning gains** (Adams et al. 2012). Put the effort into instructional support (Wouters & van Oostendorp 2013).
- **Exact-match marking of descriptors.** Use SAT-lexicon synonym sets.
- **Presenting quality point scores as ground truth.** Use bands; human judges are unreliable (Hodgson 2008).
- **Implying the game trains the nose.** It trains knowledge and reasoning. Real tasting must complement it (Parr et al. 2002; Tempere et al. 2012).
- **Showing the label before the judgement.** It causes expectation bias (Morrot et al. 2001).
- **Pairs answering jointly before answering individually.** It causes collaborative inhibition and error contagion.
- **Counterfactual "what-if" answers outside the model's calibration ranges.** They would teach false facts. Mark them UNVERIFIED or suppress them.

## References (all DOIs checked against Crossref)

- Adams, D. M., Mayer, R. E., MacNamara, A., Koenig, A., & Wainess, R. (2012). Narrative games for learning: Testing the discovery and narrative hypotheses. *J. Educational Psychology, 104*, 235–249. https://doi.org/10.1037/a0025595
- Adesope, O. O., Trevisan, D. A., & Sundararajan, N. (2017). Rethinking the use of tests: A meta-analysis of practice testing. *Review of Educational Research, 87*, 659–701. https://doi.org/10.3102/0034654316689306
- Ballester, J., Patris, B., Symoneaux, R., & Valentin, D. (2008). Conceptual vs. perceptual wine spaces: Does expertise matter? *Food Quality and Preference, 19*, 267–276. https://doi.org/10.1016/j.foodqual.2007.08.001
- Bertsch, S., Pesta, B. J., Wiscott, R., & McDaniel, M. A. (2007). The generation effect: A meta-analytic review. *Memory & Cognition, 35*, 201–210. https://doi.org/10.3758/BF03193441
- Bisra, K., Liu, Q., Nesbit, J. C., Salimi, F., & Winne, P. H. (2018). Inducing self-explanation: A meta-analysis. *Educational Psychology Review, 30*, 703–725. https://doi.org/10.1007/s10648-018-9434-x
- Brochet, F., & Dubourdieu, D. (2001). Wine descriptive language supports cognitive specificity of chemical senses. *Brain and Language, 77*, 187–196. https://doi.org/10.1006/brln.2000.2428
- Brunmair, M., & Richter, T. (2019). Similarity matters: A meta-analysis of interleaved learning and its moderators. *Psychological Bulletin, 145*, 1029–1052. https://doi.org/10.1037/bul0000209
- Butler, A. C., Karpicke, J. D., & Roediger, H. L. (2007). The effect of type and timing of feedback on learning from multiple-choice tests. *J. Experimental Psychology: Applied, 13*, 273–281. https://doi.org/10.1037/1076-898X.13.4.273
- Butler, A. C., Karpicke, J. D., & Roediger, H. L. (2008). Correcting a metacognitive error: Feedback increases retention of low-confidence correct responses. *JEP: LMC, 34*, 918–928. https://doi.org/10.1037/0278-7393.34.4.918
- Butler, A. C., & Roediger, H. L. (2008). Feedback enhances the positive effects and reduces the negative effects of multiple-choice testing. *Memory & Cognition, 36*, 604–616. https://doi.org/10.3758/MC.36.3.604
- Butterfield, B., & Metcalfe, J. (2001). Errors committed with high confidence are hypercorrected. *JEP: LMC, 27*, 1491–1494. https://doi.org/10.1037/0278-7393.27.6.1491
- Carvalho, P. F., & Goldstone, R. L. (2014). Putting category learning in order: Category structure and temporal arrangement affect the benefit of interleaved over blocked study. *Memory & Cognition, 42*, 481–495. https://doi.org/10.3758/s13421-013-0371-0
- Cepeda, N. J., Pashler, H., Vul, E., Wixted, J. T., & Rohrer, D. (2006). Distributed practice in verbal recall tasks: A review and quantitative synthesis. *Psychological Bulletin, 132*, 354–380. https://doi.org/10.1037/0033-2909.132.3.354
- Cepeda, N. J., Vul, E., Rohrer, D., Wixted, J. T., & Pashler, H. (2008). Spacing effects in learning: A temporal ridgeline of optimal retention. *Psychological Science, 19*, 1095–1102. https://doi.org/10.1111/j.1467-9280.2008.02209.x
- Chen, O., Kalyuga, S., & Sweller, J. (2015). The worked example effect, the generation effect, and element interactivity. *J. Educational Psychology, 107*, 689–704. https://doi.org/10.1037/edu0000018
- Chi, M. T. H., De Leeuw, N., Chiu, M.-H., & LaVancher, C. (1994). Eliciting self-explanations improves understanding. *Cognitive Science, 18*, 439–477. https://doi.org/10.1207/s15516709cog1803_3
- Chi, M. T. H., & Wylie, R. (2014). The ICAP framework: Linking cognitive engagement to active learning outcomes. *Educational Psychologist, 49*, 219–243. https://doi.org/10.1080/00461520.2014.965823
- Clark, D. B., Tanner-Smith, E. E., & Killingsworth, S. S. (2016). Digital games, design, and learning: A systematic review and meta-analysis. *Review of Educational Research, 86*, 79–122. https://doi.org/10.3102/0034654315582065
- Croijmans, I., & Majid, A. (2016). Not all flavor expertise is equal: The language of wine and coffee experts. *PLOS ONE, 11*, e0155845. https://doi.org/10.1371/journal.pone.0155845
- Croijmans, I., Speed, L. J., Arshamian, A., & Majid, A. (2020). Expertise shapes multimodal imagery for wine. *Cognitive Science, 44*, e12842. https://doi.org/10.1111/cogs.12842
- D'Mello, S., Lehman, B., Pekrun, R., & Graesser, A. (2014). Confusion can be beneficial for learning. *Learning and Instruction, 29*, 153–170. https://doi.org/10.1016/j.learninstruc.2012.05.003
- Deci, E. L., Koestner, R., & Ryan, R. M. (1999). A meta-analytic review of experiments examining the effects of extrinsic rewards on intrinsic motivation. *Psychological Bulletin, 125*, 627–668. https://doi.org/10.1037/0033-2909.125.6.627
- Dunlosky, J., & Rawson, K. A. (2012). Overconfidence produces underachievement: Inaccurate self evaluations undermine students' learning and retention. *Learning and Instruction, 22*, 271–280. https://doi.org/10.1016/j.learninstruc.2011.08.003
- Dunlosky, J., Rawson, K. A., Marsh, E. J., Nathan, M. J., & Willingham, D. T. (2013). Improving students' learning with effective learning techniques. *Psychological Science in the Public Interest, 14*, 4–58. https://doi.org/10.1177/1529100612453266
- Fiorella, L., & Mayer, R. E. (2013). The relative benefits of learning by teaching and teaching expectancy. *Contemporary Educational Psychology, 38*, 281–288. https://doi.org/10.1016/j.cedpsych.2013.06.001
- FSRS documentation, "ABC of FSRS" (open-spaced-repetition project wiki). https://github.com/open-spaced-repetition/awesome-fsrs/wiki/ABC-of-FSRS
- Gollwitzer, P. M., & Sheeran, P. (2006). Implementation intentions and goal achievement: A meta-analysis of effects and processes. *Advances in Experimental Social Psychology, 38*, 69–119. https://doi.org/10.1016/S0065-2601(06)38002-1
- Hamari, J., Koivisto, J., & Sarsa, H. (2014). Does gamification work? A literature review of empirical studies on gamification. *Proc. 47th HICSS*, 3025–3034. https://doi.org/10.1109/HICSS.2014.377
- Hanus, M. D., & Fox, J. (2015). Assessing the effects of gamification in the classroom: A longitudinal study on intrinsic motivation, social comparison, satisfaction, effort, and academic performance. *Computers & Education, 80*, 152–161. https://doi.org/10.1016/j.compedu.2014.08.019
- Hattie, J., & Timperley, H. (2007). The power of feedback. *Review of Educational Research, 77*, 81–112. https://doi.org/10.3102/003465430298487
- Hodgson, R. T. (2008). An examination of judge reliability at a major U.S. wine competition. *Journal of Wine Economics, 3*, 105–113. https://doi.org/10.1017/S1931436100001152
- Hughson, A. L., & Boakes, R. A. (2001). Perceptual and cognitive aspects of wine expertise. *Australian Journal of Psychology, 53*, 103–108. https://doi.org/10.1080/00049530108255130
- Hughson, A. L., & Boakes, R. A. (2002). The knowing nose: The role of knowledge in wine expertise. *Food Quality and Preference, 13*, 463–472. https://doi.org/10.1016/S0950-3293(02)00051-4
- Hughson, A. L., & Boakes, R. A. (2009). Passive perceptual learning in relation to wine: Short-term recognition and verbal description. *Quarterly Journal of Experimental Psychology, 62*, 1–8. https://doi.org/10.1080/17470210802214890
- Kalyuga, S., Ayres, P., Chandler, P., & Sweller, J. (2003). The expertise reversal effect. *Educational Psychologist, 38*, 23–31. https://doi.org/10.1207/S15326985EP3801_4
- Kang, S. H. K., Lindsey, R. V., Mozer, M. C., & Pashler, H. (2014). Retrieval practice over the long term: Should spacing be expanding or equal-interval? *Psychonomic Bulletin & Review, 21*, 1544–1550. https://doi.org/10.3758/s13423-014-0636-z
- Kang, S. H. K., Pashler, H., Cepeda, N. J., Rohrer, D., Carpenter, S. K., & Mozer, M. C. (2011). Does incorrect guessing impair fact learning? *J. Educational Psychology, 103*, 48–59. https://doi.org/10.1037/a0021977
- Karpicke, J. D., & Roediger, H. L. (2007). Expanding retrieval practice promotes short-term retention, but equally spaced retrieval enhances long-term retention. *JEP: LMC, 33*, 704–719. https://doi.org/10.1037/0278-7393.33.4.704
- Kirschner, P. A., Sweller, J., & Clark, R. E. (2006). Why minimal guidance during instruction does not work. *Educational Psychologist, 41*, 75–86. https://doi.org/10.1207/s15326985ep4102_1
- Kornell, N. (2009). Optimising learning using flashcards: Spacing is more effective than cramming. *Applied Cognitive Psychology, 23*, 1297–1317. https://doi.org/10.1002/acp.1537
- Kornell, N., & Bjork, R. A. (2008). Learning concepts and categories: Is spacing the "enemy of induction"? *Psychological Science, 19*, 585–592. https://doi.org/10.1111/j.1467-9280.2008.02127.x
- Kornell, N., Hays, M. J., & Bjork, R. A. (2009). Unsuccessful retrieval attempts enhance subsequent learning. *JEP: LMC, 35*, 989–998. https://doi.org/10.1037/a0015729
- Lally, P., van Jaarsveld, C. H. M., Potts, H. W. W., & Wardle, J. (2010). How are habits formed: Modelling habit formation in the real world. *European Journal of Social Psychology, 40*, 998–1009. https://doi.org/10.1002/ejsp.674
- Latimier, A., Peyre, H., & Ramus, F. (2021). A meta-analytic review of the benefit of spacing out retrieval practice episodes on retention. *Educational Psychology Review, 33*, 959–987. https://doi.org/10.1007/s10648-020-09572-8
- Lawless, H. T. (1984). Flavor description of white wine by "expert" and nonexpert wine consumers. *Journal of Food Science, 49*, 120–123. https://doi.org/10.1111/j.1365-2621.1984.tb13686.x
- Lindsey, R. V., Shroyer, J. D., Pashler, H., & Mozer, M. C. (2014). Improving students' long-term knowledge retention through personalized review. *Psychological Science, 25*, 639–647. https://doi.org/10.1177/0956797613504302
- Locke, E. A., & Latham, G. P. (2002). Building a practically useful theory of goal setting and task motivation. *American Psychologist, 57*, 705–717. https://doi.org/10.1037/0003-066X.57.9.705
- Mayer, R. E. (2019). Computer games in education. *Annual Review of Psychology, 70*, 531–549. https://doi.org/10.1146/annurev-psych-010418-102744
- Melcher, J. M., & Schooler, J. W. (1996). The misremembrance of wines past: Verbal and perceptual expertise differentially mediate verbal overshadowing of taste memory. *Journal of Memory and Language, 35*, 231–245. https://doi.org/10.1006/jmla.1996.0013
- Metcalfe, J. (2017). Learning from errors. *Annual Review of Psychology, 68*, 465–489. https://doi.org/10.1146/annurev-psych-010416-044022
- Metcalfe, J., Kornell, N., & Finn, B. (2009). Delayed versus immediate feedback in children's and adults' vocabulary learning. *Memory & Cognition, 37*, 1077–1087. https://doi.org/10.3758/MC.37.8.1077
- Morrot, G., Brochet, F., & Dubourdieu, D. (2001). The color of odors. *Brain and Language, 79*, 309–320. https://doi.org/10.1006/brln.2001.2493
- Nestojko, J. F., Bui, D. C., Kornell, N., & Bjork, E. L. (2014). Expecting to teach enhances learning and organization of knowledge in free recall of text passages. *Memory & Cognition, 42*, 1038–1048. https://doi.org/10.3758/s13421-014-0416-z
- Pan, S. C., & Carpenter, S. K. (2023). Prequestioning and pretesting effects: A review of empirical research, theoretical perspectives, and implications for educational practice. *Educational Psychology Review, 35*. https://doi.org/10.1007/s10648-023-09814-5
- Pan, S. C., & Rickard, T. C. (2018). Transfer of test-enhanced learning: Meta-analytic review and synthesis. *Psychological Bulletin, 144*, 710–756. https://doi.org/10.1037/bul0000151
- Parr, W. V., Heatherbell, D., & White, K. G. (2002). Demystifying wine expertise: Olfactory threshold, perceptual skill and semantic memory in expert and novice wine judges. *Chemical Senses, 27*, 747–755. https://doi.org/10.1093/chemse/27.8.747
- Rajaram, S., & Pereira-Pasarin, L. P. (2010). Collaborative memory: Cognitive research and theory. *Perspectives on Psychological Science, 5*, 649–663. https://doi.org/10.1177/1745691610388763
- Raviv, L., Lupyan, G., & Green, S. C. (2022). How variability shapes learning and generalization. *Trends in Cognitive Sciences, 26*, 462–483. https://doi.org/10.1016/j.tics.2022.03.007
- Rawson, K. A., & Dunlosky, J. (2011). Optimizing schedules of retrieval practice for durable and efficient learning: How much is enough? *JEP: General, 140*, 283–302. https://doi.org/10.1037/a0023956
- Renkl, A., & Atkinson, R. K. (2003). Structuring the transition from example study to problem solving in cognitive skill acquisition: A cognitive load perspective. *Educational Psychologist, 38*, 15–22. https://doi.org/10.1207/S15326985EP3801_3
- Rhodes, M. G., & Tauber, S. K. (2011). The influence of delaying judgments of learning on metacognitive accuracy: A meta-analytic review. *Psychological Bulletin, 137*, 131–148. https://doi.org/10.1037/a0021705
- Richland, L. E., Kornell, N., & Kao, L. S. (2009). The pretesting effect: Do unsuccessful retrieval attempts enhance learning? *JEP: Applied, 15*, 243–257. https://doi.org/10.1037/a0016496
- Roediger, H. L., & Karpicke, J. D. (2006). Test-enhanced learning. *Psychological Science, 17*, 249–255. https://doi.org/10.1111/j.1467-9280.2006.01693.x
- Roediger, H. L., Meade, M. L., & Bergman, E. T. (2001). Social contagion of memory. *Psychonomic Bulletin & Review, 8*, 365–371. https://doi.org/10.3758/BF03196174
- Rowland, C. A. (2014). The effect of testing versus restudy on retention: A meta-analytic review of the testing effect. *Psychological Bulletin, 140*, 1432–1463. https://doi.org/10.1037/a0037559
- Ryan, R. M., & Deci, E. L. (2000). Self-determination theory and the facilitation of intrinsic motivation, social development, and well-being. *American Psychologist, 55*, 68–78. https://doi.org/10.1037/0003-066X.55.1.68
- Sailer, M., & Homner, L. (2020). The gamification of learning: A meta-analysis. *Educational Psychology Review, 32*, 77–112. https://doi.org/10.1007/s10648-019-09498-w
- Silverman, J., & Barasch, A. (2023). On or off track: How (broken) streaks affect consumer decisions. *Journal of Consumer Research, 49*, 1095–1117. https://doi.org/10.1093/jcr/ucac029
- Sinha, T., & Kapur, M. (2021). When problem solving followed by instruction works: Evidence for productive failure. *Review of Educational Research, 91*, 761–798. https://doi.org/10.3102/00346543211019105
- Sitzmann, T. (2011). A meta-analytic examination of the instructional effectiveness of computer-based simulation games. *Personnel Psychology, 64*, 489–528. https://doi.org/10.1111/j.1744-6570.2011.01190.x
- Smith, M. K., Wood, W. B., Adams, W. K., Wieman, C., Knight, J. K., Guild, N., & Su, T. T. (2009). Why peer discussion improves student performance on in-class concept questions. *Science, 323*, 122–124. https://doi.org/10.1126/science.1165919
- Soderstrom, N. C., & Bjork, R. A. (2015). Learning versus performance: An integrative review. *Perspectives on Psychological Science, 10*, 176–199. https://doi.org/10.1177/1745691615569000
- Solomon, G. E. A. (1990). Psychology of novice and expert wine talk. *American Journal of Psychology, 103*, 495–517. https://doi.org/10.2307/1423321
- Spence, C. (2020). Wine psychology: Basic & applied. *Cognitive Research: Principles and Implications, 5*. https://doi.org/10.1186/s41235-020-00225-6
- Sweller, J., van Merriënboer, J. J. G., & Paas, F. (2019). Cognitive architecture and instructional design: 20 years later. *Educational Psychology Review, 31*, 261–292. https://doi.org/10.1007/s10648-019-09465-5
- Tabibian, B., Upadhyay, U., De, A., Zarezade, A., Schölkopf, B., & Gomez-Rodriguez, M. (2019). Enhancing human learning via spaced repetition optimization. *PNAS, 116*, 3988–3993. https://doi.org/10.1073/pnas.1815156116
- Tempere, S., Cuzange, E., Malak, J., Bougeant, J. C., de Revel, G., & Sicard, G. (2011). The training level of experts influences their detection thresholds for key wine compounds. *Chemosensory Perception, 4*, 99–115. https://doi.org/10.1007/s12078-011-9090-8
- Tempere, S., Cuzange, E., Bougeant, J. C., de Revel, G., & Sicard, G. (2012). Explicit sensory training improves the olfactory sensitivity of wine experts. *Chemosensory Perception, 5*, 205–213. https://doi.org/10.1007/s12078-012-9120-1
- Tempere, S., Hamtat, M. L., de Revel, G., & Sicard, G. (2016). Comparison of the ability of wine experts and novices to identify odorant signals. *Australian Journal of Grape and Wine Research, 22*, 190–196. https://doi.org/10.1111/ajgw.12192
- Van der Kleij, F. M., Feskens, R. C. W., & Eggen, T. J. H. M. (2015). Effects of feedback in a computer-based learning environment on students' learning outcomes: A meta-analysis. *Review of Educational Research, 85*, 475–511. https://doi.org/10.3102/0034654314564881
- Vogel, J. J., Vogel, D. S., Cannon-Bowers, J., Bowers, C. A., Muse, K., & Wright, M. (2006). Computer gaming and interactive simulations for learning: A meta-analysis. *J. Educational Computing Research, 34*, 229–243. https://doi.org/10.2190/FLHV-K4WA-WPVQ-H0YM
- Weldon, M. S., & Bellinger, K. D. (1997). Collective memory: Collaborative and individual processes in remembering. *JEP: LMC, 23*, 1160–1175. https://doi.org/10.1037/0278-7393.23.5.1160
- Wisniewski, B., Zierer, K., & Hattie, J. (2020). The power of feedback revisited: A meta-analysis of educational feedback research. *Frontiers in Psychology, 10*, 3087. https://doi.org/10.3389/fpsyg.2019.03087
- Wouters, P., van Nimwegen, C., van Oostendorp, H., & van der Spek, E. D. (2013). A meta-analysis of the cognitive and motivational effects of serious games. *J. Educational Psychology, 105*, 249–265. https://doi.org/10.1037/a0031311
- Wouters, P., & van Oostendorp, H. (2013). A meta-analytic review of the role of instructional support in game-based learning. *Computers & Education, 60*, 412–425. https://doi.org/10.1016/j.compedu.2012.07.018
- WSET. Level 3 Award in Wines: Systematic Approach to Tasting Wine (SAT), June 2016 edition (PDF). https://www.wsetglobal.com/media/13017/wset_l3wines_sat_en_jun-2016.pdf
- Yan, V. X., Bjork, E. L., & Bjork, R. A. (2016). On the difficulty of mending metacognitive illusions: A priori theories, fluency effects, and misattributions of the interleaving benefit. *JEP: General, 145*, 918–933. https://doi.org/10.1037/xge0000177
- Ye, J., Su, J., & Cao, Y. (2022). A stochastic shortest path algorithm for optimizing spaced repetition scheduling. *Proc. 28th ACM SIGKDD*, 4381–4390. https://doi.org/10.1145/3534678.3539081

**Notes on uncertainty**
- I deliberately left out confidence-based marking (Gardner-Medwin) because I did not verify a source for it. The confidence and calibration recommendations rest on Butler et al. (2008), Butterfield & Metcalfe (2001), Dunlosky & Rawson (2012) and Rhodes & Tauber (2011).
- Lally et al.'s commonly quoted median of about 66 days is not in the abstract I checked; only the 18–254 day range is.
- For Wouters et al. (2013), I report only the moderators I could confirm: supplementary instruction and multiple sessions.
- The specific numbers in the design implications are design choices informed by the evidence, not values taken from studies. This includes the 1-3-7-16-35 ladder, the 60/25/15 session mix and the 0.85–0.9 target retention. They should be treated as tunable defaults.

**Relevant existing files** (read only, not modified):
- /mnt/c/Users/Aleksander/src/repos/winegamesimulator/docs/science/tasting-practice.md (current adaptive rule: "lowest average of the last 20 answers")
- /mnt/c/Users/Aleksander/src/repos/winegamesimulator/CONTEXT.md (glossary terms used above: Wine Fair, Stand, Flight, Vintage card, Taster rank, Your Tasting sheet)