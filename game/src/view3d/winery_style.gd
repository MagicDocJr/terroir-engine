# The Winery look (docs/superpowers/specs/2026-09-29-cozy-winery-design.md §2): what the player can change, the options and
# each Region's default. Shared by the Winery screen's "Winery look" panel and the 3D winery (winery.gd apply_style).
# Cosmetic only: the simulation stores the choices (`decor <key> <value>`) and never reads them. No facts are attached;
# the blurbs describe the look.
extends RefCounted

const ELEMENTS := [
	{"key": "walls", "label": "Walls", "options": [
		{"value": "render", "label": "Plain render", "blurb": "Grey rendered walls: the working hall as built."},
		{"value": "slate", "label": "Slate stone", "blurb": "Dark split slate, laid dry-stone style."},
		{"value": "limestone", "label": "Limestone", "blurb": "Pale dressed limestone blocks."},
		{"value": "brick", "label": "Whitewashed brick", "blurb": "Brick under a coat of whitewash: bright and rustic."},
		{"value": "redwood", "label": "Redwood boards", "blurb": "Warm vertical timber boards."}]},
	{"key": "floor", "label": "Floor", "options": [
		{"value": "concrete", "label": "Concrete", "blurb": "Polished concrete: easy to hose down."},
		{"value": "stone", "label": "Stone flags", "blurb": "Worn stone flags, as in an old cuverie."},
		{"value": "slate", "label": "Slate flags", "blurb": "Dark slate slabs."},
		{"value": "terracotta", "label": "Terracotta", "blurb": "Warm terracotta tiles."},
		{"value": "herringbone", "label": "Herringbone brick", "blurb": "Brick pavers laid in herringbone."}]},
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
		{"value": "off", "label": "Off", "blurb": "No plants."},
		{"value": "on", "label": "On", "blurb": "Potted plants by the door and the corner; planter boxes outside."}]},
	{"key": "outside", "label": "Outside", "options": [
		{"value": "off", "label": "Plain", "blurb": "The yard as it is."},
		{"value": "on", "label": "Cosy", "blurb": "A bench, lanterns by the doors and a warm glow in the windows."}]},
	{"key": "cellar", "label": "Cellar", "options": [
		{"value": "off", "label": "Plain", "blurb": "The cellar's own lamps only."},
		{"value": "on", "label": "Candlelit", "blurb": "Candles and lanterns along the barrel racks."}]},
]

const DEFAULTS := {
	"mosel": {"walls": "slate", "floor": "slate", "ceiling": "oak", "lights": "warm", "corner": "table", "plants": "on", "outside": "on", "cellar": "on"},
	"cote-dor": {"walls": "limestone", "floor": "stone", "ceiling": "oak", "lights": "chandelier", "corner": "table", "plants": "on", "outside": "on", "cellar": "on"},
	"napa": {"walls": "redwood", "floor": "terracotta", "ceiling": "oak", "lights": "warm", "corner": "lounge", "plants": "on", "outside": "on", "cellar": "on"},
}

## The look before the Winery was made cosy (the "plain" set every Region falls back to for unknown Regions).
const PLAIN := {"walls": "render", "floor": "concrete", "ceiling": "steel", "lights": "workshop", "corner": "none", "plants": "off", "outside": "off", "cellar": "off"}


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
