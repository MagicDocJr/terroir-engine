# Terroir Engine — game shell: title & pre-game flow, top bar with time controls, left menu, screen host, status bar,
# toasts, keys, autosave, 3D toggle, and a capture mode that plays a real game and screenshots every screen.
# The UI only reads snapshots from the `Sim` autoload and sends commands; it never computes outcomes (ADR 0001).
extends Control

const UI := preload("res://src/ui/ui.gd")
const Onboarding := preload("res://src/ui/onboarding.gd")
const Charts := preload("res://src/ui/charts.gd")
const SCREENS := {
	"title": ["Terroir Engine", "res://src/ui/screens/pregame.gd", "title"],
	"region": ["Choose a Region", "res://src/ui/screens/pregame.gd", "region"],
	"plots": ["Compare Plots", "res://src/ui/screens/pregame.gd", "plots"],
	"planting": ["Planting", "res://src/ui/screens/pregame.gd", "planting"],
	"inbox": ["Inbox", "res://src/ui/screens/inbox.gd", ""],
	"estate": ["Estate", "res://src/ui/screens/estate.gd", ""],
	"plot": ["Plot & Blocks", "res://src/ui/screens/plot.gd", ""],
	"weather": ["Weather", "res://src/ui/screens/weather.gd", ""],
	"programmes": ["Programmes", "res://src/ui/screens/programmes.gd", ""],
	"shop": ["Shop", "res://src/ui/screens/shop.gd", ""],
	"ripeness": ["Ripeness", "res://src/ui/screens/ripeness.gd", ""],
	"winery": ["Winery", "res://src/ui/screens/winery.gd", ""],
	"blending": ["Blending", "res://src/ui/screens/blending.gd", ""],
	"wines": ["Wines", "res://src/ui/screens/wines.gd", ""],
	"glossary": ["Glossary", "res://src/ui/screens/glossary.gd", ""],
	"report": ["Vintage report", "res://src/ui/screens/report.gd", ""],
	"practice": ["Tasting practice", "res://src/ui/screens/practice.gd", ""],
	"fair": ["Wine Fair", "res://src/ui/screens/fair.gd", ""],
	"cellarbook": ["Cellar book", "res://src/ui/screens/cellar_book.gd", ""],
	"scenarios": ["Famous vintages", "res://src/ui/screens/scenarios.gd", "list"],
	"scenario_brief": ["Famous vintages", "res://src/ui/screens/scenarios.gd", "brief"],
	"scenario": ["Famous vintage", "res://src/ui/screens/scenarios.gd", "status"],
}
const NAV := ["inbox", "estate", "plot", "weather", "programmes", "shop", "ripeness", "winery", "blending", "wines", "glossary", "practice"]
const NAV_GLYPH := {"inbox": "▤", "estate": "◆", "plot": "▦", "weather": "☁", "programmes": "≡", "shop": "⌂", "ripeness": "◔",
	"winery": "▥", "blending": "⋈", "wines": "✦", "glossary": "?", "practice": "◇"}
const PREGAME := ["title", "region", "plots", "planting", "scenarios", "scenario_brief"]
const TASTING := ["practice", "fair", "cellarbook"]   # open with or without a game; their state lives in `state`, so never cached

var D: Dictionary = {}          # latest snapshot
var CAT: Dictionary = {}        # setup catalog (Regions, Plots, options)
var setup := {}                 # pre-game choices: region, plot, planting per Block, year, staff, estate name
var current := ""
var capture := false
var state := {}                 # screen-local UI state that survives re-renders (selected Block, Lot, sort, …)
var root_box: VBoxContainer
var topbar: Control
var nav_panel: Control
var nav_box: VBoxContainer
var nav_plan: MarginContainer
var host: MarginContainer
var statusbar: Control
var toast: PanelContainer
var toast_label: Label
var view3d: Node = null
var busy := false
var playing := false            # continuous play: advances every tick until an Alert
var play_speed := 1             # days per 0.25 s tick (4 days a second)
var play_timer: Timer
var sfx: Node
var _screen_cache := {}          # screen id → {node, ver, ret}: built screens reused while the game state is unchanged
var _chrome_ver := 0             # bumps whenever a new snapshot is shown
var learn_layer: Control = null   # the open learn drawer (one at a time)
var _learn_open := ["", {}]
var harness := ""         # the harness this run plays (scripts/*.sh), or "" in normal play
var shot_hold := 10       # frames a harness waits before each screenshot; scripts/record.sh raises it so a video lingers
var _learn_seen_cache = null
const LEARN_DRAWER_AT := 0.58     # the learn card's left edge, as a share of the window width (learn_drawer.gd)
var _cur_node: Control = null     # the screen on show (pre-game screens are not cached, so it is kept here)
var _pending_scroll := -1         # a scroll position still being restored on _cur_node
var _cur_sig := ""                # the page on show (_page_sig)

func _ready() -> void:
	theme = UI.make_theme()
	var args := OS.get_cmdline_user_args()
	capture = "--capture" in args
	for a in args: if a.begins_with("--hold="): shot_hold = maxi(1, int(a.substr(7)))   # frames per screenshot (videos linger)
	if capture:
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		get_tree().root.content_scale_size = Vector2i(1920, 1080)
	CAT = JSON.parse_string(Sim.Catalog())
	var bg := ColorRect.new(); bg.color = UI.BG; bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	root_box = UI.vbox(0); root_box.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(root_box)
	topbar = PanelContainer.new(); root_box.add_child(topbar)
	var body := UI.hbox(0); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; root_box.add_child(body)
	nav_panel = PanelContainer.new(); body.add_child(nav_panel)
	host = MarginContainer.new(); host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		host.add_theme_constant_override("margin_" + side, 24 if side in ["left", "right"] else 18)
	body.add_child(host)
	statusbar = PanelContainer.new(); root_box.add_child(statusbar)
	_make_toast()
	sfx = load("res://src/ui/sfx.gd").new(); add_child(sfx)
	# harness runs never touch the player's study record or saves, and each harness has its own, so they can run in parallel
	for h in ["scenarios", "learning", "practice", "fuzz", "perf", "pregame", "layoutcheck", "capture"]:
		if ("--" + h) in args:
			harness = h
			Sim.SetRecordPath("user://tasting_record_test_%s.json" % h); Sim.SetSaveDir("user://saves_test_%s" % h)
			break
	if capture:
		sfx.enabled = false
	get_tree().node_added.connect(_on_node_added)
	play_timer = Timer.new(); play_timer.wait_time = 0.25; play_timer.timeout.connect(_play_tick); add_child(play_timer)
	if "--sfxcheck" in args:
		var fx = load("res://src/ui/sfx.gd").new(); add_child(fx)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/sfx"))
		for n in fx.players: (fx.players[n].stream as AudioStreamWAV).save_to_wav(ProjectSettings.globalize_path("res://shots/sfx/%s.wav" % n))
		print("SFX saved"); get_tree().quit(); return
	if "--perf" in args: capture = true; _perf.call_deferred(); return
	if "--pregame" in args: capture = true; _pregame_shots.call_deferred(); return
	if "--avatars" in args: capture = true; _avatar_sheet.call_deferred(); return
	if "--scenarios" in args:
		capture = true; _scenario_test.call_deferred(); return
	if "--learning" in args:
		capture = true; _learning_test.call_deferred(); return
	if "--practice" in args:
		capture = true; _practice_test.call_deferred(); return
	if "--layoutcheck" in args: capture = true; _layout_selftest.call_deferred(); return
	if "--fuzz" in args: capture = true; _run_fuzz.call_deferred()
	elif capture: _run_capture.call_deferred()
	else: show_screen("title")

# ------------------------------------------------------------------ data & commands
func refresh() -> void:
	if Sim.HasGame():
		D = JSON.parse_string(Sim.Snapshot())
	_build_chrome()
	show_screen(current if current != "" else "inbox")

func command(type: String, a := "", b := "", c := "", d := "", e := "", stay := true) -> void:
	var ok: bool = Sim.Command(type, a, b, c, d, e)
	if ok and sfx:
		if type == "wine": sfx.play("cork")
		elif type == "harvest": sfx.play("harvest")
	if not ok: notify("That didn't work: " + String(Sim.LastError()).left(160))
	if stay: refresh()

## A player choice that applies immediately, with a visible confirmation.
func apply(type: String, a: String, b: String, c: String, message: String) -> void:
	command(type, a, b, c)
	notify(message, true)

## The autosave slot: a famous-vintage scenario keeps its own, so it never overwrites the main Estate's autosave.
func autosave_slot() -> String:
	var sid := String(Sim.ScenarioId())
	return "autosave" if sid == "" else "autosave-" + sid

## Advance time. stop=true runs until the next Alert (max `days`).
func advance(days: int, stop := true, quiet := false) -> bool:
	if busy or not Sim.HasGame(): return false
	busy = true
	var before := _alert_ids()
	var n: int = Sim.Advance(days, stop)
	D = JSON.parse_string(Sim.Snapshot())
	Sim.SaveGame(autosave_slot())
	busy = false
	# open each Vintage report once, the first time its Vintage is fully bottled (the flag lives in the save)
	var fl: Array = D.get("flags", [])
	for bv in D.get("bottledVintages", []):
		var key := "report_%d" % int(bv)
		if not fl.has(key):
			Sim.Command("flag", key, "", "", "", "")
			D = JSON.parse_string(Sim.Snapshot())
			state["report_vintage"] = int(bv)
			_build_chrome(); show_screen("report")
			return false
	var new_alerts := []
	for m in D.get("inbox", []):
		if m.get("stop", false) and not before.has(int(m["id"])): new_alerts.append(m)
	_build_chrome()
	if new_alerts.size() > 0:
		if sfx: sfx.play("alert")
		state["inbox_sel"] = int(new_alerts[-1]["id"])   # the oldest of the new Alerts (the list is newest first)
		show_screen("inbox")
		notify("%d day%s later — %s" % [n, "" if n == 1 else "s", String(new_alerts[-1]["subject"])])
	else:
		show_screen(current)
		if n > 0 and not quiet: notify("%d day%s passed." % [n, "" if n == 1 else "s"])
	if view3d != null and view3d.visible and view3d.has_method("apply_snapshot"): view3d.apply_snapshot(D)
	return new_alerts.size() > 0

