# Pre-game flow: title → Region → Plot comparison → Planting per Block → start. Reads the setup catalog only.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const Charts := preload("res://src/ui/charts.gd")

static func build(_D: Dictionary, shell, step: String) -> Control:
	match step:
		"region": return _region(shell)
		"plots": return _plots(shell)
		"planting": return _planting(shell)
	return _title(shell)

static func _center(child: Control, w := 1100.0) -> Control:
	var c := CenterContainer.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child.custom_minimum_size.x = w
	c.add_child(child)
	return c

static func _steps(active: int) -> HBoxContainer:
	var h := UI.hbox(8)
	var names := ["Region", "Plot", "Planting"]
	for i in names.size():
		var col := UI.GOLD if i == active else (UI.INK2 if i < active else UI.MUTED)
		h.add_child(UI.label("%d  %s" % [i + 1, names[i]], 15, col, UI.f_body_b if i == active else null))
		if i < names.size() - 1: h.add_child(UI.label("›", 15, UI.MUTED))
	return h

static func _cat(shell) -> Dictionary: return shell.CAT

static func _region_data(shell, id: String) -> Dictionary:
	for r in _cat(shell)["regions"]:
		if r["id"] == id: return r
	return {}

static func _plot_data(shell, id: String) -> Dictionary:
	for r in _cat(shell)["regions"]:
		for p in r["plots"]:
			if p["id"] == id: return p
	return {}

