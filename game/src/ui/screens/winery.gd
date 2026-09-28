# Winery: every Lot with its fermentation curve, live analysis, the cellar choices (locked once they can't change), and the log.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const Metrics := preload("res://src/ui/metrics.gd")
const Charts := preload("res://src/ui/charts.gd")

static func build(D: Dictionary, shell) -> Control:
	var lots: Array = []
	for l in D.get("lots", []):
		if String(l["phase"]) != "Blended": lots.append(l)
	lots.sort_custom(func(a, b): return int(a["vintage"]) > int(b["vintage"]) or (int(a["vintage"]) == int(b["vintage"]) and String(a["id"]) < String(b["id"])))
	var v := UI.vbox(16)
	var b3 := UI.button("See the hall in 3D"); b3.pressed.connect(func(): shell.toggle_3d("hall"))
	var b4 := UI.button("Barrel cellar in 3D"); b4.pressed.connect(func(): shell.toggle_3d("cellar"))
	v.add_child(UI.page_header("Winery", "Each Block's grapes become one Lot. Choices before fermentation lock when it starts; others can change until bottling.", [b3, b4]))
	if lots.is_empty():
		var p: Array = UI.panel("No Lots yet", "")
		p[1].add_child(UI.label("Harvest a Block and its grapes arrive here the next day. You can prepare the cellar choices as soon as the Lot is received, before fermentation starts.", 16, UI.INK2, null, true))
		v.add_child(p[0])
		return v
	var sel_id: String = shell.state.get("lot_sel", lots[0]["id"])
	var L: Dictionary = lots[0]
	for l in lots:
		if l["id"] == sel_id: L = l
	# wraps: two Vintages in the cellar (long oak ageing) can mean eight or more Lots
	var tabs := HFlowContainer.new(); tabs.add_theme_constant_override("h_separation", 8); tabs.add_theme_constant_override("v_separation", 8)
	var last_v := -1
	for l in lots:
		if int(l["vintage"]) != last_v:
			last_v = int(l["vintage"])
			var vl := UI.label(str(last_v), 14, UI.GOLD, UI.f_body_b); vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tabs.add_child(vl)
		var sel: bool = l["id"] == L["id"]
		var c := UI.card(sel, 12)
		var h := UI.hbox(10); c.add_child(h)
		h.add_child(UI.block_tag(l["block"], 15))
		var tv := UI.vbox(0); h.add_child(tv)
		tv.add_child(UI.label("%s · %s" % [l["id"], l["variety"]], 16, UI.INK, UI.f_body_b))
		var st := String(l["phase"])
		var col := UI.INK2
		if l["stuck"]: col = UI.CRIT; st = "STUCK"
		elif l["ready"]: col = UI.GOLD; st = "Ready to bottle"
		tv.add_child(UI.label("%s · %s L" % [st, UI.thousands(int(l["volume"]))], 14, col))
		var lid: String = l["id"]
		UI.on_click(c, func(): shell.state["lot_sel"] = lid; shell.show_screen("winery"))
		tabs.add_child(c)
	v.add_child(tabs)
	var row := UI.hbox(16); v.add_child(row)
	var left := UI.vbox(16); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(left)
	# status & analysis
	var ap: Array = UI.panel("Lot %s — %s from Block %s" % [L["id"], L["variety"], L["block"]], "picked %s · %s kg grapes" % [L["picked"], UI.thousands(int(L["kg"]))])
	var sl := UI.label(String(L["status"]), 17, UI.CRIT if L["stuck"] else UI.INK, UI.f_body_b, true); ap[1].add_child(sl)
	if L["stuck"]:
		var rb := UI.button("Restart the fermentation", true, 16)
		var lid2: String = L["id"]
		rb.pressed.connect(func(): shell.command("restart", lid2); shell.notify("Restart culture added: warmed, aerated, nutrients and acclimatised yeast."))
		rb.disabled = L.get("restarted", false)
		var sb := UI.button("Stop here, keep the sugar", false, 16)
		sb.pressed.connect(func(): shell.command("acceptstuck", lid2); shell.notify("Fermentation stopped: chilled and sulphured with the residual sugar left."))
		var bh := UI.hbox(10); bh.add_child(rb); bh.add_child(sb)
		ap[1].add_child(bh)
		if L.get("restarted", false): ap[1].add_child(UI.label("Already restarted once — a second restart won't help.", 14, UI.MUTED))
	var tiles := GridContainer.new(); tiles.columns = 5; tiles.add_theme_constant_override("h_separation", 12); tiles.add_theme_constant_override("v_separation", 12)
	var napa: bool = D["region"]["units"] == "brix"
	var items := [
		["Temperature", "%.1f °C" % float(L["tempC"]), ("set %d °C" % int(L["setC"])) if L["setC"] != null else "uncontrolled"],
		["Sugar", "%.1f g/L" % float(L["sugar"]), "%d °Oe" % int(L["oe"]) if not napa else ""],
		["Alcohol", "%.1f %%" % float(L["alcohol"]), "natural must %d °Oe" % int(L["naturalOe"])],
		["TA · pH", "%.1f · %.2f" % [float(L["ta"]), float(L["ph"])], "must %.1f · %.2f" % [float(L["must"]["ta"]), float(L["must"]["ph"])]],
		["Malic", "%.1f g/L" % float(L["malic"]), "falls with MLF"],
		["YAN", "%d mg/L" % int(L["yan"]), "yeast nitrogen"],
		["Free SO₂", "%d mg/L" % int(L["freeSo2"]), "molecular %.2f" % float(L["molSo2"])],
		["Volatile acidity", "%.2f g/L" % float(L["va"]), "vinegar above ≈0.9"],
		["Volume", "%s L" % UI.thousands(int(L["volume"])), ""],
	]
	if L["red"]:
		items.append(["Tannin", "%d mg/L" % int(L["tannin"]), ""])
		items.append(["Colour", "%d mg/L" % int(L["anth"]), "anthocyanins"])
	if String(L["phase"]) == "Ageing":
		items.append(["Ageing", "%d / %d months" % [int(L["ageingDay"]) / 30, int(L["ageingMonths"])], ""])
	var tile_keys := {"Temperature": "temp", "Sugar": "sugar", "Alcohol": "alcohol", "TA · pH": "ta", "Malic": "malic", "YAN": "yan", "Free SO₂": "molSo2", "Volatile acidity": "va", "Tannin": "tannin", "Colour": "colour"}
	for it in items:
		var t := UI.tile(it[0], it[1], it[2])
		if tile_keys.has(it[0]):
			t.tooltip_text = Metrics.tip(tile_keys[it[0]]) + ("\n\n" + Metrics.tip("ph") if it[0] == "TA · pH" else "")
			t.mouse_filter = Control.MOUSE_FILTER_PASS
		t.add_theme_stylebox_override("panel", UI.sb(UI.RAISED, 6, Color(0, 0, 0, 0), 0, 12))
		t.custom_minimum_size = Vector2(150, 0)
		tiles.add_child(t)
	ap[1].add_child(tiles)
	left.add_child(ap[0])
	# curves
	var curve: Array = L.get("curve", [])
	if curve.size() > 1:
		var ch := UI.hbox(16); left.add_child(ch)
		var labels := []; var sug := []; var tmp := []
		var step := maxi(1, curve.size() / 60)
		for i in range(0, curve.size(), step):
			labels.append("day %d" % int(curve[i]["day"])); sug.append(curve[i]["oe"]); tmp.append(curve[i]["temp"])
		var sp: Array = UI.panel("Fermentation", "sugar, °Oe")
		sp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sc = Charts.LineChart.new(); sc.labels = labels; sc.series = [{"name": "Sugar", "values": sug, "color": UI.GOLD}]
		var smax := 20.0
		for x in sug: smax = maxf(smax, float(x))
		sc.y_min = 0; sc.y_max = ceilf(smax / 20.0) * 20.0; sc.y_step = 20; sc.unit = " °Oe"; sc.custom_minimum_size = Vector2(0, 240); sc.label_every = maxi(1, labels.size() / 6); sc.direct_labels = false
		sp[1].add_child(sc); ch.add_child(sp[0])
		var tp: Array = UI.panel("Temperature", "°C in the tank")
		tp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tc = Charts.LineChart.new(); tc.labels = labels; tc.series = [{"name": "Tank", "values": tmp, "color": UI.BLOCK["B"]}]
		tc.y_min = 0; tc.y_max = 40; tc.y_step = 10; tc.unit = " °C"; tc.custom_minimum_size = Vector2(0, 240); tc.label_every = maxi(1, labels.size() / 6); tc.direct_labels = false
		tc.bands = [{"lo": 32, "hi": 40, "label": "yeast die"}]
		tp[1].add_child(tc); ch.add_child(tp[0])
	# log
	var lp: Array = UI.panel("Cellar log", "")
	var lv := UI.vbox(2)
	var log: Array = L.get("log", [])
	for i in range(log.size() - 1, maxi(-1, log.size() - 30), -1):
		lv.add_child(UI.label("·  " + String(log[i]), 14, UI.INK2, null, true))
	lp[1].add_child(lv)
	left.add_child(lp[0])
	# choices
	var cp: Array = UI.panel("Cellar choices", "🔒 = fixed once fermentation starts")
	cp[0].custom_minimum_size = Vector2(560, 0)
	var lid3: String = L["id"]
	var bottled: bool = L["ready"] == false and String(L["phase"]) == "Blended"
	# design review §2: 3–4 key choices up front, the rest under "More choices" (the Cellar master's plan is a fine default)
	var key_set: Array = ["Destemming", "Cap management", "Red temperature", "Vessel"] if L["red"] else ["Pressing", "Temperature", "Sweetness", "Vessel"]
	var show_more: bool = shell.state.get("winery_more", false)
	cp[1].add_child(UI.label("Your Cellar master's plan for this Lot is already set. These are the choices that shape it most:", 14, UI.INK2, null, true))
	var opts: Array = []
	for opt in D.get("cellarOptions", []):
		if opt["key"] in key_set: opts.append(opt)
	var rest: Array = []
	for opt in D.get("cellarOptions", []):
		if not (opt["key"] in key_set): rest.append(opt)
	var more_btn := UI.button(("▾ Fewer choices" if show_more else "▸ More choices (%d)" % rest.size()), false, 14)
	more_btn.pressed.connect(func(): shell.state["winery_more"] = not show_more; shell.show_screen("winery"))
	if show_more: opts.append_array(rest)
	for opt in opts:
		if opt["whiteOnly"] and L["red"]: continue
		if opt["redOnly"] and not L["red"]: continue
		var key: String = opt["key"]
		if not (L["choices"] as Dictionary).has(key): continue
		var cur := int(L["choices"][key])
		var locked: bool = (opt["locked"] and L["started"]) or bottled
		var h := UI.hbox(8)
		var kl := UI.label(("🔒 " if locked and opt["locked"] else "") + key, 15, UI.MUTED if locked else UI.INK2)
		kl.custom_minimum_size = Vector2(150, 0); kl.tooltip_text = String(opt["why"]); kl.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(kl)
		var names: Array = opt["options"]
		var ob := UI.option(names, String(names[cur]), func(x): shell.apply("lot", lid3, key, str(names.find(x)), "Lot %s: %s → %s. Your Cellar master will do it this way." % [lid3, key, x]), 360)
		ob.disabled = locked
		ob.tooltip_text = String(opt["why"])
		h.add_child(ob)
		cp[1].add_child(h)
	cp[1].add_child(more_btn)
	cp[1].add_child(UI.label("Hover a choice for what it does. Changes apply straight away; there's nothing to confirm.", 13, UI.MUTED, null, true))
	row.add_child(cp[0])
	return UI.scroll(v)
