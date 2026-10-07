# The Winery look (docs/superpowers/specs/2026-09-29-cozy-winery-design.md §2; the Shop, 2026-10-07-equipment-shop-design.md):
# what can be shown, the options and each Region's look from before the Shop. The Shop's prices and what a game owns come from
# the sim (data/shop.json, snapshot "shop"); this list mirrors that catalogue (the winerylook harness checks they
# match) for the 3D winery (winery.gd apply_style).
# Cosmetic only: the simulation stores the choices (`decor <key> <value>`) and never reads them. No facts are attached;
# the blurbs describe the look.
extends RefCounted

const ELEMENTS := [
	{"key": "walls", "label": "Interior walls", "options": [
		{"value": "render", "label": "Plain render", "blurb": "Grey rendered walls: the working hall as built."},
		{"value": "paint-whitewash", "label": "Whitewash", "blurb": "A fresh coat of whitewash over the render: bright and clean."},
		{"value": "paint-cream", "label": "Cream", "blurb": "Warm cream paint: soft light on the tanks."},
		{"value": "paint-ochre", "label": "Ochre", "blurb": "Earthy ochre, like old southern farmhouses."},
		{"value": "paint-sage", "label": "Sage green", "blurb": "Muted sage green: calm and countryside."},
		{"value": "paint-burgundy", "label": "Burgundy red", "blurb": "Deep wine red on the walls."},
		{"value": "brick", "label": "Whitewashed brick", "blurb": "Brick under a coat of whitewash: bright and rustic."},
		{"value": "limestone", "label": "Limestone", "blurb": "Pale dressed limestone blocks."},
		{"value": "slate", "label": "Slate stone", "blurb": "Dark split slate, laid dry-stone style."},
		{"value": "redwood", "label": "Redwood boards", "blurb": "Warm vertical timber boards."}]},
	{"key": "floor", "label": "Floor", "options": [
		{"value": "concrete", "label": "Concrete", "blurb": "Polished concrete: easy to hose down."},
		{"value": "terracotta", "label": "Terracotta", "blurb": "Warm terracotta tiles."},
		{"value": "herringbone", "label": "Herringbone brick", "blurb": "Brick pavers laid in herringbone."},
		{"value": "stone", "label": "Stone flags", "blurb": "Worn stone flags, as in an old cuverie."},
		{"value": "slate", "label": "Slate flags", "blurb": "Dark slate slabs."}]},
	{"key": "ceiling", "label": "Ceiling", "options": [
		{"value": "steel", "label": "Steel trusses", "blurb": "The steel roof trusses of the working hall."},
		{"value": "oak", "label": "Oak beams", "blurb": "Dark oak beams and a timber ceiling."}]},
	{"key": "lights", "label": "Lights", "options": [
		{"value": "workshop", "label": "Workshop", "blurb": "Bright, neutral working light."},
		{"value": "warm", "label": "Warm pendants", "blurb": "The same pendants with warm bulbs."},
		{"value": "chandelier", "label": "Chandeliers", "blurb": "Iron lantern chandeliers over the aisle."}]},
	{"key": "corner", "label": "Tasting corner", "options": [
		{"value": "none", "label": "None", "blurb": "The corner stays free for crates."},
		{"value": "table", "label": "Tasting table", "blurb": "A wooden table and chairs, bottles and a barrel side table."},
		{"value": "lounge", "label": "Lounge", "blurb": "A sofa, armchairs and a coffee table on a rug."}]},
	{"key": "plants", "label": "Plants", "options": [
		{"value": "off", "label": "None", "blurb": "No plants."},
		{"value": "on", "label": "Plants", "blurb": "Potted plants by the door and the corner; planter boxes outside."}]},
	{"key": "cellar", "label": "Cellar", "options": [
		{"value": "off", "label": "Plain", "blurb": "The cellar's own lamps only."},
		{"value": "on", "label": "Candlelit", "blurb": "Candles and lanterns along the barrel racks, a shelf of bottles at the end."}]},
	{"key": "facade", "label": "Facade", "options": [
		{"value": "region", "label": "The Region's render", "blurb": "The building as it was built, in the local render."},
		{"value": "paint-white", "label": "White paint", "blurb": "Crisp white walls in the sun."},
		{"value": "paint-cream", "label": "Cream paint", "blurb": "Soft cream walls."},
		{"value": "paint-ochre", "label": "Ochre paint", "blurb": "Warm ochre walls."},
		{"value": "paint-sage", "label": "Sage paint", "blurb": "Sage green walls."},
		{"value": "paint-grey", "label": "Slate-grey paint", "blurb": "Dark grey walls, modern and calm."},
		{"value": "timber", "label": "Timber cladding", "blurb": "Larch boards over the walls, weathering to silver."},
		{"value": "shingle", "label": "Slate shingles", "blurb": "Hand-cut slate shingles, as on old Mosel houses."},
		{"value": "ashlar", "label": "Limestone ashlar", "blurb": "Dressed limestone blocks, like a Burgundy cuverie."}]},
	{"key": "shutters", "label": "Shutters and doors", "options": [
		{"value": "none", "label": "Plain", "blurb": "Plain doors, no shutters."},
		{"value": "green", "label": "Green", "blurb": "Shutters and doors painted bottle green."},
		{"value": "blue", "label": "Blue", "blurb": "Shutters and doors painted French blue."},
		{"value": "oxblood", "label": "Oxblood", "blurb": "Shutters and doors painted oxblood red."},
		{"value": "oak", "label": "Natural oak", "blurb": "Oiled oak shutters and doors."}]},
	{"key": "outside", "label": "Yard", "options": [
		{"value": "off", "label": "Plain", "blurb": "The yard as it is."},
		{"value": "on", "label": "Cozy yard", "blurb": "A bench, lanterns by the doors and a warm glow in the windows."}]},
	{"key": "stringlights", "label": "String lights", "options": [
		{"value": "off", "label": "None", "blurb": "No string lights."},
		{"value": "on", "label": "String lights", "blurb": "Warm bulbs strung over the yard."}]},
	{"key": "sign", "label": "Estate sign", "options": [
		{"value": "off", "label": "Painted board", "blurb": "The Estate's name painted on a plain board over the door."},
		{"value": "on", "label": "Gilded, lit sign", "blurb": "Gold-leaf letters and two lamps over the door that light the name after dark."}]},
]

