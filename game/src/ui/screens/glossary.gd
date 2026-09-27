# Glossary: the game's terms, read from CONTEXT.md (the project's shared language), plus the controls.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")

static func build(_D: Dictionary, shell) -> Control:
	var v := UI.vbox(14)
	var hidden: bool = "plan_hidden" in _D.get("flags", [])
	var pb := UI.button("Show the Mentor's plan again" if hidden else "Show all screen intros again", false, 14)
	pb.pressed.connect(func():
		if hidden: shell.command("unflag", "plan_hidden")
		else:
			for f in _D.get("flags", []):
				if String(f).begins_with("intro_"): Sim.Command("unflag", String(f), "", "", "", "")
			shell.refresh()
		shell.notify("Done.", true))
	v.add_child(UI.page_header("Glossary", "The words the game uses, and what they mean here.", [pb]))
	var terms := _terms()
	var g := GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 16); g.add_theme_constant_override("v_separation", 16)
	for section in terms:
		var p: Array = UI.panel(section[0], "")
		p[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for t in section[1]:
			var h := UI.vbox(0)
			h.add_child(UI.label(t[0], 16, UI.GOLD, UI.f_body_b))
			h.add_child(UI.label(t[1], 14, UI.INK2, null, true))
			p[1].add_child(h)
		g.add_child(p[0])
	var k: Array = UI.panel("Controls", "")
	k[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for pair in [["1 – 9, 0", "switch screens"], ["Space", "advance one day"], ["P", "play / pause (time runs until the next Alert)"], ["Enter", "Continue until the next Alert"], ["Tab", "3D walkaround (Esc to leave)"], ["M", "sound on / off"], ["Ctrl + S", "save (the game also autosaves after every advance)"]]:
		k[1].add_child(UI.kv(pair[0], pair[1]))
	g.add_child(k[0])
	v.add_child(g)
	return UI.scroll(v)

static func _terms() -> Array:
	var path := ProjectSettings.globalize_path("res://").path_join("../CONTEXT.md")
	var out := []
	if not FileAccess.file_exists(path): return [["Glossary", [["CONTEXT.md not found", path]]]]
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var section := ""
	var cur := []
	var i := 0
	while i < lines.size():
		var ln := lines[i].strip_edges()
		if ln.begins_with("### "):
			if cur.size() > 0: out.append([section, cur])
			section = ln.substr(4); cur = []
		elif ln.begins_with("**") and ln.ends_with("**:"):
			var term := ln.substr(2, ln.length() - 5)
			var defn := ""
			var j := i + 1
			while j < lines.size() and lines[j].strip_edges() != "" and not lines[j].begins_with("_Avoid_"):
				defn += (" " if defn != "" else "") + lines[j].strip_edges(); j += 1
			cur.append([term, defn])
			i = j
			continue
		elif ln.begins_with("## ") and ln != "## Language":
			if cur.size() > 0: out.append([section, cur]); cur = []
			break
		i += 1
	if cur.size() > 0: out.append([section, cur])
	return out
