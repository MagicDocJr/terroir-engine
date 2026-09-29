# 3D view of the Estate (look-only in the MVP): one walkable world with the Plot's vineyard, the farm track and
# the winery (fermentation hall, stairs, barrel cellar under the ground).
#
# Contract with the UI (game/src/ui):
#   apply_snapshot(D)  D = parsed Sim.Snapshot() JSON; call on entry and after every advance
#   set_view(kind)     "vineyard" | "cellar" | "hall": teleports the walker to that place in the one world;
#                      "drone": a free-flying camera above the Estate (the walker waits where it is)
#   exit_requested     emitted on Tab, or Esc while the mouse is not captured
#   task_chosen(id, value, timing)  the player did a staff task on its demonstration vine / tank (the shell sends `task`)
#   focus_task(id)     puts the walker in front of that task's vine or tank
# Input is handled only while this node is visible: click to capture the mouse, WASD walk, Shift run,
# 1/2/3 jump to vineyard/cellar/hall, 4 drone on/off, M sound on/off, E work a task's marked vine or tank (close-up). The 3D world renders in its own SubViewport (own World3D);
# rendering and sound stop while this Control is hidden.
extends Control

signal exit_requested
signal task_chosen(id: int, value: String, timing: String)

const A := preload("res://src/view3d/assets3d.gd")
const WineryStyle := preload("res://src/view3d/winery_style.gd")
const VIEWS := ["vineyard", "cellar", "hall"]
const NEAR_WINERY := 45.0          # metres: hall lights/GI stay on this close to the building
const EYE_OUT := 1.7               # vineyard.gd EYE (eye height of its camera presets)

var show_hud := true
## Sound: master volume of the 3D view in dB, and on/off (also M).
var sound_volume_db := 0.0:
	set(v):
		sound_volume_db = v
		if ambience: ambience.set("master_db", v)
var sound_on := true:
	set(v):
		sound_on = v
		if ambience: ambience.set("muted", not v)
var viewport: SubViewport
var container: SubViewportContainer
var vineyard: Node3D
var winery: Node3D
var workers: Node3D
var player: CharacterBody3D
var ambience: Node3D
var current := "vineyard"
var zone := "?"                    # "" outside | "hall" | "cellar"
var near := false
var D := {}
var hud_label: Label
var hint_label: Label
var missing := false
var placed_key := ""
var has_view := false
# drone: orbit camera round a centre point (drag to orbit, WASD pan, wheel height/zoom, Shift faster)
var drone := false
var drone_cam: Camera3D
var drone_center := Vector3.ZERO
var drone_yaw := 0.6
var drone_pitch := -0.62
var drone_dist := 120.0
var dragging := false
# staff tasks (tasks3d.gd): E near a marked vine or tank opens a close-up with the options as clickable parts
const TASK_REACH := 2.5
var tasks3d: Node3D
var closeup_id := -1
var closeup_pending: Array = []       # [id, value, timing] of a confirmed choice waiting for its animation
var closeup_task := {}
var closeup_value := ""
var closeup_busy := false
var near_task := {}
var prompt_label: Label
var task_panel: PanelContainer
var tp_title: Label
var tp_place: Label
var tp_plan: Label
var tp_why: Label
var tp_options: VBoxContainer
var tp_late: CheckBox
var tp_confirm: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	container = SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.positional_shadow_atlas_size = 4096
	viewport.anisotropic_filtering_level = Viewport.ANISOTROPY_4X
	viewport.audio_listener_enable_3d = true
	viewport.use_occlusion_culling = true
	container.add_child(viewport)
	# shadow quality is global (project settings normally); set it here so the view needs no project changes
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	missing = not A.available()
	vineyard = _make(viewport, "res://src/view3d/vineyard.gd", "Vineyard")
	winery = _make(vineyard, "res://src/view3d/winery.gd", "Winery")
	workers = _make(vineyard, "res://src/view3d/workers.gd", "Workers")
	tasks3d = _make(vineyard, "res://src/view3d/tasks3d.gd", "Tasks")
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(load("res://src/view3d/player.gd"))
	viewport.add_child(player)
	player.cam.current = true
	vineyard.set("cam", player.cam)
	drone_cam = Camera3D.new()
	drone_cam.name = "DroneCam"
	drone_cam.fov = 60.0
	drone_cam.near = 0.2
	drone_cam.far = 6000.0
	viewport.add_child(drone_cam)
	player.set("ground_fn", Callable(vineyard, "ground_height"))
	player.set("indoors_fn", func(p: Vector3) -> bool: return winery.call("zone_at", winery.to_local(p)) != "")
	ambience = _make(viewport, "res://src/view3d/ambience.gd", "Ambience")
	player.footstep.connect(func(speed: float): ambience.call("footstep", speed))
	ambience.set("master_db", sound_volume_db)
	ambience.set("muted", not sound_on)
	_build_hud()
	_build_task_panel()
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _exit_tree() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	A.clear()


