# PROTOTYPE — Football-Manager-style "Plot & Blocks" screen in Godot Control nodes only (no web view).
# Data: assets/models_r2/dashboard_data.json (fake but plausible Mosel values).
extends Control

const Lib := preload("res://lib.gd")

var layout2: Dictionary
var shot2: Dictionary = {}
var D: Dictionary
var blocks: Array
var selected := "A"
var sort_key := "id"
var sort_desc := false
var table_box: VBoxContainer
var chart: Control
var header_buttons := {}
var font_ui: SystemFont
var font_num: SystemFont
var font_bold: SystemFont

const C_BG := Color("0d1217")
const C_PANEL := Color("141b22")
const C_PANEL2 := Color("1a232c")
const C_LINE := Color("25313c")
const C_TXT := Color("e4ebf0")
const C_DIM := Color("8797a4")
const C_FAINT := Color("56646f")
const C_ACC := Color("c9a646")       # Riesling gold
const C_ACC2 := Color("7fb069")      # vine green
const C_GOOD := Color("58b26a")
const C_WARN := Color("e0a53a")
const C_BAD := Color("dc5a4b")
const C_WATER := Color("4d9de0")
const BLOCK_COL := {"A": Color("e3b448"), "B": Color("7fb069"), "C": Color("4d9de0"), "D": Color("c05a7a"), "E": Color("a08bd6")}

func settle_frames() -> int:
	return 40

func _ready() -> void:
	D = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models_r2/dashboard_data.json"))
	blocks = D["blocks"]
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1920, 1080)
	theme = _theme()
	var bg := ColorRect.new(); bg.color = C_BG; bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var root := VBoxContainer.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_topbar())
	var body := HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 0)
	root.add_child(body)
	body.add_child(_nav())
	var content := MarginContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, 22 if side != "top" else 16)
	body.add_child(content)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 14)
	content.add_child(col)
	col.add_child(_page_header())
	var grid := HBoxContainer.new(); grid.size_flags_vertical = Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("separation", 16)
	col.add_child(grid)
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; left.add_theme_constant_override("separation", 16)
	grid.add_child(left)
	var right := VBoxContainer.new(); right.custom_minimum_size = Vector2(500, 0); right.add_theme_constant_override("separation", 16)
	grid.add_child(right)
	left.add_child(_table_panel())
	var cp := _chart_panel(); cp.size_flags_vertical = Control.SIZE_EXPAND_FILL; left.add_child(cp)
	right.add_child(_forecast_panel())
	right.add_child(_inbox_panel())
	right.add_child(_harvest_panel())
	root.add_child(_statusbar())

# ------------------------------------------------------------------ theme
func _font(names: Array, weight := 400) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_LCD
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f

