# PROTOTYPE — Plot & Blocks: sortable Block table, a schematic Plot map, and the soil profile of the selected Block.
extends RefCounted

const UI := preload("res://src/ui.gd")
const Charts := preload("res://src/charts.gd")

const COLS := [["id", "Block", 70], ["name", "Name", 240], ["variety", "Variety", 170], ["status", "Status", 190], ["oe", "°Oe", 90], ["ta", "TA g/L", 96],
	["water", "Ψstem MPa", 120], ["downy", "Downy", 100], ["powdery", "Powdery", 104], ["botrytis", "Botrytis", 108], ["yieldKgHa", "Yield kg/ha", 120], ["health", "Canopy", 170]]

static func build(D: Dictionary, S) -> Control:
	var blocks: Array = D["blocks"]
	var sel: String = S.state.get("block", "A")
	var v := UI.vbox(16)
	var p: Dictionary = D["plot"]
	v.add_child(UI.page_header(String(p["name"]),
		"%d Blocks on %.1f ha of steep slate. %s, trained %s. Classification: %s." % [int(p["blocks"]), float(p["ha"]), p["leaf"], p["training"], p["classification"]]))
	v.add_child(_table(D, S, sel))
	var row := UI.hbox(18); row.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(row)
	var b: Dictionary = blocks[0]
	for x in blocks:
		if x["id"] == sel: b = x
	row.add_child(_map_panel(D, S, sel))
	row.add_child(_facts_panel(b))
	var sp := UI.panel("Soil profile, Block %s" % sel, "from the pit dug before Planting")
	sp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var prof = Charts.SoilProfile.new(); prof.profile = b["soilProfile"]; prof.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp[1].add_child(prof)
	row.add_child(sp[0])
	return v

static func _val(b: Dictionary, k: String):
	if k in ["oe", "ta"]: return float((b[k] as Array)[-1])
	if k == "status": return String(b["harvested"]) if b["harvested"] != null else "~"
	return b[k]

static func _table(D: Dictionary, S, sel: String) -> Control:
	var pv := UI.panel("Blocks", "click a header to sort, a row to inspect it; hover a value for detail", 3)
	var sort_key: String = S.state.get("plot_sort", "id")
	var desc: bool = S.state.get("plot_desc", false)
	var head := UI.hbox(3)
	for c in COLS:
		var b := UI.button(String(c[1]) + ((" ▼" if desc else " ▲") if sort_key == c[0] else ""), false, 14)
		b.custom_minimum_size = Vector2(c[2], 32); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_stylebox_override("normal", UI.sb(UI.SUNKEN, 3, Color(0, 0, 0, 0), 0, 9))
		b.add_theme_color_override("font_color", UI.GOLD if sort_key == c[0] else UI.MUTED)
		b.pressed.connect(func():
			if sort_key == c[0]: S.state["plot_desc"] = not desc
			else: S.state["plot_sort"] = c[0]; S.state["plot_desc"] = c[0] in ["oe", "downy", "powdery", "botrytis", "yieldKgHa"]
			S.rerender())
		head.add_child(b)
	pv[1].add_child(head)
	var rows: Array = (D["blocks"] as Array).duplicate()
	rows.sort_custom(func(a, b):
		var va = _val(a, sort_key); var vb = _val(b, sort_key)
		return (va > vb) if desc else (va < vb))
	for b in rows: pv[1].add_child(_row(b, b["id"] == sel, S))
	return pv[0]