func _make(parent: Node, script: String, name_: String) -> Node3D:
	var n := Node3D.new()
	n.name = name_
	n.set_script(load(script))
	parent.add_child(n)
	return n


func _build_hud() -> void:
	hud_label = Label.new()
	hud_label.position = Vector2(24, 18)
	hud_label.add_theme_font_size_override("font_size", 17)
	hud_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.96))
	hud_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	hud_label.add_theme_constant_override("shadow_offset_x", 1)
	hud_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(hud_label)
	hint_label = Label.new()
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.position = Vector2(24, -40)
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.9, 0.85))
	hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	add_child(hint_label)
	_update_hint()
	if missing:
		hud_label.text = "3D assets missing — run game/tools/sync_assets3d.sh"


func _update_hint() -> void:
	if drone:
		hint_label.text = "Drone · drag to orbit · WASD pan · wheel height · Shift faster · 4 or 1/2/3 back to walking · M sound %s · Tab back" % ["on" if sound_on else "off"]
		return
	var where: String = {"": "Follow the track to the winery", "hall": "Stairs to the cellar at the far end", "cellar": "Stairs up to the hall by the door"}.get(zone, "")
	hint_label.text = "Click to look around · WASD walk · Shift run · 1 vineyard  2 cellar  3 hall (jump) · 4 drone · M sound %s · Tab back%s" % [
		"on" if sound_on else "off", ("   —   " + where) if where != "" else ""]


# ------------------------------------------------------------------ contract
func apply_snapshot(snap: Dictionary) -> void:
	D = snap
	if missing or snap.is_empty():
		return
	vineyard.call("apply_snapshot", snap)
	winery.call("build")
	var region := String(snap.get("region", {}).get("id", "mosel"))
	winery.call("set_region", region)
	var moved := false
	if String(vineyard.get("plot_key")) != placed_key:
		placed_key = String(vineyard.get("plot_key"))
		winery.position = vineyard.call("building_origin")
		moved = true
	# the Winery look (winery_style.gd; cosmetic) before the GI bake, so one bake sees both the new place and the look
	var baked_now: bool = winery.call("apply_style", WineryStyle.resolve(region, snap.get("decor", {})))
	if moved and not baked_now:
		winery.call("bake_gi")
	winery.call("apply_snapshot", snap)
	winery.call("sync_hall_env", vineyard.get("env"))
	if workers.get("vy") == null:
		workers.call("setup", vineyard, winery)
	workers.call("apply", snap)
	if tasks3d.get("vy") == null:
		tasks3d.call("setup", vineyard, winery)
	if closeup_id >= 0:
		_leave_closeup()
	tasks3d.call("apply", snap)
	player.set("bounds", vineyard.call("walk_rect"))
	_configure_sound()
	if moved or not has_view:
		set_view(current)          # new landscape: start again at the entry spot
	else:
		_update_zone(true)


func set_view(kind: String) -> void:
	if kind == "drone":
		if not missing and placed_key != "":
			_drone_on()
		return
	if drone:
		_drone_off(false)
	if not kind in VIEWS or missing or placed_key == "":
		current = kind if kind in VIEWS else current
		return
	current = kind
	has_view = true
	if kind == "vineyard":
		var pt: Array = vineyard.call("camera_preset", "walk")
		player.call("teleport", pt[0] - Vector3(0, EYE_OUT, 0), pt[1])
	else:
		var sp: Array = winery.call("spawn", kind)
		if sp.is_empty():
			return
		player.call("teleport", winery.to_global(sp[0]), winery.to_global(sp[1]))
	player.cam.current = true
	ambience.call("snap")
	_update_zone(true)


## Put the eye exactly at pos looking at target (capture harness, cut-aways). The walker waits there.
func set_camera(pos: Vector3, target: Vector3) -> void:
	if drone:
		_drone_off(false)
	player.call("place_camera", pos, target)
	ambience.call("snap")
	_update_zone(true)