# ------------------------------------------------------------------ title
static func _title(shell) -> Control:
	var v := UI.vbox(22)
	var t := UI.head("TERROIR ENGINE", 84, UI.INK); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var s := UI.label("Found a vineyard on bare land, farm it through the seasons, and make a wine that tells you why it tastes the way it does.", 20, UI.INK2, null, true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(s)
	v.add_child(UI.spacer(false, 18))
	var saves: Array = JSON.parse_string(Sim.ListSaves())
	var col := UI.vbox(12)
	var nb := UI.button("New estate", true, 20); nb.custom_minimum_size = Vector2(360, 56)
	nb.pressed.connect(func(): shell.setup = {}; shell.show_screen("region"))
	col.add_child(nb)
	for sv in saves.slice(0, 5):
		var b := UI.button("Load %s   ·   %s" % [sv["name"], sv["modified"]], false, 16); b.custom_minimum_size = Vector2(360, 46)
		var name: String = sv["name"]
		b.pressed.connect(func():
			if Sim.LoadGame(name): shell.state.clear(); shell.current = ""; shell.refresh(); shell.notify("Loaded " + name + ".")
			else: shell.notify("Could not load: " + String(Sim.LastError()).left(160)))
		col.add_child(b)
	var cc := CenterContainer.new(); cc.add_child(col); v.add_child(cc)
	v.add_child(UI.spacer(false, 30))
	var foot := UI.label("MVP build · one Plot, one Vintage, three Regions with Historical weather 1990–2025 · Science notes in docs/science/", 14, UI.MUTED)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(foot)
	return _center(v, 1000)

# ------------------------------------------------------------------ region
static func _region(shell) -> Control:
	var v := UI.vbox(18)
	var back := UI.button("‹ Back"); back.pressed.connect(func(): shell.show_screen("title"))
	v.add_child(UI.page_header("Choose a Region", "Each Region has its own climate, soils, hazards and wine law. You can't move later.", [_steps(0), back]))
	var row := UI.hbox(18); row.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(row)
	var cap: int = int(_cat(shell)["startingCapital"])
	for r in _cat(shell)["regions"]:
		var c := UI.card(shell.setup.get("region", "") == r["id"], 22)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := UI.vbox(12); c.add_child(cv)
		cv.add_child(UI.head(r["name"], 34, UI.INK))
		cv.add_child(UI.label("%s · %s" % [r["country"], r["appellation"]], 15, UI.GOLD))
		cv.add_child(UI.label(r["blurb"], 16, UI.INK2, null, true))
		cv.add_child(UI.divider())
		var lo := 1e12; var hi := 0.0
		for p in r["plots"]:
			lo = minf(lo, float(p["price"])); hi = maxf(hi, float(p["price"]))
		cv.add_child(UI.kv("Plots for sale", str(r["plots"].size())))
		cv.add_child(UI.kv("Land prices", "%s – %s" % [UI.euro(int(lo)), UI.euro(int(hi))]))
		var hmin := 9999; var hmax := 0
		for p in r["plots"]:
			hmin = mini(hmin, int(p["huglin"])); hmax = maxi(hmax, int(p["huglin"]))
		cv.add_child(UI.kv("Huglin heat index", "%d – %d" % [hmin, hmax], "Sum of daytime heat over the growing season. ≈1500 is Riesling's minimum, ≈1900 Cabernet Sauvignon's."))
		for p in r["plots"]:
			var h := UI.hbox(8)
			h.add_child(UI.label("·  " + String(p["name"]), 15, UI.INK))
			h.add_child(UI.spacer())
			h.add_child(UI.num(UI.euro(int(p["price"])), 16, UI.INK if float(p["price"]) < cap * 0.8 else UI.SERIOUS))
			cv.add_child(h)
		# a spinning model of the Region's signature Plot fills the card
		var sig: Dictionary = r["plots"][0]
		for p in r["plots"]:
			if int(p["ratings"]["Prestige"]) > int(sig["ratings"]["Prestige"]) and int(p["price"]) <= cap: sig = p
		var dwrap := PanelContainer.new(); dwrap.add_theme_stylebox_override("panel", UI.sb(Color("1a2127"), 6, UI.LINE, 1, 0))
		dwrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var dio = load("res://src/ui/diorama.gd").new()
		dio.custom_minimum_size = Vector2(0, 300)
		dio.set_plot(sig)
		dwrap.add_child(dio)
		var cap_l := UI.label("  Signature Plot: " + String(sig["name"]) + " · drag to turn", 13, UI.INK2); cap_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap_l.vertical_alignment = VERTICAL_ALIGNMENT_TOP; cap_l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		dwrap.add_child(cap_l)
		cv.add_child(dwrap)
		var b := UI.button("Look at plots in %s ›" % r["name"], true, 17); b.custom_minimum_size = Vector2(0, 48)
		var rid: String = r["id"]
		b.pressed.connect(func(): shell.setup["region"] = rid; shell.setup.erase("plot"); shell.show_screen("plots"))
		cv.add_child(b)
		UI.on_click(c, func(): shell.setup["region"] = rid; shell.setup.erase("plot"); shell.show_screen("plots"))
		row.add_child(c)
	v.add_child(UI.label("Starting capital: %s. Land, planting and three years of running costs come out of it before the first Vintage." % UI.euro(cap), 15, UI.INK2))
	return v

# ------------------------------------------------------------------ plots
static func _cost_to_first_vintage(p: Dictionary) -> int:
	return int(p["price"]) + int(p["plantingCost"]) + int(p["runningCostYear"]) * 3

const RATING_AXES := ["Heat", "Frost safety", "Water reserve", "Drainage", "Workability", "Prestige", "Value"]
const RATING_TIPS := {"Heat": "Huglin heat index with each Block's microclimate, 2001–2020 average.", "Frost safety": "Spring frost nights around budburst and cold-air pockets.",
	"Water reserve": "Plant-available water the roots can reach (mm).", "Drainage": "Stones and sand: dries out fast after rain.",
	"Workability": "Slope. Steep sites need hand work (expensive).", "Prestige": "Classification and reputation — sets the price per bottle.",
	"Value": "How cheap the land is per hectare."}

static func _plots(shell) -> Control:
	var R := _region_data(shell, shell.setup.get("region", "mosel"))
	var plots: Array = R["plots"]
	if not shell.setup.has("plot"): shell.setup["plot"] = plots[0]["id"]
	var P := _plot_data(shell, shell.setup["plot"])
	var cmp_id: String = shell.setup.get("compare", "")
	var C := _plot_data(shell, cmp_id) if cmp_id != "" and cmp_id != P["id"] else {}
	var cap: int = int(_cat(shell)["startingCapital"])
	var v := UI.vbox(14)
	var back := UI.button("‹ Regions"); back.pressed.connect(func(): shell.show_screen("region"))
	v.add_child(UI.page_header("%s: choose your land" % R["name"], "Click a Plot to inspect it. Drag the model to turn it, scroll to zoom. Ratings are 1–20 against all twelve Plots in the game.", [_steps(1), back]))
	var row := UI.hbox(16); row.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(row)
	# ---- left: Plot cards
	var left := UI.vbox(10); left.custom_minimum_size = Vector2(390, 0); row.add_child(left)
	for p in plots:
		left.add_child(_plot_card(shell, p, p["id"] == P["id"], p["id"] == cmp_id, cap))
	left.add_child(UI.label("Tip: \"Compare\" overlays a second Plot on the rating chart.", 13, UI.MUTED, null, true))
	# ---- centre: the diorama
	var mid := UI.vbox(10); mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(mid)
	var dp := PanelContainer.new(); dp.add_theme_stylebox_override("panel", UI.sb(Color("1a2127"), 8, UI.LINE, 1, 0))
	dp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dio = load("res://src/ui/diorama.gd").new()
	dio.custom_minimum_size = Vector2(0, 560)
	dio.set_plot(P)
	dp.add_child(dio)
	var over := MarginContainer.new(); over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]: over.add_theme_constant_override("margin_" + side, 16)
	var ov := UI.vbox(4); ov.mouse_filter = Control.MOUSE_FILTER_IGNORE; over.add_child(ov)
	var tl := UI.head(String(P["name"]), 30, UI.INK); tl.mouse_filter = Control.MOUSE_FILTER_IGNORE; ov.add_child(tl)
	var facts := UI.hbox(6); facts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for f in ["%.1f ha" % float(P["ha"]), "%d %% slope" % int(P["slope"]), "facing %s" % P["aspect"], "%d m" % int(P["elevation"]), String(P["tier"])]:
		facts.add_child(UI.chip(f, UI.INK2, 13))
	ov.add_child(facts)
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE; ov.add_child(spacer)
	var hint := UI.label("Drag to turn · scroll to zoom · edges show each Block's soil (depth ×8) · mist marks frost pockets", 13, UI.MUTED)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE; ov.add_child(hint)
	dp.add_child(over)
	mid.add_child(dp)
	var bl := HFlowContainer.new(); bl.add_theme_constant_override("h_separation", 10); bl.add_theme_constant_override("v_separation", 8)
	for b in P["blocks"]:
		var bc := PanelContainer.new(); bc.add_theme_stylebox_override("panel", UI.sb(UI.SURFACE, 6, UI.LINE, 1, 10))
		var bh := UI.hbox(8); bc.add_child(bh)
		bh.add_child(UI.block_tag(b["id"], 15))
		var bv := UI.vbox(0); bh.add_child(bv)
		bv.add_child(UI.label(String(b["name"]), 14, UI.INK, UI.f_body_b))
		bv.add_child(UI.label("%s · %d cm · %d mm water%s" % [b["texture"], int(b["depth"]), int(b["taw"]), " · frost pocket" if float(b["frostPocket"]) > 0.5 else ""], 12, UI.MUTED))
		bc.tooltip_text = String(b.get("notes", ""))
		bl.add_child(bc)
	mid.add_child(bl)
	# ---- right: budget, ratings, Mentor, buy
	var right := UI.vbox(12); right.custom_minimum_size = Vector2(470, 0); row.add_child(right)
	right.add_child(_budget_card(P, cap))
	var rp: Array = UI.panel("Ratings", "gold: %s%s" % [P["name"], ("  ·  blue: " + String(C["name"])) if not C.is_empty() else ""], 4)
	var radar = Charts.RadarChart.new()
	radar.axes = RATING_AXES
	var vals := []
	for a in RATING_AXES: vals.append(int(P["ratings"][a]))
	radar.series = [{"name": P["name"], "values": vals, "color": UI.GOLD}]
	if not C.is_empty():
		var cv := []
		for a in RATING_AXES: cv.append(int(C["ratings"][a]))
		radar.series.push_front({"name": C["name"], "values": cv, "color": UI.SEQ})
	radar.custom_minimum_size = Vector2(0, 280)
	rp[1].add_child(radar)
	var rg := GridContainer.new(); rg.columns = 4; rg.add_theme_constant_override("h_separation", 12)
	for a in RATING_AXES:
		var al := UI.label(a, 13, UI.INK2); al.tooltip_text = RATING_TIPS[a]; al.mouse_filter = Control.MOUSE_FILTER_PASS
		rg.add_child(al)
		var val := int(P["ratings"][a])
		rg.add_child(UI.head(str(val), 18, UI.rating_col(val)))
	rp[1].add_child(rg)
	right.add_child(rp[0])
	var mp: Array = UI.panel("The Mentor's view", "", 6)
	for m in (P["mentor"] as Array).slice(0, 3):
		var mh := UI.hbox(8)
		mh.add_child(UI.label("❝", 16, UI.GOLD))
		var ml := UI.label(m, 14, UI.INK, null, true); ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL; mh.add_child(ml)
		mp[1].add_child(mh)
	right.add_child(mp[0])
	var go := UI.button("Buy %s ›" % P["name"], true, 18); go.custom_minimum_size = Vector2(0, 52)
	go.pressed.connect(func(): shell.setup.erase("planting"); shell.show_screen("planting"))
	right.add_child(go)
	return UI.scroll(v)