static func _row(b: Dictionary, selected: bool, S) -> Control:
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", UI.sb(UI.RAISED if selected else Color(0, 0, 0, 0), 4, UI.GOLD if selected else Color(0, 0, 0, 0), 1 if selected else 0, 0))
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP; wrap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	wrap.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: S.state["block"] = b["id"]; S.rerender())
	var h := UI.hbox(3); wrap.add_child(h)
	var idc := PanelContainer.new(); idc.custom_minimum_size = Vector2(COLS[0][2], 40)
	idc.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 9))
	idc.add_child(UI.block_tag(String(b["id"]))); h.add_child(idc)
	h.add_child(UI.table_cell(String(b["name"]), COLS[1][2], UI.INK, Color(0, 0, 0, 0),
		"%s\nSlope %d°, aspect %s, %d m\nRootstock %s, clone %s" % [b["soil"], int(b["slope"]), b["aspect"], int(b["elevation"]), b["rootstock"], b["clone"]], UI.f_body, 16))
	h.add_child(UI.table_cell(String(b["variety"]), COLS[2][2], UI.INK2, Color(0, 0, 0, 0), "", UI.f_body, 15))
	var harvested = b["harvested"]
	var stxt := "Picked %s" % _short_date(String(harvested)) if harvested != null else "Hanging"
	h.add_child(UI.table_cell(stxt, COLS[3][2], UI.INK2 if harvested != null else UI.INK, Color(0, 0, 0, 0),
		"Harvested and in the Winery as Lot %s" % b["id"] if harvested != null else "Still on the vine: target %s (%d °Oe)" % [b["target"]["style"], int(b["target"]["oe"])], UI.f_body, 15))
	var oe := float((b["oe"] as Array)[-1])
	var t := clampf((oe - 65.0) / 35.0, 0, 1)
	h.add_child(UI.table_cell("%d" % roundi(oe), COLS[4][2], UI.INK, Color(UI.SEQ, 0.12 + 0.45 * t),
		"Must weight %d °Oe (about %.1f °Brix)\nMosel Riesling minimums: Kabinett 70, Spätlese 76, Auslese 83" % [roundi(oe), oe / 4.2]))
	var ta := float((b["ta"] as Array)[-1])
	h.add_child(UI.table_cell("%.1f" % ta, COLS[5][2], UI.INK, Color(UI.SEQ, 0.1 + 0.4 * clampf((ta - 7.0) / 5.0, 0, 1)), "Titratable acidity %.1f g/L as tartaric" % ta))
	var w := float(b["water"])
	h.add_child(UI.table_cell("%.2f" % w, COLS[6][2], UI.INK, Color(0, 0, 0, 0),
		"Stem water potential %.2f MPa\nAbove −0.7 no stress, −0.7 to −1.2 moderate (often good for quality), below −1.2 strong" % w))
	for k in ["downy", "powdery", "botrytis"]:
		var val := float(b[k])
		var cell := UI.hbox(6); cell.custom_minimum_size = Vector2(COLS[["downy", "powdery", "botrytis"].find(k) + 7][2], 40)
		cell.add_child(UI.label("▲" if val >= 20 else "●", 12, UI.risk_col(val)))
		cell.add_child(UI.num("%d %%" % roundi(val), 17, UI.INK))
		cell.tooltip_text = "%s infection risk (model): %d %%" % [k.capitalize(), roundi(val)]
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(cell)
	h.add_child(UI.table_cell(UI.thousands(int(b["yieldKgHa"])), COLS[10][2], UI.INK, Color(0, 0, 0, 0), "%s kg/ha from bunch counts × berry weight" % UI.thousands(int(b["yieldKgHa"]))))
	var hc := MarginContainer.new(); hc.custom_minimum_size = Vector2(COLS[11][2], 40); hc.add_theme_constant_override("margin_right", 12)
	var m = Charts.Meter.new(); m.value = float(b["health"]); m.color = UI.GOOD if float(b["health"]) > 0.87 else UI.WARN
	m.custom_minimum_size = Vector2(90, 10); m.tooltip_text = "Canopy health %d %%" % roundi(float(b["health"]) * 100)
	hc.add_child(m); h.add_child(hc)
	return wrap

static func _short_date(iso: String) -> String:
	var parts := iso.split("-")
	var months := ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s" % [int(parts[2]), months[int(parts[1])]]

