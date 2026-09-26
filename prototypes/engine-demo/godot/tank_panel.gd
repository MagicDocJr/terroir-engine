# PROTOTYPE — live tank readout rendered into a SubViewport (shown on the tank as an emissive screen).
extends Control

var data: Dictionary
var t := 0.0
var oe_now := 0.0
var temp_now := 0.0
var font: Font
var mono: Font

const BG := Color(0.035, 0.05, 0.065)
const LINE := Color(0.16, 0.22, 0.27)
const TXT := Color(0.86, 0.92, 0.95)
const DIM := Color(0.50, 0.60, 0.66)
const ACC := Color(0.35, 0.85, 0.95)
const WARN := Color(1.0, 0.72, 0.25)
const OK := Color(0.45, 0.9, 0.5)

func setup(d: Dictionary) -> void:
	data = d
	var s: Array = d["oe_series"]
	oe_now = float(s[-1]) if s.size() > 0 else 0.0
	temp_now = float(d["tempC"])
	font = SystemFont.new(); font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	mono = SystemFont.new(); mono.font_names = PackedStringArray(["Bahnschrift SemiCondensed", "Consolas"])
	set_process(true)

func _process(delta: float) -> void:
	t += delta
	# values tick slowly: temperature jitters around the setpoint, active ferments keep dropping
	var set_c = data["setC"]
	var base_t := float(data["tempC"])
	temp_now = base_t + 0.08 * sin(t * 0.9) + 0.03 * sin(t * 3.1)
	if String(data["phase"]).contains("ferment") and not String(data["phase"]).contains("Stopped"):
		oe_now = maxf(0.0, oe_now - delta * 0.02)
	queue_redraw()

func _txt(p: Vector2, s: String, size: int, col: Color, f: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	draw_string(f if f else font, p, s, align, w, size, col)

func _draw() -> void:
	var W := size.x
	var H := size.y
	draw_rect(Rect2(0, 0, W, H), BG)
	draw_rect(Rect2(0, 0, W, 58), Color(0.06, 0.09, 0.11))
	draw_rect(Rect2(0, 0, 8, H), ACC if data["contents"] != "— empty —" else DIM)
	_txt(Vector2(22, 40), String(data["id"]), 30, ACC, mono)
	_txt(Vector2(78, 40), String(data["contents"]), 25, TXT)
	var phase := String(data["phase"])
	var day := int(data["day"])
	_txt(Vector2(22, 92), phase + ("   ·   day %d" % day if day > 0 else ""), 21, DIM)
	# temperature block
	var set_c = data["setC"]
	var dev := 0.0 if set_c == null else temp_now - float(set_c)
	var tcol := OK if absf(dev) < 0.6 else WARN
	_txt(Vector2(22, 168), "%.1f" % temp_now, 54, tcol, mono)
	_txt(Vector2(168, 168), "°C", 24, tcol)
	_txt(Vector2(22, 200), ("set %.1f °C" % float(set_c)) if set_c != null else "no setpoint", 19, DIM)
	# °Oe + sparkline
	var s: Array = data["oe_series"]
	if s.size() > 0:
		_txt(Vector2(230, 126), "MUST WEIGHT", 15, DIM)
		_txt(Vector2(230, 168), "%d" % roundi(oe_now), 50, TXT, mono)
		_txt(Vector2(300, 168), "°Oe", 22, DIM)
		_txt(Vector2(380, 168), "SG %.3f · %.1f °Bx" % [1.0 + oe_now / 1000.0, oe_now / 4.25], 17, DIM)
		var bx := 230.0; var by := 184.0; var bw := W - bx - 22; var bh := 46.0
		draw_rect(Rect2(bx, by, bw, bh), Color(0.05, 0.07, 0.09))
		var mx := 100.0
		var pts := PackedVector2Array()
		for i in s.size():
			var x := bx + bw * (float(i) / maxf(1.0, s.size() - 1))
			var y := by + bh - bh * (float(s[i]) / mx)
			pts.append(Vector2(x, y))
		if pts.size() > 1:
			draw_polyline(pts, ACC, 3.0, true)
			draw_circle(pts[-1], 5.0, ACC)
	else:
		_txt(Vector2(230, 168), "—", 50, DIM, mono)
	draw_line(Vector2(16, 244), Vector2(W - 16, 244), LINE, 2.0)
	var note := String(data["note"])
	if note == "" and String(data["yeast"]) != "":
		note = String(data["yeast"])
	_txt(Vector2(22, 284), note, 22, WARN if note.contains("monitor") or note.contains("Cap") else TXT, null, HORIZONTAL_ALIGNMENT_LEFT, W - 40)
	if String(data["yeast"]) != "":
		_txt(Vector2(22, 322), "Yeast: " + String(data["yeast"]), 18, DIM)
	var bar_w := (W - 44) * clampf(float(day) / 21.0, 0.0, 1.0)
	draw_rect(Rect2(22, 350, W - 44, 8), Color(0.08, 0.11, 0.13))
	draw_rect(Rect2(22, 350, bar_w, 8), ACC.darkened(0.2))
	# status LED + clock
	var blink := fmod(t, 1.2) < 0.6
	draw_circle(Vector2(W - 28, 29), 8.0, OK if blink else OK.darkened(0.7))
	_txt(Vector2(W - 170, 40), "%02d:%02d" % [9 + int(t / 60) % 12, int(t) % 60], 20, DIM, mono)
