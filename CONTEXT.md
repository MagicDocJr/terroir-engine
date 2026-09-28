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

### Play modes

The engine always simulates at full depth. The mode only changes what the player is shown and how certain it is.

**Normal mode**:
Shows concepts at WSET Level 3 depth. Lab values are exact and free, and the advisor's explanations are always visible.
_Avoid_: Easy mode, study mode

**Hard mode**:
Shows Diploma-level detail. Lab analyses cost money and come with sampling error. (Post-MVP.)
_Avoid_: Expert mode, exam mode