class PlotMap extends Control:
	var sel := "A"
	var shell
	var blocks: Array = []
	const UI2 := preload("res://src/ui.gd")
	# Schematic polygons, uphill at the top (normalised 0–1 coordinates)
	const SHAPES := {
		"E": [Vector2(0.05, 0.04), Vector2(0.62, 0.02), Vector2(0.58, 0.24), Vector2(0.08, 0.27)],
		"D": [Vector2(0.64, 0.02), Vector2(0.96, 0.06), Vector2(0.93, 0.36), Vector2(0.60, 0.26)],
		"A": [Vector2(0.08, 0.29), Vector2(0.58, 0.26), Vector2(0.92, 0.38), Vector2(0.90, 0.58), Vector2(0.10, 0.56)],
		"B": [Vector2(0.10, 0.58), Vector2(0.90, 0.60), Vector2(0.88, 0.78), Vector2(0.12, 0.77)],
		"C": [Vector2(0.12, 0.79), Vector2(0.88, 0.80), Vector2(0.86, 0.97), Vector2(0.14, 0.96)],
	}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(300, 300)

	func _pts(id: String) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in SHAPES[id]: out.append(Vector2(p.x * size.x, p.y * (size.y - 24)))
		return out

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			for id in SHAPES:
				if Geometry2D.is_point_in_polygon(e.position, _pts(id)):
					shell.state["block"] = id; shell.rerender(); return
		if e is InputEventMouseMotion: queue_redraw()

	func _draw() -> void:
		for id in SHAPES:
			var pts := _pts(id)
			var col: Color = UI2.BLOCK[id]
			var is_sel: bool = id == sel
			draw_colored_polygon(pts, Color(col, 0.55 if is_sel else 0.25))
			var closed := pts.duplicate(); closed.append(pts[0])
			draw_polyline(closed, UI2.GOLD if is_sel else Color(col, 0.9), 3.0 if is_sel else 1.5, true)
			var c := Vector2.ZERO
			for p in pts: c += p
			c /= pts.size()
			draw_string(UI2.f_head, c + Vector2(-8, 8), id, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI2.INK)
		draw_string(UI2.f_body, Vector2(0, size.y - 4), "Uphill at the top, river below", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI2.MUTED)

static func _map_panel(D: Dictionary, S, sel: String) -> Control:
	var pv := UI.panel("Plot map", "click a Block")
	pv[0].custom_minimum_size = Vector2(380, 0)
	var m := PlotMap.new(); m.sel = sel; m.shell = S; m.blocks = D["blocks"]; m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv[1].add_child(m)
	return pv[0]

static func _facts_panel(b: Dictionary) -> Control:
	var pv := UI.panel("Block %s, %s" % [b["id"], b["name"]])
	pv[0].custom_minimum_size = Vector2(420, 0)
	var g := GridContainer.new(); g.columns = 2
	g.add_theme_constant_override("h_separation", 20); g.add_theme_constant_override("v_separation", 9)
	var rows := [["Variety", b["variety"]], ["Rootstock", b["rootstock"]], ["Clone", b["clone"]], ["Planted", "%d (%dth leaf)" % [int(b["planted"]), int(b["leaf"])]],
		["Training", b["training"]], ["Density", "%s vines/ha" % UI.thousands(int(b["density"]))], ["Area", "%.2f ha" % float(b["area"])],
		["Elevation", "%d m" % int(b["elevation"])], ["Slope, aspect", "%d°, %s" % [int(b["slope"]), b["aspect"]]], ["Soil", b["soil"]],
		["Available water", "%d mm" % int(b["awc"])], ["Target", "%s, %d °Oe" % [b["target"]["style"], int(b["target"]["oe"])]]]
	for r in rows:
		var k := UI.label(String(r[0]), 15, UI.MUTED); k.custom_minimum_size = Vector2(130, 0); g.add_child(k)
		var val := UI.label(String(r[1]), 16, UI.INK, null, true); val.custom_minimum_size = Vector2(230, 0); g.add_child(val)
	pv[1].add_child(g)
	var sp := Charts.Sparkline.new(); sp.values = b["oe"]; sp.color = UI.BLOCK[b["id"]]; sp.custom_minimum_size = Vector2(0, 40)
	pv[1].add_child(UI.label("Must weight since 18 Aug", 14, UI.MUTED))
	pv[1].add_child(sp)
	return pv[0]
