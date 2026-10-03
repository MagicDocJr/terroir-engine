# Famous vintages (docs/superpowers/specs/2026-10-03-famous-vintages-design.md): the list on the title screen, the briefing,
# and inside a scenario game its goals and, once a Wine of the vintage is in bottle, the debrief. The sim judges every medal
# and writes every line; this screen only lays out the bridge JSON (ADR 0001).
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const T := preload("res://src/ui/tasting_ui.gd")
const MEDALS := ["bronze", "silver", "gold"]

static func build(_D: Dictionary, shell, mode := "") -> Control:
	match mode:
		"list": return UI.scroll(_list(shell))
		"brief": return UI.scroll(_brief(shell))
		_: return UI.scroll(_status(shell))

static func _list_json() -> Array:
	var parsed = JSON.parse_string(Sim.ScenarioList())
	return parsed if parsed is Array else []

# ------------------------------------------------------------------ title screen: the list
static func _list(shell) -> Control:
	var v := UI.vbox(18)
	var top := UI.hbox(12); v.add_child(top)
	var hv := UI.vbox(4); hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(hv)
	hv.add_child(UI.head("Famous vintages", 40, UI.INK))
	hv.add_child(UI.label("Replay a real year on an established Estate, on the weather that really happened. Three goals for each year, judged when your Wine is in bottle; then see what really happened and what growers did.", 16, UI.INK2, null, true))
	var back := UI.button("‹ Title", false, 15); back.pressed.connect(func(): shell.show_screen("title")); top.add_child(back)
	var row := HFlowContainer.new(); row.add_theme_constant_override("h_separation", 16); row.add_theme_constant_override("v_separation", 16)
	v.add_child(row)
	for item in _list_json():
		var S: Dictionary = item["scenario"]
		var card: Array = UI.panel(String(S["title"]), "")
		card[0].custom_minimum_size = Vector2(440, 0)
		card[1].add_child(UI.label("“%s”" % String(S["teaser"]), 16, UI.INK2, null, true))
		card[1].add_child(UI.label(String(S["variety"]), 13, UI.MUTED))
		var mh := UI.hbox(8); card[1].add_child(mh)
		mh.add_child(T.medal_chip(item.get("best")) if item.get("best") != null else UI.chip("not played yet", UI.MUTED, 13))
		mh.add_child(UI.spacer())
		var id := String(S["id"])
		var b := UI.button("Read the briefing", true, 15)
		b.pressed.connect(func(): shell.state["scn_id"] = id; shell.show_screen("scenario_brief"))
		mh.add_child(b)
		row.add_child(card[0])
	return v

static func _goals_panel(goals: Array, title: String, hint: String) -> Control:
	var p: Array = UI.panel(title, hint)
	for m in goals:
		var h := UI.hbox(12)
		var chip := T.medal_chip(String(m["name"]), 14); chip.custom_minimum_size = Vector2(110, 0); chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(chip)
		var cv := UI.vbox(2); cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(cv)
		for c in m["criteria"]: cv.add_child(UI.label("· " + String(c), 15, UI.INK, null, true))
		p[1].add_child(h)
	p[1].add_child(UI.label("Each medal also needs the ones below it.", 13, UI.MUTED))
	return p[0]

# ------------------------------------------------------------------ title screen: the briefing
static func _brief(shell) -> Control:
	var v := UI.vbox(18)
	var id := String(shell.state.get("scn_id", ""))
	var item := {}
	for it in _list_json(): if String(it["scenario"]["id"]) == id: item = it
	if item.is_empty():
		shell.call_deferred("show_screen", "scenarios")
		return v
	var S: Dictionary = item["scenario"]
	var top := UI.hbox(12); v.add_child(top)
	var hv := UI.vbox(4); hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(hv)
	hv.add_child(UI.head(String(S["title"]), 40, UI.INK))
	hv.add_child(UI.label("“%s”" % String(S["teaser"]), 18, UI.INK2))
	var back := UI.button("‹ Famous vintages", false, 15); back.pressed.connect(func(): shell.show_screen("scenarios")); top.add_child(back)
	var bp: Array = UI.panel("The briefing", "what a grower knew in January")
	bp[1].add_child(UI.label(String(S["briefing"]), 17, UI.INK, null, true))
	v.add_child(bp[0])
	v.add_child(_goals_panel(item["goals"], "Your goals", "judged on your best %s Wine of %d, once it is in bottle" % [S["variety"], int(S["vintage"])]))
	var start := UI.button("Start %s" % String(S["title"]), true, 18); start.custom_minimum_size = Vector2(360, 52)
	start.pressed.connect(func():
		if Sim.NewScenarioGame(id):
			shell.state.clear(); shell.current = ""; shell.refresh()
			shell.notify("%s: the vines are yours. Open the scenario from the medal chip at the top." % String(S["title"]), true)
		else: shell.notify("The scenario could not start: " + String(Sim.LastError())))
	v.add_child(start)
	return v

