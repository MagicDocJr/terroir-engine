# Tank controller screen (rendered into a SubViewport and shown on the tank as an emissive panel).
# Shows one simulated Lot exactly as the snapshot reports it: id, Variety, phase/status, temperature against
# the setpoint, must weight and the fermentation curve. Nothing here is computed except display units.
extends Control

var lot: Dictionary = {}
var tank_id := "T1"
var units := "oe"
var t := 0.0
var font: Font
var mono: Font

const BG := Color(0.035, 0.05, 0.065)
const LINE := Color(0.16, 0.22, 0.27)
const TXT := Color(0.86, 0.92, 0.95)
const DIM := Color(0.50, 0.60, 0.66)
const ACC := Color(0.35, 0.85, 0.95)
const WARN := Color(1.0, 0.72, 0.25)
const OK := Color(0.45, 0.9, 0.5)
const RED := Color(1.0, 0.4, 0.35)


func setup(id: String, l: Dictionary, u: String) -> void:
	tank_id = id
	lot = l
	units = u
	if font == null:
		font = SystemFont.new(); font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
		mono = SystemFont.new(); mono.font_names = PackedStringArray(["Bahnschrift SemiCondensed", "Consolas"])
	queue_redraw()


func _process(delta: float) -> void:
	t += delta
	if fmod(t, 0.6) < delta:
		queue_redraw()        # blink the status LED; values only change with a new snapshot


func _txt(p: Vector2, s: String, size: int, col: Color, f: Font = null, w := -1.0) -> void:
	draw_string(f if f else font, p, s, HORIZONTAL_ALIGNMENT_LEFT, w, size, col)


static func _brix(oe: float) -> float:
	# display only: invert the sim's SG(°Brix) relation (TerroirEngine.Util.Units.SgFromBrix)
	var lo := 0.0
	var hi := 45.0
	for i in 40:
		var mid := (lo + hi) / 2.0
		var sg := 1.0 + mid / (258.6 - mid / 258.2 * 227.1)
		if (sg - 1.0) * 1000.0 < oe:
			lo = mid
		else:
			hi = mid
	return (lo + hi) / 2.0


func _num(k: String, def := 0.0) -> float:
	var v = lot.get(k, def)
	return float(v) if v != null else def


func _draw() -> void:
	var W := size.x
	var H := size.y
	draw_rect(Rect2(0, 0, W, H), BG)
	draw_rect(Rect2(0, 0, W, 58), Color(0.06, 0.09, 0.11))
	var empty := lot.is_empty()
	var stuck: bool = lot.get("stuck", false)
	draw_rect(Rect2(0, 0, 8, H), DIM if empty else (RED if stuck else ACC))
	_txt(Vector2(22, 40), tank_id, 30, ACC, mono)
	if empty:
		_txt(Vector2(84, 40), "— empty —", 25, DIM)
		_txt(Vector2(22, 100), "Cleaned · available", 22, DIM)
		draw_circle(Vector2(W - 28, 29), 8.0, DIM.darkened(0.5))
		return
	_txt(Vector2(84, 40), "%s · %s" % [lot.get("variety", ""), lot.get("id", "")], 25, TXT, null, W - 150)
	var curve: Array = lot.get("curve", [])
	var day := int(curve[-1].get("day", curve.size())) if curve.size() > 0 else 0
	_txt(Vector2(22, 90), String(lot.get("status", lot.get("phase", ""))), 20, WARN if stuck else DIM, null, W - 44)
	# temperature against the setpoint
	var set_c = lot.get("setC")
	var temp := _num("tempC")
	var dev := 0.0 if set_c == null else temp - float(set_c)
	var tcol := OK if absf(dev) < 1.0 else WARN
	_txt(Vector2(22, 168), "%.1f" % temp, 54, tcol, mono)
	_txt(Vector2(150, 168), "°C", 24, tcol)
	_txt(Vector2(22, 200), ("set %.0f °C" % float(set_c)) if set_c != null else "no setpoint", 19, DIM)
	# must weight now + curve of the fermentation
	var oe := _num("oe")
	_txt(Vector2(230, 126), "MUST WEIGHT" if oe > 0.5 else "ALCOHOL", 15, DIM)
	if oe > 0.5:
		if units == "brix":
			_txt(Vector2(230, 168), "%.1f" % _brix(oe), 50, TXT, mono)
			_txt(Vector2(330, 168), "°Bx", 22, DIM)
		else:
			_txt(Vector2(230, 168), "%d" % roundi(oe), 50, TXT, mono)
			_txt(Vector2(310, 168), "°Oe", 22, DIM)
	else:
		_txt(Vector2(230, 168), "%.1f" % _num("alcohol"), 50, TXT, mono)
		_txt(Vector2(330, 168), "% vol", 22, DIM)
	_txt(Vector2(420, 168), "day %d" % day if day > 0 else "", 18, DIM)
	var bx := 230.0; var by := 182.0; var bw := W - bx - 22; var bh := 48.0
	draw_rect(Rect2(bx, by, bw, bh), Color(0.05, 0.07, 0.09))
	if curve.size() > 1:
		var mx := 1.0
		for c in curve:
			mx = maxf(mx, float(c.get("oe", 0.0)))
		var pts := PackedVector2Array()
		for i in curve.size():
			var x := bx + bw * (float(i) / float(curve.size() - 1))
			var y := by + bh - bh * (float(curve[i].get("oe", 0.0)) / mx)
			pts.append(Vector2(x, y))
		draw_polyline(pts, ACC, 3.0, true)
		draw_circle(pts[-1], 5.0, ACC)
	draw_line(Vector2(16, 244), Vector2(W - 16, 244), LINE, 2.0)
	_txt(Vector2(22, 284), "%s  ·  %s L  ·  picked %s" % [lot.get("block", "") if String(lot.get("block", "")).length() > 2 else "Block " + String(lot.get("block", "")),
		str(int(_num("volume"))), lot.get("picked", "")], 20, TXT, null, W - 40)
	_txt(Vector2(22, 322), "Alc %.1f %%  ·  TA %.1f g/L  ·  pH %.2f  ·  free SO₂ %d" % [_num("alcohol"), _num("ta"), _num("ph"), int(_num("freeSo2"))], 18, DIM, null, W - 40)
	var ph := String(lot.get("phase", ""))
	var prog: float = {"Received": 0.05, "ColdSoak": 0.12, "Fermenting": 0.35, "Stuck": 0.35, "PostMaceration": 0.55, "Pressed": 0.6, "Malolactic": 0.7, "Ageing": 0.85, "Ready": 1.0}.get(ph, 0.0)
	draw_rect(Rect2(22, 350, W - 44, 8), Color(0.08, 0.11, 0.13))
	draw_rect(Rect2(22, 350, (W - 44) * prog, 8), (RED if stuck else ACC).darkened(0.2))
	var blink := fmod(t, 1.2) < 0.6
	draw_circle(Vector2(W - 28, 29), 8.0, (RED if stuck else OK) if blink else OK.darkened(0.7))
