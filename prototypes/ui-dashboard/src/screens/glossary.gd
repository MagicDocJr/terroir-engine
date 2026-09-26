# PROTOTYPE — Glossary: game terms (CONTEXT.md) and wine terms, searchable. Draft text: to be checked against docs/science.
extends RefCounted

const UI := preload("res://src/ui.gd")
const GAME_TERMS := ["Estate", "Region", "Plot", "Block", "Classification", "Variety", "Planting", "Establishment", "Vintage", "Programme",
	"Alert", "Staff level", "Mentor", "Lot", "Wine", "Legal category", "Tasting sheet"]

static func build(D: Dictionary, S) -> Control:
	var q: String = S.state.get("gloss_q", "")
	var v := UI.vbox(16)
	var search := LineEdit.new(); search.placeholder_text = "Search terms, e.g. botrytis"; search.custom_minimum_size = Vector2(380, 42)
	search.text = q
	search.text_changed.connect(func(t): S.state["gloss_q"] = t; _fill(D, S.state.get("_gloss_box"), t))
	v.add_child(UI.page_header("Glossary", "The game's own terms and the wine terms it uses. Draft wording, still to be checked against the science notes.", [search]))
	var cols := UI.hbox(18); cols.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(cols)
	var box := UI.vbox(10)
	S.state["_gloss_box"] = box
	cols.add_child(UI.scroll(box))
	_fill(D, box, q)
	return v

static func _fill(D: Dictionary, box: VBoxContainer, q: String) -> void:
	if box == null: return
	for c in box.get_children(): c.queue_free()
	var groups := [["Game terms", true], ["Wine terms", false]]
	for g in groups:
		var items := []
		for e in D["glossary"]:
			var is_game: bool = String(e["term"]) in GAME_TERMS
			if is_game != g[1]: continue
			if q != "" and not (String(e["term"]).to_lower().contains(q.to_lower()) or String(e["text"]).to_lower().contains(q.to_lower())): continue
			items.append(e)
		if items.is_empty(): continue
		box.add_child(UI.head(String(g[0]), 22, UI.INK))
		var grid := GridContainer.new(); grid.columns = 2
		grid.add_theme_constant_override("h_separation", 16); grid.add_theme_constant_override("v_separation", 12)
		for e in items:
			var p := PanelContainer.new(); p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			p.custom_minimum_size = Vector2(760, 0)
			var pv := UI.vbox(4); p.add_child(pv)
			pv.add_child(UI.head(String(e["term"]), 19, UI.INK))
			pv.add_child(UI.label(String(e["text"]), 16, UI.INK2, null, true))
			grid.add_child(p)
		box.add_child(grid)