# ------------------------------------------------------------------ in a scenario game: goals, then the debrief
static func _status(shell) -> Control:
	var v := UI.vbox(18)
	var St = JSON.parse_string(Sim.ScenarioStatus())
	if not (St is Dictionary) or St.get("scenario") == null:
		v.add_child(UI.label("This Estate is not a famous-vintage scenario.", 16, UI.INK2))
		return v
	var S: Dictionary = St["scenario"]
	var top := UI.hbox(12); v.add_child(top)
	var hv := UI.vbox(4); hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(hv)
	hv.add_child(UI.head(String(S["title"]), 36, UI.INK))
	hv.add_child(UI.label("“%s”" % String(S["teaser"]), 16, UI.INK2))
	if not St.get("judged", false):
		v.add_child(_goals_panel(St["goals"], "Your goals", "judged when your first %s Wine of %d is in bottle" % [S["variety"], int(S["vintage"])]))
		var bp: Array = UI.panel("The briefing", "")
		bp[1].add_child(UI.label(String(S["briefing"]), 15, UI.INK2, null, true))
		v.add_child(bp[0])
		return v
	Sim.ScenarioDebriefSeen()
	var E: Dictionary = St["evaluation"]; var Db: Dictionary = St["debrief"]
	# medals
	var mp: Array = UI.panel("Your medal", "for %s (%s, %s)" % [E["wine"]["name"], E["wine"]["category"], E["wine"]["quality"]])
	var mh := UI.hbox(12); mp[1].add_child(mh)
	mh.add_child(T.medal_chip(E.get("medal"), 20) if E.get("medal") != null else UI.chip("no medal this time", UI.MUTED, 18))
	for m in E["medals"]:
		var h := UI.hbox(12)
		var chip := T.medal_chip(String(m["name"]), 13); chip.custom_minimum_size = Vector2(110, 0); chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		chip.modulate = Color(1, 1, 1, 1.0 if m["met"] else 0.45)
		h.add_child(chip)
		var cv := UI.vbox(2); cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(cv)
		for c in m["criteria"]:
			var ev := String(c["evidence"])
			cv.add_child(UI.label(("✓ " if c["met"] else "✗ ") + String(c["text"]) + ("" if ev == "" else "  —  " + ev), 15, UI.GOOD if c["met"] else UI.SERIOUS, null, true))
		mp[1].add_child(h)
	v.add_child(mp[0])
	var row := UI.hbox(16); v.add_child(row)
	var c1 := UI.vbox(16); c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(c1)
	var c2 := UI.vbox(16); c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(c2)
	# what happened
	if Db.get("note") != null:
		var np: Array = UI.panel("What happened in %d" % int(S["vintage"]), "")
		np[1].add_child(UI.label(String(Db["note"]["note"]), 15, UI.INK, null, true))
		np[1].add_child(_sources(Db["note"]["sources"]))
		c1.add_child(np[0])
	# what growers did
	if Db["growers"].size() > 0:
		var gp: Array = UI.panel("What real growers did", "")
		for g in Db["growers"]:
			gp[1].add_child(UI.label("· " + String(g["text"]), 15, UI.INK, null, true))
			gp[1].add_child(UI.label("    " + String(g["source"].get("title", g["source"]["key"])), 12, UI.MUTED, null, true))
		c1.add_child(gp[0])
	# your Wine against the real year
	if Db["compare"].size() > 0:
		var cp: Array = UI.panel("Your Wine against the real year", "")
		for c in Db["compare"]:
			var h := UI.hbox(10)
			var l := UI.label(String(c["label"]), 14, UI.INK2, null, true); l.custom_minimum_size = Vector2(170, 0); h.add_child(l)
			var y := UI.label(String(c["yours"]), 15, UI.INK, UI.f_body_b); y.custom_minimum_size = Vector2(120, 0); h.add_child(y)
			var r := UI.label(String(c["real"]), 14, UI.INK2, null, true); r.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(r)
			cp[1].add_child(h)
		cp[1].add_child(UI.label("Left: your Wine. Right: what was reported that year (sources in docs/science/vintage-notes.md).", 12, UI.MUTED, null, true))
		c2.add_child(cp[0])
	if Db["causes"].size() > 0:
		var qp: Array = UI.panel("Added to your review queue", "Tasting practice brings these back")
		for c in Db["causes"]: qp[1].add_child(UI.label("· " + String(c["title"]), 15, UI.INK, null, true))
		c2.add_child(qp[0])
	var bh := UI.hbox(12); v.add_child(bh)
	var keep := UI.button("Keep playing this Estate", true, 16); keep.pressed.connect(func(): shell.show_screen("inbox")); bh.add_child(keep)
	var more := UI.button("Famous vintages", false, 16); more.pressed.connect(func(): shell.show_screen("scenarios")); bh.add_child(more)
	return v

static func _sources(arr: Array) -> Control:
	var t := []
	for s in arr: t.append(String(s.get("title", "")))
	return UI.label("Sources: " + "; ".join(t), 12, UI.MUTED, null, true)
