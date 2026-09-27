# Weather: forecast (horizon depends on the Vineyard manager), season so far against the 1991–2020 normal, disease risk, phenology.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const Charts := preload("res://src/ui/charts.gd")

static func build(D: Dictionary, shell) -> Control:
	var W: Dictionary = D["weather"]
	var v := UI.vbox(16)
	v.add_child(UI.page_header("Weather", "%s · %s" % [W["station"], D["weatherMode"]]))
	# forecast strip
	var fp: Array = UI.panel("Forecast", "%d days from your %s Vineyard manager · further ahead is less certain" % [int(D["staff"]["vineyard"]["forecastDays"]), String(D["staff"]["vineyard"]["level"]).to_lower()])
	var fh := UI.hbox(10)
	var fc: Array = W.get("forecast", [])
	if fc.is_empty(): fh.add_child(UI.label("No forecast.", 15, UI.MUTED))
	for f in fc:
		var c := PanelContainer.new(); c.add_theme_stylebox_override("panel", UI.sb(UI.RAISED, 6, UI.LINE, 1, 10))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := UI.vbox(2); c.add_child(cv)
		var dl := UI.label(String(f["day"]), 15, UI.INK2, UI.f_body_b); dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cv.add_child(dl)
		var ic = Charts.WeatherIcon.new(); ic.kind = String(f["icon"]); cv.add_child(ic)
		var tl := UI.num("%d° / %d°" % [int(f["tmax"]), int(f["tmin"])], 18); tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cv.add_child(tl)
		var rl := UI.label("%d %% · %.0f mm" % [int(f["prob"]), float(f["rain"])], 14, UI.SEQ.lightened(0.3) if int(f["prob"]) >= 50 else UI.MUTED); rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cv.add_child(rl)
		c.tooltip_text = "Max %d °C, min %d °C, %d %% chance of rain (%.0f mm), humidity %d %%" % [int(f["tmax"]), int(f["tmin"]), int(f["prob"]), float(f["rain"]), int(f["rh"])]
		fh.add_child(c)
	fp[1].add_child(fh)
	v.add_child(fp[0])
	var row := UI.hbox(16); v.add_child(row)
	var wk: Array = W.get("weekly", [])
	var labels := []; var gdd := []; var gddn := []; var tm := []; var tmn := []
	for w in wk:
		labels.append(w["date"]); gdd.append(w["gdd"]); gddn.append(w["gddNormal"]); tm.append(w["tmean"]); tmn.append(w["tmeanNormal"])
	var gp: Array = UI.panel("Heat accumulation", "growing degree days above 10 °C since 1 April")
	gp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gc = Charts.LineChart.new()
	gc.labels = labels
	gc.series = [{"name": "This year", "values": gdd, "color": UI.BLOCK["B"]}, {"name": "Normal 1991–2020", "short": "Normal", "values": gddn, "color": UI.INK2, "dashed": true, "width": 1.5}]
	var gmax := 200.0
	for x in gdd + gddn: gmax = maxf(gmax, float(x))
	gc.y_max = ceilf(gmax / 250.0) * 250.0; gc.y_step = 250.0 if gc.y_max <= 1500 else 500.0; gc.y_fmt = "%d"; gc.unit = " GDD"
	gc.label_every = maxi(1, labels.size() / 7); gc.custom_minimum_size = Vector2(0, 280)
	gp[1].add_child(gc)
	row.add_child(gp[0])
	var tp: Array = UI.panel("Weekly mean temperature", "°C, Block A microclimate")
	tp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tc = Charts.LineChart.new()
	tc.labels = labels
	tc.series = [{"name": "This year", "values": tm, "color": UI.BLOCK["B"]}, {"name": "Normal 1991–2020", "short": "Normal", "values": tmn, "color": UI.INK2, "dashed": true, "width": 1.5}]
	tc.y_min = -5; tc.y_max = 30; tc.y_step = 5; tc.y_fmt = "%d°"; tc.unit = " °C"
	tc.label_every = maxi(1, labels.size() / 7); tc.custom_minimum_size = Vector2(0, 280)
	tp[1].add_child(tc)
	row.add_child(tp[0])
	var row2 := UI.hbox(16); v.add_child(row2)
	var rp: Array = UI.panel("Rain by month", "bars this year · line is the normal")
	rp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bc = Charts.BarNormalChart.new()
	var ml := []; var mv := []; var mn := []
	var rmax := 50.0
	for m in W["months"]:
		ml.append(m["month"]); mv.append(m["rain"] if m["past"] else 0); mn.append(m["normal"])
		rmax = maxf(rmax, maxf(float(m["rain"]), float(m["normal"])))
	bc.labels = ml; bc.values = mv; bc.normals = mn; bc.y_max = ceilf(rmax / 25.0) * 25.0; bc.y_step = 25.0 if bc.y_max <= 150 else 50.0
	bc.custom_minimum_size = Vector2(0, 250)
	rp[1].add_child(bc)
	row2.add_child(rp[0])
	var kp: Array = UI.panel("Disease risk", "last 120 days · 0–100 · above 35 = serious")
	kp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var risk: Array = W.get("risk", [])
	var rl2 := []; var dn := []; var pw := []; var bt := []
	for r in risk:
		rl2.append(r["date"]); dn.append(r["downy"]); pw.append(r["powdery"]); bt.append(r["botrytis"])
	if risk.size() > 1:
		var kc = Charts.LineChart.new()
		kc.labels = rl2
		kc.series = [{"name": "Downy mildew", "short": "Downy", "values": dn, "color": UI.BLOCK["A"]}, {"name": "Powdery mildew", "short": "Powdery", "values": pw, "color": UI.BLOCK["D"]}, {"name": "Botrytis", "values": bt, "color": UI.BLOCK["E"]}]
		kc.y_max = 100; kc.y_step = 25; kc.bands = [{"lo": 35, "hi": 100, "label": "serious"}]
		kc.label_every = maxi(1, rl2.size() / 6); kc.custom_minimum_size = Vector2(0, 250)
		kp[1].add_child(kc)
	else:
		kp[1].add_child(UI.label("Risk tracking starts at budburst.", 15, UI.MUTED))
	row2.add_child(kp[0])
	var row3 := UI.hbox(16); v.add_child(row3)
	var ip: Array = UI.panel("Season indices", "")
	ip[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var I: Dictionary = W["indices"]
	ip[1].add_child(UI.kv("Winkler (GDD >10 °C)", "%d  (normal to date %d)" % [int(I["winkler"]), int(I["winklerNormal"])], "Growing degree days, 1 April–31 October. Region I < 1390 (cool) … Region V > 2220 (hot)."))
	ip[1].add_child(UI.kv("Huglin index", "%d" % int(I["huglin"]), "Weights daytime heat and latitude. Riesling needs ≈1500, Cabernet Sauvignon ≈1900."))
	ip[1].add_child(UI.kv("Growing-season mean", "%.1f °C" % float(I["seasonTmean"]), "April–October mean temperature (Jones). Cool < 16.5 °C, intermediate to 18.5, warm to 21."))
	ip[1].add_child(UI.kv("Rain since budburst", "%d mm" % int(I["rainSeason"])))
	var today: Dictionary = W["today"]
	ip[1].add_child(UI.kv("Today", "%s–%s °C, %s mm, humidity %s %%, wind %s km/h" % [today["tmin"], today["tmax"], today["rain"], today["rh"], today["wind"]]))
	row3.add_child(ip[0])
	var pp: Array = UI.panel("Phenology", "Block A")
	pp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for ph in W["phenology"]:
		pp[1].add_child(UI.kv(String(ph["stage"]), String(ph["date"]) if ph["date"] != null else "—"))
	row3.add_child(pp[0])
	return UI.scroll(v)
