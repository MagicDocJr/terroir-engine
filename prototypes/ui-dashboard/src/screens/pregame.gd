# PROTOTYPE — pre-game flow: Region picker → Plot comparison (Football Manager-style attribute grid, Mentor comments).
extends RefCounted

const UI := preload("res://src/ui.gd")

static func build(D: Dictionary, S, mode: String) -> Control:
	return _regions(D, S) if mode == "region" else _plots(D, S)

# ------------------------------------------------------------------ regions
static func _regions(D: Dictionary, S) -> Control:
	var sel: String = S.state.get("region", "mosel")
	var v := UI.vbox(16)
	var top := UI.hbox(12)
	top.add_child(UI.head("Terroir", 26, UI.INK))
	top.add_child(UI.spacer())
	top.add_child(UI.label("New Estate, step 1 of 3", 15, UI.MUTED))
	v.add_child(top)
	v.add_child(UI.page_header("Where will you plant your first vines?",
		"Each Region has its own climate, soils, hazards and wine law. You can plant any Variety anywhere, but the Region decides what's easy."))
	var row := UI.hbox(18); row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	for r in D["regions"]:
		row.add_child(_region_card(r, String(r["id"]) == sel, S))
	var foot := UI.hbox(12)
	foot.add_child(UI.label("The Mentor, Klaus Weber, will walk you through your first Vintage.", 15, UI.INK2))
	foot.add_child(UI.spacer())
	var go := UI.button("Compare Plots in %s" % _region_name(D, sel), true, 17); go.custom_minimum_size = Vector2(0, 46)
	go.disabled = sel != "mosel"
	go.tooltip_text = "" if sel == "mosel" else "Only the Mosel Plots are built in this prototype."
	go.pressed.connect(func(): S.show_screen("plots"))
	foot.add_child(go)
	v.add_child(foot)
	return v

static func _region_name(D: Dictionary, id: String) -> String:
	for r in D["regions"]:
		if r["id"] == id: return String(r["name"])
	return id

static func _region_card(r: Dictionary, selected: bool, S) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UI.sb(UI.RAISED if selected else UI.SURFACE, 8, UI.GOLD if selected else UI.LINE, 2 if selected else 1, 22))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: S.state["region"] = r["id"]; S.rerender())
	var v := UI.vbox(9); p.add_child(v)
	var h := UI.hbox(10)
	h.add_child(UI.head(String(r["name"]), 36, UI.INK))
	h.add_child(UI.spacer())
	var cl := UI.label("%s, %s" % [r["country"], r["lat"]], 15, UI.MUTED); cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(cl)
	v.add_child(h)
	v.add_child(UI.label(String(r["blurb"]), 16, UI.INK, UI.f_body, true))
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18); grid.add_theme_constant_override("v_separation", 5)
	for kv in [["Climate", r["climate"]], ["Heat", r["winkler"] + " (Winkler)"], ["Rain", r["rain"]], ["Soils", r["soils"]], ["Wine law", r["law"]], ["Land price", r["land"]]]:
		var k := UI.label(kv[0], 14, UI.MUTED); k.custom_minimum_size = Vector2(88, 0); grid.add_child(k)
		var val := UI.label(String(kv[1]), 15, UI.INK2, null, true); val.custom_minimum_size = Vector2(300, 0); val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(val)
	v.add_child(grid)
	v.add_child(UI.head("Main hazards", 17, UI.INK))
	for hz in r["hazards"]:
		var hh := UI.hbox(8)
		hh.add_child(UI.label("▲", 12, UI.WARN))
		hh.add_child(UI.label(String(hz), 15, UI.INK2))
		v.add_child(hh)
	v.add_child(UI.head("Typical wines", 17, UI.INK))
	for st in r["styles"]:
		var sh := UI.hbox(8); sh.add_child(UI.label("•", 14, UI.MUTED)); sh.add_child(UI.label(String(st), 15, UI.INK2)); v.add_child(sh)
	v.add_child(UI.head("How the four Varieties would do here", 17, UI.INK))
	var sg := GridContainer.new(); sg.columns = 2; sg.add_theme_constant_override("h_separation", 16)
	for vn in ["Riesling", "Chardonnay", "Pinot Noir", "Cabernet Sauvignon"]:
		var n: int = int(r["suit"][vn])
		var vl := UI.label(vn, 15, UI.INK2); vl.custom_minimum_size = Vector2(170, 0); sg.add_child(vl)
		sg.add_child(UI.label("★".repeat(n) + "☆".repeat(5 - n), 16, UI.WARN if n >= 4 else UI.INK2))
	v.add_child(sg)
	var clim := UI.hbox(18)
	for spec in [["Monthly mean temperature", r["tmean"], "%.0f–%.0f °C"], ["Monthly rain", r["rainMonthly"], "%.0f–%.0f mm"]]:
		var cv := UI.vbox(2); cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var arr: Array = spec[1]
		cv.add_child(UI.label("%s, %s" % [spec[0], spec[2] % [arr.min(), arr.max()]], 13, UI.MUTED))
		var spk = load("res://src/charts.gd").Sparkline.new(); spk.values = arr; spk.color = UI.SEQ; spk.custom_minimum_size = Vector2(0, 34)
		cv.add_child(spk)
		clim.add_child(cv)
	v.add_child(clim)
	v.add_child(UI.spacer(false))
	var avail := UI.label("4 Plots to compare" if r["id"] == "mosel" else "Plots not built in this prototype", 14, UI.INK2 if r["id"] == "mosel" else UI.MUTED)
	v.add_child(avail)
	return p

