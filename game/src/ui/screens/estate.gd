# Estate: cash, P&L by category, ledger, staff, Establishment history, and the end-of-game summary.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const Charts := preload("res://src/ui/charts.gd")

static func build(D: Dictionary, shell) -> Control:
	var F: Dictionary = D.get("finance", {})
	var v := UI.vbox(16)
	v.add_child(UI.page_header("Estate", "%s · %s, %s" % [D["estate"], D["plot"]["name"], D["plot"]["region"]]))
	if String(D.get("phase", "")) == "Finished": v.add_child(_finished(D, shell))
	var vin: Dictionary = F.get("vintageByCategory", {})
	var spent := 0.0
	for k in vin:
		if float(vin[k]) < 0: spent += float(vin[k])
	var tiles := UI.hbox(14)
	tiles.add_child(UI.tile("Cash", UI.euro(int(F["cash"])), "after land, planting and Establishment", UI.INK if float(F["cash"]) >= 0 else UI.CRIT))
	tiles.add_child(UI.tile("Land value", UI.euro(int(F["landValue"])), "what you paid for the Plot"))
	tiles.add_child(UI.tile("Spent this Vintage", UI.euro(int(spent)), "since 1 January %d" % int(D["vintage"])))
	var rev := float(F.get("revenue", 0))
	tiles.add_child(UI.tile("Wine sales" if rev > 0 else "Projected sales", UI.euro(int(rev if rev > 0 else float(F.get("projectedRevenue", 0)))),
		"bottled and sold" if rev > 0 else "Mentor's rough estimate from the crop on the vine (UNVERIFIED prices)"))
	v.add_child(tiles)
	var mid := UI.hbox(16); v.add_child(mid)
	# cash chart
	var cp: Array = UI.panel("Cash since Planting", "")
	cp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var series: Array = F.get("cashSeries", [])
	var step := maxi(1, series.size() / 80)
	var labels := []; var vals := []
	var lo := 0.0; var hi := 0.0
	for i in range(0, series.size(), step):
		labels.append(series[i]["date"]); var c := float(series[i]["cash"]) / 1000.0; vals.append(c)
		lo = minf(lo, c); hi = maxf(hi, c)
	if series.size() > 0 and (series.size() - 1) % step != 0:
		labels.append(series[-1]["date"]); vals.append(float(series[-1]["cash"]) / 1000.0)
	var ch = Charts.LineChart.new()
	ch.labels = labels; ch.series = [{"name": "Cash", "values": vals, "color": UI.SEQ}]
	var span := maxf(50.0, hi - lo)
	var ystep := _nice(span / 5.0)
	ch.y_min = floorf(lo / ystep) * ystep; ch.y_max = ceilf(hi / ystep) * ystep + ystep * 0.01; ch.y_step = ystep
	ch.y_fmt = "€%dk"; ch.unit = "k"; ch.label_every = maxi(1, labels.size() / 6); ch.custom_minimum_size = Vector2(0, 300); ch.direct_labels = false
	cp[1].add_child(ch)
	mid.add_child(cp[0])
	# P&L
	var pl: Array = UI.panel("Profit & loss", "this Vintage · since founding")
	pl[0].custom_minimum_size = Vector2(620, 0)
	var all: Dictionary = F.get("byCategory", {})
	var keys := all.keys()
	keys.sort_custom(func(a, b): return float(all[a]) > float(all[b]))
	var tot_v := 0.0; var tot_a := 0.0
	for k in keys:
		var h := UI.hbox(8)
		var kl := UI.label(k, 15, UI.INK2); kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(kl)
		var a := float(vin.get(k, 0)); var b := float(all[k])
		tot_v += a; tot_a += b
		var al := UI.num(UI.euro(int(a)) if a != 0 else "—", 16, UI.GOOD if a > 0 else UI.INK); al.custom_minimum_size = Vector2(140, 0); al.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; h.add_child(al)
		var bl := UI.num(UI.euro(int(b)), 16, UI.GOOD if b > 0 else UI.INK); bl.custom_minimum_size = Vector2(150, 0); bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; h.add_child(bl)
		pl[1].add_child(h)
	pl[1].add_child(UI.divider())
	var th := UI.hbox(8)
	var tl := UI.label("Net", 15, UI.INK, UI.f_body_b); tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; th.add_child(tl)
	for pair in [[tot_v, 140], [tot_a, 150]]:
		var l := UI.num(UI.euro(int(pair[0])), 17, UI.GOOD if pair[0] > 0 else UI.CRIT); l.custom_minimum_size = Vector2(pair[1], 0); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; th.add_child(l)
	pl[1].add_child(th)
	mid.add_child(pl[0])
	var low := UI.hbox(16); v.add_child(low)
	# staff
	var sp: Array = UI.panel("Staff", "part-time posts sized to the estate")
	sp[0].custom_minimum_size = Vector2(700, 0)
	var S: Dictionary = D["staff"]
	var sal := {}
	for s in S["salaries"]: sal[s["level"]] = s
	var desc := {"vineyard": {"Junior": "Follows the book: never wrong, never insightful. %d-day forecasts.", "Experienced": "Times sprays and picking well. %d-day forecasts.", "Senior": "Reads the vintage and suggests moves you wouldn't think of. %d-day forecasts."},
		"cellar": {"Junior": "Keeps ferments safe and clean.", "Experienced": "Catches problems early and explains options.", "Senior": "Suggests stylistic choices that lift quality."}}
	for role in [["vineyard", "Vineyard manager"], ["cellar", "Cellar master"]]:
		var r: String = role[0]
		var cur: String = S[r]["level"]
		var h := UI.hbox(12)
		var l := UI.label(role[1], 16, UI.INK, UI.f_body_b); l.custom_minimum_size = Vector2(170, 0); h.add_child(l)
		var opts := []
		for lvl in ["Junior", "Experienced", "Senior"]: opts.append(lvl)
		h.add_child(UI.segmented(opts, cur, func(x):
			if x != cur:
				shell.command("staff", r, x)
				shell.notify("%s is now %s (%s a year)." % [role[1], x, UI.euro(int(sal[x][r]))]), 120))
		sp[1].add_child(h)
		var dtxt: String = desc[r][cur]
		if "%d" in dtxt: dtxt = dtxt % int(S["vineyard"]["forecastDays"])
		sp[1].add_child(UI.label("%s  %s a year for a %d %% post." % [dtxt, UI.euro(int(S[r]["salary"])), int(S[r].get("post", 100))], 14, UI.INK2, null, true))
	var m: Dictionary = D.get("mentor", {})
	sp[1].add_child(UI.divider())
	sp[1].add_child(UI.label(("Mentor: %s has retired." if m.get("retired", false) else "Mentor: %s — advises you through this first Vintage and retires once it is bottled.") % m.get("name", ""), 14, UI.MUTED, null, true))
	low.add_child(sp[0])
	# ledger
	var lp: Array = UI.panel("Ledger", "latest 40 entries")
	lp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp[0].custom_minimum_size = Vector2(0, 360)
	var lv := UI.vbox(2)
	for e in F.get("entries", []):
		var h := UI.hbox(10)
		var dl := UI.label(String(e["date"]), 14, UI.MUTED); dl.custom_minimum_size = Vector2(90, 0); h.add_child(dl)
		var cl := UI.label(String(e["category"]), 14, UI.INK2); cl.custom_minimum_size = Vector2(120, 0); h.add_child(cl)
		var nl := UI.label(String(e["note"]), 14, UI.INK); nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nl.clip_text = true; nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; nl.tooltip_text = String(e["note"]); nl.mouse_filter = Control.MOUSE_FILTER_PASS; h.add_child(nl)
		var al := UI.num(UI.euro(int(e["amount"])), 15, UI.GOOD if float(e["amount"]) > 0 else UI.INK); al.custom_minimum_size = Vector2(110, 0); al.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; h.add_child(al)
		lv.add_child(h)
	lp[1].add_child(UI.scroll(lv))
	lp[1].size_flags_vertical = Control.SIZE_EXPAND_FILL
	low.add_child(lp[0])
	var est: Array = D.get("establishment", [])
	if est.size() > 0:
		var ep: Array = UI.panel("Establishment years", "run by the Mentor while the vines grew in")
		for s in est: ep[1].add_child(UI.label("·  " + String(s), 15, UI.INK2, null, true))
		v.add_child(ep[0])
	return UI.scroll(v)

