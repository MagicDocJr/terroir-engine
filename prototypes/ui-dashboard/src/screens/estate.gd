# PROTOTYPE — Estate: cash, P&L against budget, projected wine revenue, staff with Staff levels and 1–20 attributes.
extends RefCounted

const UI := preload("res://src/ui.gd")
const Charts := preload("res://src/charts.gd")

static func build(D: Dictionary, S) -> Control:
	var v := UI.vbox(18)
	v.add_child(UI.page_header("Estate", "Money and people. Nothing is sold until the first Wine is bottled, so this year runs on starting capital."))
	var row := UI.hbox(18); row.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(row)
	var left := UI.vbox(18); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(left)
	var right := UI.vbox(18); right.custom_minimum_size = Vector2(640, 0); row.add_child(right)
	left.add_child(_cash_panel(D))
	var pl := _pnl_panel(D); pl.size_flags_vertical = Control.SIZE_EXPAND_FILL; left.add_child(pl)
	right.add_child(_revenue_panel(D))
	var sp := _staff_panel(D, S); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL; right.add_child(sp)
	return v

static func _cash_panel(D: Dictionary) -> Control:
	var pv := UI.panel("Cash", "month end, 2025")
	var h := UI.hbox(28); pv[1].add_child(h)
	var cv := UI.vbox(0); h.add_child(cv)
	cv.add_child(UI.num(UI.euro(int(D["cash"])), 40, UI.INK))
	var flow: Array = D["cashflow"]
	cv.add_child(UI.label("%s since January" % UI.euro(int(flow[-1]) - int(flow[0])), 15, UI.INK2))
	var ch := Charts.LineChart.new()
	ch.labels = D["cashflowLabels"]
	var vals := []
	for x in flow: vals.append(float(x) / 1000.0)
	ch.series = [{"name": "Cash", "values": vals, "color": UI.SEQ}]
	ch.y_min = 160; ch.y_max = 220; ch.y_step = 20; ch.y_fmt = "€%dk"; ch.unit = "k"
	ch.direct_labels = false
	ch.custom_minimum_size = Vector2(0, 150); ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ch)
	return pv[0]

static func _pnl_panel(D: Dictionary) -> Control:
	var pv := UI.panel("Profit and loss", "year to date against budget")
	var head := UI.hbox(4)
	for c in [["Line", 300], ["Actual", 130], ["Budget", 130], ["Variance", 130], ["", 220]]:
		var l := UI.label(c[0], 14, UI.MUTED); l.custom_minimum_size = Vector2(c[1], 26); head.add_child(l)
	pv[1].add_child(head)
	var tot_a := 0; var tot_b := 0
	for ln in D["pnl"]:
		var a: int = int(ln["actual"]); var b: int = int(ln["budget"])
		tot_a += a; tot_b += b
		var h := UI.hbox(4)
		var name := UI.table_cell(String(ln["line"]), 300, UI.INK, Color(0, 0, 0, 0), String(ln.get("note", "")), UI.f_body, 16)
		h.add_child(name)
		h.add_child(UI.table_cell(UI.euro(a), 130, UI.INK))
		h.add_child(UI.table_cell(UI.euro(b), 130, UI.INK2))
		var var_ := a - b
		var over: bool = var_ < 0
		h.add_child(UI.table_cell(("+" if var_ > 0 else "") + UI.euro(var_) if var_ != 0 else "on budget", 130, UI.SERIOUS if over else (UI.GOOD.lightened(0.3) if var_ > 0 else UI.INK2)))
		var m = Charts.Meter.new(); m.custom_minimum_size = Vector2(200, 10)
		if b != 0:
			m.value = float(a) / float(b) * 0.8; m.target = 0.8
			m.color = UI.SERIOUS if over else UI.SEQ
		else:
			m.value = 0.0
		m.tooltip_text = "%s of budget" % ("%d %%" % roundi(100.0 * a / b) if b != 0 else "no budget")
		var mw := MarginContainer.new(); mw.add_theme_constant_override("margin_left", 10); mw.add_child(m); h.add_child(mw)
		pv[1].add_child(h)
	pv[1].add_child(UI.divider())
	var th := UI.hbox(4)
	th.add_child(UI.table_cell("Result so far", 300, UI.INK, Color(0, 0, 0, 0), "", UI.f_body_b, 17))
	th.add_child(UI.table_cell(UI.euro(tot_a), 130, UI.INK, Color(0, 0, 0, 0), "", UI.f_head, 18))
	th.add_child(UI.table_cell(UI.euro(tot_b), 130, UI.INK2))
	th.add_child(UI.table_cell(("+" if tot_a > tot_b else "") + UI.euro(tot_a - tot_b), 130, UI.SERIOUS if tot_a < tot_b else UI.GOOD.lightened(0.3)))
	pv[1].add_child(th)
	pv[1].add_child(UI.label("Variance: red means over budget. The bar's tick marks 100 % of budget.", 13, UI.MUTED))
	return pv[0]

