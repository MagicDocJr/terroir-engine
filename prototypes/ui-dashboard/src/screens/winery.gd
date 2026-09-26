# PROTOTYPE — Winery: Lots in their vessels, fermentation curve + temperature (two charts, no dual axis), cellar choices.
extends RefCounted

const UI := preload("res://src/ui.gd")
const Charts := preload("res://src/charts.gd")

static func build(D: Dictionary, S) -> Control:
	var lots: Array = D["lots"]
	var sel: String = S.state.get("lot", "B")
	var v := UI.vbox(16)
	v.add_child(UI.page_header("Winery", "Each Block's harvest is its own Lot. Your Cellar master (Experienced) carries out the choices you set here."))
	var row := UI.hbox(18); row.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(row)
	var lp := UI.panel("Lots", "", 8); lp[0].custom_minimum_size = Vector2(380, 0); row.add_child(lp[0])
	for l in lots: lp[1].add_child(_lot_card(l, l["id"] == sel, S))
	var cur: Dictionary = lots[0]
	for l in lots:
		if l["id"] == sel: cur = l
	var mid := UI.vbox(16); mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(mid)
	if cur["status"] == "idle":
		var pv := UI.panel("Lot %s" % cur["id"]); pv[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
		pv[1].add_child(UI.head("Block E is still on the vine.", 26, UI.INK))
		pv[1].add_child(UI.label("Tank T5 is reserved for it. Decide the harvest in Ripeness, then the Lot appears here with its must analysis.", 17, UI.INK2, null, true))
		mid.add_child(pv[0])
		return v
	mid.add_child(_numbers(cur))
	var fc := UI.panel("Fermentation", "must weight falls as yeast turn sugar into alcohol")
	fc[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
	var labels := []
	for i in (cur["oe"] as Array).size(): labels.append("d%d" % i)
	var ch := Charts.LineChart.new(); ch.labels = labels
	ch.series = [{"name": "Lot %s" % cur["id"], "short": "°Oe", "values": cur["oe"], "color": UI.BLOCK[cur["block"]]}]
	ch.y_min = 0; ch.y_max = 100; ch.y_step = 20; ch.unit = " °Oe"
	ch.label_every = 2; ch.custom_minimum_size = Vector2(0, 230); ch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if S.capture: ch.demo_hover = (cur["oe"] as Array).size() - 3
	fc[1].add_child(ch)
	mid.add_child(fc[0])
	var tp := UI.panel("Temperature", "°C in the vessel; dashed line = setpoint")
	var tl := []
	for i in (cur["temp"] as Array).size(): tl.append("d%d" % i)
	var tch := Charts.LineChart.new(); tch.labels = tl
	var ser := [{"name": "Temperature", "short": "°C", "values": cur["temp"], "color": UI.INK2}]
	if cur["setC"] != null:
		var setv := []
		for i in tl.size(): setv.append(float(cur["setC"]))
		ser.push_front({"name": "Setpoint", "short": "set", "values": setv, "color": Color("75818a"), "dashed": true})
	tch.series = ser
	var tmax := 32.0 if cur["block"] == "D" else 20.0
	tch.y_min = 5; tch.y_max = tmax; tch.y_step = 5 if tmax > 20 else 5; tch.unit = " °C"; tch.label_every = 2; tch.custom_minimum_size = Vector2(0, 170)
	tp[1].add_child(tch)
	mid.add_child(tp[0])
	row.add_child(_choices(D, cur, S))
	return v

static func _lot_card(l: Dictionary, selected: bool, S) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sb(UI.RAISED if selected else UI.SUNKEN, 5, UI.GOLD if selected else Color(0, 0, 0, 0), 1 if selected else 0, 14))
	p.mouse_filter = Control.MOUSE_FILTER_STOP; p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: S.state["lot"] = l["id"]; S.rerender())
	var v := UI.vbox(4); p.add_child(v)
	var h := UI.hbox(10)
	h.add_child(UI.block_tag(String(l["id"])))
	var nv := UI.vbox(0); nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nl := UI.label("Lot %s, %s" % [l["id"], l["vessel"]], 15, UI.INK, UI.f_body_b); nl.clip_text = true; nl.custom_minimum_size = Vector2(270, 0); nv.add_child(nl)
	nv.add_child(UI.label(String(l["phase"]), 14, UI.INK2))
	h.add_child(nv)
	v.add_child(h)
	var h2 := UI.hbox(10)
	var kind: String = {"ok": "good", "warn": "warn", "idle": "idle"}[l["status"]]
	h2.add_child(UI.status(kind, {"ok": "On track", "warn": "Needs attention", "idle": "Not picked"}[l["status"]]))
	h2.add_child(UI.spacer())
	if (l["oe"] as Array).size() > 1:
		var sp := Charts.Sparkline.new(); sp.values = l["oe"]; sp.color = UI.BLOCK[l["block"]]; sp.custom_minimum_size = Vector2(130, 26)
		h2.add_child(sp)
		h2.add_child(UI.num("%d °Oe" % roundi(float((l["oe"] as Array)[-1])), 16, UI.INK))
	v.add_child(h2)
	return p

