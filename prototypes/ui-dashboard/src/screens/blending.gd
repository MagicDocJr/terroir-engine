# PROTOTYPE — Blending: assign shares of each Lot to up to three Wines; the blend analysis and Legal category update live.
extends RefCounted

const UI := preload("res://src/ui.gd")
const Charts := preload("res://src/charts.gd")
const LEVELS := ["Qualitätswein", "Kabinett", "Spätlese", "Auslese"]
const STEPS := [0, 20, 40, 60, 80, 100]

static func build(D: Dictionary, S) -> Control:
	var lots: Array = D["blendLots"]
	if not S.state.has("blend"):
		var b := {}
		for w in D["wines"]:
			for lot in w["assign"]: b["%d_%s" % [int(w["id"]), lot]] = int(w["assign"][lot])
		S.state["blend"] = b
	var blend: Dictionary = S.state["blend"]
	var v := UI.vbox(16)
	v.add_child(UI.page_header("Blending", "Decide how much of each Lot goes into which Wine. Up to three Wines per Vintage; what's left over is sold as bulk wine."))
	var row := UI.hbox(18); row.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(row)
	var tp := UI.panel("Lots", "share of each Lot per Wine, in steps of 20 %")
	tp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tp[0])
	var head := UI.hbox(6)
	for c in [["Lot", 380], ["Volume", 90], ["Wine 1", 150], ["Wine 2", 150], ["Wine 3", 150], ["Unused", 70]]:
		var l := UI.label(c[0], 14, UI.MUTED); l.custom_minimum_size = Vector2(c[1], 26); head.add_child(l)
	tp[1].add_child(head)
	for lot in lots:
		var h := UI.hbox(6)
		var lc := UI.hbox(10); lc.custom_minimum_size = Vector2(380, 52)
		lc.add_child(UI.block_tag(String(lot["lot"])))
		var nv := UI.vbox(0); nv.add_child(UI.label(String(lot["name"]), 15, UI.INK))
		var lvl_txt: String = String(lot["level"]) if not String(lot["level"]).begins_with("UNVERIFIED") else "not assessed"
		var sub := UI.label("%.1f %%, RS %.0f g/L, TA %.1f g/L, qualifies %s" % [float(lot["abv"]), float(lot["rs"]), float(lot["ta"]), lvl_txt], 13, UI.MUTED)
		if lvl_txt == "not assessed":
			sub.tooltip_text = "Prädikat minimums for red Varieties are UNVERIFIED in this prototype."; sub.mouse_filter = Control.MOUSE_FILTER_PASS
		nv.add_child(sub); lc.add_child(nv)
		h.add_child(lc)
		h.add_child(UI.table_cell("%s L" % UI.thousands(int(lot["volume"])), 90, UI.INK))
		var used := 0
		for w in D["wines"]:
			var key := "%d_%s" % [int(w["id"]), lot["lot"]]
			var pct: int = int(blend.get(key, 0)); used += pct
		for w in D["wines"]:
			var key := "%d_%s" % [int(w["id"]), lot["lot"]]
			var pct: int = int(blend.get(key, 0))
			var cell := UI.hbox(2); cell.custom_minimum_size = Vector2(150, 48)
			var minus := UI.button("−", false, 16); minus.custom_minimum_size = Vector2(36, 34); minus.disabled = pct <= 0
			minus.pressed.connect(func(): blend[key] = maxi(0, pct - 20); S.rerender())
			var pl := UI.num("%d %%" % pct, 18, UI.INK if pct > 0 else UI.MUTED); pl.custom_minimum_size = Vector2(62, 0); pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var plus := UI.button("+", false, 16); plus.custom_minimum_size = Vector2(36, 34); plus.disabled = used >= 100
			plus.pressed.connect(func(): blend[key] = mini(100, pct + 20); S.rerender())
			cell.add_child(minus); cell.add_child(pl); cell.add_child(plus)
			h.add_child(cell)
		h.add_child(UI.table_cell("%d %%" % (100 - used), 70, UI.INK2 if used < 100 else UI.MUTED))
		tp[1].add_child(h)
	tp[1].add_child(UI.spacer(false, 8))
	tp[1].add_child(UI.label("A Lot can't be split beyond 100 %. Blending the red Lot D into a white Wine is allowed by the rules here but makes a rosé-coloured oddity.", 13, UI.MUTED, null, true))
	var right := UI.vbox(14); right.custom_minimum_size = Vector2(560, 0); row.add_child(right)
	for w in D["wines"]: right.add_child(_wine_card(w, lots, blend))
	return v

