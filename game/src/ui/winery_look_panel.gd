# "Your winery" panel on the Winery screen (the Shop spec §3): the looks you own, one row per element, switched freely
# (`decor <key> <value>`, stored and replayed, never read by the simulation), with "Visit the Shop" for more and "See it in
# 3D". What is owned and in use comes from the snapshot's "shop" (the sim decides).
extends RefCounted

const UI := preload("res://src/ui/ui.gd")

static func build(D: Dictionary, shell) -> Control:
	var shop: Dictionary = D.get("shop", {})
	var p: Array = UI.panel("Your winery", "Cosmetic: no effect on the wine · more in the Shop", 8)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	p[1].add_child(grid)
	var for_sale := 0
	for sec in shop.get("look", []):
		var key := String(sec["key"])
		var labels := []
		var by_label := {}
		var chosen := ""
		var chosen_blurb := ""
		for o in sec["options"]:
			if not bool(o["owned"]):
				for_sale += 1
				continue
			labels.append(String(o["label"]))
			by_label[String(o["label"])] = String(o["value"])
			if bool(o["inUse"]):
				chosen = String(o["label"]); chosen_blurb = String(o["blurb"])
		var name_l := UI.label(String(sec["label"]), 15, UI.INK2)
		name_l.custom_minimum_size = Vector2(150, 0)
		grid.add_child(name_l)
		if labels.size() > 1:
			grid.add_child(UI.segmented(labels, chosen, func(x):
				shell.command("decor", key, String(by_label[x]))
				shell.notify("Your winery · %s: %s." % [sec["label"], x], true)))
		else:
			grid.add_child(UI.label(chosen, 15, UI.INK))
		grid.add_child(UI.label(chosen_blurb, 13, UI.MUTED))
	var row := UI.hbox(10)
	var shopb := UI.button("Visit the Shop" + (" (%d looks for sale)" % for_sale if for_sale > 0 else ""), true, 14)
	shopb.pressed.connect(func(): shell.show_screen("shop"))
	row.add_child(shopb)
	var walk := UI.button("See it in 3D", false, 14)
	walk.pressed.connect(func(): shell.toggle_3d("hall"))
	row.add_child(walk)
	p[1].add_child(row)
	return p[0]
