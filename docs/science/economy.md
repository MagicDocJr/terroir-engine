# Economy (minimal, spec §5.3)

**Goal:** realistic *ratios*, not accounting precision. Money is the scarce resource that makes every decision a trade-off (spec Q9).

**Game simplifications (labelled in-game):**
- **Prices:** all prices are EUR at **2026 levels** in every Timeline year.
- **Currency conversion:** US$ figures are converted at **€0.92 per US$** (`UNVERIFIED`; a fixed game rate).
- **Winery:** a basic Winery comes with the Estate (spec §5.3), so there's no building cost.
- **Sales:** Wine sells at the end of the MVP at an **average realised ex-cellar price** (a mix of direct and trade sales); no market simulation.

Anything below without a source is a **design value**, marked `UNVERIFIED`, chosen to sit inside plausible real-world ranges.

---

## 1. Starting capital

**€600,000** (design value; also in `data/plots.json`). It covers the land, Planting, three Establishment years at ~60 % of full running cost, and the first vintage's running and bottling costs. Checked against every Plot (method in §9):

| Region | Affordable with €600k | Not affordable (long-term goal) |
|---|---|---|
| Mosel | all four, even the steep terraces (land is cheap; **labour** is the cost) | — |
| Côte d'Or | flats (Bourgogne), Hautes-Côtes, Village (tight, ~€510k) | **Premier Cru** (~€1.3 M) |
| Napa | valley floor, Carneros (tight, ~€520k), mountain | **Rutherford bench** (~€680k) |

This matches spec §4.2: a cheap or middle Plot is affordable; the great Plots are aspirational.

---

## 2. Land (bare, plantable)

Per-Plot prices are listed in `regions-and-plots.md` and `data/plots.json`. Anchors:

| Anchor | Value | Source |
|---|---|---|
| Côte d'Or average vineyard price, 2024 | €1,022,600/ha (+11 % on 2023) | [SAFER-2024 via REUSSIR] |
| Côte de Beaune village AOC, whites, 2024 | ≈ €1,050,000/ha | [SAFER-2024 via REUSSIR] |
| Burgundy Premier Cru whites, 2024 | > €2,500,000/ha | [SAFER-2024 via REUSSIR] |
| Grand Cru | too few sales to quote a price per ha | [SAFER-2024 via REUSSIR] |
| Napa, plantable prime land (2020) | US$200–250k per acre (≈ €455–570k/ha) | [UCD-NAPA-2020] |
| Napa, plantable secondary land (2020) | US$50–240k per acre | [UCD-NAPA-2020] |
| Napa, established prime vineyards (2020) | US$300–400k per acre | [UCD-NAPA-2020] |
| Mosel land | `UNVERIFIED` €20–80k/ha by site class | — |

Design choices:
- The Premier Cru Plot is priced at €2.5 M/ha from the white-wine figure. `UNVERIFIED` for red Premier Cru.
- The Village Plot is priced at €900k/ha, a little below the white-wine average, because it's a mixed red/white commune.

---

## 3. Planting (one-off, per ha)

| System | Cost per ha | Basis |
|---|---|---|
| **Napa, VSP cordon, drip irrigation** (1,555 vines per acre ≈ 3,840 vines/ha; vines US$6.50 each) | **€75,000** for bare land | UC Davis 2020: the first-year operating cost is US$34,665 per acre including removal of an old vineyard (US$4,500 per acre). The removal is excluded here and the rest converted [UCD-NAPA-2020] |
| Napa hillside (erosion control plan, terracing, small equipment) | **€110,000** | `UNVERIFIED` +45 % surcharge; county approval needed on slopes ≥ 5 % [UCD-NAPA-2020] |
| Mosel flat or gentle slope, wire trellis (~5,000 vines/ha) | **€25,000–30,000** | `UNVERIFIED`: grafted vines ~€1.8, trellis ~€8k, machine planting |
| Mosel steep slope, Einzelpfahl (~8,000–10,000 vines/ha, one stake per vine) | **€50,000–60,000** | `UNVERIFIED`: vines ~€2 plus stakes ~€1, planting by hand, terrace and wall repair |
| Côte d'Or, ≥ 9,000 vines/ha, low wires | **€40,000–42,000** | `UNVERIFIED`; density minimum from the INAO specification (`law.md` §3) |