static func _numbers(l: Dictionary) -> Control:
	var p := PanelContainer.new()
	var h := UI.hbox(22); p.add_child(h)
	var t := UI.vbox(0)
	t.add_child(UI.head("Lot %s" % l["id"], 28, UI.INK))
	t.add_child(UI.label("Picked %s, %s L" % [l["picked"], UI.thousands(int(l["volume"]))], 14, UI.INK2))
	h.add_child(t)
	var m: Dictionary = l["must"]
	var items := [["Day", str(int(l["day"]))], ["Now", "%d °Oe" % roundi(float((l["oe"] as Array)[-1]))],
		["Temperature", "%.1f °C" % float(l["tempC"])], ["Must", "%d °Oe, TA %.1f, pH %.2f" % [int(m["oe"]), float(m["ta"]), float(m["ph"])]],
		["YAN in must", "%d mg N/L" % int(m["yan"]) if m["yan"] != null else "n/a"]]
	for it in items:
		var c := UI.vbox(0)
		c.add_child(UI.label(it[0], 13, UI.MUTED))
		var warn: bool = it[0] == "YAN in must" and m["yan"] != null and int(m["yan"]) < 140
		c.add_child(UI.num(it[1], 20, UI.SERIOUS if warn else UI.INK))
		if warn: c.tooltip_text = "Below about 140 mg N/L fermentations often slow and can smell of hydrogen sulfide."
		h.add_child(c)
	if l.has("analysis"):
		var a: Dictionary = l["analysis"]
		var c2 := UI.vbox(0); c2.add_child(UI.label("After the stop", 13, UI.MUTED))
		c2.add_child(UI.num("%.1f %% vol, RS %d g/L" % [float(a["abv"]), int(a["rs"])], 20, UI.INK)); h.add_child(c2)
	return p

static func _choices(D: Dictionary, l: Dictionary, S) -> Control:
	var pv := UI.panel("Cellar choices", "applied by the Cellar master")
	pv[0].custom_minimum_size = Vector2(470, 0)
	var opts: Dictionary = D["choiceOptions"]
	var why: Dictionary = D["choiceWhy"]
	var key := "choices_%s" % l["id"]
	if not S.state.has(key): S.state[key] = (l["choices"] as Dictionary).duplicate()
	var ch: Dictionary = S.state[key]
	var focus: String = S.state.get("choice_focus", "Sweetness" if l["block"] != "D" else "Cap management")
	for k in ch:
		var h := UI.hbox(10)
		var kl := UI.label(String(k), 15, UI.INK2); kl.custom_minimum_size = Vector2(130, 0); h.add_child(kl)
		var ob := OptionButton.new(); ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ob.custom_minimum_size = Vector2(220, 38)
		ob.fit_to_longest_item = false; ob.clip_text = true; ob.tooltip_text = String(ch[k])
		var list: Array = opts.get(k, [ch[k]])
		if not (ch[k] in list): list = [ch[k]] + list
		for i in list.size():
			ob.add_item(String(list[i]))
			if String(list[i]) == String(ch[k]): ob.select(i)
		ob.item_selected.connect(func(i): ch[k] = list[i]; S.state["choice_focus"] = k; S.notify("%s for Lot %s: %s" % [k, l["id"], list[i]]); S.rerender())
		h.add_child(ob)
		var wb := UI.button("Why?", false, 14); wb.custom_minimum_size = Vector2(60, 38)
		wb.pressed.connect(func(): S.state["choice_focus"] = k; S.rerender())
		h.add_child(wb)
		pv[1].add_child(h)
	pv[1].add_child(UI.divider())
	var box := PanelContainer.new()
	var st := UI.sb(UI.SUNKEN, 5, Color(0, 0, 0, 0), 0, 18); st.border_color = UI.GOLD; st.border_width_left = 3
	box.add_theme_stylebox_override("panel", st)
	var bv := UI.vbox(6); box.add_child(bv)
	bv.add_child(UI.head(focus, 18, UI.INK))
	bv.add_child(UI.label(String(why.get(focus, "")), 16, UI.INK2, null, true))
	pv[1].add_child(box)
	pv[1].add_child(UI.spacer(false))
	pv[1].add_child(UI.label("Choices lock once they happen: you can't un-press a Lot. Future steps stay editable.", 13, UI.MUTED, null, true))
	return pv[0]
