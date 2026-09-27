# First-person walker for the 3D Estate: a capsule with gravity that walks up terrain slopes (to ~50°), through
# the winery door and down the cellar stairs (the stairs carry a ramp collider). view3d.gd feeds the mouse look
# and turns the keyboard on (`enabled`); tests drive it with `auto_dir`.
#
# `place_camera` puts the eye exactly somewhere (screenshots, drone-like presets) and freezes the body until the
# next move key, which drops it onto the ground below. `teleport` puts the feet on the ground and walks on.
extends CharacterBody3D

signal footstep(speed: float)

const EYE := 1.65
const RADIUS := 0.28
const HEIGHT := 1.75
const WALK := 1.6
const RUN := 4.2
const GRAVITY := 9.8

var cam: Camera3D
var head: Node3D
var yaw := 0.0
var pitch := 0.0
var enabled := false               # read the keyboard
var frozen := true                 # eye placed freely; no physics until the next move
var auto_dir := Vector3.ZERO       # scripted walking (tests): overrides the keys
var auto_run := true
var bounds := Rect2()              # outdoor walk limits (x, z); empty = none
var ground_fn: Callable            # (x, z) -> terrain height (safety net against falling through)
var indoors_fn: Callable           # (global position) -> bool; inside the winery the bounds and net don't apply
var rescues := 0                   # how often the safety net had to lift the player (tests assert 0)
var _stride := 0.0


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	cs.shape = cap
	cs.position = Vector3(0, HEIGHT / 2.0, 0)
	add_child(cs)
	head = Node3D.new()
	head.position = Vector3(0, EYE, 0)
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 6000.0
	head.add_child(cam)
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.5
	floor_constant_speed = true
	floor_block_on_wall = true
	max_slides = 6
	safe_margin = 0.02


func look(y: float, p: float) -> void:
	yaw = wrapf(y, -PI, PI)
	pitch = clampf(p, -1.45, 1.45)
	rotation = Vector3(0, yaw, 0)
	head.rotation = Vector3(pitch, 0, 0)


func look_at_point(eye: Vector3, target: Vector3) -> void:
	var d := target - eye
	if d.length() < 0.001:
		return
	look(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


## Eye exactly at pos looking at target; the body waits there (no gravity) until the next move key.
func place_camera(pos: Vector3, target: Vector3) -> void:
	global_position = pos - Vector3(0, EYE, 0)
	look_at_point(pos, target)
	velocity = Vector3.ZERO
	frozen = true
	reset_physics_interpolation()


## Feet at `feet` (on a floor), looking at target; walking resumes at once.
func teleport(feet: Vector3, target: Vector3) -> void:
	global_position = feet + Vector3(0, 0.04, 0)
	look_at_point(feet + Vector3(0, EYE, 0), target)
	velocity = Vector3.ZERO
	frozen = false
	reset_physics_interpolation()


func eye_position() -> Vector3:
	return global_position + Vector3(0, EYE, 0)


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	var run := false
	if auto_dir != Vector3.ZERO:
		dir = Vector3(auto_dir.x, 0, auto_dir.z).normalized()
		run = auto_run
	elif enabled:
		var k := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): k.z -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): k.z += 1
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): k.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): k.x += 1
		if k != Vector3.ZERO:
			dir = Basis(Vector3.UP, yaw) * k.normalized()
		run = Input.is_physical_key_pressed(KEY_SHIFT)
	if frozen:
		if dir == Vector3.ZERO:
			return
		frozen = false
		_drop_to_ground()
	var speed := RUN if run else WALK
	var want := dir * speed
	var accel := (12.0 if is_on_floor() else 3.0) * delta
	velocity.x = lerpf(velocity.x, want.x, minf(accel, 1.0))
	velocity.z = lerpf(velocity.z, want.z, minf(accel, 1.0))
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= GRAVITY * delta
	var before := global_position
	move_and_slide()
	_limits()
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if is_on_floor() and moved > 0.0005:
		_stride += moved
		var stride := 1.05 if run else 0.72
		if _stride >= stride:
			_stride = 0.0
			footstep.emit(moved / maxf(delta, 0.0001))


func _limits() -> void:
	var inside: bool = indoors_fn.is_valid() and indoors_fn.call(global_position + Vector3(0, 1.0, 0))
	if inside:
		return
	var p := global_position
	if bounds.size != Vector2.ZERO:
		var cx := clampf(p.x, bounds.position.x, bounds.end.x)
		var cz := clampf(p.z, bounds.position.y, bounds.end.y)
		if cx != p.x or cz != p.z:
			global_position = Vector3(cx, p.y, cz)
	if ground_fn.is_valid():
		var g: float = ground_fn.call(global_position.x, global_position.z)
		if global_position.y < g - 1.5:                 # fell through the terrain: put it back on top
			global_position.y = g + 0.1
			velocity = Vector3.ZERO
			rescues += 1


func _drop_to_ground() -> void:
	var from := eye_position()
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -400, 0))
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit["position"] + Vector3(0, 0.04, 0)
	velocity = Vector3.ZERO