func _sb(col: Color, radius := 6, border := Color(0, 0, 0, 0), bw := 0, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = pad; s.content_margin_right = pad; s.content_margin_top = pad * 0.6; s.content_margin_bottom = pad * 0.6
	s.anti_aliasing = true
	return s

func _theme() -> Theme:
	font_ui = _font(["Bahnschrift", "Segoe UI", "Arial"])
	font_num = _font(["Bahnschrift SemiCondensed", "Bahnschrift", "Consolas"])
	font_bold = _font(["Bahnschrift SemiBold", "Bahnschrift", "Segoe UI Semibold"], 600)
	var t := Theme.new()
	t.default_font = font_ui
	t.default_font_size = 16
	t.set_color("font_color", "Label", C_TXT)
	t.set_stylebox("panel", "PanelContainer", _sb(C_PANEL, 8, C_LINE, 1, 14))
	t.set_stylebox("normal", "Button", _sb(C_PANEL2, 5, C_LINE, 1, 12))
	t.set_stylebox("hover", "Button", _sb(C_PANEL2.lightened(0.08), 5, C_ACC.darkened(0.3), 1, 12))
	t.set_stylebox("pressed", "Button", _sb(C_ACC.darkened(0.55), 5, C_ACC, 1, 12))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", C_TXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_stylebox("panel", "TooltipPanel", _sb(Color("0a0f13"), 6, C_ACC.darkened(0.2), 1, 12))
	t.set_color("font_color", "TooltipLabel", C_TXT)
	t.set_font_size("font_size", "TooltipLabel", 15)
	return t

func _label(text: String, size := 16, col := C_TXT, f: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if f: l.add_theme_font_override("font", f)
	return l

func _panel(title: String, sub := "") -> Array:
	var p := PanelContainer.new()
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	h.add_child(_label(title.to_upper(), 14, C_DIM, font_bold))
	if sub != "":
		var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(sp)
		h.add_child(_label(sub, 13, C_FAINT))
	return [p, v]

# ------------------------------------------------------------------ chrome
func _topbar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _sb(Color("0a0e12"), 0, C_LINE, 0, 18))
	bar.custom_minimum_size = Vector2(0, 66)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); bar.add_child(h)
	var logo := _label("TERROIR", 24, C_ACC, font_bold); h.add_child(logo)
	h.add_child(_label(String(D["estate"]), 16, C_DIM))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(sp)
	h.add_child(_label(String(D["date"]), 22, C_TXT, font_bold))
	var chip := PanelContainer.new(); chip.add_theme_stylebox_override("panel", _sb(C_ACC2.darkened(0.65), 12, C_ACC2.darkened(0.2), 1, 12))
	chip.add_child(_label(String(D["stage"]), 15, C_ACC2.lightened(0.2)))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(chip)
	var sp2 := Control.new(); sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(sp2)
	var cash := _label("€ %s" % _thousands(int(D["cash"])), 22, C_TXT, font_num); h.add_child(cash)
	for txt in ["+1 day", "+1 week"]:
		var b := Button.new(); b.text = txt; b.add_theme_font_size_override("font_size", 16); b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.custom_minimum_size = Vector2(0, 40); h.add_child(b)
	var cont := Button.new(); cont.text = "Continue  ▶"
	cont.add_theme_stylebox_override("normal", _sb(C_ACC, 5, C_ACC.lightened(0.2), 1, 18))
	cont.add_theme_stylebox_override("hover", _sb(C_ACC.lightened(0.12), 5, C_ACC.lightened(0.3), 1, 18))
	cont.add_theme_color_override("font_color", Color("1a1406")); cont.add_theme_color_override("font_hover_color", Color("1a1406"))
	cont.add_theme_font_override("font", font_bold); cont.add_theme_font_size_override("font_size", 17)
	cont.custom_minimum_size = Vector2(136, 42); cont.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cont)
	var bell := PanelContainer.new(); bell.add_theme_stylebox_override("panel", _sb(C_BAD, 14, Color(0, 0, 0, 0), 0, 9))
	bell.add_child(_label("⚑ 3", 16, Color.WHITE, font_bold)); bell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bell.tooltip_text = "3 alerts: rain Mon–Tue · Block C botrytis risk · T2 slow ferment"
	h.add_child(bell)
	return bar

func _nav() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color("0b1015"), 0, C_LINE, 0, 0))
	p.custom_minimum_size = Vector2(228, 0)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2); p.add_child(v)
	var pad := Control.new(); pad.custom_minimum_size = Vector2(0, 14); v.add_child(pad)
	var items := [["✉", "Inbox", "4"], ["◆", "Estate", ""], ["▦", "Plot & Blocks", ""], ["☁", "Weather", ""], ["⚙", "Programmes", ""],
		["◔", "Ripeness", ""], ["⛁", "Winery", ""], ["⚗", "Blending", ""], ["🍷", "Wines", ""], ["❖", "Staff", ""], ["?", "Glossary", ""]]
	for it in items:
		var active: bool = it[1] == "Plot & Blocks"
		var row := PanelContainer.new()
		var st := _sb(C_ACC.darkened(0.78) if active else Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 18)
		if active:
			st.border_color = C_ACC; st.border_width_left = 4
		row.add_theme_stylebox_override("panel", st)
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 14); row.add_child(h)
		var ic := _label(it[0], 17, C_ACC if active else C_FAINT); ic.custom_minimum_size = Vector2(20, 0); h.add_child(ic)
		h.add_child(_label(it[1], 17, C_TXT if active else C_DIM, font_bold if active else null))
		if it[2] != "":
			var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(sp)
			var badge := PanelContainer.new(); badge.add_theme_stylebox_override("panel", _sb(C_ACC.darkened(0.3), 9, Color(0, 0, 0, 0), 0, 6))
			badge.add_child(_label(it[2], 13, Color.WHITE, font_bold)); h.add_child(badge)
		row.custom_minimum_size = Vector2(0, 46)
		v.add_child(row)
	var sp2 := Control.new(); sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(sp2)
	var tip := MarginContainer.new(); tip.add_theme_constant_override("margin_left", 18); tip.add_theme_constant_override("margin_bottom", 16)
	tip.add_child(_label("Tab  ·  walk the vineyard in 3D", 13, C_FAINT)); v.add_child(tip)
	return p

