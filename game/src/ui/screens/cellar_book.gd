# The Cellar book: a Vintage card for every vintage tasted at a Wine Fair stand, row by Region. Each card is revision material:
# the season in numbers from the weather record, how warm it was against the other years, and the sourced real note if one
# exists. Empty slots show the vintages the open stands still have to give.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const T := preload("res://src/ui/tasting_ui.gd")
const CLIMATE_COL := {"cool": Color("5fa8d3"), "moderate": Color("9fb86a"), "warm": Color("e0874a")}

static func build(_D: Dictionary, shell) -> Control:
	var L := T.lobby(shell)
	var v := UI.vbox(16)
	v.add_child(T.header(shell, L, "cellarbook"))
	var B: Dictionary = L.get("cellarBook", {})
	var cards: Array = B.get("cards", [])
	var slots: Dictionary = B.get("slots", {})
	var names: Dictionary = B.get("regionNames", {})
	if cards.is_empty():
		var p: Array = UI.panel("No Vintage cards yet", "")
		p[1].add_child(UI.label("Taste a Flight at the Wine Fair: every vintage in it becomes a card here, with its weather and what really happened.", 15, UI.INK2, null, true))
		var b := UI.button("Go to the Wine Fair", true, 15); b.pressed.connect(func(): shell.show_screen("fair"))
		p[1].add_child(b)
		v.add_child(p[0])
	if int(B.get("hidden", 0)) > 0:
		v.add_child(UI.label("%d card%s from later vintages stay hidden in this game until those harvests (no future knowledge)." % [int(B["hidden"]), "" if int(B["hidden"]) == 1 else "s"], 14, UI.MUTED, null, true))
	var regions := {}
	for r in slots.keys(): regions[r] = true
	for c in cards: regions[String(c["region"])] = true
	for r in regions.keys():
		var have := {}
		for c in cards: if String(c["region"]) == r: have[int(c["year"])] = c
		var years := {}
		for y in slots.get(r, []): years[int(y)] = true
		for y in have.keys(): years[y] = true
		var ys := years.keys(); ys.sort()
		var p: Array = UI.panel(String(names.get(r, r)), "%d of %d collected" % [have.size(), ys.size()])
		var flow := HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 14); flow.add_theme_constant_override("v_separation", 14)
		p[1].add_child(flow)
		for y in ys:
			flow.add_child(_card(have[y]) if have.has(y) else _empty(int(y)))
		v.add_child(p[0])
	return UI.scroll(v)

static func _empty(year: int) -> Control:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UI.sb(UI.SUNKEN, 8, UI.LINE, 1, 16))
	c.custom_minimum_size = Vector2(380, 120)
	c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var v := UI.vbox(6); c.add_child(v)
	v.add_child(UI.head(str(year), 30, UI.MUTED))
	v.add_child(UI.label("Not tasted yet. A Wine Fair stand pours this vintage.", 14, UI.MUTED, null, true))
	return c

static func _card(C: Dictionary) -> Control:
	var climate := String(C["climate"])
	var col: Color = CLIMATE_COL.get(climate, UI.INK2)
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UI.sb(UI.SURFACE, 8, col.darkened(0.2), 2, 16))
	c.custom_minimum_size = Vector2(380, 150)
	c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var v := UI.vbox(6); c.add_child(v)
	var top := UI.hbox(10); v.add_child(top)
	top.add_child(UI.head(str(int(C["year"])), 30, UI.INK))
	top.add_child(UI.spacer())
	top.add_child(UI.chip(climate + " year", col, 13, true))
	if C.get("climateLine") != null: v.add_child(UI.label(String(C["climateLine"]).capitalize().substr(0, 1) + String(C["climateLine"]).substr(1) + " (average April–October %.1f °C)." % float(C["regionGst"]), 13, UI.INK2, null, true))
	v.add_child(_row("Growing-degree days", "%d · %d of %d, warmest first" % [int(C["gdd"]), int(C["gddRank"]), int(C["recordYears"])]))
	v.add_child(_row("Summer maximum", "%.1f °C" % float(C["summerTmax"])))
	v.add_child(_row("Hot days (≥ 30 °C)", str(int(C["hotDays"]))))
	v.add_child(_row("Autumn rain", "%d mm (Sep–Oct)" % int(C["autumnRain"])))
	v.add_child(_row("Coldest spring night", "%s, %.1f °C" % [C["frostNight"], float(C["frostC"])]))
	var np = T.note_panel(C.get("note", null))
	if np != null:
		np.custom_minimum_size = Vector2(340, 0)
		v.add_child(np)
	c.tooltip_text = String(C["climateBecause"])
	return c

static func _row(k: String, val: String) -> Control:
	var h := UI.hbox(8)
	var kl := UI.label(k, 14, UI.INK2); kl.custom_minimum_size = Vector2(150, 0); h.add_child(kl)
	var vl := UI.label(val, 14, UI.INK, UI.f_body_b); h.add_child(vl)
	return h
