# Wines: the Tasting sheet (appearance, nose, palate, conclusions) where every descriptor explains its cause; legal category and price.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const T := preload("res://src/ui/tasting_ui.gd")

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
			var tasted: bool = ("revealed_" + String(w["id"])) in D.get("flags", [])
			c.add_child(UI.label("%s · %s" % [w["name"], w["sheet"]["quality"] if tasted else "not tasted yet"], 16, UI.INK, UI.f_body_b))
			var wid: String = w["id"]
			UI.on_click(c, func(): shell.state["wine_sel"] = wid; shell.show_screen("wines"))
			tabs.add_child(c)
		v.add_child(tabs)
	var S: Dictionary = W["sheet"]
	var wid: String = W["id"]
	if not (("revealed_" + wid) in D.get("flags", [])):
		v.add_child(_predict(D, shell, W))
		return UI.scroll(v)
	var PR = shell.state.get("pred_result", {}).get(wid, null)
	if PR != null: v.add_child(_pred_result(shell, PR, wid))
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
	qh.add_child(UI.tile("Readiness", String(S["readiness"]) if String(S["readiness"]) != "" else "not judged (faulty)", ""))
	qh.add_child(UI.tile("Price", "€%.2f" % float(W["price"]), "per bottle · %s total" % UI.euro(int(W["revenue"]))))
	q[1].add_child(qh)
	# quality as an argument: for, against, and why not the level above (Tasting sheet 2)
	if S.has("qualityFor") and String(S["quality"]) != "Faulty":
		if S["qualityFor"].size() > 0: q[1].add_child(UI.label("For: " + "; ".join(S["qualityFor"]), 15, UI.GOOD, null, true))
		if S["qualityAgainst"].size() > 0: q[1].add_child(UI.label("Against: " + "; ".join(S["qualityAgainst"]), 15, UI.SERIOUS, null, true))
		if String(S.get("qualityNotHigher", "")) != "": q[1].add_child(UI.label(String(S["qualityNotHigher"]) + ".", 15, UI.INK2, null, true))
		if String(S.get("readinessBecause", "")) != "": q[1].add_child(UI.label("Readiness: " + String(S["readinessBecause"]) + ".", 13, UI.MUTED, null, true))
	else:
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
	for o in S.get("observations", []):
		ap[1].add_child(UI.kv("Other", String(o["term"])))
		ap[1].add_child(UI.label("because " + String(o["because"]), 13, UI.MUTED, null, true))
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
	if S.get("simple", false): np[1].add_child(UI.label("Simple: few aromas, mostly fruit; nothing from oak, lees or age.", 14, UI.INK2, null, true))
	if String(S.get("fruitRipeness", "")) != "":
		np[1].add_child(UI.kv("Fruit ripeness", String(S["fruitRipeness"])))
		np[1].add_child(UI.label("because " + String(S.get("fruitRipenessBecause", "")), 13, UI.MUTED, null, true))
	c1.add_child(np[0])
	var c2 := UI.vbox(16); c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(c2)
	var pp: Array = UI.panel("Palate", "")
	for p in S["palate"]:
		var h := UI.hbox(10)
		var al := UI.label(String(p["attribute"]), 15, UI.INK2); al.custom_minimum_size = Vector2(170, 0); h.add_child(al)
		h.add_child(UI.label(String(p["level"]), 16, UI.INK, UI.f_body_b))
		pp[1].add_child(h)
		if String(p["because"]) != "": pp[1].add_child(UI.label("because " + String(p["because"]), 13, UI.MUTED, null, true))
	if S.get("flavours", []).size() > 0: pp[1].add_child(UI.kv("Flavours", ", ".join(S["flavours"])))
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

# ------------------------------------------------------------------ predict before reveal (learning-core design §6)
static func _pred_answers(shell, wid: String) -> Dictionary:
	var all: Dictionary = shell.state.get("pred_ans", {})
	if not all.has(wid): all[wid] = {"items": {}, "confidence": {}, "recall": [], "recallConfidence": []}
	shell.state["pred_ans"] = all
	return all[wid]

