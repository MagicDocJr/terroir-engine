# Terroir Engine

A realistic vineyard-founding and winemaking simulator. The player buys land, plants vines, runs the vineyard through each season and makes wine at WSET Diploma depth. Outcomes follow from real viticultural and oenological science.

## Language

### Ownership and land

**Estate**:
The player's wine business. It owns one or more Plots and makes wine from them.
_Avoid_: Company, winery, farm

**Region**:
A real-world wine region with its own macroclimate, typical soils, hazards and legal rules (e.g. Mosel, Napa Valley).
_Avoid_: Country, location, area

**Plot**:
A specific piece of land inside a Region that the Estate can buy. It is divided into 3–6 Blocks.
_Avoid_: Parcel, site, lot, field

**Block**:
A zone within a Plot with its own soil profile and microclimate. It is the unit that is planted, managed and harvested.
_Avoid_: Soil, zone, section, row

**Classification**:
A Plot's legal standing within its Region's appellation system (e.g. Bourgogne AOC, Village, Premier Cru). It caps the Legal category of wine made from that Plot.
_Avoid_: Rank, tier, cru level

**Winery**:
The Estate's cellar building and equipment, where Lots are fermented, aged, blended and bottled.
_Avoid_: Cellar, facility

### Plants

**Variety**:
A grape cultivar the player can plant (e.g. Riesling). Any Variety can be planted on any Plot; a poor match shows up as poor results, never as a blocked choice.
_Avoid_: Grape, cultivar, type

**Planting**:
The one-off set of choices made when vines go into bare land: Variety, clone, rootstock, density, row orientation and training system.
_Avoid_: Setup, founding

**Establishment**:
The young-vine years between Planting and the first full crop (about 3 years). The game fast-forwards through them, and they give reduced yield and concentration.
_Avoid_: Growing-in, waiting period

### Time and weather

**Vintage**:
One growing season and the wine made from it, named by harvest year.
_Avoid_: Season, year, round

**Non-vintage**:
A Wine blended from more than one Vintage, with too little of any one year to put a year on the label (EU: under 85 %; a Napa AVA wine: under 95 %).
_Avoid_: NV blend, multi-year wine

**Timeline**:
The continuous calendar a game runs on. It starts in the Planting year the player chooses (1990–2022) and continues year after year.
_Avoid_: Campaign, career

**Historical weather**:
Daily weather for a real past year in a Region, taken from archived observations. It is used for every year of the Timeline the archive covers.
_Avoid_: Real weather, recorded data

**Synthetic weather**:
Daily weather generated from a seed, for Timeline years after the archive ends. It is built from recent climate plus the warming trend, and the same seed always gives the same weather.
_Avoid_: Random weather, procedural weather

**Task**:
A dated job from your staff, such as winter pruning, leaf removal, green harvest or working the cap of a red Lot. You can do it yourself on a demonstration vine (or at the tank) in 3D, decide it on the dashboard, or let the crew do it to the staff member's plan. If nobody decides by the due date, the plan applies.
_Avoid_: Quest, job, chore

**Alert**:
Something happening in the simulation that stops time and needs the player's attention (e.g. a frost warning, a disease-risk threshold being crossed).
_Avoid_: Event, notification, interrupt

### Management

**Programme**:
A standing instruction for one area of work (e.g. spraying, canopy, labour), set at a Low, Medium or High tier. Staff carry it out automatically each day.
_Avoid_: Policy, plan, strategy, setting

**Vineyard manager**:
The staff member who runs the vineyard Programmes and reports on the vines.
_Avoid_: Viticulturist, farm manager

**Cellar master**:
The staff member who carries out the Winery decisions and reports on the Lots.
_Avoid_: Winemaker, oenologist

**Staff level**:
Junior, Experienced or Senior. It sets a staff member's salary, how well they carry out the work, and how much they explain. Advice at every level is correct; higher levels give more detail, see further ahead and suggest better ideas.
_Avoid_: Rank, grade, skill

**Mentor**:
An expert who is about to retire and guides the player through the start of the game, including the first Vintage and its ageing, before leaving.
_Avoid_: Tutor, guide, tutorial

**Bud fruitfulness**:
How many bunches each shoot carries. It is set inside the buds around flowering of the previous Vintage, so warm, bright flowering weather means more bunches next year. Growers estimate it in winter by cutting buds open (bud dissection).
_Avoid_: Bud fertility, bud potential