## Named camera spots. Vineyard: "walk" | "row" | "close" | "overview" | "valley" (optionally for Block index bi),
## "estate" | "estate_high" | "track". Winery: "hall" | "hall_panel" | "hall_stairs" | "stairs_down" |
## "stairs_up" | "cellar" | "cellar_heads" | "cellar_fuder" | "cellar_door" | "door".
func camera_preset(name: String, bi := 0) -> void:
	if name == "drone":
		set_view("drone")
		return
	if name == "crew":                     # whoever is at work (harvest crew, sprayer, pruners); else the Block row view
		var cv: Array = workers.call("crew_view")
		if not cv.is_empty():
			set_camera(cv[0], cv[1])
			return
		name = "row"
	var pt: Array = winery.call("camera_preset", name)
	if not pt.is_empty():
		set_camera(winery.to_global(pt[0]), winery.to_global(pt[1]))
		return
	pt = vineyard.call("camera_preset", name, bi)
	set_camera(pt[0], pt[1])


func capture() -> Image:
	return viewport.get_texture().get_image()


# ------------------------------------------------------------------ zones
func _cam() -> Camera3D:
	return drone_cam if drone else player.cam


func _zone_now() -> String:
	return String(winery.call("zone_at", winery.to_local(_cam().global_position)))


## Camera environment, interior lights/GI, sun, rain and sound follow where the eye is.
func _update_zone(force := false) -> void:
	if placed_key == "":
		return
	var z := _zone_now()
	var n: bool = z != "" or _cam().global_position.distance_to(winery.global_position) < NEAR_WINERY
	if z == zone and n == near and not force:
		return
	var changed := z != zone
	zone = z
	near = n
	var cam: Camera3D = _cam()
	match zone:
		"hall":
			cam.environment = winery.get("env_hall")
			cam.attributes = winery.get("attr_hall")
		"cellar":
			cam.environment = winery.get("env_cellar")
			cam.attributes = winery.get("attr_cellar")
		_:
			cam.environment = vineyard.get("env")
			cam.attributes = vineyard.get("outside_attributes")
	winery.call("set_active", zone, near)
	var sun: DirectionalLight3D = vineyard.get("sun")
	sun.visible = zone != "cellar"
	# indoors the sun only reaches in through the door and windows: a shorter, cheaper shadow cascade
	sun.directional_shadow_max_distance = 70.0 if zone == "" else 40.0      # 70 = vineyard.gd OUT_SHADOW
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if zone == "" else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	vineyard.call("set_outdoors", zone == "")
	if changed:
		_update_hint()


func _configure_sound() -> void:
	var w: Dictionary = (vineyard.get("weather") as Dictionary).duplicate()
	w["day"] = true                 # the view always shows the afternoon light (vineyard._apply_weather)
	var river: Vector2 = vineyard.get("river")
	var ry: float = vineyard.get("river_y")
	var b0: float = vineyard.get("band_x0")
	var b1: float = vineyard.get("band_x1")
	var hz: float = vineyard.get("hz")
	# the neighbours' tractor works a row some way above the Plot
	var tz := -hz - 90.0
	var tractor := [Vector3(b0 - 60.0, vineyard.call("ground_height", b0 - 60.0, tz) + 1.5, tz), Vector3(b1 + 60.0, vineyard.call("ground_height", b1 + 60.0, tz) + 1.5, tz)]
	var cellar: Node3D = winery.get("cellar")
	var dims: Dictionary = (winery.get("L") as Dictionary)["cellar"]["dims"]
	ambience.call("configure", w, river.x if river.x < INF else INF, ry, tractor, winery.to_global(Vector3(10.6, 1.2, 6.3)),
		winery.to_global(Vector3(-6.0, 0.4, 1.4)), cellar.global_transform, Vector2(float(dims["L"]), float(dims["W"])))
	ambience.call("set_tanks", winery.call("active_tanks"))


