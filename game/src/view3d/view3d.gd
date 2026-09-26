# 3D views of the Estate (look-only in the MVP): the vineyard, the barrel cellar and the fermentation hall.
#
# Contract with the UI (game/src/ui):
#   apply_snapshot(D)  D = parsed Sim.Snapshot() JSON; call on entry and after every advance
#   set_view(kind)     "vineyard" | "cellar" | "hall"
#   exit_requested     emitted on Tab, or Esc while the mouse is not captured
# Input is handled only while this node is visible: WASD + mouse look (click to capture), Shift to run,
# 1/2/3 switch vineyard/cellar/hall. The 3D world renders in its own SubViewport (own World3D), so the UI
# can show/hide this Control like any other screen; rendering stops while it is hidden.
extends Control

signal exit_requested

const A := preload("res://src/view3d/assets3d.gd")
const VIEWS := ["vineyard", "cellar", "hall"]

var show_hud := true
var viewport: SubViewport
var container: SubViewportContainer
var vineyard: Node3D
var cellar: Node3D
var hall: Node3D
var current := "vineyard"
var D := {}
var rig := {}                 # per view: {pos, yaw, pitch}
var hud_label: Label
var hint_label: Label
var missing := false


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
	container.add_child(viewport)
	# shadow quality is global (project settings normally); set it here so the view needs no project changes
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	missing = not A.available()
	vineyard = _make("res://src/view3d/vineyard.gd", "Vineyard")
	cellar = _make("res://src/view3d/winery.gd", "Cellar", "cellar")
	hall = _make("res://src/view3d/winery.gd", "Hall", "hall")
	cellar.visible = false
	hall.visible = false
	_build_hud()
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _exit_tree() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	A.clear()


func _make(script: String, name_: String, room := "") -> Node3D:
	var n := Node3D.new()
	n.name = name_
	n.set_script(load(script))
	if room != "":
		n.set("room", room)
	viewport.add_child(n)
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
	hint_label.text = "Click to look around · WASD move · Shift run · 1 vineyard  2 cellar  3 hall · Tab back"
	add_child(hint_label)
	if missing:
		hud_label.text = "3D assets missing — run game/tools/sync_assets3d.sh"


# ------------------------------------------------------------------ contract
func apply_snapshot(snap: Dictionary) -> void:
	D = snap
	if missing or snap.is_empty():
		return
	var before: String = vineyard.get("plot_key")
	vineyard.call("apply_snapshot", snap)
	cellar.call("apply_snapshot", snap)
	hall.call("apply_snapshot", snap)
	if before != String(vineyard.get("plot_key")):
		rig.erase("vineyard")                 # new landscape: start again at the entry viewpoint
	if not rig.has(current):
		set_view(current)


func set_view(kind: String) -> void:
	if not kind in VIEWS or missing:
		return
	_store_rig()
	current = kind
	for v in VIEWS:
		var n := _node(v)
		var on: bool = v == kind
		n.visible = on
		if n.has_method("on_hidden") and not on:
			n.call("on_hidden")
	var node := _node(kind)
	if node.has_method("on_shown"):
		node.call("on_shown")
	var cam: Camera3D = node.get("cam")
	if cam == null:
		return
	cam.current = true
	if rig.has(kind):
		_apply_rig()
	else:
		var pt: Array = node.call("camera_preset", "walk" if kind == "vineyard" else kind)
		set_camera(pt[0], pt[1])


## Place the camera of the current view (used by the capture harness and by presets).
func set_camera(pos: Vector3, target: Vector3) -> void:
	var cam: Camera3D = _node(current).get("cam")
	if cam == null:
		return
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	rig[current] = {"pos": pos, "yaw": cam.rotation.y, "pitch": cam.rotation.x}


## Named presets: vineyard "walk" | "row" | "close" | "overview" | "valley" (optionally for Block index bi);
## cellar "cellar" | "cellar_heads" | "cellar_fuder"; hall "hall" | "hall_panel".
func camera_preset(name: String, bi := 0) -> void:
	var node := _node(current)
	var pt: Array = node.call("camera_preset", name, bi) if current == "vineyard" else node.call("camera_preset", name)
	set_camera(pt[0], pt[1])


func capture() -> Image:
	return viewport.get_texture().get_image()


# ------------------------------------------------------------------ internals
func _node(kind: String) -> Node3D:
	return vineyard if kind == "vineyard" else (cellar if kind == "cellar" else hall)


func _store_rig() -> void:
	var cam: Camera3D = _node(current).get("cam")
	if cam and rig.has(current):
		rig[current] = {"pos": cam.global_position, "yaw": cam.rotation.y, "pitch": cam.rotation.x}


func _apply_rig() -> void:
	var cam: Camera3D = _node(current).get("cam")
	var r: Dictionary = rig[current]
	cam.global_position = r["pos"]
	cam.rotation = Vector3(r["pitch"], r["yaw"], 0)


func _on_visibility_changed() -> void:
	var on := is_visible_in_tree()
	set_process(on)
	set_process_input(on)
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or missing:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		accept_event()
	elif e is InputEventMouseMotion and captured and rig.has(current):
		var r: Dictionary = rig[current]
		r["yaw"] = float(r["yaw"]) - e.relative.x * 0.0025
		r["pitch"] = clampf(float(r["pitch"]) - e.relative.y * 0.0025, -1.45, 1.45)
		_apply_rig()
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


func _process(delta: float) -> void:
	if missing or not rig.has(current):
		return
	var node := _node(current)
	var cam: Camera3D = node.get("cam")
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): dir.z -= 1
	if Input.is_physical_key_pressed(KEY_S): dir.z += 1
	if Input.is_physical_key_pressed(KEY_A): dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D): dir.x += 1
	if dir != Vector3.ZERO:
		var run := Input.is_physical_key_pressed(KEY_SHIFT)
		var speed := (4.5 if run else 1.6) if current == "vineyard" else (3.0 if run else 1.4)
		var r: Dictionary = rig[current]
		var mv := Basis(Vector3.UP, float(r["yaw"])) * dir.normalized() * speed * delta
		var p: Vector3 = r["pos"] + Vector3(mv.x, 0, mv.z)
		r["pos"] = node.call("constrain", p)
		_apply_rig()
	if show_hud and cam:
		hud_label.text = String(node.call("hud_text", cam.global_position))
	hud_label.visible = show_hud
	hint_label.visible = show_hud