**Vine reserves**:
The starch a vine stores in its roots and trunk after the harvest. It feeds the next spring's growth. A big crop, a late harvest or early leaf loss runs it down.
_Avoid_: Vine energy, vine health

**Vine age**:
Counted in leaves: the planting year is the 1st leaf, and the 4th leaf gives the first near-full crop. Older vines root deeper, but age alone does not make better wine: well-kept old and young vines in the same vineyard give the same yield and grape composition.
_Avoid_: Old-vine quality, vieilles vignes bonus

### Wine

**Lot**:
The fruit harvested from one Block in one Vintage, fermented and aged as its own batch.
_Avoid_: Batch, tank, parcel

**Wine**:
A finished, bottled product made from one Lot or a blend of Lots. An Estate makes up to about three Wines per Vintage.
_Avoid_: Cuvée, product, bottle

**Legal category**:
The designation a Wine qualifies for under its Region's rules (e.g. Mosel Kabinett, Vin de France). It is the main driver of price.
_Avoid_: Label, appellation, quality level

**Tasting sheet**:
The structured assessment of a Wine (appearance, nose, palate, conclusions). Every descriptor on it is linked to the decision or condition that caused it.
_Avoid_: Tasting note, review, evaluation

### Tasting practice

**Tasting practice**:
The study mode where the simulation pours Wines from real vintages for the player to assess, with or without an Estate.
_Avoid_: Quiz mode, training, tasting game

**Wine Fair**:
The part of Tasting practice with themed Stands, each pouring a Flight.
_Avoid_: Tasting event, expo

**Stand**:
One theme at the Wine Fair, hosted by an invented producer (e.g. "The 2016 frost").
_Avoid_: Booth, level, challenge

**Flight**:
The Wines a Stand pours side by side.
_Avoid_: Set, line-up, round

**Your Tasting sheet**:
The player's own assessment in the Tasting sheet's structure, marked against the Wine's Tasting sheet.
_Avoid_: Tasting note, guess, answer sheet

**Vintage card**:
A card in the Cellar book for a vintage tasted at a Stand: its weather in numbers and, where sourced, what really happened.
_Avoid_: Badge, collectible

**Taster rank**:
The player's progression in Tasting practice (Novice taster to Fair judge), set by the share of Causes the player Knows.
_Avoid_: Level, score

### Learning

**Cause**:
One cause chain from a choice, a site, a vintage or a fault to what it does in the glass (e.g. cool fermentation → more fruity esters → pear on the nose). Tasting sheet lines are tagged with the Causes they show.
_Avoid_: Fact, flashcard, lesson

**Review queue**:
The Causes the player has met, each due again after a spaced gap that grows with every right answer.
_Avoid_: Deck, backlog, revision list

**Known**:
A Cause answered right on three separate days; two misses in a row return it to learning.
_Avoid_: Mastered, learned, completed

**Confidence**:
How sure the player is of an answer (guess, think so, sure), given before the reveal.
_Avoid_: Certainty, bet

**Weekly rhythm**:
The goal of five study days in each Monday-to-Sunday week; extra reviews repair a missed day.
_Avoid_: Streak, daily goal

**Exam date**:
An optional date the review queue works towards: gaps shrink so every Cause comes back before it.
_Avoid_: Deadline, test day

**Learn card**:
A short card that opens beside a choice and explains what that choice does in the wine, applied to the player's own Block or Lot.
_Avoid_: Tooltip, help page, tutorial

**Vintage in review**:
The top of a Vintage report: the season replayed and cause cards linking the year's moments and choices to the Tasting-sheet lines they shaped.
_Avoid_: Recap, summary, verdict

**Famous vintage**:
A scenario that replays one real, well-known year on an established Estate, with bronze, silver and gold goals judged on the Wine and a cited debrief of what really happened.
_Avoid_: Level, mission, challenge mode

### Play modes

The engine always simulates at full depth. The mode only changes what the player is shown and how certain it is.

**Normal mode**:
Shows concepts at WSET Level 3 depth. Lab values are exact and free, and the advisor's explanations are always visible.
_Avoid_: Easy mode, study mode

**Hard mode**:
Shows Diploma-level detail. Lab analyses cost money and come with sampling error. (Post-MVP.)
_Avoid_: Expert mode, exam mode