static func _plot_card(shell, p: Dictionary, sel: bool, cmp: bool, cap: int) -> Control:
	var c := UI.card(sel, 14)
	if cmp and not sel: c.add_theme_stylebox_override("panel", UI.sb(UI.SURFACE, 6, UI.SEQ, 2, 14))
	var v := UI.vbox(6); c.add_child(v)
	var top := UI.hbox(8)
	top.add_child(UI.head(String(p["name"]), 22, UI.INK))
	top.add_child(UI.chip(String(p["tier"]), UI.GOLD if sel else UI.INK2, 12))
	top.add_child(UI.spacer())
	var total := _cost_to_first_vintage(p)
	var ok := total <= cap
	top.add_child(UI.chip("✓ affordable" if ok else "✕ over budget", UI.GOOD if ok else UI.CRIT, 12, true))
	v.add_child(top)
	var ph := UI.hbox(10)
	ph.add_child(UI.num(UI.euro(int(p["price"])), 26, UI.INK))
	var sub := UI.label("%.1f ha · %s/ha" % [float(p["ha"]), UI.euro(int(p["pricePerHa"]))], 13, UI.MUTED); sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(sub)
	v.add_child(ph)
	for a in ["Heat", "Frost safety", "Prestige"]:
		var h := UI.hbox(8)
		var l := UI.label(a, 13, UI.INK2); l.custom_minimum_size = Vector2(96, 0); h.add_child(l)
		var mt = Charts.Meter.new(); mt.value = float(p["ratings"][a]) / 20.0; mt.color = UI.rating_col(int(p["ratings"][a])); mt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(mt)
		h.add_child(UI.head(str(int(p["ratings"][a])), 16, UI.rating_col(int(p["ratings"][a]))))
		v.add_child(h)
	var pid: String = p["id"]
	var bh := UI.hbox(8)
	bh.add_child(UI.label(String(p["summary"]).left(70) + ("…" if String(p["summary"]).length() > 70 else ""), 12, UI.MUTED, null, true))
	bh.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not sel:
		var cb := UI.button("Compare" if not cmp else "✓ Comparing", false, 12)
		cb.pressed.connect(func(): shell.setup["compare"] = "" if cmp else pid; shell.show_screen("plots"))
		bh.add_child(cb)
	v.add_child(bh)
	UI.on_click(c, func(): shell.setup["plot"] = pid; shell.show_screen("plots"))
	return c

