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
	"ripeness": ["Ripeness", "res://src/ui/screens/ripeness.gd", ""],
	"winery": ["Winery", "res://src/ui/screens/winery.gd", ""],
	"blending": ["Blending", "res://src/ui/screens/blending.gd", ""],
	"wines": ["Wines", "res://src/ui/screens/wines.gd", ""],
	"glossary": ["Glossary", "res://src/ui/screens/glossary.gd", ""],
	"report": ["Vintage report", "res://src/ui/screens/report.gd", ""],
}
const NAV := ["inbox", "estate", "plot", "weather", "programmes", "ripeness", "winery", "blending", "wines", "glossary"]
const NAV_GLYPH := {"inbox": "▤", "estate": "◆", "plot": "▦", "weather": "☁", "programmes": "≡", "ripeness": "◔",
	"winery": "▥", "blending": "⋈", "wines": "✦", "glossary": "?"}
const PREGAME := ["title", "region", "plots", "planting"]

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

func _ready() -> void:
	theme = UI.make_theme()
	var args := OS.get_cmdline_user_args()
	capture = "--capture" in args
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
	if capture: sfx.enabled = false
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

## Advance time. stop=true runs until the next Alert (max `days`).
func advance(days: int, stop := true, quiet := false) -> bool:
	if busy or not Sim.HasGame(): return false
	busy = true
	var before := _alert_ids()
	var n: int = Sim.Advance(days, stop)
	D = JSON.parse_string(Sim.Snapshot())
	Sim.SaveGame("autosave")
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
		"goto": state["return_to"] = "inbox"; show_screen(arg)
		"harvest":
			state["return_to"] = "inbox"
			state["plot_sel"] = arg
			show_screen("plot")
			notify("Choose how to pick Block %s, then press Harvest." % arg)
		"restart": command("restart", arg)
		"spraynow": command("spraynow"); notify("Extra spray pass ordered for today — advance a day to carry it out.")
		"acceptstuck": command("acceptstuck", arg); notify("Fermentation stopped; the Lot keeps its residual sugar.")
		"programme":
			var p := arg.split(":"); command("programme", p[0], p[1]); notify("%s set to %s. Your Vineyard manager applies it from today." % [p[0].capitalize(), p[1]], true)
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
	Sim.SaveGame("autosave")
	state.clear()
	_build_chrome()
	show_screen("inbox")

# ------------------------------------------------------------------ navigation
func show_screen(id: String) -> void:
	if not SCREENS.has(id): id = "inbox"
	if not Sim.HasGame() and not (id in PREGAME): id = "title"
	if id != current and sfx: sfx.play("page")
	# re-rendering the same screen (after a choice) keeps the scroll position instead of jumping to the top
	var cur_e: Dictionary = _screen_cache.get(current, {})
	var keep_scroll := -1
	if id == current and not cur_e.is_empty() and is_instance_valid(cur_e["node"]): keep_scroll = _scroll_pos(cur_e["node"])
	var pre: bool = id in PREGAME
	# switching tabs reuses a screen built for the same game state (fast); a same-screen call always rebuilds it
	var cached: Dictionary = _screen_cache.get(id, {})
	var reuse: bool = id != current and not pre and not cached.is_empty() and is_instance_valid(cached["node"]) \
		and int(cached["ver"]) == _chrome_ver and String(cached["ret"]) == String(state.get("return_to", ""))
	current = id
	for k in _screen_cache.keys():
		var e: Dictionary = _screen_cache[k]
		var stale: bool = not is_instance_valid(e["node"]) or int(e["ver"]) != _chrome_ver or (k == id and not reuse)
		if stale:
			if is_instance_valid(e["node"]): e["node"].queue_free()
			_screen_cache.erase(k)
	for c in host.get_children():
		if _is_cached_node(c): c.visible = reuse and c == cached["node"]
		else: c.queue_free()
	topbar.visible = not pre
	nav_panel.visible = not pre
	statusbar.visible = not pre
	if reuse:
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
	if not pre: _screen_cache[id] = {"node": node, "ver": _chrome_ver, "ret": String(state.get("return_to", ""))}
	if keep_scroll > 0: _restore_scroll(node, keep_scroll)
	if not pre: _refresh_nav()

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

func _restore_scroll(n: Node, pos: int) -> void:
	for f in 2: await get_tree().process_frame
	if not is_instance_valid(n): return
	var s := _find_scroll(n)
	if s != null: s.scroll_vertical = pos

func _unhandled_input(e: InputEvent) -> void:
	if capture or not (e is InputEventKey and e.pressed and not e.echo): return
	if view3d != null and view3d.visible: return
	if current in PREGAME: return
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

# ------------------------------------------------------------------ 3D
## kind "" (Tab or the 3D button) resumes where you left the 3D view; a named place ("vineyard", "hall", "cellar") goes there.
func toggle_3d(kind := "") -> void:
	var first := view3d == null
	if view3d == null:
		if not ResourceLoader.exists("res://src/view3d/view3d.tscn"):
			notify("The 3D walkaround isn't installed in this build yet."); return
		view3d = load("res://src/view3d/view3d.tscn").instantiate()
		add_child(view3d)
		if view3d.has_signal("exit_requested"): view3d.exit_requested.connect(func(): _hide_3d())
		if view3d.has_signal("task_chosen"): view3d.task_chosen.connect(_on_task_chosen)
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

func _hide_3d() -> void:
	if view3d: view3d.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	root_box.visible = true

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
		row.tooltip_text = "%s  (key %s)" % [SCREENS[id][0], str((i + 1) % 10)]
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
func _shot_scrolled_to_end(name: String) -> void:
	var sc := _find_scroll(host)
	if sc:
		for f in 3: await get_tree().process_frame
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	await _shot(name)

func _shot(name: String) -> void:
	for f in 10: await get_tree().process_frame
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
		elif (b as Button).text.begins_with("Bottle") or (b as Button).text.begins_with("Harvest Block") or "3D" in (b as Button).text:
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
	setup = {}; setup["region"] = "cote-dor"; setup["plot"] = "cotedor-village"
	show_screen("planting"); await get_tree().process_frame
	await start_game(load("res://src/ui/screens/pregame.gd").setup_json(self))
	for stop_at in [0, 200, 60, 200, 150]:
		if stop_at > 0: Sim.Advance(stop_at, false); D = JSON.parse_string(Sim.Snapshot()); _build_chrome()
		if stop_at == 0: await _fuzz_task3d()     # before the buttons decide the first pruning tasks
		for id in NAV: await _fuzz_screen(id)
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
	if view3d.visible: toggle_3d("")
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

func _pregame_shots() -> void:
	show_screen("region"); await _shot("pre_region")
	setup = {"region": "mosel", "plot": "mosel-blauschiefer"}
	for tab in ["Varieties", "Rootstocks", "Training", "Density & rows"]:
		setup["guide_tab"] = tab
		show_screen("planting"); await get_tree().process_frame
		var sc := _find_scroll(host)
		if sc: sc.scroll_vertical = 420
		await _shot("pre_planting_" + tab.get_slice(" ", 0).to_lower())
	for spec in [["mosel", "mosel-blauschiefer", "mosel-uferflur"], ["cote-dor", "cotedor-village", ""], ["napa", "napa-mountain", "napa-floor"]]:
		setup = {"region": spec[0], "plot": spec[1], "compare": spec[2]}
		show_screen("plots")
		await get_tree().create_timer(2.0).timeout
		await _shot("pre_plots_" + spec[1])
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
