# Plot & Blocks: the Block table, and for the selected Block its soil, vine state, per-Block choices and harvest order.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const Metrics := preload("res://src/ui/metrics.gd")
const Charts := preload("res://src/ui/charts.gd")
const TasksPanel := preload("res://src/ui/tasks_panel.gd")

static func build(D: Dictionary, shell) -> Control:
	var blocks: Array = D["blocks"]
	var napa: bool = D["region"]["units"] == "brix"
	var sel_id: String = shell.state.get("plot_sel", blocks[0]["id"])
	var B: Dictionary = blocks[0]
	for b in blocks:
		if b["id"] == sel_id: B = b
	var P: Dictionary = D["plot"]
	var v := UI.vbox(16)
	var b3 := UI.button("Walk the vineyard in 3D"); b3.pressed.connect(func(): shell.toggle_3d("vineyard"))
	v.add_child(UI.page_header("Plot & Blocks", "%s · %.1f ha · %s · %d %% slope facing %s · %d m" % [P["name"], float(P["ha"]), P["classification"], int(P["slope"]), P["aspect"], int(P["elevation"])], [b3]))
	var task_strip = TasksPanel.build(D, shell, "vineyard")
	if task_strip: v.add_child(task_strip)
	# overview: the Plot model with what's planted where, and the Planting per Block
	v.add_child(_overview(D, shell))
	# table
	var tp: Array = UI.panel("", "", 2)
	var cols := ["Block", "Variety", "Stage", "Health", "Water", "Downy", "Powdery", "Botrytis", "Crop est.", "Must", "Yield"]
	var widths := [220, 240, 130, 90, 190, 84, 90, 90, 120, 180, 130]
	var tips := {"Health": Metrics.tip("health"), "Water": Metrics.tip("water"), "Downy": Metrics.tip("downy"), "Powdery": Metrics.tip("powdery"), "Botrytis": Metrics.tip("botrytis"),
		"Crop est.": Metrics.tip("crop"), "Must": "Latest must analysis (after véraison): sugar and titratable acidity.\n\n" + Metrics.tip("brix" if napa else "oe"), "Yield": Metrics.tip("yield")}
	var hdr := UI.hbox(2)
	for i in cols.size(): hdr.add_child(UI.table_cell(cols[i], widths[i], UI.MUTED, Color(0, 0, 0, 0), tips.get(cols[i], ""), UI.f_body_b, 14, 32))
	tp[1].add_child(hdr)
	for b in blocks:
		var sel: bool = b["id"] == B["id"]
		var bg := Color(UI.GOLD, 0.12) if sel else Color(0, 0, 0, 0)
		var row := UI.hbox(2); row.mouse_filter = Control.MOUSE_FILTER_STOP
		var nh := PanelContainer.new(); nh.custom_minimum_size = Vector2(widths[0], 44); nh.add_theme_stylebox_override("panel", UI.sb(bg, 3, Color(0, 0, 0, 0), 0, 8))
		var nhh := UI.hbox(8); nh.add_child(nhh); nhh.add_child(UI.block_tag(b["id"], 15))
		var nl := UI.label(String(b["name"]), 15, UI.INK); nl.clip_text = true; nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nhh.add_child(nl)
		nh.mouse_filter = Control.MOUSE_FILTER_PASS; row.add_child(nh)
		row.add_child(UI.table_cell("%s · %.2f ha" % [b["variety"], float(b["area"])], widths[1], UI.INK, bg, "", UI.f_body, 15, 44))
		var stage := String(b["stage"])
		if b["picking"]: stage = "Picking %d %%" % int(b["pickedPct"])
		row.add_child(UI.table_cell(stage, widths[2], UI.GOLD if b.get("inWindow", false) else UI.INK, bg, "In the harvest window" if b.get("inWindow", false) else "", UI.f_body, 15, 44))
		var hp := int(float(b["health"]) * 100)
		row.add_child(UI.table_cell("%d %%" % hp, widths[3], UI.GOOD if hp >= 85 else (UI.WARN if hp >= 65 else UI.CRIT), bg, Metrics.tip("health")))
		row.add_child(UI.table_cell("%.1f MPa · %s" % [float(b["water"]), b["waterClass"]], widths[4], UI.INK2, bg, Metrics.value_tip("water", float(b["water"])), null, 15, 44))
		for k in [["downy", 5], ["powdery", 6], ["botrytis", 7]]:
			var r := float(b[k[0]])
			row.add_child(UI.table_cell("%d / 100" % int(r), widths[k[1]], UI.risk_col(r), bg, Metrics.value_tip(k[0], r)))
		row.add_child(UI.table_cell("%s kg" % UI.thousands(int(b["cropKg"])), widths[8], UI.INK, bg))
		var must = b.get("must")
		var mtxt := "—"
		if must != null: mtxt = ("%.1f °Bx" % float(must["brix"]) if napa else "%d °Oe" % int(must["oe"])) + " · TA %.1f" % float(must["ta"])
		row.add_child(UI.table_cell(mtxt, widths[9], UI.INK, bg))
		row.add_child(UI.table_cell("%s kg/ha" % UI.thousands(int(b["yieldKgHa"])), widths[10], UI.INK2, bg))
		for c in row.get_children(): c.mouse_filter = Control.MOUSE_FILTER_PASS
		var bid: String = b["id"]
		UI.on_click(row, func(): shell.state["plot_sel"] = bid; shell.show_screen("plot"))
		tp[1].add_child(row)
	v.add_child(tp[0])
	# detail
	var det := UI.hbox(16); v.add_child(det)
	var c1 := UI.vbox(16); c1.custom_minimum_size = Vector2(520, 0); det.add_child(c1)
	var sp: Array = UI.panel("Block %s — %s" % [B["id"], B["name"]], "soil and site")
	sp[1].add_child(_soil(B))
	var m: Dictionary = B["micro"]
	sp[1].add_child(UI.kv("Site", "%d %% slope facing %s, %d m" % [int(B["slope"]), B["aspect"], int(B["elevation"])]))
	var micro := []
	if float(m["frostPocket"]) > 0.5: micro.append("frost pocket")
	if float(m["fog"]) > 0.4: micro.append("fog-prone")
	if float(m["wind"]) > 0.6: micro.append("windy")
	if float(m["radiative"]) > 0.3: micro.append("warm rock/radiative heat")
	sp[1].add_child(UI.kv("Microclimate", ", ".join(micro) if micro.size() > 0 else "unremarkable"))
	sp[1].add_child(UI.kv("Heat so far", "Winkler %d · Huglin %d" % [int(B["winkler"]), int(B["huglin"])]))
	if String(B["notes"]) != "": sp[1].add_child(UI.label(String(B["notes"]), 14, UI.MUTED, null, true))
	c1.add_child(sp[0])
	var c2 := UI.vbox(16); c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; det.add_child(c2)
	var vp: Array = UI.panel("Vines", "%s on %s · %s · %s vines/ha · %s" % [B["variety"], B["rootstock"], B["training"], UI.thousands(int(B["density"])), _leaf(int(B["leaf"]))])
	var g := GridContainer.new(); g.columns = 4; g.add_theme_constant_override("h_separation", 26); g.add_theme_constant_override("v_separation", 6)
	for pair in [["Budburst", B["budburst"]], ["Flowering", B["flowering"]], ["Véraison", B["veraison"]], ["Harvest", B["harvestDate"]],
			["Leaf area index", "%.2f" % float(B["lai"])], ["Fruit exposure", "%.2f" % float(B["exposure"])], ["Berries / vine", UI.thousands(int(B["berriesPerVine"]))], ["Berry weight", "%.2f g" % float(B["berryWeight"])],
			["Soil water", "%d %% of %d mm" % [int(B["soilWaterPct"]), int(B["taw"])]], ["Frost shoot loss", "%d %%" % int(B["frostLoss"])], ["Sunburn", "%.1f %%" % float(B["sunburn"])], ["Chlorosis", "%d %%" % int(B["chlorosis"])],
			["Downy (leaf · bunch)", "%.1f %% · %.1f %%" % [float(B["downyLeaf"]), float(B["downyBunch"])]], ["Powdery (bunch)", "%.1f %%" % float(B["powderyBunch"])], ["Grey rot · noble rot", "%.1f %% · %.1f %%" % [float(B["greyRot"]), float(B["nobleRot"])]], ["Spray cover · passes", "%d %% · %d" % [int(B["protection"]), int(B["sprays"])]]]:
		var gl := UI.label(pair[0], 14, UI.INK2)
		var mk: String = {"Leaf area index": "lai", "Fruit exposure": "exposure", "Berries / vine": "berries", "Berry weight": "berryWeight", "Soil water": "soilwater",
			"Frost shoot loss": "frostLoss", "Sunburn": "sunburn", "Chlorosis": "chlorosis", "Downy (leaf · bunch)": "downy", "Grey rot · noble rot": "grey", "Spray cover · passes": "protection"}.get(pair[0], "")
		if mk != "": gl.tooltip_text = Metrics.tip(mk); gl.mouse_filter = Control.MOUSE_FILTER_PASS; gl.text += " ⓘ"
		g.add_child(gl)
		g.add_child(UI.num(String(pair[1]) if pair[1] != null else "—", 17))
	vp[1].add_child(g)
	c2.add_child(vp[0])
	var cp: Array = UI.panel("Choices for Block %s" % B["id"], "the Vineyard manager carries them out")
	var bid2: String = B["id"]
	var done: bool = B["harvested"] or B["picking"]
	_choice(cp[1], "Winter pruning (bud load)", ["Low", "Balanced", "High"], B["budLoad"], func(x): Sim.Command("flag", "pruning_ok", "", "", "", ""); shell.apply("block", bid2, "budload", x, "Block %s pruned to a %s bud load. Your crew prunes it this way." % [bid2, x.to_lower()]),
		"%.0f buds per vine now. Fewer buds → fewer, better-ripened bunches; more buds → bigger crop, slower ripening. Only matters before budburst." % float(B["budsPerVine"]), done, shell, "green-harvest", {"block": bid2})
	if not ("pruning_ok" in D.get("flags", [])) and String(B["stage"]) == "Dormant":
		var keep := UI.button("Keep the Mentor's pruning for all Blocks", true, 14)
		keep.pressed.connect(func():
			Sim.Command("task", "kind:Prune", "delegate", "", "", "")
			shell.apply("flag", "pruning_ok", "", "", "Pruning settled: the crew prunes every Block as the Mentor planned."))
		cp[1].add_child(keep)
	_choice(cp[1], "Leaf removal side", ["None", "Morning", "Afternoon", "Both"], B["leafSide"], func(x): shell.apply("block", bid2, "leafside", x, "Block %s: leaf removal on the %s side." % [bid2, x.to_lower()]),
		"Opening the morning side dries bunches (less rot) with little sunburn risk; the afternoon side is hotter — more colour and TDN, more sunburn.", done, shell, "leaf-removal", {"block": bid2})
	_choice(cp[1], "Leaf removal timing", ["Early", "Late"], B["leafTiming"], func(x): shell.apply("block", bid2, "leaftiming", x, "Block %s: leaf removal timing set to %s." % [bid2, x.to_lower()]),
		"Early (fruit set to bunch closure) lets the berries acclimatise to the sun; late (around véraison) bares berries grown in shade, the classic sunburn case.", done, shell, "leaf-removal", {"block": bid2})
	var thin := {"0": "None", "1": "Drop ~20 %", "2": "Drop ~40 %"}
	var inv := {"None": "0", "Drop ~20 %": "1", "Drop ~40 %": "2"}
	var cur_thin: String = thin.get(str(int(B.get("thinning", 0))), "None")
	_choice(cp[1], "Green harvest (crop thinning)", ["None", "Drop ~20 %", "Drop ~40 %"], cur_thin, func(x): shell.apply("block", bid2, "thinning", inv[x], "Block %s: green harvest set to %s." % [bid2, x.to_lower()]),
		"Cutting off bunches at véraison concentrates the rest and ripens them faster. Costs crop — and in the Côte d'Or can keep you inside the AOC yield limit.", done, shell, "green-harvest", {"block": bid2})
	c2.add_child(cp[0])
	# harvest
	var hp: Array = UI.panel("Harvest Block %s" % B["id"], "")
	(hp[1].get_child(0) as HBoxContainer).add_child(load("res://src/ui/learn_drawer.gd").link(shell, "harvest-date", {"block": String(B["id"])}))
	if B["harvested"]:
		hp[1].add_child(UI.label("Picked on %s → Lot %s in the Winery." % [B["harvestDate"], B["lotId"]], 16, UI.INK))
		var gb := UI.button("Open the Winery"); gb.pressed.connect(func(): shell.state["lot_sel"] = String(B["lotId"]); shell.show_screen("winery")); hp[1].add_child(gb)
	elif B["picking"]:
		hp[1].add_child(UI.label("Picking in progress: %d %% in." % int(B["pickedPct"]), 16, UI.GOLD))
		var mt = Charts.Meter.new(); mt.value = float(B["pickedPct"]) / 100.0; mt.color = UI.GOLD; hp[1].add_child(mt)
	elif B["veraison"] == null:
		hp[1].add_child(UI.label("Not before véraison. The Ripeness screen shows sampling once berries soften.", 15, UI.MUTED, null, true))
	else:
		var method: String = shell.state.get("h_method", "Hand")
		var sorting: String = shell.state.get("h_sort", "Table")
		var steep: bool = float(P["slope"]) >= 30 or String(B["training"]) == "Einzelpfahl"
		var h1 := UI.hbox(12); var l1 := UI.label("Picking", 15, UI.INK2); l1.custom_minimum_size = Vector2(110, 0); h1.add_child(l1)
		h1.add_child(UI.segmented(["Hand"] if steep else ["Hand", "Machine"], method if not steep else "Hand", func(x): shell.state["h_method"] = x; shell.show_screen("plot"), 110))
		h1.add_child(UI.label("Machines can't work this slope or single-stake vines." if steep else "Machines are fast and cheap but can't select bunches.", 13, UI.MUTED))
		hp[1].add_child(h1)
		var h2 := UI.hbox(12); var l2 := UI.label("Sorting", 15, UI.INK2); l2.custom_minimum_size = Vector2(110, 0); h2.add_child(l2)
		h2.add_child(UI.segmented(["None", "Table", "Rigorous"], sorting, func(x): shell.state["h_sort"] = x; shell.show_screen("plot"), 110))
		hp[1].add_child(h2)
		# the trade-off of each sorting level for this Block's fruit today (numbers from the simulation)
		var sg := GridContainer.new(); sg.columns = 5; sg.add_theme_constant_override("h_separation", 18); sg.add_theme_constant_override("v_separation", 3)
		for hname in ["", "Rot left in the wine", "Crop lost", "Extra labour", ""]: sg.add_child(UI.label(hname, 12, UI.MUTED, UI.f_body_b))
		for so in B.get("sortingOptions", []):
			var chosen: bool = String(so["level"]) == sorting
			var col := UI.GOLD if chosen else UI.INK2
			sg.add_child(UI.label(("▸ " if chosen else "  ") + String(so["level"]), 14, col, UI.f_body_b if chosen else null))
			sg.add_child(UI.num("%.1f %%" % float(so["rotLeftPct"]), 15, UI.CRIT if float(so["rotLeftPct"]) > 5 else col))
			sg.add_child(UI.num("%.1f %%" % float(so["cropLossPct"]), 15, col))
			sg.add_child(UI.num(UI.euro(int(so["extraCost"])) if int(so["extraCost"]) > 0 else "—", 15, col))
			sg.add_child(UI.label("slower picking" if so["slower"] else "", 12, UI.MUTED))
		hp[1].add_child(sg)
		hp[1].add_child(UI.label("Sorting throws out rotten and unripe bunches: cleaner wine, but you lose some good fruit and the crew picks more slowly. Above ~5 % grey rot the wine tastes mouldy.", 13, UI.MUTED, null, true))
		var must = B.get("must")
		if must != null:
			hp[1].add_child(UI.label("Now: %s, TA %.1f g/L, pH %.2f, potential alcohol %.1f %% · %s" % [("%.1f °Brix" % float(must["brix"])) if napa else ("%d °Oe" % int(must["oe"])), float(must["ta"]), float(must["ph"]), float(must["pa"]),
				"in the harvest window" if B.get("inWindow", false) else "not yet in the harvest window"], 15, UI.GOLD if B.get("inWindow", false) else UI.INK2, null, true))
		var hb := UI.button("Harvest Block %s now" % B["id"], true, 17); hb.custom_minimum_size = Vector2(0, 46)
		var meth_arg := "machine" if method == "Machine" and not steep else "hand"
		hb.pressed.connect(func():
			shell.command("harvest", bid2, meth_arg, sorting)
			shell.notify("Picking Block %s has started. Advance time to bring the grapes in." % bid2))
		hp[1].add_child(hb)
	c2.add_child(hp[0])
	return UI.scroll(v)

