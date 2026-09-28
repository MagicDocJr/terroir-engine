# The Tasks strip (tasks-in-3d design §5): the staff's open tasks for one place ("vineyard" on Plot & Blocks, "hall" on the
# Winery screen), each with its due date, the plan, "Do it in 3D", "Let the crew do it" and the options as buttons (the
# dashboard route). Everything shown comes from the snapshot's `tasks`; the choice goes back as the `task` command.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")

static func build(D: Dictionary, shell, where: String) -> Control:
	var list := []
	for t in D.get("tasks", []):
		if String(t.get("where", "")) == where: list.append(t)
	if list.is_empty(): return null
	var p: Array = UI.panel("Tasks", "from your staff · do them in 3D, here, or let the crew do them", 8)
	p[0].add_theme_stylebox_override("panel", UI.sb(Color("1d2418"), 6, UI.GOLD.darkened(0.35), 1, 14))
	for t in list:
		p[1].add_child(_row(t, shell))
	return p[0]

static func _row(t: Dictionary, shell) -> Control:
	# one line per task: what and where · due · the options (dashboard route) · Do it in 3D · Let the crew do it
	var id := str(int(t["id"]))
	var kind := String(t["kind"])
	var open := String(t["status"]) == "Open"
	var row := UI.hbox(10)
	var place := ("Lot %s" % t["lot"]) if kind == "CapManagement" else ("Block %s" % t["block"])
	var name_l := UI.label("%s · %s" % [t["title"], place], 15, UI.INK, UI.f_body_b)
	name_l.custom_minimum_size = Vector2(250, 0)
	name_l.tooltip_text = "Plan: %s" % t.get("planLabel", "")
	name_l.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name_l)
	if not open:
		var who: String = String({"3d": "you, at the vine", "dashboard": "you", "crew": "the crew, to the plan"}.get(String(t.get("decidedBy", "")), ""))
		var chosen := String(t.get("choice", ""))
		for o in t.get("options", []):
			if String(o["value"]) == chosen: chosen = String(o["label"])
		row.add_child(UI.label("%s — decided by %s · crew at work until %s" % [chosen, who, t.get("crewUntil", "")], 14, UI.GOOD))
		return row
	var left := int(t.get("daysLeft", 0))
	var due := UI.label("due %s · %s" % [t["due"], "today" if left <= 0 else "%d d" % left], 14, UI.WARN if left <= 3 else UI.INK2)
	due.custom_minimum_size = Vector2(130, 0)
	row.add_child(due)
	var labels := []
	var by_label := {}
	for o in t.get("options", []):
		labels.append(String(o["label"]))
		by_label[String(o["label"])] = o
	var late := CheckBox.new()
	late.text = "at véraison"
	late.button_pressed = str(t.get("planTiming", "")) == "Late"
	late.tooltip_text = "Remove the leaves around véraison instead of now; applies to the option you choose. Berries that grew in shade and are bared late sunburn more easily; early removal lets them acclimatise (Gambetta et al. 2021)."
	var plan_label := String(t.get("planLabel", ""))
	var seg := UI.segmented(labels, plan_label, func(x):
		var o: Dictionary = by_label[x]
		Sim.Command("task", id, "do", String(o["value"]), "Late" if late.button_pressed else "", "dashboard")
		shell.refresh()
		shell.notify("%s · %s: %s. The crew does the rest the same way." % [t["title"], place, x], true), 0)
	for c in seg.get_children():
		if c is Button:
			var o: Dictionary = by_label.get((c as Button).text, {})
			(c as Button).tooltip_text = String(o.get("why", ""))
	row.add_child(seg)
	if kind == "LeafRemoval": row.add_child(late)
	row.add_child(UI.spacer())
	var b3 := UI.button("Do it in 3D", true, 14)
	b3.pressed.connect(func(): shell.run_action("task3d", id))
	row.add_child(b3)
	var bc := UI.button("Crew", false, 14)
	bc.tooltip_text = "Let the crew do it to the plan (%s)" % plan_label
	bc.pressed.connect(func():
		Sim.Command("task", id, "delegate", "", "", "")
		shell.refresh()
		shell.notify("%s · %s: the crew does it to the plan (%s)." % [t["title"], place, plan_label], true))
	row.add_child(bc)
	return row