- **Density choice** (spec §4.3) scales the vine cost linearly with vines/ha. Trellis and stake costs scale with row length or vine count.
- **Rootstock choice** has no price effect in the MVP (`UNVERIFIED` simplification).

**Establishment years** (fast-forwarded): each year costs **~60 % of the full running cost** in §4 (`UNVERIFIED`). For comparison, the Napa study's years 2 and 3 cash costs were US$11,806 and US$9,275 per acre, against US$11,871 per acre in a production year [UCD-NAPA-2020]. The third-leaf crop can be sold as grapes (backlog) or discarded. In the MVP it's **thinned off**, as young-vine practice often does. The Napa study removes ~50 % of the crop in year 3 [UCD-NAPA-2020].

---

## 4. Running costs (per ha per year, production years)

### 4.1 Labour hours by slope class
The biggest cost driver, and the reason the Mosel steep slopes are expensive.

| Work class | Labour-hours per ha per year | Source |
|---|---|---|
| Flat land, tractor-worked (Direktzug) | **200–250** | KTBL-based figures as summarised in [STEIL-WIKI] / [KTBL-DS] |
| Steep, cross-slope terraces worked by machine | **300–500** | same |
| Steep, winch-worked (Seilzug) | **800–1,600** (often > 1,000) | same |
| Steep, hand work only (traditional) | **~1,200** and up | same |
| Napa valley floor (vineyard management company, machine harvest) | ~121 hand hours per acre ≈ **300 h/ha**, plus contracted machine passes | [UCD-NAPA-2020] Table 3 |
| Côte d'Or (≥ 9,000 vines/ha, mostly hand work) | **500–700** | `UNVERIFIED` |

The hours mapped to our Plots (design values): Uferflur 250, Seitental 400, Blauschiefer-Hang 1,100 (winch), Terrassen 1,400 (hand), Côte d'Or flats 500, Hautes-Côtes 550, Village and 1er Cru 650, Napa floor, Carneros and bench 300, Napa mountain 450.

**Split of hours by task** (drives the Programmes; Napa study proportions [UCD-NAPA-2020], `UNVERIFIED` for the other Regions):
- winter pruning and tying ~25 %
- canopy work (suckering, shoot thinning, positioning, leaf removal) ~55 %
- crop and fruit thinning ~15 %
- irrigation and other ~5 %

Harvest labour is accounted separately (§4.3).

### 4.2 Wage rates (fully loaded employer cost per hour)

| Region | Legal minimum 2026 | Game rate: seasonal hand labour | Game rate: skilled tractor/cellar | Source |
|---|---|---|---|---|
| Mosel | €13.90/h (€14.60 from 2027) | **€17/h** | **€23/h** | minimum wage [BMAS-2026]; loading `UNVERIFIED` |
| Côte d'Or | SMIC €12.02/h (1 Jan 2026), €12.31/h (from 1 Jun 2026) | **€17/h** | **€22/h** | [SMIC-2026]; loading `UNVERIFIED` |
| Napa | US$16.90/h state minimum | **€29/h** (≈ US$31.5) | **€33/h** | [CA-MW-2026]. In 2020 UC Davis used US$29.51/h for hand labour and US$33.72/h for machine operators, including 40.53 % payroll overhead [UCD-NAPA-2020]. The game rate is lifted slightly for 2026 (`UNVERIFIED`) |

The **labour Programme tier** (Low/Medium/High, spec §5.1) sets crew size: 0.8×, 1.0× or 1.25× the Plot's needed hours. A **Low** crew finishes canopy tasks late, and a late task loses part of its benefit (see the viticulture docs). It also stretches the harvest over more days.

