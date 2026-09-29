# "Winery look" panel on the Winery screen (cozy-winery design §3): one row per element with its options (★ = the
# Region's default), the chosen option's blurb, "Reset to the regional look" and "See it in 3D". Choices go to the
# sim as `decor <key> <value>` (stored and replayed, never read by the simulation) and show in the 3D winery.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const Style := preload("res://src/view3d/winery_style.gd")

static func build(D: Dictionary, shell) -> Control:
	var region := String(D.get("region", {}).get("id", ""))
	var look := Style.resolve(region, D.get("decor", {}))
	var defaults := Style.defaults(region)
	var p: Array = UI.panel("Winery look", "Cosmetic: no effect on the wine or the accounts · ★ the Region's usual look", 8)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	p[1].add_child(grid)
	for e in Style.ELEMENTS:
		var key: String = e["key"]
		var labels := []
		var by_label := {}
		var chosen := ""
		for o in e["options"]:
			var lab := String(o["label"]) + (" ★" if String(o["value"]) == String(defaults.get(key, "")) else "")
			labels.append(lab)
			by_label[lab] = String(o["value"])
			if String(o["value"]) == String(look.get(key, "")): chosen = lab
		var name_l := UI.label(String(e["label"]), 15, UI.INK2)
		name_l.custom_minimum_size = Vector2(130, 0)
		grid.add_child(name_l)
		var seg := UI.segmented(labels, chosen, func(x):
			Sim.Command("decor", key, String(by_label[x]), "", "", "")
			shell.refresh()
			shell.notify("Winery look · %s: %s." % [e["label"], String(x).trim_suffix(" ★")], true))
		grid.add_child(seg)
		var blurb := UI.label(String(Style.option(key, String(look.get(key, ""))).get("blurb", "")), 13, UI.MUTED)
		grid.add_child(blurb)
	var row := UI.hbox(10)
	var reset := UI.button("Reset to the regional look", false, 14)
	reset.disabled = look == defaults
	reset.pressed.connect(func():
		for k in defaults: Sim.Command("decor", k, "", "", "", "")     # "" = follow the Region's default (resolve ignores it)
		shell.refresh()
		shell.notify("Winery look: back to the Region's usual look.", true))
	row.add_child(reset)
	var walk := UI.button("See it in 3D", true, 14)
	walk.pressed.connect(func(): shell.toggle_3d("hall"))
	row.add_child(walk)
	p[1].add_child(row)
	return p[0]
