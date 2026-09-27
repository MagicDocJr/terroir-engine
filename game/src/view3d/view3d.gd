# 3D view of the Estate (look-only in the MVP): one walkable world with the Plot's vineyard, the farm track and
# the winery (fermentation hall, stairs, barrel cellar under the ground).
#
# Contract with the UI (game/src/ui):
#   apply_snapshot(D)  D = parsed Sim.Snapshot() JSON; call on entry and after every advance
#   set_view(kind)     "vineyard" | "cellar" | "hall": teleports the walker to that place in the one world
#   exit_requested     emitted on Tab, or Esc while the mouse is not captured
# Input is handled only while this node is visible: click to capture the mouse, WASD walk, Shift run,
# 1/2/3 jump to vineyard/cellar/hall, M sound on/off. The 3D world renders in its own SubViewport (own World3D);
# rendering and sound stop while this Control is hidden.
extends Control

signal exit_requested

const A := preload("res://src/view3d/assets3d.gd")
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
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(load("res://src/view3d/player.gd"))
	viewport.add_child(player)
	player.cam.current = true
	vineyard.set("cam", player.cam)
	player.set("ground_fn", Callable(vineyard, "ground_height"))
	player.set("indoors_fn", func(p: Vector3) -> bool: return winery.call("zone_at", winery.to_local(p)) != "")
	ambience = _make(viewport, "res://src/view3d/ambience.gd", "Ambience")
	player.footstep.connect(func(speed: float): ambience.call("footstep", speed))
	ambience.set("master_db", sound_volume_db)
	ambience.set("muted", not sound_on)
	_build_hud()
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
	var where: String = {"": "Follow the track to the winery", "hall": "Stairs to the cellar at the far end", "cellar": "Stairs up to the hall by the door"}.get(zone, "")
	hint_label.text = "Click to look around · WASD walk · Shift run · 1 vineyard  2 cellar  3 hall (jump) · M sound %s · Tab back%s" % [
		"on" if sound_on else "off", ("   —   " + where) if where != "" else ""]


# ------------------------------------------------------------------ contract
func apply_snapshot(snap: Dictionary) -> void:
	D = snap
	if missing or snap.is_empty():
		return
	vineyard.call("apply_snapshot", snap)
	winery.call("build")
	winery.call("set_region", String(snap.get("region", {}).get("id", "mosel")))
	var moved := false
	if String(vineyard.get("plot_key")) != placed_key:
		placed_key = String(vineyard.get("plot_key"))
		winery.position = vineyard.call("building_origin")
		winery.call("bake_gi")
		moved = true
	winery.call("apply_snapshot", snap)
	winery.call("sync_hall_env", vineyard.get("env"))
	player.set("bounds", vineyard.call("walk_rect"))
	_configure_sound()
	if moved or not has_view:
		set_view(current)          # new landscape: start again at the entry spot
	else:
		_update_zone(true)


func set_view(kind: String) -> void:
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
	player.call("place_camera", pos, target)
	ambience.call("snap")
	_update_zone(true)


## Named camera spots. Vineyard: "walk" | "row" | "close" | "overview" | "valley" (optionally for Block index bi),
## "estate" | "estate_high" | "track". Winery: "hall" | "hall_panel" | "hall_stairs" | "stairs_down" |
## "stairs_up" | "cellar" | "cellar_heads" | "cellar_fuder" | "cellar_door" | "door".
func camera_preset(name: String, bi := 0) -> void:
	var pt: Array = winery.call("camera_preset", name)
	if not pt.is_empty():
		set_camera(winery.to_global(pt[0]), winery.to_global(pt[1]))
		return
	pt = vineyard.call("camera_preset", name, bi)
	set_camera(pt[0], pt[1])


func capture() -> Image:
	return viewport.get_texture().get_image()


# ------------------------------------------------------------------ zones
func _zone_now() -> String:
	return String(winery.call("zone_at", winery.to_local(player.cam.global_position)))


## Camera environment, interior lights/GI, sun, rain and sound follow where the eye is.
func _update_zone(force := false) -> void:
	if placed_key == "":
		return
	var z := _zone_now()
	var n: bool = z != "" or player.cam.global_position.distance_to(winery.global_position) < NEAR_WINERY
	if z == zone and n == near and not force:
		return
	var changed := z != zone
	zone = z
	near = n
	var cam: Camera3D = player.cam
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
	sun.directional_shadow_max_distance = 90.0 if zone == "" else 40.0
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
		player.set("enabled", on and not missing)
		player.set_physics_process(on)
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if ambience:
		ambience.call("set_running", on and not missing)
	if not on and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or missing:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
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
			KEY_M:
				sound_on = not sound_on
				_update_hint()
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if missing or placed_key == "":
		return
	_update_zone()
	ambience.call("update", delta, zone, player.cam.global_position, near)
	if show_hud:
		var p: Vector3 = player.cam.global_position
		hud_label.text = String(winery.call("hud_text", zone)) if zone != "" else String(vineyard.call("hud_text", p))
	hud_label.visible = show_hud
	hint_label.visible = show_hud
