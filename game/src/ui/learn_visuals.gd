# Visuals for learn cards (learning-core design §7.3). Each one shows something text alone cannot: the game's own vine in each
# training system as a slow 3D turntable (winter wood or summer canopy), rootstock traits side by side, a Block's ripening
# curves, the fruit-zone sun by side, malic turning into lactic acid, and which oak gives which aromas. No decorative pictures.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const A := preload("res://src/view3d/assets3d.gd")

static func build(shell, J: Dictionary) -> Control:
	match String(J.get("visual", "none")):
		"turntable-training": return _turntable(shell, J)
		"rootstock-roots": return _rootstocks(J.get("visualData", {}))
		"ripening-curves": return _ripening(J.get("visualData", {}))
		"canopy-exposure": return _exposure()
		"berry-temperature": return _berry(J.get("visualData", {}))
		"ripening-capacity": return _capacity(J.get("visualData", {}))
		"malic-to-lactic": return _mlf(J.get("visualData", null))
		"oak-aromas": return _oak(J.get("visualData", null))
	return null

# ------------------------------------------------------------------ training systems: the game's own vines, named
static func _turntable(shell, J: Dictionary) -> Control:
	var kind: String = shell.state.get("learn_training", "Guyot")
	var season: String = shell.state.get("learn_season", "Summer")
	var TM = load("res://src/ui/training_model.gd")
	if not TM.available():
		# no 3D assets (a build without game/assets3d): the drawings, winter and summer side by side
		var v := UI.vbox(8)
		v.add_child(UI.segmented(["Einzelpfahl", "Guyot", "Cordon"], kind, func(x): shell.state["learn_training"] = x; shell.reopen_learn(), 110))
		var row := UI.hbox(10); v.add_child(row)
		for s in ["Winter", "Summer"]:
			var d = load("res://src/ui/planting_guide.gd").TrainingDiagram.new(); d.kind = kind; d.season = s; d.custom_minimum_size = Vector2(0, 240)
			d.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(d)
		return v
	var m = TM.new()
	m.kind = kind; m.season = season; m.variety = _variety(shell)
	m.on_change = func(k, s): shell.state["learn_training"] = k; shell.state["learn_season"] = s   # changes in place: the card keeps its scroll
	return m

## The Variety on the card's Block (the game's Block, or the Planting screen's choice), for the leaves.
static func _variety(shell) -> String:
	var ctx: Dictionary = shell._learn_open[1] if shell._learn_open[1] is Dictionary else {}
	var bid := String(ctx.get("block", ""))
	if Sim.HasGame():
		for b in shell.D.get("blocks", []):
			if String(b.get("id", "")) == bid: return String(b.get("variety", "Riesling"))
	var pc: Dictionary = shell.setup.get("planting", {}).get(bid, {})
	for x in shell.CAT.get("varieties", []):
		if String(x.get("id", "")) == String(pc.get("variety", "")): return String(x.get("name", "Riesling"))
	return "Riesling"

# ------------------------------------------------------------------ rootstocks side by side
static func _rootstocks(D) -> Control:
	var v := UI.vbox(6)
	var rows: Array = D.get("rows", []) if D is Dictionary else []
	var bi = D.get("blockIndex", null) if D is Dictionary else null
	var head := UI.hbox(10)
	for t in [["Rootstock", 110], ["Root depth", 110], ["Vigour", 110], ["Drought", 110], ["Lime tolerance", 170]]:
		var l := UI.label(t[0], 13, UI.MUTED); l.custom_minimum_size = Vector2(t[1], 0); head.add_child(l)
	v.add_child(head)
	for r in rows:
		var h := UI.hbox(10)
		var nl := UI.label(String(r["name"]), 14, UI.INK, UI.f_body_b); nl.custom_minimum_size = Vector2(110, 0); h.add_child(nl)
		h.add_child(_bar(float(r["depth"]) / 1.3, "%.2f×" % float(r["depth"]), 110))
		h.add_child(_bar(float(r["vigour"]) / 1.3, "%.2f×" % float(r["vigour"]), 110))
		h.add_child(_bar(clampf((float(r["drought"]) + 0.2) / 0.4, 0, 1), ("+" if float(r["drought"]) > 0 else "") + "%.1f" % float(r["drought"]), 110))
		var ok: bool = bi == null or float(bi) <= 0.8 * float(r["lime"])
		h.add_child(_bar(minf(1.0, float(r["lime"]) / 120.0), str(int(r["lime"])) + ("" if ok else "  yellows here"), 170))
		v.add_child(h)
	v.add_child(UI.label(("This Block: chlorosis index about %d in this game. " % int(bi) if bi != null else "") + "Drought: how much drier the soil can get before the vine stresses (MPa, + is tolerant). Own-rooted vines are left out: they have no phylloxera resistance.", 12, UI.MUTED, null, true))
	return v