static func _predict(D: Dictionary, shell, W: Dictionary) -> Control:
	var wid: String = W["id"]
	var P = JSON.parse_string(Sim.PredictionFor(wid))
	var p: Array = UI.panel("Before you taste: predict your Wine", "it changes nothing in the Wine; it is how you learn what your choices did")
	if not (P is Dictionary) or not P.has("items"):
		p[1].add_child(UI.label("This Wine's Tasting sheet is ready.", 15, UI.INK2))
		var go := UI.button("Show the Tasting sheet", true, 15); go.pressed.connect(func(): Sim.SkipPrediction(wid); shell.refresh())
		p[1].add_child(go)
		return p[0]
	var A := _pred_answers(shell, wid)
	var top := UI.hbox(18); p[1].add_child(top)
	top.add_child(T.glass({"glassColour": P["glassColour"]}, 0.8))
	var tv := UI.vbox(4); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(tv)
	tv.add_child(UI.head(String(P["name"]), 24, UI.INK))
	tv.add_child(UI.label("You made this Wine. Before its Tasting sheet opens, say what you expect, and how sure you are.", 15, UI.INK2, null, true))
	for q in P["items"]:
		var key: String = q["key"]
		var row := UI.hbox(12); p[1].add_child(row)
		var nl := UI.label(String(q["prompt"]), 15, UI.INK2, null, true); nl.custom_minimum_size = Vector2(300, 0); nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER; row.add_child(nl)
		var chosen := String(A["items"].get(key, ""))
		var pick := func(o): A["items"][key] = o; shell.show_screen("wines")
		var flow := HFlowContainer.new(); flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_child(UI.segmented(q["options"], chosen, pick)); row.add_child(flow)
		if chosen != "":
			var set_c := func(c: int): A["confidence"][key] = c; shell.show_screen("wines")
			row.add_child(T.confidence_row(int(A["confidence"].get(key, 0)), set_c))
	var recall: Array = P["recall"]
	if recall.size() > 0:
		p[1].add_child(UI.divider())
		p[1].add_child(UI.label("And your own choices", 15, UI.GOLD, UI.f_body_b))
	for i in recall.size():
		var R: Dictionary = recall[i]
		while A["recall"].size() <= i: A["recall"].append("")
		while A["recallConfidence"].size() <= i: A["recallConfidence"].append(0)
		p[1].add_child(UI.label(String(R["prompt"]), 15, UI.INK, UI.f_body_b, true))
		var chosen := String(A["recall"][i])
		var idx := i
		for o in R["options"]:
			var b := UI.button(String(o), false, 14); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if String(o) == chosen:
				b.add_theme_stylebox_override("normal", UI.sb(UI.GOLD.darkened(0.62), 4, UI.GOLD, 1, 10))
				b.add_theme_color_override("font_color", UI.GOLD.lightened(0.35))
			var val := String(o)
			b.pressed.connect(func(): A["recall"][idx] = val; shell.show_screen("wines"))
			p[1].add_child(b)
		if chosen != "":
			var set_rc := func(c: int): A["recallConfidence"][idx] = c; shell.show_screen("wines")
			var h := UI.hbox(8); h.add_child(UI.label("How sure?", 13, UI.MUTED)); h.add_child(T.confidence_row(int(A["recallConfidence"][idx]), set_rc))
			p[1].add_child(h)
	var bar := UI.hbox(12); p[1].add_child(bar)
	var rb := UI.button("Reveal the Tasting sheet", true, 17); rb.custom_minimum_size = Vector2(280, 46)
	rb.pressed.connect(func():
		var R = JSON.parse_string(Sim.RevealWine(wid, JSON.stringify(A)))
		if R is Dictionary and R.has("items"):
			var res: Dictionary = shell.state.get("pred_result", {}); res[wid] = R; shell.state["pred_result"] = res
			if shell.sfx: shell.sfx.play("cork")
		shell.refresh())
	bar.add_child(rb)
	var sk := UI.button("Skip", false, 15); sk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sk.pressed.connect(func(): Sim.SkipPrediction(wid); shell.refresh())
	bar.add_child(sk)
	return p[0]

static func _pred_result(shell, PR: Dictionary, wid: String) -> Control:
	var p: Array = UI.panel("Your predictions", "each one checked against the Tasting sheet below")
	var all: Array = PR["items"] + PR.get("recall", [])
	var right := 0.0
	for it in all: right += float(it["score"])
	p[1].add_child(UI.label("%s of %d right" % [str(right) if right != floor(right) else str(int(right)), all.size()], 16, UI.GOLD, UI.f_body_b))
	p[1].add_child(T.item_rows(all, false, 0.0, 300.0))
	var hb := UI.button("Hide", false, 14)
	hb.pressed.connect(func(): var res: Dictionary = shell.state.get("pred_result", {}); res.erase(wid); shell.show_screen("wines"))
	p[1].add_child(hb)
	return p[0]