static func _nice(x: float) -> float:
	var p := pow(10.0, floorf(log(x) / log(10.0)))
	for m in [1.0, 2.0, 2.5, 5.0, 10.0]:
		if x <= m * p: return m * p
	return 10.0 * p

static func _finished(D: Dictionary, shell) -> Control:
	var p: Array = UI.panel("The Vintage is bottled", "")
	p[0].add_theme_stylebox_override("panel", UI.sb(Color("2a2616"), 6, UI.GOLD, 2, 20))
	var m: Dictionary = D.get("mentor", {})
	p[1].add_child(UI.label("%s has retired. \"You made %d wine%s from your first Vintage. Open each Tasting sheet and trace every descriptor back to what you did in the vineyard and the cellar — that is how you get better.\"" %
		[m.get("name", "The Mentor"), D.get("wines", []).size(), "" if D.get("wines", []).size() == 1 else "s"], 17, UI.INK, null, true))
	var h := UI.hbox(14)
	for w in D.get("wines", []):
		h.add_child(UI.tile(String(w["name"]), String(w["sheet"]["quality"]), "%s · %d bottles · €%.2f" % [w["category"], int(w["bottles"]), float(w["price"])]))
	p[1].add_child(h)
	var bh := UI.hbox(10)
	var rb := UI.button("Open the Vintage report", true, 16); rb.pressed.connect(func(): shell.show_screen("report"))
	var b := UI.button("Open the Tasting sheets", false, 16); b.pressed.connect(func(): shell.show_screen("wines"))
	bh.add_child(rb); bh.add_child(b)
	p[1].add_child(bh)
	p[1].add_child(UI.label("This MVP ends after one Vintage. Later Vintages, more Plots and a continuing Timeline are on the backlog.", 14, UI.MUTED))
	return p[0]
