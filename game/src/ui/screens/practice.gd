# Tasting practice: today's review session (Causes due, the weak spot and something new, each checked a different way), the
# Glass of the day, four single-glass exercises, and the Progress view (Causes known, calibration, skills over time). Every
# answer is committed with a Confidence before the reveal, and every verdict says why (learning-core design §4–§5).
# Reachable from the title screen and from a game (ADR 0002 locks vintages not yet harvested there).
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
	var S: Dictionary = shell.state.get("tp_session", {})
	match view:
		"pouring": v.add_child(T.pouring_view(shell, "practice"))
		"answer": v.add_child(_session(shell) if S.has("entries") and S["entries"].size() > 0 else _answer(shell))
		"reveal": v.add_child(_session_reveal(shell) if shell.state.get("tp_result", {}).has("entries") else _reveal(shell))
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
	# today's session: the heart of the study loop
	var due := int(S.get("due", 0))
	var ss: Array = UI.panel("Today's session", "about 6 questions, 5–10 minutes")
	ss[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL; ss[0].size_flags_stretch_ratio = 1.6
	var line := ""
	if due > 0: line = "%d Cause%s due for review, plus your weak spot and something new." % [due, "" if due == 1 else "s"]
	elif int(S.get("known", 0)) > 0: line = "Nothing is due today: the session brings something new and your weak spot."
	else: line = "Start here. Each session teaches a few Causes (why a Wine tastes as it does) and brings them back over the next days and weeks until you know them for good."
	ss[1].add_child(UI.label(line, 16, UI.INK2, null, true))
	var sb := UI.button("Start today's session", true, 17); sb.custom_minimum_size = Vector2(280, 46)
	sb.pressed.connect(func(): T.start_pour(shell, {"kind": "session"}, "practice"))
	ss[1].add_child(sb)
	top.add_child(ss[0])
	# Glass of the day
	var gd: Array = UI.panel("Glass of the day", "Identify")
	gd[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var done: bool = S.get("dailyDone", false)
	gd[1].add_child(UI.label("One blind glass a day: name the grape, the Region and how warm the vintage was." if not done
		else "Done for today. Come back tomorrow.", 15, UI.INK2, null, true))
	if not done:
		var b := UI.button("Pour today's glass", false, 16)
		b.pressed.connect(func(): T.start_pour(shell, {"kind": "daily"}, "practice"))
		gd[1].add_child(b)
	top.add_child(gd[0])
	# the four exercises
	var ex: Array = UI.panel("Practise one exercise", "a single Wine from 1995–%s" % (str(int(L["maxVintage"])) if L.get("maxVintage") != null else "2025"))
	var grid := GridContainer.new(); grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12)
	ex[1].add_child(grid)
	for e in L.get("exercises", []):
		var c := UI.card(false, 14); c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := UI.vbox(6); c.add_child(cv)
		cv.add_child(UI.head(String(e["title"]), 19, UI.INK))
		cv.add_child(UI.label(String(e["line"]), 13, UI.INK2, null, true))
		var id: String = e["id"]
		var b := UI.button("Pour a glass", false, 14)
		b.pressed.connect(func(): T.start_pour(shell, {"kind": "practice", "exercise": id}, "practice"))
		cv.add_child(b)
		grid.add_child(c)
	v.add_child(ex[0])
	v.add_child(_progress(S))
	return v

# ------------------------------------------------------------------ Progress view
static func _progress(S: Dictionary) -> Control:
	var p: Array = UI.panel("Progress", "measured by what you still know days later, not by how much you answer")
	var row := UI.hbox(28); p[1].add_child(row)
	# Causes known, by topic
	var kv := UI.vbox(8); kv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(kv)
	kv.add_child(UI.label("Causes known", 15, UI.GOLD, UI.f_body_b))
	kv.add_child(UI.num("%d of %d" % [int(S.get("known", 0)), int(S.get("catalogSize", 0))], 26, UI.INK))
	kv.add_child(UI.label("Known means right on three separate days. Two misses in a row and it goes back to learning. Green known, amber learning, grey not seen yet.", 13, UI.MUTED, null, true))
	var cov = S.get("coverage", null)
	if cov != null:
		for t in cov:
			var h := UI.hbox(8)
			var tl := UI.label(String(t["topic"]), 14, UI.INK2, null, true); tl.custom_minimum_size = Vector2(200, 0); h.add_child(tl)
			var bar := StackBar.new(); bar.parts = [int(t["known"]), int(t["learning"]), int(t["notSeen"])]
			bar.custom_minimum_size = Vector2(260, 10); bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(bar)
			h.add_child(UI.label("%d / %d" % [int(t["known"]), int(t["known"]) + int(t["learning"]) + int(t["notSeen"])], 13, UI.MUTED))
			kv.add_child(h)
	# calibration
	var cv := UI.vbox(8); cv.custom_minimum_size = Vector2(360, 0); row.add_child(cv)
	cv.add_child(UI.label("How sure, how right", 15, UI.GOLD, UI.f_body_b))
	var cal: Array = S.get("calibration", [])
	var acc := {}
	for c in cal:
		var h := UI.hbox(8)
		var nl := UI.label("When you say \"%s\"" % T.CONF[int(c["confidence"]) - 1], 14, UI.INK2); nl.custom_minimum_size = Vector2(170, 0); h.add_child(nl)
		if c["accuracy"] != null:
			acc[int(c["confidence"])] = [float(c["accuracy"]), int(c["n"])]
			var m := ProgressBar.new(); m.show_percentage = false; m.max_value = 1.0; m.value = float(c["accuracy"])
			m.custom_minimum_size = Vector2(100, 10); m.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(m)
			h.add_child(UI.label("right %d %% (%d)" % [int(round(float(c["accuracy"]) * 100)), int(c["n"])], 13, UI.MUTED))
		else:
			h.add_child(UI.label("no answers yet", 13, UI.MUTED))
		cv.add_child(h)
	cv.add_child(UI.label(_calibration_line(acc), 13, UI.INK2, null, true))
	# skills over time
	var sv := UI.vbox(6); sv.custom_minimum_size = Vector2(340, 0); row.add_child(sv)
	sv.add_child(UI.label("Skills over time", 15, UI.GOLD, UI.f_body_b))
	var any := false
	for sk in S.get("skills", []):
		if sk["avg"] == null or int(sk["n"]) < 3: continue
		any = true
		var h := UI.hbox(8)
		var nl := UI.label(String(sk["skill"]).capitalize(), 13, UI.INK2); nl.custom_minimum_size = Vector2(90, 0); h.add_child(nl)
		var sp := Spark.new(); sp.values = sk.get("history", []); sp.custom_minimum_size = Vector2(120, 22); h.add_child(sp)
		h.add_child(UI.label("%d %%" % int(round(float(sk["avg"]) * 100)), 13, UI.MUTED))
		if S.get("weakest", null) != null and String(S["weakest"]) == String(sk["skill"]) and float(sk["avg"]) < 0.75: h.add_child(UI.chip("weak spot", UI.SERIOUS, 12))
		sv.add_child(h)
	if not any: sv.add_child(UI.label("Shows after a few answers per skill.", 13, UI.MUTED))
	p[1].add_child(UI.label("The game trains reasoning and vocabulary: why a Wine tastes as it does. Your nose and palate need real glasses alongside it.", 13, UI.MUTED, null, true))
	return p[0]

static func _calibration_line(acc: Dictionary) -> String:
	if not acc.has(3) or acc[3][1] < 5: return "Rate every answer honestly: after a few sessions this shows whether your confidence can be trusted."
	if acc[3][0] < 0.75: return "You are sometimes sure when you shouldn't be. Slow down on the answers you feel certain about."
	if acc.has(1) and acc[1][1] >= 5 and acc[1][0] > 0.65: return "Your guesses are better than you think: trust your reasoning a little more."
	return "Your confidence matches your results well."

class StackBar extends Control:
	var parts := [0, 0, 0]
	func _draw() -> void:
		var total := 0
		for x in parts: total += int(x)
		var cols := [Color("0ca30c"), Color("fab219"), Color("36434f")]
		draw_rect(Rect2(Vector2.ZERO, size), Color("182026"))
		if total == 0: return
		var x0 := 0.0
		for i in 3:
			var w := size.x * float(parts[i]) / float(total)
			draw_rect(Rect2(x0, 0, w, size.y), cols[i])
			x0 += w

class Spark extends Control:
	var values := []
	func _draw() -> void:
		if values.size() < 2: return
		var pts := PackedVector2Array()
		var avg := []
		for i in values.size():
			var lo := maxi(0, i - 4); var s := 0.0
			for j in range(lo, i + 1): s += float(values[j])
			avg.append(s / float(i - lo + 1))
		for i in avg.size():
			pts.append(Vector2(size.x * float(i) / float(avg.size() - 1), size.y * (1.0 - float(avg[i]))))
		draw_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), Color(1, 1, 1, 0.08))
		draw_polyline(pts, Color("d9b24c"), 2.0, true)

