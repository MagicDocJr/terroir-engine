# Shared pieces of the Tasting-practice screens (Tasting practice, Wine Fair, Cellar book): the header with the Taster rank,
# pour polling, what each exercise shows, the answer pickers and the item-by-item reveal. Reads bridge JSON only; the
# simulation pours, marks and keeps the progression (ADR 0001).
extends RefCounted

const UI := preload("res://src/ui/ui.gd")

const TABS := [["practice", "Practice"], ["fair", "Wine Fair"], ["cellarbook", "Cellar book"]]
const MEDAL_COL := {"bronze": Color("c98a4b"), "silver": Color("c3ccd3"), "gold": Color("e6c14f")}

## The lobby JSON, cached in shell state until a pour is marked (then re-read).
static func lobby(shell) -> Dictionary:
	if not shell.state.has("tp_lobby"):
		var parsed = JSON.parse_string(Sim.PracticeLobby())
		shell.state["tp_lobby"] = parsed if parsed is Dictionary else {}
	return shell.state["tp_lobby"]

static func medal_chip(m, size := 14) -> Control:
	if m == null or String(m) == "": return UI.chip("no medal yet", UI.MUTED, size)
	return UI.chip("● " + String(m).capitalize(), MEDAL_COL.get(String(m), UI.GOLD), size, true)

# ------------------------------------------------------------------ header and tabs
static func header(shell, L: Dictionary, tab: String) -> Control:
	var v := UI.vbox(12)
	var S: Dictionary = L.get("summary", {})
	var titles := {"practice": ["Tasting practice", "The simulation pours real vintages; you assess them with the systematic approach and learn why each Wine tastes as it does."],
		"fair": ["Wine Fair", "Themed stands pour Flights side by side. Write your Tasting sheet for each glass, answer the host's vintage quiz, win medals."],
		"cellarbook": ["Cellar book", "A card for every vintage you have tasted at the Fair: the weather in numbers and what really happened."]}
	var right: Array = []
	if not Sim.HasGame():
		var back := UI.button("‹ Title", false, 15)
		back.pressed.connect(func(): shell.show_screen("title"))
		right.append(back)
	right.append(rank_badge(L))
	v.add_child(UI.page_header(titles[tab][0], titles[tab][1], right))
	var h := UI.hbox(8)
	for t in TABS:
		var id: String = t[0]
		var b := UI.button(t[1], false, 16)
		b.custom_minimum_size = Vector2(150, 38)
		if id == tab:
			b.add_theme_stylebox_override("normal", UI.sb(UI.GOLD.darkened(0.62), 4, UI.GOLD, 1, 12))
			b.add_theme_color_override("font_color", UI.GOLD.lightened(0.35))
		b.pressed.connect(func(): shell.show_screen(id))
		h.add_child(b)
	h.add_child(UI.spacer())
	var R: Dictionary = S.get("rhythm", {})
	if not R.is_empty():
		var days := int(R.get("daysThisWeek", 0))
		h.add_child(UI.chip("◆ %d of %d study days this week" % [days, int(R.get("target", 5))], UI.GOOD if R.get("met", false) else UI.WARN, 14))
	if int(S.get("catalogSize", 0)) > 0: h.add_child(UI.chip("%d of %d Causes known" % [int(S.get("known", 0)), int(S.get("catalogSize", 0))], UI.GOOD, 14))
	h.add_child(UI.chip("%d medal%s" % [int(S.get("medalCount", 0)), "" if int(S.get("medalCount", 0)) == 1 else "s"], UI.GOLD, 14))
	h.add_child(UI.chip("%d Vintage card%s" % [S.get("cards", []).size(), "" if S.get("cards", []).size() == 1 else "s"], UI.SEQ, 14))
	v.add_child(h)
	return v