func _page_header() -> Control:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 16)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0); h.add_child(v)
	v.add_child(_label(String(D["plot"]), 30, C_TXT, font_bold))
	v.add_child(_label("5 Blocks  ·  1.4 ha  ·  Riesling, Spätburgunder  ·  4th leaf  ·  Classification: Mosel (Prädikat eligible)", 15, C_DIM))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(sp)
	for tab in ["Overview", "Blocks", "Ripeness", "Soil"]:
		var b := Button.new(); b.text = tab; b.custom_minimum_size = Vector2(0, 38); b.size_flags_vertical = Control.SIZE_SHRINK_END
		if tab == "Blocks":
			b.add_theme_stylebox_override("normal", _sb(C_PANEL2, 5, C_ACC, 1, 14)); b.add_theme_color_override("font_color", C_ACC)
		h.add_child(b)
	return h

func _statusbar() -> Control:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", _sb(Color("090d11"), 0, C_LINE, 0, 18))
	p.custom_minimum_size = Vector2(0, 30)
	p.add_child(_label("Normal mode  ·  Vineyard manager: Junior  ·  Cellar master: Experienced  ·  Mentor: Klaus Weber (retires after bottling)  ·  Historical weather: Mosel 2025", 13, C_FAINT))
	return p

# ------------------------------------------------------------------ block table
const COLS := [
	["id", "Block", 58], ["name", "Name", 132], ["variety", "Variety", 116], ["oe", "°Oe", 68], ["ta", "TA g/L", 74], ["ph", "pH", 58],
	["water", "Ψstem", 72], ["downy", "Downy", 74], ["powdery", "Powdery", 80], ["botrytis", "Botrytis", 82], ["yieldKgHa", "Yield kg/ha", 100], ["health", "Health", 96]]

func _table_panel() -> Control:
	var pv := _panel("Blocks", "click a header to sort · click a row to chart it · hover for detail")
	table_box = VBoxContainer.new(); table_box.add_theme_constant_override("separation", 2)
	pv[1].add_child(table_box)
	_rebuild_table()
	return pv[0]

func _last(b: Dictionary, k: String) -> float:
	var a: Array = b[k]
	return float(a[-1])

func _value(b: Dictionary, k: String):
	if k in ["oe", "ta", "ph"]:
		return _last(b, k)
	return b[k]

func _rebuild_table() -> void:
	for c in table_box.get_children():
		c.queue_free()
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 2)
	for col in COLS:
		var b := Button.new()
		var arrow := ("  ▼" if sort_desc else "  ▲") if sort_key == col[0] else ""
		b.text = String(col[1]) + arrow
		b.custom_minimum_size = Vector2(col[2], 34)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", C_ACC if sort_key == col[0] else C_DIM)
		b.add_theme_stylebox_override("normal", _sb(Color("10161c"), 3, Color(0, 0, 0, 0), 0, 8))
		b.pressed.connect(_on_sort.bind(col[0]))
		head.add_child(b)
	table_box.add_child(head)
	var rows := blocks.duplicate()
	rows.sort_custom(func(a, b):
		var va = _value(a, sort_key); var vb = _value(b, sort_key)
		return (va > vb) if sort_desc else (va < vb))
	for b in rows:
		table_box.add_child(_row(b))

func _on_sort(k: String) -> void:
	if sort_key == k:
		sort_desc = not sort_desc
	else:
		sort_key = k; sort_desc = k in ["oe", "downy", "powdery", "botrytis", "yieldKgHa"]
	_rebuild_table()

func _risk_col(v: float) -> Color:
	return C_GOOD if v < 20 else (C_WARN if v < 35 else C_BAD)

func _cell(text: String, w: float, fg := C_TXT, bg := Color(0, 0, 0, 0), tip := "", f: Font = null, size := 16) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(w, 42)
	p.add_theme_stylebox_override("panel", _sb(bg, 3, Color(0, 0, 0, 0), 0, 8))
	var l := _label(text, size, fg, f if f else font_num)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(l)
	p.tooltip_text = tip
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p

