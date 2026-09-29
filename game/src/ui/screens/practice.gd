# Tasting practice: one simulated Wine at a time in one of four exercises (Conclusions, Cause to glass, Identify, your Tasting
# sheet), the Glass of the day, adaptive practice aimed at the weakest skill, then an item-by-item reveal where every answer
# says why. Reachable from the title screen and from a game (ADR 0002 locks vintages not yet harvested there).
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const T := preload("res://src/ui/tasting_ui.gd")

static func build(_D: Dictionary, shell) -> Control:
	var L := T.lobby(shell)
	var v := UI.vbox(16)
	v.add_child(T.header(shell, L, "practice"))
	var view := String(shell.state.get("tp_view", ""))
	if view != "" and String(shell.state.get("tp_owner", "practice")) != "practice":
		v.add_child(_elsewhere(shell))
		view = ""
	match view:
		"pouring": v.add_child(T.pouring_view(shell, "practice"))
		"answer": v.add_child(_answer(shell))
		"reveal": v.add_child(_reveal(shell))
		_: v.add_child(_lobby(shell, L))
	return UI.scroll(v)

static func _elsewhere(shell) -> Control:
	var h := UI.hbox(12)
	h.add_child(UI.label("A Flight is waiting for you at the Wine Fair.", 15, UI.INK2))
	var b := UI.button("Go to the stand", true, 15); b.pressed.connect(func(): shell.show_screen("fair")); h.add_child(b)
	return h

