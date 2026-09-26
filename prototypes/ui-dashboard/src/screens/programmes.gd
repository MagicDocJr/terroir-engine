# PROTOTYPE — Programmes: Low / Medium / High tiers with cost, labour and effect; totals update as you change tiers.
extends RefCounted

const UI := preload("res://src/ui.gd")
const Charts := preload("res://src/charts.gd")

static func build(D: Dictionary, S) -> Control:
	var progs: Array = D["programmes"]
	if not S.state.has("tiers"):
		var t := {}
		for p in progs: t[p["id"]] = p["current"]
		S.state["tiers"] = t
	var tiers: Dictionary = S.state["tiers"]
	var v := UI.vbox(16)
	v.add_child(UI.page_header("Programmes", "Standing instructions your staff carry out every day. Cutting spend saves money now and shows up later as disease, late work or a slow harvest."))
	var row := UI.hbox(18); row.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(row)
	var grid := GridContainer.new(); grid.columns = 2; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16); grid.add_theme_constant_override("v_separation", 16)
	row.add_child(grid)
	for p in progs: grid.add_child(_card(p, tiers, S))
	row.add_child(_summary(D, tiers))
	return v

static func _card(p: Dictionary, tiers: Dictionary, S) -> Control:
	var pc := PanelContainer.new(); pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.custom_minimum_size = Vector2(560, 0)
	var v := UI.vbox(10); pc.add_child(v)
	var h := UI.hbox(10)
	h.add_child(UI.head(String(p["name"]), 21, UI.INK))
	h.add_child(UI.spacer())
	v.add_child(h)
	v.add_child(UI.label(String(p["notes"]), 14, UI.MUTED, null, true))
	var t: Dictionary = p["tiers"]
	if t.is_empty():
		v.add_child(UI.status("idle", "Not available on this Plot"))
		v.add_child(UI.label("Irrigation needs a water connection. Mosel steep slopes are mostly dry-farmed; the slate roots go deep.", 15, UI.INK2, null, true))
		return pc
	var chosen: String = tiers[p["id"]]
	v.add_child(UI.segmented(["Low", "Medium", "High"], chosen, func(o): tiers[p["id"]] = o; S.rerender(), 110))
	var info: Dictionary = t[chosen]
	var nums := UI.hbox(26)
	for kv in [["Cost this season", UI.euro(int(info["cost"]))], ["Labour", "%s h" % UI.thousands(int(info["hours"]))]]:
		var c := UI.vbox(0); c.add_child(UI.label(kv[0], 13, UI.MUTED)); c.add_child(UI.num(kv[1], 22, UI.INK)); nums.add_child(c)
	var rk := int(info["risk"])
	if rk != 0 or p["id"] in ["spray", "canopy"]:
		var c2 := UI.vbox(0); c2.add_child(UI.label("Disease pressure", 13, UI.MUTED))
		var txt := "baseline" if rk == 0 else ("%+d %% vs Medium" % rk)
		c2.add_child(UI.num(txt, 22, UI.SERIOUS if rk > 0 else (UI.GOOD.lightened(0.3) if rk < 0 else UI.INK)))
		nums.add_child(c2)
	v.add_child(nums)
	v.add_child(UI.label(String(info["effect"]), 16, UI.INK2, null, true))
	return pc

static func _summary(D: Dictionary, tiers: Dictionary) -> Control:
	var pv := UI.panel("This season", "totals for your current tiers")
	pv[0].custom_minimum_size = Vector2(480, 0)
	var cost := 0; var hours := 0
	for p in D["programmes"]:
		var t: Dictionary = p["tiers"]
		if t.is_empty(): continue
		var info: Dictionary = t[tiers[p["id"]]]
		cost += int(info["cost"])
		if p["id"] != "labour": hours += int(info["hours"])
	var avail: int = 0
	for p in D["programmes"]:
		if p["id"] == "labour": avail = int(p["tiers"][tiers["labour"]]["hours"]) + 3200
	pv[1].add_child(UI.label("Programme cost", 15, UI.INK2))
	pv[1].add_child(UI.num(UI.euro(cost), 36, UI.INK))
	pv[1].add_child(UI.divider())
	pv[1].add_child(UI.label("Labour needed vs available", 15, UI.INK2))
	var need := hours + 3100                                         # plus pruning, tying, harvest (fixed in the prototype)
	var h := UI.hbox(10)
	h.add_child(UI.num("%s h of %s h" % [UI.thousands(need), UI.thousands(avail)], 22, UI.SERIOUS if need > avail else UI.INK))
	pv[1].add_child(h)
	var m = Charts.Meter.new(); m.value = float(need) / float(avail) * 0.85; m.target = 0.85
	m.color = UI.SERIOUS if need > avail else UI.SEQ; m.custom_minimum_size = Vector2(0, 12)
	pv[1].add_child(m)
	pv[1].add_child(UI.label("Available = seasonal crew + your staff (3,200 h). The tick is 100 % of capacity." if need <= avail
		else "Over capacity: work will run late. Expect late leaf removal and a slower harvest.", 14, UI.MUTED if need <= avail else UI.SERIOUS, null, true))
	pv[1].add_child(UI.divider())
	pv[1].add_child(UI.label("Weekly labour this season", 15, UI.INK2))
	var sp = Charts.Sparkline.new(); sp.values = D["labourHours"]["weekly"]; sp.color = UI.SEQ; sp.custom_minimum_size = Vector2(0, 60)
	pv[1].add_child(sp)
	pv[1].add_child(UI.label("Peaks: shoot tying in June, leaf removal in July, harvest in October.", 13, UI.MUTED, null, true))
	pv[1].add_child(UI.spacer(false))
	pv[1].add_child(UI.label("Your Vineyard manager is Junior: sprays land a little later than planned. A Senior times them to the model alerts.", 14, UI.INK2, null, true))
	return pv[0]