func _row(b: Dictionary) -> Control:
	var sel: bool = b["id"] == selected
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", _sb(C_PANEL2 if sel else Color("111820"), 4, (BLOCK_COL[b["id"]] as Color) if sel else Color(0, 0, 0, 0), 1 if sel else 0, 0))
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			selected = b["id"]; _rebuild_table(); chart.queue_redraw())
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 2); wrap.add_child(h)
	var bc: Color = BLOCK_COL[b["id"]]
	var idc := _cell("  " + String(b["id"]), COLS[0][2], bc, Color(0, 0, 0, 0), "", font_bold, 18)
	h.add_child(idc)
	h.add_child(_cell(String(b["name"]), COLS[1][2], C_TXT, Color(0, 0, 0, 0), "%s\nSlope %d°  ·  aspect %s  ·  rootstock %s" % [b["soil"], int(b["slope"]), b["aspect"], b["rootstock"]], font_ui, 16))
	h.add_child(_cell(String(b["variety"]), COLS[2][2], C_DIM, Color(0, 0, 0, 0), "", font_ui, 15))
	var oe := _last(b, "oe")
	var oe_t := clampf((oe - 65.0) / 30.0, 0.0, 1.0)
	h.add_child(_cell("%d" % roundi(oe), COLS[3][2], C_ACC.lerp(Color.WHITE, 0.2) if oe >= 76 else C_TXT, C_ACC.darkened(0.9 - 0.45 * oe_t),
		"Must weight %d °Oe (≈ %.1f °Brix)\n+%d °Oe in the last week\nKabinett ≥ 70 · Spätlese ≥ 76 · Auslese ≥ 83" % [roundi(oe), oe / 4.25, roundi(oe - float(b["oe"][-2]))]))
	var ta := _last(b, "ta")
	h.add_child(_cell("%.1f" % ta, COLS[4][2], C_TXT, C_WATER.darkened(0.85 - 0.3 * clampf((ta - 7.0) / 6.0, 0, 1)), "Titratable acidity %.1f g/L (as tartaric)\nMalic acid is still falling with warm nights" % ta))
	h.add_child(_cell("%.2f" % _last(b, "ph"), COLS[5][2], C_DIM))
	var w := float(b["water"])
	var wc := C_WATER if w > -0.7 else (C_GOOD if w > -1.0 else C_WARN)
	h.add_child(_cell("%.2f" % w, COLS[6][2], wc, wc.darkened(0.82), "Stem water potential %.2f MPa\n> −0.7 no stress · −0.7 to −1.0 mild (good for quality) · < −1.2 strong" % w))
	for k in ["downy", "powdery", "botrytis"]:
		var v := float(b[k])
		var col := _risk_col(v)
		h.add_child(_cell("%d %%" % roundi(v), COLS[["downy", "powdery", "botrytis"].find(k) + 7][2], col.lightened(0.15), col.darkened(0.78),
			"%s infection risk %d %% (model)\n%s" % [k.capitalize(), roundi(v), "Rain Mon–Tue will raise this" if k == "botrytis" else ""]))
	h.add_child(_cell(_thousands(int(b["yieldKgHa"])), COLS[10][2], C_TXT, Color(0, 0, 0, 0), "Estimated yield %s kg/ha from bunch counts × berry weight" % _thousands(int(b["yieldKgHa"]))))
	var hp := PanelContainer.new(); hp.custom_minimum_size = Vector2(COLS[11][2], 42)
	hp.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0), 3, Color(0, 0, 0, 0), 0, 8))
	var bar := ProgressBar.new(); bar.min_value = 0; bar.max_value = 1; bar.value = float(b["health"]); bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10); bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hv := float(b["health"])
	bar.add_theme_stylebox_override("background", _sb(Color("0c1116"), 4, Color(0, 0, 0, 0), 0, 0))
	bar.add_theme_stylebox_override("fill", _sb(C_GOOD if hv > 0.87 else C_WARN, 4, Color(0, 0, 0, 0), 0, 0))
	bar.tooltip_text = "Canopy health %d %%" % roundi(hv * 100)
	hp.add_child(bar); h.add_child(hp)
	return wrap