## Continue jumps further when nothing is growing or fermenting (design review §1).
func continue_days() -> int:
	return 120 if D.get("quiet", false) else 60

## Continuous play (spec §3.3): a day or more per tick, stopping at the first Alert.
func toggle_play() -> void:
	playing = not playing
	if playing: play_timer.start()
	else: play_timer.stop()
	_topbar_refresh_count()

func _play_tick() -> void:
	if not playing or busy: return
	var alert := advance(play_speed, true, true)
	if alert:
		playing = false; play_timer.stop(); _topbar_refresh_count()

func _alert_ids() -> Dictionary:
	var ids := {}
	for m in D.get("inbox", []): ids[int(m["id"])] = true
	return ids

## Run an inbox action button: goto <screen>, harvest <block>, restart <lot>, programme "<id>:<tier>", block "<id>:<key>:<value>".
func run_action(action: String, arg: String) -> void:
	match action:
		"goto":
			state["return_to"] = "inbox"
			if arg == "shop-equipment": state["shop_tab"] = "Vineyard & cellar"; arg = "shop"
			show_screen(arg)
		"harvest":
			state["return_to"] = "inbox"
			state["plot_sel"] = arg
			show_screen("plot")
			notify("Choose how to pick Block %s, then press Harvest." % arg)
		"restart": command("restart", arg)
		"spraynow": command("spraynow"); notify("Extra spray pass ordered for today — advance a day to carry it out.")
		"acceptstuck": command("acceptstuck", arg); notify("Fermentation stopped; the Lot keeps its residual sugar.")
		"programme":
			var p := arg.split(":"); command("programme", p[0], p[1])
			notify(("Frost protection is on. Your Vineyard manager uses it on frost nights from today." if p[0] == "frost" and p[1] != "Low" else "%s set to %s. Your Vineyard manager applies it from today." % [p[0].capitalize(), p[1]]), true)
		"block":
			var q := arg.split(":"); command("block", q[0], q[1], q[2]); notify("Block %s: %s updated." % [q[0], q[1]], true)
		"task3d":
			if view3d == null or not view3d.visible: toggle_3d("")
			if view3d and view3d.has_method("focus_task"): view3d.focus_task(int(arg))
		"taskcrew":
			# "ids:3,4" = the tasks of that message; a bare kind comes from messages saved before ids were carried
			command("task", arg if arg.begins_with("ids:") else "kind:" + arg, "delegate"); notify("The crew takes it over and works to the plan.", true)

func start_game(setup_json: Dictionary) -> void:
	notify("Planting… the Mentor is looking after three years of Establishment.")
	await get_tree().process_frame
	var ok: bool = Sim.NewGame(JSON.stringify(setup_json))
	if not ok:
		notify("Could not start: " + String(Sim.LastError()).left(200)); return
	D = JSON.parse_string(Sim.Snapshot())
	Sim.SaveGame(autosave_slot())
	state.clear()
	_build_chrome()
	show_screen("inbox")

# ------------------------------------------------------------------ navigation
func show_screen(id: String) -> void:
	if id != current: close_learn()
	if not SCREENS.has(id): id = "inbox"
	if not Sim.HasGame() and not (id in PREGAME) and not (id in TASTING): id = "title"
	if id != current and sfx: sfx.play("page")
	if id in TASTING and not (current in TASTING): state.erase("tp_lobby")   # the Timeline, the date or the record may have moved on
	# re-rendering the same screen (after a choice) keeps the scroll position instead of jumping to the top: the old
	# screen stays on top until the new one has its layout and scroll position, so nothing flashes or jumps
	var keep_scroll := -1
	var old_node: Control = null
	var sig := _page_sig(id)
	if id == current and sig == _cur_sig and is_instance_valid(_cur_node):
		keep_scroll = _pending_scroll if _pending_scroll >= 0 else _scroll_pos(_cur_node)
		if keep_scroll > 0: old_node = _cur_node
	var pre: bool = id in PREGAME or (id in TASTING and not Sim.HasGame())
	# switching tabs reuses a screen built for the same game state (fast); a same-screen call always rebuilds it
	var cached: Dictionary = _screen_cache.get(id, {})
	var reuse: bool = id != current and not pre and not (id in TASTING) and not cached.is_empty() and is_instance_valid(cached["node"]) \
		and int(cached["ver"]) == _chrome_ver and String(cached["ret"]) == String(state.get("return_to", ""))
	current = id
	for k in _screen_cache.keys():
		var e: Dictionary = _screen_cache[k]
		var stale: bool = not is_instance_valid(e["node"]) or int(e["ver"]) != _chrome_ver or (k == id and not reuse)
		if stale:
			if is_instance_valid(e["node"]) and e["node"] != old_node: e["node"].queue_free()
			_screen_cache.erase(k)
	for c in host.get_children():
		if _is_cached_node(c): c.visible = reuse and c == cached["node"]
		elif c != old_node: c.queue_free()
	topbar.visible = not pre
	nav_panel.visible = not pre
	statusbar.visible = not pre
	if reuse:
		_cur_node = cached["node"]
		_cur_sig = sig
		_refresh_nav()
		return
	var def: Array = SCREENS[id]
	var mod = load(def[1])
	var node: Control = mod.build(D, self, def[2]) if def[2] != "" else mod.build(D, self)
	if not pre and Sim.HasGame():
		var f := Onboarding.flags(D)
		if not f.has("visited_" + id):
			Sim.Command("flag", "visited_" + id, "", "", "", "")
			(D["flags"] as Array).append("visited_" + id)
			if Onboarding.enabled(D): call_deferred("_refresh_nav_card")
		if Onboarding.enabled(D) and not f.has("intro_" + id):
			var card := Onboarding.intro_card(id, self)
			if card != null:
				var iw := UI.vbox(12); iw.size_flags_vertical = Control.SIZE_EXPAND_FILL
				iw.add_child(card)
				node.size_flags_vertical = Control.SIZE_EXPAND_FILL
				iw.add_child(node)
				node = iw
	if state.get("return_to", "") == "inbox" and id != "inbox" and not pre:
		# came here from a message's action button: offer the way back
		var wrap := UI.vbox(10); wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var bar := UI.hbox(12)
		var back := UI.button("◂  Back to Inbox", true, 15); back.custom_minimum_size = Vector2(0, 38)
		back.pressed.connect(func(): state.erase("return_to"); show_screen("inbox"))
		bar.add_child(back)
		bar.add_child(UI.label("Changes you make here apply straight away; there's nothing to confirm.", 14, UI.INK2))
		wrap.add_child(bar)
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
		wrap.add_child(node)
		node = wrap
	host.add_child(node)
	_cur_node = node
	_cur_sig = sig
	if not pre: _screen_cache[id] = {"node": node, "ver": _chrome_ver, "ret": String(state.get("return_to", ""))}
	if keep_scroll > 0: _restore_scroll(node, keep_scroll, old_node)
	if not pre: _refresh_nav()

## Which page of a screen is on show: a choice on the same page keeps the place; moving on (a pour starting, the answers
## marked, another glass, back to the list) is a new page and starts at the top.
func _page_sig(id: String) -> String:
	return "%s|%s|%s" % [id, state.get("tp_view", ""), state.get("tp_glass", "")]

func _is_cached_node(c: Node) -> bool:
	for e in _screen_cache.values():
		if e["node"] == c: return true
	return false

func _find_scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer and not n.is_queued_for_deletion(): return n
	for c in n.get_children():
		var f := _find_scroll(c)
		if f != null: return f
	return null

func _scroll_pos(n: Node) -> int:
	var s := _find_scroll(n)
	return s.scroll_vertical if s != null else -1

## The new screen is laid out invisibly under the old one; once its scroll position is set it replaces the old one.
func _restore_scroll(n: Control, pos: int, old: Control = null) -> void:
	_pending_scroll = pos
	if old != null:
		n.modulate.a = 0.0
		old.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.move_child(old, -1)
	for f in 2: await get_tree().process_frame
	if is_instance_valid(old): old.queue_free()
	if not is_instance_valid(n): return
	if n == _cur_node: _pending_scroll = -1
	var s := _find_scroll(n)
	if s != null: s.scroll_vertical = pos
	n.modulate.a = 1.0

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo): return
	if learn_layer != null and is_instance_valid(learn_layer) and e.physical_keycode == KEY_ESCAPE:
		close_learn(); get_viewport().set_input_as_handled(); return
	if capture: return
	if view3d != null and view3d.visible: return
	if current in PREGAME or not Sim.HasGame(): return
	var k: int = e.physical_keycode
	if e.ctrl_pressed and k == KEY_S:
		Sim.SaveGame("manual"); notify("Game saved."); return
	if k >= KEY_1 and k <= KEY_9: state.erase("return_to"); show_screen(NAV[k - KEY_1])
	elif k == KEY_0: show_screen("glossary")
	elif k == KEY_TAB: toggle_3d()
	elif current == "inbox" and (k == KEY_UP or k == KEY_DOWN):
		var ids: Array = state.get("inbox_ids", [])
		if ids.is_empty(): return
		var i := ids.find(int(state.get("inbox_current", ids[0])))
		i = clampi(i + (1 if k == KEY_DOWN else -1), 0, ids.size() - 1)
		state["inbox_sel"] = ids[i]
		show_screen("inbox")
		get_viewport().set_input_as_handled()
	elif k == KEY_SPACE: advance(1, false)
	elif k == KEY_P: toggle_play()
	elif k == KEY_M: notify("Sound " + ("on" if sfx.toggle() else "off") + ".")
	elif k == KEY_ENTER or k == KEY_KP_ENTER: advance(continue_days(), true)

# ------------------------------------------------------------------ learn cards (learning-core design §7)
func learn_seen() -> Array:
	if _learn_seen_cache == null:
		var a = JSON.parse_string(Sim.LearnSeenList())
		_learn_seen_cache = a if a is Array else []
	return _learn_seen_cache

