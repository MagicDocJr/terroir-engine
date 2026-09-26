# Wine law: simplified Region rulebooks

Scope: the rules that decide a Wine's **Legal category** in the MVP (spec §4.4). Each rulebook is a small, extensible table the simulation checks when a Wine is bottled. Values are paraphrased from primary sources and cited below.

**Game simplification (labelled in-game):** today's law applies in every Timeline year (ADR 0002). Examples: the German origin pyramid reform of 2021, and current AOC yields, apply even in 1995.

**Game simplification:** EU planting authorisations and US county permits are assumed to come with the Plot purchase (see "Not modelled").

Conventions used below:
- °Oe is Oechsle (Mosel); % vol is potential or actual alcohol by volume.
- "Natural minimum" means minimum natural alcohol at harvest, **before** any enrichment.
- TAV is *titre alcoométrique volumique*, i.e. % vol.

---

## 1. EU framework (Mosel and Côte d'Or)

### Wine-growing zones
- **Mosel is in zone A.** Zone A covers all German wine regions except Baden [EU-1308, Annex VII App. 1].
- **Côte d'Or is in zone C I** [WIKI-ZONES]. `UNVERIFIED`: checked only against a secondary source; confirm against Annex VII Appendix 1.

### Enrichment (chaptalisation) limits [EU-1308, Annex VIII Part I]

| Zone | Max increase in natural alcohol | Max total alcohol after enrichment |
|---|---|---|
| A | +3.0 % vol | 11.5 % vol (red wine 12.0 %) |
| B | +2.0 % vol | 12.0 % vol (red 12.5 %) |
| C I | +1.5 % vol | 12.5 % vol |

