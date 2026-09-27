# Design review after the first playtest (27 Sep 2026)

After the first playtest, the owner asked me to answer the "questions for expert designers" myself, from the game-design literature, and then act on the answers. Each section below gives the question, what the literature says, the decision, and what was built.

Sources are cited from memory, so check the exact wording before quoting them. They are **Sid Meier**, "a game is a series of interesting decisions" (GDC 2012); **Jesse Schell**, *The Art of Game Design: A Book of Lenses* (2008), especially the interest curve and flow lenses; **Mihaly Csikszentmihalyi**, *Flow* (1990); **Raph Koster**, *A Theory of Fun* (2004); **Celia Hodent**, *The Gamer's Brain* (2017), on onboarding, cognitive load and learning by doing; **Tynan Sylvester**, *Designing Games* (2013), on legibility and feedback loops; **Daniel Cook**, "The Chemistry of Game Design" (2007), on skill atoms and loops; and **Kathy Sierra**, *Badass: Making Users Awesome* (2015). I also looked at genre precedent: Football Manager's inbox and staff advice, Two Point Hospital's objectives, and RimWorld's alerts.

## 1. Pacing: where does the Vintage sag?

**Literature.** Schell's *interest curve*: an experience needs rising peaks, not a flat line. The quiet stretches between peaks should be short, and each peak should be stronger than the last, ending on the strongest. Koster adds that boredom sets in once there is nothing new to learn.

**Diagnosis.** The Vintage has natural peaks: pruning, budburst and frost, flowering, véraison, harvest, the ferment, the bottling and the reveal. It sags in two places. Mid-winter to budburst has little to do. Months 2–10 of ageing have almost nothing to do.

**Decision.**
- Continue now jumps up to **120 days** once everything is in the cellar, still stopping at every Alert. In the vineyard season it stays at 60 days.
- The Tasting sheet reveal at bottling is the climax. The Mentor's end-of-game letter and summary already frame it.
- Later (backlog): a barrel-sample tasting note during ageing, so the long cellar stretch gets a small beat of its own.

## 2. Decision density: too many, too few, or badly spread?

**Literature.** Meier: every decision should be *interesting*, a real trade-off with no obvious answer. Hodent: working memory holds about four items, so dumping twelve options at once overloads it. Sierra: expose the few controls that matter most, and keep the rest behind "more".

**Diagnosis.** In the vineyard the count is right (about ten decisions spread over the season). In the cellar there are about 12 choices per Lot, and all of them arrive at harvest, the busiest moment. Five Lots means about 60 dropdowns in one week.

**Decision.** Each Lot shows **3–4 key choices**: for whites, pressing, temperature and sweetness plus the vessel; for reds, destemming, cap management and temperature plus the vessel. The other choices sit under **More choices** and keep the Cellar master's suggestions. A clear line says the defaults are the Cellar master's plan and are fine to accept. The full depth is still there for players who want it.

## 3. Legibility: is the decision → outcome loop readable, or too delayed?

**Literature.** Sylvester: players learn only from feedback they can connect to their actions, and long delays break that link unless the game draws the connection for them. Cook: every skill atom needs its feedback. Hodent: feedback should be immediate or, when it can't be, explicitly linked back.

**Diagnosis.** The Tasting sheet links every descriptor to its cause, which is strong. But a harvest date only pays off eight months later.

**Decision.** Give an **immediate proxy** at the moment of the decision. When a Lot arrives, the Mentor says in plain words what the fruit will probably become: the likely legal category from the must weight, the expected alcohol, and the acidity style. The bottling sheet then closes the loop.

## 4. Information design: is the Inbox the right hub?

**Literature.** Football Manager shows that an inbox as a hub works for simulation games. Its known failure is inbox fatigue (the FM community's standing complaint), and RimWorld's lesson is the same: alerts must be few and actionable.

**Decision.**
- Keep the Inbox as the hub.
- Messages now open **oldest unread first**, and there are **Mark all read** and **Next unread** buttons.
- Every alert carries an action button, and a screen reached from a message shows **Back to Inbox**.
- Staff have **faces and names**. Faces are processed faster than role labels (Hodent on recognition over recall).
- Repeated heatwave warnings are already limited to one per 10 days.

## 5. Failure states: fair and telegraphed?

**Literature.** A failure feels fair when the player could see it coming and could recover (Schell's lens of challenge; Sid Meier's "the player should be the one having fun").

**Current state.**
- **Stuck ferment:** there is an Alert and two recoveries.
- **Brett:** the SO₂ default now prevents it.
- **Declassification:** the yield limit gets an Alert at véraison.
- **Debt:** the Plot comparison warns about it, but nothing tells you once it has happened.

**Decision.** The first time cash goes below zero, the Mentor sends a one-off warning explaining what caused the debt. Full loans stay on the backlog.

## 6. Replayability before multi-vintage play

**Literature.** Replay value comes from variety that changes decisions, not only numbers (Koster: new patterns to learn).

**Decision.** A different planting year means a genuinely different real vintage (1990–2025, synthetic after that). Each Region and Plot changes the problem. For the MVP that is enough. **Famous-vintage challenges** (for example the 2021 Burgundy frost, or the hot 2003) are on the backlog as the cheapest way to add authored replay.

## 7. Do staff levels make hiring feel worth it?

**Literature.** An upgrade has to be *felt* in play, not just shown in a table (Sierra: show the player they are becoming better).

**Decision.**
- Staff differences already show in play: the forecast horizon, whether numbers are included, and a recommendation from the Senior.
- Each level is now a named person with a face, so hiring someone feels like a change.
- Hiring still happens from the Estate screen.
- Later: a Senior's occasional "clever idea" message (spec §5.4) as a stronger reward.

## 8. Onboarding (the owner: "as a new gamer you need more help")

**Literature.** Hodent: people learn by doing, in context and just in time, one concept at a time, with the next step always visible. Nintendo's World 1-1 teaches without text by making the first safe action obvious. Two Point Hospital and Anno teach through objectives. Sierra: get the player to a first small win fast.

**Decision.** Three layers, all tied to the Mentor storyline, with no separate tutorial mode (spec §5.5):
1. **The Mentor's plan.** A persistent checklist of the first Vintage's milestones: read the welcome, look at your Blocks, settle the pruning, check the Programmes, let the season start, watch the weather, open Ripeness after véraison, harvest a Block, set up a Lot, bottle a wine, read its Tasting sheet. Each step has a **Go** button and ticks itself off from what you actually do. The next step is always visible in the top bar ("Next: …"). It can be hidden.
2. **First-visit screen intros.** The first time you open a screen, a short card explains what the screen is for and the one thing to do there. It is dismissible and never shown again.
3. **Contextual action buttons in messages** (already there), plus Back to Inbox.

## Backlog additions from this review

- **Staff-assigned tasks you can do yourself in 3D.** The Vineyard manager says "go out and prune Block B", and you prune in the 3D vineyard or delegate it. The same for leaf pulling, green harvest and punching down. This extends "Hands-on tasks in 3D".
- **3D time-lapse with a speed control.** Watching the days pass in 3D is where 1×/2×/4× makes sense. It was removed from the dashboard.
- **Famous-vintage challenges.**
- **Barrel-sample notes during ageing.**
- **A Senior's "clever idea" messages.**
