# Blending & bottling: combine ready Lots into a Wine, choose closure, filtration and fining, and bottle it.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")

static func build(D: Dictionary, shell) -> Control:
	var ready: Array = []
	for l in D.get("lots", []):
		if l["ready"]: ready.append(l)
	var v := UI.vbox(16)
	v.add_child(UI.page_header("Blending & bottling", "Lots become ready when their ageing is done. Pick what goes into each Wine — a single Lot or a blend."))
	var B: Dictionary = shell.state.get("blend", {})
	if not B.has("parts"): B["parts"] = {}
	if not B.has("closure"): B["closure"] = "Screwcap" if D["region"]["id"] == "mosel" else "NaturalCork"
	if not B.has("filtration"): B["filtration"] = "Sterile"
	if not B.has("fining"): B["fining"] = "Bentonite"
	shell.state["blend"] = B
	var row := UI.hbox(16); v.add_child(row)
	var lp: Array = UI.panel("Ready Lots", "choose how much of each")
	lp[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ready.is_empty():
		var waiting := []
		for l in D.get("lots", []):
			if String(l["phase"]) != "Blended": waiting.append("%s (%s): %s" % [l["id"], l["variety"], l["status"]])
		lp[1].add_child(UI.label("Nothing is ready yet.", 16, UI.INK2))
		for w in waiting: lp[1].add_child(UI.label("·  " + w, 14, UI.MUTED, null, true))
	var total := 0.0
	var names := []
	for l in ready:
		var lid: String = l["id"]
		var share := int(B["parts"].get(lid, 0))
		var h := UI.hbox(12)
		h.add_child(UI.block_tag(l["block"], 16))
		var tv := UI.vbox(0); tv.custom_minimum_size = Vector2(360, 0)
		tv.add_child(UI.label("%s · %s" % [lid, l["variety"]], 16, UI.INK, UI.f_body_b))
		tv.add_child(UI.label("%s L · %.1f %% alc · TA %.1f · pH %.2f · RS %.1f g/L" % [UI.thousands(int(l["volume"])), float(l["alcohol"]), float(l["ta"]), float(l["ph"]), float(l["sugar"])], 14, UI.INK2))
		h.add_child(tv)
		h.add_child(UI.segmented(["0 %", "25 %", "50 %", "75 %", "100 %"], "%d %%" % share, func(x): B["parts"][lid] = int(x.split(" ")[0]); shell.show_screen("blending"), 70))
		lp[1].add_child(h)
		if share > 0:
			total += float(l["volume"]) * share / 100.0
			names.append("%s %s" % [l["variety"], l["block"]])
	row.add_child(lp[0])
	var bp: Array = UI.panel("The Wine", "")
	bp[0].custom_minimum_size = Vector2(640, 0)
	if not B.has("name") or String(B["name"]) == "":
		B["name"] = " & ".join(names) if names.size() > 0 else ""
	var nh := UI.hbox(12); var nl := UI.label("Name", 15, UI.INK2); nl.custom_minimum_size = Vector2(110, 0); nh.add_child(nl)
	nh.add_child(UI.line_edit(String(B["name"]), func(t): B["name"] = t, 420)); bp[1].add_child(nh)
	for spec in [["Closure", "closure", [["Screwcap", "Screw cap"], ["NaturalCork", "Natural cork"], ["TechnicalCork", "Technical cork"]], "Natural cork lets in a trace of oxygen and carries a small risk of cork taint (TCA). Screw caps keep wines fresh and reductive."],
			["Filtration", "filtration", [["Sterile", "Sterile"], ["Coarse", "Coarse"], ["Unfiltered", "Unfiltered"]], "Sterile filtration removes yeast and bacteria — essential for sweet wines. Unfiltered keeps texture but risks refermentation and Brett."],
			["Fining", "fining", [["None", "None"], ["Bentonite", "Bentonite"], ["BentoniteGelatine", "Bentonite + gelatine"]], "Bentonite removes proteins that would haze a white wine. Gelatine softens tannin in reds (and strips a little colour)."]]:
		var h := UI.hbox(12); var l := UI.label(spec[0], 15, UI.INK2); l.custom_minimum_size = Vector2(110, 0); h.add_child(l)
		var key: String = spec[1]
		var labels := []
		var cur_label := ""
		for o in spec[2]:
			labels.append(o[1])
			if o[0] == B[key]: cur_label = o[1]
		var opts: Array = spec[2]
		h.add_child(UI.segmented(labels, cur_label, func(x):
			for o in opts:
				if o[1] == x: B[key] = o[0]
			shell.show_screen("blending"), 150))
		bp[1].add_child(h)
		bp[1].add_child(UI.label(spec[3], 13, UI.MUTED, null, true))
	bp[1].add_child(UI.divider())
	bp[1].add_child(UI.kv("Volume", "%s L · about %s bottles" % [UI.thousands(int(total)), UI.thousands(int(total / 0.75))] if total > 0 else "choose at least one Lot"))
	var go := UI.button("Bottle this Wine", true, 17); go.custom_minimum_size = Vector2(0, 48); go.disabled = total <= 0
	go.pressed.connect(func():
		var parts := []
		for l in ready:
			var sh := int(B["parts"].get(l["id"], 0))
			if sh > 0: parts.append("%s:%.1f" % [l["id"], float(l["volume"]) * sh / 100.0])
		shell.command("wine", String(B["name"]), String(B["closure"]), String(B["filtration"]), String(B["fining"]), ";".join(parts), false)
		shell.state.erase("blend")
		shell.D = JSON.parse_string(Sim.Snapshot())
		shell._build_chrome()
		if shell.D.get("wines", []).size() > 0: shell.state["wine_sel"] = shell.D["wines"][-1]["id"]
		shell.show_screen("wines")
		shell.notify("Bottled. Here is the Tasting sheet."))
	bp[1].add_child(go)
	row.add_child(bp[0])
	var wines: Array = D.get("wines", [])
	if wines.size() > 0:
		var wp: Array = UI.panel("Bottled so far", "")
		for w in wines:
			wp[1].add_child(UI.kv(String(w["name"]), "%s · %s · %s bottles · €%.2f" % [w["label"], w["sheet"]["quality"], UI.thousands(int(w["bottles"])), float(w["price"])]))
		v.add_child(wp[0])
	return UI.scroll(v)