static func rank_badge(L: Dictionary) -> Control:
	var S: Dictionary = L.get("summary", L)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sb(UI.RAISED, 6, UI.GOLD.darkened(0.3), 1, 12))
	var v := UI.vbox(4); p.add_child(v)
	var top := UI.hbox(10); v.add_child(top)
	top.add_child(UI.head(String(S.get("rank", "Novice taster")), 20, UI.GOLD))
	top.add_child(UI.spacer())
	var bar := ProgressBar.new(); bar.show_percentage = false; bar.custom_minimum_size = Vector2(260, 8)
	if S.get("byKnown", false):
		# ranks report durable mastery: the share of the Cause catalogue Known (learning-core design §4.3)
		top.add_child(UI.num("%d %%" % int(round(float(S.get("knownShare", 0)) * 100)), 16, UI.INK))
		var lo := float(S.get("rankShare", 0)); var hi = S.get("nextShare", null)
		bar.min_value = lo; bar.max_value = float(hi) if hi != null else 1.0
		bar.value = float(S.get("knownShare", 0))
		v.add_child(bar)
		v.add_child(UI.label(("%d of %d Causes known · next: %s at %d %%" % [int(S.get("known", 0)), int(S.get("catalogSize", 0)), S.get("nextRank", ""), int(round(float(hi) * 100))]) if hi != null else "the highest rank", 12, UI.MUTED))
	else:
		top.add_child(UI.num("%d XP" % int(S.get("xp", 0)), 16, UI.INK))
		var lo := float(S.get("rankXp", 0)); var hi = S.get("nextXp", null)
		bar.min_value = lo; bar.max_value = float(hi) if hi != null else lo + 1.0
		bar.value = float(S.get("xp", 0)) if hi != null else bar.max_value
		v.add_child(bar)
		v.add_child(UI.label(("next: %s at %d XP" % [S.get("nextRank", ""), int(hi)]) if hi != null else "the highest rank", 12, UI.MUTED))
	p.tooltip_text = String(S.get("rankLine", ""))
	p.size_flags_vertical = Control.SIZE_SHRINK_END
	return p

# ------------------------------------------------------------------ pouring
## Starts a pour unless one is already running (no double pours). owner = the screen that shows it.
static func start_pour(shell, req: Dictionary, owner: String) -> void:
	if String(shell.state.get("tp_view", "")) == "pouring": return
	var id: int = Sim.PourStart(JSON.stringify(req))
	if id == 0: shell.notify("Could not pour: " + (String(Sim.LastError()).left(160) if String(Sim.LastError()) != "" else "the game data did not load.")); return
	shell.state["tp_job"] = id
	shell.state["tp_view"] = "pouring"
	shell.state["tp_owner"] = owner
	shell.state["tp_req"] = req
	for k in ["tp_session", "tp_answers", "tp_result", "tp_glass", "tp_anim_done", "tp_conf_warned"]: shell.state.erase(k)
	if shell.sfx: shell.sfx.play("pour")
	shell.show_screen(owner)

static func reset(shell) -> void:
	Sim.PourDrop()
	for k in ["tp_job", "tp_view", "tp_owner", "tp_req", "tp_session", "tp_answers", "tp_result", "tp_glass", "tp_anim_done", "tp_conf_warned"]: shell.state.erase(k)