# ------------------------------------------------------------------ lobby
static func _lobby(shell, L: Dictionary) -> Control:
	var v := UI.vbox(16)
	if not L.get("available", true):
		var p: Array = UI.panel("Tasting practice opens with your first harvest from 1995 on", "")
		p[1].add_child(UI.label("Inside a game only vintages already harvested on its Timeline can be poured (no future knowledge). Open Tasting practice from the title screen to taste every vintage from 1995 to 2025.", 15, UI.INK2, null, true))
		v.add_child(p[0])
		return v
	var S: Dictionary = L.get("summary", {})
	var top := UI.hbox(16); v.add_child(top)
	# Glass of the day
	var gd: Array = UI.panel("Glass of the day", "Identify · +25 XP bonus")
	gd[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var done: bool = S.get("dailyDone", false)
	gd[1].add_child(UI.label("One blind glass a day, the same for everyone. Name the grape, the Region and how warm the vintage was." if not done
		else "Done for today. Come back tomorrow to keep your run going.", 15, UI.INK2, null, true))
	gd[1].add_child(UI.label("%d day%s in a row · best run %d" % [int(S.get("daysInARow", 0)), "" if int(S.get("daysInARow", 0)) == 1 else "s", int(S.get("bestDaysInARow", 0))], 14, UI.WARN))
	if not done:
		var b := UI.button("Pour today's glass", true, 16)
		b.pressed.connect(func(): T.start_pour(shell, {"kind": "daily"}, "practice"))
		gd[1].add_child(b)
	top.add_child(gd[0])
	# adaptive practice
	var wk: Array = UI.panel("Practise your weak spot", "")
	wk[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fl = L.get("focusLine", null)
	wk[1].add_child(UI.label(String(fl) if fl != null else "Answer a few glasses first: once each skill has three answers, this pours Wines aimed at the one you find hardest.", 15, UI.INK2, null, true))
	var wb := UI.button("Pour a glass for me", fl != null, 16)
	wb.pressed.connect(func(): T.start_pour(shell, {"kind": "suggest"}, "practice"))
	wk[1].add_child(wb)
	top.add_child(wk[0])
	# the four exercises
	var ex: Array = UI.panel("Exercises", "a random Wine from 1995–2025 in each")
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14); grid.add_theme_constant_override("v_separation", 14)
	ex[1].add_child(grid)
	for e in L.get("exercises", []):
		var c := UI.card(false, 16); c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := UI.vbox(8); c.add_child(cv)
		cv.add_child(UI.head(String(e["title"]), 22, UI.INK))
		cv.add_child(UI.label(String(e["line"]), 15, UI.INK2, null, true))
		var id: String = e["id"]
		var b := UI.button("Pour a glass", false, 15)
		b.pressed.connect(func(): T.start_pour(shell, {"kind": "practice", "exercise": id}, "practice"))
		cv.add_child(b)
		grid.add_child(c)
	v.add_child(ex[0])
	var low := UI.hbox(16); v.add_child(low)
	low.add_child(_skills(S))
	low.add_child(_ranks(L))
	return v

static func _skills(S: Dictionary) -> Control:
	var p: Array = UI.panel("Your skills", "average of the last 20 answers")
	p[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for sk in S.get("skills", []):
		var h := UI.hbox(10)
		var nl := UI.label(String(sk["skill"]).capitalize(), 15, UI.INK2); nl.custom_minimum_size = Vector2(130, 0); h.add_child(nl)
		var bar := ProgressBar.new(); bar.show_percentage = false; bar.custom_minimum_size = Vector2(260, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = 1.0; bar.value = float(sk["avg"]) if sk["avg"] != null else 0.0
		h.add_child(bar)
		h.add_child(UI.label(("%d %%  (%d)" % [int(round(float(sk["avg"]) * 100)), int(sk["n"])]) if sk["avg"] != null else "not tried yet", 14, UI.MUTED))
		if S.get("weakest", null) != null and String(S["weakest"]) == String(sk["skill"]): h.add_child(UI.chip("weak spot", UI.SERIOUS, 12))
		p[1].add_child(h)
	return p[0]

static func _ranks(L: Dictionary) -> Control:
	var p: Array = UI.panel("Taster ranks", "every marked answer earns XP")
	p[0].custom_minimum_size = Vector2(520, 0)
	var cur := String(L.get("summary", {}).get("rank", ""))
	for r in L.get("ranks", []):
		var on := String(r["name"]) == cur
		var h := UI.hbox(10)
		var n := UI.label(String(r["name"]), 16, UI.GOLD if on else UI.INK, UI.f_body_b if on else null); n.custom_minimum_size = Vector2(140, 0); h.add_child(n)
		h.add_child(UI.label("%d XP" % int(r["xp"]), 14, UI.MUTED))
		var ln := UI.label(String(r["line"]), 14, UI.INK2, null, true); ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(ln)
		p[1].add_child(h)
	return p[0]

# ------------------------------------------------------------------ answering
static func _answer(shell) -> Control:
	var S: Dictionary = shell.state["tp_session"]
	var G: Dictionary = S["glasses"][0]
	var v := UI.vbox(14)
	var head := UI.hbox(12); v.add_child(head)
	var hv := UI.vbox(2); hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(hv)
	hv.add_child(UI.head(("Glass of the day: " if String(S["kind"]) == "daily" else "") + String(S["exerciseTitle"]), 26, UI.INK))
	hv.add_child(UI.label(String(S["exerciseLine"]), 15, UI.INK2, null, true))
	if S.get("focusLine", null) != null: hv.add_child(UI.label(String(S["focusLine"]), 15, UI.SERIOUS))
	var quit := UI.button("Leave this glass", false, 14)
	quit.pressed.connect(func(): T.reset(shell); shell.show_screen("practice"))
	quit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(quit)
	var row := UI.hbox(16); v.add_child(row)
	var left := T.shown_panel(G, String(S["exercise"]))
	left.custom_minimum_size = Vector2(620, 0)
	row.add_child(left)
	var ans: Array = UI.panel("Your answers", "%d of %d answered" % [T.answered(shell, 0, G), G["keys"].size()])
	ans[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ans[1].add_child(T.pickers(shell, "practice", 0, G))
	ans[1].add_child(UI.divider())
	ans[1].add_child(T.hint_row(shell, "practice", 0, G))
	var mb := UI.button("Mark my answers", true, 17); mb.custom_minimum_size = Vector2(240, 46)
	mb.pressed.connect(func(): T.mark(shell, "practice"))
	ans[1].add_child(mb)
	row.add_child(ans[0])
	return v

# ------------------------------------------------------------------ reveal
static func _reveal(shell) -> Control:
	var R: Dictionary = shell.state["tp_result"]
	var S: Dictionary = shell.state["tp_session"]
	var animate: bool = not shell.capture and not shell.state.get("tp_anim_done", false)
	shell.state["tp_anim_done"] = true
	var v := UI.vbox(14)
	v.add_child(T.result_banner(R))
	var g: Dictionary = R["glasses"][0]
	var W: Dictionary = S["glasses"][0]["wine"]
	var p: Array = UI.panel("%s · %s" % [String(g.get("label", W.get("label", ""))), String(g["producer"])], String(g["style"]))
	p[1].add_child(T.item_rows(g["items"], animate))
	p[1].add_child(UI.label(String(g["climate"]), 13, UI.MUTED, null, true))
	var np = T.note_panel(g.get("note", null))
	if np != null: p[1].add_child(np)
	v.add_child(p[0])
	var sheet: Array = UI.panel("The full Tasting sheet", "every line says why")
	sheet[1].add_child(T._sheet_view(W, ["appearance", "nose", "palate"]))
	sheet[1].add_child(UI.label(String(W["sheet"]["qualityBecause"]), 14, UI.INK2, null, true))
	v.add_child(sheet[0])
	var bar := UI.hbox(12); v.add_child(bar)
	var req: Dictionary = shell.state.get("tp_req", {})
	if String(req.get("kind", "")) != "daily":
		var again := UI.button("Pour another", true, 16)
		again.pressed.connect(func():
			var r2 := req.duplicate(); r2.erase("seed")
			shell.state.erase("tp_view"); T.start_pour(shell, r2, "practice"))
		bar.add_child(again)
	var back := UI.button("Back to Tasting practice", false, 16)
	back.pressed.connect(func(): T.reset(shell); shell.show_screen("practice"))
	bar.add_child(back)
	return v
