# Planting guide: what each Planting choice means, with drawings, and how it suits the Plot being planted.
# Facts follow docs/science (canopy-and-yield.md §training, soil-and-water.md §7 rootstocks, phenology/ripening for Varieties).
# The "suits this Plot" hints compare catalog numbers only; the simulation decides what actually happens.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const TABS := ["Varieties", "Rootstocks", "Training", "Density & rows"]

static func build(shell, P: Dictionary, cat: Dictionary) -> Control:
	var tab: String = shell.setup.get("guide_tab", "Training")
	var pn: Array = UI.panel("Planting guide", "what each choice means, and how it suits %s" % P["name"], 12)
	pn[1].add_child(UI.segmented(TABS, tab, func(x): shell.setup["guide_tab"] = x; shell.show_screen("planting"), 150))
	match tab:
		"Varieties": pn[1].add_child(_varieties(P, cat))
		"Rootstocks": pn[1].add_child(_rootstocks(P, cat))
		"Density & rows": pn[1].add_child(_density(P))
		_: pn[1].add_child(_training(P))
	return pn[0]

static func _card(title: String, sub: String, col := UI.INK) -> Array:
	var c := PanelContainer.new(); c.add_theme_stylebox_override("panel", UI.sb(UI.RAISED, 6, UI.LINE, 1, 14))
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6); c.add_child(v)
	v.add_child(UI.head(title, 20, col))
	if sub != "": v.add_child(UI.label(sub, 13, UI.GOLD))
	return [c, v]

static func _bar(parent: Control, label: String, value: float, text: String, good_high := true) -> void:
	var h := UI.hbox(8)
	var l := UI.label(label, 13, UI.INK2); l.custom_minimum_size = Vector2(120, 0); h.add_child(l)
	var m = load("res://src/ui/charts.gd").Meter.new(); m.value = clampf(value, 0, 1); m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.color = UI.rating_col(int(round((value if good_high else 1.0 - value) * 19 + 1)))
	h.add_child(m)
	var t := UI.label(text, 13, UI.INK); t.custom_minimum_size = Vector2(110, 0); h.add_child(t)
	parent.add_child(h)

static func _line(parent: Control, text: String, col := UI.INK2) -> void:
	parent.add_child(UI.label(text, 14, col, null, true))

# ----------------------------------------------------------------------------------------------- Varieties
static func _varieties(P: Dictionary, cat: Dictionary) -> Control:
	var row := UI.hbox(12)
	var huglin := float(P["huglin"])
	for vv in cat["varieties"]:
		var c := _card(String(vv["name"]), ("red" if vv["red"] else "white") + " · " + String(vv["note"]), Color("e7a3b0") if vv["red"] else Color("e9dc9a"))
		var bb := float(vv["budburstGdd"])
		_bar(c[1], "Budburst", inverse_lerp(210.0, 140.0, bb), "early" if bb < 165 else ("mid" if bb < 195 else "late"), false)
		var rip := float(vv["ripeningNeed"])
		_bar(c[1], "Ripening", inverse_lerp(2650.0, 3150.0, rip), "early" if rip < 2750 else ("mid" if rip < 3000 else "late"), false)
		_bar(c[1], "Bunch density", inverse_lerp(0.6, 1.5, float(vv["compactness"])), "compact" if float(vv["compactness"]) > 1.1 else "loose", false)
		if vv["red"]:
			_bar(c[1], "Colour", inverse_lerp(0.3, 1.5, float(vv["colour"])), "light" if float(vv["colour"]) < 0.8 else "deep")
			_bar(c[1], "Tannin", inverse_lerp(0.3, 1.2, float(vv["tannin"])), "soft" if float(vv["tannin"]) < 0.6 else "firm")
		var need := float(vv["heatNeed"])
		var fit := "ripens comfortably here" if huglin >= need + 150 else ("ripens in average-to-warm years" if huglin >= need - 100 else "struggles to ripen here")
		var fcol := UI.GOOD if huglin >= need + 150 else (UI.WARN if huglin >= need - 100 else UI.CRIT)
		_line(c[1], "Needs a Huglin index of about %d. This Plot averages %d: %s." % [need, huglin, fit], fcol)
		var extra := []
		if bb < 165: extra.append("Early budburst means more spring-frost risk.")
		if float(vv["compactness"]) > 1.1: extra.append("Tight bunches stay wet after rain, so grey rot spreads faster.")
		if float(vv["pyrazine"]) > 5: extra.append("Tastes green (pyrazine, bell pepper) when picked underripe or shaded.")
		if float(vv["coulure"]) >= 0.5 or float(vv["millerandage"]) >= 0.5: extra.append("Cold, wet weather at flowering gives uneven fruit set.")
		for e in extra: _line(c[1], "·  " + e, UI.MUTED)
		row.add_child(c[0])
	return row