## "Pouring…" with a poll timer: when the Flight is ready the owner screen re-renders with the answer view.
static func pouring_view(shell, owner: String) -> Control:
	var p: Array = UI.panel("", "")
	var c := CenterContainer.new(); c.custom_minimum_size = Vector2(0, 280); p[1].add_child(c)
	var v := UI.vbox(14); c.add_child(v)
	var req: Dictionary = shell.state.get("tp_req", {})
	var what := "a Flight" if String(req.get("kind", "")) == "stand" else ("today's session" if String(req.get("kind", "")) == "session" else "your glass")
	var l := UI.head("Pouring %s…" % what, 30, UI.GOLD); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(l)
	var s := UI.label("The simulation is growing and making the Wine from that year's real weather. This takes a moment.", 16, UI.INK2, null, true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; s.custom_minimum_size = Vector2(520, 0); v.add_child(s)
	var cancel := UI.button("Cancel", false, 15)
	cancel.pressed.connect(func(): reset(shell); shell.show_screen(owner))
	var cc := CenterContainer.new(); cc.add_child(cancel); v.add_child(cc)
	var timer := Timer.new(); timer.wait_time = 0.2; timer.autostart = true
	timer.timeout.connect(func(): poll(shell, owner))
	p[0].add_child(timer)
	return p[0]

static func poll(shell, owner: String) -> void:
	if String(shell.state.get("tp_view", "")) != "pouring": return
	var id := int(shell.state.get("tp_job", 0))
	var st: String = Sim.PourStatus(id)
	if st == "pouring": return
	if st == "ready":
		var S = JSON.parse_string(Sim.PourResult(id))
		if not (S is Dictionary) or not S.has("glasses"):
			reset(shell); shell.notify("The pour went wrong: " + String(Sim.LastError()).left(160)); shell.show_screen(owner); return
		var wines := []
		for g in S["glasses"]: wines.append({})
		var entries := []
		for e in S.get("entries", []): entries.append({"answers": [], "confidence": []})
		shell.state["tp_session"] = S
		shell.state["tp_answers"] = {"wines": wines, "quiz": {}, "quizConfidence": {}, "entries": entries}
		shell.state["tp_glass"] = 0
		shell.state["tp_view"] = "answer"
		if shell.sfx: shell.sfx.play("clink")
	else:
		reset(shell)
		if st.begins_with("failed"): shell.notify("Could not pour: " + st.substr(8).left(160))
	if shell.current == owner: shell.show_screen(owner)

# ------------------------------------------------------------------ what the player sees
static func colour_of(sheet: Dictionary) -> Color:   # fallback when a wine carries no glassColour
	var A: Dictionary = sheet.get("appearance", {})
	var base: Color = {"lemon-green": Color("e4e8a2"), "lemon": Color("ecdf8e"), "gold": Color("e0b84e"), "amber": Color("c3822c"),
		"purple": Color("4e1a3f"), "ruby": Color("851a2a"), "garnet": Color("86352a"), "tawny": Color("9a5a2a")}.get(String(A.get("colour", "")), Color("d8c889"))
	var k: float = {"pale": 0.5, "medium": 0.2, "deep": 0.0}.get(String(A.get("intensity", "")), 0.2)
	return base.lerp(Color("f7f3e6"), k)

## A wine glass drawn in the Wine's colour (presentation of the sheet's appearance terms).
static func glass(W: Dictionary, size := 1.0) -> Control:
	var v := UI.vbox(0); v.alignment = BoxContainer.ALIGNMENT_CENTER
	var bowl := Panel.new()
	var st := StyleBoxFlat.new(); st.bg_color = Color(String(W["glassColour"])) if W.has("glassColour") else colour_of(W.get("sheet", W))
	st.corner_radius_bottom_left = int(44 * size); st.corner_radius_bottom_right = int(44 * size)
	st.corner_radius_top_left = int(6 * size); st.corner_radius_top_right = int(6 * size)
	st.border_width_top = int(10 * size); st.border_color = Color(1, 1, 1, 0.10)
	bowl.add_theme_stylebox_override("panel", st)
	bowl.custom_minimum_size = Vector2(88, 84) * size
	var cb := CenterContainer.new(); cb.add_child(bowl); v.add_child(cb)
	var stem := ColorRect.new(); stem.color = Color(1, 1, 1, 0.25); stem.custom_minimum_size = Vector2(5, 34) * size
	var cs := CenterContainer.new(); cs.add_child(stem); v.add_child(cs)
	var base := ColorRect.new(); base.color = Color(1, 1, 1, 0.25); base.custom_minimum_size = Vector2(52, 5) * size
	var cf := CenterContainer.new(); cf.add_child(base); v.add_child(cf)
	return v

static func _sheet_view(W: Dictionary, parts: Array) -> Control:
	var S: Dictionary = W["sheet"]
	var v := UI.vbox(10)
	if "appearance" in parts:
		var A: Dictionary = S["appearance"]
		var h := UI.hbox(18); v.add_child(h)
		h.add_child(glass(W, 0.8))
		var av := UI.vbox(4); av.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(av)
		av.add_child(UI.label("Appearance", 14, UI.GOLD, UI.f_body_b))
		av.add_child(UI.kv("Clarity", String(A["clarity"])))
		av.add_child(UI.kv("Intensity", String(A["intensity"])))
		av.add_child(UI.kv("Colour", String(A["colour"])))
		var obs: Array = S.get("observations", [])
		if obs.size() > 0:
			var terms := []
			for o in obs: terms.append(String(o["term"]) if o is Dictionary else String(o))
			av.add_child(UI.kv("Other", ", ".join(terms)))
	if "nose" in parts:
		var N: Dictionary = S["nose"]
		v.add_child(UI.label("Nose", 14, UI.GOLD, UI.f_body_b))
		v.add_child(UI.kv("Condition", String(N["condition"])))
		v.add_child(UI.kv("Intensity", String(N["intensity"])))
		v.add_child(UI.kv("Development", String(N["development"])))
		for f in S.get("faults", []): v.add_child(UI.label("⚠ " + String(f), 14, UI.CRIT, null, true))
		for a in S["aromas"]:
			v.add_child(UI.kv(String(a["family"]), "%s  (%s)" % [a["terms"], a["intensity"]]))
		if S.get("simple", false): v.add_child(UI.kv("Overall", "simple: few aromas, all from the grape"))
		if String(S.get("fruitRipeness", "")) != "": v.add_child(UI.kv("Fruit ripeness", String(S["fruitRipeness"])))
	if "palate" in parts:
		v.add_child(UI.label("Palate", 14, UI.GOLD, UI.f_body_b))
		for p in S["palate"]: v.add_child(UI.kv(String(p["attribute"]), String(p["level"])))
		var fl: Array = S.get("flavours", [])
		if fl.size() > 0: v.add_child(UI.kv("Flavours", ", ".join(fl)))
	return v

static func _context_view(W: Dictionary, full: bool) -> Control:
	var C: Dictionary = W["context"]
	var v := UI.vbox(6)
	if C.get("producer") != null: v.add_child(UI.kv("Producer", str(C["producer"])))
	v.add_child(UI.kv("Site", "%s, %s" % [C["plotName"], C["regionName"]]))
	v.add_child(UI.kv("Grape", String(C["variety"])))
	if full:
		v.add_child(UI.kv("Vintage", str(int(C["vintage"]))))
		v.add_child(UI.label("The season", 14, UI.GOLD, UI.f_body_b))
		v.add_child(UI.kv("Growing-degree days", "%d  (April–October, above 10 °C)" % int(C["gdd"])))
		v.add_child(UI.kv("Summer maximum", "%.1f °C mean daily maximum, June–August" % float(C["summerTmax"])))
		if float(C["frostLoss"]) >= 1: v.add_child(UI.kv("Spring frost", "%d %% of the young shoots killed" % int(C["frostLoss"]), "", UI.SERIOUS))
		v.add_child(UI.kv("Rain before harvest", "%d mm in the three weeks before picking" % int(C["harvestRain"])))
		v.add_child(UI.label("Harvest and cellar", 14, UI.GOLD, UI.f_body_b))
		v.add_child(UI.kv("Picked", "%s at %d °Oe, TA %.1f g/L, pH %.2f" % [C["harvestDate"], int(C["harvestOe"]), float(C["harvestTa"]), float(C["harvestPh"])]))
		v.add_child(UI.kv("Yield", "%d hL/ha" % int(C["yield"])))
		v.add_child(UI.kv("Winemaking", String(C["styleLabel"])))
		v.add_child(UI.kv("Tasted", "%s years after the harvest" % str(C["ageYears"])))
	return v

## What an exercise shows before the player answers.
static func shown_panel(G: Dictionary, exercise: String, blind := false) -> Control:
	var W: Dictionary = G["wine"]
	var p: Array = UI.panel("What you have in front of you", "")
	match exercise:
		"conclusions": p[1].add_child(_sheet_view(W, ["appearance", "nose", "palate"]))
		"cause":
			p[1].add_child(UI.label("Predict the palate from the site, the season and the winemaking.", 14, UI.INK2, null, true))
			p[1].add_child(_context_view(W, true))
		"identify":
			p[1].add_child(UI.label("A blind glass: the Tasting sheet without the label.", 14, UI.INK2, null, true))
			p[1].add_child(_sheet_view(W, ["appearance", "nose", "palate"]))
		_:
			var h := UI.hbox(20); p[1].add_child(h)
			h.add_child(glass(W, 1.0))
			var lv := UI.vbox(6); lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(lv)
			lv.add_child(UI.label("The label says", 14, UI.GOLD, UI.f_body_b))
			lv.add_child(_context_view(W, false))
			lv.add_child(UI.kv("Vintage", "?" if blind or W["context"].get("vintage") == null else str(int(W["context"]["vintage"]))))
			p[1].add_child(UI.label("Name the colour you see, then predict the nose and palate from what you know of the grape, the site and the vintage.", 14, UI.INK2, null, true))
	return p[0]

# ------------------------------------------------------------------ answer pickers
const LABELS := {"clarity": "Clarity", "colourIntensity": "Colour intensity", "colour": "Colour", "noseIntensity": "Nose intensity",
	"development": "Development", "aromas": "Aroma families", "sweetness": "Sweetness", "acidity": "Acidity", "tannin": "Tannin",
	"alcohol": "Alcohol", "body": "Body", "flavourIntensity": "Flavour intensity", "finish": "Finish", "quality": "Quality",
	"readiness": "Readiness", "fruitRipeness": "Fruit ripeness", "flavours": "Flavour characteristics", "variety": "Grape variety", "region": "Region", "climate": "Vintage: cool, moderate or warm"}

static func _answers(shell, gi: int) -> Dictionary:
	var A: Dictionary = shell.state.get("tp_answers", {"wines": [], "quiz": {}})
	while A["wines"].size() <= gi: A["wines"].append({})
	return A["wines"][gi]

static func answered(shell, gi: int, G: Dictionary) -> int:
	var a := _answers(shell, gi)
	var n := 0
	for k in G["keys"]:
		var key := String(k)
		if key.begins_with("blic."):
			if a.get("blic", {}).has(key.substr(5)): n += 1
		elif key in ["aromas", "flavours"]:
			if a.get(key, []).size() > 0: n += 1
		elif String(a.get(key, "")) != "": n += 1
	return n

## The pickers for one glass: a row per item in the sheet's order, options from the model's own vocabulary.
static func pickers(shell, owner: String, gi: int, G: Dictionary) -> Control:
	var v := UI.vbox(10)
	var a := _answers(shell, gi)
	var O: Dictionary = G["options"]
	for k in G["keys"]:
		var key := String(k)
		var row := UI.hbox(12)
		var name: String = LABELS.get(key, key.substr(5) if key.begins_with("blic.") else key)
		var nl := UI.label(name, 15, UI.INK2); nl.custom_minimum_size = Vector2(190, 0); nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(nl)
		if key.begins_with("blic."):
			var crit := key.substr(5)
			var cur = a.get("blic", {}).get(crit, null)
			var chosen := "" if cur == null else ("met" if cur else "not met")
			var set_blic := func(o):
				var bl: Dictionary = a.get("blic", {}); bl[crit] = (o == "met"); a["blic"] = bl; shell.show_screen(owner)
			row.add_child(UI.segmented(["met", "not met"], chosen, set_blic, 110))
		elif key in ["aromas", "flavours"]:
			var flow := HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 6); flow.add_theme_constant_override("v_separation", 6)
			flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var picked: Array = a.get(key, [])
			for f in O.get(key, []):
				var fam := String(f)
				var on := fam in picked
				var b := UI.button(("✓ " if on else "") + fam, false, 14)
				if on:
					b.add_theme_stylebox_override("normal", UI.sb(UI.GOLD.darkened(0.62), 4, UI.GOLD, 1, 10))
					b.add_theme_color_override("font_color", UI.GOLD.lightened(0.35))
				var mk := key
				b.pressed.connect(func():
					var cur: Array = a.get(mk, [])
					if fam in cur: cur.erase(fam)
					else: cur.append(fam)
					a[mk] = cur; shell.show_screen(owner))
				flow.add_child(b)
			row.add_child(flow)
		else:
			var opts: Array = O.get(key, [])
			var long := false
			for o in opts: long = long or String(o).length() > 20
			var chosen := String(a.get(key, ""))
			var pick := func(o): a[key] = o; shell.show_screen(owner)
			if long:
				var col := UI.vbox(4)
				for o in opts:
					var b := UI.button(String(o), false, 14)
					b.alignment = HORIZONTAL_ALIGNMENT_LEFT
					if String(o) == chosen:
						b.add_theme_stylebox_override("normal", UI.sb(UI.GOLD.darkened(0.62), 4, UI.GOLD, 1, 10))
						b.add_theme_color_override("font_color", UI.GOLD.lightened(0.35))
					b.pressed.connect(pick.bind(String(o)))
					col.add_child(b)
				row.add_child(col)
			else:
				var flow := HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 4); flow.add_theme_constant_override("v_separation", 4)
				flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				flow.add_child(UI.segmented(opts, chosen, pick))
				row.add_child(flow)
		var done := false
		if key.begins_with("blic."): done = a.get("blic", {}).has(key.substr(5))
		elif key in ["aromas", "flavours"]: done = a.get(key, []).size() > 0
		else: done = String(a.get(key, "")) != ""
		if done:
			var conf: Dictionary = a.get("confidence", {})
			var set_conf := func(c: int): conf[key] = c; a["confidence"] = conf; shell.show_screen(owner)
			row.add_child(confidence_row(int(conf.get(key, 0)), set_conf))
		v.add_child(row)
	return v

