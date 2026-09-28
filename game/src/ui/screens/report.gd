# The Vintage report: the year in review once everything is in bottle. All numbers and wording come from the simulation
# (VintageReport.cs); this screen only lays them out.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const Charts := preload("res://src/ui/charts.gd")
const Avatar := preload("res://src/ui/avatar.gd")
const Metrics := preload("res://src/ui/metrics.gd")

static func build(D: Dictionary, shell) -> Control:
	var reps: Array = D.get("reports", [])
	var v := UI.vbox(16)
	if reps.is_empty():
		v.add_child(UI.page_header("Vintage report", "A Vintage's report appears when every one of its Lots is in bottle."))
		return v
	var want := int(shell.state.get("report_vintage", int(reps[0]["vintage"])))
	var R: Dictionary = reps[0]
	for r in reps:
		if int(r["vintage"]) == want: R = r
	if reps.size() > 1:
		var labels := []
		for r in reps: labels.append(str(int(r["vintage"])))
		v.add_child(UI.segmented(labels, str(int(R["vintage"])), func(x): shell.state["report_vintage"] = int(x); shell.show_screen("report"), 90))
	var W: Dictionary = R["weather"]
	# ---- title
	var top := UI.hbox(18)
	var tv := UI.vbox(2); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UI.label("THE %d VINTAGE · %s, %s" % [int(R["vintage"]), String(R["plot"]).to_upper(), String(R["region"]).to_upper()], 13, UI.GOLD, UI.f_body_b))
	tv.add_child(UI.head(String(R["verdict"]), 46, UI.INK))
	tv.add_child(UI.label(("Played on the weather that really happened in %s in %d." if W["historical"] else "Played on synthetic weather (recent climate plus the warming trend) for %s %d.") % [R["region"], int(R["vintage"])], 15, UI.INK2))
	top.add_child(tv)
	var wb := UI.button("Open the Tasting sheets", true, 16); wb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wb.pressed.connect(func(): shell.show_screen("wines"))
	top.add_child(wb)
	v.add_child(top)
	# ---- weather tiles against the normal
	var tiles := UI.hbox(12)
	tiles.add_child(_tile("Season heat (Winkler)", "%d" % int(W["winkler"]), "normal %d · %+d %%" % [int(W["winklerNormal"]), int(W["heatAnomalyPct"])], _anom_col(float(W["heatAnomalyPct"]), 4, 12), Metrics.tip("winkler")))
	tiles.add_child(_tile("Growing-season mean", "%.1f °C" % float(W["gst"]), "normal %.1f °C" % float(W["gstNormal"]), _anom_col((float(W["gst"]) - float(W["gstNormal"])) * 10, 4, 12), "Mean temperature April–October."))
	tiles.add_child(_tile("Rain April–October", "%d mm" % int(W["rain"]), "normal %d mm · %+d %%" % [int(W["rainNormal"]), int(W["rainAnomalyPct"])], _anom_col(float(W["rainAnomalyPct"]), 10, 30), "Total rain in the growing season."))
	tiles.add_child(_tile("Harvest-time rain", "%d mm" % int(W["rainAutumn"]), "normal %d mm (Sep–Oct)" % int(W["rainAutumnNormal"]), _anom_col((float(W["rainAutumn"]) / maxf(1, float(W["rainAutumnNormal"])) - 1) * 100, 10, 30), "Rain in September and October drives grey rot at harvest."))
	tiles.add_child(_tile("Days ≥ 35 °C", str(int(W["heatDays"])), "normal %.1f" % float(W["heatDaysNormal"]), UI.SERIOUS if int(W["heatDays"]) > float(W["heatDaysNormal"]) + 2 else UI.INK, "Days hot enough to scorch exposed bunches and pause ripening."))
	tiles.add_child(_tile("Frost nights after budburst", str(int(W["frostNights"])), "normal %.1f" % float(W["frostNightsNormal"]), UI.SERIOUS if int(W["frostNights"]) > 0 else UI.GOOD, "Nights ≤ −1 °C between budburst and 20 May."))
	v.add_child(tiles)
	# ---- what it meant + temperature chart
	var row := UI.hbox(16); v.add_child(row)
	var mp: Array = UI.panel("What the weather meant for your grapes", "")
	mp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in R["meant"]:
		var h := UI.hbox(8); h.add_child(UI.label("▸", 15, UI.GOLD))
		var l := UI.label(String(s), 15, UI.INK, null, true); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
		mp[1].add_child(h)
	row.add_child(mp[0])
	var cp: Array = UI.panel("Weekly temperature", "this year against the 1991–2020 normal")
	cp[0].custom_minimum_size = Vector2(760, 0)
	var labels := []; var tm := []; var tn := []
	for w in R.get("weekly", []):
		labels.append(w["date"]); tm.append(w["tmean"]); tn.append(w["tmeanNormal"])
	if labels.size() > 2:
		var tc = Charts.LineChart.new()
		tc.labels = labels
		tc.series = [{"name": "This year", "values": tm, "color": UI.BLOCK["B"]}, {"name": "Normal", "values": tn, "color": UI.INK2, "dashed": true, "width": 1.5}]
		tc.y_min = -5; tc.y_max = 30; tc.y_step = 5; tc.y_fmt = "%d°"; tc.unit = " °C"; tc.label_every = maxi(1, labels.size() / 6); tc.custom_minimum_size = Vector2(0, 230)
		cp[1].add_child(tc)
	row.add_child(cp[0])
	# ---- Blocks
	var bp: Array = UI.panel("Your Blocks through the year", "", 4)
	var g := GridContainer.new(); g.columns = 12; g.add_theme_constant_override("h_separation", 20); g.add_theme_constant_override("v_separation", 6)
	for hname in ["", "Variety", "Budburst", "Flowering", "Véraison", "Harvest", "°Oe", "TA", "pH", "hL/ha", "Rot", "Wine"]:
		g.add_child(UI.label(hname, 13, UI.MUTED, UI.f_body_b))
	for b in R["blocks"]:
		g.add_child(UI.block_tag(String(b["id"]), 14))
		g.add_child(UI.label(String(b["variety"]), 14, UI.INK))
		for k in ["budburst", "flowering", "veraison", "harvest"]: g.add_child(UI.num(String(b[k]) if b[k] != null else "—", 15, UI.INK2))
		g.add_child(UI.num(str(b["oe"]) if b["oe"] != null else "—", 15))
		g.add_child(UI.num(str(b["ta"]) if b["ta"] != null else "—", 15))
		g.add_child(UI.num(str(b["ph"]) if b["ph"] != null else "—", 15))
		g.add_child(UI.num(str(b["yieldHl"]) if b["yieldHl"] != null else "—", 15))
		var rot := float(b["rot"]) if b["rot"] != null else 0.0
		g.add_child(UI.num("%.1f %%" % rot, 15, UI.CRIT if rot > 5 else UI.INK))
		g.add_child(UI.label("%s · %s" % [b["wine"], b["quality"]] if b["wine"] != null else "—", 14, UI.GOLD if b["quality"] in ["Very good", "Outstanding"] else UI.INK2))
	bp[1].add_child(g)
	v.add_child(bp[0])
	# ---- wines + money
	var row2 := UI.hbox(16); v.add_child(row2)
	var wp: Array = UI.panel("Your wines", "")
	wp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wg := HFlowContainer.new(); wg.add_theme_constant_override("h_separation", 12); wg.add_theme_constant_override("v_separation", 12)
	for w in R["wines"]:
		var c := PanelContainer.new(); c.add_theme_stylebox_override("panel", UI.sb(Color("f1ead8"), 6, Color("b8a77a"), 1, 14)); c.custom_minimum_size = Vector2(280, 0)
		var cv := UI.vbox(2); c.add_child(cv)
		cv.add_child(UI.head(String(w["name"]), 20, Color("2a2216")))
		cv.add_child(UI.label(String(w["label"]), 13, Color("5a4a2e"), null, true))
		cv.add_child(UI.head(String(w["quality"]), 22, Color("8a5a10")))
		cv.add_child(UI.label("%s bottles · €%.2f · %s" % [UI.thousands(int(w["bottles"])), float(w["price"]), UI.euro(int(w["revenue"]))], 13, Color("6b5a3a")))
		wg.add_child(c)
	wp[1].add_child(wg)
	row2.add_child(wp[0])
	var M: Dictionary = R["money"]
	var mn: Array = UI.panel("The money", "costs in %d, sales of its wines" % int(R["vintage"]))
	mn[0].custom_minimum_size = Vector2(520, 0)
	mn[1].add_child(UI.kv("Wine sales", UI.euro(int(M["revenue"]))))
	mn[1].add_child(UI.kv("Costs", UI.euro(-int(M["costs"]))))
	mn[1].add_child(UI.kv("Result", UI.euro(int(M["result"])), "", UI.GOOD if float(M["result"]) >= 0 else UI.CRIT))
	mn[1].add_child(UI.label("Biggest costs", 13, UI.MUTED, UI.f_body_b))
	var mx := 1.0
	for t in M["topCosts"]: mx = maxf(mx, float(t["amount"]))
	for t in M["topCosts"]:
		var h := UI.hbox(8)
		var l := UI.label(String(t["category"]), 13, UI.INK2); l.custom_minimum_size = Vector2(130, 0); h.add_child(l)
		var m = Charts.Meter.new(); m.value = float(t["amount"]) / mx; m.color = UI.SEQ; m.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(m)
		var al := UI.num(UI.euro(int(t["amount"])), 14); al.custom_minimum_size = Vector2(90, 0); al.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; h.add_child(al)
		mn[1].add_child(h)
	row2.add_child(mn[0])
	# ---- key moments + next time
	var row3 := UI.hbox(16); v.add_child(row3)
	var ep: Array = UI.panel("Key moments", "")
	ep[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for e in R["events"]:
		var h := UI.hbox(10)
		var dl := UI.label(String(e["date"]), 14, UI.MUTED); dl.custom_minimum_size = Vector2(70, 0); h.add_child(dl)
		h.add_child(UI.label(String(e["text"]), 14, UI.INK))
		ep[1].add_child(h)
	row3.add_child(ep[0])
	var np: Array = UI.panel("Next time", "suggestions from what happened")
	np[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in R["next"]:
		var h := UI.hbox(8); h.add_child(UI.label("→", 15, UI.GOLD))
		var l := UI.label(String(s), 15, UI.INK, null, true); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
		np[1].add_child(h)
	row3.add_child(np[0])
	# ---- the Mentor's farewell
	if R.get("farewell", false):
		var fp := PanelContainer.new(); fp.add_theme_stylebox_override("panel", UI.sb(Color("2a2616"), 6, UI.GOLD.darkened(0.25), 1, 18))
		var fh := UI.hbox(16); fp.add_child(fh)
		var mentor: Dictionary = D.get("mentor", {})
		fh.add_child(Avatar.make(String(mentor.get("name", "")), "mentor", 64))
		var fl := UI.label("\"Every descriptor on your Tasting sheets traces back to this year's weather and your decisions. Read them next to this report, and you will know what to do differently.\" — %s" % mentor.get("name", "the Mentor"), 16, UI.INK, null, true)
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fh.add_child(fl)
		v.add_child(fp)
	return UI.scroll(v)

static func _tile(caption: String, value: String, sub: String, col: Color, tip: String) -> Control:
	var t := UI.tile(caption, value, sub, col)
	t.tooltip_text = tip
	t.mouse_filter = Control.MOUSE_FILTER_PASS
	return t

## Colour for an anomaly in percent: small = ink, moderate = warn, large = serious.
static func _anom_col(pct: float, mild: float, strong: float) -> Color:
	var a := absf(pct)
	return UI.SERIOUS if a >= strong else (UI.WARN if a >= mild else UI.INK)
