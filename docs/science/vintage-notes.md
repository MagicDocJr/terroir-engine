# Real vintage notes (for the Mentor and staff)

Short, cited notes on notable vintages from 1990 to 2025. The Mentor and advisors use them as **"real vintage notes"** (spec §3.4), and Tasting practice shows them in reveals and the Cellar book. The sourced rows are mirrored in `data/vintage_notes.json` (keep the two in step).

**No-future-knowledge rule (ADR 0002, spec §5.4):**
- A note may only be shown **after that vintage's harvest has happened on the Timeline**, e.g. as the Mentor looking back ("In 2003 we picked in August…"), or at the start of the next year.
- It must **never** be used to predict the current year. The notes describe what happened; the simulation is driven by the weather data, not by these notes.
- If the simulated outcome of a Historical-weather year differs from the note, that's a **calibration signal** (see the calibration table, another milestone-1 file), not an error to hide.

Format: **year: what happened** [source]. A note marked `UNVERIFIED` must not be shown to the player until it has a source.

---

## Mosel

| Year | Note | Source |
|---|---|---|
| 2003 | Heatwave summer; very ripe, concentrated grapes. Clean, raisined berries allowed many estates on the Mosel, Saar and Ruwer to make highly concentrated Beerenauslese and TBA. Heavy, intense, rich wines. | [RIESLING-2003] |
| 2010 | Very small crop, 30–50 % below normal (~40 hL/ha at Prädikat estates), with very high acidity. Deacidification was widespread (double-salt deacidification, or MLF). Dense wines thanks to the low yields. | [WEINKENNER-2010], [NIKOS-2010] |
| 2018 | Very hot, dry summer that almost entirely prevented oidium and downy mildew. September rain without rot, thanks to cool nights, raised juice yield and gave a large crop. Mosel Riesling averaged ~85 °Oe in late-harvest ranges. Rich aromas, moderate acidity. | [DWI-2018] |
| 2021 | Cool and wet; downy mildew was hard to control, with waterlogged soils making spraying difficult. South-facing top sites on the Mosel did particularly well in this cooler year. Good sites reached ~95 °Oe; most of the harvest was 70–90 °Oe. | [DWI-2021 via FALSTAFF] |
| 1990, 2005, 2006, 2011, 2017, 2019 | `UNVERIFIED`. Candidates for notes (1990 classic; 2006 rot pressure; 2017 April frost). Source them before use. | — |

## Côte d'Or (Burgundy)

| Year | Note | Source |
|---|---|---|
| 2003 | Heatwave vintage: the record-early harvest started around 20 August. Rich, opulent wines. | [LETROIS] (secondary); `UNVERIFIED` exact start date |
| 2016 | Catastrophic frost on the nights of **26–27 April**, the worst in the Côte d'Or since 1985. Unlike 1985 it also hit higher slopes. Heavy losses, e.g. a famous Gevrey domaine lost two-thirds of its crop. | [DECANTER-2016], [COATES-2016] |
| 2021 | Temperatures plunged on 5 April, then **three nights of hard frost from 6 to 9 April**. Côte de Beaune whites were hit hardest, with losses around 80 % reported. Nationally it was France's worst agricultural frost disaster since at least 1947. | [INSIDEBURGUNDY-2021], [EURONEWS-2021] |
| 1990, 2005, 2010, 2015, 2019, 2020 | `UNVERIFIED`. Candidates (2019 and 2020 heat and early harvests; 2005 and 2010 classics). Source them before use. | — |

## Napa Valley

| Year | Note | Source |
|---|---|---|
| 2011 | Unusual rain until mid-June delayed bloom and disrupted fruit set (shatter in places). A cool, Bordeaux-like vintage. | [NVV-2011] |
| 2014 | **South Napa earthquake, M6.0, 24 August 2014, 3:20 a.m.** Stacked barrels (over a quarter-ton each) toppled in many wineries; an estimated 5,000–6,000 barrels of wine were lost. | [USGS-2014], [PEER-2014] |
| 2017 | Warm to hot season with extreme heat around Labor Day (up to ~120 °F reported), so picking came slightly early. Most fruit was in before the **wildfires started on 8 October**. Later lots were monitored for smoke taint. | [NVR-2017] |
| 2020 | **Glass Fire:** fully contained 20 October 2020, after burning more than 67,000 acres and destroying 1,555 structures in Napa County. Smoke taint was a defining factor for late-harvested fruit. The start date (late September) is `UNVERIFIED`. | [WIKI-GLASSFIRE] |
| 2022 | **Labor Day heat wave:** five days of triple-digit heat in early September, followed by mid-September rain. Many varieties ripened at once, compressing the harvest; strict selection was needed. | [WINEINSTITUTE-2022], [NVV-2022] |
| 1990, 1997, 2013, 2019 | `UNVERIFIED`. Candidates (widely rated great years). Source them before use. | — |