func _on_visibility_changed() -> void:
	var on := is_visible_in_tree()
	set_process(on)
	set_process_input(on)
	if player:
		player.set("enabled", on and not missing and not drone)
		player.set_physics_process(on)
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if ambience:
		ambience.call("set_running", on and not missing)
	if workers:
		workers.call("set_active", on and not missing)
	# re-entry without set_view (the UI keeps the place): walker, drone and sound carry on where they were
	if on and not missing and placed_key != "":
		(drone_cam if drone else player.cam).current = true
		if ambience:
			ambience.call("snap")
		_update_zone(true)
	if not on and closeup_id >= 0:
		if closeup_busy:
			_finish_confirm()        # a confirmed choice is sent even if the view closes during its animation
		else:
			_leave_closeup()         # leaving the 3D view ends an undecided close-up without deciding
	if not on and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or missing:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if closeup_id >= 0:
		_closeup_input(e)
		return
	if drone and _drone_input(e):
		get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		accept_event()
	elif e is InputEventMouseMotion and captured:
		player.call("look", float(player.get("yaw")) - e.relative.x * 0.0025, float(player.get("pitch")) - e.relative.y * 0.0025)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_TAB:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				exit_requested.emit()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if captured:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				else:
					exit_requested.emit()
				get_viewport().set_input_as_handled()
			KEY_1:
				set_view("vineyard"); get_viewport().set_input_as_handled()
			KEY_2:
				set_view("cellar"); get_viewport().set_input_as_handled()
			KEY_3:
				set_view("hall"); get_viewport().set_input_as_handled()
			KEY_4:
				if drone:
					_drone_off(true)
				else:
					set_view("drone")
				get_viewport().set_input_as_handled()
			KEY_M:
				sound_on = not sound_on
				_update_hint()
				get_viewport().set_input_as_handled()
			KEY_E:
				if _interact():
					get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if missing or placed_key == "":
		return
	if drone:
		_drone_step(delta)
	_update_zone()
	ambience.call("update", delta, zone, _cam().global_position, near)
	if show_hud:
		var p: Vector3 = _cam().global_position
		hud_label.text = String(winery.call("hud_text", zone)) if zone != "" else String(vineyard.call("hud_text", p))
		var at_work := String(workers.get("summary"))
		if at_work != "":
			hud_label.text += "\nAt work: " + at_work
	hud_label.visible = show_hud
	hint_label.visible = show_hud
	near_task = {} if drone or closeup_id >= 0 else tasks3d.call("nearest", player.global_position, TASK_REACH)
	prompt_label.visible = not near_task.is_empty()
	if not near_task.is_empty():
		var place := ("Lot %s" % near_task["lot"]) if String(near_task["kind"]) == "CapManagement" else ("Block %s" % near_task["block"])
		var verb := String(near_task["verb"])
		prompt_label.text = "E  %s   ·   %s, %s" % [verb.substr(0, 1).to_upper() + verb.substr(1), near_task["title"], place]


# ------------------------------------------------------------------ drone
func _drone_on() -> void:
	if not drone:
		var b0: float = vineyard.get("band_x0")
		var b1: float = vineyard.get("band_x1")
		drone_center = Vector3((b0 + b1) * 0.5, 0.0, 0.0)
		drone_center.y = float(vineyard.call("ground_height", drone_center.x, drone_center.z))
		drone_dist = clampf((b1 - b0) * 0.62, 60.0, 180.0)
		drone_pitch = -0.72
		drone_yaw = float(player.get("yaw"))
	drone = true
	dragging = false
	player.set("enabled", false)
	player.set("auto_dir", Vector3.ZERO)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	drone_cam.current = true
	vineyard.set("cam", drone_cam)
	_drone_apply()
	ambience.call("snap")
	_update_zone(true)
	_update_hint()


## Back to walking where the walker was (resume = true), or before a teleport (set_view / set_camera).
func _drone_off(resume: bool) -> void:
	drone = false
	dragging = false
	player.cam.current = true
	vineyard.set("cam", player.cam)
	player.set("enabled", is_visible_in_tree() and not missing)
	if resume:
		ambience.call("snap")
		_update_zone(true)
	_update_hint()


func _drone_apply() -> void:
	var dir := Vector3(sin(drone_yaw) * cos(drone_pitch), -sin(drone_pitch), cos(drone_yaw) * cos(drone_pitch))
	var pos := drone_center + dir * drone_dist
	var ground := float(vineyard.call("ground_height", pos.x, pos.z)) + 3.0
	if pos.y < ground:
		pos.y = ground
	drone_cam.global_position = pos
	drone_cam.look_at(drone_center, Vector3.UP)


func _drone_input(e: InputEvent) -> bool:
	if e is InputEventMouseButton:
		match e.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				dragging = e.pressed
				return true
			MOUSE_BUTTON_WHEEL_UP:
				if e.pressed:
					drone_dist = clampf(drone_dist * (0.8 if Input.is_physical_key_pressed(KEY_SHIFT) else 0.9), 12.0, 900.0)
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				if e.pressed:
					drone_dist = clampf(drone_dist * (1.25 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.1), 12.0, 900.0)
				return true
	elif e is InputEventMouseMotion and dragging:
		drone_yaw -= e.relative.x * 0.005
		drone_pitch = clampf(drone_pitch - e.relative.y * 0.005, -1.5, -0.08)
		return true
	return false