# ------------------------------------------------------------------ ripeness chart
func _chart_panel() -> Control:
	var pv := _panel("Ripeness", "°Oe (solid) · TA g/L (dashed) · dotted = 14-day projection")
	var legend := HBoxContainer.new(); legend.add_theme_constant_override("separation", 8)
	for b in blocks:
		var chipb := Button.new(); chipb.text = "  %s  %s" % [b["id"], b["name"]]
		chipb.add_theme_font_size_override("font_size", 14)
		chipb.add_theme_color_override("font_color", BLOCK_COL[b["id"]])
		chipb.pressed.connect(func(): selected = b["id"]; _rebuild_table(); chart.queue_redraw())
		legend.add_child(chipb)
	pv[1].add_child(legend)
	chart = Control.new()
	chart.custom_minimum_size = Vector2(0, 360)
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.mouse_filter = Control.MOUSE_FILTER_STOP
	chart.draw.connect(_draw_chart)
	chart.gui_input.connect(func(e): if e is InputEventMouseMotion: chart.queue_redraw())
	pv[1].add_child(chart)
	return pv[0]

func _draw_chart() -> void:
	var r := Rect2(Vector2(58, 30), chart.size - Vector2(58 + 58, 30 + 34))
	var weeks: Array = D["weeks"]
	var n := weeks.size() + 2          # two projected weeks
	var oe_min := 40.0; var oe_max := 100.0
	var ta_min := 6.0; var ta_max := 24.0
	var X := func(i: float) -> float: return r.position.x + r.size.x * i / (n - 1)
	var Y := func(v: float) -> float: return r.position.y + r.size.y * (1.0 - (v - oe_min) / (oe_max - oe_min))
	var YT := func(v: float) -> float: return r.position.y + r.size.y * (1.0 - (v - ta_min) / (ta_max - ta_min))
	# Prädikat bands
	for band in [[70.0, 76.0, "Kabinett"], [76.0, 83.0, "Spätlese"], [83.0, 100.0, "Auslese+"]]:
		var y0: float = Y.call(band[1]); var y1: float = Y.call(band[0])
		chart.draw_rect(Rect2(r.position.x, y0, r.size.x, y1 - y0), Color(C_ACC, 0.035 + 0.02 * ["Kabinett", "Spätlese", "Auslese+"].find(band[2])))
		chart.draw_string(font_ui, Vector2(r.end.x - 90, y1 - 6), band[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(C_ACC, 0.7))
	for v in range(40, 101, 10):
		var y: float = Y.call(v)
		chart.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(C_LINE, 0.8), 1.0)
		chart.draw_string(font_num, Vector2(10, y + 5), "%d" % v, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_FAINT)
	for v in [8, 12, 16, 20]:
		chart.draw_string(font_num, Vector2(r.end.x + 10, YT.call(v) + 5), "%d" % v, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(C_WATER, 0.7))
	chart.draw_string(font_ui, Vector2(20, 14), "°Oe", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_DIM)
	chart.draw_string(font_ui, Vector2(r.end.x + 8, 14), "TA g/L", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(C_WATER, 0.8))
	var labels := weeks.duplicate(); labels.append("3 Oct"); labels.append("10 Oct")
	for i in n:
		var x: float = X.call(i)
		chart.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(C_LINE, 0.35), 1.0)
		chart.draw_string(font_num, Vector2(x - 24, r.end.y + 24), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_FAINT if i >= weeks.size() else C_DIM)
	var today_x: float = X.call(weeks.size() - 1)
	chart.draw_dashed_line(Vector2(today_x, r.position.y), Vector2(today_x, r.end.y), Color(C_TXT, 0.35), 1.0, 5.0)
	chart.draw_string(font_ui, Vector2(today_x + 6, r.position.y + 16), "today", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_DIM)
	var sel_b: Dictionary
	for pass_i in 2:
		for b in blocks:
			var is_sel: bool = b["id"] == selected
			if (pass_i == 0) == is_sel:
				continue
			if is_sel: sel_b = b
			var col: Color = BLOCK_COL[b["id"]]
			var oe: Array = b["oe"]
			var pts := PackedVector2Array()
			for i in oe.size():
				pts.append(Vector2(X.call(i), Y.call(float(oe[i]))))
			chart.draw_polyline(pts, Color(col, 1.0 if is_sel else 0.28), 3.5 if is_sel else 1.6, true)
			if is_sel:
				var slope := float(oe[-1]) - float(oe[-2])
				var proj := PackedVector2Array([pts[-1]])
				var cone := PackedVector2Array([pts[-1]])
				var lo := PackedVector2Array()
				for k in [1, 2]:
					var v: float = float(oe[-1]) + slope * float(k) * (0.8 - 0.15 * float(k))
					proj.append(Vector2(X.call(oe.size() - 1 + k), Y.call(v)))
					cone.append(Vector2(X.call(oe.size() - 1 + k), Y.call(v + 2.5 * k)))
					lo.append(Vector2(X.call(oe.size() - 1 + k), Y.call(v - 2.5 * k)))
				lo.reverse()
				cone.append_array(lo)
				chart.draw_colored_polygon(cone, Color(col, 0.12))
				for i in proj.size() - 1:
					chart.draw_dashed_line(proj[i], proj[i + 1], col, 2.5, 3.0)
				for p in pts:
					chart.draw_circle(p, 4.5, col)
				var ta: Array = b["ta"]
				var tpts := PackedVector2Array()
				for i in ta.size():
					tpts.append(Vector2(X.call(i), YT.call(float(ta[i]))))
				for i in tpts.size() - 1:
					chart.draw_dashed_line(tpts[i], tpts[i + 1], Color(C_WATER, 0.9), 2.0, 7.0)
	# hover crosshair + tooltip for the selected Block
	var m := chart.get_local_mouse_position()
	var hover_i := -1
	if r.has_point(m):
		hover_i = clampi(roundi((m.x - r.position.x) / r.size.x * (n - 1)), 0, weeks.size() - 1)
	if not shot2.is_empty():
		hover_i = weeks.size() - 2      # show the tooltip in the screenshot
	if hover_i >= 0 and sel_b:
		var x: float = X.call(hover_i)
		chart.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(C_TXT, 0.5), 1.0)
		var oev := float(sel_b["oe"][hover_i]); var tav := float(sel_b["ta"][hover_i]); var phv := float(sel_b["ph"][hover_i])
		var box := Rect2(Vector2(x + 14, Y.call(oev) - 74), Vector2(210, 86))
		chart.draw_style_box(_sb(Color("0a0f13"), 6, BLOCK_COL[sel_b["id"]], 1, 0), box)
		chart.draw_string(font_bold, box.position + Vector2(12, 24), "Block %s · %s" % [sel_b["id"], weeks[hover_i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_TXT)
		chart.draw_string(font_num, box.position + Vector2(12, 48), "%d °Oe   %.1f g/L TA" % [roundi(oev), tav], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_ACC)
		chart.draw_string(font_num, box.position + Vector2(12, 72), "pH %.2f   ≈ %.1f °Brix" % [phv, oev / 4.25], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_DIM)

# ------------------------------------------------------------------ forecast
func _forecast_panel() -> Control:
	var pv := _panel("7-day forecast", "Bernkastel · ensemble mean")
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6)
	pv[1].add_child(h)
	for d in D["forecast"]:
		var card := PanelContainer.new()
		var rainy: bool = float(d["rain"]) > 5.0
		card.add_theme_stylebox_override("panel", _sb(C_WATER.darkened(0.8) if rainy else C_PANEL2, 6, C_WATER.darkened(0.3) if rainy else Color(0, 0, 0, 0), 1 if rainy else 0, 6))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2); v.alignment = BoxContainer.ALIGNMENT_CENTER; card.add_child(v)
		var dl := _label(String(d["day"]), 14, C_DIM); dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(dl)
		var icon := Control.new(); icon.custom_minimum_size = Vector2(0, 44)
		var kind := String(d["icon"])
		icon.draw.connect(func(): _draw_weather_icon(icon, kind))
		v.add_child(icon)
		var tl := _label("%d° / %d°" % [int(d["tmax"]), int(d["tmin"])], 16, C_TXT, font_num); tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(tl)
		var rl := _label("%.1f mm" % float(d["rain"]), 14, C_WATER if rainy else C_FAINT, font_num); rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(rl)
		var bar := ColorRect.new(); bar.color = C_WATER; bar.custom_minimum_size = Vector2(0, maxf(2.0, float(d["rain"]) * 1.6)); v.add_child(bar)
		card.tooltip_text = "%s: %d–%d °C, %.1f mm, RH %d %%" % [d["day"], int(d["tmin"]), int(d["tmax"]), float(d["rain"]), int(d["rh"])]
		h.add_child(card)
	return pv[0]