---

## What growers did (famous-vintage debriefs)

Shown in the famous-vintage debriefs (`data/scenarios.json`). Paraphrased; every line has its source.

**Côte d'Or 2016**
- Candles lit in some famous parcels did not stop the April frost. [DECANTER-2016]
- With half the crop already lost, many organic and biodynamic growers sprayed against mildew rather than risk the rest. [DECANTER-2016]
- Several top Montrachet owners pooled their tiny crops to fill about two barrels. [DECANTER-2016]
- A fine late summer brought picking forward. Most Côte de Beaune producers picked reds first; some picked whites first as
  their acidity fell. [INSIDEBURGUNDY-2016]
- Several producers picked and chaptalised a little to keep the acid balance, rather than wait for sugar and have to
  acidify. [INSIDEBURGUNDY-2016]
- Reds came out concentrated with a fresh finish; whites fine-boned, with some dilution in Puligny. [INSIDEBURGUNDY-2016]
- **Numbers.**
  - Harvest from about 14–15 September (early pickers) to 27 September (Côte de Nuits). [INSIDEBURGUNDY-2016]
  - Potential alcohol 12.5–13 % at one Gevrey estate. [DECANTER-2016]
  - Crop losses of about a third to a half in many villages (Chambolle −39 %, Musigny −55 %), while Morey made more
    than in 2015. [INSIDEBURGUNDY-2016]

**Mosel 2018**
- The grapes were so healthy that sorting took little effort; shrivelled berries were still picked out for the sweetest
  wines. [MOSELWEIN-2018]
- Some growers watered young vines to keep them alive; deep-rooted old vines coped. [MOSELWEIN-2018]
- Most estates began picking Riesling by mid-September, their earliest ever. [MFW-2018]
- Most wines were ripe and soft with mild acidity, many Kabinett and Spätlese of Auslese weight; a few top growers made
  racy, elegant wines. [MFW-2018]
- **Numbers.** Riesling averaged about 85 °Oe. Most varieties reached the legal maximum yield, the largest Mosel crop since
  2002. [MOSELWEIN-2018]

**Napa Valley 2011**
- Growers opened their canopies for sun, warmth and air around the clusters. [NVV-2011]
- Every pick was a choice between harvesting safely and waiting for more sugar at the risk of more botrytis. [NVV-2011]
- Sorting in the field and at the wineries meant botrytis cut quantity rather than quality; one estate made a separate pass
  to remove it before picking. [NVV-2011]
- Flavours developed at lower sugar than usual, giving lower-alcohol wines; some estates picked early to catch fresh fruit.
  [NVV-2011]
- **Numbers.** Cabernet decisions around 23 °Brix; many estates finished in mid to late October, some in early November;
  some sites lost more than 30 % of the crop to shatter. [NVV-2011]