func _drone_step(delta: float) -> void:
	var k := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): k.z -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): k.z += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): k.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): k.x += 1
	if Input.is_physical_key_pressed(KEY_Q): drone_yaw += delta * 0.8
	if Input.is_physical_key_pressed(KEY_E): drone_yaw -= delta * 0.8
	if k != Vector3.ZERO:
		var speed := drone_dist * 0.6 * (3.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
		var mv := Basis(Vector3.UP, drone_yaw) * k.normalized() * speed * delta
		var wr: Rect2 = vineyard.call("walk_rect")
		drone_center.x = clampf(drone_center.x + mv.x, wr.position.x - 200.0, wr.end.x + 200.0)
		drone_center.z = clampf(drone_center.z + mv.z, wr.position.y - 200.0, wr.end.y + 200.0)
		drone_center.y = float(vineyard.call("ground_height", drone_center.x, drone_center.z))
	_drone_apply()


# ------------------------------------------------------------------ staff tasks (close-up)
func _build_task_panel() -> void:
	prompt_label = Label.new()
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-300, -120)
	prompt_label.size = Vector2(600, 40)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 22)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	prompt_label.visible = false
	add_child(prompt_label)
	task_panel = PanelContainer.new()
	task_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	task_panel.offset_left = -470
	task_panel.offset_right = -24
	task_panel.offset_top = 90
	task_panel.offset_bottom = -90
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.07, 0.86)
	sb.border_color = Color(0.85, 0.68, 0.3, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(22)
	task_panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	task_panel.add_child(v)
	tp_title = _tp_label(26, Color(1, 0.93, 0.78))
	tp_place = _tp_label(16, Color(0.8, 0.84, 0.86))
	tp_plan = _tp_label(15, Color(0.7, 0.74, 0.76))
	v.add_child(tp_title); v.add_child(tp_place); v.add_child(tp_plan)
	var hint := _tp_label(14, Color(0.66, 0.7, 0.72))
	hint.text = "Click a part of the vine (or a tool), or an option below."
	v.add_child(hint)
	tp_options = VBoxContainer.new()
	tp_options.add_theme_constant_override("separation", 6)
	v.add_child(tp_options)
	tp_late = CheckBox.new()
	tp_late.text = "Do it later, at véraison (late leaf removal)"
	v.add_child(tp_late)
	tp_why = _tp_label(15, Color(0.9, 0.92, 0.9))
	tp_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tp_why.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tp_why)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	tp_confirm = Button.new()
	tp_confirm.text = "Confirm (Enter)"
	tp_confirm.custom_minimum_size = Vector2(190, 44)
	tp_confirm.pressed.connect(_confirm)
	var back := Button.new()
	back.text = "Back (Esc)"
	back.custom_minimum_size = Vector2(130, 44)
	back.pressed.connect(_leave_closeup)
	hb.add_child(tp_confirm); hb.add_child(back)
	v.add_child(hb)
	task_panel.visible = false
	add_child(task_panel)


func _tp_label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Puts the walker in front of the task's vine (or its Lot's tank). No-op for unknown or closed tasks.
func focus_task(id: int) -> void:
	if missing or placed_key == "":
		return
	if drone:
		_drone_off(false)
	var sp: Array = tasks3d.call("stand_point", id)
	if sp.is_empty():
		return
	player.call("teleport", sp[0], sp[1])
	player.cam.current = true
	ambience.call("snap")
	_update_zone(true)


## E: opens the close-up of the task within reach. Returns true when one opened.
func _interact() -> bool:
	if drone or closeup_id >= 0 or missing:
		return false
	var task: Dictionary = tasks3d.call("nearest", player.global_position, TASK_REACH)
	if task.is_empty():
		return false
	var cam: Array = tasks3d.call("open_closeup", task)
	if cam.is_empty():
		return false
	closeup_id = int(task["id"])
	closeup_task = task
	closeup_value = ""
	closeup_busy = false
	player.set("enabled", false)       # the keys belong to the close-up now (WASD must not walk the camera away)
	player.call("place_camera", cam[0], cam[1])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var place := ("Lot %s" % task["lot"]) if String(task["kind"]) == "CapManagement" else ("Block %s · %s" % [task["block"], task.get("variety", "")])
	tp_title.text = String(task["title"])
	tp_place.text = "%s · due %s" % [place, task["due"]]
	tp_plan.text = "Plan if you let the crew do it: %s" % task.get("planLabel", "")
	tp_why.text = "What you choose here, the crew then does on the whole %s." % ("Lot" if String(task["kind"]) == "CapManagement" else "Block")
	tp_late.visible = String(task["kind"]) == "LeafRemoval"
	tp_late.button_pressed = str(task.get("planTiming", "")) == "Late"
	for c in tp_options.get_children():
		c.queue_free()
	for o in task.get("options", []):
		var b := Button.new()
		b.text = String(o["label"])
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 38)
		b.set_meta("value", String(o["value"]))
		var val := String(o["value"])
		b.pressed.connect(func(): _choose(val))
		b.mouse_entered.connect(func(): _explain(val))
		tp_options.add_child(b)
	tp_confirm.disabled = true
	task_panel.visible = true
	prompt_label.visible = false
	hint_label.text = "Click a part or an option · Enter confirm · Esc back"
	return true


