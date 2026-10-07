# The Winery shop: make it cozy with the money your wine earns

Status: approved by the owner 2026-10-07 ("agree, go ahead i also want the frost protection and such. just this in
addition"): the Winery shop plus a "Vineyard & cellar" equipment section (§6). Revised after the owner's direction: "more like stuff to the winery.
like colors on the wall and outside panels and such. wanna make it a bit cozy and fun to actually do an effort to make
money". Earlier draft (equipment: frost protection, sorting table) moved to the backlog as a later "Vineyard & cellar"
section of the same shop.

## 1. Intent

**The loop:** your wine sells, the cash lets you make the winery yours, and a cozier winery is a reward you see every time
you walk into the 3D hall.

- **Today:** the "Winery look" panel is free, and every Region starts fully cozy, so money buys nothing you can see.
- **New:** a new Estate starts with the working winery as built, using the Region's local stone or timber for walls and
  floor. Everything cozy is bought in the shop: paint colours, lights, chandeliers, the tasting corner, plants, the
  candlelit cellar, the outside, and new exterior items (facade colour, panels or cladding, shutters, string lights, a
  sign with your Estate's name).

**Rules:**
- Purely cosmetic: the simulation never reads it (ADR 0001).
- Prices are real money from the Estate's cash, so decor competes with running the vineyard. Overspending can push you
  into overdraft, as for a real grower: a gentle trade-off, not a trap.
- No study currency, no random rewards, no time pressure.

**Success:**
- A new player finds the shop without being told.
- Every item shows what it looks like before you buy.
- Owned items can be switched freely.
- Saves replay all of it.

## 2. The catalogue (first set)

| Section | Items (each a choice you buy once, then switch freely) | Today |
|---|---|---|
| **Interior walls** | Plain render (start); paint: whitewash, cream, ochre, sage, burgundy; slate stone, limestone, whitewashed brick, redwood boards | partly exists |
| **Floor** | concrete (start), stone flags, slate flags, terracotta, herringbone brick | exists |
| **Ceiling** | steel trusses (start), oak beams | exists |
| **Lights** | workshop (start), warm pendants, chandeliers | exists |
| **Tasting corner** | none (start), tasting table, lounge | exists |
| **Plants** | off (start), potted plants and planter boxes | exists |
| **Cellar** | plain (start), candlelit | exists |
| **Facade** | the Region's render (start); paint: white, cream, ochre, sage, slate grey; panels: timber cladding, slate shingle, limestone ashlar | new: material swaps |
| **Shutters and doors** | none (start); green, blue, oxblood, natural oak | new |
| **Outside** | plain yard (start); cozy yard (bench, lanterns, warm windows); string lights; a sign with your Estate's name | partly exists |

**Prices** are `UNVERIFIED` design values, roughly the real cost of the work for a small winery: about €3–8k for a paint
job, €10–40k for cladding or a tasting lounge. Buying everything costs about €150–200k, about one to two good Vintages of
sales on a small Estate. The tuning target: the first treat is affordable after the first Vintage sells, and the full set
takes several years. The prices live in `data/winery_shop.json`, and a sim test pins that the full set costs between one
and three times a typical Vintage's revenue.

**The Region's local walls and floor** (Mosel slate, Côte d'Or limestone, Napa redwood) are owned from the start: the
building is made of them.

## 3. Easy to find and intuitive (the owner's requirement)

- **"Shop" in the left navigation,** with a gold dot until the first visit and an intro card on first open.
- **The Winery screen's "Winery look" panel** becomes "Your winery": it shows what you own and lets you switch among it,
  with a clear "Visit the shop" button.
- **When a Vintage's first Wine sells,** the Inbox message adds one friendly line, "Your winery could use a treat: see
  the Shop", with a button. It is shown once per Vintage, never an alert.
- **The shop screen:**
  - sections as above;
  - each item is a card with a picture of it in the 3D winery, the price, and a one-line description;
  - the state of each card is "Owned · in use", "Owned" or the price;
  - "Preview in 3D" shows it on your winery before buying, and leaves without changing anything;
  - "Buy" (with the cash after purchase shown) and "Use" for owned items;
  - an item you can't afford shows the gap.
- **The pictures** are rendered once from the 3D winery by a harness script (`scripts/shop_thumbs.sh`) and committed as
  small images: one per item, on the Region's default look.

## 4. Architecture

- **Sim:**
  - `data/winery_shop.json`: item id, section key, value, label, blurb, price, and the Region's free starting values.
  - `WineryShop.cs`: catalogue, `Owned(game)`, and the `buy <section> <value>` command (cash debit, ledger
    "Winery", owned set).
  - `decor` commands are refused for items not owned.
  - The snapshot carries the shop (items, owned, in use, affordable).
  - **Old saves:** every look option chosen before this release is owned for free (migration on load), and the starting
    set of a game from before this release is the full regional default.
- **3D:**
  - `winery_style.gd` gains the new elements (facade paint and panels, shutters, string lights, sign);
  - `winery.gd apply_style` swaps facade, plinth and shutter materials and adds lights and a sign label;
  - the plain start look already exists (`PLAIN`).
- **UI:** a `shop.gd` screen, nav entry, intro card, and the inbox line. The Winery look panel becomes "Your winery".
- **Tests:**
  - buying debits cash and replay keeps ownership;
  - using an item not owned is refused;
  - old saves own their look;
  - a new game owns only the starting set;
  - price-band test.
  - The `winerylook` harness renders the new elements. The capture run buys and applies two items. The layout check and
    the visual diff cover the shop.

## 5. Out of scope (backlog)

- The label designer bound by label law.
- A trophy wall for medals.
- Resale, and seasonal decorations.

## 6. Vineyard & cellar: equipment with real effects (part of this build)

The same Shop has a second section of real equipment. These items, unlike the cosmetic ones, change the simulation; each
card says how, with cited numbers.

| Item | What it changes in the simulation | Where the need shows |
|---|---|---|
| **Frost candles** (stock per night) | Today's frost protection, kept as the baseline: a small lift of vine-level Tmin on radiation-frost nights, paid per hectare per night. Owned from the start | frost warnings, Programmes frost row |
| **Wind machine** | Bought once (per about 4–5 ha), then a low cost per night. Lifts vine-level Tmin under an inversion (radiation frost) only, and does nothing on windy, advective nights | frost warnings, Programmes |
| **Overhead sprinklers** | Bought once, plus water per night. Protects down to a lower temperature through the latent heat of freezing water, and works in advective frost too. Offered only where water is plausible (not on steep Mosel slate) | frost warnings, Programmes |
| **Sorting table** | Makes rigorous sorting possible. Without it, sorting stays at table level | the harvest panel's sorting choice |

**How it fits the existing game:**
- The frost Programme decides whether you protect on a frost night (off, or on).
- The method is the best one you own: sprinklers, then the wind machine, then candles.
- It replaces today's abstract +1 / +2 °C tiers with per-method values.
- Old saves: candles only, with their tier mapped to on or off.

**Numbers** (protected temperature, conditions, coverage, capital and running costs, regional use, and the effect of a
sorting table) come from a research task and are cited in `economy.md` and `phenology.md` §6. Values the research cannot
back are `UNVERIFIED`.

**Findability:**
- a frost-warning message shows what you own and links to the section;
- the Programmes frost row names the method in use;
- the rigorous-sorting option says "needs a sorting table", with a link;
- the first Inbox message of a new game mentions the Shop once.

**Tests:**
- the wind machine lifts Tmin on a radiation night and not on a windy one;
- sprinklers protect below the candle limit;
- rigorous sorting without a table is refused;
- a Mosel steep Plot offers no sprinklers;
- Côte d'Or 2016 with a wind machine loses less to frost than without.
