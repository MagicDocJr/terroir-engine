# PROTOTYPE — app shell: top bar, left menu, screen host, status bar, toasts, keys, capture mode.
# Run:      ./run.sh                   (starts on the pre-game Region picker)
#           ./run.sh --screen ripeness (jump straight to a screen)
# Capture:  ./shot.sh                  (every screen at 1920×1080 into shots/)
extends Control

const UI := preload("res://src/ui.gd")
const SCREENS := {
	"region": ["Choose a Region", "res://src/screens/pregame.gd", "region"],
	"plots": ["Compare Plots", "res://src/screens/pregame.gd", "plots"],
	"inbox": ["Inbox", "res://src/screens/inbox.gd", ""],
	"estate": ["Estate", "res://src/screens/estate.gd", ""],
	"plot": ["Plot & Blocks", "res://src/screens/plot.gd", ""],
	"weather": ["Weather", "res://src/screens/weather.gd", ""],
	"programmes": ["Programmes", "res://src/screens/programmes.gd", ""],
	"ripeness": ["Ripeness", "res://src/screens/ripeness.gd", ""],
	"winery": ["Winery", "res://src/screens/winery.gd", ""],
	"blending": ["Blending", "res://src/screens/blending.gd", ""],
	"wines": ["Wines", "res://src/screens/wines.gd", ""],
	"glossary": ["Glossary", "res://src/screens/glossary.gd", ""],
}
const NAV := ["inbox", "estate", "plot", "weather", "programmes", "ripeness", "winery", "blending", "wines", "glossary"]
const NAV_GLYPH := {"inbox": "▤", "estate": "◆", "plot": "▦", "weather": "☁", "programmes": "≡", "ripeness": "◔",
	"winery": "▥", "blending": "⋈", "wines": "✦", "glossary": "?"}
const CAPTURE := ["region", "plots", "inbox", "estate", "plot", "weather", "programmes", "ripeness", "winery", "blending", "wines", "glossary"]

var D: Dictionary
var current := ""
var capture := false
var state := {}                 # screen-local state that survives re-renders (selected Block, Lot, sort…)
var root_box: VBoxContainer
var topbar: Control
var nav_box: VBoxContainer
var nav_panel: Control
var host: MarginContainer
var statusbar: Control
var toast: PanelContainer
var toast_label: Label
var date_label: Label
var day_offset := 0

func _ready() -> void:
	D = JSON.parse_string(FileAccess.get_file_as_string("res://data/fake_data.json"))
	theme = UI.make_theme()
	var args := OS.get_cmdline_user_args()
	capture = "--capture" in args
	if capture:
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		get_tree().root.content_scale_size = Vector2i(1920, 1080)
	var bg := ColorRect.new(); bg.color = UI.BG; bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	root_box = UI.vbox(0); root_box.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(root_box)
	topbar = _topbar(); root_box.add_child(topbar)
	var body := UI.hbox(0); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; root_box.add_child(body)
	nav_panel = _nav(); body.add_child(nav_panel)
	host = MarginContainer.new(); host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		host.add_theme_constant_override("margin_" + side, 24 if side in ["left", "right"] else 18)
	body.add_child(host)
	statusbar = _statusbar(); root_box.add_child(statusbar)
	_make_toast()
	var start := "region"
	var i := args.find("--screen")
	if i >= 0 and i + 1 < args.size(): start = args[i + 1]
	show_screen(start)
	if capture: _run_capture.call_deferred()

# ------------------------------------------------------------------ navigation
func show_screen(id: String) -> void:
	if not SCREENS.has(id): id = "inbox"
	current = id
	for c in host.get_children(): c.queue_free()
	var pre: bool = id in ["region", "plots"]
	topbar.visible = not pre
	nav_panel.visible = not pre
	statusbar.visible = not pre
	var def: Array = SCREENS[id]
	var mod = load(def[1])
	var node: Control = mod.build(D, self, def[2]) if def[2] != "" else mod.build(D, self)
	host.add_child(node)
	_refresh_nav()

func rerender() -> void:
	show_screen(current)

func _unhandled_input(e: InputEvent) -> void:
	if capture or not (e is InputEventKey and e.pressed and not e.echo): return
	var k: int = e.physical_keycode
	if k >= KEY_1 and k <= KEY_9:
		show_screen(NAV[k - KEY_1])
	elif k == KEY_0:
		show_screen("glossary")
	elif k == KEY_P:
		show_screen("region")
	elif k == KEY_TAB:
		notify("The 3D walkaround is not part of this UI prototype.")
	elif k == KEY_SPACE and current not in ["region", "plots"]:
		_advance(1)

