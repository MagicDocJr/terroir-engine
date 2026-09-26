# PROTOTYPE — Ripeness: °Oe, TA and pH per Block as separate charts (no dual axis), picks recorded, harvest-window planner.
extends RefCounted

const UI := preload("res://src/ui.gd")
const Charts := preload("res://src/charts.gd")

static func build(D: Dictionary, S) -> Control:
	var blocks: Array = D["blocks"]
	var sel: String = S.state.get("ripe_block", "E")
	var v := UI.vbox(16)
	var chips := UI.hbox(6)
	for b in blocks:
		var btn := UI.button("%s  %s" % [b["id"], b["name"]], false, 15)
		var active: bool = b["id"] == sel
		var st := UI.sb(Color(UI.BLOCK[b["id"]], 0.3) if active else UI.RAISED, 4, UI.BLOCK[b["id"]] if active else UI.LINE, 2 if active else 1, 12)
		btn.add_theme_stylebox_override("normal", st)
		btn.pressed.connect(func(): S.state["ripe_block"] = b["id"]; S.rerender())
		chips.add_child(btn)
	v.add_child(UI.page_header("Ripeness", "Weekly berry samples of 200 berries per Block. Highlight a Block to follow it; the others stay faint for comparison.", [chips]))
	var row := UI.hbox(18); row.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(row)
	var left := UI.vbox(16); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(left)
	var labels: Array = (D["weeks"] as Array).duplicate()
	labels.append("27 Oct"); labels.append("3 Nov")
	var oe_series := []; var ta_series := []; var ph_series := []
	for b in blocks:
		var name := "%s %s" % [b["id"], b["name"]]
		var s := {"name": name, "short": String(b["id"]), "values": b["oe"], "color": UI.BLOCK[b["id"]]}
		if b["harvested"] == null:
			var last := float((b["oe"] as Array)[-1])
			s["proj"] = [last + 1.6, last + 2.4]
		oe_series.append(s)
		ta_series.append({"name": name, "short": String(b["id"]), "values": b["ta"], "color": UI.BLOCK[b["id"]]})
		ph_series.append({"name": name, "short": String(b["id"]), "values": b["ph"], "color": UI.BLOCK[b["id"]]})
	var sel_name := ""
	for b in blocks:
		if b["id"] == sel: sel_name = "%s %s" % [b["id"], b["name"]]
	var op := UI.panel("Must weight (°Oe)", "dashed = 2-week projection; lines stop at harvest")
	op[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
	var oc := Charts.LineChart.new(); oc.labels = labels; oc.series = oe_series; oc.highlight = sel_name
	oc.y_min = 40; oc.y_max = 100; oc.y_step = 10; oc.unit = " °Oe"
	oc.bands = [{"lo": 70, "hi": 76, "label": "Kabinett ≥ 70"}, {"lo": 76, "hi": 83, "label": "Spätlese ≥ 76"}, {"lo": 83, "hi": 100, "label": "Auslese ≥ 83"}]
	oc.today = float((D["weeks"] as Array).size() - 1)
	oc.size_flags_vertical = Control.SIZE_EXPAND_FILL; oc.custom_minimum_size = Vector2(0, 330)
	if S.capture: oc.demo_hover = 4
	op[1].add_child(oc)
	left.add_child(op[0])
	var small := UI.hbox(16); left.add_child(small)
	for spec in [["Titratable acidity (g/L)", ta_series, 6.0, 24.0, 4.0, "%.0f", " g/L"], ["pH", ph_series, 2.6, 3.4, 0.2, "%.1f", ""]]:
		var pv := UI.panel(spec[0]); pv[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ch := Charts.LineChart.new(); ch.labels = labels; ch.series = spec[1]; ch.highlight = sel_name
		ch.y_min = spec[2]; ch.y_max = spec[3]; ch.y_step = spec[4]; ch.y_fmt = spec[5]; ch.unit = spec[6]
		ch.label_every = 3; ch.custom_minimum_size = Vector2(0, 200); ch.direct_labels = false
		ch.today = float((D["weeks"] as Array).size() - 1)
		pv[1].add_child(ch)
		small.add_child(pv[0])
	row.add_child(_planner(D, S, sel))
	return v

static func _planner(D: Dictionary, S, sel: String) -> Control:
	var pv := UI.panel("Harvest planner")
	pv[0].custom_minimum_size = Vector2(560, 0)
	for b in D["blocks"]:
		var h := UI.hbox(10)
		h.add_child(UI.block_tag(String(b["id"])))
		var nv := UI.vbox(0); nv.custom_minimum_size = Vector2(190, 0)
		nv.add_child(UI.label(String(b["target"]["style"]), 15, UI.INK))
		nv.add_child(UI.label("target %d °Oe" % int(b["target"]["oe"]), 13, UI.MUTED))
		h.add_child(nv)
		var oe := float((b["oe"] as Array)[-1])
		if b["harvested"] != null:
			var parts := String(b["harvested"]).split("-")
			var hl := UI.label("Picked %d Oct at %d °Oe" % [int(parts[2]), roundi(oe)] if parts[1] == "10" else "Picked %d Sep at %d °Oe" % [int(parts[2]), roundi(oe)], 15, UI.INK2)
			hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(hl)
			h.add_child(UI.status("good", "In the Winery"))
		else:
			var m = Charts.Meter.new(); m.value = oe / float(b["target"]["oe"]) * 0.9; m.target = 0.9; m.color = UI.BLOCK[b["id"]]
			m.size_flags_horizontal = Control.SIZE_EXPAND_FILL; m.custom_minimum_size = Vector2(120, 12)
			m.tooltip_text = "%d of %d °Oe. The tick marks the target." % [roundi(oe), int(b["target"]["oe"])]
			h.add_child(m)
			h.add_child(UI.num("%d / %d" % [roundi(oe), int(b["target"]["oe"])], 17, UI.INK))
		pv[1].add_child(h)
	pv[1].add_child(UI.divider())
	pv[1].add_child(UI.head("Block E: when to pick?", 19, UI.INK))
	var cal := UI.hbox(5)
	var fc: Array = D["weather"]["forecast"]
	var plan := ["watch", "watch", "pick?", "pick", "rain", "rain", "grey rot risk"]
	for i in fc.size():
		var d: Dictionary = fc[i]
		var rainy: bool = float(d["rain"]) > 5.0
		var col := UI.SERIOUS if rainy else (UI.GOLD if plan[i].begins_with("pick") else UI.SUNKEN)
		var c := PanelContainer.new(); c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_theme_stylebox_override("panel", UI.sb(Color(col, 0.22) if col != UI.SUNKEN else UI.SUNKEN, 4, Color(col, 0.7) if col != UI.SUNKEN else Color(0, 0, 0, 0), 1 if col != UI.SUNKEN else 0, 6))
		var cv := UI.vbox(2); c.add_child(cv)
		var dl := UI.label(String(d["day"]), 13, UI.INK2); dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cv.add_child(dl)
		var ic = Charts.WeatherIcon.new(); ic.kind = String(d["icon"]); ic.custom_minimum_size = Vector2(0, 38); cv.add_child(ic)
		var pl := UI.label(plan[i], 13, UI.INK); pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cv.add_child(pl)
		c.tooltip_text = "%s: %.1f mm. %s" % [d["day"], float(d["rain"]), d["note"]]
		cal.add_child(c)
	pv[1].add_child(cal)
	pv[1].add_child(UI.label("Projection: about +0.8 °Oe per dry day, more in the botrytised bunches. Picking crew: 2 days for 0.2 ha with a selective first pass.", 14, UI.INK2, null, true))
	var acts := UI.hbox(8)
	var a1 := UI.button("Plan a selective pass Friday", true); a1.pressed.connect(func(): S.notify("Harvest planned: Block E, Friday, selective pass (prototype)."))
	var a2 := UI.button("Pick all Thursday"); a2.pressed.connect(func(): S.notify("Harvest planned: Block E, Thursday (prototype)."))
	acts.add_child(a1); acts.add_child(a2)
	pv[1].add_child(acts)
	pv[1].add_child(UI.spacer(false))
	pv[1].add_child(UI.label("Must weight alone isn't ripeness. Taste berries and check seed colour for phenolic ripeness; that's the 3D walk in the full game.", 13, UI.MUTED, null, true))
	return pv[0]