## Opens a learn card in the side drawer, replacing any open one. ctx: {plot?, block?, lot?}.
func open_learn(card_id: String, ctx := {}) -> void:
	var keep_state: bool = String(_learn_open[0]) == card_id
	close_learn()
	if not keep_state:
		state.erase("learn_full")
	var J = JSON.parse_string(Sim.LearnCard(card_id, JSON.stringify(ctx)))
	if not (J is Dictionary) or not J.has("id"):
		notify("That card isn't written yet."); return
	_learn_open = [card_id, ctx]
	_learn_seen_cache = null
	learn_layer = load("res://src/ui/learn_drawer.gd").build(self, J)
	add_child(learn_layer)
	_fit_beside_drawer()
	if sfx: sfx.play("page")

func reopen_learn() -> void:
	if String(_learn_open[0]) != "": open_learn(String(_learn_open[0]), _learn_open[1])

func close_learn() -> void:
	if learn_layer != null and is_instance_valid(learn_layer): learn_layer.queue_free()
	learn_layer = null
	_fit_beside_drawer()

## While a learn card is open the screen narrows to the space left of it, so the choice behind the card stays fully
## visible and usable (the rows reflow) instead of running under the card.
func _fit_beside_drawer() -> void:
	var open := learn_layer != null and is_instance_valid(learn_layer)
	var w := get_viewport_rect().size.x
	host.add_theme_constant_override("margin_right", 24 + (int(w * (1.0 - LEARN_DRAWER_AT)) if open else 0))
	if open and not get_viewport().size_changed.is_connected(_fit_beside_drawer): get_viewport().size_changed.connect(_fit_beside_drawer)

# ------------------------------------------------------------------ 3D
## kind "" (Tab or the 3D button) resumes where you left the 3D view; a named place ("vineyard", "hall", "cellar") goes there.
func toggle_3d(kind := "") -> void:
	if playing: toggle_play()          # 2D continuous play and the 3D time-lapse must not run together
	var first := view3d == null
	if view3d == null:
		if not ResourceLoader.exists("res://src/view3d/view3d.tscn"):
			notify("The 3D walkaround isn't installed in this build yet."); return
		view3d = load("res://src/view3d/view3d.tscn").instantiate()
		add_child(view3d)
		if view3d.has_signal("exit_requested"): view3d.exit_requested.connect(func(): _hide_3d())
		if view3d.has_signal("task_chosen"): view3d.task_chosen.connect(_on_task_chosen)
		if view3d.has_signal("advance_requested"): view3d.advance_requested.connect(_on_advance_requested)
		if view3d.has_signal("timelapse_toggled"): view3d.timelapse_toggled.connect(_on_timelapse_toggled)
		view3d.visible = false
	if view3d.visible: _hide_3d(); return
	root_box.visible = false
	view3d.visible = true
	if view3d.has_method("apply_snapshot"): view3d.apply_snapshot(D)
	if view3d.has_method("set_view") and (kind != "" or first): view3d.set_view(kind if kind != "" else "vineyard")

## A staff task done on its demonstration vine / tank in 3D: send it to the sim and redraw the world.
func _on_task_chosen(id: int, value: String, timing: String) -> void:
	var t := {}
	for x in D.get("tasks", []):
		if int(x["id"]) == id: t = x
	command("task", str(id), "do", value, timing, "")
	if view3d and view3d.visible and view3d.has_method("apply_snapshot"): view3d.apply_snapshot(D)
	if t.is_empty(): return
	var label := value
	for o in t.get("options", []):
		if String(o["value"]) == value: label = String(o["label"])
	var place := ("Lot %s" % t["lot"]) if String(t["kind"]) == "CapManagement" else ("Block %s" % t["block"])
	notify("%s · %s: %s. The crew does the rest the same way." % [t["title"], place, label], true)

func _shot3d(name: String, kind: String) -> void:
	if not ResourceLoader.exists("res://src/view3d/view3d.tscn"): return
	if view3d == null or not view3d.visible: toggle_3d(kind)
	elif view3d.has_method("set_view"): view3d.set_view(kind)
	await get_tree().create_timer(5.0).timeout
	await _shot(name)
	_hide_3d()

## The Shop's "Preview in 3D": the 3D winery with one look shown over the one in use, from a camera that sees it.
## Leaving 3D ends the preview; nothing is saved and no cash moves.
var previewing := false
func preview_3d(look: Dictionary, view: String, cam: String) -> void:
	if view3d != null and view3d.visible: _hide_3d()
	toggle_3d(view)
	if view3d == null or not view3d.visible: return
	previewing = true
	if view3d.has_method("set_preview"): view3d.set_preview(look)
	if cam != "" and view3d.has_method("camera_preset"): view3d.camera_preset(cam)

func _hide_3d() -> void:
	if previewing and view3d and view3d.has_method("set_preview"):
		previewing = false
		view3d.set_preview({})
	if view3d: view3d.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	root_box.visible = true
	if stale_2d:                       # days passed in the 3D time-lapse: rebuild the screens once
		stale_2d = false
		Sim.SaveGame(autosave_slot())
		_build_chrome()
		show_screen("report" if tl_report else ("inbox" if tl_alert_id >= 0 else current))
		tl_alert_id = -1
		tl_report = false

## The 3D time-lapse asks for a day: the sim advances (stopping at an Alert) without rebuilding the hidden 2D screens.
## Everything the 2D screens need is decided here, before the frame boundary, so a Tab in between loses nothing.
var stale_2d := false
var tl_alert_id := -1              # the Alert that paused the time-lapse: Tab opens it in the Inbox
var tl_report := false             # a Vintage was fully bottled during the time-lapse: Tab opens its report
var tl_days := 0
func _on_advance_requested(days: int) -> void:
	if busy or not Sim.HasGame(): return
	busy = true
	var before := _alert_ids()
	Sim.Advance(days, true)
	D = JSON.parse_string(Sim.Snapshot())
	stale_2d = true
	tl_days += days
	var subject := ""
	for m in D.get("inbox", []):
		if m.get("stop", false) and not before.has(int(m["id"])):
			subject = String(m["subject"]); tl_alert_id = int(m["id"]); state["inbox_sel"] = tl_alert_id
	# the first time a Vintage is fully bottled its report opens (as advance() does); the flag lives in the save
	var fl: Array = D.get("flags", [])
	for bv in D.get("bottledVintages", []):
		var key := "report_%d" % int(bv)
		if not fl.has(key):
			Sim.Command("flag", key, "", "", "", "")
			D = JSON.parse_string(Sim.Snapshot())
			state["report_vintage"] = int(bv)
			tl_report = true
			if subject == "": subject = "The %d Vintage report is ready" % int(bv)
	if subject != "" or tl_days % 7 == 0:
		Sim.SaveGame(autosave_slot())
	await get_tree().process_frame   # the sim step and the 3D update land in different frames (time-lapse smoothness)
	busy = false
	if view3d == null or not view3d.visible:
		return                        # the view closed in between: _hide_3d already rebuilt the 2D screens
	view3d.apply_snapshot(D)
	if subject != "":
		if sfx: sfx.play("alert")
		view3d.timelapse_alert(subject)

func _on_timelapse_toggled(on: bool) -> void:
	if not on and stale_2d: Sim.SaveGame(autosave_slot())

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and Sim.HasGame() and stale_2d:
		Sim.SaveGame(autosave_slot())      # days passed in the 3D time-lapse since the last save

# ------------------------------------------------------------------ chrome
func _build_chrome() -> void:
	_chrome_ver += 1
	for c in topbar.get_children(): c.queue_free()
	for c in nav_panel.get_children(): c.queue_free()
	for c in statusbar.get_children(): c.queue_free()
	if D.is_empty(): return
	_topbar(); _nav(); _statusbar()