## What the first Vintage costs against the starting capital: land + planting + three years of running costs.
static func _budget_card(p: Dictionary, cap: int) -> Control:
	var bp: Array = UI.panel("Your budget", "starting capital " + UI.euro(cap), 8)
	var land := float(p["price"]); var plant := float(p["plantingCost"]); var run := float(p["runningCostYear"]) * 3.0
	var total := land + plant + run
	var scale := maxf(total, float(cap)) * 1.05
	var bar := Control.new(); bar.custom_minimum_size = Vector2(0, 34)
	var parts := [[land, Color("c98500"), "Land"], [plant, Color("199e70"), "Planting"], [run, Color("3987e5"), "3 years running"]]
	bar.draw.connect(func():
		var w := bar.size.x; var x := 0.0
		bar.draw_style_box(UI.sb(UI.SUNKEN, 4, Color(0, 0, 0, 0), 0, 0), Rect2(0, 6, w, 22))
		for pt in parts:
			var pw := w * float(pt[0]) / scale
			bar.draw_rect(Rect2(x, 6, pw, 22), pt[1]); x += pw
		var cx := w * cap / scale
		bar.draw_line(Vector2(cx, 0), Vector2(cx, 34), UI.INK, 2.0)
		bar.draw_string(UI.f_body, Vector2(minf(cx + 4, w - 120), 12), "your capital", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.INK))
	bp[1].add_child(bar)
	var g := GridContainer.new(); g.columns = 3; g.add_theme_constant_override("h_separation", 14)
	for pt in parts:
		var sw := ColorRect.new(); sw.color = pt[1]; sw.custom_minimum_size = Vector2(12, 12); sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		g.add_child(sw); g.add_child(UI.label(pt[2], 14, UI.INK2)); g.add_child(UI.num(UI.euro(int(pt[0])), 16))
	bp[1].add_child(g)
	var left := cap - int(total)
	bp[1].add_child(UI.label(("Leaves %s for staff, the cellar and bottling before the first sale." % UI.euro(left)) if left >= 0 else ("%s short: you would go into debt (no loans in this version)." % UI.euro(-left)), 14, UI.GOOD if left >= 0 else UI.CRIT, UI.f_body_b, true))
	return bp[0]