- Member States may ask for an **extra +0.5 % vol in exceptionally unfavourable years**. Germany received this for 2017 grapes in some regions [EU-2017/2281].
- Permitted methods: sucrose, concentrated grape must or rectified concentrated grape must, or partial concentration (including reverse osmosis on must) [EU-1308 Annex VIII I.B].
- AOC specifications can set a **higher ceiling for total alcohol** after enrichment than the zone default (see Côte d'Or below).

### Acidification and deacidification [EU-1308 Annex VIII I.C–D]
- **Acidification** of wine: max 2.5 g/L as tartaric acid.
- **Deacidification** of wine: max 1 g/L as tartaric acid.
- **Mutual exclusivity:** enrichment and acidification of the same product are mutually exclusive (with narrow derogations), and so are acidification and deacidification.
- **Game rule:** a Lot that was chaptalised can't also be acidified, and vice versa. The cellar UI blocks the second action and the Cellar master explains why.
- `UNVERIFIED`: the exact per-zone acidification permissions for grapes/must (zone A must is normally not acidified except in derogation years). The MVP rule is: **no acidification in the Mosel; acidification allowed in Côte d'Or only in derogation years (off by default); allowed in Napa.**

---

## 2. Mosel (Germany, PDO "Mosel")

Source: the official PDO product specification [MOSEL-PS] and the Weingesetz [WEING].

### Categories (lowest to highest)

| Legal category | Requirement (Riesling) | Enrichment | Notes |
|---|---|---|---|
| Deutscher Wein (Wein) | any sound grapes | allowed (zone A limits) | fallback category for anything that fails higher rules |
| Landwein (PGI "Landwein der Mosel") | `UNVERIFIED`: ≈ 6.0 % vol natural / 50 °Oe (the Pfalz figure) [WK-MMG]; dry or off-dry only | allowed | |
| **Qualitätswein Mosel** | **≥ 55 °Oe / 6.7 % vol natural** [MOSEL-PS 3.2] | allowed (zone A limits) | needs official testing (A.P.-Nr.) |
| **Kabinett** | **≥ 73 °Oe / 9.5 % vol** (Elbling: 70 °Oe) | **forbidden** [WEING §20] | |
| **Spätlese** | **≥ 80 °Oe / 10.6 % vol** (Riesling) | forbidden | late harvest of fully ripe grapes |
| **Auslese** | **≥ 88 °Oe / 11.9 % vol** (Riesling) | forbidden | selected bunches; botrytis allowed |
| **Beerenauslese** | **≥ 110 °Oe / 15.3 % vol** | forbidden | overripe or botrytised berries |
| **Eiswein** | **≥ 110 °Oe / 15.3 % vol** | forbidden | naturally frozen at harvest and pressing |
| **Trockenbeerenauslese** | **≥ 150 °Oe / 21.5 % vol** | forbidden | shrivelled botrytised berries |

- Other white varieties such as **Chardonnay** have higher Prädikat thresholds: Spätlese 85 °Oe, Auslese 93 °Oe [MOSEL-PS]. **Red varieties** such as Pinot Noir (Spätburgunder) use the same thresholds as Riesling for Spätlese and Auslese (80 and 88 °Oe) [MOSEL-PS]. **Cabernet Sauvignon** and Chardonnay are both on the permitted-variety list [MOSEL-PS §8].
- **Maximum yield: 125 hL/ha** for the PDO [MOSEL-PS §7]. Any volume above that loses the PDO.
- **Single-vineyard names** in Bereiche Bernkastel, Burg Cochem, Ruwertal and Saar require **≥ 85 % Riesling or Pinot Noir** [MOSEL-PS 10.2.2]. Our Mosel Plots sit in Bereich Bernkastel, so **a Chardonnay or Cabernet can't carry a single-vineyard name.** That's a clean, real consequence of "any variety anywhere".
- **Ageing and release:** Ortswein (village-level wine) requires Kabinett-level must at least and can't be sold before 15 December of the harvest year [DWI-PYR].

### Origin pyramid (2021 reform, binding from vintage 2026)
The four tiers, from broadest to narrowest [DWI-PYR]:
1. **Gebietswein**: wine of the PDO region, e.g. "Mosel".
2. **Regionalwein**: a Bereich (sub-region).
3. **Ortswein**: a village.
4. **Lagenwein**: a single vineyard, optionally Erste Lage / Große Lage.

For the MVP, a Wine's origin label is simply "Mosel" plus the Plot's village or site name, if the ≥85 % variety rule is met. The Prädikat is the main price driver.

### Must-weight conversions used by the game
- °Oe = (SG − 1) × 1000.
- Potential alcohol follows the spec's own pairs, e.g. 73 °Oe ≈ 9.5 % vol and 88 °Oe ≈ 11.9 % vol. The simulation's sugar model (see the fermentation docs) must reproduce these anchors within ±0.2 % vol.

---

## 3. Côte d'Or (Burgundy, France)

Source: INAO specifications (cahiers des charges). The figures below come from the **2010 revision drafts** of the Pommard AOC [INAO-POMMARD] and Bourgogne AOC [INAO-BOURGOGNE] specifications. Where a draft shows an old (struck-through) and a new value, the new value is used. `UNVERIFIED`: these may have been amended since 2010.

### Hierarchy (Plot Classification caps the Legal category)
1. **Grand Cru**: not offered in the MVP; aspirational only.
2. **Premier Cru**: village name + "Premier Cru", on 1er Cru-classified parcels.
3. **Village**: village name only, inside the village's delimited area.
4. **Regional**: "Bourgogne", or "Bourgogne Hautes-Côtes de Beaune" on the plateau.
5. **Vin de France**: the fallback for non-permitted varieties, or for wines that fail AOC rules.

A Wine can always be **declassified downwards** (repli) to a broader appellation it qualifies for, never upwards.

### Varieties
- **Village and 1er Cru reds** (Pommard model): Pinot Noir; accessory varieties (Chardonnay, Pinot Blanc, Pinot Gris) ≤ 15 % of the vines in a parcel, **interplanted only** [INAO-POMMARD V].
- **Bourgogne regional:**
  - whites: Chardonnay (dominant), Pinot Blanc; Pinot Gris ≤ 10 %
  - reds: Pinot Noir and Gamay
  - [INAO-BOURGOGNE]
- **Game simplification:** our fictional village permits both red (Pinot Noir) and white (Chardonnay) wines, like several real Côte de Beaune villages. Pommard itself is red-only.
- **Consequence for "any variety anywhere":** Riesling or Cabernet Sauvignon planted on any Côte d'Or Plot can only be sold as **Vin de France**.

### Rules that bite in the simulation

| Rule | Regional (Bourgogne) | Village (Pommard model) | Premier Cru (Pommard model) |
|---|---|---|---|
| Min planting density | `UNVERIFIED` ~5,500–6,400 vines/ha (varies by sub-area) [INAO-BOURGOGNE] | **9,000 vines/ha**, rows ≤ 1.25 m, vines ≥ 0.5 m apart | same |
| Pruning | — | ≤ 8 buds/vine (Guyot simple or spur/cordon) | same |
| Max average crop on the vine | — | 9,000 kg/ha | same |
| Min sugar in grapes | reds 162–175 g/L; whites 153–170 g/L (draft old/new) | 180 g/L | 189 g/L |
| Natural minimum alcohol | reds 10.0–10.2 %; whites 10.5 % | 10.5 % vol | 11.0 % vol |
| Max total alcohol after enrichment | reds 12.7–13 %; whites 13–13.5 % | 13.5 % vol | 14.0 % vol |
| Yield (base / hard cap "butoir") | reds 55–60 hL/ha; whites 60–68 hL/ha | 50 / 58 hL/ha | 48 / 56 hL/ha |
| Irrigation | forbidden | forbidden | forbidden |
| Wood chips | forbidden | forbidden | forbidden |
| Malic acid at bottling | — | ≤ 0.4 g/L (MLF effectively required for reds) | same |
| Residual sugar (reds) | — | ≤ 2 g/L | same |
| Minimum ageing | — | until 15 June after harvest; released after 30 June | same |
| Young vines | — | eligible from the 2nd year after planting | same |

- **Chaptalisation is legal in Côte d'Or** within zone C I limits (+1.5 % vol), subject to the AOC's ceiling on total alcohol above.
- **Must concentration** (subtractive enrichment) is allowed up to 10 % concentration [INAO-POMMARD IX].

### Hautes-Côtes de Beaune (regional, mid-low Plot)
- Yields: reds 50/60, whites 55/66 hL/ha (draft old/new).
- Natural minimum alcohol: reds 10.0–10.5 %, whites 10.5 %.
- Max total alcohol after enrichment: 13–13.5 %.
- [INAO-BOURGOGNE]

---

## 4. Napa Valley (USA, AVA system)

Sources: 27 CFR (TTB) and the California Code of Regulations (CCR).

### Labelling rules that set the Legal category
- **Varietal label** (e.g. "Cabernet Sauvignon"): **≥ 75 %** of that variety, all of it grown in the labelled appellation [27CFR4.23]. Below 75 % the wine is a proprietary blend ("Red Wine").
- **AVA label** (e.g. "Napa Valley", "Rutherford", "Los Carneros"): **≥ 85 %** of the grapes grown within the AVA [27CFR4.25].
- **Conjunctive labelling (California):** a Napa County wine labelled with a sub-AVA must also say "Napa Valley" on the label [CA-BPC-25240].
- `UNVERIFIED`: county appellation ≥ 75 % from that county, and vintage date ≥ 95 % from the year for AVA wines [27CFR4.27], both from secondary sources. The MVP uses a single-Plot estate, so these always pass.
- **MVP Legal category ladder:**
  1. **Sub-AVA** (Rutherford, a mountain AVA, Los Carneros)
  2. **Napa Valley AVA**
  3. **"California"** (e.g. if AVA rules fail after buying in fruit, which is backlog)

  Price depends mostly on the AVA tier plus quality.

### Winemaking rules
- **No chaptalisation in California:** sugar, or sugar-containing material other than pure condensed grape must, is prohibited in still grape wine [17CCR17010]. Federal law would allow it, but California's rule is stricter.
- **Water:** may be used to flush equipment or aid fermentation, but can't reduce must below **22 °Brix**. If the must is already below 23 °Brix, water may lower it by at most 1 °Brix [27CFR24.176]. **Game rule:** "water back" is allowed on Napa Lots above 22 °Brix only.
- **Acidification:** tartaric, malic, citric and lactic acid are authorised to correct natural acid deficiency [27CFR24.246]. **Game rule:** acidification is allowed on Napa Lots, and is the normal correction for high pH.
- **Irrigation** is allowed (the UC Davis Napa cost study assumes drip irrigation) [UCD-NAPA-2020].
- **Hillside development:** planting on slopes ≥ 5 % needs county approval (an erosion control plan) [UCD-NAPA-2020]. **Game rule:** the mountain Plot's planting cost includes this approval, as a surcharge and 1 season of delay (`UNVERIFIED` magnitude).

---

## 5. Rulebook data shape (for the simulation)

Each Region exports a list of **categories**, ordered from best to fallback. Each category is a set of **predicates** over the Lot/Wine history:

```
category:
  id, displayName, region
  permittedVarieties | varietyMinShare (e.g. Napa varietal ≥ 0.75)
  minNaturalAlcohol | minMustWeightOe | minSugarGL      (per variety group)
  maxYieldHLha, maxYieldButoirHLha
  enrichment: forbidden | {maxIncreasePctVol, maxTotalPctVol}
  acidification: forbidden | allowed | derogationOnly
  waterAddition: forbidden | {minBrixAfter: 22}
  irrigation: forbidden | allowed
  minPlantingDensity, maxBudsPerVine
  maxMalicAtBottling, maxResidualSugar (reds)
  minAgeingUntil (month/day of year after harvest)
  requiresPlotClassification ≥ X
```

The first category whose predicates all pass becomes the Wine's **Legal category**. The Tasting sheet and P&L show **why** higher categories failed, e.g. "Not Kabinett: chaptalised (+1.2 % vol) — Prädikat wines may not be enriched."

## Not modelled in the MVP (backlog)
- **EU planting authorisations**: the 1 % per year growth cap, from Regulation 1308/2013 Arts. 61–72.
- **German single-vineyard (Lagen) register detail**, and VDP private classifications.
- **Burgundy Grand Cru rules.**
- **US TTB label approval (COLA)** and California county-name rules.
- **Organic or biodynamic certification rules.**

## Sources
- [EU-1308] Regulation (EU) No 1308/2013, Annex VII Appendix 1 (zones) and Annex VIII (enrichment, acidification): https://www.legislation.gov.uk/eur/2013/1308/annex/VIII/adopted (retained EU text, identical to the 2013 original); EUR-Lex for current consolidation.
- [EU-2017/2281] Commission Implementing Regulation (EU) 2017/2281: +0.5 % enrichment for 2017 in certain German regions: https://eur-lex.europa.eu/eli/reg_impl/2017/2281/oj/eng
- [WIKI-ZONES] "European Union wine growing zones", Wikipedia (secondary; used only for Côte d'Or = C I): https://en.wikipedia.org/wiki/European_Union_wine_growing_zones
- [MOSEL-PS] BLE, "Mosel" Produktspezifikation für eine geschützte Ursprungsbezeichnung (current version, cites 2023 data): https://www.ble.de/SharedDocs/Downloads/DE/Ernaehrung-Lebensmittel/EU-Qualitaetskennzeichen/Wein/Antraege/Bestimmte_Anbaugebiete/Mosel/Mosel_1Uae/Produktspezifikation.pdf
- [WEING] Weingesetz §20 (Prädikatswein, no enrichment): https://www.gesetze-im-internet.de/weing_1994/__20.html
- [WK-MMG] WeinKommission Kügler, "Mindestmostgewichte" (Pfalz, zone A; secondary): https://www.weinkommission.com/assets/uploads/dateien/mindestmostgewichte.pdf
- [DWI-PYR] Deutsches Weininstitut, "Herkunftspyramide für Qualitäts- und Prädikatsweine": https://www.deutscheweine.de/qualitaetstandard/462/neue-herkunftspyramide-f%C3%BCr-qualit%C3%A4ts-und-pr%C3%A4dikatsweine
- [INAO-POMMARD] INAO, Cahier des charges AOC « Pommard », version 2.2 (21/09/2010, national opposition draft): https://extranet.inao.gouv.fr/fichier/PNOCDCPommard.pdf
- [INAO-BOURGOGNE] INAO, Cahier des charges AOC « Bourgogne », version 2.2 (05/08/2010, national opposition draft): https://extranet.inao.gouv.fr/fichier/PNOCDCBourgogne.pdf
- [27CFR4.23] 27 CFR 4.23, varietal (grape type) designations: https://www.ecfr.gov/current/title-27/chapter-I/subchapter-A/part-4
- [27CFR4.25] 27 CFR 4.25, appellations of origin: https://www.ecfr.gov/current/title-27/chapter-I/subchapter-A/part-4/subpart-C/section-4.25
- [27CFR4.27] 27 CFR 4.27, vintage wine (secondary summary: https://www.winewithseth.com/winewiki/label-rules-united-states/)
- [27CFR24.176] 27 CFR 24.176, crushing and fermentation (water, 22 °Brix): https://www.ecfr.gov/current/title-27/chapter-I/subchapter-A/part-24/subpart-F/section-24.176
- [27CFR24.246] 27 CFR 24.246, materials authorised for the treatment of wine and juice: https://www.ecfr.gov/current/title-27/chapter-I/subchapter-A/part-24/subpart-L/section-24.246
- [17CCR17010] Cal. Code Regs. tit. 17, §17010: https://www.law.cornell.edu/regulations/california/17-CCR-17010
- [CA-BPC-25240] California Business & Professions Code §25240 (Napa Valley conjunctive labelling): https://codes.findlaw.com/ca/business-and-professions-code/bpc-sect-25240/
- [UCD-NAPA-2020] Kurtural, Stewart, Sumner, *2020 Sample Costs to Establish a Vineyard and Produce Winegrapes, Cabernet Sauvignon, North Coast Region, Napa County*, UC Cooperative Extension / UC Davis ARE: https://coststudyfiles.ucdavis.edu/uploads/cs_public/fe/24/fe24e27a-5c29-4cc3-a83c-63a31cd0c767/2020napawinegrape.pdf
