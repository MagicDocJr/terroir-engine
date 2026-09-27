# What every number in the game means: name, unit, what it measures, the usual range and what's good or bad.
# Used for tooltips on table headers, tiles and charts. Ranges follow docs/science (ripening.md, acid-ph-so2.md, disease.md,
# fermentation.md, soil-and-water.md, weather-and-climate.md); display text only, nothing is computed here.
extends RefCounted

const M := {
	"oe": ["Must weight (°Oe, Oechsle)", "How dense the grape juice is, which is mostly sugar. °Oe = (density − 1) × 1000.", "At harvest: Kabinett ≥ 73, Spätlese ≥ 80, Auslese ≥ 88 (Mosel Riesling). 85 °Oe ≈ 20.5 °Brix ≈ 11.5 % potential alcohol."],
	"brix": ["Sugar (°Brix)", "Grams of dissolved sugar per 100 g of juice, as measured by a refractometer.", "Picking targets: Burgundy 21–23.5, Napa Cabernet 24–27. 1 °Brix ≈ 0.55–0.6 % alcohol once fermented dry."],
	"pa": ["Potential alcohol (% vol)", "The alcohol the juice would give if all its sugar fermented (EU rule: 16.83 g/L sugar per 1 % vol).", "Light wines 9–11 %, most dry wines 12–14 %, above 14.5 % tastes warm unless the wine has the body to carry it."],
	"ta": ["Titratable acidity (g/L, as tartaric)", "The total acid you can taste: mostly tartaric plus malic acid.", "Harvest: Mosel 8–11, Burgundy 5.5–8.5, Napa 5–7. Higher tastes fresher and sharper; very low tastes flat."],
	"ph": ["pH", "How strong the acidity is (lower = more acidic). It is not the same as TA: potassium in the juice raises pH.", "Musts 2.9–3.9. Low pH keeps wine fresh, stable and protected by SO₂; above ~3.7 wines spoil more easily."],
	"malic": ["Malic acid (g/L)", "The sharp, green-apple acid. The grape burns it off as it ripens, faster in warm weather.", "Harvest 1.5–6 g/L. Malolactic fermentation later turns it into softer lactic acid."],
	"yan": ["Yeast-available nitrogen, YAN (mg N/L)", "The nitrogen yeast need to grow and finish fermenting.", "Below about 140–150 mg/L fermentations turn sluggish and can smell of rotten egg (H₂S). Your Cellar master can add DAP (a yeast nutrient)."],
	"seeds": ["Seed ripeness (%)", "How far the pips have turned from green to brown. Green seeds give harsh, bitter tannin in red wines.", "Reds are best picked with seeds ≥ ~70 % brown."],
	"anth": ["Colour (anthocyanins, mg/g berry)", "The red pigment in the skins.", "Pinot Noir is naturally low (< 0.7), Cabernet high (> 1). Heat above ~35 °C destroys colour."],
	"ibmp": ["Pyrazine, IBMP (ng/L)", "The green-pepper aroma of Cabernet. Sunlight and warmth break it down as grapes ripen.", "Tasters notice it from a few ng/L; below ~5 ng/L it is rarely obvious."],
	"grey": ["Grey rot (%)", "Share of bunches with Botrytis grey rot: it brings mouldy, earthy off-flavours and oxidation.", "Above ~5 % in the press is a problem; sorting removes most of it."],
	"noble": ["Noble rot (%)", "The same fungus in dry weather: it shrivels berries and concentrates sugar and acid.", "Needed for Beerenauslese and Trockenbeerenauslese; useless for dry wines."],
	"downy": ["Downy mildew risk today (0–100)", "How favourable today's weather is for infection: rain, wet leaves and warmth, discounted by your spray cover.", "Below 20 low, 20–35 watch, above 35 serious: spray before the next rain."],
	"powdery": ["Powdery mildew risk index (0–100)", "A UC Davis-style index: it rises on warm days (21–30 °C) and falls in heat or cold. Rain isn't needed.", "0–30 low (long spray intervals), 40–50 moderate, 60–100 high: shorten spray intervals."],
	"botrytis": ["Botrytis risk today (0–100)", "How favourable today is for grey rot: hours of wet bunches at 15–25 °C, worse in dense canopies and ripe, split berries.", "Rises sharply after véraison; above 35 is serious close to harvest."],
	"health": ["Canopy health (%)", "The share of the leaf canopy still working: leaf disease, rot, chlorosis and frost reduce it.", "Above 85 % is healthy. Low health slows ripening."],
	"water": ["Vine water stress, Ψstem (MPa)", "Midday stem water potential: how hard the vine has to pull water. More negative = more stress.", "Above −0.6 none, −0.6 to −0.9 weak (good for quality), −0.9 to −1.1 weak–moderate, −1.1 to −1.4 moderate–severe, below −1.4 severe (ripening stalls)."],
	"soilwater": ["Soil water (% of available)", "How full the soil's plant-available water reserve is.", "Below ~40 % the vine starts to feel drought."],
	"crop": ["Crop on the vine (kg)", "The estimated weight of grapes on this Block now.", "Changes with frost, fruit set, disease, green harvest and berry growth."],
	"yield": ["Yield (kg per hectare)", "Crop per hectare. 1,000 kg/ha makes roughly 6–7 hL of wine.", "Côte d'Or 5–7 t/ha, Mosel steep 6–10, Napa 7–11. Legal limits apply in the Côte d'Or."],
	"lai": ["Leaf area index", "Square metres of leaf per square metre of ground.", "1.5–3 is typical for a trained vineyard."],
	"exposure": ["Fruit exposure (0–1)", "How much sun reaches the bunches (leaf removal and canopy management raise it).", "Around 0.4–0.6 is balanced; high exposure means drier bunches and more colour but sunburn risk."],
	"sugar": ["Sugar left (g/L)", "Sugar still in the fermenting wine or the finished wine.", "Below 4 g/L tastes dry; 15–35 off-dry to medium; above 45 sweet."],
	"alcohol": ["Alcohol (% vol)", "Alcohol produced so far.", "Yeast struggle above ~15–16 %."],
	"temp": ["Tank temperature (°C)", "Fermentation makes heat; cooling holds the set point.", "Whites 14–18 °C keep fruity esters; reds 22–30 °C extract colour; above ~32 °C yeast die."],
	"freeSo2": ["Free SO₂ (mg/L)", "The sulphur dioxide not yet bound; it protects against oxygen and microbes.", "What matters is molecular SO₂: about 0.8 mg/L for whites and 0.5 for reds."],
	"molSo2": ["Molecular SO₂ (mg/L)", "The active, protective part of free SO₂. It falls steeply as pH rises.", "0.5–0.8 mg/L protects; below ~0.4 Brettanomyces and bacteria can grow."],
	"va": ["Volatile acidity (g/L)", "Acetic acid (vinegar) from bacteria or stressed yeast.", "Below 0.6 unnoticed; 0.7–1.0 a lift; EU legal maximum 1.08 (whites) and 1.20 (reds)."],
	"tannin": ["Tannin (mg/L)", "Astringent compounds from skins, seeds, stems and oak.", "Pinot Noir 300–700, Cabernet 700–1,500+. Seed tannin from green seeds tastes coarse."],
	"colour": ["Colour (anthocyanins, mg/L)", "Red pigment extracted into the wine.", "Pinot Noir 100–300, Cabernet 400–900."],
	"winkler": ["Winkler index (degree-days)", "Sum of daily mean temperature above 10 °C from 1 April to 31 October.", "Region I < 1,390 (cool), II 1,390–1,667, III 1,667–1,944, IV and V warmer."],
	"huglin": ["Huglin index", "Daytime heat above 10 °C, 1 April–30 September, weighted by day length.", "Riesling needs about 1,500–1,800; Cabernet Sauvignon about 1,900–2,000."],
	"frostLoss": ["Frost damage (% of shoots)", "Young shoots killed by spring frost. Secondary buds push again but carry far less fruit.", "Anything above a few per cent costs crop."],
	"sunburn": ["Sunburn (% of berries)", "Berries scorched by sun and heat (brown, shrivelled, bitter).", "Rises with afternoon-side leaf removal before a heatwave."],
	"chlorosis": ["Lime chlorosis (%)", "Yellow leaves from iron shortage on limy soil with an unsuited rootstock.", "Anything above 20 % hurts vigour and ripening."],
	"protection": ["Spray cover (%)", "How much protection the last spray still gives. Rain washes it off; new leaves are unprotected.", "Below ~40 % infections get through on risky days."],
	"berries": ["Berries per vine", "Set at flowering (fruit set) and after green harvest.", ""],
	"berryWeight": ["Berry weight (g)", "Grows until véraison, then swells with sugar and later shrinks as berries dehydrate.", "Riesling ~1.3–1.6 g, Cabernet ~1.0–1.2 g."],
}

static func tip(key: String) -> String:
	if not M.has(key): return ""
	var m: Array = M[key]
	return "%s\n%s%s" % [m[0], m[1], ("\nRange: " + m[2]) if m[2] != "" else ""]

## A tooltip for a shown value, with its reading added (e.g. "Powdery 80 → high").
static func value_tip(key: String, value: float) -> String:
	var t := tip(key)
	var reading := ""
	match key:
		"downy", "botrytis": reading = "low" if value < 20 else ("watch" if value < 35 else "serious")
		"powdery": reading = "low" if value < 35 else ("moderate" if value < 60 else "high")
		"water": reading = "no stress" if value > -0.6 else ("weak" if value > -0.9 else ("weak–moderate" if value > -1.1 else ("moderate–severe" if value > -1.4 else "severe")))
	if reading != "": t = "%s now: %s → %s\n\n%s" % [M[key][0].get_slice(" (", 0), str(snappedf(value, 0.01)), reading, t]
	return t