const DEFAULTS := {
	"mosel": {"walls": "slate", "floor": "slate", "ceiling": "oak", "lights": "warm", "corner": "table", "plants": "on", "outside": "on", "cellar": "on", "facade": "region", "shutters": "none", "stringlights": "off", "sign": "off"},
	"cote-dor": {"walls": "limestone", "floor": "stone", "ceiling": "oak", "lights": "chandelier", "corner": "table", "plants": "on", "outside": "on", "cellar": "on", "facade": "region", "shutters": "none", "stringlights": "off", "sign": "off"},
	"napa": {"walls": "redwood", "floor": "terracotta", "ceiling": "oak", "lights": "warm", "corner": "lounge", "plants": "on", "outside": "on", "cellar": "on", "facade": "region", "shutters": "none", "stringlights": "off", "sign": "off"},
}

## The look before the Winery was made cosy (the "plain" set every Region falls back to for unknown Regions).
const PLAIN := {"walls": "render", "floor": "concrete", "ceiling": "steel", "lights": "workshop", "corner": "none", "plants": "off", "outside": "off", "cellar": "off", "facade": "region", "shutters": "none", "stringlights": "off", "sign": "off"}


## The Region's default look with the player's choices on top. Keys or values this build doesn't know (an older or
## newer save) are ignored.
static func resolve(region: String, decor: Dictionary) -> Dictionary:
	var out: Dictionary = (DEFAULTS.get(region, PLAIN) as Dictionary).duplicate()
	for e in ELEMENTS:
		var k: String = e["key"]
		if decor.has(k) and _known(e, String(decor[k])):
			out[k] = String(decor[k])
	return out


static func defaults(region: String) -> Dictionary:
	return (DEFAULTS.get(region, PLAIN) as Dictionary).duplicate()


static func _known(e: Dictionary, value: String) -> bool:
	for o in e["options"]:
		if String(o["value"]) == value:
			return true
	return false


static func option(key: String, value: String) -> Dictionary:
	for e in ELEMENTS:
		if e["key"] == key:
			for o in e["options"]:
				if String(o["value"]) == value:
					return o
	return {}