const CONF := ["guess", "think so", "sure"]

## Commit before the reveal: how sure are you? One tap, shown only once an answer is picked (learning-core design §5).
static func confidence_row(current: int, on_pick: Callable) -> Control:
	var h := UI.hbox(2)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in 3:
		var b := UI.button(CONF[i], false, 13)
		b.custom_minimum_size = Vector2(68, 30)
		if current == i + 1:
			b.add_theme_stylebox_override("normal", UI.sb(UI.SEQ.darkened(0.55), 4, UI.SEQ, 1, 8))
			b.add_theme_color_override("font_color", UI.SEQ.lightened(0.4))
		elif current == 0:
			b.add_theme_color_override("font_color", UI.MUTED)
		b.tooltip_text = "How sure are you? Being honest here is what makes the review schedule work."
		var c := i + 1
		b.pressed.connect(func(): on_pick.call(c))
		h.add_child(b)
	return h

## Answers picked without a Confidence (the first Mark press reminds once; the second marks anyway).
static func missing_confidence(shell) -> int:
	var A: Dictionary = shell.state.get("tp_answers", {})
	var n := 0
	for a in A.get("wines", []):
		var conf: Dictionary = a.get("confidence", {})
		for k in a.keys():
			if k in ["confidence", "hints"]: continue
			if k == "blic":
				for crit in a["blic"].keys(): if not conf.has("blic." + crit): n += 1
			elif k in ["aromas", "flavours"]:
				if a[k].size() > 0 and not conf.has(k): n += 1
			elif String(a[k]) != "" and not conf.has(k): n += 1
	for t in A.get("quiz", {}).keys(): if not A.get("quizConfidence", {}).has(t): n += 1
	for e in A.get("entries", []):
		for j in e.get("answers", []).size():
			if str(e["answers"][j]) != "" and (j >= e.get("confidence", []).size() or int(e["confidence"][j]) == 0): n += 1
	return n