func _option(value: String) -> Dictionary:
	for o in closeup_task.get("options", []):
		if String(o["value"]) == value:
			return o
	return {}


func _explain(value: String) -> void:
	var o := _option(value)
	if not o.is_empty():
		tp_why.text = "%s\n\n%s" % [o["label"], o["why"]]


## Selects an option (from a click on a part or a button). Leaf removal toggles sides.
func _choose(value: String) -> void:
	if closeup_id < 0 or closeup_busy:
		return
	if String(closeup_task.get("kind", "")) == "LeafRemoval" and value in ["Morning", "Afternoon"]:
		value = tasks3d.call("toggle_side", value)
	elif String(closeup_task.get("kind", "")) == "LeafRemoval":
		tasks3d.call("toggle_side", value)
	closeup_value = value
	tasks3d.call("highlight", value)
	for b in tp_options.get_children():
		if b is Button:
			(b as Button).set_pressed_no_signal(String(b.get_meta("value", "")) == value)
	_explain(value)
	tp_confirm.disabled = false


func _confirm() -> void:
	if closeup_id < 0 or closeup_value == "" or closeup_busy:
		return
	closeup_busy = true
	var id := closeup_id
	var value := closeup_value
	var timing := "Late" if tp_late.visible and tp_late.button_pressed else ""
	closeup_pending = [id, value, timing]
	tasks3d.call("play_confirm", value, timing)
	tp_confirm.disabled = true
	await get_tree().create_timer(1.0).timeout
	if closeup_id == id and closeup_busy:
		_finish_confirm()


## Sends a confirmed choice: after the confirm animation, or at once when the player leaves the 3D view (Tab) during it.
func _finish_confirm() -> void:
	if closeup_pending.is_empty():
		return
	var p: Array = closeup_pending
	closeup_pending = []
	_leave_closeup()
	task_chosen.emit(int(p[0]), String(p[1]), String(p[2]))


func _leave_closeup() -> void:
	if closeup_id < 0:
		return
	var sp: Array = tasks3d.call("stand_point", closeup_id)
	tasks3d.call("close_closeup")
	closeup_id = -1
	closeup_task = {}
	closeup_value = ""
	closeup_busy = false
	closeup_pending = []
	task_panel.visible = false
	player.set("enabled", is_visible_in_tree() and not missing and not drone)
	if not sp.is_empty():
		player.call("teleport", sp[0], sp[1])
	_update_hint()


func _closeup_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_ESCAPE:
				if not closeup_busy:           # a confirmed choice can't be taken back; it lands in a moment
					_leave_closeup()
				get_viewport().set_input_as_handled()
			KEY_TAB:
				if closeup_busy:
					_finish_confirm()            # confirmed: send it rather than drop it
				else:
					_leave_closeup()
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				exit_requested.emit()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				_confirm(); get_viewport().set_input_as_handled()
		return
	if task_panel.visible and e is InputEventMouse and task_panel.get_global_rect().has_point((e as InputEventMouse).position):
		return                     # the panel's own buttons handle it
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var v := _pick_at((e as InputEventMouseButton).position)
		if v != "":
			_choose(v)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion:
		var v2 := _pick_at((e as InputEventMouseMotion).position)
		if v2 != "":
			_explain(v2)


func _pick_at(screen_pos: Vector2) -> String:
	var cam: Camera3D = player.cam
	var r := container.get_global_rect()
	var p := (screen_pos - r.position) * Vector2(viewport.size) / r.size if r.size.x > 0 else screen_pos
	return String(tasks3d.call("pick", cam.project_ray_origin(p), cam.project_ray_normal(p)))

