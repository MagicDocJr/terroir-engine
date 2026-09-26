# PROTOTYPE — Wines: the Tasting sheet (every descriptor linked to its cause), Legal category, price and bottles.
extends RefCounted

const UI := preload("res://src/ui.gd")

static func build(D: Dictionary, S) -> Control:
	var T: Dictionary = D["tasting"]
	var sel: int = S.state.get("wine", 2)
	var tabs := UI.hbox(6)
	for w in D["wines"]:
		var b := UI.button(String(w["name"]).replace("2025 ", ""), false, 15)
		if int(w["id"]) == sel:
			b.add_theme_stylebox_override("normal", UI.sb(UI.GOLD.darkened(0.62), 4, UI.GOLD, 1, 12)); b.add_theme_color_override("font_color", UI.GOLD.lightened(0.35))
		b.pressed.connect(func(): S.state["wine"] = int(w["id"]); S.rerender())
		tabs.add_child(b)
	var v := UI.vbox(16)
	v.add_child(UI.page_header("Wines", "Each Wine gets a Tasting sheet. Every descriptor links back to what caused it, so you learn why the wine tastes the way it does.", [tabs]))
	if sel != 2:
		var pv := UI.panel(""); pv[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
		pv[1].add_child(UI.head("The Tasting sheet appears once this blend is final.", 26, UI.INK))
		pv[1].add_child(UI.label("In this prototype only Wine 2 has a projected sheet. In the full game every Wine gets one at bottling.", 17, UI.INK2, null, true))
		v.add_child(pv[0])
		return v
	var row := UI.hbox(18); row.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(row)
	var sheet := PanelContainer.new(); sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.add_theme_stylebox_override("panel", UI.sb(UI.SURFACE, 6, UI.LINE, 1, 28))
	row.add_child(sheet)
	var sv := UI.vbox(6); sheet.add_child(sv)
	var th := UI.hbox(12)
	th.add_child(UI.head(String(T["wine"]), 30, UI.INK))
	th.add_child(UI.spacer())
	th.add_child(UI.chip(String(T["status"]), UI.INK2, 14))
	sv.add_child(th)
	sv.add_child(UI.label("Tasting sheet. The left column is what you'd write in a systematic tasting note; the right column is the reason.", 14, UI.MUTED))
	sv.add_child(UI.spacer(false, 6))
	var colhead := UI.hbox(14)
	var c1 := UI.label("", 13, UI.MUTED); c1.custom_minimum_size = Vector2(150, 0); colhead.add_child(c1)
	var c2 := UI.label("Assessment", 13, UI.MUTED); c2.custom_minimum_size = Vector2(360, 0); colhead.add_child(c2)
	colhead.add_child(UI.label("Because", 13, UI.MUTED))
	sv.add_child(colhead)
	for sec in T["sections"]:
		sv.add_child(UI.spacer(false, 4))
		sv.add_child(UI.head(String(sec["title"]), 20, UI.INK))
		sv.add_child(UI.divider())
		for r in sec["rows"]:
			var h := UI.hbox(14)
			var k := UI.label(String(r["k"]), 15, UI.INK2); k.custom_minimum_size = Vector2(150, 0); h.add_child(k)
			var val := UI.label(String(r["v"]), 16, UI.INK, UI.f_body_b, true); val.custom_minimum_size = Vector2(360, 0); h.add_child(val)
			var why := UI.label(String(r["why"]), 15, UI.INK2, null, true); why.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(why)
			sv.add_child(h)
	var right := UI.vbox(16); right.custom_minimum_size = Vector2(520, 0); row.add_child(right)
	var ap := UI.panel("Analysis", "projected at bottling")
	var a: Dictionary = T["analysis"]
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 26); grid.add_theme_constant_override("v_separation", 10)
	for kv in [["Alcohol", "%.1f %% vol" % float(a["abv"])], ["Residual sugar", "%d g/L" % int(a["rs"])], ["Titratable acidity", "%.1f g/L" % float(a["ta"])],
			["pH", "%.2f" % float(a["ph"])], ["Free SO₂", "%d mg/L" % int(a["freeSO2"])]]:
		var c := UI.vbox(0); c.add_child(UI.label(kv[0], 13, UI.MUTED)); c.add_child(UI.num(kv[1], 22, UI.INK)); grid.add_child(c)
	ap[1].add_child(grid)
	right.add_child(ap[0])
	var lp := UI.panel("Legal category")
	var L: Dictionary = T["legal"]
	lp[1].add_child(UI.head(String(L["category"]), 21, UI.INK))
	lp[1].add_child(UI.label("Qualifies for: %s." % L["qualifies"], 15, UI.INK2, null, true))
	lp[1].add_child(UI.label("Label: %s." % L["labelTerm"], 15, UI.INK2, null, true))
	lp[1].add_child(UI.label(String(L["note"]), 13, UI.MUTED, null, true))
	right.add_child(lp[0])
	var pp := UI.panel("Price")
	var P: Dictionary = T["price"]
	var ph := UI.hbox(26)
	for kv in [["Ex-cellar", "€%.2f" % float(P["exCellar"])], ["Bottles", UI.thousands(int(P["bottles"]))], ["Revenue", UI.euro(int(P["revenue"]))]]:
		var c := UI.vbox(0); c.add_child(UI.label(kv[0], 13, UI.MUTED)); c.add_child(UI.num(kv[1], 24, UI.INK)); ph.add_child(c)
	pp[1].add_child(ph)
	pp[1].add_child(UI.label("Price follows Legal category and quality. A Kabinett from a steep slope sells above a Qualitätswein from the flat.", 13, UI.MUTED, null, true))
	right.add_child(pp[0])
	right.add_child(UI.spacer(false))
	return v
