# Terroir Engine — game shell: title & pre-game flow, top bar with time controls, left menu, screen host, status bar,
# toasts, keys, autosave, 3D toggle, and a capture mode that plays a real game and screenshots every screen.
# The UI only reads snapshots from the `Sim` autoload and sends commands; it never computes outcomes (ADR 0001).
extends Control

const UI := preload("res://src/ui/ui.gd")
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
var host: MarginContainer
var statusbar: Control
var toast: PanelContainer
var toast_label: Label
var view3d: Node = null
var busy := false
var playing := false            # continuous play: advances every tick until an Alert
var play_speed := 1             # days per 0.25 s tick (4 days a second)
var play_timer: Timer

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
	play_timer = Timer.new(); play_timer.wait_time = 0.25; play_timer.timeout.connect(_play_tick); add_child(play_timer)
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
	var new_alerts := []
	for m in D.get("inbox", []):
		if m.get("stop", false) and not before.has(int(m["id"])): new_alerts.append(m)
	_build_chrome()
	if new_alerts.size() > 0:
		state["inbox_sel"] = int(new_alerts[-1]["id"])   # the oldest of the new Alerts (the list is newest first)
		show_screen("inbox")
		notify("%d day%s later — %s" % [n, "" if n == 1 else "s", String(new_alerts[-1]["subject"])])
	else:
		show_screen(current)
		if n > 0 and not quiet: notify("%d day%s passed." % [n, "" if n == 1 else "s"])
	if view3d != null and view3d.visible and view3d.has_method("apply_snapshot"): view3d.apply_snapshot(D)
	return new_alerts.size() > 0

## Continuous play (spec §3.3): a day or more per tick, stopping at the first Alert.
func toggle_play() -> void:
	playing = not playing and String(D.get("phase", "")) != "Finished"
	if playing: play_timer.start()
	else: play_timer.stop()
	_topbar_refresh_count()

func _play_tick() -> void:
	if not playing or busy: return
	var alert := advance(play_speed, true, true)
	if alert or String(D.get("phase", "")) == "Finished":
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
	current = id
	for c in host.get_children(): c.queue_free()
	var pre: bool = id in PREGAME
	topbar.visible = not pre
	nav_panel.visible = not pre
	statusbar.visible = not pre
	var def: Array = SCREENS[id]
	var mod = load(def[1])
	var node: Control = mod.build(D, self, def[2]) if def[2] != "" else mod.build(D, self)
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
	if not pre: _refresh_nav()

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
	elif k == KEY_SPACE: advance(1, false)
	elif k == KEY_P: toggle_play()
	elif k == KEY_ENTER or k == KEY_KP_ENTER: advance(60, true)

