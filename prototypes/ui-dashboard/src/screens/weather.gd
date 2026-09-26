# PROTOTYPE — Weather: season vs normal (heat, rain), disease-risk small multiples, phenology, 7-day forecast.
# Disease risk uses small multiples with one neutral line each (the title names the series), so no categorical colour
# competes with the Block colours used elsewhere.
extends RefCounted

const UI := preload("res://src/ui.gd")
const Charts := preload("res://src/charts.gd")

static func build(D: Dictionary, S) -> Control:
	var W: Dictionary = D["weather"]
	var v := UI.vbox(16)
	v.add_child(UI.page_header("Weather", "%s. Season from 1 April, compared with the 1991–2020 normal." % W["station"]))
	v.add_child(_indices(W))
	var row := UI.hbox(18); v.add_child(row)
	row.add_child(_heat(W, S))
	row.add_child(_rain(W))
	var row2 := UI.hbox(18); row2.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(row2)
	row2.add_child(_risk(W, S))
	row2.add_child(_forecast(W))
	return v

static func _stat(title: String, value: String, delta: String, tip: String, good := true) -> Control:
	var p := PanelContainer.new(); p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vv := UI.vbox(2); p.add_child(vv)
	vv.add_child(UI.label(title, 15, UI.INK2))
	var h := UI.hbox(10); vv.add_child(h)
	h.add_child(UI.num(value, 30, UI.INK))
	var dl := UI.label(delta, 15, UI.INK2); dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(dl)
	p.tooltip_text = tip
	return p

static func _indices(W: Dictionary) -> Control:
	var I: Dictionary = W["indices"]
	var h := UI.hbox(14)
	h.add_child(_stat("Growing degree days", "%s" % UI.thousands(int(I["winkler"])), "normal %s" % UI.thousands(int(I["winklerNormal"])),
		"Heat above 10 °C summed since 1 April. The Winkler index uses April–October; this is season to date."))
	h.add_child(_stat("Huglin index", "%d" % int(I["huglin"]), "normal %d" % int(I["huglinNormal"]),
		"Weights daytime maximum temperatures and day length. Riesling ripens reliably from about 1 700."))
	h.add_child(_stat("Mean temperature", "%.1f °C" % float(I["seasonTmean"]), "normal %.1f °C" % float(I["seasonTmeanNormal"]), "Average daily mean since 1 April."))
	h.add_child(_stat("Rain", "%d mm" % int(I["rainSeason"]), "normal %d mm" % int(I["rainSeasonNormal"]), "Rain since 1 April. October is to date."))
	var ph := PanelContainer.new(); ph.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ph.size_flags_stretch_ratio = 2.2
	var pv := UI.vbox(6); ph.add_child(pv)
	pv.add_child(UI.label("Vine stages this Vintage", 15, UI.INK2))
	var tl := UI.hbox(0); pv.add_child(tl)
	for st in W["phenology"]:
		var c := UI.vbox(0); c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_child(UI.num(String(st["date"]), 17, UI.INK))
		c.add_child(UI.label(String(st["stage"]), 13, UI.MUTED))
		tl.add_child(c)
	h.add_child(ph)
	return h

