# Pre-game flow: title → Region → Plot comparison → Planting per Block → start. Reads the setup catalog only.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")

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
		cv.add_child(UI.spacer(false))
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

static func _plots(shell) -> Control:
	var R := _region_data(shell, shell.setup.get("region", "mosel"))
	var plots: Array = R["plots"]
	if not shell.setup.has("plot"): shell.setup["plot"] = plots[0]["id"]
	var P := _plot_data(shell, shell.setup["plot"])
	var cap: int = int(_cat(shell)["startingCapital"])
	var v := UI.vbox(16)
	var back := UI.button("‹ Regions"); back.pressed.connect(func(): shell.show_screen("region"))
	v.add_child(UI.page_header("%s: compare Plots" % R["name"], "Ratings are 1–20 against all twelve Plots in the game. Hover a rating for what it means.", [_steps(1), back]))
	# comparison table
	var tp: Array = UI.panel("", "", 4)
	var hdr := UI.hbox(2)
	var cols := ["Plot", "Heat", "Frost safety", "Water reserve", "Drainage", "Workability", "Prestige", "Value", "Area", "Price", "To first vintage"]
	var widths := [300, 92, 112, 122, 100, 112, 96, 84, 80, 140, 170]
	var tips := {"Heat": "Huglin heat index with each Block's microclimate, 2001–2020 average.", "Frost safety": "Spring frost nights around budburst and cold-air pockets.",
		"Water reserve": "Plant-available water the roots can reach (mm).", "Drainage": "Stones and sand: dries out fast after rain.",
		"Workability": "Slope. Steep sites need hand work (expensive).", "Prestige": "Classification and reputation — sets the price per bottle.",
		"Value": "How cheap the land is per hectare.", "To first vintage": "Land + planting + 3 years of running costs, before the first sale."}
	for i in cols.size():
		var c := UI.table_cell(cols[i], widths[i], UI.MUTED, Color(0, 0, 0, 0), tips.get(cols[i], ""), UI.f_body_b, 14, 32)
		hdr.add_child(c)
	tp[1].add_child(hdr)
	for p in plots:
		var sel: bool = p["id"] == P["id"]
		var row := UI.hbox(2)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var bg := Color(UI.GOLD, 0.12) if sel else Color(0, 0, 0, 0)
		row.add_child(UI.table_cell("%s  ·  %s" % [p["name"], p["tier"]], widths[0], UI.INK, bg, p["summary"], UI.f_body_b if sel else UI.f_body, 16, 44))
		var k := 1
		for rname in ["Heat", "Frost safety", "Water reserve", "Drainage", "Workability", "Prestige", "Value"]:
			var val := int(p["ratings"][rname])
			var cell := UI.table_cell(str(val), widths[k], UI.rating_col(val), bg, tips.get(rname, ""), UI.f_head, 20, 44)
			(cell.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(cell); k += 1
		row.add_child(UI.table_cell("%.1f ha" % float(p["ha"]), widths[8], UI.INK2, bg, "", null, 16, 44))
		row.add_child(UI.table_cell(UI.euro(int(p["price"])), widths[9], UI.INK, bg, "", null, 16, 44))
		var total := _cost_to_first_vintage(p)
		row.add_child(UI.table_cell(UI.euro(total) + ("" if total <= cap else "  ✕"), widths[10], UI.INK if total <= cap else UI.CRIT, bg,
			"Affordable with your %s." % UI.euro(cap) if total <= cap else "More than your starting capital: you would run out of cash.", null, 16, 44))
		var pid: String = p["id"]
		UI.on_click(row, func(): shell.setup["plot"] = pid; shell.show_screen("plots"))
		for c in row.get_children(): c.mouse_filter = Control.MOUSE_FILTER_PASS
		tp[1].add_child(row)
	v.add_child(tp[0])
	# detail of selected plot
	var det := UI.hbox(16); det.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(det)
	var left: Array = UI.panel(P["name"], P["classification"])
	left[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left[1].add_child(UI.label(P["summary"], 16, UI.INK2, null, true))
	var g := GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 30); g.add_theme_constant_override("v_separation", 4)
	for pair in [["Area", "%.1f ha in %d Blocks" % [float(P["ha"]), P["blocks"].size()]], ["Slope · aspect", "%d %% · %s" % [int(P["slope"]), P["aspect"]]],
			["Elevation", "%d m" % int(P["elevation"])], ["Mechanisation", String(P["mechanisation"])],
			["Winkler (GDD >10 °C)", "%d" % int(P["winkler"])], ["Huglin index", "%d" % int(P["huglin"])],
			["Spring frost nights", "%.1f per year" % float(P["springFrostNights"])], ["Labour", "%d h/ha/year" % int(P["labourHoursHa"])],
			["Land price", UI.euro(int(P["price"]))], ["Planting cost", UI.euro(int(P["plantingCost"]))],
			["Running cost", UI.euro(int(P["runningCostYear"])) + " / year"], ["Training allowed", ", ".join(P["training"])]]:
		g.add_child(UI.label(pair[0], 15, UI.INK2)); g.add_child(UI.num(pair[1], 17))
	left[1].add_child(g)
	left[1].add_child(UI.head("Blocks", 18))
	for b in P["blocks"]:
		var h := UI.hbox(10)
		h.add_child(UI.block_tag(b["id"], 15))
		var bl := UI.label("%s — %s, %d %% stones, %d cm deep, %d mm water, lime %d %%, %s-facing %d %%%s" % [b["name"], b["texture"], int(b["stones"]), int(b["depth"]), int(b["taw"]), int(b["lime"]), b["aspect"], int(b["slope"]),
			", frost pocket" if float(b["frostPocket"]) > 0.5 else ""], 14, UI.INK2, null, true)
		bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(bl)
		left[1].add_child(h)
	det.add_child(left[0])
	var right: Array = UI.panel("The Mentor's view", "")
	right[0].custom_minimum_size = Vector2(620, 0)
	for m in P["mentor"]:
		var h := UI.hbox(10)
		h.add_child(UI.label("❝", 20, UI.GOLD))
		var l := UI.label(m, 16, UI.INK, null, true); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
		right[1].add_child(h)
	right[1].add_child(UI.spacer(false))
	var total := _cost_to_first_vintage(P)
	if total > cap:
		right[1].add_child(UI.label("This Plot costs more than your starting capital before the first Vintage is sold. You can buy it, but you will go into debt.", 15, UI.SERIOUS, null, true))
	var go := UI.button("Buy %s and plan the Planting ›" % P["name"], true, 17); go.custom_minimum_size = Vector2(0, 50)
	go.pressed.connect(func(): shell.setup.erase("planting"); shell.show_screen("planting"))
	right[1].add_child(go)
	det.add_child(right[0])
	return UI.scroll(v)

# ------------------------------------------------------------------ planting
static func _planting(shell) -> Control:
	var P := _plot_data(shell, shell.setup.get("plot", "mosel-blauschiefer"))
	var R := _region_data(shell, shell.setup.get("region", "mosel"))
	var S: Dictionary = shell.setup
	if not S.has("planting"):
		S["planting"] = {}
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
		var info := UI.vbox(0); info.custom_minimum_size = Vector2(430, 0)
		info.add_child(UI.label(b["name"], 16, UI.INK, UI.f_body_b))
		info.add_child(UI.label("%s, %d cm deep, %d mm water, lime %d %%, pH %.1f · %s-facing, %d %% slope%s" % [b["texture"], int(b["depth"]), int(b["taw"]), int(b["lime"]), float(b["ph"]), b["aspect"], int(b["slope"]),
			" · frost pocket" if float(b["frostPocket"]) > 0.5 else ""], 13, UI.MUTED, null, true))
		row.add_child(info)
		var ov := UI.option(var_items, pc["variety"], func(x): pc["variety"] = x; shell.show_screen("planting"), 240)
		ov.tooltip_text = var_notes.get(pc["variety"], ""); row.add_child(ov)
		var orr := UI.option(rs_items, pc["rootstock"], func(x): pc["rootstock"] = x; shell.show_screen("planting"), 190)
		orr.tooltip_text = rs_notes.get(pc["rootstock"], ""); row.add_child(orr)
		var tr_items := []
		for t in P["training"]: tr_items.append(t)
		row.add_child(UI.option(tr_items, pc["training"], func(x): pc["training"] = x, 150))
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
		planting[bid] = {"variety": pc["variety"], "rootstock": pc["rootstock"], "training": pc["training"], "density": int(pc["density"])}
	return {"plotId": S["plot"], "plantingYear": int(S["year"]), "estateName": S["estateName"], "vineyardManager": S["vineyardManager"], "cellarMaster": S["cellarMaster"], "planting": planting, "seed": 7}