# ------------------------------------------------------------------ today's session
static func _entry_answers(shell, i: int) -> Dictionary:
	var A: Dictionary = shell.state["tp_answers"]
	while A["entries"].size() <= i: A["entries"].append({"answers": [], "confidence": []})
	var e: Dictionary = A["entries"][i]
	var nq: int = shell.state["tp_session"]["entries"][i]["questions"].size()
	while e["answers"].size() < nq: e["answers"].append("")
	while e["confidence"].size() < nq: e["confidence"].append(0)
	return e

static func _session(shell) -> Control:
	var S: Dictionary = shell.state["tp_session"]
	var v := UI.vbox(14)
	var head := UI.hbox(12); v.add_child(head)
	var hv := UI.vbox(2); hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(hv)
	hv.add_child(UI.head("Today's session", 26, UI.INK))
	hv.add_child(UI.label("Answer each one and say how sure you are. The reveal explains every answer, right or wrong.", 15, UI.INK2, null, true))
	var quit := UI.button("Leave the session", false, 14); quit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(func(): T.reset(shell); shell.show_screen("practice"))
	head.add_child(quit)
	var entries: Array = S["entries"]
	for i in entries.size():
		v.add_child(_entry_card(shell, i, entries[i]))
	var mb := UI.button("Mark my answers", true, 17); mb.custom_minimum_size = Vector2(260, 46)
	mb.pressed.connect(func(): T.mark(shell, "practice"))
	v.add_child(mb)
	return v