# ------------------------------------------------------------------ chrome
func _topbar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.sb(Color("161c22"), 0, UI.LINE, 0, 20))
	bar.custom_minimum_size = Vector2(0, 64)
	var h := UI.hbox(14); bar.add_child(h)
	h.add_child(UI.head("Terroir", 26, UI.INK))
	var est := UI.label(String(D["estate"]), 15, UI.INK2); est.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(est)
	h.add_child(UI.spacer())
	var dv := UI.vbox(0)
	date_label = UI.head(String(D["date"]), 22, UI.INK); date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; dv.add_child(date_label)
	var st := UI.label(String(D["stage"]), 13, UI.INK2); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; dv.add_child(st)
	h.add_child(dv)
	var fc: Dictionary = D["weather"]["forecast"][0]
	var wx := UI.hbox(4); wx.tooltip_text = "Today: %s, %d–%d °C. %s" % [fc["day"], int(fc["tmin"]), int(fc["tmax"]), fc["note"]]
	var ic = load("res://src/charts.gd").WeatherIcon.new(); ic.kind = String(fc["icon"]); ic.custom_minimum_size = Vector2(40, 40); wx.add_child(ic)
	var wl := UI.num("%d°" % int(fc["tmax"]), 20, UI.INK); wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER; wx.add_child(wl)
	h.add_child(wx)
	h.add_child(UI.spacer())
	var cash := UI.num(UI.euro(int(D["cash"])), 22, UI.INK); cash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cash.tooltip_text = "Cash. Open Estate for the P&L."; cash.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(cash)
	for spec in [["+1 day", 1], ["+1 week", 7]]:
		var b := UI.button(spec[0]); b.custom_minimum_size = Vector2(0, 40); b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(_advance.bind(spec[1])); h.add_child(b)
	var cont := UI.button("Continue", true, 16); cont.custom_minimum_size = Vector2(128, 42); cont.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cont.tooltip_text = "Run day by day until the next Alert (Space)"
	cont.pressed.connect(func(): notify("Continue runs until the next Alert. The simulation isn't connected in this prototype."))
	h.add_child(cont)
	var alerts := 0
	for m in D["inbox"]:
		if m["alert"]: alerts += 1
	var bell := PanelContainer.new(); bell.add_theme_stylebox_override("panel", UI.sb(UI.CRIT, 14, Color(0, 0, 0, 0), 0, 10))
	bell.add_child(UI.label("⚑ %d" % alerts, 16, Color.WHITE, UI.f_body_b)); bell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bell.tooltip_text = "%d Alerts waiting in the Inbox" % alerts
	bell.mouse_filter = Control.MOUSE_FILTER_STOP
	bell.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: show_screen("inbox"))
	h.add_child(bell)
	return bar

func _advance(days: int) -> void:
	day_offset += days
	notify("Advanced %d day%s (prototype: the data doesn't change)." % [days, "" if days == 1 else "s"])

func _nav() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sb(Color("182026"), 0, Color(0, 0, 0, 0), 0, 0))
	p.custom_minimum_size = Vector2(216, 0)
	var v := UI.vbox(0); p.add_child(v)
	v.add_child(UI.spacer(false, 12))
	nav_box = UI.vbox(2); v.add_child(nav_box)
	v.add_child(UI.spacer(false))
	var plot_card := MarginContainer.new()
	for side in ["left", "right", "bottom"]: plot_card.add_theme_constant_override("margin_" + side, 16)
	var pv := UI.vbox(2); plot_card.add_child(pv)
	pv.add_child(UI.head(String(D["plot"]["name"]), 16, UI.INK))
	pv.add_child(UI.label("%s, %.1f ha" % [D["plot"]["region"], float(D["plot"]["ha"])], 13, UI.MUTED))
	pv.add_child(UI.label(String(D["plot"]["leaf"]), 13, UI.MUTED))
	v.add_child(plot_card)
	return p

func _refresh_nav() -> void:
	for c in nav_box.get_children(): c.queue_free()
	var unread := 0
	for m in D["inbox"]:
		if m["alert"]: unread += 1
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
		row.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: show_screen(id))
		var h := UI.hbox(14); row.add_child(h)
		var ic := UI.label(NAV_GLYPH[id], 17, UI.GOLD if active else UI.MUTED); ic.custom_minimum_size = Vector2(20, 0); h.add_child(ic)
		h.add_child(UI.label(SCREENS[id][0], 17, UI.INK if active else UI.INK2, UI.f_body_b if active else null))
		if id == "inbox" and unread > 0:
			h.add_child(UI.spacer())
			var badge := PanelContainer.new(); badge.add_theme_stylebox_override("panel", UI.sb(UI.CRIT, 9, Color(0, 0, 0, 0), 0, 7))
			badge.add_child(UI.label(str(unread), 13, Color.WHITE, UI.f_body_b)); badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(badge)
		nav_box.add_child(row)

func _statusbar() -> Control:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", UI.sb(Color("161c22"), 0, Color(0, 0, 0, 0), 0, 20))
	p.custom_minimum_size = Vector2(0, 30)
	var h := UI.hbox(28); p.add_child(h)
	var staff: Array = D["staff"]
	for txt in [String(D["modes"]["mode"]), "Vineyard manager: %s" % staff[0]["level"], "Cellar master: %s" % staff[1]["level"],
			"Mentor: %s, retires after bottling" % String(staff[2]["name"]), String(D["modes"]["weather"])]:
		h.add_child(UI.label(txt, 13, UI.MUTED))
	h.add_child(UI.spacer())
	h.add_child(UI.label("Keys 1–0 switch screens, P restarts the pre-game, Tab would open 3D", 13, UI.MUTED))
	return p

func _make_toast() -> void:
	toast = PanelContainer.new()
	toast.add_theme_stylebox_override("panel", UI.sb(Color("11171c"), 6, UI.GOLD.darkened(0.2), 1, 16))
	toast_label = UI.label("", 15, UI.INK)
	toast.add_child(toast_label)
	toast.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	toast.position = Vector2(1920 - 620, 1080 - 110)
	toast.custom_minimum_size = Vector2(580, 0)
	toast.visible = false
	add_child(toast)

func notify(text: String) -> void:
	toast_label.text = text
	toast.visible = true
	toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): toast.visible = false)

# ------------------------------------------------------------------ capture
func _run_capture() -> void:
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var only := ""
	var args := OS.get_cmdline_user_args()
	var i := args.find("--only")
	if i >= 0 and i + 1 < args.size(): only = args[i + 1]
	var n := 0
	for id in CAPTURE:
		n += 1
		if only != "" and not (id in only.split(",")): continue
		show_screen(id)
		for f in 12: await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var path := "%s/%02d_%s.png" % [dir, n, id]
		img.save_png(path)
		print("saved ", path, " ", img.get_size())
	get_tree().quit()
