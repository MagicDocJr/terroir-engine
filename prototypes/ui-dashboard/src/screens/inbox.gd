# PROTOTYPE — Inbox: Alerts and messages from staff and the Mentor; reading pane with a "Why?" explanation and actions.
extends RefCounted

const UI := preload("res://src/ui.gd")
const ROLE_COL := {"mentor": Color("c9b8e8"), "cellar": Color("9fb7c9"), "vineyard": Color("8fbf8a"), "weather": Color("aeb5b9"), "estate": Color("aeb5b9")}

static func build(D: Dictionary, S) -> Control:
	var msgs: Array = D["inbox"]
	var sel: int = S.state.get("inbox_sel", 1)
	var why_open: bool = S.state.get("inbox_why", S.capture)
	var v := UI.vbox(16)
	var alerts := 0
	for m in msgs:
		if m["alert"]: alerts += 1
	v.add_child(UI.page_header("Inbox", "%d Alerts need a decision before time can run on. Everything else is for information." % alerts))
	var row := UI.hbox(18); row.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(row)
	# ---- list
	var lp := UI.panel("Messages", "%d messages" % msgs.size(), 6)
	lp[0].custom_minimum_size = Vector2(600, 0)
	row.add_child(lp[0])
	for m in msgs:
		lp[1].add_child(_list_item(m, int(m["id"]) == sel, S))
	# ---- reading pane
	var cur: Dictionary = msgs[0]
	for m in msgs:
		if int(m["id"]) == sel: cur = m
	var rp := PanelContainer.new(); rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rp.add_theme_stylebox_override("panel", UI.sb(UI.SURFACE, 6, UI.LINE, 1, 30))
	row.add_child(rp)
	var rv := UI.vbox(16); rp.add_child(rv)
	var hdr := UI.hbox(12)
	hdr.add_child(UI.label(String(cur["from"]), 16, ROLE_COL[cur["role"]], UI.f_body_b))
	if cur["alert"]: hdr.add_child(UI.status("serious" if cur["priority"] == "high" else "warn", "Alert"))
	hdr.add_child(UI.spacer())
	hdr.add_child(UI.label(String(cur["time"]), 15, UI.MUTED))
	rv.add_child(hdr)
	var subj := UI.head(String(cur["subject"]), 30, UI.INK); subj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; rv.add_child(subj)
	if String(cur["body"]) != "":
		var body := UI.label(String(cur["body"]), 18, UI.INK, UI.f_body, true)
		body.custom_minimum_size = Vector2(0, 0)
		rv.add_child(body)
	if String(cur["why"]) != "":
		var wb := UI.button("Hide the explanation" if why_open else "Why? Explain it")
		wb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		wb.pressed.connect(func(): S.state["inbox_why"] = not why_open; S.rerender())
		rv.add_child(wb)
		if why_open:
			var box := PanelContainer.new()
			var st := UI.sb(UI.SUNKEN, 5, Color(0, 0, 0, 0), 0, 20); st.border_color = UI.GOLD; st.border_width_left = 3
			box.add_theme_stylebox_override("panel", st)
			var bv := UI.vbox(6); box.add_child(bv)
			bv.add_child(UI.head("Why this matters", 18, UI.INK))
			bv.add_child(UI.label(String(cur["why"]), 17, UI.INK2, UI.f_body, true))
			bv.add_child(UI.label("Normal mode shows these explanations at WSET Level 3 depth.", 13, UI.MUTED))
			rv.add_child(box)
	if (cur["actions"] as Array).size() > 0:
		rv.add_child(UI.spacer(false, 6))
		rv.add_child(UI.head("Your decision", 18, UI.INK))
		var ah := UI.hbox(10)
		var first := true
		for a in cur["actions"]:
			var b := UI.button(String(a), first, 16); b.custom_minimum_size = Vector2(0, 44)
			b.pressed.connect(func(): S.notify("Decision recorded: %s (prototype)." % a))
			ah.add_child(b)
			first = false
		rv.add_child(ah)
	rv.add_child(UI.spacer(false))
	if cur["role"] == "mentor":
		rv.add_child(UI.label("Klaus retires after your first Wine is bottled. From then on, advice comes from your own staff.", 14, UI.MUTED, null, true))
	return v

static func _list_item(m: Dictionary, selected: bool, S) -> Control:
	var p := PanelContainer.new()
	var st := UI.sb(UI.RAISED if selected else Color(0, 0, 0, 0), 4, Color(0, 0, 0, 0), 0, 14)
	st.border_color = UI.GOLD if selected else (UI.SERIOUS if m["alert"] else Color(0, 0, 0, 0)); st.border_width_left = 3
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_STOP; p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: S.state["inbox_sel"] = int(m["id"]); S.state["inbox_why"] = false; S.rerender())
	var v := UI.vbox(3); p.add_child(v)
	var h := UI.hbox(8)
	h.add_child(UI.label(String(m["from"]), 14, ROLE_COL[m["role"]], UI.f_body_b))
	if m["alert"]: h.add_child(UI.label("▲ Alert", 13, UI.SERIOUS))
	h.add_child(UI.spacer())
	h.add_child(UI.label(String(m["time"]), 13, UI.MUTED))
	v.add_child(h)
	var s := UI.label(String(m["subject"]), 16, UI.INK if selected or m["alert"] else UI.INK2, UI.f_body_b if m["alert"] else null, true)
	v.add_child(s)
	return p