func _topbar() -> void:
	topbar.add_theme_stylebox_override("panel", UI.sb(Color("161c22"), 0, UI.LINE, 0, 20))
	topbar.custom_minimum_size = Vector2(0, 64)
	var h := UI.hbox(10); topbar.add_child(h)
	var est := UI.head(String(D.get("estate", "")), 20, UI.INK); est.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(est)
	h.add_child(UI.spacer())
	var dv := UI.vbox(0)
	var dl := UI.head(String(D.get("dateLabel", "")), 22, UI.INK); dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; dv.add_child(dl)
	var st := UI.label("%s · %s" % [String(D.get("seasonLabel", "")), String(D.get("stage", ""))], 13, UI.INK2); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; dv.add_child(st)
	h.add_child(dv)
	var today: Dictionary = D.get("weather", {}).get("today", {})
	var wx := UI.hbox(4)
	wx.tooltip_text = "Today at Block A: %s–%s °C, %s mm rain, humidity %s %%" % [today.get("tmin", ""), today.get("tmax", ""), today.get("rain", ""), today.get("rh", "")]
	var ic = Charts.WeatherIcon.new(); ic.kind = String(today.get("icon", "sun")); ic.custom_minimum_size = Vector2(40, 40); wx.add_child(ic)
	var wl := UI.num("%s°" % str(roundi(float(today.get("tmax", 0)))), 20, UI.INK); wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER; wx.add_child(wl)
	wx.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(wx)
	# the staff forecast, compact (spec §8.1: weather now + 7-day forecast in the top bar)
	var fc: Array = D.get("weather", {}).get("forecast", [])
	var fh := UI.hbox(0); fh.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for f in fc.slice(1, 7):
		var cell := UI.vbox(0); cell.custom_minimum_size = Vector2(30, 0)
		var holder := Control.new(); holder.custom_minimum_size = Vector2(30, 24)
		var mi = Charts.WeatherIcon.new(); mi.kind = String(f["icon"]); mi.scale = Vector2(0.55, 0.55); mi.size = Vector2(54, 40); mi.position = Vector2(0, 0)
		holder.add_child(mi); cell.add_child(holder)
		var tl := UI.num("%d°" % int(f["tmax"]), 12, UI.INK2); tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cell.add_child(tl)
		cell.tooltip_text = "%s: %d° / %d°, %d %% chance of rain" % [f["day"], int(f["tmax"]), int(f["tmin"]), int(f["prob"])]
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		fh.add_child(cell)
	h.add_child(fh)
	h.add_child(UI.spacer())
	var cash := UI.num(UI.euro(int(D.get("cash", 0))), 22, UI.INK if float(D.get("cash", 0)) >= 0 else UI.CRIT)
	cash.size_flags_vertical = Control.SIZE_SHRINK_CENTER; cash.tooltip_text = "Cash. Open Estate for the P&L."; cash.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(cash)
	for spec in [["+1 day", 1, false, "Advance one day (Space)"], ["+1 week", 7, false, "Advance seven days, even through Alerts"]]:
		var b := UI.button(spec[0]); b.custom_minimum_size = Vector2(0, 40); b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.tooltip_text = spec[3]
		b.pressed.connect(advance.bind(spec[1], spec[2])); h.add_child(b)
	var pb := UI.button("❚❚ Pause" if playing else "▶ Play", playing, 15); pb.custom_minimum_size = Vector2(96, 40); pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.tooltip_text = "Let time run, 4 days a second; stops at the next Alert (P)"
	pb.pressed.connect(toggle_play); h.add_child(pb)
	var cont := UI.button("Continue ▸", true, 16); cont.custom_minimum_size = Vector2(132, 42); cont.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cont.tooltip_text = "Run day by day until the next Alert (Enter)"
	cont.pressed.connect(func(): advance(continue_days(), true))
	h.add_child(cont)
	var unread := int(D.get("unreadAlerts", 0))
	var bell := PanelContainer.new(); bell.add_theme_stylebox_override("panel", UI.sb(UI.CRIT if unread > 0 else UI.RAISED, 14, Color(0, 0, 0, 0), 0, 10))
	bell.add_child(UI.label("⚑ %d" % unread, 16, Color.WHITE, UI.f_body_b)); bell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bell.tooltip_text = "%d unread high-priority messages" % unread
	bell.mouse_filter = Control.MOUSE_FILTER_STOP
	bell.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: show_screen("inbox"))
	h.add_child(bell)
	# a famous-vintage scenario: its chip opens the goals (and the debrief once a Wine of the vintage is judged)
	var SC = JSON.parse_string(Sim.ScenarioStatus())
	if SC is Dictionary and SC.get("scenario") != null:
		var judged: bool = SC.get("judged", false)
		var medal = SC["evaluation"].get("medal") if judged and SC.get("evaluation") != null else null
		var sc := UI.button(("● %s" % String(medal).capitalize()) if medal != null else "◎ %s" % String(SC["scenario"]["title"]), false, 14)
		sc.custom_minimum_size = Vector2(0, 40); sc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sc.tooltip_text = "Famous vintage %s: %s" % [SC["scenario"]["title"], "your medal and the debrief" if judged else "your goals, judged at bottling"]
		sc.pressed.connect(func(): show_screen("scenario")); h.add_child(sc)
		if judged and not SC.get("seen", false) and current != "scenario":
			if playing: playing = false; play_timer.stop(); call_deferred("_build_chrome")   # the Play button must show the stopped clock
			call_deferred("show_screen", "scenario")
	var b3 := UI.button("3D", false, 15); b3.custom_minimum_size = Vector2(52, 40); b3.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b3.tooltip_text = "Walk the vineyard and winery in 3D (Tab)"; b3.pressed.connect(toggle_3d.bind("")); h.add_child(b3)
	var sv := UI.button("Save", false, 15); sv.size_flags_vertical = Control.SIZE_SHRINK_CENTER; sv.custom_minimum_size = Vector2(0, 40)
	sv.tooltip_text = "Save the game (Ctrl+S). The game also autosaves after every time advance."
	sv.pressed.connect(func(): Sim.SaveGame("manual"); notify("Game saved.")); h.add_child(sv)

## Cheap refresh after reading a message: rebuild the top bar and menu badges only.
func _topbar_refresh_count() -> void:
	for c in topbar.get_children(): c.queue_free()
	_topbar()
	_refresh_nav()

func _nav() -> void:
	nav_panel.add_theme_stylebox_override("panel", UI.sb(Color("182026"), 0, Color(0, 0, 0, 0), 0, 0))
	nav_panel.custom_minimum_size = Vector2(216, 0)
	var v := UI.vbox(0); nav_panel.add_child(v)
	v.add_child(UI.spacer(false, 12))
	nav_box = UI.vbox(2); v.add_child(nav_box)
	v.add_child(UI.spacer(false))
	nav_plan = MarginContainer.new()
	for side in ["left", "right", "bottom"]: nav_plan.add_theme_constant_override("margin_" + side, 12)
	v.add_child(nav_plan)
	_refresh_nav_card()
	var plot_card := MarginContainer.new()
	for side in ["left", "right", "bottom"]: plot_card.add_theme_constant_override("margin_" + side, 16)
	var pv := UI.vbox(2); plot_card.add_child(pv)
	var P: Dictionary = D.get("plot", {})
	pv.add_child(UI.head(String(P.get("name", "")), 16, UI.INK))
	pv.add_child(UI.label("%s, %.1f ha" % [P.get("region", ""), float(P.get("ha", 0))], 13, UI.MUTED))
	pv.add_child(UI.label(String(P.get("leaf", "")), 13, UI.MUTED))
	for b in D.get("blocks", []):
		var bh := UI.hbox(6)
		bh.add_child(UI.block_tag(String(b["id"]), 11))
		bh.add_child(UI.label("%s · %s" % [String(b["variety"]), String(b["training"])], 12, UI.INK2))
		bh.tooltip_text = "%s on %s, %s vines/ha, %s" % [b["variety"], b["rootstock"], UI.thousands(int(b["density"])), b["soil"]]
		bh.mouse_filter = Control.MOUSE_FILTER_PASS
		pv.add_child(bh)
	v.add_child(plot_card)

func _refresh_nav_card() -> void:
	if nav_plan == null or not is_instance_valid(nav_plan): return
	for c in nav_plan.get_children(): c.queue_free()
	var card := Onboarding.nav_card(D, self)
	if card != null: nav_plan.add_child(card)

func _refresh_nav() -> void:
	if nav_box == null or not is_instance_valid(nav_box): return
	for c in nav_box.get_children(): c.queue_free()
	var unread := int(D.get("unreadAlerts", 0))
	for i in NAV.size():
		var id: String = NAV[i]
		var active: bool = id == current
		var row := PanelContainer.new()
		var st := UI.sb(UI.RAISED if active else Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 18)
		if active:
			st.border_color = UI.GOLD; st.border_width_left = 4
		row.add_theme_stylebox_override("panel", st)
		row.custom_minimum_size = Vector2(0, 46)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var key_hint := str(i + 1) if i < 9 else ("0" if id == "glossary" else "")
		row.tooltip_text = "%s  (key %s)" % [SCREENS[id][0], key_hint] if key_hint != "" else String(SCREENS[id][0])
		row.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: state.erase("return_to"); show_screen(id))
		var h := UI.hbox(14); row.add_child(h)
		var ic := UI.label(NAV_GLYPH[id], 17, UI.GOLD if active else UI.MUTED); ic.custom_minimum_size = Vector2(20, 0); h.add_child(ic)
		h.add_child(UI.label(SCREENS[id][0], 17, UI.INK if active else UI.INK2, UI.f_body_b if active else null))
		var badge_n := 0
		if id == "inbox": badge_n = unread
		if id == "winery":
			for l in D.get("lots", []):
				if l.get("stuck", false) or String(l.get("phase", "")) == "Received": badge_n += 1
		if id == "blending":
			for l in D.get("lots", []):
				if l.get("ready", false): badge_n += 1
		if id == "shop" and not Onboarding.flags(D).has("visited_shop") and not D.get("shop", {}).is_empty():
			h.add_child(UI.spacer())                       # a gold dot until the first visit (Shop spec §3)
			var dot := UI.label("●", 13, UI.GOLD); dot.tooltip_text = "New: the Shop"; h.add_child(dot)
		if badge_n > 0:
			h.add_child(UI.spacer())
			var badge := PanelContainer.new(); badge.add_theme_stylebox_override("panel", UI.sb(UI.CRIT if id != "blending" else UI.GOLD.darkened(0.3), 9, Color(0, 0, 0, 0), 0, 7))
			badge.add_child(UI.label(str(badge_n), 13, Color.WHITE, UI.f_body_b)); badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(badge)
		nav_box.add_child(row)

func _statusbar() -> void:
	statusbar.add_theme_stylebox_override("panel", UI.sb(Color("161c22"), 0, Color(0, 0, 0, 0), 0, 20))
	statusbar.custom_minimum_size = Vector2(0, 30)
	var h := UI.hbox(28); statusbar.add_child(h)
	var staff: Dictionary = D.get("staff", {})
	var mentor: Dictionary = D.get("mentor", {})
	for txt in [String(D.get("mode", "")), "Vineyard manager: %s" % staff.get("vineyard", {}).get("level", ""), "Cellar master: %s" % staff.get("cellar", {}).get("level", ""),
			("Mentor: %s (retired)" % mentor.get("name", "")) if mentor.get("retired", false) else ("Mentor: %s, retires after bottling" % mentor.get("name", "")), String(D.get("weatherMode", ""))]:
		h.add_child(UI.label(txt, 13, UI.MUTED))
	h.add_child(UI.spacer())
	h.add_child(UI.label("1–0 screens · Space +1 day · P play/pause · Enter Continue · Tab 3D · M sound · Ctrl+S save", 13, UI.MUTED))

func _make_toast() -> void:
	toast = PanelContainer.new()
	toast.add_theme_stylebox_override("panel", UI.sb(Color("11171c"), 6, UI.GOLD.darkened(0.2), 1, 16))
	toast_label = UI.label("", 15, UI.INK, null, true)
	toast.add_child(toast_label)
	toast.position = Vector2(960 - 330, 74)
	toast.custom_minimum_size = Vector2(660, 0)
	toast.visible = false
	add_child(toast)

func _on_node_added(n: Node) -> void:
	if n is BaseButton and not (n is OptionButton):
		(n as BaseButton).pressed.connect(func(): if sfx: sfx.play("click"))

func notify(text: String, ok := false) -> void:
	if ok and sfx: sfx.play("confirm")
	if toast == null or capture: return
	toast.add_theme_stylebox_override("panel", UI.sb(Color("13201a") if ok else Color("11171c"), 6, UI.GOOD if ok else UI.GOLD.darkened(0.2), 2 if ok else 1, 16))
	toast_label.text = ("✓  " if ok else "") + text
	toast.visible = true
	toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): toast.visible = false)