### 4.3 Harvest
- **Hand picking: ~1 t per picker per 8-hour day** on flat land [UCD-NAPA-2020]. Steep slopes: `UNVERIFIED` 0.4–0.6 t per picker-day. Picking cost = t ÷ (t per day) × 8 h × wage.
- **Machine harvest** (flat, trellised Plots only): **US$350/t including hauling** [UCD-NAPA-2020] ≈ €320/t. Not possible on Einzelpfahl or steep Plots.
- **Sorting** (spec §5.2) adds labour: `UNVERIFIED` +15 % picking hours for a sorting table, +30 % for berry-by-berry selection of Prädikat Lots.

### 4.4 Spray Programme (Low / Medium / High)
Anchor, Napa 2020 (a powdery-mildew region) [UCD-NAPA-2020]:
- 7 air-blast passes at US$100 per acre each, plus one sulphur dusting at US$90 per acre
- fungicide materials US$116 per acre per year; insecticide US$97 per acre per year
- total ≈ US$1,000 per acre ≈ €2,300/ha

| Tier | Passes per year (Napa / Côte d'Or / Mosel) | Cost per ha per year, flat land | Steep land (Mosel slopes, helicopter or drone) | Effect (see disease docs) |
|---|---|---|---|---|
| Low | 5 / 6 / 6 | €1,600 | €1,000 | cheapest; infections get through in wet years |
| Medium | 7 / 9 / 9 | €2,300 | €1,500 | baseline, ≈ typical practice |
| High | 10 / 12 / 13 | €3,300 | €2,200 | best protection; highest cost and more residue work |

- Cost per pass: **€120–150/ha by helicopter or drone on steep slopes** vs. €60–90/ha by ground on flat land (materials included). `UNVERIFIED`. The Mosel figures are lower overall because the materials are cheaper (copper and sulphur) and passes are shorter.
- Staff level changes **timing quality**, not cost (spec §5.4).

### 4.5 Other annual costs (per ha)

| Item | Mosel | Côte d'Or | Napa | Source |
|---|---|---|---|---|
| Canopy and floor materials, repairs, fuel | €1,500 | €2,000 | €2,500 | `UNVERIFIED` |
| Irrigation (where allowed) | — (steep: rarely) | forbidden | ≈ €300 (water + labour ≈ US$206 per acre; system maintenance US$126 per acre) | [UCD-NAPA-2020] |
| Frost protection, **Medium/High tier** | candles: €600 per night-event | candles or wind machine: €600 per night | wind machine ≈ €600 per season (12 h × US$18, plus maintenance US$150 per acre) | [UCD-NAPA-2020]; EU values `UNVERIFIED` |
| Property tax and insurance | €150 | €400 | ≈ 1 % of land value per year (property tax US$2,229 per acre in the study) | [UCD-NAPA-2020]; EU values `UNVERIFIED` |
| Associations and assessments | €100 | €300 | ≈ US$95 per acre (grower dues, housing, pest district) | [UCD-NAPA-2020]; EU values `UNVERIFIED` |

---

## 5. Winery operating costs (the basic Winery is included)

| Item | Cost | Source |
|---|---|---|
| Cellar consumables (yeast, nutrients, SO₂, fining, cleaning) | €10/hL | `UNVERIFIED` |
| Cooling and energy | €3/hL per month of temperature control | `UNVERIFIED` |
| Cellar labour per Lot | 6 h per 10 hL of must, at the skilled rate | `UNVERIFIED` |
| Lab analyses | free in Normal mode (spec §6) | — |
| Official testing (German A.P.-Nr.) or equivalent | €150 per Wine | `UNVERIFIED` |

**Volume conversions** used by the game (`UNVERIFIED` practical averages):
- white press yield ≈ **65 L of must per 100 kg** of grapes; reds ≈ **72 L of wine per 100 kg**
- **133 bottles (0.75 L) per hL**

---

## 6. Barrels and casks

| Vessel | New | 1st fill (one previous use) | Neutral (3+ uses) | Notes |
|---|---|---|---|---|
| **French oak barrique, 225 L** (Allier, Tronçais…) | **€950** (range €850–1,150 by grain and toast) | €380 | €120 | 2023–25 market reports quote €800–900 for a new 225 L French barrique [BARRIQUE-PRICE]; 2026 uplift `UNVERIFIED` |
| American oak barrique, 225 L (wine grade) | **€520** | €220 | €90 | `UNVERIFIED`. American oak can be sawn rather than split, so more of each tree is usable and it's cheaper than French oak, whose staves must be split (20–25 % of the tree is usable) [BARRIQUE-PRICE] |
| Hungarian oak barrique, 225 L | **€720** | €290 | €100 | `UNVERIFIED` |
| Mosel **Fuder**, 1,000 L (traditional) | **€7,500** | €3,000 | €900 | `UNVERIFIED` |
| Stainless steel tank | included in the Winery | — | — | spec §5.3 |

Surcharges (`UNVERIFIED`):
- toast: Light −€20, Medium ±0, Medium-plus +€20, Heavy +€35
- extra-fine grain: +€80
- tight-grain premium cooperage: +€150

Lifetime: a barrique is "new" for one fill, gives **most of its oak flavour in the first 2–3 fills**, and is neutral from the 4th fill (detailed in the oak docs, another milestone-1 file).

---

## 7. Staff (annual gross salary, spec §5.4)

| Role | Junior | Experienced | Senior |
|---|---|---|---|
| Vineyard manager | €38,000 | €48,000 | €62,000 |
| Cellar master | €40,000 | €52,000 | €68,000 |

- **Regional multiplier:** Mosel 1.00, Côte d'Or 0.95, Napa 1.70. All `UNVERIFIED` design values.
- The **Mentor** is free (spec §5.5).
- On a 0.5–2 ha estate, staff are hired **part-time** (`UNVERIFIED` simplification). Crews do the field hours (§4.1); the staff supervise.
  - **Vineyard manager:** max(0.25, the Plot's needed hours ÷ 3,400) of a full-time post.
  - **Cellar master:** max(0.25, hL of wine made ÷ 400) of a full-time post.

---

### Sorting at harvest (game simplification, `UNVERIFIED`)
| Sorting | Grey rot removed | Sound fruit lost | Extra labour |
|---|---|---|---|
| None | 10 % | 0 % | none |
| Table | 60 % | 3 % | 0.004 h/kg |
| Rigorous (berry by berry) | 90 % | 8 % | 0.012 h/kg |

The extra labour is added to the picking hours, so sorting also slows the harvest.

## 8. Bottling and packaging (per 0.75 L bottle)

| Item | Cost | Source |
|---|---|---|
| Glass | €0.55 (range €0.40–0.90; heavy "prestige" bottle €1.20) | `UNVERIFIED` |
| Closure | screwcap €0.15; natural cork €0.60 (range €0.35–1.50); technical cork €0.25 | `UNVERIFIED` |
| Label, capsule, carton share | €0.35 | `UNVERIFIED` |
| Mobile bottling service | €0.30 | `UNVERIFIED` |
| **Typical total** | **≈ €1.35 (screwcap) to €1.80 (natural cork)** | — |

**Closure choice** also sets cork-taint risk (TCA): natural cork carries a small risk; screwcap and technical cork carry none (spec §4.5 / A7).

---

## 9. Wine prices (average realised ex-cellar price per 0.75 L, before quality multiplier)

| Region | Legal category | Base price |
|---|---|---|
| Mosel | Deutscher Wein | €4.00 |
| | Landwein der Mosel | €5.50 |
| | Qualitätswein Mosel | €8.00 |
| | Kabinett | €11.00 |
| | Spätlese | €15.00 |
| | Auslese | €24.00 |
| | Beerenauslese / Eiswein / TBA (0.375 L) | €45 / €70 / €90 |
| | +20 % if a single-vineyard name is allowed (≥ 85 % Riesling or Pinot Noir) | — |
| | Site factor by Plot tier: cheap riverbank ×0.55, mid-low side valley ×0.75, mid-high slate slope ×1.0, famous terraces ×1.15 (`UNVERIFIED`; added after playtest: flat-site Prädikat wine was selling at steep-slope prices) | — |
| | Dry (trocken) Auslese: €18 instead of €24 (`UNVERIFIED`; the market expects Auslese to be sweet) | — |
| | Beerenauslese / TBA need ≥ 30 % / ≥ 60 % noble-rotten fruit in the Lot (game rule for "berry-by-berry selection", `UNVERIFIED` thresholds) | — |
| Côte d'Or | Vin de France | €7.00 |
| | Bourgogne (red or white) | €16.00 |
| | Bourgogne Hautes-Côtes de Beaune | €15.00 |
| | Village | €38.00 |
| | Premier Cru | €75.00 |
| Napa | "California" | €12.00 |
| | Napa Valley AVA (Cabernet Sauvignon) | €45.00 |
| | Napa Valley AVA (Chardonnay, Pinot Noir) | €32.00 |
| | Los Carneros AVA (Pinot Noir, Chardonnay) | €30.00 |
| | Mountain sub-AVA (Cabernet Sauvignon) | €60.00 |
| | Rutherford AVA (Cabernet Sauvignon) | €70.00 |
| | proprietary blend (< 75 % one variety) | −10 % |

All prices are `UNVERIFIED` design values. They keep the real-world ordering and rough ratios: Mosel Prädikat wines are cheap relative to Burgundy crus, and Napa Cabernet commands the highest ex-cellar prices of the three. Anchor: Napa Cabernet grapes averaged US$8,200/t in 2020, about US$11 of fruit per bottle at 720 bottles per ton, consistent with bottle prices several times that [UCD-NAPA-2020].

**Quality multiplier** (from the Tasting sheet's conclusion, spec §3.2):

| Quality | Multiplier |
|---|---|
| Poor | 0.55 |
| Acceptable | 0.80 |
| Good | 1.00 |
| Very good | 1.25 |
| Outstanding | 1.60 |

A **faulty** Wine (e.g. volatile acidity above the legal limit, cork taint, strong Brett) sells in **bulk at €1.20 per litre** (`UNVERIFIED`).

**Wrong variety for the Region** (e.g. Riesling in Côte d'Or → Vin de France): the price rule above already punishes it through the Legal category. No extra penalty is needed.

### Affordability check method (§1)
Total = land + Planting + 3 × (0.6 × running cost) + first-vintage running cost + €15,000 for Winery, barrels and bottling. Running cost per ha, from §4: Uferflur €7.5k; Seitental €9.5k; Blauschiefer €22k; Terrassen €28k; Côte d'Or €14–16k; Napa €27–30k.

---

## 10. Worked sanity checks (design review)

**Mosel steep slate, 1.2 ha Riesling, Medium tiers, Kabinett, "Good" quality:**
- Assumed yield: 60 hL/ha (`UNVERIFIED`; well under the 125 hL/ha legal cap [MOSEL-PS]) → 72 hL → ~9,600 bottles.
- Revenue: 9,600 × €11 = **€106k**.
- Costs: labour 1,100 h/ha × 1.2 ha × €17 = €22k; harvest picking ~€8k; sprays and materials ~€4k; cellar ~€2k; bottling €1.35 × 9,600 = €13k.
- Staff (Experienced level): vineyard manager 1,320 h ÷ 3,400 = 0.39 post × €48k ≈ €19k; cellar master 0.25 post × €52k = €13k.
- **Margin ≈ €25k.** Thin but positive, as for many real family estates. The margin grows if the player makes a Spätlese from the best Blocks.

**Napa valley floor, 1.0 ha Cabernet, "Good":**
- Yield: 4 t per acre ≈ 9.9 t/ha [UCD-NAPA-2020] → ~7,100 bottles.
- Revenue: 7,100 × €45 = **€320k**.
- Costs: running ~€27k; picking ~€3k; cellar and barrels (50 % new French oak: 16 barriques × €950 × 0.5 ≈ €7.6k); bottling ~€13k.
- Staff (Experienced level, Napa multiplier 1.7, both at the 0.25 post minimum): ≈ €42k.
- **Margin ≈ €230k.** That's why Napa land is so expensive: the land price absorbs the margin.
- `UNVERIFIED` balance: this is the largest open balancing risk. Tune the Napa prices, yields or land prices if Napa dominates in playtests.

## 11. Overdraft interest (multi-vintage)

**Game simplification:** a negative cash balance is carried by the bank at 9 % a year, charged monthly on the balance on the 1st of the month (`UNVERIFIED` design value; euro-area small-business overdraft rates are typically in the high single digits). Loans stay in the backlog. The overdraft message says so in-game.

## Open questions
1. Real Mosel and Côte d'Or labour loadings and salaries (the regional multipliers) are unsourced.
2. Real ex-cellar price distributions per category are needed for calibration. Possible sources: DWI market reports, BIVB market data, Napa DTC surveys.
3. Should the MVP allow selling young-vine (3rd leaf) grapes? Currently thinned off.
4. Balancing Napa margins against Mosel margins; playtest.

## Sources
- [SAFER-2024 via REUSSIR] Réussir Vigne, "Prix des vignes 2024 : quelle évolution par région ?" (SAFER data): https://www.reussir.fr/vigne/prix-des-vignes-2024-quelle-evolution-par-regions
- [UCD-NAPA-2020] UC Cooperative Extension / UC Davis ARE, *2020 Sample Costs to Establish a Vineyard and Produce Winegrapes, Cabernet Sauvignon, North Coast Region, Napa County*: https://coststudyfiles.ucdavis.edu/uploads/cs_public/fe/24/fe24e27a-5c29-4cc3-a83c-63a31cd0c767/2020napawinegrape.pdf
- [KTBL-DS] KTBL, *Datensammlung Weinbau und Kellerwirtschaft* (the primary data behind the labour figures): https://www.ktbl.de/service/presse/pressemeldung/ktbl-datensammlung-weinbau-und-kellerwirtschaft
- [STEIL-WIKI] "Steillagenweinbau", Wikipedia (secondary summary of the labour-hour ranges): https://de.wikipedia.org/wiki/Steillagenweinbau; see also Vitipendium "Direktzug": https://www.vitipendium.de/Direktzug
- [BMAS-2026] BMAS, "Mindestlohn steigt zum 1. Januar 2026 auf 13,90 Euro": https://www.bmas.de/DE/Service/Presse/Pressemitteilungen/2025/mindestlohn-steigt-zum-ersten-januar-2026.html; Bundesregierung: https://www.bundesregierung.de/breg-de/aktuelles/mindestlohn-steigt-2391010
- [SMIC-2026] LégiSocial, "SMIC 2026": https://www.legisocial.fr/reperes-sociaux/montant-smic-2026-taux-horaire-net-brut.html; info.gouv.fr, "Le SMIC revalorisé le 1er juin 2026": https://www.info.gouv.fr/actualite/le-smic-revalorise-le-1er-juin-2026
- [CA-MW-2026] California DIR, Minimum Wage: https://www.dir.ca.gov/dlse/minimum_wage.htm
- [BARRIQUE-PRICE] WineWiki, "Barrique — 225L Bordeaux Barrel" (secondary; €800–900 new French barrique, 12 %+ rise): https://www.winewithseth.com/winewiki/barrique-225l-bordeaux-barrel/
- [MOSEL-PS] BLE, "Mosel" Produktspezifikation (125 hL/ha cap): https://www.ble.de/SharedDocs/Downloads/DE/Ernaehrung-Lebensmittel/EU-Qualitaetskennzeichen/Wein/Antraege/Bestimmte_Anbaugebiete/Mosel/Mosel_1Uae/Produktspezifikation.pdf