# ------------------------------------------------------------------ 3D
func toggle_3d(kind := "vineyard") -> void:
	if view3d == null:
		if not ResourceLoader.exists("res://src/view3d/view3d.tscn"):
			notify("The 3D walkaround isn't installed in this build yet."); return
		view3d = load("res://src/view3d/view3d.tscn").instantiate()
		add_child(view3d)
		if view3d.has_signal("exit_requested"): view3d.exit_requested.connect(func(): _hide_3d())
		view3d.visible = false
	if view3d.visible: _hide_3d(); return
	root_box.visible = false
	view3d.visible = true
	if view3d.has_method("apply_snapshot"): view3d.apply_snapshot(D)
	if view3d.has_method("set_view"): view3d.set_view(kind)

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
	var st := UI.label(String(D.get("stage", "")), 13, UI.INK2); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; dv.add_child(st)
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
	var finished: bool = String(D.get("phase", "")) == "Finished"
	for spec in [["+1 day", 1, false, "Advance one day (Space)"], ["+1 week", 7, false, "Advance seven days, even through Alerts"]]:
		var b := UI.button(spec[0]); b.custom_minimum_size = Vector2(0, 40); b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.tooltip_text = spec[3]; b.disabled = finished
		b.pressed.connect(advance.bind(spec[1], spec[2])); h.add_child(b)
	var pb := UI.button("❚❚ Pause" if playing else "▶ Play", playing, 15); pb.custom_minimum_size = Vector2(96, 40); pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.tooltip_text = "Let time run, 4 days a second; stops at the next Alert (P)"; pb.disabled = finished
	pb.pressed.connect(toggle_play); h.add_child(pb)
	var cont := UI.button("Continue ▸", true, 16); cont.custom_minimum_size = Vector2(132, 42); cont.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cont.tooltip_text = "Run day by day until the next Alert (Enter)"; cont.disabled = finished
	cont.pressed.connect(advance.bind(60, true))
	h.add_child(cont)
	var unread := int(D.get("unreadAlerts", 0))
	var bell := PanelContainer.new(); bell.add_theme_stylebox_override("panel", UI.sb(UI.CRIT if unread > 0 else UI.RAISED, 14, Color(0, 0, 0, 0), 0, 10))
	bell.add_child(UI.label("⚑ %d" % unread, 16, Color.WHITE, UI.f_body_b)); bell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bell.tooltip_text = "%d unread high-priority messages" % unread
	bell.mouse_filter = Control.MOUSE_FILTER_STOP
	bell.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: show_screen("inbox"))
	h.add_child(bell)
	var b3 := UI.button("3D", false, 15); b3.custom_minimum_size = Vector2(52, 40); b3.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b3.tooltip_text = "Walk the vineyard and winery in 3D (Tab)"; b3.pressed.connect(toggle_3d.bind("vineyard")); h.add_child(b3)
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
	var plot_card := MarginContainer.new()
	for side in ["left", "right", "bottom"]: plot_card.add_theme_constant_override("margin_" + side, 16)
	var pv := UI.vbox(2); plot_card.add_child(pv)
	var P: Dictionary = D.get("plot", {})
	pv.add_child(UI.head(String(P.get("name", "")), 16, UI.INK))
	pv.add_child(UI.label("%s, %.1f ha" % [P.get("region", ""), float(P.get("ha", 0))], 13, UI.MUTED))
	pv.add_child(UI.label(String(P.get("leaf", "")), 13, UI.MUTED))
	pv.add_child(UI.label(String(P.get("varieties", "")), 13, UI.MUTED))
	v.add_child(plot_card)

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
	h.add_child(UI.label("1–0 screens · Space +1 day · P play/pause · Enter Continue · Tab 3D · Ctrl+S save", 13, UI.MUTED))

func _make_toast() -> void:
	toast = PanelContainer.new()
	toast.add_theme_stylebox_override("panel", UI.sb(Color("11171c"), 6, UI.GOLD.darkened(0.2), 1, 16))
	toast_label = UI.label("", 15, UI.INK, null, true)
	toast.add_child(toast_label)
	toast.position = Vector2(960 - 330, 74)
	toast.custom_minimum_size = Vector2(660, 0)
	toast.visible = false
	add_child(toast)

func notify(text: String, ok := false) -> void:
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
	await _shot3d("%s_10b_3d_hall" % prefix, "hall")
	Sim.Advance(20, false); D = JSON.parse_string(Sim.Snapshot()); _build_chrome()
	show_screen("winery"); await _shot("%s_11_winery_later" % prefix)
	show_screen("estate"); await _shot("%s_12_estate" % prefix)
	# age and bottle every Lot as it becomes ready
	guard = 0
	while String(D.get("phase", "")) != "Finished" and guard < 40:
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
	show_screen("wines"); await _shot("%s_14_wines" % prefix)
	show_screen("estate"); await _shot("%s_15_estate_end" % prefix)
	show_screen("glossary"); await _shot("%s_16_glossary" % prefix)
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
	for stop_at in [0, 200, 60, 200]:
		if stop_at > 0: Sim.Advance(stop_at, false); D = JSON.parse_string(Sim.Snapshot()); _build_chrome()
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