# ------------------------------------------------------------------ plot comparison
const ATTRS := ["Sun exposure", "Heat accumulation", "Frost safety", "Drainage", "Water holding", "Low vigour", "Rot safety", "Mechanisation", "Labour ease"]
const ATTR_TIP := {
	"Sun exposure": "How much direct sun the vines get, from slope and aspect. More sun, riper fruit.",
	"Heat accumulation": "Estimated growing degree days compared with the Region.",
	"Frost safety": "How well cold air drains away on spring nights. Low = frost pocket.",
	"Drainage": "How fast water leaves the root zone. Slate slopes drain fast.",
	"Water holding": "Available water for dry spells. High on deep soils, low on shallow slate.",
	"Low vigour": "How much the site holds back leafy growth. Moderate vigour usually means better fruit.",
	"Rot safety": "Air movement and drying after rain. Low = more botrytis and mildew pressure.",
	"Mechanisation": "Can machines work here? Steep slopes mean hand work or a monorack.",
	"Labour ease": "The opposite of hours per hectare per year.",
}

static func _plots(D: Dictionary, S) -> Control:
	var sel: int = S.state.get("plot_pick", 3)
	var plots: Array = D["plots"]
	var v := UI.vbox(12)
	var top := UI.hbox(12)
	var back := UI.button("Back to Regions"); back.pressed.connect(func(): S.show_screen("region")); top.add_child(back)
	top.add_child(UI.spacer())
	top.add_child(UI.label("New Estate, step 2 of 3", 15, UI.MUTED))
	v.add_child(top)
	var cash := 260000
	v.add_child(UI.page_header("Compare Plots in the Mosel",
		"Ratings run from 1 to 20. Starting capital %s. The land price has to leave money for planting and three years of Establishment." % UI.euro(cash)))
	var grid_panel := PanelContainer.new(); grid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(grid_panel)
	var g := GridContainer.new(); g.columns = plots.size() + 1
	g.add_theme_constant_override("h_separation", 6); g.add_theme_constant_override("v_separation", 2)
	grid_panel.add_child(g)
	var label_w := 250.0
	var col_w := 318.0
	# column heads
	g.add_child(UI.spacer(true, 0))
	for p in plots:
		var is_sel: bool = int(p["id"]) == sel
		var hp := PanelContainer.new(); hp.custom_minimum_size = Vector2(col_w, 0)
		hp.add_theme_stylebox_override("panel", UI.sb(UI.RAISED if is_sel else UI.SUNKEN, 5, UI.GOLD if is_sel else Color(0, 0, 0, 0), 2 if is_sel else 0, 14))
		hp.mouse_filter = Control.MOUSE_FILTER_STOP; hp.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hp.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: S.state["plot_pick"] = int(p["id"]); S.rerender())
		var hv := UI.vbox(2); hp.add_child(hv)
		hv.add_child(UI.head(String(p["name"]), 22, UI.INK))
		hv.add_child(UI.label(String(p["kind"]), 14, UI.INK2))
		var ph := UI.hbox(8)
		var price: int = int(float(p["price"]) * float(p["ha"]))
		ph.add_child(UI.num(UI.euro(price), 20, UI.INK if price < cash * 0.7 else UI.SERIOUS))
		ph.add_child(UI.label("for %.1f ha" % float(p["ha"]), 14, UI.MUTED))
		hv.add_child(ph)
		g.add_child(hp)
	# facts
	var facts := [["Elevation", func(p): return "%d m" % int(p["elevation"])], ["Slope", func(p): return "%d %%" % int(p["slope"])],
		["Aspect", func(p): return String(p["aspect"])], ["Soil", func(p): return String(p["soil"])],
		["Work per year", func(p): return "%s h/ha" % UI.thousands(int(p["hoursPerHa"]))], ["Classification", func(p): return String(p["classification"])]]
	for fct in facts:
		var k := UI.label(fct[0], 15, UI.MUTED); k.custom_minimum_size = Vector2(label_w, 27); k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; g.add_child(k)
		for p in plots:
			var c := UI.label(fct[1].call(p), 15, UI.INK2); c.custom_minimum_size = Vector2(col_w, 27); c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			c.clip_text = true
			g.add_child(c)
	# FM attribute ratings
	for a in ATTRS:
		var k := UI.label(a, 16, UI.INK); k.custom_minimum_size = Vector2(label_w, 31); k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		k.tooltip_text = ATTR_TIP[a]; k.mouse_filter = Control.MOUSE_FILTER_PASS
		g.add_child(k)
		var best := 0
		for p in plots: best = maxi(best, int(p["attrs"][a]))
		for p in plots:
			var val: int = int(p["attrs"][a])
			var cell := UI.hbox(12); cell.custom_minimum_size = Vector2(col_w, 31)
			var nb := PanelContainer.new(); nb.custom_minimum_size = Vector2(46, 28)
			nb.add_theme_stylebox_override("panel", UI.sb(UI.SUNKEN, 4, UI.rating_col(val) if val == best else Color(0, 0, 0, 0), 1 if val == best else 0, 6))
			var nl := UI.num(str(val), 21, UI.rating_col(val)); nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; nb.add_child(nl)
			cell.add_child(nb)
			var bar = load("res://src/charts.gd").Meter.new(); bar.value = val / 20.0; bar.color = Color(UI.rating_col(val), 0.8)
			bar.custom_minimum_size = Vector2(150, 8); cell.add_child(bar)
			cell.tooltip_text = "%s: %d / 20. %s" % [a, val, ATTR_TIP[a]]
			g.add_child(cell)
	# suitability per Variety
	for vname in ["Riesling", "Chardonnay", "Pinot Noir", "Cabernet Sauvignon"]:
		var k := UI.label("Suits %s" % vname, 15, UI.INK2); k.custom_minimum_size = Vector2(label_w, 26); k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; g.add_child(k)
		for p in plots:
			var s: int = int(p["suit"][vname])
			var st := UI.label("★".repeat(s) + "☆".repeat(5 - s), 17, UI.WARN if s >= 4 else UI.INK2)
			st.custom_minimum_size = Vector2(col_w, 26); st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			st.tooltip_text = "Mentor's estimate for %s here: %d of 5" % [vname, s]; st.mouse_filter = Control.MOUSE_FILTER_PASS
			g.add_child(st)
	# mentor comments
	var mk := UI.label("Klaus says", 16, UI.INK); mk.custom_minimum_size = Vector2(label_w, 0); mk.vertical_alignment = VERTICAL_ALIGNMENT_TOP; g.add_child(mk)
	for p in plots:
		var mc := UI.label("“%s”" % p["mentor"], 15, UI.INK2, UI.f_body, true); mc.custom_minimum_size = Vector2(col_w, 70)
		g.add_child(mc)
	var foot := UI.hbox(12)
	var chosen: Dictionary = plots[sel - 1]
	var total := int(float(chosen["price"]) * float(chosen["ha"]))
	foot.add_child(UI.label("Selected: %s, %s. Cash left after purchase: %s." % [chosen["name"], UI.euro(total), UI.euro(cash - total)], 16, UI.INK))
	foot.add_child(UI.spacer())
	var buy := UI.button("Buy %s" % chosen["name"], true, 17); buy.custom_minimum_size = Vector2(0, 46)
	buy.pressed.connect(func(): S.notify("Next in the full game: Planting decisions per Block. Jumping to the running Estate."); S.show_screen("inbox"))
	foot.add_child(buy)
	v.add_child(foot)
	return v