## Hint button: shows the glass's hint line and costs half a mark.
static func hint_row(shell, owner: String, gi: int, G: Dictionary) -> Control:
	var a := _answers(shell, gi)
	var h := UI.hbox(12)
	if int(a.get("hints", 0)) > 0:
		h.add_child(UI.label("Hint: " + String(G.get("hint", "")), 15, UI.WARN, null, true))
		h.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		var b := UI.button("Show a hint  (costs ½ mark)", false, 14)
		b.pressed.connect(func(): a["hints"] = 1; shell.show_screen(owner))
		h.add_child(b)
	return h

static func mark(shell, owner: String) -> void:
	var missing := missing_confidence(shell)
	if missing > 0 and not shell.state.get("tp_conf_warned", false):
		shell.state["tp_conf_warned"] = true
		shell.notify("%d answer%s still need%s a guess / think so / sure. Press Mark again to go on without." % [missing, "" if missing == 1 else "s", "s" if missing == 1 else ""])
		return
	var raw: String = Sim.PracticeMark(JSON.stringify(shell.state.get("tp_answers", {})))
	var R = JSON.parse_string(raw)
	if not (R is Dictionary) or not (R.has("glasses") or R.has("entries")):
		shell.notify("Marking failed: " + String(Sim.LastError()).left(160)); return
	shell.state["tp_result"] = R
	shell.state["tp_view"] = "reveal"
	shell.state.erase("tp_lobby")
	if shell.sfx: shell.sfx.play("medal" if R.get("medal") != null or R.get("rankUp", false) else "confirm")
	shell.show_screen(owner)