# ----------------------------------------------------------------------------------------------- Rootstocks
static func _rootstocks(P: Dictionary, cat: Dictionary) -> Control:
	var v := UI.vbox(10)
	_line(v, "Since phylloxera (a root louse) destroyed Europe's vineyards in the 1800s, vines are grafted onto American rootstocks. The rootstock decides how deep the roots go, how vigorous the vine is, how it copes with drought, and whether limy soil turns its leaves yellow (chlorosis).")
	var max_lime := 0.0; var min_taw := 999.0
	for b in P["blocks"]:
		max_lime = maxf(max_lime, float(b["lime"])); min_taw = minf(min_taw, float(b["taw"]))
	var row := UI.hbox(12)
	for rs in cat["rootstocks"]:
		var c := _card(String(rs["name"]), "resists phylloxera" if rs["phylloxera"] else "NO phylloxera resistance", UI.INK)
		_bar(c[1], "Vigour", inverse_lerp(0.75, 1.2, float(rs["vigour"])), "low" if float(rs["vigour"]) < 0.95 else ("high" if float(rs["vigour"]) > 1.1 else "moderate"), false)
		_bar(c[1], "Root depth", inverse_lerp(0.7, 1.3, float(rs["rootDepth"])), "shallow" if float(rs["rootDepth"]) < 0.9 else ("deep" if float(rs["rootDepth"]) > 1.1 else "medium"))
		_bar(c[1], "Drought", inverse_lerp(-0.25, 0.25, float(rs["drought"])), "tolerant" if float(rs["drought"]) > 0.1 else ("sensitive" if float(rs["drought"]) < -0.1 else "moderate"))
		var lime := float(rs["lime"])
		_bar(c[1], "Lime tolerance", clampf(log(lime) / log(200.0), 0, 1), "very high" if lime >= 100 else ("good" if lime >= 25 else "poor"))
		_line(c[1], String(rs["note"]), UI.MUTED)
		# suitability hints for this Plot
		var hints := []
		if max_lime >= 12 and lime < 60: hints.append(["⚠ up to %d %% active lime here: chlorosis risk" % int(max_lime), UI.SERIOUS])
		if min_taw < 90 and float(rs["drought"]) < 0: hints.append(["⚠ shallow, dry Blocks here: drought stress", UI.SERIOUS])
		if not rs["phylloxera"]: hints.append(["⚠ roots slowly die from phylloxera (multi-year risk)", UI.SERIOUS])
		if hints.is_empty(): hints.append(["✓ no warning for this Plot", UI.GOOD])
		for hh in hints: _line(c[1], hh[0], hh[1])
		row.add_child(c[0])
	v.add_child(row)
	return v

# ----------------------------------------------------------------------------------------------- Training
static func _training(P: Dictionary) -> Control:
	var allowed: Array = P["training"]
	var row := UI.hbox(12)
	var specs := [
		["Einzelpfahl", "single stake · Mosel steep slopes", "Each vine has its own stake. Two canes are bent into heart-shaped bows and tied to it. There are no wires, so it works on slopes far too steep for a trellis, and everything is done by hand (1,000+ hours per hectare). Good air flow keeps bunches dry. Usually planted densely (6,000–10,000 vines/ha)."],
		["Guyot", "cane pruning on a wire trellis (VSP)", "Each winter you keep one cane (double Guyot: two) of 8–12 buds and tie it along a low wire, plus a short spur that grows next year's cane. Shoots grow straight up between wires. It is the standard in Burgundy and much of Germany, suits cool climates, and needs skilled pruning."],
		["Cordon", "spur pruning on a permanent arm (VSP)", "The trunk carries a permanent horizontal arm (the cordon) along the wire, with short 2-bud spurs every 15–20 cm. Winter pruning is quick and can be partly done by machine. Common in Napa and in warm regions; it suits Varieties whose lowest buds are fruitful."],
	]
	for sp in specs:
		var ok: bool = sp[0] in allowed
		var c := _card(String(sp[0]), String(sp[1]), UI.INK if ok else UI.MUTED)
		var d = TrainingDiagram.new(); d.kind = String(sp[0]); d.custom_minimum_size = Vector2(0, 170)
		c[1].add_child(d)
		_line(c[1], String(sp[2]))
		_line(c[1], "✓ possible on %s" % P["name"] if ok else "✕ not used on this Plot (slope or local practice)", UI.GOOD if ok else UI.MUTED)
		row.add_child(c[0])
	return row