static func _heat(W: Dictionary, S) -> Control:
	var pv := UI.panel("Heat accumulation", "growing degree days since 1 April")
	pv[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ch := Charts.LineChart.new()
	var labels := []; var a := []; var n := []
	for w in W["weekly"]:
		labels.append(w["date"]); a.append(float(w["gdd"])); n.append(float(w["gddNormal"]))
	ch.labels = labels
	ch.series = [{"name": "Normal", "short": "Normal", "values": n, "color": Color("75818a"), "dashed": true}, {"name": "2025", "short": "2025", "values": a, "color": UI.SEQ}]
	ch.y_min = 0; ch.y_max = 1400; ch.y_step = 200; ch.unit = " GDD"
	ch.label_every = 4
	ch.custom_minimum_size = Vector2(0, 250)
	if S.capture: ch.demo_hover = 20
	pv[1].add_child(ch)
	return pv[0]

static func _rain(W: Dictionary) -> Control:
	var pv := UI.panel("Rain by month", "bar = 2025, line = normal")
	pv[0].custom_minimum_size = Vector2(620, 0)
	var ch := Charts.BarNormalChart.new()
	ch.labels = W["months"]; ch.values = W["rain"]; ch.normals = W["rainNormal"]
	ch.y_max = 100; ch.y_step = 25; ch.partial_last = "to date"
	ch.custom_minimum_size = Vector2(0, 250)
	pv[1].add_child(ch)
	return pv[0]

static func _risk(W: Dictionary, S) -> Control:
	var pv := UI.panel("Disease risk", "last 60 days, model output from temperature, humidity and leaf wetness")
	pv[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UI.hbox(14); h.size_flags_vertical = Control.SIZE_EXPAND_FILL; pv[1].add_child(h)
	var labels := []
	for r in W["risk"]: labels.append(r["date"])
	for spec in [["downy", "Downy mildew", "Spreads after rain on warm days."], ["powdery", "Powdery mildew", "Likes warm, humid, shaded canopies."],
			["botrytis", "Botrytis", "Rises in wet, mild autumn weather."]]:
		var col := UI.vbox(4); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var vals := []
		for r in W["risk"]: vals.append(float(r[spec[0]]))
		var t := UI.hbox(8)
		t.add_child(UI.head(spec[1], 17, UI.INK))
		t.add_child(UI.spacer())
		var now: float = vals[-1]
		t.add_child(UI.status(UI.risk_kind(now), "%d %% now" % roundi(now)))
		col.add_child(t)
		col.add_child(UI.label(spec[2], 13, UI.MUTED, null, true))
		var ch := Charts.LineChart.new()
		ch.labels = labels
		ch.series = [{"name": spec[1], "values": vals, "color": UI.INK2}]
		ch.bands = [{"lo": 20, "hi": 35, "label": "watch"}, {"lo": 35, "hi": 100, "label": "serious"}]
		ch.y_min = 0; ch.y_max = 100; ch.y_step = 25; ch.unit = " %"
		ch.direct_labels = false; ch.label_every = 20
		ch.custom_minimum_size = Vector2(0, 200); ch.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(ch)
		h.add_child(col)
	return pv[0]

static func _forecast(W: Dictionary) -> Control:
	var pv := UI.panel("Next 7 days", "ensemble mean")
	pv[0].custom_minimum_size = Vector2(620, 0)
	var h := UI.hbox(6); pv[1].add_child(h)
	for d in W["forecast"]:
		var rainy: bool = float(d["rain"]) > 5.0
		var card := PanelContainer.new(); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UI.sb(Color(UI.SEQ, 0.16) if rainy else UI.SUNKEN, 5, Color(UI.SEQ, 0.6) if rainy else Color(0, 0, 0, 0), 1 if rainy else 0, 6))
		var cv := UI.vbox(2); card.add_child(cv)
		var dl := UI.label(String(d["day"]), 14, UI.INK2); dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cv.add_child(dl)
		var ic = Charts.WeatherIcon.new(); ic.kind = String(d["icon"]); cv.add_child(ic)
		var tl := UI.num("%d° / %d°" % [int(d["tmax"]), int(d["tmin"])], 16, UI.INK); tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cv.add_child(tl)
		var rl := UI.num("%.1f mm" % float(d["rain"]), 15, UI.INK if rainy else UI.MUTED); rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cv.add_child(rl)
		card.tooltip_text = "%s: %d–%d °C, %.1f mm, humidity %d %%. %s" % [d["day"], int(d["tmin"]), int(d["tmax"]), float(d["rain"]), int(d["rh"]), d["note"]]
		h.add_child(card)
	pv[1].add_child(UI.spacer(false, 8))
	pv[1].add_child(UI.head("What it means", 17, UI.INK))
	pv[1].add_child(UI.label("Fog mornings with dry afternoons until Thursday: good conditions for noble rot in Block E. The front on Saturday brings 18 mm; after that, botrytis turns grey quickly.", 15, UI.INK2, null, true))
	pv[1].add_child(UI.label("Forecast skill drops after 3–4 days. A Senior Vineyard manager reads further ahead.", 13, UI.MUTED, null, true))
	return pv[0]
