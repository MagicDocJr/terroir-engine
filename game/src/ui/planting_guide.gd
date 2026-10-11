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
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL; c.custom_minimum_size = Vector2(330, 0)
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
	var row := UI.flow(12, 12)
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
	var row := UI.flow(12, 12)
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
	var col := UI.vbox(12)
	var specs := [
		["Einzelpfahl", "single stake · Mosel steep slopes", "Each vine has its own stake. One or two canes are bent into heart-shaped bows and tied to it. There are no wires, so it works on slopes far too steep for a trellis, and everything is done by hand (1,000+ hours per hectare). Good air flow keeps bunches dry. Usually planted densely (6,000–10,000 vines/ha)."],
		["Guyot", "cane pruning on a wire trellis (VSP)", "Each winter you keep one cane (double Guyot: two) of 8–12 buds and tie it along the fruiting wire, plus a short spur that grows next year's cane. Shoots are trained straight up between catch wires. It is the standard in Burgundy and much of Germany, suits cool climates, and needs skilled pruning."],
		["Cordon", "spur pruning on a permanent arm (VSP)", "The trunk carries a permanent horizontal arm (the cordon) along the wire, with short 2-bud spurs every 15–20 cm. Winter pruning is quick and can be partly done by machine. Common in Napa and in warm regions; it suits Varieties whose lowest buds are fruitful."],
	]
	for sp in specs:
		var ok: bool = sp[0] in allowed
		var c := _card(String(sp[0]), String(sp[1]), UI.INK if ok else UI.MUTED)
		var fl := UI.flow(12, 10); c[1].add_child(fl)
		for season in ["Winter", "Summer"]:
			var d = TrainingDiagram.new(); d.kind = String(sp[0]); d.season = season; d.custom_minimum_size = Vector2(440, 330)
			d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fl.add_child(d)
		var txt := UI.vbox(6); txt.custom_minimum_size = Vector2(380, 0); txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_line(txt, String(sp[2]))
		_line(txt, "✓ possible on %s" % P["name"] if ok else "✕ not used on this Plot (slope or local practice)", UI.GOOD if ok else UI.MUTED)
		fl.add_child(txt)
		col.add_child(c[0])
	return col