static func _leaf(n: int) -> String:
	return "%d%s leaf" % [n, "st" if n == 1 else ("nd" if n == 2 else ("rd" if n == 3 else "th"))]

static func _choice(parent: Control, title: String, opts: Array, cur: String, f: Callable, why: String, locked := false, shell = null, card := "", ctx := {}) -> void:
	var h := UI.hbox(12)
	var l := UI.label(title, 15, UI.INK2); l.custom_minimum_size = Vector2(250, 0); h.add_child(l)
	var seg := UI.segmented(opts, cur, f, 110)
	if locked:
		for b in seg.get_children(): (b as Button).disabled = true
	h.add_child(seg)
	if shell != null and card != "": h.add_child(load("res://src/ui/learn_drawer.gd").link(shell, card, ctx))
	h.tooltip_text = why
	parent.add_child(h)
	parent.add_child(UI.label(why, 13, UI.MUTED, null, true))

## Soil column built from the Block's measured profile. Horizon split is a game illustration (labelled), the numbers are the Block's.
static func _soil(B: Dictionary) -> Control:
	var s: Dictionary = B["soilProfile"]
	var depth := float(s["depthCm"])
	var tex := String(s["texture"])
	var stones := int(s["stones"])
	var top_col := "5b4632" if float(s["om"]) > 2 else "6b5640"
	var rock_col := "4a5058" if "slate" in String(B["soil"]).to_lower() or "slate" in String(B["notes"]).to_lower() else ("b9ab8e" if float(s["lime"]) > 8 else "7a6a55")
	var hz := [
		{"from": 0, "to": minf(30, depth), "name": "A", "texture": "%s topsoil" % tex, "stones": stones, "color": top_col},
		{"from": minf(30, depth), "to": depth, "name": "B", "texture": "%s subsoil" % tex, "stones": mini(95, stones + 15), "color": "7d6446"},
		{"from": depth, "to": 180, "name": "C", "texture": "weathered bedrock", "stones": 90, "color": rock_col},
	]
	var sc = Charts.SoilProfile.new()
	sc.profile = {"horizons": hz, "rootDepthCm": depth, "awcMm": float(s["tawMm"]), "phTopsoil": float(s["ph"]), "caco3": float(s["lime"])}
	sc.custom_minimum_size = Vector2(480, 300)
	sc.tooltip_text = "Sand %d %% · silt %d %% · clay %d %% · organic matter %.1f %% · drainage %s.\nHorizon depths are drawn schematically (game illustration); the numbers are this Block's." % [int(s["sand"]), int(s["silt"]), int(s["clay"]), float(s["om"]), String(s["drainage"])]
	return sc