# ------------------------------------------------------------------ planting
static func _planting(shell) -> Control:
	var P := _plot_data(shell, shell.setup.get("plot", "mosel-blauschiefer"))
	var R := _region_data(shell, shell.setup.get("region", "mosel"))
	var S: Dictionary = shell.setup
	if not S.has("planting") or S.get("planting_plot", "") != P["id"]:
		S["planting"] = {}
		S["planting_plot"] = P["id"]
		for b in P["blocks"]: S["planting"][b["id"]] = (b["default"] as Dictionary).duplicate()
	if not S.has("year"): S["year"] = 2015
	if not S.has("vineyardManager"): S["vineyardManager"] = "Junior"
	if not S.has("cellarMaster"): S["cellarMaster"] = "Junior"
	if not S.has("estateName"): S["estateName"] = {"mosel": "Weingut Schieferhang", "cote-dor": "Domaine des Pierres", "napa": "Stonefield Cellars"}.get(R["id"], "My Estate")
	var v := UI.vbox(16)
	var back := UI.button("‹ Plots"); back.pressed.connect(func(): shell.show_screen("plots"))
	v.add_child(UI.page_header("Planting %s" % P["name"], "What goes into the ground now stays for decades. The Mentor's defaults are sensible; change anything.", [_steps(2), back]))
	var tp: Array = UI.panel("Blocks", "Any Variety may be planted anywhere — a poor match shows up in the wine, never as a blocked choice.")
	var cat := _cat(shell)
	var var_items := []
	for x in cat["varieties"]: var_items.append([x["id"], "%s (%s)" % [x["name"], "red" if x["red"] else "white"]])
	var rs_items := []
	for x in cat["rootstocks"]: rs_items.append([x["id"], x["name"]])
	var rs_notes := {}
	for x in cat["rootstocks"]: rs_notes[x["id"]] = x["note"]
	var var_notes := {}
	for x in cat["varieties"]: var_notes[x["id"]] = x["note"]
	var dens := [["3000", "3 000 vines/ha"], ["3800", "3 800 vines/ha"], ["5000", "5 000 vines/ha"], ["6500", "6 500 vines/ha"], ["8000", "8 000 vines/ha"], ["10000", "10 000 vines/ha"], ["12000", "12 000 vines/ha"]]
	for b in P["blocks"]:
		var bid: String = b["id"]
		var pc: Dictionary = S["planting"][bid]
		var row := UI.hbox(12)
		row.add_child(UI.block_tag(bid, 18))
		var info := UI.vbox(0); info.custom_minimum_size = Vector2(380, 0)
		info.add_child(UI.label(b["name"], 16, UI.INK, UI.f_body_b))
		info.add_child(UI.label("%s, %d cm deep, %d mm water, lime %d %%, pH %.1f · %s-facing, %d %% slope%s" % [b["texture"], int(b["depth"]), int(b["taw"]), int(b["lime"]), float(b["ph"]), b["aspect"], int(b["slope"]),
			" · frost pocket" if float(b["frostPocket"]) > 0.5 else ""], 13, UI.MUTED, null, true))
		row.add_child(info)
		var ov := UI.option(var_items, pc["variety"], func(x): pc["variety"] = x; shell.show_screen("planting"), 220)
		ov.tooltip_text = var_notes.get(pc["variety"], ""); row.add_child(ov)
		var orr := UI.option(rs_items, pc["rootstock"], func(x): pc["rootstock"] = x; shell.show_screen("planting"), 170)
		orr.tooltip_text = rs_notes.get(pc["rootstock"], ""); row.add_child(orr)
		var tr_items := []
		for t in P["training"]: tr_items.append(t)
		row.add_child(UI.option(tr_items, pc["training"], func(x): pc["training"] = x, 150))
		var steep_plot: bool = float(P["slope"]) >= 30
		var rows_items := [["DownSlope", "Rows downhill"]] if steep_plot else [["NorthSouth", "Rows N–S"], ["EastWest", "Rows E–W"]]
		if steep_plot: pc["rows"] = "DownSlope"
		var ro := UI.option(rows_items, String(pc.get("rows", "NorthSouth")), func(x): pc["rows"] = x, 150)
		ro.tooltip_text = "On steep slopes rows must run straight downhill (winch and safety). On flat land N–S rows light both sides of the canopy evenly; E–W rows shade the north side."
		row.add_child(ro)
		var d_items := dens.duplicate()
		var has := false
		for d in d_items:
			if d[0] == str(int(pc["density"])): has = true
		if not has: d_items.append([str(pc["density"]), "%d vines/ha" % int(pc["density"])])
		row.add_child(UI.option(d_items, str(int(pc["density"])), func(x): pc["density"] = int(x), 170))
		var note := UI.label(rs_notes.get(pc["rootstock"], ""), 13, UI.MUTED, null, true); note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if float(b["lime"]) >= 12 and pc["rootstock"] != "Fercal":
			note.text = "⚠ %d %% active lime: this rootstock risks lime-induced chlorosis." % int(b["lime"]); note.add_theme_color_override("font_color", UI.SERIOUS)
		row.add_child(note)
		tp[1].add_child(row)
		tp[1].add_child(UI.divider())
	v.add_child(tp[0])
	var bottom := UI.hbox(16); v.add_child(bottom)
	var a: Array = UI.panel("Timeline", "")
	a[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var yrs := []
	for y in range(int(cat["plantingYears"][0]), int(cat["plantingYears"][1]) + 1): yrs.append([str(y), str(y)])
	var yh := UI.hbox(12); yh.add_child(UI.label("Planting year", 15, UI.INK2))
	yh.add_child(UI.option(yrs, str(S["year"]), func(x): S["year"] = int(x); shell.show_screen("planting"), 120)); a[1].add_child(yh)
	var fv := int(S["year"]) + 3
	a[1].add_child(UI.label("Establishment runs %d–%d (the Mentor manages it). Your first Vintage is %d, played with the %s weather that really happened in %s." %
		[int(S["year"]), fv - 1, fv, "Historical" if fv <= 2025 else "synthetic", R["name"]], 15, UI.INK2, null, true))
	bottom.add_child(a[0])
	var s: Array = UI.panel("Staff", "part-time on an estate this size · cost per year")
	s[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var desc := {"Junior": "never wrong, never insightful", "Experienced": "longer forecasts, better timing", "Senior": "reads the vintage, suggests clever moves"}
	for role in [["vineyardManager", "Vineyard manager"], ["cellarMaster", "Cellar master"]]:
		var h := UI.hbox(12)
		var l := UI.label(role[1], 15, UI.INK2); l.custom_minimum_size = Vector2(150, 0); h.add_child(l)
		var key: String = role[0]
		h.add_child(UI.segmented(cat["staffLevels"], S[key], func(x): S[key] = x; shell.show_screen("planting"), 120))
		var role_key: String = "vineyard" if key == "vineyardManager" else "cellar"
		h.add_child(UI.label("%s · %s" % [UI.euro(int(P["salaries"][S[key]][role_key])), desc[S[key]]], 13, UI.MUTED))
		s[1].add_child(h)
	bottom.add_child(s[0])
	var e: Array = UI.panel("Estate", "")
	e[0].custom_minimum_size = Vector2(460, 0)
	e[1].add_child(UI.line_edit(S["estateName"], func(t): S["estateName"] = t, 400))
	var go := UI.button("Plant and start ›", true, 18); go.custom_minimum_size = Vector2(0, 50)
	go.pressed.connect(func(): shell.start_game(setup_json(shell)))
	e[1].add_child(go)
	bottom.add_child(e[0])
	return UI.scroll(v)

## The NewGame payload from the choices on the Planting screen (also used by capture mode).
static func setup_json(shell) -> Dictionary:
	var S: Dictionary = shell.setup
	var planting := {}
	for bid in S["planting"]:
		var pc: Dictionary = S["planting"][bid]
		planting[bid] = {"variety": pc["variety"], "rootstock": pc["rootstock"], "training": pc["training"], "density": int(pc["density"]), "rows": String(pc.get("rows", "NorthSouth"))}
	return {"plotId": S["plot"], "plantingYear": int(S["year"]), "estateName": S["estateName"], "vineyardManager": S["vineyardManager"], "cellarMaster": S["cellarMaster"], "planting": planting, "seed": 7}