static func _revenue_panel(D: Dictionary) -> Control:
	var pv := UI.panel("Projected wine revenue", "at planned ex-cellar prices")
	var rows := [["2025 Riesling Spätlese trocken", 2290, 19.5], ["2025 Riesling Kabinett feinherb", 3130, 13.5], ["2025 Spätburgunder trocken", 1250, 24.0]]
	var tot := 0
	for r in rows:
		var h := UI.hbox(10)
		var n := UI.label(String(r[0]), 16, UI.INK); n.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(n)
		h.add_child(UI.num("%s bottles" % UI.thousands(int(r[1])), 16, UI.INK2))
		h.add_child(UI.num("× €%.2f" % float(r[2]), 16, UI.INK2))
		var rev := int(float(r[1]) * float(r[2])); tot += rev
		var rl := UI.num(UI.euro(rev), 18, UI.INK); rl.custom_minimum_size = Vector2(110, 0); rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; h.add_child(rl)
		pv[1].add_child(h)
	pv[1].add_child(UI.divider())
	var th := UI.hbox(10)
	th.add_child(UI.label("After bottling in spring 2026", 15, UI.INK2)); th.add_child(UI.spacer())
	th.add_child(UI.num(UI.euro(tot), 22, UI.INK))
	pv[1].add_child(th)
	pv[1].add_child(UI.label("Prices depend on Legal category and the quality assessment. Game simplification: no market dynamics yet.", 13, UI.MUTED, null, true))
	return pv[0]

static func _staff_panel(D: Dictionary, S) -> Control:
	var pv := UI.panel("Staff", "Staff level sets skill, salary and how much they explain")
	for s in D["staff"]:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.sb(UI.SUNKEN, 5, Color(0, 0, 0, 0), 0, 16))
		var cv := UI.vbox(8); card.add_child(cv)
		var h := UI.hbox(10)
		var nv := UI.vbox(0); h.add_child(nv)
		nv.add_child(UI.head(String(s["name"]), 20, UI.INK))
		nv.add_child(UI.label(String(s["role"]), 14, UI.INK2))
		h.add_child(UI.spacer())
		var lv := UI.vbox(0); h.add_child(lv)
		var lvl := UI.label(String(s["level"]), 15, UI.INK, UI.f_body_b); lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; lv.add_child(lvl)
		var sal := UI.label("%s / month" % UI.euro(int(s["salary"])) if int(s["salary"]) > 0 else "free (Mentor)", 14, UI.MUTED)
		sal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; lv.add_child(sal)
		cv.add_child(h)
		var grid := GridContainer.new(); grid.columns = 6
		grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 4)
		for k in s["attrs"]:
			var val: int = int(s["attrs"][k])
			var kl := UI.label(String(k), 14, UI.INK2); kl.custom_minimum_size = Vector2(150, 0); grid.add_child(kl)
			grid.add_child(UI.num(str(val), 18, UI.rating_col(val)))
			grid.add_child(UI.spacer(true, 8))
		cv.add_child(grid)
		if String(s["role"]) != "Mentor":
			var up := UI.button("See candidates to replace")
			up.size_flags_horizontal = Control.SIZE_SHRINK_END
			up.pressed.connect(func(): S.notify("Hiring is part of the full game."))
			cv.add_child(up)
		pv[1].add_child(card)
	return pv[0]