## "Your Blocks": a small spinning model labelled with each Block's Variety, next to the Planting table.
static func _overview(D: Dictionary, shell) -> Control:
	var row := UI.hbox(16)
	var cat_plot := {}
	for r in shell.CAT.get("regions", []):
		for p in r["plots"]:
			if p["id"] == D["plot"]["id"]: cat_plot = p
	var dp := PanelContainer.new(); dp.add_theme_stylebox_override("panel", UI.sb(Color("1a2127"), 8, UI.LINE, 1, 0))
	dp.custom_minimum_size = Vector2(620, 300)
	if not cat_plot.is_empty():
		var dio = load("res://src/ui/diorama.gd").new()
		for b in D["blocks"]: dio.label_text[String(b["id"])] = String(b["variety"])
		dio.set_plot(cat_plot)
		dp.add_child(dio)
		var cap := UI.label("  Your Plot · drag to turn", 13, UI.INK2); cap.vertical_alignment = VERTICAL_ALIGNMENT_TOP; cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dp.add_child(cap)
	row.add_child(dp)
	var tp: Array = UI.panel("Your Blocks", "what you planted in %d" % int(D.get("plantingYear", 0)), 4)
	tp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var g := GridContainer.new(); g.columns = 7; g.add_theme_constant_override("h_separation", 18); g.add_theme_constant_override("v_separation", 6)
	for h in ["", "Variety", "Rootstock", "Training", "Vines/ha", "Area", "Soil"]:
		g.add_child(UI.label(h, 13, UI.MUTED, UI.f_body_b))
	for b in D["blocks"]:
		g.add_child(UI.block_tag(String(b["id"]), 14))
		g.add_child(UI.label("%s %s" % [String(b["variety"]), "●" if b["red"] else "○"], 15, UI.INK, UI.f_body_b))
		g.add_child(UI.label(String(b["rootstock"]), 14, UI.INK2))
		g.add_child(UI.label("%s · rows %s" % [String(b["training"]), {"NorthSouth": "N–S", "EastWest": "E–W", "DownSlope": "downhill"}.get(String(b.get("rows", "")), "")], 14, UI.INK2))
		g.add_child(UI.num(UI.thousands(int(b["density"])), 15))
		g.add_child(UI.num("%.2f ha" % float(b["area"]), 15))
		var sl := UI.label(String(b["soil"]), 13, UI.MUTED); sl.clip_text = true; sl.custom_minimum_size = Vector2(200, 0)
		g.add_child(sl)
	tp[1].add_child(g)
	tp[1].add_child(UI.label("● red · ○ white. Click a Block in the table below for its soil, vines and choices.", 13, UI.MUTED))
	row.add_child(tp[0])
	return row
