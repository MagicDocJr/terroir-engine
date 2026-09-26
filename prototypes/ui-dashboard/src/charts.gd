# PROTOTYPE — custom-drawn chart controls (Godot has no chart library).
# Rules followed (dataviz skill): one y-axis per chart (no dual axes), 2 px lines, recessive grid, text in ink tokens
# (never the series colour), direct labels + a legend elsewhere, crosshair + tooltip on hover.
extends RefCounted

const UI := preload("res://src/ui.gd")

static func _tip_box(c: Control, anchor: Vector2, lines: Array, bounds: Rect2) -> void:
	# lines: [[text, colour_or_null, is_title]]
	var f: Font = UI.f_body
	var fb: Font = UI.f_body_b
	var w := 0.0
	for ln in lines:
		w = maxf(w, (fb if ln[2] else f).get_string_size(ln[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + (22.0 if ln[1] != null else 0.0))
	var h := 12.0 + 22.0 * lines.size()
	var pos := anchor + Vector2(14, -h * 0.5)
	if pos.x + w + 26 > bounds.end.x: pos.x = anchor.x - w - 40
	pos.y = clampf(pos.y, bounds.position.y, bounds.end.y - h)
	c.draw_style_box(UI.sb(Color("11171c"), 5, UI.LINE.lightened(0.2), 1, 0), Rect2(pos, Vector2(w + 26, h)))
	var y := pos.y + 24.0
	for ln in lines:
		var x := pos.x + 13.0
		if ln[1] != null:
			c.draw_rect(Rect2(x, y - 10, 12, 3), ln[1])
			x += 22.0
		c.draw_string(fb if ln[2] else f, Vector2(x, y), ln[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.INK if ln[2] else UI.INK2)
		y += 22.0


class LineChart extends Control:
	var labels: Array = []          # x labels (projection slots included)
	var series: Array = []          # {name, values, color, width?, dashed?, proj?: Array}
	var y_min := 0.0
	var y_max := 100.0
	var y_step := 10.0
	var y_fmt := "%d"
	var unit := ""
	var y_title := ""
	var bands: Array = []           # {lo, hi, label}
	var markers: Array = []         # {x (index float), label}
	var today := -1.0
	var highlight := ""
	var demo_hover := -1
	var label_every := 1
	var direct_labels := true
	var pad_right := 96.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(200, 180)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion: queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT: queue_redraw()

	func _plot() -> Rect2:
		return Rect2(Vector2(48, 12), size - Vector2(48 + (pad_right if direct_labels else 16), 12 + 30))

	func _x(r: Rect2, i: float) -> float:
		return r.position.x + r.size.x * i / maxf(1.0, labels.size() - 1)

	func _y(r: Rect2, v: float) -> float:
		return r.position.y + r.size.y * (1.0 - (v - y_min) / (y_max - y_min))

	func _draw() -> void:
		var r := _plot()
		var f: Font = UI.f_num
		for b in bands:
			var y0 := _y(r, minf(float(b["hi"]), y_max)); var y1 := _y(r, maxf(float(b["lo"]), y_min))
			draw_rect(Rect2(r.position.x, y0, r.size.x, y1 - y0), Color(UI.INK, 0.035))
			draw_line(Vector2(r.position.x, y1), Vector2(r.end.x, y1), Color(UI.INK, 0.18), 1.0)
			draw_string(UI.f_body, Vector2(r.position.x + 8, y1 - 6), String(b["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.MUTED)
		var v := y_min
		while v <= y_max + 0.001:
			var y := _y(r, v)
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(UI.LINE, 0.55), 1.0)
			draw_string(f, Vector2(0, y + 5), y_fmt % v, HORIZONTAL_ALIGNMENT_RIGHT, 40, 14, UI.MUTED)
			v += y_step
		if y_title != "":
			draw_string(UI.f_body, Vector2(r.position.x + 6, r.position.y + 14), y_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.MUTED)
		for i in labels.size():
			if i % label_every != 0 and i != labels.size() - 1: continue
			var x := _x(r, i)
			draw_string(f, Vector2(x - 40, r.end.y + 22), String(labels[i]), HORIZONTAL_ALIGNMENT_CENTER, 80, 14, UI.MUTED)
		if today >= 0.0:
			var tx := _x(r, today)
			draw_dashed_line(Vector2(tx, r.position.y), Vector2(tx, r.end.y), Color(UI.INK, 0.4), 1.0, 5.0)
			draw_string(UI.f_body, Vector2(tx + 5, r.position.y + 14), "today", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.INK2)
		for m in markers:
			var mx := _x(r, float(m["x"]))
			draw_line(Vector2(mx, r.end.y - 6), Vector2(mx, r.end.y), UI.INK2, 1.0)
			draw_string(UI.f_body, Vector2(mx - 60, r.end.y - 10), String(m["label"]), HORIZONTAL_ALIGNMENT_CENTER, 120, 12, UI.MUTED)
		var order := []
		for s in series:
			if String(s["name"]) != highlight: order.append(s)
		for s in series:
			if String(s["name"]) == highlight: order.append(s)
		var label_ys := []
		for s in order:
			var faded: bool = highlight != "" and String(s["name"]) != highlight
			var col: Color = s["color"]
			if faded: col = Color(col, 0.35)
			var width: float = float(s.get("width", 2.0)) * (1.6 if String(s["name"]) == highlight else 1.0)
			var pts := PackedVector2Array()
			var vals: Array = s["values"]
			for i in vals.size():
				if vals[i] == null: continue
				pts.append(Vector2(_x(r, i), _y(r, float(vals[i]))))
			if pts.size() >= 2:
				if s.get("dashed", false):
					for i in pts.size() - 1: draw_dashed_line(pts[i], pts[i + 1], col, width, 6.0)
				else:
					draw_polyline(pts, col, width, true)
			if s.has("proj") and pts.size() > 0:
				var pj: Array = s["proj"]
				var prev := pts[pts.size() - 1]
				for k in pj.size():
					var p := Vector2(_x(r, vals.size() - 1 + k + 1), _y(r, float(pj[k])))
					draw_dashed_line(prev, p, col, width, 3.0)
					prev = p
			if pts.size() > 0 and not faded:
				draw_circle(pts[pts.size() - 1], 4.5, col)
				draw_arc(pts[pts.size() - 1], 5.5, 0, TAU, 20, UI.SURFACE, 2.0)
			if direct_labels and pts.size() > 0:
				# label sits at the end of its own line (after the projection if any), nudged to avoid overlaps
				var end := pts[pts.size() - 1]
				if s.has("proj"):
					var pj2: Array = s["proj"]
					end = Vector2(_x(r, vals.size() - 1 + pj2.size()), _y(r, float(pj2[pj2.size() - 1])))
				var lx := end.x + 9
				var ly := end.y
				for other in label_ys:
					if absf(lx - other.x) < 40 and absf(ly - other.y) < 15: ly = other.y - 15.0
				ly = clampf(ly, r.position.y + 6, r.end.y - 4)
				label_ys.append(Vector2(lx, ly))
				draw_string(UI.f_body_b, Vector2(minf(lx, size.x - 30), ly + 5), String(s.get("short", s["name"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.INK if not faded else UI.MUTED)
		# crosshair + tooltip
		var hi := demo_hover
		var m := get_local_mouse_position()
		if Rect2(Vector2.ZERO, size).has_point(m) and r.grow(8).has_point(m):
			hi = clampi(roundi((m.x - r.position.x) / r.size.x * (labels.size() - 1)), 0, labels.size() - 1)
		if hi >= 0:
			var x := _x(r, hi)
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(UI.INK, 0.45), 1.0)
			var lines := [[String(labels[hi]), null, true]]
			var rows := []
			for s in series:
				var vals2: Array = s["values"]
				var val = null
				var projected := false
				if hi < vals2.size():
					val = vals2[hi]
				elif s.has("proj") and hi - vals2.size() < (s["proj"] as Array).size():
					val = s["proj"][hi - vals2.size()]; projected = true
				if val == null: continue
				rows.append([float(val), "%s  %s%s%s" % [String(s["name"]), y_fmt % float(val), unit, "  (projected)" if projected else ""], s["color"]])
				draw_circle(Vector2(x, _y(r, float(val))), 4.0, s["color"])
			rows.sort_custom(func(a, b): return a[0] > b[0])
			for rw in rows: lines.append([rw[1], rw[2], false])
			if lines.size() > 1:
				Charts_tip(self, Vector2(x, r.position.y + r.size.y * 0.35), lines, Rect2(Vector2.ZERO, size))

	func Charts_tip(c: Control, a: Vector2, lines: Array, b: Rect2) -> void:
		load("res://src/charts.gd")._tip_box(c, a, lines, b)


class Sparkline extends Control:
	var values: Array = []
	var color := Color("3987e5")
	var fill := true
	var ref_line := NAN

	func _init() -> void:
		custom_minimum_size = Vector2(90, 28)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		if values.size() < 2: return
		var lo := INF; var hi := -INF
		for v in values:
			lo = minf(lo, float(v)); hi = maxf(hi, float(v))
		if not is_nan(ref_line):
			lo = minf(lo, ref_line); hi = maxf(hi, ref_line)
		if hi - lo < 0.001: hi = lo + 1.0
		var pts := PackedVector2Array()
		for i in values.size():
			pts.append(Vector2(2 + (size.x - 8) * i / (values.size() - 1), 3 + (size.y - 6) * (1.0 - (float(values[i]) - lo) / (hi - lo))))
		if fill:
			var poly := pts.duplicate()
			poly.append(Vector2(pts[pts.size() - 1].x, size.y)); poly.append(Vector2(pts[0].x, size.y))
			draw_colored_polygon(poly, Color(color, 0.14))
		if not is_nan(ref_line):
			var ry := 3 + (size.y - 6) * (1.0 - (ref_line - lo) / (hi - lo))
			draw_dashed_line(Vector2(0, ry), Vector2(size.x, ry), Color(UI.INK, 0.3), 1.0, 3.0)
		draw_polyline(pts, color, 2.0, true)
		draw_circle(pts[pts.size() - 1], 3.5, color)


## Bars of actual values with the long-term normal drawn as a tick (no second colour needed).
class BarNormalChart extends Control:
	var labels: Array = []
	var values: Array = []
	var normals: Array = []
	var color := Color("3987e5")
	var unit := " mm"
	var y_max := 100.0
	var y_step := 25.0
	var partial_last := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(200, 160)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion: queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT: queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(44, 10), size - Vector2(44 + 10, 10 + 28))
		var v := 0.0
		while v <= y_max + 0.01:
			var y := r.end.y - r.size.y * v / y_max
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(UI.LINE, 0.55), 1.0)
			draw_string(UI.f_num, Vector2(0, y + 5), "%d" % v, HORIZONTAL_ALIGNMENT_RIGHT, 36, 14, UI.MUTED)
			v += y_step
		var n := labels.size()
		var slot := r.size.x / n
		var bw := minf(34.0, slot * 0.5)
		var m := get_local_mouse_position()
		var hover := -1
		for i in n:
			var cx := r.position.x + slot * (i + 0.5)
			var h := r.size.y * float(values[i]) / y_max
			var rect := Rect2(cx - bw / 2, r.end.y - h, bw, h)
			var col := color if not (partial_last != "" and i == n - 1) else Color(color, 0.55)
			draw_style_box(UI.sb(col, 4, Color(0, 0, 0, 0), 0, 0), rect)
			var ny := r.end.y - r.size.y * float(normals[i]) / y_max
			draw_line(Vector2(cx - bw / 2 - 6, ny), Vector2(cx + bw / 2 + 6, ny), UI.INK, 2.0)
			draw_string(UI.f_num, Vector2(cx - 30, r.end.y + 20), String(labels[i]), HORIZONTAL_ALIGNMENT_CENTER, 60, 14, UI.MUTED)
			if absf(m.x - cx) < slot / 2 and Rect2(Vector2.ZERO, size).has_point(m): hover = i
		if hover >= 0:
			var cx2 := r.position.x + slot * (hover + 0.5)
			var lines := [[String(labels[hover]) + (" (to date)" if partial_last != "" and hover == n - 1 else ""), null, true],
				["Rain  %d%s" % [int(values[hover]), unit], color, false], ["Normal  %d%s" % [int(normals[hover]), unit], UI.INK, false]]
			load("res://src/charts.gd")._tip_box(self, Vector2(cx2, r.position.y + 40), lines, Rect2(Vector2.ZERO, size))


## Soil profile: horizons drawn to depth with a stone-content stipple and a rooting-depth line.
class SoilProfile extends Control:
	var profile: Dictionary = {}
	var max_depth := 180.0

	func _init() -> void:
		custom_minimum_size = Vector2(300, 330)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		if profile.is_empty(): return
		var col_w := 110.0
		var top := 8.0
		var h := size.y - 30.0
		var rng := RandomNumberGenerator.new(); rng.seed = 7
		draw_line(Vector2(col_w + 8, top), Vector2(col_w + 8, top + h), UI.LINE, 1.0)
		for d in [0, 50, 100, 150]:
			var y: float = top + h * float(d) / max_depth
			draw_string(UI.f_num, Vector2(col_w + 14, y + 5), "%d cm" % d, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.MUTED)
		for hz in profile["horizons"]:
			var y0 := top + h * float(hz["from"]) / max_depth
			var y1 := top + h * minf(float(hz["to"]), max_depth) / max_depth
			var rect := Rect2(0, y0, col_w, y1 - y0)
			draw_rect(rect, Color(String(hz["color"])))
			var stones := int(hz["stones"])
			for k in int(rect.size.x * rect.size.y / 90.0 * stones / 100.0):
				var p := Vector2(rng.randf_range(2, col_w - 2), rng.randf_range(y0 + 2, y1 - 2))
				var sz := rng.randf_range(2.0, 5.5)
				draw_colored_polygon(PackedVector2Array([p, p + Vector2(sz, sz * 0.25), p + Vector2(sz * 0.8, sz * 0.7), p + Vector2(-sz * 0.2, sz * 0.5)]), Color(0.72, 0.76, 0.82, 0.55))
			draw_line(Vector2(0, y1), Vector2(col_w, y1), Color(0, 0, 0, 0.35), 1.0)
			var tx := col_w + 64.0
			draw_string(UI.f_head, Vector2(tx, y0 + 20), String(hz["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.INK)
			draw_string(UI.f_body, Vector2(tx + 36, y0 + 20), String(hz["texture"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - tx - 40, 14, UI.INK2)
			draw_string(UI.f_body, Vector2(tx + 36, y0 + 39), "%d %% stones" % stones, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.MUTED)
		var rd := top + h * float(profile["rootDepthCm"]) / max_depth
		draw_dashed_line(Vector2(0, rd), Vector2(col_w, rd), UI.INK, 2.0, 5.0)
		draw_string(UI.f_body, Vector2(4, rd - 6), "roots", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.INK)
		draw_string(UI.f_body, Vector2(0, size.y - 6), "Available water %d mm, pH %.1f, lime %d %%" % [int(profile["awcMm"]), float(profile["phTopsoil"]), int(profile["caco3"])], HORIZONTAL_ALIGNMENT_LEFT, size.x, 14, UI.INK2)


## Horizontal meter with an optional target tick (used for readiness, labour, budget).
class Meter extends Control:
	var value := 0.5
	var target := -1.0
	var color := Color("0ca30c")

	func _init() -> void:
		custom_minimum_size = Vector2(120, 12)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		draw_style_box(UI.sb(UI.SUNKEN, 4, Color(0, 0, 0, 0), 0, 0), Rect2(Vector2.ZERO, size))
		draw_style_box(UI.sb(color, 4, Color(0, 0, 0, 0), 0, 0), Rect2(Vector2.ZERO, Vector2(size.x * clampf(value, 0, 1), size.y)))
		if target >= 0.0:
			var tx := size.x * clampf(target, 0, 1)
			draw_line(Vector2(tx, -3), Vector2(tx, size.y + 3), UI.INK, 2.0)


## Small weather glyphs for the forecast.
class WeatherIcon extends Control:
	var kind := "sun"

	func _init() -> void:
		custom_minimum_size = Vector2(0, 40)

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, 20)
		match kind:
			"sun":
				for i in 8:
					var a := TAU * i / 8.0
					draw_line(c + Vector2(cos(a), sin(a)) * 12, c + Vector2(cos(a), sin(a)) * 17, UI.WARN, 2.0, true)
				draw_circle(c, 8.0, UI.WARN)
			"fog":
				for i in 4:
					draw_line(c + Vector2(-16 + (i % 2) * 4, -9 + i * 6), c + Vector2(14 + (i % 2) * 2, -9 + i * 6), Color("aeb5b9"), 2.5, true)
			_:
				var cc := Color("b8c0c6") if kind == "cloud" else Color("8e9aa3")
				draw_circle(c + Vector2(-8, 2), 8.0, cc); draw_circle(c + Vector2(2, -4), 10.0, cc); draw_circle(c + Vector2(11, 3), 7.0, cc)
				draw_rect(Rect2(c.x - 8, c.y + 2, 19, 8), cc)
				if kind == "rain":
					for i in 3:
						draw_line(c + Vector2(-7 + i * 7, 14), c + Vector2(-10 + i * 7, 21), Color("3987e5"), 2.0, true)