func _draw_weather_icon(c: Control, kind: String) -> void:
	var cx := c.size.x / 2.0; var cy := 22.0
	if kind == "sun":
		for i in 8:
			var a := TAU * i / 8.0
			c.draw_line(Vector2(cx, cy) + Vector2(cos(a), sin(a)) * 13, Vector2(cx, cy) + Vector2(cos(a), sin(a)) * 18, C_ACC, 2.0, true)
		c.draw_circle(Vector2(cx, cy), 9.0, C_ACC)
	else:
		var cc := Color("b8c3cc") if kind == "cloud" else Color("8fa0ad")
		c.draw_circle(Vector2(cx - 8, cy + 2), 8.0, cc); c.draw_circle(Vector2(cx + 2, cy - 4), 10.0, cc); c.draw_circle(Vector2(cx + 11, cy + 3), 7.0, cc)
		c.draw_rect(Rect2(cx - 8, cy + 2, 19, 8), cc)
		if kind == "rain":
			for i in 3:
				c.draw_line(Vector2(cx - 7 + i * 7, cy + 14), Vector2(cx - 10 + i * 7, cy + 22), C_WATER, 2.0, true)

# ------------------------------------------------------------------ inbox
func _inbox_panel() -> Control:
	var pv := _panel("Inbox", "4 messages")
	var first := true
	for msg in D["inbox"]:
		var pr := String(msg["priority"])
		var accent := C_BAD if pr == "high" else (C_ACC2 if pr == "normal" else C_FAINT)
		var card := PanelContainer.new()
		var st := _sb(C_PANEL2 if first else Color("11181f"), 5, Color(0, 0, 0, 0), 0, 14)
		st.border_color = accent; st.border_width_left = 4
		card.add_theme_stylebox_override("panel", st)
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); card.add_child(v)
		var h := HBoxContainer.new(); v.add_child(h)
		h.add_child(_label(String(msg["from"]), 14, accent.lightened(0.2), font_bold))
		var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(sp)
		h.add_child(_label(String(msg["time"]), 13, C_FAINT, font_num))
		var subj := _label(String(msg["subject"]), 17 if first else 15, C_TXT, font_bold if first else null)
		subj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(subj)
		if first and String(msg["body"]) != "":
			var body := _label(String(msg["body"]), 15, C_DIM)
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(body)
			var acts := HBoxContainer.new(); acts.add_theme_constant_override("separation", 8)
			var a1 := Button.new(); a1.text = "Plan harvest: Block C, Saturday"
			a1.add_theme_stylebox_override("normal", _sb(C_ACC.darkened(0.55), 5, C_ACC, 1, 12)); a1.add_theme_color_override("font_color", C_ACC.lightened(0.3))
			acts.add_child(a1)
			var a2 := Button.new(); a2.text = "Why?  Explain the risk"; acts.add_child(a2)
			v.add_child(acts)
		pv[1].add_child(card)
		first = false
	return pv[0]

