# The Wine Fair: themed stands, each hosted by an invented producer who pours a Flight from real vintages. For each glass the
# player writes their Tasting sheet, then answers the host's vintage quiz; the reveal plays the verdicts one by one, shows the
# real vintage notes and awards a medal. Medals open more stands; the Taster rank opens blind Flights.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const T := preload("res://src/ui/tasting_ui.gd")
const Avatar := preload("res://src/ui/avatar.gd")

static func build(_D: Dictionary, shell) -> Control:
	var L := T.lobby(shell)
	var v := UI.vbox(16)
	v.add_child(T.header(shell, L, "fair"))
	var view := String(shell.state.get("tp_view", ""))
	if view != "" and String(shell.state.get("tp_owner", "fair")) != "fair":
		var h := UI.hbox(12)
		h.add_child(UI.label("You have a glass waiting in Tasting practice.", 15, UI.INK2))
		var b := UI.button("Back to it", true, 15); b.pressed.connect(func(): shell.show_screen("practice")); h.add_child(b)
		v.add_child(h)
		view = ""
	match view:
		"pouring": v.add_child(T.pouring_view(shell, "fair"))
		"answer": v.add_child(_stand(shell))
		"reveal": v.add_child(_reveal(shell))
		_: v.add_child(_stands(shell, L))
	return UI.scroll(v)

# ------------------------------------------------------------------ the stands
static func _stands(shell, L: Dictionary) -> Control:
	var v := UI.vbox(14)
	var S: Dictionary = L.get("summary", {})
	var blind_ok: bool = S.get("blindUnlocked", false)
	var blind: bool = blind_ok and shell.state.get("fair_blind", false)
	var bar := UI.hbox(12); v.add_child(bar)
	bar.add_child(UI.label("Win medals to open more stands: %d medal%s so far." % [int(S.get("medalCount", 0)), "" if int(S.get("medalCount", 0)) == 1 else "s"], 15, UI.INK2))
	bar.add_child(UI.spacer())
	if blind_ok:
		bar.add_child(UI.label("Flights:", 15, UI.INK2))
		var set_blind := func(o): shell.state["fair_blind"] = (o == "Blind"); shell.show_screen("fair")
		bar.add_child(UI.segmented(["Vintages shown", "Blind"], "Blind" if blind else "Vintages shown", set_blind))
	else:
		bar.add_child(UI.label("Blind Flights open at the rank of Taster.", 14, UI.MUTED))
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16); grid.add_theme_constant_override("v_separation", 16)
	v.add_child(grid)
	for st in L.get("stands", []):
		grid.add_child(_stand_card(shell, st, blind))
	return v

static func _stand_card(shell, st: Dictionary, blind: bool) -> Control:
	var locked: bool = st.get("locked", false) or st.get("tierLocked", false)
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UI.sb(UI.SURFACE if not locked else UI.SUNKEN, 8, T.MEDAL_COL.get(str(st.get("medal", "")), UI.LINE), 2 if st.get("medal") != null else 1, 18))
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(0, 230)
	var h := UI.hbox(16); c.add_child(h)
	var host: Dictionary = st["host"]
	var av := Avatar.make(String(host["name"]), "cellar", 72)
	if locked: av.modulate = Color(1, 1, 1, 0.35)
	h.add_child(av)
	var v := UI.vbox(6); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(v)
	var top := UI.hbox(8); v.add_child(top)
	top.add_child(UI.head(String(st["title"]), 22, UI.INK if not locked else UI.MUTED))
	top.add_child(UI.spacer())
	if not locked: top.add_child(T.medal_chip(st.get("medal", null), 13))
	v.add_child(UI.label(String(st["blurb"]), 15, UI.INK2 if not locked else UI.MUTED, null, true))
	v.add_child(UI.label("%s, %s" % [host["name"], host["producer"]], 14, UI.GOLD if not locked else UI.MUTED))
	if st.get("locked", false):
		pass   # the blurb already says when it opens
	elif st.get("tierLocked", false):
		v.add_child(UI.label("Locked: win %d medal%s to open this stand." % [int(st["medalsNeeded"]), "" if int(st["medalsNeeded"]) == 1 else "s"], 14, UI.MUTED))
	else:
		v.add_child(UI.label("“%s”" % host["greeting"], 14, UI.INK, null, true))
		var info := "%d glasses · %s · %s" % [int(st["glasses"]), st["variety"], "vintages hidden" if blind else " · ".join(st["shown"])]
		v.add_child(UI.label(info, 13, UI.MUTED))
		var row := UI.hbox(10); v.add_child(row)
		var id: String = st["id"]
		var b := UI.button("Taste this Flight", true, 15)
		b.pressed.connect(func(): T.start_pour(shell, {"kind": "stand", "stand": id, "blind": blind}, "fair"))
		row.add_child(b)
		if st.get("bestPercent", null) != null: row.add_child(UI.label("best %d %%" % int(round(float(st["bestPercent"]))), 14, UI.MUTED))
	return c