const REASON := {"due": ["due for review", Color("3987e5")], "weak": ["your weak spot", Color("ec835a")], "new": ["new", Color("0ca30c")],
	"learning": ["still learning", Color("fab219")], "review": ["review", Color("75818a")]}

static func _entry_card(shell, i: int, E: Dictionary) -> Control:
	var p: Array = UI.panel("", "", 10)
	var top := UI.hbox(10); p[1].add_child(top)
	top.add_child(UI.head("%d" % (i + 1), 22, UI.GOLD))
	var r: Array = REASON.get(String(E["reason"]), ["review", UI.MUTED])
	top.add_child(UI.chip(r[0], r[1], 12))
	var kind := String(E["kind"])
	var ans := _entry_answers(shell, i)
	if kind == "chain":
		var tl := UI.label(String(E["title"]), 17, UI.INK, UI.f_body_b, true); tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(tl)
		p[1].add_child(UI.label("Complete the chain from cause to glass.", 13, UI.MUTED))
		var steps: Array = E["steps"]
		var blanks := []
		for b in E["blanks"]: blanks.append(int(b))
		var qi := 0
		for s in steps.size():
			if s > 0: p[1].add_child(UI.label("↓", 14, UI.MUTED))
			if s in blanks:
				p[1].add_child(_question(shell, i, qi, E["questions"][qi], ans, true))
				qi += 1
			else:
				var box := PanelContainer.new(); box.add_theme_stylebox_override("panel", UI.sb(UI.RAISED, 4, UI.LINE, 1, 10))
				box.add_child(UI.label(String(steps[s]), 15, UI.INK, null, true)); p[1].add_child(box)
	elif kind == "wine":
		top.add_child(UI.label("Predict from the site, the season and the cellar", 15, UI.INK2))
		p[1].add_child(_mini_context(E["wine"]))
		p[1].add_child(_question(shell, i, 0, E["questions"][0], ans, false))
	else:
		top.add_child(UI.label("Two Wines from the same Block", 15, UI.INK2))
		var cols := UI.hbox(16); p[1].add_child(cols)
		for w in [[E["wine"], "Glass 1"], [E["wine2"], "Glass 2"]]:
			var cv := UI.vbox(4); cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; cols.add_child(cv)
			cv.add_child(UI.label(w[1], 14, UI.GOLD, UI.f_body_b))
			cv.add_child(_mini_context(w[0]))
		for q in E["questions"].size(): p[1].add_child(_question(shell, i, q, E["questions"][q], ans, false))
	return p[0]