# ------------------------------------------------------------------ reveal
static func verdict(score: float) -> Array:
	if score >= 1.0: return ["✓", UI.GOOD, "right"]
	if score > 0.0: return ["½" if is_equal_approx(score, 0.5) else "≈", UI.WARN, "close"]
	return ["✗", UI.CRIT, "wrong"]

## One reveal row per item, styled by the four cases of commit-then-reveal (learning-core design §5): a surprise card when you
## were sure and wrong, the full explanation when you guessed right, a short confirmation (with the "why" one tap away) when you
## were sure and right. The "because" shows for right answers too. Rows fade in one by one the first time.
static func item_rows(items: Array, animate: bool, delay0 := 0.0, label_w := 220.0) -> Control:
	var v := UI.vbox(6)
	var i := 0
	for it in items:
		var case_: String = String(it.get("case", "no-confidence"))
		var r := UI.vbox(2)
		var wrap: Control = r
		if case_ == "sure-wrong":
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", UI.sb(Color(UI.CRIT, 0.10), 6, UI.CRIT, 1, 10))
			card.add_child(r); wrap = card
			r.add_child(UI.label("Surprise: you were sure. This is the one to remember; it comes back tomorrow.", 13, UI.SERIOUS, UI.f_body_b))
		var h := UI.hbox(12); r.add_child(h)
		var vd := verdict(float(it["score"]))
		var vl := UI.label(vd[0], 18, vd[1], UI.f_body_b); vl.custom_minimum_size = Vector2(24, 0); h.add_child(vl)
		var nl := UI.label(String(it["label"]), 15, UI.INK2, null, true); nl.custom_minimum_size = Vector2(label_w, 0); h.add_child(nl)
		var yours := String(it["yours"])
		var conf := int(it.get("confidence", 0))
		var yl := UI.label("you: " + (yours if yours != "" else "—") + ((" (%s)" % CONF[conf - 1]) if conf > 0 and yours != "" else ""), 15, vd[1] if yours != "" else UI.MUTED, null, true)
		yl.custom_minimum_size = Vector2(280, 0); h.add_child(yl)
		var al := UI.label(String(it["actual"]), 15, UI.INK, UI.f_body_b, true); al.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(al)
		var because := String(it["because"])
		if because != "":
			var bl := UI.label("because " + because, 13, UI.MUTED if case_ != "guess-right" else UI.INK2, null, true)
			bl.custom_minimum_size = Vector2(700, 0)
			var m := MarginContainer.new(); m.add_theme_constant_override("margin_left", 36); m.add_child(bl)
			if case_ == "guess-right": r.add_child(UI.label("A guess, and right: here is why, so next time you know.", 13, UI.GOOD))
			if case_ == "sure-right":
				m.visible = false
				var why := UI.button("why ▸", false, 13); why.custom_minimum_size = Vector2(70, 26)
				why.pressed.connect(func(): m.visible = not m.visible; why.text = "why ▾" if m.visible else "why ▸")
				h.add_child(why)
			r.add_child(m)
		if animate:
			wrap.modulate.a = 0.0
			var d := delay0 + 0.07 * i
			var fade := func():
				var tw := wrap.create_tween(); tw.tween_interval(d); tw.tween_property(wrap, "modulate:a", 1.0, 0.25)
			wrap.tree_entered.connect(fade, CONNECT_ONE_SHOT)
		v.add_child(wrap)
		i += 1
	return v

