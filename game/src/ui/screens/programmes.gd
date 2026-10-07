# Programmes: six season-long management tiers (Low/Medium/High; frost protection is Off/On) with their cost and effect. Staff carry them out day by day.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")

static func build(D: Dictionary, shell) -> Control:
	var v := UI.vbox(16)
	var total := 0
	for p in D["programmes"]:
		if p["available"] and not p.get("perNight", false): total += int(p["tiers"][p["current"]]["cost"])
	v.add_child(UI.page_header("Programmes", "Set how intensively the vineyard is farmed. Click a tier to switch; it applies from today, with no confirm needed. Costs are for the whole Plot per year.",
		[UI.num("≈ %s / year" % UI.euro(total), 22, UI.INK)]))
	var g := GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 16); g.add_theme_constant_override("v_separation", 16)
	for p in D["programmes"]:
		var cur_label := String(p["tiers"].get(p["current"], {}).get("label", p["current"]))
		var hint := "not available here" if not p["available"] else ("✓ %s since %s" % [cur_label, p["changed"]] if p.get("changed") != null else "✓ %s (the Mentor's default)" % cur_label)
		var card: Array = UI.panel(String(p["name"]), hint)
		card[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card[1].add_child(UI.label(String(p["notes"]), 14, UI.INK2, null, true))
		var id: String = p["id"]
		var cur: String = p["current"]
		for tier in p.get("order", ["Low", "Medium", "High"]):
			var t: Dictionary = p["tiers"][tier]
			var sel: bool = tier == cur
			var c := UI.card(sel, 12)
			var h := UI.hbox(12); c.add_child(h)
			var tl := UI.label(("● " if sel else "○ ") + String(t.get("label", tier)), 16, UI.GOLD if sel else UI.INK, UI.f_body_b); tl.custom_minimum_size = Vector2(110, 0); h.add_child(tl)
			var el := UI.label(String(t["effect"]), 14, UI.INK if sel else UI.INK2, null, true); el.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(el)
			var cl := UI.num((UI.euro(int(t["cost"])) + (" / night" if p.get("perNight", false) else "")) if int(t["cost"]) > 0 else "—", 17, UI.INK); cl.custom_minimum_size = Vector2(100, 0); cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; h.add_child(cl)
			if p["available"] and not sel:
				UI.on_click(c, func(): shell.command("programme", id, tier); shell.notify("%s set to %s. Your Vineyard manager works this way from today." % [p["name"], String(t.get("label", tier))], true))
			elif not p["available"]:
				c.modulate = Color(1, 1, 1, 0.45); c.mouse_default_cursor_shape = Control.CURSOR_ARROW
			card[1].add_child(c)
		if p.get("shopLink", false):
			var sh := UI.button("Frost equipment in the Shop", false, 14)
			sh.tooltip_text = "A wind machine or sprinklers: cheaper frost nights, or protection in harder frosts."
			sh.pressed.connect(func(): shell.state["shop_tab"] = "Vineyard & cellar"; shell.show_screen("shop"))
			card[1].add_child(sh)
		if id == "spray":
			var sb := UI.button("Spray today (one extra pass)", false, 15)
			sb.tooltip_text = "Override the schedule once, e.g. before forecast rain. Costs one pass; skipped if it's pouring."
			sb.pressed.connect(func(): shell.command("spraynow"); shell.notify("Extra spray pass ordered for today — advance a day to carry it out."))
			card[1].add_child(sb)
		g.add_child(card[0])
	v.add_child(g)
	v.add_child(UI.label("Game simplification: one spray programme covers all three fungal diseases, and costs are regional averages (see docs/science/economy.md).", 13, UI.MUTED, null, true))
	return UI.scroll(v)