static func _bar(frac: float, text: String, w: float) -> Control:
	var h := UI.hbox(6); h.custom_minimum_size = Vector2(w, 0)
	var m := ProgressBar.new(); m.show_percentage = false; m.max_value = 1.0; m.value = clampf(frac, 0, 1)
	m.custom_minimum_size = Vector2(w - 60, 10); m.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(m)
	h.add_child(UI.label(text, 12, UI.MUTED))
	return h

# ------------------------------------------------------------------ a Block's ripening (or the general shape)
class Curves extends Control:
	var samples := []
	var lines := []
	func _draw() -> void:
		var r := Rect2(Vector2(44, 10), size - Vector2(54, 34))
		draw_rect(r, Color("182026"))
		var n := samples.size()
		var font := ThemeDB.fallback_font
		if n < 2:
			# the general shape: sugar climbs and levels off, acid falls fast then slowly, seeds brown; the window is where they meet the targets
			var pts_s := PackedVector2Array(); var pts_a := PackedVector2Array(); var pts_k := PackedVector2Array()
			for i in 41:
				var x := float(i) / 40.0
				pts_s.append(r.position + Vector2(x * r.size.x, r.size.y * (1.0 - (1.0 - exp(-3.0 * x)) * 0.95)))
				pts_a.append(r.position + Vector2(x * r.size.x, r.size.y * (0.1 + 0.75 * (1.0 - exp(-3.0 * x)))))
				pts_k.append(r.position + Vector2(x * r.size.x, r.size.y * (1.0 - clampf((x - 0.2) * 1.4, 0, 1) * 0.9)))
			draw_polyline(pts_s, Color("d9b24c"), 2.5, true); draw_polyline(pts_a, Color("5fa8d3"), 2.5, true); draw_polyline(pts_k, Color("9fb86a"), 2.0, true)
			draw_rect(Rect2(r.position + Vector2(r.size.x * 0.62, 0), Vector2(r.size.x * 0.2, r.size.y)), Color(1, 1, 1, 0.06))
			draw_string(font, r.position + Vector2(r.size.x * 0.63, 14), "pick window", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.6))
			draw_string(font, Vector2(4, size.y - 6), "véraison → harvest (shape only)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))
			return
		# absolute axes: sugar 40–110 °Oe (left), acidity 4–20 g/L (same box, right labels); seeds 0–100 %
		var oe_lo := 40.0; var oe_hi := 110.0; var ta_lo := 4.0; var ta_hi := 20.0
		var Y_oe := func(o): return r.position.y + r.size.y * (1.0 - clampf((float(o) - oe_lo) / (oe_hi - oe_lo), 0, 1))
		var Y_ta := func(t): return r.position.y + r.size.y * (1.0 - clampf((float(t) - ta_lo) / (ta_hi - ta_lo), 0, 1))
		for L in lines:
			var y: float = Y_oe.call(L["oe"])
			draw_dashed_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.85, 0.7, 0.3, 0.45), 1.0, 6.0)
			draw_string(font, Vector2(r.position.x + 4, y - 3), "%s %d" % [L["name"], int(L["oe"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.7, 0.3, 0.8))
		var po := PackedVector2Array(); var pt := PackedVector2Array(); var pk := PackedVector2Array()
		for i in n:
			var x := r.position.x + r.size.x * float(i) / float(n - 1)
			po.append(Vector2(x, Y_oe.call(samples[i]["oe"]))); pt.append(Vector2(x, Y_ta.call(samples[i]["ta"])))
			pk.append(Vector2(x, r.position.y + r.size.y * (1.0 - float(samples[i]["seed"]))))
		draw_polyline(po, Color("d9b24c"), 2.5, true); draw_polyline(pt, Color("5fa8d3"), 2.5, true); draw_polyline(pk, Color("9fb86a"), 2.0, true)
		draw_circle(po[n - 1], 4, Color("d9b24c")); draw_string(font, po[n - 1] + Vector2(-60, -8), "today %d °Oe" % int(samples[n - 1]["oe"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d9b24c"))
		for o in [50, 70, 90, 110]: draw_string(font, Vector2(4, Y_oe.call(o) + 4), str(o), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d9b24c", 0.7))
		draw_string(font, Vector2(4, size.y - 6), "%s → %s" % [samples[0]["date"], samples[n - 1]["date"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))

static func _ripening(D) -> Control:
	var v := UI.vbox(4)
	var samples = D.get("samples", []) if D is Dictionary else []
	var c := Curves.new(); c.samples = samples; c.lines = D.get("lines", []) if D is Dictionary else []; c.custom_minimum_size = Vector2(0, 210)
	v.add_child(c)
	var key := UI.hbox(14); v.add_child(key)
	for k in [["sugar (°Oe)", Color("d9b24c")], ["acidity (4–20 g/L)", Color("5fa8d3")], ["seed ripeness", Color("9fb86a")]]: key.add_child(UI.label("■ " + k[0], 13, k[1]))
	key.add_child(UI.label("this Block's weekly samples" if samples.size() > 1 else "the typical shape (open from a Block to see its own)", 12, UI.MUTED))
	return v

# ------------------------------------------------------------------ the fruit zone and the sun
class Exposure extends Control:
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var w := size.x; var h := size.y
		var cx := w * 0.5
		draw_rect(Rect2(Vector2(0, h - 18), Vector2(w, 18)), Color("4a3b2a"))
		draw_rect(Rect2(Vector2(cx - 4, h * 0.25), Vector2(8, h * 0.75 - 18)), Color("6b5236"))
		draw_rect(Rect2(Vector2(cx - 46, h * 0.12), Vector2(92, h * 0.42)), Color("3f7d4e"))   # canopy
		for i in 3:
			draw_circle(Vector2(cx - 22 + i * 22, h * 0.62), 9, Color("6b2a4a"))              # fruit zone
		draw_rect(Rect2(Vector2(cx - 50, h * 0.55), Vector2(100, h * 0.16)), Color(1, 1, 1, 0.08))
		draw_circle(Vector2(w * 0.12, h * 0.25), 16, Color("f2d27a")); draw_string(font, Vector2(w * 0.04, h * 0.25 + 34), "morning sun (east)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.75))
		draw_circle(Vector2(w * 0.88, h * 0.25), 20, Color("f5a54a")); draw_string(font, Vector2(w * 0.70, h * 0.25 + 38), "afternoon sun (west), hotter", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.75))
		draw_line(Vector2(w * 0.14, h * 0.3), Vector2(cx - 50, h * 0.6), Color("f2d27a", 0.6), 2.0)
		draw_line(Vector2(w * 0.86, h * 0.3), Vector2(cx + 50, h * 0.6), Color("f5a54a", 0.8), 3.0)
		draw_string(font, Vector2(cx - 44, h * 0.55 - 6), "fruit zone", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.7))

static func _exposure() -> Control:
	var e := Exposure.new(); e.custom_minimum_size = Vector2(0, 220)
	return e

# ------------------------------------------------------------------ malolactic conversion
static func _mlf(d) -> Control:
	var v := UI.vbox(6)
	var h := UI.hbox(18); v.add_child(h)
	for side in [["before", "malic acid", "sharp, green-apple acid", Color("9fb86a")], ["after", "lactic acid", "softer, milky acid", Color("e6dcc0")]]:
		var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", UI.sb(Color(side[3], 0.15), 6, side[3], 1, 12))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var c := UI.vbox(2); p.add_child(c)
		c.add_child(UI.label(String(side[0]), 12, UI.MUTED))
		c.add_child(UI.head(String(side[1]), 20, side[3]))
		c.add_child(UI.label(String(side[2]), 13, UI.INK2))
		h.add_child(p)
		if side[0] == "before": h.add_child(UI.label("→ lactic bacteria →", 14, UI.GOLD))
	if d is Dictionary and d.get("taAfter") != null:
		v.add_child(UI.label("This Lot: %.1f g/L malic, TA %.1f g/L, pH %.2f now; after full conversion about TA %.1f g/L, pH %.2f." % [float(d["malic"]), float(d["ta"]), float(d["ph"]), float(d["taAfter"]), float(d["phAfter"])], 13, UI.INK2, null, true))
	else:
		v.add_child(UI.label("Titratable acidity falls and pH rises; a by-product, diacetyl, can add buttery notes.", 13, UI.INK2, null, true))
	return v

# ------------------------------------------------------------------ oak and its aromas (the simulation's own oak model)
static func _oak(rows) -> Control:
	var v := UI.vbox(4)
	if not (rows is Array) or rows.is_empty(): return null
	v.add_child(UI.label("One Chardonnay (Côte d'Or 2018), medium toast, 6 months, in each vessel: the oak on its Tasting sheet", 13, UI.MUTED, null, true))
	for r in rows:
		var h := UI.hbox(10)
		var nl := UI.label(String(r["vessel"]), 14, UI.INK2); nl.custom_minimum_size = Vector2(220, 0); h.add_child(nl)
		var t := String(r["oak"])
		var ol := UI.label(t if t != "" else "no oak on the nose (fruit only)", 14, UI.GOLD if t != "" else UI.MUTED, UI.f_body_b if t != "" else null, true)
		ol.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(ol)
		if String(r["intensity"]) != "": h.add_child(UI.label("(%s)" % r["intensity"], 13, UI.MUTED))
		v.add_child(h)
	v.add_child(UI.label("Game simplification: how much each barrel age gives is a calibration of the model.", 12, UI.MUTED, null, true))
	return v

# ------------------------------------------------------------------ berry temperature by side (the game's sunburn model)
static func _berry(D) -> Control:
	if not (D is Dictionary) or not D.has("rows"): return null
	var v := UI.vbox(6)
	v.add_child(UI.label("A clear, calm %d °C day, medium canopy: how hot the bunches on the afternoon side get" % int(D["tmax"]), 13, UI.MUTED, null, true))
	var shade := float(D["shade"]); var accl := float(D["acclimatised"])
	for r in D["rows"]:
		var h := UI.hbox(10)
		var nl := UI.label("Leaf removal: " + String(r["side"]).to_lower(), 14, UI.INK2); nl.custom_minimum_size = Vector2(200, 0); h.add_child(nl)
		var t := float(r["berry"])
		var m := ProgressBar.new(); m.show_percentage = false; m.min_value = 35; m.max_value = 52; m.value = t
		m.custom_minimum_size = Vector2(260, 12); m.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(m)
		var col := UI.CRIT if t > accl else (UI.SERIOUS if t > shade else UI.GOOD)
		h.add_child(UI.label("%.1f °C%s" % [t, "  burns even acclimatised" if t > accl else ("  burns if shade-grown (late removal)" if t > shade else "")], 13, col))
		v.add_child(h)
	v.add_child(UI.label("Burn starts at %.0f °C for berries grown in shade and %.1f °C once acclimatised by early removal (game model, canopy-and-yield.md §2.5)." % [shade, accl], 12, UI.MUTED, null, true))
	return v

# ------------------------------------------------------------------ ripening capacity against leaf per kg (the game's model)
class Capacity extends Control:
	var lafr = null
	func _cap(x: float) -> float: return clampf(x / 1.0, 0.4, 1.1)
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var r := Rect2(Vector2(44, 10), size - Vector2(54, 34))
		draw_rect(r, Color("182026"))
		var xmax := 2.0 if lafr == null else maxf(2.0, ceilf(float(lafr) / 0.6 * 1.1 * 2.0) / 2.0)
		var X := func(x): return r.position.x + r.size.x * clampf(float(x) / xmax, 0, 1)
		var Y := func(c): return r.position.y + r.size.y * (1.0 - clampf((float(c) - 0.3) / 0.9, 0, 1))
		draw_rect(Rect2(Vector2(X.call(0.8), r.position.y), Vector2(X.call(1.2) - X.call(0.8), r.size.y)), Color(0.05, 0.64, 0.05, 0.12))
		draw_string(font, Vector2(X.call(0.8) + 4, r.position.y + 14), "studies: full ripening 0.8–1.2", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.9, 0.6, 0.8))
		draw_dashed_line(Vector2(X.call(1.0), r.position.y + 20), Vector2(X.call(1.0), r.end.y), Color(1, 1, 1, 0.35), 1.0, 5.0)
		draw_string(font, Vector2(X.call(1.0) + 4, r.end.y - 6), "the game ripens fully from here", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
		var pts := PackedVector2Array()
		for i in 81:
			var x := xmax * float(i) / 80.0
			pts.append(Vector2(X.call(x), Y.call(_cap(x))))
		draw_polyline(pts, Color("d9b24c"), 2.5, true)
		var ticks := []
		var tk := 0.5
		while tk <= xmax + 0.01: ticks.append(tk); tk += 0.5
		for t in ticks: draw_string(font, Vector2(X.call(t) - 8, r.end.y + 14), "%.1f" % t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.5))
		draw_string(font, Vector2(4, r.position.y + 12), "ripen", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d9b24c", 0.8))
		if lafr != null:
			var marks := [["now", float(lafr)], ["−20 %", float(lafr) / 0.8], ["−40 %", float(lafr) / 0.6]]
			for i in marks.size():
				var p := Vector2(X.call(marks[i][1]), Y.call(_cap(marks[i][1])))
				draw_circle(p, 5, Color.WHITE if i == 0 else Color(1, 1, 1, 0.55))
				draw_string(font, p + Vector2(-14, 18 + 12 * i), String(marks[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.85))

static func _capacity(D) -> Control:
	var v := UI.vbox(4)
	var c := Capacity.new(); c.lafr = D.get("lafr", null) if D is Dictionary else null; c.custom_minimum_size = Vector2(0, 190)
	v.add_child(c)
	v.add_child(UI.label(("This Block now, and after thinning 20 % or 40 % of the bunches. " if c.lafr != null else "") + "m² of leaf per kg of fruit (x) against how fully the vine can ripen its crop (the game's model, canopy-and-yield.md §2.2): from about 1 m²/kg more leaf adds little.", 12, UI.MUTED, null, true))
	return v

