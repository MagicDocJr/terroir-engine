# Programmes: six season-long management tiers (Low/Medium/High) with their cost and effect. Staff carry them out day by day.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")

static func build(D: Dictionary, shell) -> Control:
	var v := UI.vbox(16)
	var total := 0
	for p in D["programmes"]:
		if p["available"]: total += int(p["tiers"][p["current"]]["cost"])
	v.add_child(UI.page_header("Programmes", "Set how intensively the vineyard is farmed. Costs are for the whole Plot per year (spray and frost scale with how often they're needed).",
		[UI.num("≈ %s / year" % UI.euro(total), 22, UI.INK)]))
	var g := GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 16); g.add_theme_constant_override("v_separation", 16)
	for p in D["programmes"]:
		var card: Array = UI.panel(String(p["name"]), "" if p["available"] else "not available here")
		card[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card[1].add_child(UI.label(String(p["notes"]), 14, UI.INK2, null, true))
		var id: String = p["id"]
		var cur: String = p["current"]
		for tier in ["Low", "Medium", "High"]:
			var t: Dictionary = p["tiers"][tier]
			var sel: bool = tier == cur
			var c := UI.card(sel, 12)
			var h := UI.hbox(12); c.add_child(h)
			var tl := UI.label(("● " if sel else "○ ") + tier, 16, UI.GOLD if sel else UI.INK, UI.f_body_b); tl.custom_minimum_size = Vector2(110, 0); h.add_child(tl)
			var el := UI.label(String(t["effect"]), 14, UI.INK if sel else UI.INK2, null, true); el.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(el)
			var cl := UI.num(UI.euro(int(t["cost"])) if int(t["cost"]) > 0 else "—", 17, UI.INK); cl.custom_minimum_size = Vector2(100, 0); cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; h.add_child(cl)
			if p["available"] and not sel:
				UI.on_click(c, func(): shell.command("programme", id, tier); shell.notify("%s set to %s." % [p["name"], tier]))
			elif not p["available"]:
				c.modulate = Color(1, 1, 1, 0.45); c.mouse_default_cursor_shape = Control.CURSOR_ARROW
			card[1].add_child(c)
		g.add_child(card[0])
	v.add_child(g)
	v.add_child(UI.label("Game simplification: one spray programme covers all three fungal diseases, and costs are regional averages (see docs/science/economy.md).", 13, UI.MUTED, null, true))
	return UI.scroll(v)
