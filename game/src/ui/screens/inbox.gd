# Inbox: messages from staff and the Mentor. Alerts stop time; every message explains why, and offers actions.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const Avatar := preload("res://src/ui/avatar.gd")

static func build(D: Dictionary, shell) -> Control:
	var msgs: Array = D.get("inbox", [])
	var v := UI.vbox(14)
	var unread := 0
	for m in msgs:
		if not m["read"]: unread += 1
	var filt: String = shell.state.get("inbox_filter", "All")
	var header_at := v.get_child_count()
	var shown := []
	for m in msgs:
		var role := String(m["role"]).to_lower()
		if filt == "Unread" and m["read"]: continue
		if filt == "Vineyard" and not ("vineyard" in role): continue
		if filt == "Cellar" and not ("cellar" in role): continue
		if filt == "Mentor" and not ("mentor" in role): continue
		shown.append(m)
	var sel_id := int(shell.state.get("inbox_sel", -1))
	var sel = null
	for m in shown:
		if int(m["id"]) == sel_id: sel = m
	# open on the OLDEST unread message, so a new player reads the welcome first and alerts in the order they happened
	if sel == null:
		for i in range(shown.size() - 1, -1, -1):
			if not shown[i]["read"]: sel = shown[i]; break
	if sel == null and shown.size() > 0: sel = shown[0]
	var next_unread = null
	if sel != null:
		for i in range(shown.size() - 1, -1, -1):
			if not shown[i]["read"] and shown[i]["id"] != sel["id"]: next_unread = shown[i]; break
	if sel != null and not sel["read"]:
		Sim.Command("read", str(int(sel["id"])), "", "", "", "")
		sel["read"] = true
		sel["_was_unread"] = true
		D["unreadAlerts"] = maxi(0, int(D.get("unreadAlerts", 0)) - (1 if sel["priority"] == "high" else 0))
		shell.call_deferred("_topbar_refresh_count")
	var hdr := UI.page_header("Inbox", "%d messages, %d unread. Alerts stop time until you've seen them." % [msgs.size(), unread - (1 if sel != null and sel.get("_was_unread", false) else 0)],
		[_mark_all_button(shell, unread), UI.segmented(["All", "Unread", "Vineyard", "Cellar", "Mentor"], filt, func(x): shell.state["inbox_filter"] = x; shell.show_screen("inbox"), 90)])
	v.add_child(hdr); v.move_child(hdr, header_at)
	# the Mentor's plan: open by default for the first steps, collapsible, hidden for good from its own button
	var OB = load("res://src/ui/onboarding.gd")
	var nxt: int = OB.next_step(D)
	if OB.enabled(D) and nxt >= 0 and shell.state.get("plan_open", nxt <= 4):
		v.add_child(OB.plan_panel(D, shell))
	var body := UI.hbox(16); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(body)
	# list
	var lp: Array = UI.panel("", "", 2)
	lp[0].custom_minimum_size = Vector2(560, 0)
	var list := UI.vbox(2)
	for m in shown:
		var is_sel: bool = sel != null and m["id"] == sel["id"]
		var c := PanelContainer.new()
		c.add_theme_stylebox_override("panel", UI.sb(UI.RAISED if is_sel else Color(0, 0, 0, 0), 4, UI.GOLD if is_sel else Color(0, 0, 0, 0), 1 if is_sel else 0, 12))
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var h := UI.hbox(10); c.add_child(h)
		var mark := "◆" if m["priority"] == "high" else ("●" if not m["read"] else "○")
		var mcol := UI.CRIT if m["priority"] == "high" and not m["read"] else (UI.GOLD if not m["read"] else UI.MUTED)
		var ml := UI.label(mark, 13, mcol); ml.custom_minimum_size = Vector2(16, 0); h.add_child(ml)
		h.add_child(Avatar.make(String(m.get("sender", "")), String(m["role"]), 40))
		var tv := UI.vbox(0); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top := UI.hbox(8)
		top.add_child(UI.label(String(m["from"]), 13, UI.INK2))
		if String(m["block"]) != "" and UI.BLOCK.has(String(m["block"])): top.add_child(UI.block_tag(String(m["block"]), 12))
		top.add_child(UI.spacer())
		top.add_child(UI.label(String(m["date"]), 13, UI.MUTED))
		tv.add_child(top)
		var subj := UI.label(String(m["subject"]), 16, UI.INK if not m["read"] else UI.INK2, UI.f_body_b if not m["read"] else null)
		subj.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; subj.clip_text = true
		tv.add_child(subj)
		h.add_child(tv)
		var id := int(m["id"])
		UI.on_click(c, func(): shell.state["inbox_sel"] = id; shell.show_screen("inbox"))
		list.add_child(c)
	if shown.is_empty(): list.add_child(UI.label("Nothing here.", 15, UI.MUTED))
	lp[1].add_child(UI.scroll(list))
	lp[1].size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(lp[0])
	# detail
	var dp: Array = UI.panel("", "", 14)
	dp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if sel != null:
		var dv := UI.vbox(14)
		var h := UI.hbox(12)
		h.add_child(Avatar.make(String(sel.get("sender", "")), String(sel["role"]), 56))
		h.add_child(UI.label(String(sel["from"]), 16, UI.INK2))
		h.add_child(UI.spacer())
		if sel["priority"] == "high": h.add_child(UI.chip("Alert", UI.CRIT))
		h.add_child(UI.label(String(sel["date"]), 15, UI.MUTED))
		dv.add_child(h)
		dv.add_child(UI.head(String(sel["subject"]), 28, UI.INK))
		var bl := UI.label(String(sel["body"]), 17, UI.INK, null, true); dv.add_child(bl)
		if String(sel["why"]) != "":
			var why: Array = UI.panel("Why", "", 6)
			why[0].add_theme_stylebox_override("panel", UI.sb(UI.SUNKEN, 6, UI.LINE, 1, 16))
			why[1].add_child(UI.label(String(sel["why"]), 15, UI.INK2, null, true))
			dv.add_child(why[0])
		var acts: Array = sel.get("actions", [])
		if acts.size() > 0:
			var ah := UI.hbox(10)
			for i in acts.size():
				var a: Dictionary = acts[i]
				var b := UI.button(String(a["label"]), i == 0, 16); b.custom_minimum_size = Vector2(0, 42)
				var act: String = a["action"]; var arg: String = a["arg"]
				b.pressed.connect(func(): shell.run_action(act, arg))
				ah.add_child(b)
			dv.add_child(ah)
		if next_unread != null:
			var nb := UI.button("Next unread ▸  %s" % String(next_unread["subject"]).left(48), false, 15)
			var nid := int(next_unread["id"])
			nb.pressed.connect(func(): shell.state["inbox_sel"] = nid; shell.show_screen("inbox"))
			dv.add_child(nb)
		dp[1].add_child(UI.scroll(dv))
	else:
		dp[1].add_child(UI.label("No messages.", 16, UI.MUTED))
	dp[1].size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(dp[0])
	return v

static func _mark_all_button(shell, unread: int) -> Button:
	var b := UI.button("Mark all read", false, 15)
	b.disabled = unread == 0
	b.pressed.connect(func(): shell.command("read", "all"); shell.notify("All messages marked as read."))
	return b
