# Onboarding (design review §8): the Mentor's plan for the first Vintage, a checklist that ticks itself off from what the
# player does, plus a short intro card the first time each screen opens. Progress lives in the save as "flag" commands
# (no effect on the simulation). Learning by doing, one step at a time, next step always visible (Hodent, The Gamer's Brain).
extends RefCounted

const UI := preload("res://src/ui/ui.gd")

const STEPS := [
	["welcome", "Read the Mentor's welcome letter", "It sums up the three years of Establishment and what comes next.", "inbox"],
	["blocks", "Look at your Blocks", "Each Block has its own soil and microclimate. Get to know them.", "plot"],
	["pruning", "Settle the winter pruning", "Choose a bud load per Block, or keep the Mentor's pruning. It sets this year's crop.", "plot"],
	["programmes", "Check the Programmes", "Spraying, canopy, floor, frost protection and crew size. The defaults are sound.", "programmes"],
	["season", "Let the season start", "Press Continue (Enter) or Play (P). Time stops by itself when something needs you.", "inbox"],
	["weather", "Keep an eye on the weather", "Frost after budburst, rain before harvest: the forecast tells you what's coming.", "weather"],
	["ripeness", "Follow the ripening", "After véraison the lab samples every Block weekly. Watch sugar rise and acid fall.", "ripeness"],
	["harvest", "Harvest your first Block", "Pick when the balance of sugar, acidity and health suits the wine you want.", "ripeness"],
	["cellar", "Look at a Lot's cellar plan", "Your Cellar master has a plan for each Lot. Change the key choices if you like.", "winery"],
	["bottle", "Bottle your first Wine", "When a Lot is ready, bottle it on its own or blend it with others.", "blending"],
	["taste", "Read the Tasting sheet", "Every line says why the wine tastes that way. This is where you learn.", "wines"],
]

const INTROS := {
	"inbox": ["Your Inbox", "Your staff and the Mentor write here. Messages marked ◆ are Alerts: time stops until you've seen them. Most messages have a button that takes you straight to where you can act."],
	"estate": ["The Estate", "Cash, profit and loss, and your staff. Better staff forecast further ahead and give more advice, but cost more."],
	"plot": ["Plot & Blocks", "The table lists your Blocks. Click one to see its soil, its vines and the choices you can make for it: pruning, leaf removal, green harvest and, later, the harvest order."],
	"weather": ["Weather", "The forecast comes from your Vineyard manager: further ahead means less certain. The charts compare this year with the 1991–2020 normal."],
	"programmes": ["Programmes", "Standing orders for the whole Plot. Click a tier to switch; it applies from today. Low saves money and lets problems through; High costs more."],
	"ripeness": ["Ripeness", "From véraison the lab samples each Block weekly. The bands show the must weight each style needs. When a Block looks right, press Harvest."],
	"winery": ["The Winery", "Each harvested Block becomes a Lot. Your Cellar master has a plan for it. The choices marked 🔒 fix once fermentation starts, so decide those first."],
	"blending": ["Blending & bottling", "Lots appear here when their ageing is done. Choose how much of each goes into a Wine, pick the closure, and bottle."],
	"wines": ["Your Wines", "The Tasting sheet: appearance, nose, palate and conclusions. The grey 'because' lines trace each descriptor back to a decision or a condition."],
	"glossary": ["Glossary", "The words the game uses. You can switch the Mentor's plan back on here."],
}

static func flags(D: Dictionary) -> Dictionary:
	var f := {}
	for x in D.get("flags", []): f[String(x)] = true
	return f

static func _any_block(D: Dictionary, key: String) -> bool:
	for b in D.get("blocks", []):
		if b.get(key) != null: return true
	return false

static func is_done(D: Dictionary, id: String) -> bool:
	var f := flags(D)
	match id:
		"welcome":
			for m in D.get("inbox", []):
				if int(m["id"]) == 1: return bool(m["read"])
			return true
		"blocks": return f.has("visited_plot")
		"pruning": return f.has("pruning_ok") or _any_block(D, "budburst")
		"programmes": return f.has("visited_programmes")
		"season": return _any_block(D, "budburst")
		"weather": return f.has("visited_weather")
		"ripeness": return f.has("visited_ripeness") and _any_block(D, "veraison")
		"harvest":
			for b in D.get("blocks", []):
				if b["harvested"] or b["picking"]: return true
			return false
		"cellar": return f.has("visited_winery") and D.get("lots", []).size() > 0
		"bottle": return D.get("wines", []).size() > 0
		"taste": return f.has("visited_wines") and D.get("wines", []).size() > 0
	return false

