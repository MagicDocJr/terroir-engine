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
	var how: Array = UI.panel("How bottling works", "", 4)
	how[0].add_theme_stylebox_override("panel", UI.sb(UI.SUNKEN, 6, UI.LINE, 1, 14))
	for line in ["Choose how much of each ready Lot goes into this Wine. 100 % bottles the whole Lot. 25–75 % bottles part of it and keeps the rest in the Lot for another Wine later.",
			"To blend, give two or more Lots a share: 50 % of Lot A plus 50 % of Lot B makes one Wine from both. Blending can balance acidity, body and flavour, but it can change the label (see the notes under the blend).",
			"Ready Lots can wait: there is no rush to bottle the moment a Lot is ready."]:
		how[1].add_child(UI.label("·  " + line, 14, UI.INK2, null, true))
	v.add_child(how[0])
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
	# what's in the blend (shares only; the wine itself is judged by the simulation when you bottle)
	var comp := {}
	var reds := 0.0; var whites := 0.0
	for l in ready:
		var sh := int(B["parts"].get(l["id"], 0))
		if sh <= 0: continue
		var litres := float(l["volume"]) * sh / 100.0
		comp[String(l["variety"])] = float(comp.get(String(l["variety"]), 0.0)) + litres
		if l["red"]: reds += litres
		else: whites += litres
	if total > 0:
		var parts_txt := []
		for vname in comp: parts_txt.append("%d %% %s" % [roundi(100.0 * float(comp[vname]) / total), vname])
		bp[1].add_child(UI.kv("Blend", ", ".join(parts_txt)))
		var top := 0.0
		for vname in comp: top = maxf(top, float(comp[vname]) / total)
		var notes := []
		if comp.size() > 1:
			match String(D["region"]["id"]):
				"mosel": notes.append("A single-vineyard name needs ≥ 85 % Riesling (or Pinot Noir)." if top < 0.85 else "One Variety is ≥ 85 %, so a single-vineyard name is still allowed.")
				"cote-dor": notes.append("Burgundy AOCs allow Pinot Noir and Chardonnay; other Varieties make it Vin de France.")
				_: notes.append("A varietal label (e.g. \"Cabernet Sauvignon\") needs ≥ 75 % of that Variety." if top < 0.75 else "One Variety is ≥ 75 %, so the varietal label is kept.")
		if reds > 0 and whites > 0: notes.append("Mixing red and white wine to make rosé isn't allowed for these still wines in the EU; in Napa it's legal but unusual.")
		for n in notes: bp[1].add_child(UI.label("ⓘ " + n, 13, UI.INK2, null, true))
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
		if String(shell.D.get("phase", "")) == "Finished" and not shell.state.get("report_shown", false):
			shell.state["report_shown"] = true
			shell.show_screen("report")
			shell.notify("That was the last Lot: here is your Vintage report.")
			return
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
