# The Equipment shop: buy what a real grower buys

Status: draft for the owner's review (2026-10-07). The owner asked for more gamification through customisation and a shop
"where you can buy decorations or other things to help you", and wants the shop "easy to find and intuitive". Agreed
direction: real equipment bought with Estate money, each item a lesson. No study currency, no shortcuts that skip a
decision, no pressure mechanics. Earned decor and the label designer come later.

## 1. Intent

- **One clear place, the Equipment shop,** where you buy real vineyard and cellar equipment with the Estate's cash.
- **Every item changes what you can do,** and its card says how, with cited numbers:
  - frost protection that actually changes a frost night;
  - a sorting table that makes rigorous sorting possible.
- **The fun:** a visible investment with a visible payoff (a frost night survived, cleaner fruit in a rot year).
- **The learning:** why growers own this equipment, and when it pays.

**Success:**
- A new player finds the shop without being told: it sits in the left navigation, the first Inbox message mentions it,
  and contextual links appear exactly where the need arises.
- Buying is two clicks, with no hidden costs. Running costs are shown on the card.
- Every effect is computed by the simulation, cited, or marked `UNVERIFIED` (ADR 0001, science rules).
- Saves replay purchases (a command).

## 2. The catalogue (first set)

| Item | Category | What it changes in the simulation | Where the need shows |
|---|---|---|---|
| **Frost candles** (stock per night) | Frost | Today's Medium frost tier: +1 °C at vine level on radiation-frost nights, €600 per ha per night. No purchase needed; shown in the shop as the baseline | frost warnings, Programmes |
| **Wind machine** (one per about 4–5 ha) | Frost | Capital cost, then a low running cost per night. Lifts vine-level Tmin under an inversion (radiation frost) only. No effect on windy, advective frost nights. Replaces the High tier's abstract "+2 °C" | frost warnings, Programmes frost row |
| **Overhead sprinklers** | Frost | Capital cost plus water. Protects to a lower temperature through the latent heat of freezing water, and works in advective frost too. Needs a water source (not on steep Mosel slate: not offered there) | frost warnings, Programmes |
| **Sorting table** (vibrating) | Harvest | Makes rigorous sorting possible. Without it, sorting is hand sorting at the table: today's "Table" level | harvest panel, the sorting choice |

**Numbers** (cost, protected temperature, coverage per unit, running cost, regional use) come from a research task and
are cited in `docs/science/economy.md` and `phenology.md` §6. Values the research cannot back are marked `UNVERIFIED`. The
current tier magnitudes (+1 / +2 °C) are replaced by per-method values.

**Regional sense:** the shop shows only what makes sense on the Plot:
- no sprinklers on steep slate without water;
- wind machines on flat or gentle ground only.

Anything not offered says why ("not used on steep terraces: …").

## 3. Easy to find and intuitive (the owner's requirement)

- **Navigation:** an "Equipment" entry with a cart glyph in the left navigation, right after Programmes. A gold dot shows
  until the first visit (the existing onboarding "visited" flags), and the screen has an intro card like other screens.
- **The first Inbox message** of a new game (and of a famous vintage) gains one line: "You can buy frost protection and a
  sorting table in Equipment", with a button that opens it.
- **Contextual links, at the moment of need:**
  - a frost-warning message: "Protect the vines tonight", showing what you own, with a "See frost protection" button;
  - the Programmes frost row shows the method in use ("Wind machine" or "Candles") and an "Equipment" link;
  - the harvest panel: the rigorous-sorting option says "needs a sorting table", with a link.
- **The screen:**
  - categories (Frost, Harvest) as sections, not hidden tabs;
  - each item is a card with an icon, the price, the running cost, "What it does" (one sentence with numbers), "When it
    pays" (one line), and an "Owned ✓" state;
  - a Buy button that shows the cash after purchase;
  - an item you can't afford shows the gap;
  - an item not offered on this Plot says why;
  - no countdowns, no "limited", no random rewards.
- **Purchases are final** in this version (no resale), and that is stated on the card.

## 4. Architecture

- **Sim:**
  - `Equipment.Catalog(data)` from `data/equipment.json` (id, name, category, cost, running cost, coverage, effect
    parameters, region rules, sources).
  - Command `buy <item> [count]`: ledger entry "Equipment", owned set in the game state, replayed from the save.
  - Frost: `VineyardModel` takes the protection method and lift from the owned equipment and the frost programme's on/off
    decision, instead of the tier.
  - Sorting: the rigorous level requires the sorting table (the sim refuses the order otherwise, with a message).
  - Snapshot: an `equipment` object (catalogue with owned flags, offered or not with a reason, affordability).
- **UI:** an `equipment.gd` screen, the nav entry, an onboarding intro card, and the contextual links in inbox, programmes
  and plot/ripeness.
- **Tests:**
  - buying debits cash, and replay restores ownership;
  - the wind machine lifts Tmin on a radiation night and not on a windy one;
  - sprinklers protect below the candle limit;
  - rigorous sorting without a table is refused;
  - Mosel slate offers no sprinklers.
- **Harness:** the capture run visits Equipment and buys a wind machine. The famous-vintage harness plays Côte d'Or 2016
  with and without a wind machine and shows the frost loss difference. The layout check and visual diff cover the new
  screen.

## 5. Out of scope (backlog)

- Earned decor and a trophy wall; the label designer bound by label law.
- Cooling and lab equipment.
- Resale, depreciation and loans.
- A weather station.