func _harvest_panel() -> Control:
	var pv := _panel("Harvest readiness", "target style per Block")
	var targets := {"A": [82, "Spätlese trocken"], "B": [78, "Kabinett feinherb"], "C": [72, "Kabinett"], "D": [90, "Spätburgunder"], "E": [74, "Kabinett"]}
	for b in blocks:
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10)
		var id := _label(String(b["id"]), 16, BLOCK_COL[b["id"]], font_bold); id.custom_minimum_size = Vector2(18, 0); h.add_child(id)
		var tgt: Array = targets[b["id"]]
		var nm := _label(String(tgt[1]), 14, C_DIM); nm.custom_minimum_size = Vector2(150, 0); h.add_child(nm)
		var oe := _last(b, "oe")
		var frac := clampf(oe / float(tgt[0]), 0.0, 1.0)
		var bar := ProgressBar.new(); bar.max_value = 1.0; bar.value = frac; bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bar.custom_minimum_size = Vector2(0, 10); bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("background", _sb(Color("0c1116"), 4, Color(0, 0, 0, 0), 0, 0))
		bar.add_theme_stylebox_override("fill", _sb(C_GOOD if frac >= 1.0 else C_ACC, 4, Color(0, 0, 0, 0), 0, 0))
		h.add_child(bar)
		var st := "READY" if frac >= 1.0 else "%d/%d °Oe" % [roundi(oe), int(tgt[0])]
		var sl := _label(st, 14, C_GOOD if frac >= 1.0 else C_TXT, font_num); sl.custom_minimum_size = Vector2(84, 0); h.add_child(sl)
		h.tooltip_text = "Block %s: %d of %d °Oe for %s · botrytis risk %d %%" % [b["id"], roundi(oe), int(tgt[0]), tgt[1], int(b["botrytis"])]
		pv[1].add_child(h)
	return pv[0]

func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out
