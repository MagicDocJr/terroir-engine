# The learn drawer (learning-core design §7): a card slides in from the right, never a modal; the choice behind it stays visible
# and usable. One fixed structure: what it is (with a visual that earns its place), what it does (the cause chains to the
# glass), on this site (from the player's own data), when to choose what, what the exam wants, a check question that adds the
# card's Causes to the review queue, and the sources. A card whose Causes are all Known opens brief. ✕ or Esc closes it;
# another Learn link replaces it; changing screens closes it.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const V := preload("res://src/ui/learn_visuals.gd")
const T := preload("res://src/ui/tasting_ui.gd")

## A small "Learn" link for a choice row; a gold dot until the card has been opened once.
static func link(shell, card_id: String, ctx := {}) -> Control:
	var seen: Array = shell.learn_seen()
	var b := UI.button(("● " if not (card_id in seen) else "") + "Learn", false, 13)
	b.flat = true
	b.add_theme_color_override("font_color", UI.GOLD)
	b.add_theme_color_override("font_hover_color", UI.GOLD.lightened(0.3))
	b.tooltip_text = "Open the learn card: what this choice does to the wine, and why."
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): shell.open_learn(card_id, ctx))
	return b

static func build(shell, J: Dictionary) -> Control:
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# no dim layer: the screen behind stays fully usable (the choice can be made with the card open); a soft edge marks the drawer
	var edge := ColorRect.new(); edge.color = Color(0, 0, 0, 0.35); edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.anchor_left = 0.58; edge.anchor_right = 0.58; edge.anchor_bottom = 1.0; edge.offset_left = -10; edge.offset_right = 0
	root.add_child(edge)
	var panel := PanelContainer.new()
	var st := UI.sb(UI.SURFACE, 0, UI.GOLD.darkened(0.25), 0, 22); st.border_width_left = 3
	panel.add_theme_stylebox_override("panel", st)
	panel.anchor_left = 0.58; panel.anchor_right = 1.0; panel.anchor_top = 0.0; panel.anchor_bottom = 1.0
	panel.offset_left = 0; panel.offset_right = 0
	root.add_child(panel)
	var v := UI.vbox(14)
	var sc := UI.scroll(v); panel.add_child(sc)
	var brief: bool = String(J.get("depth", "full")) == "brief" and not shell.state.get("learn_full", false)
	# header
	var head := UI.hbox(10); v.add_child(head)
	var hv := UI.vbox(2); hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(hv)
	hv.add_child(UI.label("LEARN", 12, UI.GOLD, UI.f_body_b))
	hv.add_child(UI.head(String(J["title"]), 28, UI.INK))
	var x := UI.button("✕", false, 16); x.tooltip_text = "Close (Esc)"; x.pressed.connect(func(): shell.close_learn()); head.add_child(x)
	if brief: v.add_child(UI.label("You know this one: here is the short version.", 13, UI.GOOD))
	# visual
	var vis = V.build(shell, J)
	if vis != null and not brief: v.add_child(vis)
	# what it is
	v.add_child(_section("What it is"))
	v.add_child(UI.label(String(J["what"]), 16, UI.INK, null, true))
	# what it does
	v.add_child(_section("What it does in the wine"))
	for ch in J["chains"]:
		var box := PanelContainer.new(); box.add_theme_stylebox_override("panel", UI.sb(UI.RAISED, 6, UI.LINE, 1, 12))
		var cv := UI.vbox(4); box.add_child(cv)
		if ch.get("title") != null: cv.add_child(UI.label(String(ch["title"]), 14, UI.GOLD, UI.f_body_b))
		var steps: Array = ch["steps"]
		for i in steps.size():
			cv.add_child(UI.label(("" if i == 0 else "→ ") + String(steps[i]), 15, UI.INK if i == steps.size() - 1 else UI.INK2, UI.f_body_b if i == steps.size() - 1 else null, true))
		v.add_child(box)
	# on this site
	v.add_child(_section("On this site"))
	var sb := PanelContainer.new(); sb.add_theme_stylebox_override("panel", UI.sb(Color(UI.SEQ, 0.12), 6, UI.SEQ.darkened(0.2), 1, 12))
	sb.add_child(UI.label(String(J["site"]), 15, UI.INK, null, true)); v.add_child(sb)
	if brief:
		var more := UI.button("Show the full card", false, 14)
		more.pressed.connect(func(): shell.state["learn_full"] = true; shell.reopen_learn())
		v.add_child(more)
	else:
		v.add_child(_section("When to choose what"))
		v.add_child(UI.label(String(J["choose"]), 15, UI.INK2, null, true))
		v.add_child(_section("What the exam wants"))
		v.add_child(UI.label(String(J["exam"]), 15, UI.INK2, null, true))
		v.add_child(_check(shell, J))
	# sources and simplification
	var src := []
	for s in J["sources"]: src.append(String(s).replace(".md#", " · "))
	v.add_child(UI.label("Sources (docs/science): " + "; ".join(src), 12, UI.MUTED, null, true))
	if String(J.get("simplification", "")) != "": v.add_child(UI.label("Game simplification: " + String(J["simplification"]), 12, UI.MUTED, null, true))
	return root

static func _section(t: String) -> Control:
	return UI.label(t, 14, UI.GOLD, UI.f_body_b)

## Check yourself: one question, answered in place; a right or wrong answer both explain, and the card's Causes join the queue.
static func _check(shell, J: Dictionary) -> Control:
	var p: Array = UI.panel("Check yourself", "adds this to your review queue")
	var C: Dictionary = J["check"]
	p[1].add_child(UI.label(String(C["question"]), 16, UI.INK, UI.f_body_b, true))
	var answered := String(shell.state.get("learn_answer_" + String(J["id"]), ""))
	var conf := int(shell.state.get("learn_conf_" + String(J["id"]), 0))
	for o in C["options"]:
		var b := UI.button(String(o), false, 14); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var col := UI.INK2
		if answered != "":
			b.disabled = true
			if String(o) == String(C["answer"]): b.add_theme_stylebox_override("disabled", UI.sb(Color(UI.GOOD, 0.18), 4, UI.GOOD, 1, 10)); col = UI.GOOD
			elif String(o) == answered: b.add_theme_stylebox_override("disabled", UI.sb(Color(UI.CRIT, 0.15), 4, UI.CRIT, 1, 10)); col = UI.CRIT
			b.add_theme_color_override("font_disabled_color", col)
		var val := String(o)
		b.pressed.connect(func():
			if int(shell.state.get("learn_conf_" + String(J["id"]), 0)) == 0: shell.notify("First tap how sure you are: guess / think so / sure."); return
			shell.state["learn_answer_" + String(J["id"])] = val
			Sim.LearnCheck(String(J["id"]), val, int(shell.state.get("learn_conf_" + String(J["id"]), 0)))
			shell.reopen_learn())
		p[1].add_child(b)
	if answered == "":
		var h := UI.hbox(8); h.add_child(UI.label("How sure are you?", 13, UI.MUTED))
		var set_c := func(c: int): shell.state["learn_conf_" + String(J["id"])] = c; shell.reopen_learn()
		h.add_child(T.confidence_row(conf, set_c)); p[1].add_child(h)
	else:
		var right: bool = answered == String(C["answer"])
		p[1].add_child(UI.label(("Right. " if right else "Not quite. ") + String(C["why"]), 15, UI.GOOD if right else UI.SERIOUS, null, true))
	return p[0]