## The end-of-Flight recap: only the misses, a few seconds later (a delayed second look; research track A §3).
static func recap_panel(R: Dictionary) -> Control:
	var miss: Array = R.get("recap", [])
	if miss.is_empty(): return null
	var p: Array = UI.panel("Worth another look", "%d to remember" % miss.size())
	for it in miss:
		var h := UI.hbox(10)
		var l := UI.label(String(it["label"]), 14, UI.INK2, null, true); l.custom_minimum_size = Vector2(260, 0); h.add_child(l)
		var a := UI.label(String(it["actual"]), 14, UI.INK, UI.f_body_b, true); a.custom_minimum_size = Vector2(220, 0); h.add_child(a)
		var b := UI.label(String(it["because"]), 13, UI.MUTED, null, true); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(b)
		p[1].add_child(h)
	p[1].add_child(UI.label("These come back in the next days with new Wines.", 13, UI.MUTED))
	return p[0]

static func note_panel(note) -> Control:
	if note == null: return null
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sb(Color("2a2a22"), 6, Color("8a7a4a"), 1, 14))
	var v := UI.vbox(6); p.add_child(v)
	v.add_child(UI.label("What really happened", 14, UI.GOLD, UI.f_body_b))
	v.add_child(UI.label(String(note["note"]), 15, UI.INK, null, true))
	var src := []
	for s in note["sources"]: src.append(String(s["title"]))
	v.add_child(UI.label("Source: " + "; ".join(src), 12, UI.MUTED, null, true))
	return p