# ------------------------------------------------------------------ capture (plays a real game; also the UI smoke test)
## The current screen scrolled to its end (panels below the fold, e.g. the Winery look).
# ------------------------------------------------------------------ layout check (every harness screenshot)
## Finds the layout bugs the eye used to catch: a wrapped label squeezed into a narrow column (the "vertical letters" bug,
## when a wrapping label sits in a row without SIZE_EXPAND_FILL), or a label with text but no width. Prints one
## "LAYOUT FAIL" line per issue; scripts/check.sh fails the run on any.
func _layout_issues(root: Node) -> Array:
	var out := []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(): stack.append(c)
		if not (n is Label) or not n.is_visible_in_tree(): continue
		var l: Label = n
		var txt := l.text.strip_edges()
		if txt.length() < 8: continue
		var r := l.get_global_rect()
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF and r.size.x < 60.0 and r.size.y > 3.0 * maxf(r.size.x, 1.0):
			out.append("collapsed label (%dx%d) '%s' at %s" % [int(r.size.x), int(r.size.y), txt.left(40), str(l.get_path()).right(60)])
		elif r.size.x < 2.0 and r.size.y > 2.0:
			out.append("label with no width '%s' at %s" % [txt.left(40), str(l.get_path()).right(60)])
	return out

func _layout_lint(shot_name: String) -> void:
	for issue in _layout_issues(self): print("LAYOUT FAIL %s: %s" % [shot_name, issue])

## Self-test (--layoutcheck): a row with a wrapping label that does not expand must be flagged; the fixed row must not.
func _layout_selftest() -> void:
	var ok := true
	for fixed in [false, true]:
		for c in host.get_children(): c.queue_free()
		var row := UI.hbox(8); host.add_child(row)
		row.add_child(UI.button("A button", false, 14))
		var l := UI.label("A long hint text that wraps across the row when there is room for it.", 13, UI.MUTED, null, true)
		if fixed: l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		for f in 5: await get_tree().process_frame
		var n := _layout_issues(row).size()
		print("LAYOUTCHECK %s row: %d issue(s)" % ["fixed" if fixed else "broken", n])
		if (n == 0) != fixed: ok = false
	print("LAYOUTCHECK DONE ok=", ok)
	get_tree().quit()

func _shot_scrolled_to_end(name: String) -> void:
	var sc := _find_scroll(host)
	if sc:
		for f in 3: await get_tree().process_frame
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	await _shot(name)

func _shot(name: String) -> void:
	for f in shot_hold: await get_tree().process_frame
	_layout_lint(name)
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [dir, name]
	img.save_png(path)
	print("saved ", path)

func _run_capture() -> void:
	var args := OS.get_cmdline_user_args()
	var plot := "mosel-blauschiefer"
	var year := 2015
	var i := args.find("--plot"); if i >= 0: plot = args[i + 1]
	i = args.find("--year"); if i >= 0: year = int(args[i + 1])
	var prefix := plot.split("-")[0]
	show_screen("title"); await _shot("%s_00_title" % prefix)
	setup = {}
	show_screen("region"); await _shot("%s_01_region" % prefix)
	setup["region"] = plot.split("-")[0].replace("cotedor", "cote-dor")
	setup["plot"] = plot
	show_screen("plots"); await _shot("%s_02_plots" % prefix)
	setup["year"] = year
	show_screen("planting"); await _shot("%s_03_planting" % prefix)
	setup["estateName"] = "Capture Estate"
	await start_game(load("res://src/ui/screens/pregame.gd").setup_json(self))
	if not Sim.HasGame(): print("NEWGAME FAILED ", Sim.LastError()); get_tree().quit(); return
	await _shot("%s_04_inbox_start" % prefix)
	# read state must survive time passing (bug: Continue made everything unread again)
	command("read", "all")
	var read_ids := {}
	for m in D["inbox"]: read_ids[int(m["id"])] = true
	# exercise the real time controls once (Continue stops at the next Alert)
	advance(60, true)
	var reverted := 0
	for m in D["inbox"]:
		if read_ids.has(int(m["id"])) and not m["read"]: reverted += 1
	print("READ STATE ", "ok" if reverted == 0 else "BROKEN (%d reverted)" % reverted)
	show_screen("inbox"); await _shot("%s_04b_inbox_after_continue" % prefix)
	print("advance ok: ", D["date"], " unread ", D["unreadAlerts"])
	show_screen("programmes"); await _shot("%s_05_programmes" % prefix)
	# spring → summer
	Sim.Advance(170, false); D = JSON.parse_string(Sim.Snapshot()); _build_chrome()
	show_screen("weather"); await _shot("%s_06_weather_june" % prefix)
	show_screen("plot"); await _shot("%s_07_plot_june" % prefix)
	# walk week by week; pick each Block after it has been in the harvest window for three weekly checks
	var in_window := {}
	var ripeness_shot := false
	var guard := 0
	while guard < 30:
		guard += 1
		Sim.Advance(7, false); D = JSON.parse_string(Sim.Snapshot())
		var all_in := true
		for b in D["blocks"]:
			if b["harvested"]: continue
			all_in = false
			if b["picking"]: continue
			if b.get("inWindow", false) or String(b.get("stage", "")) == "Leaf fall":
				in_window[b["id"]] = int(in_window.get(b["id"], 0)) + 1
				if not ripeness_shot:
					_build_chrome(); show_screen("ripeness"); await _shot("%s_08_ripeness" % prefix)
					# learn cards with a real Block in front of the player (site lines from the game's own data)
					for card in ["harvest-date", "green-harvest", "leaf-removal"]:
						open_learn(card, {"block": "A"}); await _shot("%s_card_%s" % [prefix, card])
					close_learn()
					await _shot3d("%s_08b_3d_vineyard" % prefix, "vineyard")
					show_screen("inbox"); await _shot("%s_09_inbox_ripening" % prefix)
					ripeness_shot = true
				if in_window[b["id"]] >= 3 or String(b.get("stage", "")) == "Leaf fall":
					Sim.Command("harvest", b["id"], "hand", "Table", "", "")
		if all_in: break
	_build_chrome()
	show_screen("winery"); await _shot("%s_10_winery_ferment" % prefix)
	await _shot_scrolled_to_end("%s_10a_winery_look" % prefix)
	await _shot3d("%s_10b_3d_hall" % prefix, "hall")
	Sim.Advance(20, false); D = JSON.parse_string(Sim.Snapshot()); _build_chrome()
	show_screen("winery"); await _shot("%s_11_winery_later" % prefix)
	var lots0: Array = D.get("lots", [])
	if lots0.size() > 0:
		for card in ["fermentation-temperature", "yeast-nitrogen", "malolactic", "oak", "lees", "whole-bunch", "stopping-for-sweetness"]:
			open_learn(card, {"lot": String(lots0[0]["id"])}); await _shot("%s_card_%s" % [prefix, card])
		close_learn()
	show_screen("estate"); await _shot("%s_12_estate" % prefix)
	# age and bottle every Lot as it becomes ready
	guard = 0
	while D.get("bottledVintages", []).is_empty() and guard < 40:
		guard += 1
		Sim.Advance(30, false); D = JSON.parse_string(Sim.Snapshot())
		for l in D["lots"]:
			if l.get("ready", false):
				if guard == 1 or not state.has("blend_shot"):
					_build_chrome(); show_screen("blending"); await _shot("%s_13_blending" % prefix); state["blend_shot"] = true
				Sim.Command("wine", "%s %s" % [l["variety"], l["block"]], "Screwcap", "Sterile", "Bentonite", l["id"])
			if l.get("stuck", false): Sim.Command("acceptstuck" if l.get("restarted", false) else "restart", l["id"], "", "", "", "")
		D = JSON.parse_string(Sim.Snapshot())
	_build_chrome()
	show_screen("report"); await _shot("%s_13b_report" % prefix)
	var rsc := _find_scroll(host)
	if rsc: rsc.scroll_vertical = 700
	await _shot("%s_13c_report_lower" % prefix)
	show_screen("wines"); await _shot("%s_14_wines" % prefix)
	show_screen("estate"); await _shot("%s_15_estate_end" % prefix)
	show_screen("glossary"); await _shot("%s_16_glossary" % prefix)
	# the Shop after the first Vintage sold: buy two looks, then the equipment tab
	show_screen("shop"); await _shot("%s_16b_shop" % prefix)
	for it in [["plants", "on"], ["lights", "warm"]]: command("buy", it[0], it[1])
	var use: Dictionary = D.get("shop", {}).get("inUse", {})
	print("SHOP BUY ", "ok" if String(use.get("plants", "")) == "on" and String(use.get("lights", "")) == "warm" else "BROKEN %s" % str(use))
	await _shot("%s_16c_shop_bought" % prefix)
	state["shop_tab"] = "Vineyard & cellar"; show_screen("shop"); await _shot("%s_16d_shop_equipment" % prefix); state.erase("shop_tab")
	# second Vintage: the January message, the history, and a report selector with two Vintages
	for m in D.get("inbox", []):
		if String(m.get("kind", "")) == "newseason": state["inbox_sel"] = int(m["id"])
	_build_chrome(); show_screen("inbox"); await _shot("%s_17_newseason" % prefix)
	guard = 0
	while D.get("bottledVintages", []).size() < 2 and guard < 40:
		guard += 1
		Sim.Advance(30, false); D = JSON.parse_string(Sim.Snapshot())
		for b in D["blocks"]:
			if not b["harvested"] and not b["picking"] and (b.get("inWindow", false) or String(b.get("stage", "")) == "Leaf fall"):
				Sim.Command("harvest", b["id"], "hand", "Table", "", "")
		for l in D["lots"]:
			if l.get("ready", false): Sim.Command("wine", "%s %s" % [l["variety"], l["block"]], "Screwcap", "Sterile", "Bentonite", l["id"])
			if l.get("stuck", false): Sim.Command("acceptstuck" if l.get("restarted", false) else "restart", l["id"], "", "", "", "")
		D = JSON.parse_string(Sim.Snapshot())
	_build_chrome()
	show_screen("estate"); await _shot("%s_18_history" % prefix)
	state["report_vintage"] = int(D["firstVintage"])
	show_screen("report"); await _shot("%s_19_report_selector" % prefix)
	show_screen("winery"); await _shot("%s_20_winery_vintages" % prefix)
	# save → load round trip must reproduce the same state (event-sourced save)
	var cash_before = D["cash"]
	Sim.SaveGame("capture_test")
	var loaded: bool = Sim.LoadGame("capture_test")
	var D2: Dictionary = JSON.parse_string(Sim.Snapshot())
	DirAccess.remove_absolute(String(Sim.SaveDir()).path_join("capture_test.json"))
	print("SAVE/LOAD ", "ok" if loaded and D2["cash"] == cash_before and D2["wines"].size() == D["wines"].size() else "MISMATCH", " cash ", cash_before, " → ", D2["cash"])
	print("CAPTURE DONE phase=", D.get("phase", ""), " wines=", D.get("wines", []).size())
	get_tree().quit()