class TrainingDiagram extends Control:
	var kind := "Guyot"
	func _draw() -> void:
		var w := size.x; var h := size.y
		var ground := h - 18.0
		var soil := Color("5a4533"); var wood := Color("6b4a2e"); var wire := Color("9aa3a8"); var leaf := Color("4f8f3e"); var post := Color("8a7a66")
		draw_rect(Rect2(0, ground, w, h - ground), soil)
		var cx := w / 2.0
		match kind:
			"Einzelpfahl":
				draw_line(Vector2(cx, ground + 6), Vector2(cx, ground - 140), post, 5.0)
				draw_line(Vector2(cx - 4, ground), Vector2(cx - 4, ground - 70), wood, 7.0)
				for side in [-1, 1]:
					var pts := PackedVector2Array()
					for i in 21:
						var t := float(i) / 20.0
						var a := PI * t
						pts.append(Vector2(cx - 4 + side * sin(a) * 38.0, ground - 70 - 45.0 * (1 - cos(a)) * 0.5 - 40.0 * sin(a) * 0.6))
					draw_polyline(pts, wood, 4.0, true)
					for i in range(3, 20, 4):
						var p: Vector2 = pts[i]
						draw_line(p, p + Vector2(side * 10, -30), leaf, 3.0)
						draw_circle(p + Vector2(side * 10, -32), 7.0, leaf)
			"Guyot", "Cordon":
				for px in [cx - 110, cx + 110]: draw_line(Vector2(px, ground + 6), Vector2(px, ground - 140), post, 5.0)
				for wy in [ground - 55, ground - 95, ground - 130]: draw_line(Vector2(cx - 115, wy), Vector2(cx + 115, wy), wire, 1.5)
				draw_line(Vector2(cx - 40, ground), Vector2(cx - 40, ground - 55), wood, 8.0)
				if kind == "Guyot":
					draw_line(Vector2(cx - 40, ground - 55), Vector2(cx + 90, ground - 55), wood, 4.0)     # this year's cane
					draw_line(Vector2(cx - 40, ground - 55), Vector2(cx - 52, ground - 68), wood, 4.0)     # renewal spur
					for i in 7:
						var x := cx - 25 + i * 18.0
						draw_line(Vector2(x, ground - 55), Vector2(x + 2, ground - 128), leaf, 3.0)
						draw_circle(Vector2(x + 2, ground - 100), 8.0, leaf); draw_circle(Vector2(x + 2, ground - 125), 7.0, leaf)
					draw_string(UI.f_body, Vector2(cx + 20, ground - 40), "cane (renewed yearly)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.INK2)
				else:
					draw_line(Vector2(cx - 100, ground - 55), Vector2(cx + 100, ground - 55), wood, 7.0)   # permanent cordon
					for i in 6:
						var x := cx - 90 + i * 36.0
						draw_line(Vector2(x, ground - 57), Vector2(x, ground - 64), wood, 4.0)
						draw_line(Vector2(x, ground - 64), Vector2(x + 2, ground - 128), leaf, 3.0)
						draw_circle(Vector2(x + 2, ground - 100), 8.0, leaf); draw_circle(Vector2(x + 2, ground - 125), 7.0, leaf)
					draw_string(UI.f_body, Vector2(cx - 100, ground - 36), "permanent arm with short spurs", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.INK2)

# ----------------------------------------------------------------------------------------------- Density & rows
static func _density(P: Dictionary) -> Control:
	var row := UI.hbox(12)
	for dens in [3800, 6500, 10000]:
		var c := _card("%s vines/ha" % UI.thousands(dens), {3800: "Napa, machine-worked", 6500: "a middle way", 10000: "Burgundy, high density"}[dens])
		var d = DensityDiagram.new(); d.density = dens; d.custom_minimum_size = Vector2(0, 170)
		c[1].add_child(d)
		_line(c[1], {3800: "Bigger vines, wide rows for tractors, cheaper to plant. Each vine carries more fruit, so ripening depends on a big, healthy canopy.",
			6500: "Common on German slopes and in many New World vineyards.",
			10000: "Many small vines: each carries little fruit, and roots compete and go deep. The classic Burgundian view is that this gives more concentrated wines. Planting and pruning cost more, and Village and Premier Cru rules require at least 9,000 vines/ha."}[dens])
		row.add_child(c[0])
	var rc := _card("Row direction", "")
	_line(rc[1], "N–S rows: both sides of the canopy get sun (east in the morning, west in the hot afternoon), so ripening is even.")
	_line(rc[1], "E–W rows: the north side stays shaded all day. Cooler bunches, but uneven ripening in cool climates.")
	_line(rc[1], "Steep slopes (≥ 30 %): rows must run straight downhill, for safety and for the winch. The game locks this for you.")
	row.add_child(rc[0])
	return row

class DensityDiagram extends Control:
	var density := 5000
	func _draw() -> void:
		# a 10 m × 10 m patch seen from above: one dot per vine
		var side := minf(size.x, size.y) - 20.0
		var o := Vector2((size.x - side) / 2.0, 10)
		draw_rect(Rect2(o, Vector2(side, side)), Color("5a4533"))
		var row_m := 2.5 if density < 5000 else (1.8 if density < 8000 else 1.0)
		var vine_m := 10000.0 / (density * row_m)
		var y := row_m / 2.0
		while y < 10.0:
			var yy := o.y + side * y / 10.0
			draw_line(Vector2(o.x, yy), Vector2(o.x + side, yy), Color(1, 1, 1, 0.12), 1.0)
			var x := vine_m / 2.0
			while x < 10.0:
				draw_circle(Vector2(o.x + side * x / 10.0, yy), 3.5, Color("5e9d45"))
				x += vine_m
			y += row_m
		draw_string(UI.f_body, o + Vector2(0, side + 14), "10 m × 10 m · rows %.1f m apart" % row_m, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.INK2)
