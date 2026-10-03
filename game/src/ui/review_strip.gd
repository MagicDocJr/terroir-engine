# The season replayed (Vintage in review, docs/superpowers/specs/2026-10-03-vintage-in-review-design.md): the year's weekly
# temperature against the normal draws from March to November, phenology markers and the cause cards' pins appear as the
# sweep passes them, and `progress_changed` lets the report fade the cards in. Positions come from the sim's dates; this
# control only lays them out.
extends Control

const UI := preload("res://src/ui/ui.gd")

signal progress_changed(p: float)

var weekly := []      # [{tmean, tmeanNormal}], one per week from 1 March
var marks := []       # [{t: 0..1, label}] budburst, flowering, véraison, harvest
var pins := []        # [{t: 0..1, num, priority}] numbered like the cards
var animate := false
var progress := 1.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		queue_redraw()
		progress_changed.emit(progress)
var _tween: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(0, 190)
	if animate: replay()

func replay() -> void:
	if _tween: _tween.kill()
	progress = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "progress", 1.0, 6.0)

func skip() -> void:
	if _tween: _tween.kill()
	progress = 1.0

func _draw() -> void:
	var font := UI.f_body
	var r := Rect2(Vector2(40, 34), size - Vector2(56, 64))
	draw_rect(Rect2(Vector2.ZERO, size), Color("182026"))
	if weekly.size() < 2: return
	var lo := 999.0; var hi := -999.0
	for w in weekly:
		lo = minf(lo, minf(float(w["tmean"]), float(w["tmeanNormal"]))); hi = maxf(hi, maxf(float(w["tmean"]), float(w["tmeanNormal"])))
	lo = floorf(lo / 5.0) * 5.0; hi = ceilf(hi / 5.0) * 5.0
	var X := func(t: float) -> float: return r.position.x + r.size.x * t
	var Y := func(v: float) -> float: return r.position.y + r.size.y * (1.0 - (v - lo) / maxf(1.0, hi - lo))
	for v in range(int(lo), int(hi) + 1, 5):
		draw_line(Vector2(r.position.x, Y.call(v)), Vector2(r.end.x, Y.call(v)), Color(1, 1, 1, 0.06))
		draw_string(font, Vector2(4, Y.call(v) + 4), "%d°" % v, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.MUTED)
	var months := ["Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov"]
	for i in months.size(): draw_string(font, Vector2(X.call(float(i) / 9.0) + 2, r.end.y + 16), months[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.MUTED)
	var n := weekly.size()
	var prev_n := Vector2.ZERO; var prev_y := Vector2.ZERO
	for i in n:
		var t := float(i) / float(n - 1)
		var pn := Vector2(X.call(t), Y.call(float(weekly[i]["tmeanNormal"])))
		var py := Vector2(X.call(t), Y.call(float(weekly[i]["tmean"])))
		if i > 0:
			if i % 2 == 0: draw_line(prev_n, pn, Color(1, 1, 1, 0.35), 1.5)
			if t <= progress: draw_line(prev_y, py, UI.GOLD, 2.5)
		prev_n = pn; prev_y = py
	for m in marks:
		var t := float(m["t"])
		if t > progress: continue
		var x: float = X.call(t)
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(1, 1, 1, 0.25), 1.0)
		draw_string(font, Vector2(x + 3, r.end.y - 4), String(m["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.INK2)
	# numbered pins, stacked where several cards share a date
	var stack := {}
	for p in pins:
		var t := float(p["t"])
		if t < 0.0 or t > progress or t > 1.0: continue
		var x: float = X.call(t)
		var k := int(round(x / 18.0))
		var row: int = stack.get(k, 0); stack[k] = row + 1
		var c := Vector2(x + 18 * row, r.position.y - 14)
		var col := UI.CRIT if int(p["priority"]) == 0 else UI.SERIOUS if int(p["priority"]) == 1 else UI.GOLD
		draw_circle(c, 8, col)
		draw_string(font, c + Vector2(-4, 4), str(int(p["num"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("10151a"))
	if progress < 1.0:
		var sx: float = X.call(progress)
		draw_line(Vector2(sx, r.position.y - 4), Vector2(sx, r.end.y), Color(1, 1, 1, 0.6), 2.0)
