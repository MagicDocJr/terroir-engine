# Ripeness: weekly lab samples per Block against style targets, and the harvest planner.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const Metrics := preload("res://src/ui/metrics.gd")
const Charts := preload("res://src/ui/charts.gd")

static func build(D: Dictionary, shell) -> Control:
	var blocks: Array = D["blocks"]
	var napa: bool = D["region"]["units"] == "brix"
	var unit := "°Brix" if napa else "°Oe"
	var v := UI.vbox(16)
	var ids := []
	for b in blocks: ids.append(b["id"])
	var sel_id: String = shell.state.get("rip_sel", ids[0])
	var B: Dictionary = blocks[0]
	for b in blocks:
		if b["id"] == sel_id: B = b
	v.add_child(UI.page_header("Ripeness", "The lab samples each Block weekly from véraison. Sugar in %s. The shaded bands show how ripe the grapes must be for each wine style; the higher the band, the riper the wine." % unit,
		[UI.segmented(ids, B["id"], func(x): shell.state["rip_sel"] = x; shell.show_screen("ripeness"), 52)]))
	# planner
	var pp: Array = UI.panel("Harvest planner", "")
	(pp[1].get_child(0) as HBoxContainer).add_child(load("res://src/ui/learn_drawer.gd").link(shell, "harvest-date", {"block": String(shell.state.get("rip_sel", ""))}))
	var cols := ["Block", "Variety", "Stage", "Sugar", "Pot. alc.", "TA g/L", "pH", "Malic", "Seeds ripe", "Rot (grey · noble)", "Ripe enough for", ""]
	var widths := [70, 190, 130, 100, 100, 80, 70, 80, 110, 160, 190, 190]
	var hdr := UI.hbox(2)
	var ripe_tip := ("The best wine style today's sugar already qualifies for. In the Mosel these are the legal minimum must weights: Kabinett 73 °Oe, Spätlese 80, Auslese 88, Beerenauslese 110 (which also needs noble rot)." if not napa and D["region"]["id"] == "mosel"
		else "The typical picking target today's sugar has reached. Sugar keeps rising as you wait, but acidity falls and rot risk grows.")
	var col_tips := {"Ripe enough for": ripe_tip, "Sugar": Metrics.tip("brix" if napa else "oe"), "Pot. alc.": Metrics.tip("pa"), "TA g/L": Metrics.tip("ta"), "pH": Metrics.tip("ph"), "Malic": Metrics.tip("malic"),
		"Seeds ripe": Metrics.tip("seeds"), "Rot (grey · noble)": Metrics.tip("grey") + "\n\n" + Metrics.tip("noble")}
	for i in cols.size(): hdr.add_child(UI.table_cell(cols[i] + (" ⓘ" if col_tips.has(cols[i]) else ""), widths[i], UI.MUTED, Color(0, 0, 0, 0), col_tips.get(cols[i], ""), UI.f_body_b, 14, 32))
	pp[1].add_child(hdr)
	for b in blocks:
		var row := UI.hbox(2)
		var tagc := PanelContainer.new(); tagc.custom_minimum_size = Vector2(widths[0], 42); tagc.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 8)); tagc.add_child(UI.block_tag(b["id"], 15)); row.add_child(tagc)
		row.add_child(UI.table_cell(String(b["variety"]), widths[1], UI.INK, Color(0, 0, 0, 0), "", UI.f_body, 15, 42))
		var st := String(b["stage"])
		if b["picking"]: st = "Picking %d %%" % int(b["pickedPct"])
		row.add_child(UI.table_cell(st, widths[2], UI.INK2, Color(0, 0, 0, 0), "", UI.f_body, 15, 42))
		var m = b.get("must")
		if m != null and not b["harvested"]:
			row.add_child(UI.table_cell(("%.1f" % float(m["brix"])) if napa else ("%d" % int(m["oe"])), widths[3], UI.GOLD if b.get("inWindow", false) else UI.INK))
			row.add_child(UI.table_cell("%.1f %%" % float(m["pa"]), widths[4]))
			row.add_child(UI.table_cell("%.1f" % float(m["ta"]), widths[5]))
			row.add_child(UI.table_cell("%.2f" % float(m["ph"]), widths[6]))
			row.add_child(UI.table_cell("%.1f" % float(m["malic"]), widths[7]))
			row.add_child(UI.table_cell("%d %%" % int(m["seeds"]), widths[8], UI.INK, Color(0, 0, 0, 0), "Seed browning: green seeds give harsh, bitter tannin in reds."))
			row.add_child(UI.table_cell("%.1f %% · %.1f %%" % [float(b["greyRot"]), float(b["nobleRot"])], widths[9], UI.CRIT if float(b["greyRot"]) > 5 else UI.INK2))
			var tg := []
			for t in b["targets"]:
				if float(m["oe"]) >= float(t["oe"]): tg.append(t["style"])
			var reach: String = tg[-1] if tg.size() > 0 else "below targets"
			if ("Beerenauslese" in reach or "Trockenbeerenauslese" in reach) and float(b["nobleRot"]) < 30: reach = "Auslese (BA needs noble rot)"
			row.add_child(UI.table_cell(reach, widths[10], UI.INK2, Color(0, 0, 0, 0), ripe_tip, UI.f_body, 14, 42))
			var hb := UI.button("Harvest…", b.get("inWindow", false), 15); hb.custom_minimum_size = Vector2(widths[11] - 20, 36); hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var bid: String = b["id"]
			hb.disabled = b["picking"]
			hb.pressed.connect(func(): shell.state["plot_sel"] = bid; shell.show_screen("plot"))
			row.add_child(hb)
		else:
			var txt := "Picked %s → Lot %s" % [b["harvestDate"], b["lotId"]] if b["harvested"] else "sampling starts at véraison"
			row.add_child(UI.table_cell(txt, 700, UI.MUTED, Color(0, 0, 0, 0), "", UI.f_body, 15, 42))
		pp[1].add_child(row)
	v.add_child(pp[0])
	# charts for the selected Block
	var S: Array = B.get("samples", [])
	var row2 := UI.hbox(16); v.add_child(row2)
	var sp: Array = UI.panel("Block %s sugar" % B["id"], "%s · %s" % [B["variety"], unit])
	sp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tp: Array = UI.panel("Block %s acidity" % B["id"], "g/L")
	tp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if S.size() >= 1:
		var labels := []; var sug := []; var ta := []; var mal := []
		for s in S:
			labels.append(s["date"]); sug.append(float(s["brix"]) if napa else float(s["oe"])); ta.append(s["ta"]); mal.append(s["malic"])
		if S.size() == 1:
			labels.append("");
		var sc = Charts.LineChart.new()
		sc.labels = labels; sc.series = [{"name": B["variety"], "short": "Block " + String(B["id"]), "values": sug, "color": UI.BLOCK.get(B["id"], UI.GOLD)}]
		var bands := []
		var tmin := 1e9; var tmax := 0.0
		for i in B["targets"].size():
			var t: Dictionary = B["targets"][i]
			var key := "brix" if napa else "oe"
			var lo := float(t[key])
			var hi: float = float(B["targets"][i + 1][key]) if i + 1 < B["targets"].size() else lo + (3.0 if napa else 12.0)
			bands.append({"lo": lo, "hi": hi, "label": t["style"]})
			tmin = minf(tmin, lo); tmax = maxf(tmax, hi)
		for x in sug: tmin = minf(tmin, float(x)); tmax = maxf(tmax, float(x))
		sc.bands = bands
		var st := 2.0 if napa else 10.0
		sc.y_min = floorf((tmin - st) / st) * st; sc.y_max = ceilf((tmax + st * 0.5) / st) * st; sc.y_step = st
		sc.y_fmt = "%d"; sc.unit = " " + unit; sc.custom_minimum_size = Vector2(0, 300); sc.label_every = maxi(1, labels.size() / 6)
		sp[1].add_child(sc)
		var tc = Charts.LineChart.new()
		tc.labels = labels; tc.series = [{"name": "Titratable acidity", "short": "TA", "values": ta, "color": UI.BLOCK["A"]}, {"name": "Malic acid", "short": "Malic", "values": mal, "color": UI.BLOCK["C"]}]
		var amax := 6.0
		for x in ta: amax = maxf(amax, float(x))
		tc.y_min = 0; tc.y_max = ceilf(amax / 2.0) * 2.0 + 2.0; tc.y_step = 2; tc.y_fmt = "%d"; tc.unit = " g/L"; tc.custom_minimum_size = Vector2(0, 300); tc.label_every = maxi(1, labels.size() / 6)
		tp[1].add_child(tc)
		var last: Dictionary = S[-1]
		var line := "Latest (%s): berry %.2f g, seeds %d %% ripe" % [last["date"], float(last["berry"]), int(last["seeds"])]
		if B["red"]: line += ", colour %.2f mg/g" % float(last["anth"])
		if float(last["ibmp"]) > 0: line += ", pyrazine (IBMP) %.1f ng/L" % float(last["ibmp"])
		line += ", grey rot %.1f %%, noble rot %.1f %%" % [float(last["grey"]), float(last["noble"])]
		sp[1].add_child(UI.label(line, 14, UI.INK2, null, true))
	else:
		sp[1].add_child(UI.label("No samples yet — the lab starts after véraison.", 15, UI.MUTED))
		tp[1].add_child(UI.label("—", 15, UI.MUTED))
	row2.add_child(sp[0]); row2.add_child(tp[0])
	v.add_child(UI.label("Style bands follow the region's must-weight minimums (German Prädikat in the Mosel, typical picking targets elsewhere). See docs/science/ripening.md and law.md.", 13, UI.MUTED, null, true))
	return UI.scroll(v)