## Index of the first unfinished step, or -1 when the plan is complete.
static func next_step(D: Dictionary) -> int:
	for i in STEPS.size():
		if not is_done(D, STEPS[i][0]): return i
	return -1

## The Mentor's plan belongs to the first Vintage only.
static func enabled(D: Dictionary) -> bool:
	return not flags(D).has("plan_hidden") and not bool(D.get("mentor", {}).get("retired", false))

## Compact card for the left menu: progress and the next step with a Go button.
static func nav_card(D: Dictionary, shell) -> Control:
	var i := next_step(D)
	if i < 0 or not enabled(D): return null
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sb(Color("2a2616"), 6, UI.GOLD.darkened(0.25), 1, 12))
	var v := UI.vbox(6); p.add_child(v)
	var done := 0
	for s in STEPS:
		if is_done(D, s[0]): done += 1
	v.add_child(UI.label("THE MENTOR'S PLAN · %d/%d" % [done, STEPS.size()], 11, UI.GOLD, UI.f_body_b))
	v.add_child(UI.label(STEPS[i][1], 15, UI.INK, UI.f_body_b, true))
	var go := UI.button("Go ▸", true, 14)
	var target: String = STEPS[i][3]
	go.pressed.connect(func(): shell.state.erase("return_to"); shell.show_screen(target))
	v.add_child(go)
	var all := UI.button("See the whole plan", false, 13)
	all.pressed.connect(func(): shell.state["plan_open"] = true; shell.show_screen("inbox"))
	v.add_child(all)
	return p

## Full checklist (top of the Inbox).
static func plan_panel(D: Dictionary, shell) -> Control:
	var i_next := next_step(D)
	var pn: Array = UI.panel("The Mentor's plan for your first Vintage", "ticks itself off as you play")
	pn[0].add_theme_stylebox_override("panel", UI.sb(Color("2a2616"), 6, UI.GOLD.darkened(0.25), 1, 16))
	var g := UI.hbox(24)
	var cols := [UI.vbox(6), UI.vbox(6)]
	g.add_child(cols[0]); g.add_child(cols[1])
	var half := int(ceil(STEPS.size() / 2.0))
	for i in STEPS.size():
		var s: Array = STEPS[i]
		var d := is_done(D, s[0])
		var row := UI.hbox(8)
		row.add_child(UI.label("✓" if d else ("▸" if i == i_next else "○"), 15, UI.GOOD if d else (UI.GOLD if i == i_next else UI.MUTED), UI.f_body_b))
		var t := UI.vbox(0)
		t.add_child(UI.label("%d. %s" % [i + 1, s[1]], 15, UI.MUTED if d else UI.INK, UI.f_body_b if i == i_next else null))
		if i == i_next: t.add_child(UI.label(s[2], 13, UI.INK2, null, true))
		t.custom_minimum_size = Vector2(560, 0)
		row.add_child(t)
		if i == i_next:
			var go := UI.button("Go ▸", true, 13)
			var target: String = s[3]
			go.pressed.connect(func(): shell.show_screen(target))
			row.add_child(go)
		cols[0 if i < half else 1].add_child(row)
	pn[1].add_child(g)
	var h := UI.hbox(10)
	var close := UI.button("Collapse", false, 13); close.pressed.connect(func(): shell.state["plan_open"] = false; shell.show_screen("inbox"))
	var hide := UI.button("I know my way: hide the plan", false, 13); hide.pressed.connect(func(): shell.command("flag", "plan_hidden"); shell.notify("The Mentor's plan is hidden. Switch it back on in the Glossary.", true))
	h.add_child(close); h.add_child(hide)
	pn[1].add_child(h)
	return pn[0]

## Intro card shown the first time a screen opens.
static func intro_card(id: String, shell) -> Control:
	if not INTROS.has(id): return null
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sb(Color("1f2a24"), 6, UI.GOOD.darkened(0.2), 1, 14))
	var h := UI.hbox(14); p.add_child(h)
	var v := UI.vbox(2); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(v)
	v.add_child(UI.label("NEW HERE? · " + String(INTROS[id][0]).to_upper(), 11, UI.GOOD.lightened(0.3), UI.f_body_b))
	v.add_child(UI.label(INTROS[id][1], 15, UI.INK, null, true))
	var ok := UI.button("Got it", true, 14); ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func(): shell.command("flag", "intro_" + id))
	h.add_child(ok)
	return p