static func _mini_context(W: Dictionary) -> Control:
	var C: Dictionary = W["context"]
	var g := GridContainer.new(); g.columns = 4
	g.add_theme_constant_override("h_separation", 14); g.add_theme_constant_override("v_separation", 2)
	var cells := [["Site", "%s, %s" % [C["plotName"], C["regionName"]]], ["Grape", "%s %d" % [C["variety"], int(C["vintage"])]],
		["Season", "%d growing-degree days · summer max %.1f °C" % [int(C["gdd"]), float(C["summerTmax"])]],
		["Picked", "%s at %d °Oe, TA %.1f g/L" % [C["harvestDate"], int(C["harvestOe"]), float(C["harvestTa"])]],
		["Cellar", String(C["styleLabel"])], ["Tasted", "%s years after harvest" % str(C["ageYears"])]]
	if float(C.get("frostLoss", 0)) >= 1: cells.append(["Spring frost", "%d %% of young shoots killed" % int(C["frostLoss"])])
	for c in cells:
		g.add_child(UI.label(c[0], 13, UI.MUTED))
		var l := UI.label(c[1], 14, UI.INK, null, true); l.custom_minimum_size = Vector2(300, 0); g.add_child(l)
	return g

static func _question(shell, i: int, j: int, Q: Dictionary, ans: Dictionary, in_chain: bool) -> Control:
	var v := UI.vbox(6)
	if not in_chain: v.add_child(UI.label(String(Q["prompt"]), 15, UI.INK, UI.f_body_b))
	var opts: Array = Q["options"]
	var chosen := str(ans["answers"][j])
	var long := false
	for o in opts: long = long or String(o).length() > 22
	var pick := func(o): ans["answers"][j] = o; shell.show_screen("practice")
	if long:
		for o in opts:
			var b := UI.button(String(o), false, 14); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if String(o) == chosen:
				b.add_theme_stylebox_override("normal", UI.sb(UI.GOLD.darkened(0.62), 4, UI.GOLD, 1, 10))
				b.add_theme_color_override("font_color", UI.GOLD.lightened(0.35))
			b.pressed.connect(pick.bind(String(o)))
			v.add_child(b)
	else:
		v.add_child(UI.segmented(opts, chosen, pick))
	if chosen != "":
		var set_conf := func(c: int): ans["confidence"][j] = c; shell.show_screen("practice")
		var h := UI.hbox(8)
		h.add_child(UI.label("How sure?", 13, UI.MUTED))
		h.add_child(T.confidence_row(int(ans["confidence"][j]), set_conf))
		v.add_child(h)
	return v

static func _session_reveal(shell) -> Control:
	var R: Dictionary = shell.state["tp_result"]
	var animate: bool = not shell.capture and not shell.state.get("tp_anim_done", false)
	shell.state["tp_anim_done"] = true
	var v := UI.vbox(14)
	v.add_child(T.result_banner(R))
	var delay := 0.0
	for e in R["entries"]:
		var p: Array = UI.panel(String(e["title"]), String(e["topic"]))
		p[1].add_child(UI.label(" → ".join(e["chain"]), 14, UI.INK2, null, true))
		p[1].add_child(T.item_rows(e["items"], animate, delay, 260.0))
		delay += 0.07 * e["items"].size()
		v.add_child(p[0])
	var rp = T.recap_panel(R)
	if rp != null: v.add_child(rp)
	var bar := UI.hbox(12); v.add_child(bar)
	var back := UI.button("Back to Tasting practice", true, 16)
	back.pressed.connect(func(): T.reset(shell); shell.show_screen("practice"))
	bar.add_child(back)
	return v

# ------------------------------------------------------------------ one-glass exercises
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

static func _reveal(shell) -> Control:
	var R: Dictionary = shell.state["tp_result"]
	var animate: bool = not shell.capture and not shell.state.get("tp_anim_done", false)
	shell.state["tp_anim_done"] = true
	var v := UI.vbox(14)
	v.add_child(T.result_banner(R))
	var g: Dictionary = R["glasses"][0]
	var W: Dictionary = g["wine"]
	var p: Array = UI.panel("%s · %s" % [str(g.get("label", "")), str(g["producer"])], str(g["style"]))
	p[1].add_child(T.item_rows(g["items"], animate))
	p[1].add_child(UI.label(String(g["climate"]), 13, UI.MUTED, null, true))
	var np = T.note_panel(g.get("note", null))
	if np != null: p[1].add_child(np)
	v.add_child(p[0])
	var rp = T.recap_panel(R)
	if rp != null: v.add_child(rp)
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