## Sources
- [RIESLING-2003] riesling.de, "Jahrgang 2003: völlig überschätzt …" (secondary): https://www.riesling.de/de/news/wein/jahrgang-2003-vollig-uberschatzt-/6_293.html
- [WEINKENNER-2010] weinkenner.de, "Problematischer 2010er Jahrgang – Entsäuern auf breiter Front": https://www.weinkenner.de/problematischer-2010er-jahrgang-entsaeuern-auf-breiter-front/
- [NIKOS-2010] Gourmetwelten, "Wein – der Jahrgang 2010 im VDP": https://www.nikos-weinwelten.de/beitrag/wein_der_jahrgang_2010_im_vdp/
- [DWI-2018] Deutsches Weininstitut, "Der Weinjahrgang 2018 in den Anbaugebieten": https://www.deutscheweine.de/aktuelles/meldungen/details/news/detail/News/der-weinjahrgang-2018-in-den-anbaugebieten/
- [DWI-2021 via FALSTAFF] Falstaff, "Fazit: So war der Weinjahrgang 2021 in den deutschen Anbaugebieten" (reporting DWI): https://www.falstaff.com/de/news/fazit-so-war-der-weinjahrgang-2021-in-den-deutschen-anbaugebieten
- [LETROIS] Le Trois, "Vendanges 'historiquement précoces' en Bourgogne" (secondary): https://letrois.info/economie-social/vendanges-historiquement-precoces-en-bourgogne/
- [DECANTER-2016] Decanter, "Burgundy 2016 harvest report: Who survived nature's wrath": https://www.decanter.com/wine/wine-regions/burgundy-wine/burgundy-2016-harvest-report-337451/
- [COATES-2016] Clive Coates MW, "2016 Vintage": http://www.clive-coates.com/news/2016-vintage
- [INSIDEBURGUNDY-2021] Jasper Morris, Inside Burgundy, "2021 in Burgundy: An Introduction to the 2021 Vintage": https://insideburgundy.com/overview/2021-in-burgundy-an-introduction-to-the-2021-vintage/
- [EURONEWS-2021] Euronews (24 Sep 2021), Burgundy harvest report: https://www.euronews.com/2021/09/24/burgundy-harvest-confirms-millesimus-horribilis-as-winemakers-say-there-really-isn-t-much-
- [NVV-2011] Napa Valley Vintners, "Report on Harvest 2011" (verified 2026-09-29 via its indexed text; the PDF itself no longer loads): https://napavintners.com/downloads/2011-Napa-Valley-Harvest-Report.pdf
- [NVR-2017] Napa Valley Register, "Promising Napa Valley vintage turns tragic as fires continue" (verified 2026-09-29; heat around Labor Day, about 90 % of the tonnage in by 8 October): https://napavalleyregister.com/community/star/news/local/promising-napa-valley-vintage-turns-tragic-as-fires-continue/article_a12dd97c-ce58-511f-a2c1-82358fbf1624.html
- [USGS-2014] USGS, "M6.0 South Napa, California Earthquake – August 24, 2014": https://www.usgs.gov/programs/earthquake-hazards/science/m60-south-napa-california-earthquake-august-24-2014
- [PEER-2014] PEER, South Napa earthquake reconnaissance report (barrel losses): https://peer.berkeley.edu/sites/default/files/spa-2014-napa-report.pdf
- [WIKI-GLASSFIRE] "Glass Fire", Wikipedia: https://en.wikipedia.org/wiki/Glass_Fire
- [WINEINSTITUTE-2022] Wine Institute, "Californian Vintners Report High Quality for 2022 Harvest": https://wineinstitute.org/press-releases/californian-vintners-report-high-quality-for-2022-harvest/
- [NVV-2022] Napa Valley Vintners, "Napa Valley's 2022 Harvest — the Tale of Two Harvests": https://napavintners.com/press/press_release_detail.asp?ID_News=3624475
- [INSIDEBURGUNDY-2016] Jasper Morris, Inside Burgundy, "2016 Vintage Overview": https://insideburgundy.com/overview/2016-vintage-overview/
- [MOSELWEIN-2018] Moselwein e.V. / Weinland Mosel, "Moselwinzer freuen sich über Bilderbuch-Trauben" (22 Oct 2018): https://www.weinland-mosel.de/de/aktuelles/show/moselwinzer-freuen-sich-ueber-bilderbuch-trauben
- [MFW-2018] Jean Fisch, Mosel Fine Wines, "2018 Mosel Vintage | Kissed by the Sun": https://www.moselfinewines.com/2018-mosel-vintage-kissed-by-the-sun.php
- Archive copies (the original pages now return 404): [DWI-2018] http://web.archive.org/web/20230927121822/https://www.deutscheweine.de/aktuelles/meldungen/details/news/detail/News/der-weinjahrgang-2018-in-den-anbaugebieten/ ; [NVV-2011] http://web.archive.org/web/20220709070815/https://napavintners.com/downloads/2011-Napa-Valley-Harvest-Report.pdf