## A side view of one vine in its training system, in winter (pruned wood with its buds) or summer (shoots, leaves and
## bunches), with the parts named. Proportions follow the game's vine models (build_vineyard.py: Guyot fruiting wire
## 0.80 m and canopy top 1.75 m; Cordon 0.95 m and 1.95 m; Einzelpfahl stake about 1.85 m, head 0.6 m).
class TrainingDiagram extends Control:
	var kind := "Guyot"
	var season := "Winter"
	var _k := 100.0          # pixels per metre
	var _o := Vector2.ZERO   # ground under the trunk
	const BARK := Color("6e4a2c")
	const BARK_D := Color("3e2817")
	const STAKE := Color("9a8466")
	const WIREC := Color("a9b2b8")
	const BUD := Color("4a2f1b")

	func _P(x: float, y: float) -> Vector2: return _o + Vector2(x * _k, -y * _k)

	func _draw() -> void:
		var w := size.x; var h := size.y
		_k = minf(w * 0.52 / 2.35, (h - 34.0) / 2.15)       # the vine in the middle half, its parts' names in the margins
		_o = Vector2(w * 0.5, h - 20.0)
		# soil
		draw_rect(Rect2(0, _o.y, w, h - _o.y), Color("4a382a"))
		draw_rect(Rect2(0, _o.y, w, 3), Color("6a5139"))
		var rng := RandomNumberGenerator.new(); rng.seed = 5
		for i in 26:
			draw_circle(Vector2(rng.randf() * w, _o.y + 5 + rng.randf() * (h - _o.y - 8)), 1.2 + rng.randf() * 1.6, Color("5e4a38"))
		var summer := season == "Summer"
		match kind:
			"Einzelpfahl": _einzelpfahl(summer)
			"Cordon": _vsp(0.95, 1.95, summer, false)
			_: _vsp(0.80, 1.75, summer, true)
		_draw_notes()
		draw_string(UI.f_body_b, Vector2(8, 16), "Winter · pruned" if not summer else "Summer · in leaf", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.GOLD)

	# ---- shared pieces
	func _curve(pts: Array, n := 6) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in pts.size() - 1:
			var p0: Vector2 = pts[maxi(i - 1, 0)]; var p1: Vector2 = pts[i]; var p2: Vector2 = pts[i + 1]; var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
			for j in n:
				var t := float(j) / n
				out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
		out.append(pts[-1])
		return out

	func _wood(pts: PackedVector2Array, w0: float, w1: float) -> void:
		for i in pts.size() - 1:
			var f := float(i) / maxf(1.0, pts.size() - 2)
			draw_line(pts[i], pts[i + 1], BARK_D, lerpf(w0, w1, f) + 2.0, true)
		for i in pts.size() - 1:
			var f := float(i) / maxf(1.0, pts.size() - 2)
			draw_line(pts[i], pts[i + 1], BARK, lerpf(w0, w1, f), true)

	func _bud(p: Vector2, up := Vector2(0, -1)) -> void:
		var r := maxf(3.0, _k * 0.026)                      # drawn larger than life so they can be counted
		draw_circle(p + up * r * 0.6, r, BUD)
		draw_circle(p + up * r * 0.6 + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color("8a6448"))

	func _leaf(c: Vector2, r: float, ang: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 25:
			var a := TAU * float(i) / 25.0
			var lobe := 0.78 + 0.22 * absf(cos(2.5 * a))
			var notch := 0.6 if absf(wrapf(a - PI / 2.0, -PI, PI)) < 0.22 else 1.0
			pts.append(c + Vector2(cos(a + ang), sin(a + ang)) * r * lobe * notch)
		draw_colored_polygon(pts, col)
		var edge := pts.duplicate(); edge.append(pts[0])
		draw_polyline(edge, col.darkened(0.35), 1.0, true)
		draw_line(c, c + Vector2(cos(ang - PI / 2.0), sin(ang - PI / 2.0)) * r * 0.7, col.lightened(0.18), 1.0, true)

	func _bunch(top: Vector2, s: float) -> void:
		var rng := RandomNumberGenerator.new(); rng.seed = int(top.x * 7.0 + top.y)
		var r := maxf(2.3, _k * 0.016) * s
		draw_line(top, top + Vector2(0, r * 1.5), Color("6b7a2e"), 1.5)
		for row in 6:
			var n := 4 - row / 2
			for j in n:
				var p := top + Vector2((j - (n - 1) / 2.0) * r * 1.5 + rng.randf_range(-1, 1), r * 2.0 + row * r * 1.35)
				draw_circle(p, r, Color("8fa53e").darkened(rng.randf() * 0.25))
				draw_circle(p + Vector2(-r * 0.35, -r * 0.35), r * 0.3, Color(1, 1, 1, 0.25))

	func _shoot(base: Vector2, top_y: float, lean: float, seed_i: int, bunches: int) -> void:
		var rng := RandomNumberGenerator.new(); rng.seed = seed_i * 31 + 3
		var tip := Vector2(base.x + lean * _k, _o.y - top_y * _k)
		var pts := _curve([base, base.lerp(tip, 0.45) + Vector2(rng.randf_range(-4, 4), 0), tip], 6)
		draw_polyline(pts, Color("7d8a3a"), maxf(1.5, _k * 0.012), true)
		var n := 6
		for i in range(1, n + 1):
			var f := float(i) / n
			var p := pts[int(f * (pts.size() - 1))]
			var side := 1.0 if i % 2 == 0 else -1.0
			var col := Color("3f7d32").lerp(Color("6aa84a"), rng.randf() * 0.6 + f * 0.3)
			_leaf(p + Vector2(side * _k * 0.06, 0), _k * rng.randf_range(0.065, 0.085) * (1.1 - 0.35 * f), rng.randf_range(-0.5, 0.5), col)
			if i <= bunches and i >= 1:
				_bunch(p + Vector2(-side * _k * 0.03, 0), 1.0)

	var _notes := []

	## A part's name: collected while drawing, laid out at the end in a column at the left or right edge.
	func _note(at: Vector2, text: String, side: String) -> void:
		_notes.append([at, text, side])

	func _draw_notes() -> void:
		var f: Font = UI.f_body
		var fs := 12
		var maxw := maxf(90.0, (size.x - 2.35 * _k) * 0.5 - 14.0)
		for side in ["L", "R"]:
			var items := _notes.filter(func(n): return n[2] == side)
			items.sort_custom(func(x, y): return x[0].y < y[0].y)
			var y_min := 26.0
			for it in items:
				var sz := f.get_multiline_string_size(String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, maxw, fs)
				var y := maxf(y_min, clampf((it[0] as Vector2).y - sz.y * 0.5, 26.0, _o.y - sz.y - 4.0))
				y_min = y + sz.y + 8.0
				var x := 6.0 if side == "L" else size.x - sz.x - 6.0
				var r := Rect2(Vector2(x - 4, y - 2), sz + Vector2(8, 4))
				var edge := Vector2(r.end.x if side == "L" else r.position.x, y + sz.y * 0.5)
				draw_line(edge, it[0], Color(1, 0.94, 0.78, 0.7), 1.0, true)
				draw_circle(it[0], 2.6, UI.GOLD)
				draw_style_box(UI.sb(Color(0.08, 0.1, 0.12, 0.82), 4, Color(0, 0, 0, 0), 0, 0), r)
				draw_multiline_string(f, Vector2(x, y + f.get_ascent(fs)), String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, maxw, fs, -1, UI.INK)
		_notes.clear()

	# ---- Guyot (cane) and Cordon (spurs) on a VSP trellis
	func _vsp(hw: float, top: float, summer: bool, guyot: bool) -> void:
		for px in [-1.12, 1.12]:
			draw_line(_P(px, -0.05), _P(px, top + 0.2), STAKE.darkened(0.35), maxf(5.0, _k * 0.05) + 2.0)
			draw_line(_P(px, -0.05), _P(px, top + 0.2), STAKE, maxf(5.0, _k * 0.05))
		for wy in [hw + 0.33, hw + 0.66, top - 0.05]:
			draw_line(_P(-1.12, wy), _P(1.12, wy), WIREC.darkened(0.25), 1.0, true)
		draw_line(_P(-1.12, hw), _P(1.12, hw), WIREC, 1.8, true)
		var head := hw - (0.08 if guyot else 0.03)
		_wood(_curve([_P(0.0, 0.0), _P(0.015, head * 0.35), _P(-0.012, head * 0.7), _P(0.0, head)], 5), maxf(7.0, _k * 0.06), maxf(5.0, _k * 0.045))
		var buds := []
		if guyot:
			var cane := _curve([_P(0, head), _P(0.06, hw + 0.08), _P(0.17, hw + 0.01), _P(0.45, hw), _P(0.86, hw)], 6)
			_wood(cane, maxf(3.5, _k * 0.026), maxf(2.2, _k * 0.016))
			var spur := _curve([_P(0, head), _P(-0.04, hw), _P(-0.07, hw + 0.06)], 4)
			_wood(spur, maxf(3.5, _k * 0.028), maxf(3.0, _k * 0.024))
			for i in 9:
				buds.append(_P(0.24 + 0.075 * i, hw))
			buds.append(_P(-0.05, hw + 0.025)); buds.append(_P(-0.07, hw + 0.06))
			for x in [0.3, 0.6, 0.84]:
				draw_line(_P(x, hw) + Vector2(-1, -4), _P(x, hw) + Vector2(1, 4), Color(0.95, 0.95, 0.85), 1.5)
		else:
			for sgn in [-1.0, 1.0]:
				var arm := _curve([_P(0, head), _P(sgn * 0.09, hw + 0.01), _P(sgn * 0.35, hw), _P(sgn * 0.62, hw)], 6)
				_wood(arm, maxf(5.5, _k * 0.042), maxf(3.5, _k * 0.03))
				for i in 4:
					var x: float = sgn * (0.15 + 0.15 * i)
					var sp := _curve([_P(x, hw), _P(x + 0.005, hw + 0.06)], 2)
					_wood(sp, maxf(3.5, _k * 0.026), maxf(3.0, _k * 0.022))
					buds.append(_P(x + 0.008, hw + 0.03)); buds.append(_P(x + 0.004, hw + 0.06))
		if summer:
			var i := 0
			for b in buds:
				_shoot(b, top - 0.02, 0.04 * sin(i * 1.7), i, 2)
				i += 1
		else:
			for b in buds: _bud(b)
		# names
		if summer:
			_note(_P(0.3, top - 0.25), "shoots trained upright between catch wires (VSP)", "R")
			_note(_P(0.22, hw + 0.1), "fruit zone: bunches just above the wire", "R")
			_note(_P(-0.95, hw), "fruiting wire", "L")
		elif guyot:
			_note(_P(0.55, hw), "cane: 8–12 buds, a new one every winter", "R")
			_note(_P(-0.07, hw + 0.06), "renewal spur: 2 buds", "L")
			_note(_P(0.01, 0.3), "trunk", "L")
			_note(_P(-0.95, hw), "fruiting wire", "L")
		else:
			_note(_P(0.5, hw), "cordon: a permanent arm", "R")
			_note(_P(-0.3, hw + 0.06), "spurs of 2 buds, every 15–20 cm", "L")
			_note(_P(0.01, 0.35), "trunk", "L")

	# ---- Einzelpfahl: one stake per vine, two bows (the "heart")
	func _einzelpfahl(summer: bool) -> void:
		draw_line(_P(0.0, -0.05), _P(0.0, 1.85), STAKE.darkened(0.35), maxf(5.0, _k * 0.05) + 2.0)
		draw_line(_P(0.0, -0.05), _P(0.0, 1.85), STAKE, maxf(5.0, _k * 0.05))
		var head := 0.62
		_wood(_curve([_P(0.05, 0.0), _P(0.07, head * 0.4), _P(0.04, head * 0.75), _P(0.03, head)], 5), maxf(7.0, _k * 0.06), maxf(5.0, _k * 0.045))
		var buds := []
		for sgn in [-1.0, 1.0]:
			var bow := _curve([_P(0.03, head), _P(0.03 + sgn * 0.06, head + 0.26), _P(sgn * 0.24, head + 0.38), _P(sgn * 0.36, head + 0.16), _P(sgn * 0.22, head - 0.05), _P(sgn * 0.035, head - 0.10)], 6)
			_wood(bow, maxf(3.5, _k * 0.026), maxf(2.6, _k * 0.02))
			for i in 7:
				buds.append(bow[int((0.12 + 0.11 * i) * (bow.size() - 1))])
		# ties
		for y in [head - 0.1, head + 0.05]:
			draw_line(_P(-0.04, y), _P(0.04, y), Color(0.95, 0.95, 0.85), 1.5)
		if summer:
			var i := 0
			for b in buds:
				var out := 1.0 if (b as Vector2).x > _o.x else -1.0
				_shoot(b, 1.95, out * (0.18 + 0.05 * (i % 3)), i + 40, 2 if i % 7 in [1, 2] else 0)
				i += 1
			_note(_P(0.4, 1.5), "shoots fan out all round: air and light reach the bunches", "R")
			_note(_P(0.0, 1.85), "stake, no wires", "L")
		else:
			for b in buds: _bud(b)
			_note(_P(0.36, head + 0.16), "bow: a cane bent round and tied to the stake", "R")
			_note(_P(0.0, 1.5), "stake: one per vine, no wires", "L")
			_note(_P(0.05, 0.3), "trunk", "L")

# ----------------------------------------------------------------------------------------------- Density & rows
static func _density(P: Dictionary) -> Control:
	var row := UI.flow(12, 12)
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