# ------------------------------------------------------------------ fuzz: press every button on every screen (UI smoke test)
func _collect_buttons(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is BaseButton and (c as Control).is_visible_in_tree() and not (c as BaseButton).disabled: out.append(c)
		_collect_buttons(c, out)

func _fuzz_screen(id: String) -> int:
	var pressed := 0
	for i in 40:
		show_screen(id)
		for f in 2: await get_tree().process_frame
		var btns := []
		_collect_buttons(host, btns)
		if i >= btns.size(): break
		var b: BaseButton = btns[i]
		if b is OptionButton:
			var o := b as OptionButton
			if o.item_count > 1: o.select(o.item_count - 1); o.item_selected.emit(o.item_count - 1)
		elif (b as Button).text.begins_with("Bottle") or (b as Button).text.begins_with("Harvest Block") or "3D" in (b as Button).text or (b as Button).text == "Preview":
			continue   # exercised by the capture run; pressing them here would change the game too early
		else:
			b.pressed.emit()
		pressed += 1
		for f in 2: await get_tree().process_frame
	print("FUZZ ", id, " pressed ", pressed)
	return pressed

func _run_fuzz() -> void:
	setup = {}
	for id in ["region", "plots", "planting"]:
		if id == "plots": setup["region"] = "cote-dor"
		if id == "planting": setup["plot"] = "cotedor-village"
		await _fuzz_screen(id)
	for id in TASTING: await _fuzz_screen(id)            # Tasting practice from the title screen (no game)
	load("res://src/ui/tasting_ui.gd").reset(self)
	setup = {}; setup["region"] = "cote-dor"; setup["plot"] = "cotedor-village"
	show_screen("planting"); await get_tree().process_frame
	await start_game(load("res://src/ui/screens/pregame.gd").setup_json(self))
	for stop_at in [0, 200, 60, 200, 150]:
		if stop_at > 0: Sim.Advance(stop_at, false); D = JSON.parse_string(Sim.Snapshot()); _build_chrome()
		if stop_at == 0: await _fuzz_task3d()     # before the buttons decide the first pruning tasks
		for id in NAV: await _fuzz_screen(id)
		if stop_at == 0:
			for id in ["fair", "cellarbook"]: await _fuzz_screen(id)   # inside a game: later stands locked (ADR 0002)
		print("FUZZ round done at ", D["date"])
	# time controls and keys
	for k in [KEY_SPACE, KEY_ENTER, KEY_2, KEY_0]:
		var e := InputEventKey.new(); e.pressed = true; e.physical_keycode = k; e.keycode = k
		capture = false; _unhandled_input(e); capture = true
		await get_tree().process_frame
	# continuous play runs and stops by itself at an Alert (or keeps going); pause it after 3 s either way
	var d0: String = D["date"]
	play_speed = 4; toggle_play()
	await get_tree().create_timer(3.0).timeout
	print("FUZZ play: ", d0, " → ", D["date"], " still playing=", playing)
	if playing: toggle_play()
	print("FUZZ DONE date=", D["date"], " phase=", D["phase"])
	get_tree().quit()

## The whole shell path of a task done in 3D: the Inbox action opens the view at the vine, the close-up's confirm reaches
## _on_task_chosen and the sim marks the task done by "3d"; then the message's crew button delegates only its own tasks.
func _fuzz_task3d() -> void:
	var first := {}
	for t in D.get("tasks", []):
		if String(t["status"]) == "Open" and String(t["kind"]) == "Prune": first = t; break
	if first.is_empty() or not ResourceLoader.exists("res://src/view3d/view3d.tscn"):
		print("FUZZ task3d skipped (no open pruning task or no 3D view)"); return
	var id := int(first["id"])
	run_action("task3d", str(id))
	for f in 30: await get_tree().process_frame
	var opened: bool = view3d.call("_interact")
	view3d.call("_choose", String(first["plan"]))
	view3d.call("_confirm")
	await get_tree().create_timer(1.6).timeout
	var st := ""
	for t in D.get("tasks", []):
		if int(t["id"]) == id: st = "%s/%s" % [t["status"], t.get("decidedBy", "")]
	print("FUZZ task3d %s (opened=%s, task %d → %s)" % ["ok" if opened and st == "Done/3d" else "FAIL", opened, id, st])
	# the time-lapse through the real shell: days pass, the 2D screens show the new date after leaving the view
	var d0 := String(D["date"])
	view3d.call("timelapse_speed", 1)
	view3d.call("timelapse_set", true)
	await get_tree().create_timer(3.5).timeout
	view3d.call("timelapse_set", false)
	var d1 := String(D["date"])
	if view3d.visible: toggle_3d("")
	for f in 3: await get_tree().process_frame
	var shown := false
	for l in host.find_children("*", "Label", true, false):
		if String((l as Label).text).contains(String(D.get("dateLabel", "?"))): shown = true
	for l in topbar.find_children("*", "Label", true, false):
		if String((l as Label).text).contains(String(D.get("dateLabel", "?"))): shown = true
	print("FUZZ timelapse %s (%s → %s, new date shown after leaving: %s)" % ["ok" if d1 > d0 and shown else "FAIL", d0, d1, shown])
	# 2D play stops when the 3D view opens; the time-lapse runs until an Alert; leaving opens the Inbox on it
	toggle_play()
	toggle_3d("")
	var play_ok := not playing
	for f in 20: await get_tree().process_frame
	view3d.call("timelapse_speed", 2)
	view3d.call("timelapse_set", true)
	var waited := 0.0
	while String(view3d.get("tl_note")) == "" and waited < 60.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	var note := String(view3d.get("tl_note"))
	var sel := int(state.get("inbox_sel", -1))
	toggle_3d("")
	for f in 3: await get_tree().process_frame
	var inbox_ok := current in ["inbox", "report"] and note != ""
	var sel_ok := false
	for m in D.get("inbox", []):
		if int(m["id"]) == sel and m.get("stop", false): sel_ok = true
	print("FUZZ timelapse_alert %s (play stopped %s, paused on '%s', screen %s, alert selected %s)" % ["ok" if play_ok and inbox_ok and (sel_ok or current == "report") else "FAIL", play_ok, note, current, sel_ok])
	var arg := ""
	for m in D.get("inbox", []):
		for a in m.get("actions", []):
			if String(a["action"]) == "taskcrew": arg = String(a["arg"])
	if arg == "":
		print("FUZZ taskcrew skipped (no message with a crew action)"); return
	var ids := arg.trim_prefix("ids:").split(",")
	run_action("taskcrew", arg)
	var left := 0
	for t in D.get("tasks", []):
		if str(int(t["id"])) in ids and String(t["status"]) == "Open": left += 1
	print("FUZZ taskcrew %s (%d of the message's tasks still open)" % ["ok" if left == 0 else "FAIL", left])

# ------------------------------------------------------------------ Tasting practice harness (--practice)
## Pours, answers and marks in Tasting practice and at a Wine Fair stand through the real screens, leaves mid-pour and comes
## back, checks that a second Pour press does not pour twice, and that the study record file is written.
func _wait_view(view: String, owner: String, timeout := 30.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while String(state.get("tp_view", "")) != view:
		if Time.get_ticks_msec() - t0 > timeout * 1000.0: return false
		if current != owner: show_screen(owner)
		await get_tree().create_timer(0.1).timeout
	return true

func _fill_from_sheet(gi: int, right_every := 1) -> void:
	# answers taken from the Wine's own sheet (every right_every-th item; the rest one step off or wrong)
	var S: Dictionary = state["tp_session"]
	var G: Dictionary = S["glasses"][gi]
	var KEY = JSON.parse_string(Sim.PracticeDebugKey())   # harness only: the screens never see the answers before marking
	var W: Dictionary = KEY["wines"][gi]; var sh: Dictionary = W["sheet"]
	var pal := {}
	for p in sh["palate"]: pal[String(p["attribute"])] = String(p["level"]).split(",")[0]
	var actual := {"clarity": sh["appearance"]["clarity"], "colourIntensity": sh["appearance"]["intensity"], "colour": sh["appearance"]["colour"],
		"noseIntensity": sh["nose"]["intensity"], "development": sh["nose"]["development"], "sweetness": pal.get("Sweetness", ""), "acidity": pal.get("Acidity", ""),
		"tannin": pal.get("Tannin", ""), "alcohol": pal.get("Alcohol", ""), "body": pal.get("Body", ""), "flavourIntensity": sh["palate"].filter(func(x): return x["attribute"] == "Flavour intensity")[0]["level"] if true else "",
		"finish": sh["palate"].filter(func(x): return x["attribute"] == "Finish")[0]["level"], "quality": sh["quality"], "readiness": sh["readiness"], "fruitRipeness": sh.get("fruitRipeness", ""),
		"variety": W["context"]["variety"], "region": W["context"]["regionName"], "climate": "moderate"}
	var a: Dictionary = state["tp_answers"]["wines"][gi]
	var conf := {}
	a["confidence"] = conf
	var i := 0
	for k in G["keys"]:
		conf[String(k)] = 3 if i % 3 != 2 else 1
		var key := String(k)
		if i % right_every == 0:
			if key == "aromas":
				var fams := []
				for ar in sh["aromas"]: if not (String(ar["family"]) in fams): fams.append(String(ar["family"]))
				if sh.get("simple", false): fams.append("simple")
				a["aromas"] = fams
			elif key == "flavours":
				a["flavours"] = sh.get("flavours", []).duplicate()
			elif key.begins_with("blic."):
				var crit := key.substr(5)
				for b in sh["blic"]: if String(b["criterion"]) == crit: a["blic"] = a.get("blic", {}); a["blic"][crit] = b["met"]
			elif actual.has(key): a[key] = String(actual[key])
		i += 1

func _practice_test() -> void:
	var T = load("res://src/ui/tasting_ui.gd")
	var ok := true
	show_screen("practice"); await _shot("practice_01_lobby")
	# a Cause-to-glass glass; a second press while pouring must not start another pour
	T.start_pour(self, {"kind": "practice", "exercise": "cause", "seed": 3}, "practice")
	var job := int(state.get("tp_job", 0))
	T.start_pour(self, {"kind": "practice", "exercise": "cause", "seed": 4}, "practice")
	if int(state.get("tp_job", 0)) != job: ok = false; print("PRACTICE FAIL double pour")
	await _shot("practice_02_pouring")
	# leave mid-pour and come back: the same pour arrives
	show_screen("title")
	await get_tree().create_timer(0.3).timeout
	if not await _wait_view("answer", "practice"): ok = false; print("PRACTICE FAIL no glass after leaving mid-pour")
	if int(state.get("tp_job", 0)) != job: ok = false; print("PRACTICE FAIL job changed")
	show_screen("practice"); await _shot("practice_03_cause")
	_fill_from_sheet(0, 2)
	show_screen("practice"); await _shot("practice_04_cause_answered")
	T.mark(self, "practice")
	await _shot("practice_05_reveal")
	var R: Dictionary = state.get("tp_result", {})
	print("PRACTICE cause marks ", R.get("total"), "/", R.get("max"), " xp +", R.get("xpGained"))
	var rec_ok := FileAccess.file_exists(Sim.RecordFile())
	var S1 = JSON.parse_string(Sim.PracticeSummary())
	if not rec_ok or int(S1.get("xp", 0)) <= 0: ok = false; print("PRACTICE FAIL record not written ", Sim.RecordFile())
	# the other exercises, one glass each, answered from the sheet
	for ex in ["conclusions", "identify", "sheet"]:
		T.reset(self)
		T.start_pour(self, {"kind": "practice", "exercise": ex, "seed": 5}, "practice")
		if not await _wait_view("answer", "practice"): ok = false; print("PRACTICE FAIL ", ex); continue
		_fill_from_sheet(0, 1)
		show_screen("practice"); await _shot("practice_06_%s" % ex)
		T.mark(self, "practice")
		var r: Dictionary = state.get("tp_result", {})
		print("PRACTICE ", ex, " marks ", r.get("total"), "/", r.get("max"))
	# the Glass of the day
	T.reset(self)
	T.start_pour(self, {"kind": "daily"}, "practice")
	if await _wait_view("answer", "practice"):
		T.mark(self, "practice")
		var S2 = JSON.parse_string(Sim.PracticeSummary())
		if not S2.get("dailyDone", false): ok = false; print("PRACTICE FAIL daily not recorded")
	else: ok = false; print("PRACTICE FAIL daily")
	T.reset(self)
	# the Wine Fair: the 2016 frost stand
	show_screen("fair"); await _shot("practice_10_fair")
	T.start_pour(self, {"kind": "stand", "stand": "frost-2016", "seed": 2}, "fair")
	if not await _wait_view("answer", "fair"): ok = false; print("PRACTICE FAIL stand")
	else:
		var S: Dictionary = state["tp_session"]
		for gi in S["glasses"].size(): _fill_from_sheet(gi, 2)
		show_screen("fair"); await _shot("practice_11_stand")
		state["tp_glass"] = S["glasses"].size()
		for q in S["quiz"]:
			state["tp_answers"]["quiz"][String(q["topic"])] = "Glass 2"
			state["tp_answers"]["quizConfidence"][String(q["topic"])] = 2
		show_screen("fair"); await _shot("practice_12_quiz")
		T.mark(self, "fair")
		var r: Dictionary = state.get("tp_result", {})
		print("PRACTICE stand ", r.get("percent"), " % medal ", r.get("medal"), " new cards ", r.get("newCards"))
		await _shot("practice_13_stand_reveal")
		await _shot_scrolled_to_end("practice_14_stand_reveal_end")
		if r.get("newCards", []).size() != 3: ok = false; print("PRACTICE FAIL cards")
	T.reset(self)
	show_screen("fair"); await _shot("practice_15_fair_after")
	show_screen("cellarbook"); await _shot("practice_16_cellar_book")
	show_screen("title"); await _shot("practice_17_title")
	print("PRACTICE DONE ok=", ok)
	get_tree().quit()

# ------------------------------------------------------------------ famous-vintages harness (--scenarios)
## The list and briefing from the title screen, a scenario game's goals, the scripted player to bottling, then the debrief
## and the list again with the medal earned.
func _scenario_test() -> void:
	var ok := true
	show_screen("title"); await _shot("scenarios_00_title")
	show_screen("scenarios"); await _shot("scenarios_01_list")
	state["scn_id"] = "mosel-2018"
	show_screen("scenario_brief"); await _shot("scenarios_02_brief")
	if not Sim.NewScenarioGame("mosel-2018"): ok = false; print("SCENARIOS FAIL start")
	state.clear(); current = ""; refresh()
	show_screen("scenario"); await _shot("scenarios_03_goals")
	Sim.ScenarioAutoplay(75, JSON.stringify({"Sweetness": 2}))
	refresh()
	await get_tree().process_frame
	if current != "scenario": ok = false; print("SCENARIOS FAIL debrief did not open")
	var St = JSON.parse_string(Sim.ScenarioStatus())
	print("SCENARIOS mosel-2018 judged ", St.get("judged"), " medal ", St["evaluation"].get("medal") if St.get("evaluation") != null else null)
	if not St.get("judged", false) or St["evaluation"].get("medal") != "gold": ok = false; print("SCENARIOS FAIL expected gold")
	show_screen("scenario"); await _shot("scenarios_04_debrief")
	await _shot_scrolled_to_end("scenarios_05_debrief_end")
	var List = JSON.parse_string(Sim.ScenarioList())
	for it in List: if String(it["scenario"]["id"]) == "mosel-2018" and it.get("best") != "gold": ok = false; print("SCENARIOS FAIL medal not kept")
	show_screen("inbox"); await _shot("scenarios_06_topbar")
	state["report_vintage"] = 2018
	refresh(); show_screen("report"); await _shot("scenarios_08_review")
	show_screen("scenarios"); await _shot("scenarios_07_list_after")
	print("SCENARIOS DONE ok=", ok)
	get_tree().quit()

# ------------------------------------------------------------------ learning-core harness (--learning)
## Today's session through the real screen: chain, Wine and contrast entries answered right and wrong with different
## Confidences, the four-case reveal and the recap, the record's Cause states, then the Progress view.
func _learning_test() -> void:
	var T = load("res://src/ui/tasting_ui.gd")
	var ok := true
	show_screen("practice"); await _shot("learning_01_lobby")
	T.start_pour(self, {"kind": "session", "seed": 11}, "practice")
	if not await _wait_view("answer", "practice"): print("LEARNING FAIL no session"); get_tree().quit(); return
	var S: Dictionary = state["tp_session"]
	var kinds := {}
	for e in S["entries"]: kinds[String(e["kind"])] = true
	print("LEARNING entries ", S["entries"].size(), " kinds ", kinds.keys())
	show_screen("practice"); await _shot("learning_02_session")
	await _shot_scrolled_to_end("learning_03_session_end")
	var KEY = JSON.parse_string(Sim.PracticeDebugKey())
	var A: Dictionary = state["tp_answers"]
	for i in S["entries"].size():
		var E: Dictionary = S["entries"][i]
		var e := {"answers": [], "confidence": []}
		for j in E["questions"].size():
			var right: String = KEY["entries"][i]["answers"][j]
			var wrong := right
			for o in E["questions"][j]["options"]: if String(o) != right: wrong = String(o); break
			e["answers"].append(right if i % 2 == 0 else wrong)
			e["confidence"].append([3, 3, 1, 2][i % 4])
		A["entries"][i] = e
	show_screen("practice"); await _shot("learning_04_answered")
	T.mark(self, "practice")
	var R: Dictionary = state.get("tp_result", {})
	var cases := {}
	for e in R.get("entries", []):
		for it in e["items"]: cases[String(it["case"])] = true
	print("LEARNING marks ", R.get("total"), "/", R.get("max"), " cases ", cases.keys())
	if not (cases.has("sure-right") and cases.has("sure-wrong")): ok = false; print("LEARNING FAIL cases")
	await _shot("learning_05_reveal")
	await _shot_scrolled_to_end("learning_06_reveal_end")
	var f := FileAccess.open(Sim.RecordFile(), FileAccess.READ)
	var rec = JSON.parse_string(f.get_as_text()) if f else {}
	if f: f.close()   # an open handle would block the next save on Windows
	var n: int = rec.get("causes", {}).size() if rec is Dictionary else 0
	print("LEARNING record causes ", n)
	if n < S["entries"].size(): ok = false; print("LEARNING FAIL record")
	T.reset(self)
	# the queue over the next days: sessions on day 1, 4 and 11, everything answered right and sure; by then mature Causes
	# come back as Wines and contrast pairs, not chains
	var d0 := Time.get_date_dict_from_system()
	var base := Time.get_unix_time_from_datetime_dict(d0)
	var final_kinds := {}
	for day in [1, 4, 11]:
		Sim.SetPracticeToday(Time.get_date_string_from_unix_time(base + day * 86400))
		T.start_pour(self, {"kind": "session", "seed": 20 + day}, "practice")
		if not await _wait_view("answer", "practice"): ok = false; print("LEARNING FAIL day ", day); break
		var S2: Dictionary = state["tp_session"]
		var K2 = JSON.parse_string(Sim.PracticeDebugKey())
		final_kinds = {}
		for i in S2["entries"].size():
			final_kinds[String(S2["entries"][i]["kind"])] = true
			var conf := []
			for j in S2["entries"][i]["questions"].size(): conf.append(3)
			state["tp_answers"]["entries"][i] = {"answers": K2["entries"][i]["answers"], "confidence": conf}
		if day == 11:
			show_screen("practice"); await _shot("learning_07_day11_session")
			await _shot_scrolled_to_end("learning_08_day11_session_end")
		T.mark(self, "practice")
		print("LEARNING day ", day, " kinds ", final_kinds.keys(), " known gained ", state.get("tp_result", {}).get("knownGained"))
		if day == 11: await _shot("learning_09_day11_reveal")
		T.reset(self)
	if not (final_kinds.has("wine") or final_kinds.has("contrast")): ok = false; print("LEARNING FAIL no wine items by day 11")
	state.erase("tp_lobby")
	show_screen("practice"); await _shot_scrolled_to_end("learning_10_progress")
	# exam date: the sim refuses a past date; a valid one shows as days to go
	if String(Sim.PracticeSetExamDate("2020-01-01")) == "": ok = false; print("LEARNING FAIL past exam date accepted")
	var exam := Time.get_date_string_from_unix_time(base + 90 * 86400)
	var err := String(Sim.PracticeSetExamDate(exam))
	if err != "": ok = false; print("LEARNING FAIL exam date ", err)
	state.erase("tp_lobby")
	var es = T.lobby(self).get("summary", {}).get("daysToExam", null)
	print("LEARNING exam ", exam, " days to go ", es)
	if es == null or int(es) != 79: ok = false; print("LEARNING FAIL days to exam")
	show_screen("practice"); await _shot_scrolled_to_end("learning_11_exam")
	Sim.PracticeSetExamDate(""); state.erase("tp_lobby")
	Sim.SetPracticeToday("")
	# every learn card in the drawer, with a Block's context (pre-game: no Lot), plus the turntable in winter
	var ids := ["training-system", "rootstock", "harvest-date", "leaf-removal", "green-harvest", "whole-bunch", "fermentation-temperature",
		"yeast-nitrogen", "malolactic", "oak", "lees", "stopping-for-sweetness"]
	for id in ids:
		open_learn(id, {"plot": "cotedor-village", "block": "A"})
		if learn_layer == null: ok = false; print("LEARNING FAIL card ", id); continue
		await _shot("learning_card_%s" % id)
	state["learn_season"] = "Winter"; state["learn_training"] = "Einzelpfahl"
	open_learn("training-system", {"plot": "mosel-terrassen", "block": "A"}); await _shot("learning_card_training_winter")
	close_learn()
	print("LEARNING DONE ok=", ok)
	get_tree().quit()

# ------------------------------------------------------------------ avatar contact sheet (visual check)
func _avatar_sheet() -> void:
	var g := GridContainer.new(); g.columns = 7; g.position = Vector2(40, 40)
	g.add_theme_constant_override("h_separation", 24); g.add_theme_constant_override("v_separation", 24)
	add_child(g)
	var people := [["Lukas Brandt", "vineyard"], ["Anja Meurer", "vineyard"], ["Heinz Schäfer", "vineyard"], ["Marie Kessler", "cellar"], ["Tobias Hahn", "cellar"], ["Ursula Lenz", "cellar"], ["Klaus Weber", "mentor"],
		["Théo Garnier", "vineyard"], ["Claire Dumont", "vineyard"], ["Jean-Marc Rivière", "vineyard"], ["Léa Fontaine", "cellar"], ["Hugo Bernard", "cellar"], ["Sylvie Moreau", "cellar"], ["Hélène Morot", "mentor"],
		["Diego Morales", "vineyard"], ["Kate Sullivan", "vineyard"], ["Walt Henning", "vineyard"], ["Priya Nair", "cellar"], ["Ben Carter", "cellar"], ["Linda Okafor", "cellar"], ["Ray Castellanos", "mentor"]]
	for p in people:
		var v := UI.vbox(4)
		v.add_child(load("res://src/ui/avatar.gd").make(p[0], p[1], 150))
		v.add_child(UI.label(p[0], 14, UI.INK2))
		g.add_child(v)
	var small := UI.hbox(10); small.position = Vector2(40, 700); add_child(small)
	for p in people.slice(0, 7): small.add_child(load("res://src/ui/avatar.gd").make(p[0], p[1], 36))
	await _shot("avatars")
	get_tree().quit()

## The scroll position of the screen the player sees (the top one; a replacement waits invisibly under it).
func _shown_scroll() -> int:
	var kids := host.get_children()
	kids.reverse()
	for c in kids:
		if c is Control and (c as Control).visible and (c as Control).modulate.a > 0.5 and not c.is_queued_for_deletion():
			return _scroll_pos(c)
	return -1

func _pregame_shots() -> void:
	show_screen("region"); await _shot("pre_region")
	setup = {"region": "mosel", "plot": "mosel-blauschiefer"}
	for tab in ["Varieties", "Rootstocks", "Training", "Density & rows"]:
		setup["guide_tab"] = tab
		show_screen("planting")
		for f in 3: await get_tree().process_frame       # past the kept scroll position of the screen it replaces
		var sc := _find_scroll(host)
		if sc: sc.scroll_vertical = 420
		await _shot("pre_planting_" + tab.get_slice(" ", 0).to_lower())
		if tab == "Training":
			if sc: sc.scroll_vertical = 900
			await _shot("pre_planting_training_vsp")
	# choosing an option (a staff level, a dropdown) keeps the scroll position: no jump to the top
	var ok := true
	setup = {"region": "napa", "plot": "napa-carneros"}
	show_screen("planting")
	for f in 3: await get_tree().process_frame
	for pick in ["Senior", "variety"]:
		var sc2 := _find_scroll(host)
		sc2.scroll_vertical = 700
		await get_tree().process_frame
		var before := sc2.scroll_vertical
		var btns := []
		_collect_buttons(host, btns)
		for b in btns:
			if pick == "Senior" and b is Button and (b as Button).text == "Senior":
				b.emit_signal("pressed"); break
			if pick == "variety" and b is OptionButton and (b as OptionButton).item_count > 3:
				(b as OptionButton).select(1); b.emit_signal("item_selected", 1); break
		var seen := []
		for f in 4:
			await get_tree().process_frame
			seen.append(_shown_scroll())
		var kept := before > 0 and seen.all(func(y): return absi(int(y) - before) <= 1)
		ok = ok and kept
		print("PREGAME scroll_kept_%s %s (%d → %s)" % [pick, "ok" if kept else "FAIL", before, str(seen)])
	# Carneros: the Learn drawers opened from a Block's row (rootstock, and the training systems winter and summer)
	setup = {"region": "napa", "plot": "napa-carneros"}
	show_screen("planting"); await get_tree().process_frame
	open_learn("rootstock", {"plot": "napa-carneros", "block": "A"}); await _shot("pre_learn_rootstock")
	for kind in ["Guyot", "Cordon", "Einzelpfahl"]:
		for season in ["Winter", "Spring", "Summer"]:
			state["learn_training"] = kind; state["learn_season"] = season
			open_learn("training-system", {"plot": "napa-carneros", "block": "A"})
			for f in 30: await get_tree().process_frame
			await _shot("pre_learn_training_%s_%s" % [kind.to_lower(), season.to_lower()])
	# a close look at the Guyot fruit zone in summer (the model's camera moved by hand)
	state["learn_training"] = "Guyot"; state["learn_season"] = "Summer"
	open_learn("training-system", {"plot": "napa-carneros", "block": "A"})
	await get_tree().process_frame
	for m in learn_layer.find_children("*", "VBoxContainer", true, false):
		if m.get_script() == load("res://src/ui/training_model.gd"):
			m.auto = false; m.yaw = 0.35; m.pitch = -0.05; m.dist = 1.5; m.target = Vector3(0.35, 0.95, 0)
	for f in 20: await get_tree().process_frame
	await _shot("pre_learn_training_guyot_fruitzone")
	close_learn()
	for spec in [["mosel", "mosel-blauschiefer", "mosel-uferflur"], ["cote-dor", "cotedor-village", ""], ["napa", "napa-mountain", "napa-floor"]]:
		setup = {"region": spec[0], "plot": spec[1], "compare": spec[2]}
		show_screen("plots")
		await get_tree().create_timer(2.0).timeout
		await _shot("pre_plots_" + spec[1])
	print("PREGAME DONE ok=%s" % ok)
	get_tree().quit()

# ------------------------------------------------------------------ perf probe: snapshot, parse and screen build times
func _perf() -> void:
	Sim.NewGame(JSON.stringify({"plotId": "mosel-blauschiefer", "plantingYear": 2015, "seed": 7}))
	Sim.Advance(270, false)
	for b in JSON.parse_string(Sim.Snapshot())["blocks"]: Sim.Command("harvest", b["id"], "hand", "Table", "", "")
	Sim.Advance(200, false)
	var t := Time.get_ticks_usec(); var js := ""
	for i in 10: js = Sim.Snapshot()
	print("PERF snapshot %.1f ms (%d KB)" % [(Time.get_ticks_usec() - t) / 10000.0, js.length() / 1024])
	t = Time.get_ticks_usec()
	for i in 10: D = JSON.parse_string(js)
	print("PERF parse %.1f ms" % ((Time.get_ticks_usec() - t) / 10000.0))
	t = Time.get_ticks_usec()
	for i in 5: _build_chrome()
	print("PERF chrome %.1f ms" % ((Time.get_ticks_usec() - t) / 5000.0))
	for id in NAV:
		var tb := 0; var tf := 0
		for i in 5:
			t = Time.get_ticks_usec()
			show_screen(id)
			tb += Time.get_ticks_usec() - t
			t = Time.get_ticks_usec()
			await get_tree().process_frame
			tf += Time.get_ticks_usec() - t
		print("PERF screen %-10s build %.1f ms · first frame %.1f ms" % [id, tb / 5000.0, tf / 5000.0])
	# tab hopping with an unchanged game state should reuse the cached screens
	var th := Time.get_ticks_usec()
	for rep_i in 3:
		for id in NAV:
			show_screen(id)
			await get_tree().process_frame
	print("PERF tab switch (cached) %.1f ms per switch" % ((Time.get_ticks_usec() - th) / 1000.0 / (3 * NAV.size())))
	get_tree().quit()