# ------------------------------------------------------------------ at the stand
static func _stand(shell) -> Control:
	var S: Dictionary = shell.state["tp_session"]
	var st: Dictionary = S["stand"]
	var glasses: Array = S["glasses"]
	var n := glasses.size()
	var gi := int(shell.state.get("tp_glass", 0))
	var v := UI.vbox(14)
	var head := UI.hbox(14); v.add_child(head)
	head.add_child(Avatar.make(String(st["host"]["name"]), "cellar", 56))
	var hv := UI.vbox(2); hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(hv)
	hv.add_child(UI.head(String(st["title"]), 26, UI.INK))
	hv.add_child(UI.label("%s, %s: “%s”" % [st["host"]["name"], st["host"]["producer"], st["host"]["greeting"]], 15, UI.INK2, null, true))
	var quit := UI.button("Leave the stand", false, 14)
	quit.pressed.connect(func(): T.reset(shell); shell.show_screen("fair"))
	quit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(quit)
	# the Flight as columns: click a glass to write its sheet; the last column is the quiz
	var strip := UI.hbox(12); v.add_child(strip)
	for i in n:
		var G: Dictionary = glasses[i]
		var c := UI.card(i == gi, 12); c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := UI.vbox(4); c.add_child(cv)
		cv.add_child(T.glass(G["wine"]["sheet"], 0.55))
		var t := UI.head("Glass %d" % (i + 1), 18, UI.GOLD if i == gi else UI.INK); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cv.add_child(t)
		var sl := UI.label(String(G["shown"]), 15, UI.INK2); sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cv.add_child(sl)
		var done := T.answered(shell, i, G)
		var dl := UI.label("%d / %d answered" % [done, G["keys"].size()], 13, UI.GOOD if done == G["keys"].size() else UI.MUTED); dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cv.add_child(dl)
		var idx := i
		UI.on_click(c, func(): shell.state["tp_glass"] = idx; shell.show_screen("fair"))
		strip.add_child(c)
	var qc := UI.card(gi >= n, 12); qc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var qv := UI.vbox(4); qc.add_child(qv)
	var qt := UI.head("Vintage quiz", 18, UI.GOLD if gi >= n else UI.INK); qt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; qv.add_child(qt)
	var answers: Dictionary = shell.state["tp_answers"]
	var ql := UI.label("%d / %d answered" % [answers["quiz"].size(), S["quiz"].size()], 13, UI.MUTED); ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; qv.add_child(ql)
	UI.on_click(qc, func(): shell.state["tp_glass"] = n; shell.show_screen("fair"))
	strip.add_child(qc)
	if gi < n:
		var G: Dictionary = glasses[gi]
		var row := UI.hbox(16); v.add_child(row)
		var left := T.shown_panel(G, "sheet", S.get("blind", false)); left.custom_minimum_size = Vector2(560, 0)
		row.add_child(left)
		var ans: Array = UI.panel("Your Tasting sheet · Glass %d" % (gi + 1), "%d of %d answered" % [T.answered(shell, gi, G), G["keys"].size()])
		ans[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ans[1].add_child(T.pickers(shell, "fair", gi, G))
		ans[1].add_child(UI.divider())
		ans[1].add_child(T.hint_row(shell, "fair", gi, G))
		row.add_child(ans[0])
	else:
		var qp: Array = UI.panel("%s asks" % st["host"]["name"], "one mark each")
		for q in S["quiz"]:
			var topic: String = q["topic"]
			qp[1].add_child(UI.label(String(q["text"]), 17, UI.INK, UI.f_body_b, true))
			var pick := func(o): answers["quiz"][topic] = o; shell.show_screen("fair")
			qp[1].add_child(UI.segmented(q["options"], String(answers["quiz"].get(topic, "")), pick, 120))
		v.add_child(qp[0])
	var bar := UI.hbox(12); v.add_child(bar)
	if gi < n:
		var nx := UI.button("Next: %s  ›" % ("Glass %d" % (gi + 2) if gi + 1 < n else "the vintage quiz"), false, 16)
		nx.pressed.connect(func(): shell.state["tp_glass"] = gi + 1; shell.show_screen("fair"))
		bar.add_child(nx)
	var mb := UI.button("Mark the Flight", true, 17); mb.custom_minimum_size = Vector2(240, 46)
	mb.pressed.connect(func(): T.mark(shell, "fair"))
	bar.add_child(mb)
	return v

# ------------------------------------------------------------------ reveal
static func _reveal(shell) -> Control:
	var R: Dictionary = shell.state["tp_result"]
	var S: Dictionary = shell.state["tp_session"]
	var animate: bool = not shell.capture and not shell.state.get("tp_anim_done", false)
	shell.state["tp_anim_done"] = true
	var v := UI.vbox(14)
	v.add_child(T.result_banner(R, true))
	var delay := 0.0
	for i in R["glasses"].size():
		var g: Dictionary = R["glasses"][i]
		var p: Array = UI.panel("Glass %d · %s" % [i + 1, String(g["label"])], "%s · %s" % [g["producer"], g["style"]])
		var h := UI.hbox(18); p[1].add_child(h)
		h.add_child(T.glass(S["glasses"][i]["wine"]["sheet"], 0.6))
		var col := UI.vbox(8); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(col)
		col.add_child(UI.label("%s / %d marks · %s" % [T._n(float(g["total"])), int(g["max"]), String(g["climate"])], 14, UI.INK2, null, true))
		col.add_child(T.item_rows(g["items"], animate, delay))
		delay += 0.07 * g["items"].size()
		var np = T.note_panel(g.get("note", null))
		if np != null: col.add_child(np)
		v.add_child(p[0])
	var qp: Array = UI.panel("Vintage quiz", "the evidence is the weather record and the Wines themselves")
	qp[1].add_child(T.item_rows(R["quiz"], animate, delay, 420.0))
	v.add_child(qp[0])
	var bar := UI.hbox(12); v.add_child(bar)
	var again := UI.button("Taste this stand again", false, 16)
	var req: Dictionary = shell.state.get("tp_req", {})
	again.pressed.connect(func():
		var r2 := req.duplicate(); r2.erase("seed")
		shell.state.erase("tp_view"); T.start_pour(shell, r2, "fair"))
	bar.add_child(again)
	var back := UI.button("Back to the stands", true, 16)
	back.pressed.connect(func(): T.reset(shell); shell.show_screen("fair"))
	bar.add_child(back)
	var cb := UI.button("Open the Cellar book", false, 16)
	cb.pressed.connect(func(): T.reset(shell); shell.show_screen("cellarbook"))
	bar.add_child(cb)
	return v
