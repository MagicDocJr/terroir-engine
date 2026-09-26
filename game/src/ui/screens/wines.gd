# Wines: the Tasting sheet (appearance, nose, palate, conclusions) where every descriptor explains its cause; legal category and price.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")

static func build(D: Dictionary, shell) -> Control:
	var wines: Array = D.get("wines", [])
	var v := UI.vbox(16)
	v.add_child(UI.page_header("Wines", "Tasting sheets use a systematic approach to tasting. Hover or read the grey lines: each one says why."))
	if wines.is_empty():
		var p: Array = UI.panel("No wine bottled yet", "")
		p[1].add_child(UI.label("Lots become Wines on the Blending screen once their ageing is done.", 16, UI.INK2))
		v.add_child(p[0])
		return v
	var sel_id: String = shell.state.get("wine_sel", wines[0]["id"])
	var W: Dictionary = wines[0]
	for w in wines:
		if w["id"] == sel_id: W = w
	if wines.size() > 1:
		var tabs := UI.hbox(8)
		for w in wines:
			var c := UI.card(w["id"] == W["id"], 12)
			c.add_child(UI.label("%s · %s" % [w["name"], w["sheet"]["quality"]], 16, UI.INK, UI.f_body_b))
			var wid: String = w["id"]
			UI.on_click(c, func(): shell.state["wine_sel"] = wid; shell.show_screen("wines"))
			tabs.add_child(c)
		v.add_child(tabs)
	var S: Dictionary = W["sheet"]
	# label card
	var top := UI.hbox(16); v.add_child(top)
	var lab: Array = UI.panel("", "", 6)
	lab[0].add_theme_stylebox_override("panel", UI.sb(Color("f1ead8"), 6, Color("b8a77a"), 1, 22))
	lab[0].custom_minimum_size = Vector2(520, 0)
	var n := UI.head(String(W["name"]), 34, Color("2a2216")); lab[1].add_child(n)
	lab[1].add_child(UI.label(String(W["label"]), 17, Color("5a4a2e"), UI.f_body_b, true))
	if W["sweetnessTerm"] != null and String(W["sweetnessTerm"]) != "": lab[1].add_child(UI.label(String(W["sweetnessTerm"]), 15, Color("5a4a2e")))
	lab[1].add_child(UI.label("%s · %s bottles · %s, %s filtration, %s" % [D["estate"], UI.thousands(int(W["bottles"])), W["closure"], String(W["filtration"]).to_lower(), _fining(String(W["fining"]))], 14, Color("6b5a3a"), null, true))
	lab[1].add_child(UI.label("Bottled %s" % W["bottled"], 14, Color("6b5a3a")))
	top.add_child(lab[0])
	var q: Array = UI.panel("Conclusions", "")
	q[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var qh := UI.hbox(24)
	qh.add_child(UI.tile("Quality", String(S["quality"]), "", UI.GOLD))
	qh.add_child(UI.tile("Readiness", String(S["readiness"]), ""))
	qh.add_child(UI.tile("Price", "€%.2f" % float(W["price"]), "per bottle · %s total" % UI.euro(int(W["revenue"]))))
	q[1].add_child(qh)
	q[1].add_child(UI.label(String(S["qualityBecause"]), 15, UI.INK2, null, true))
	var bl := UI.hbox(18)
	for b in S["blic"]:
		var bv := UI.vbox(2); bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bv.add_child(UI.label(("✓ " if b["met"] else "✗ ") + String(b["criterion"]), 15, UI.GOOD if b["met"] else UI.SERIOUS, UI.f_body_b))
		bv.add_child(UI.label(String(b["why"]), 13, UI.MUTED, null, true))
		bl.add_child(bv)
	q[1].add_child(bl)
	top.add_child(q[0])
	var row := UI.hbox(16); v.add_child(row)
	var c1 := UI.vbox(16); c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(c1)
	var ap: Array = UI.panel("Appearance", "")
	var A: Dictionary = S["appearance"]
	ap[1].add_child(UI.kv("Clarity", String(A["clarity"])))
	ap[1].add_child(UI.kv("Intensity", String(A["intensity"])))
	ap[1].add_child(UI.kv("Colour", String(A["colour"])))
	if String(A["because"]) != "": ap[1].add_child(UI.label("because " + String(A["because"]), 13, UI.MUTED, null, true))
	c1.add_child(ap[0])
	var np: Array = UI.panel("Nose", "")
	var N: Dictionary = S["nose"]
	np[1].add_child(UI.kv("Condition", String(N["condition"])))
	np[1].add_child(UI.kv("Intensity", String(N["intensity"])))
	np[1].add_child(UI.kv("Development", String(N["development"])))
	var faults: Array = S.get("faults", [])
	if faults.size() > 0:
		for f in faults: np[1].add_child(UI.label("⚠ " + String(f), 15, UI.CRIT, UI.f_body_b, true))
	np[1].add_child(UI.divider())
	var cat := ""
	for a in S["aromas"]:
		if String(a["category"]) != cat:
			cat = String(a["category"])
			np[1].add_child(UI.label(cat, 14, UI.GOLD, UI.f_body_b))
		var h := UI.hbox(10)
		var fl := UI.label(String(a["family"]), 14, UI.INK2); fl.custom_minimum_size = Vector2(170, 0); h.add_child(fl)
		var tl := UI.label(String(a["terms"]), 15, UI.INK, UI.f_body_b, true); tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(tl)
		h.tooltip_text = String(a["because"]); h.mouse_filter = Control.MOUSE_FILTER_PASS
		np[1].add_child(h)
		np[1].add_child(UI.label("because " + String(a["because"]), 13, UI.MUTED, null, true))
	c1.add_child(np[0])
	var c2 := UI.vbox(16); c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(c2)
	var pp: Array = UI.panel("Palate", "")
	for p in S["palate"]:
		var h := UI.hbox(10)
		var al := UI.label(String(p["attribute"]), 15, UI.INK2); al.custom_minimum_size = Vector2(170, 0); h.add_child(al)
		h.add_child(UI.label(String(p["level"]), 16, UI.INK, UI.f_body_b))
		pp[1].add_child(h)
		if String(p["because"]) != "": pp[1].add_child(UI.label("because " + String(p["because"]), 13, UI.MUTED, null, true))
	c2.add_child(pp[0])
	var lg: Array = UI.panel("Legal category", String(W["category"]))
	for note in W["legalNotes"]: lg[1].add_child(UI.label("·  " + String(note), 14, UI.INK2, null, true))
	c2.add_child(lg[0])
	var ch: Array = UI.panel("Lab analysis at bottling", "")
	for c in S["chemistry"]: ch[1].add_child(UI.label(String(c), 14, UI.INK2, null, true))
	var comp := []
	for c in W["components"]: comp.append("%s %s L" % [c["lot"], UI.thousands(int(c["litres"]))])
	ch[1].add_child(UI.label("Blend: " + ", ".join(comp), 14, UI.MUTED))
	c2.add_child(ch[0])
	return UI.scroll(v)

static func _fining(f: String) -> String:
	return {"None": "unfined", "Bentonite": "bentonite-fined", "BentoniteGelatine": "bentonite + gelatine fined"}.get(f, f)