## Score, XP, medal, rank-up and streak banner at the top of a reveal.
static func result_banner(R: Dictionary, stand := false) -> Control:
	var p := PanelContainer.new()
	var medal = R.get("medal", null)
	p.add_theme_stylebox_override("panel", UI.sb(UI.RAISED, 8, MEDAL_COL.get(str(medal), UI.GOLD) if medal != null else UI.LINE, 2 if medal != null else 1, 18))
	var h := UI.hbox(28); p.add_child(h)
	h.add_child(UI.tile("Your marks", "%s / %d" % [_n(float(R["total"])), int(R["max"])], "%d %%" % int(round(float(R["percent"])))))
	var Sm: Dictionary = R["summary"]
	if Sm.get("byKnown", false):
		h.add_child(UI.tile("Causes known", "%d / %d" % [int(Sm.get("known", 0)), int(Sm.get("catalogSize", 0))], "%s · +%d XP" % [Sm.get("rank", ""), int(R.get("xpGained", 0))], UI.GOLD))
	else:
		h.add_child(UI.tile("Experience", "+%d XP" % int(R.get("xpGained", 0)), String(Sm.get("rank", "")), UI.GOLD))
	if stand:
		var best = R.get("bestMedal", null)
		h.add_child(UI.tile("Medal", String(medal).capitalize() if medal != null else "none this time",
			("best so far: %s" % String(best).capitalize()) if best != null else "50 % for bronze, 70 % silver, 85 % gold", MEDAL_COL.get(str(medal), UI.INK2)))
	if int(R.get("bestStreak", 0)) >= 3: h.add_child(UI.tile("Best streak", "%d in a row" % int(R["bestStreak"]), "items right one after another", UI.GOOD))
	var extra := UI.vbox(4); extra.custom_minimum_size = Vector2(300, 0); extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(extra)
	if R.get("rankUp", false): extra.add_child(UI.label("Rank up: you are now a %s!" % R["summary"]["rank"], 17, UI.GOLD, UI.f_body_b, true))
	if R.get("tierUp", false): extra.add_child(UI.label("New stands are open at the Wine Fair.", 16, UI.GOOD, UI.f_body_b, true))
	if int(R.get("knownGained", 0)) > 0: extra.add_child(UI.label("+%d Cause%s now known for good." % [int(R["knownGained"]), "" if int(R["knownGained"]) == 1 else "s"], 15, UI.GOOD, UI.f_body_b, true))
	for c in R.get("newCardNames", []): extra.add_child(UI.label("New Vintage card: " + String(c), 14, UI.SEQ, null, true))
	return p

static func _n(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, round(x)) else "%.1f" % x