static func _wine_card(w: Dictionary, lots: Array, blend: Dictionary) -> Control:
	var vol := 0.0; var abv := 0.0; var rs := 0.0; var ta := 0.0; var ph := 0.0
	var lowest := 99
	var parts := []
	for lot in lots:
		var pct := float(blend.get("%d_%s" % [int(w["id"]), lot["lot"]], 0)) / 100.0
		if pct <= 0: continue
		var lv := float(lot["volume"]) * pct
		vol += lv; abv += lv * float(lot["abv"]); rs += lv * float(lot["rs"]); ta += lv * float(lot["ta"]); ph += lv * float(lot["ph"])
		var li := LEVELS.find(String(lot["level"]))
		lowest = mini(lowest, li if li >= 0 else 0)
		parts.append([String(lot["lot"]), lv])
	var p := PanelContainer.new()
	var v := UI.vbox(8); p.add_child(v)
	var h := UI.hbox(10)
	var wl := UI.head("Wine %d" % int(w["id"]), 16, UI.MUTED); wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(wl)
	h.add_child(UI.head(String(w["name"]), 20, UI.INK))
	v.add_child(h)
	if vol <= 0:
		v.add_child(UI.label("No Lots assigned yet.", 15, UI.MUTED))
		return p
	abv /= vol; rs /= vol; ta /= vol; ph /= vol
	var bar := StackBar.new(); bar.parts = parts; bar.total = vol; bar.custom_minimum_size = Vector2(0, 14)
	v.add_child(bar)
	var nums := GridContainer.new(); nums.columns = 3
	nums.add_theme_constant_override("h_separation", 34); nums.add_theme_constant_override("v_separation", 6)
	for kv in [["Volume", "%s L" % UI.thousands(int(vol))], ["Bottles", UI.thousands(int(vol * 0.97 / 0.75))], ["Alcohol", "%.1f %%" % abv], ["Sugar", "%.0f g/L" % rs], ["TA", "%.1f g/L" % ta], ["pH ≈", "%.2f" % ph]]:
		var c := UI.vbox(0); c.add_child(UI.label(kv[0], 13, UI.MUTED)); c.add_child(UI.num(kv[1], 19, UI.INK)); nums.add_child(c)
	v.add_child(nums)
	var style := "dry" if rs <= 9 else ("off-dry" if rs <= 18 else ("medium" if rs <= 45 else "sweet"))
	var lvl: String = LEVELS[lowest] if lowest < 99 else "Qualitätswein"
	var sl := UI.label("Style: %s (roughly the EU label bands). Qualifies for %s, the lowest level of its Lots; you may declare a lower level." % [style, lvl], 15, UI.INK2, null, true)
	sl.tooltip_text = "Game simplification (rulebook v0): a blend takes the lowest Prädikat level of its Lots."
	sl.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(sl)
	return p

class StackBar extends Control:
	var parts: Array = []
	var total := 1.0
	const UI3 := preload("res://src/ui.gd")
	func _draw() -> void:
		var x := 0.0
		for pt in parts:
			var w := size.x * float(pt[1]) / total
			draw_style_box(UI3.sb(UI3.BLOCK[pt[0]], 3, Color(0, 0, 0, 0), 0, 0), Rect2(x, 0, maxf(0, w - 2), size.y))
			if w > 30: draw_string(UI3.f_head, Vector2(x + 6, size.y - 1), pt[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("0f1418"))
			x += w
