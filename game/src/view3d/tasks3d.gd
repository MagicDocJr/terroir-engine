# Staff tasks in the 3D world (docs/superpowers/specs/2026-09-28-tasks-in-3d-design.md §6).
#   markers   each open task gets a stake with a coloured ribbon and a label at its demonstration vine (the vine nearest
#             the headland on the Block's middle row) or above its Lot's tank in the hall
#   close-up  E opens a close view of the vine (or the tank top) with the task's options as clickable parts:
#             pruning   three canes of the option's bud count along the fruiting wire
#             leaves    a leaf cluster on the morning and on the afternoon side of the row
#             thinning  the bunches, and three tags (keep all / drop a fifth / drop two fifths)
#             cap       four tools on the tank top (pump-over hose, plunger, délestage tank, gentle hose)
# Everything shown comes from the snapshot's `tasks`; nothing here decides an outcome (ADR 0001). The choice leaves
# through view3d.gd's `task_chosen` signal and the shell sends the `task` command.
extends Node3D

const PICK_LAYER := 1 << 19
const COLORS := {"Prune": Color(0.96, 0.62, 0.16), "LeafRemoval": Color(0.38, 0.82, 0.3), "GreenHarvest": Color(0.7, 0.4, 0.95), "CapManagement": Color(0.32, 0.62, 0.98)}
const TANK_H := 3.54                 # winery.json hall.tankInfo.height
const THIN_DROP := {"0": [], "1": [2, 7], "2": [1, 3, 6, 8]}   # which of the ten bunches a level drops (a fifth / two fifths)

var vy: Node3D                       # vineyard.gd
var wy: Node3D                       # winery.gd
var markers := {}                    # task id -> {node, spot: [vine, stand, marker], task}
var parts: Node3D                    # the close-up's clickable parts (null when none)
var pickables: Array = []            # [{body, value, meshes: [MeshInstance3D], mat: StandardMaterial3D}]
var extras: Array = []               # close-up meshes animated on confirm: {mesh, value, role}
var active := {}                     # the task in the close-up
var selected := {}                   # leaf removal: {"morning": bool, "afternoon": bool}
var morning_sign := 1.0              # which side of the row (±W) faces east
var red := true
var heights := {}                    # task id -> the vine's height scale (Côte d'Or vines are trained lower)
var vine_cache := {}                 # "plot|block" -> the demonstration vine [x, z, …, scale] (vineyard.gd _block_vines is costly)
var hs := 1.0
var t := 0.0


func setup(vineyard: Node3D, winery: Node3D) -> void:
	vy = vineyard
	wy = winery


# ------------------------------------------------------------------ markers
func apply(D: Dictionary) -> void:
	for id in markers:
		(markers[id]["node"] as Node3D).queue_free()
	markers.clear()
	for task in D.get("tasks", []):
		if String(task.get("status", "")) != "Open":
			continue
		var spot := demo_spot(task)
		if spot.is_empty():
			continue
		markers[int(task["id"])] = {"node": _marker(task, spot), "spot": spot, "task": task}


## [vine, stand, marker] in this node's frame, or [] when the task has no place now (e.g. its Lot went into barrel).
func demo_spot(task: Dictionary) -> Array:
	if String(task.get("where", "")) == "hall":
		var tank: Node3D = wy.call("tank_for_lot", String(task.get("lot", "")))
		if tank == null:
			return []
		var top: Vector3 = tank.global_transform * Vector3(0, TANK_H, 0)
		var front: Vector3 = tank.global_transform.basis.z.normalized()
		var foot: Vector3 = tank.global_position + front * 1.9
		return [to_local(top), to_local(foot), to_local(top + Vector3(0, 0.45, 0))]
	var blk := _block(String(task.get("block", "")))
	if blk.is_empty():
		return []
	var fr: Dictionary = vy.call("block_frame", blk)
	var sp: float = fr["row"]
	var wmid := (float(fr["wmin"]) + float(fr["wmax"])) / 2.0
	var k := roundf(wmid / sp)
	for dk in [0.0, 1.0, -1.0, 2.0, -2.0]:
		var w: float = (k + float(dk)) * sp
		var span: Vector2 = vy.call("row_span", fr, w)
		if span.y - span.x < 3.0:
			continue
		# the real planted vine nearest the headland end of this row (vineyard.gd _block_vines), so the close-up parts grow from it
		var want := _P(fr, span.x + 1.2, w)
		var key := "%s|%s|%d" % [vy.get("plot_key"), blk["id"], int(dk)]
		if not vine_cache.has(key):
			var best0 := [want.x, want.z, 0.0, 1.0, 1.0]
			var bd := INF
			for vv in vy.call("_block_vines", blk):
				var dd := Vector2(float(vv[0]) - want.x, float(vv[1]) - want.z).length()
				if dd < bd:
					bd = dd
					best0 = vv
			vine_cache[key] = best0
		var best: Array = vine_cache[key]
		var vine := Vector3(float(best[0]), vy.call("ground_height", float(best[0]), float(best[1])), float(best[1]))
		var U2 := Vector2(fr["U"]); var W2 := Vector2(fr["W"])
		var vu := Vector2(vine.x, vine.z).dot(U2)
		var vw := Vector2(vine.x, vine.z).dot(W2)
		var stand := _P(fr, vu - 1.7, vw + 0.5 * sp)     # in the alley, a couple of steps before the vine: marker and vine in view
		var mk := _P(fr, vu - 0.4, vw + 0.24 * sp)
		heights[int(task["id"])] = float(best[4])
		return [vine, stand, mk]
	return []


func _block(id: String) -> Dictionary:
	for b in vy.get("blocks"):
		if String(b["id"]) == id:
			return b
	return {}


func _P(fr: Dictionary, u: float, w: float) -> Vector3:
	var p: Vector2 = fr["U"] * u + fr["W"] * w
	return Vector3(p.x, vy.call("ground_height", p.x, p.y), p.y)


func _mat(col: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m


func _marker(task: Dictionary, spot: Array) -> Node3D:
	var col: Color = COLORS.get(String(task["kind"]), Color.WHITE)
	var n := Node3D.new()
	n.position = spot[2]
	add_child(n)
	var stake := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.022; cm.bottom_radius = 0.028; cm.height = 1.5; cm.radial_segments = 8
	stake.mesh = cm
	stake.position.y = 0.75
	stake.material_override = _mat(Color(0.45, 0.33, 0.2))
	n.add_child(stake)
	var rib := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(0.34, 0.13)
	rib.mesh = q
	rib.position = Vector3(0.17, 1.4, 0)
	var rm := _mat(col, 1.6); rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rib.material_override = rm
	rib.name = "Ribbon"
	n.add_child(rib)
	var lab := Label3D.new()
	var place := ("Lot %s" % task["lot"]) if String(task["kind"]) == "CapManagement" else ("Block %s" % task["block"])
	lab.text = "%s\n%s · due %s" % [task["title"], place, task["due"]]
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position.y = 1.72
	lab.font_size = 40
	lab.pixel_size = 0.0019
	lab.outline_size = 12
	lab.modulate = col.lightened(0.35)
	lab.outline_modulate = Color(0, 0, 0, 0.85)
	lab.visibility_range_end = 60.0
	n.add_child(lab)
	return n


func _process(delta: float) -> void:
	t += delta
	for id in markers:
		var rib: Node3D = (markers[id]["node"] as Node3D).get_node_or_null("Ribbon")
		if rib:
			rib.rotation.y = sin(t * 2.3 + float(id)) * 0.35


## The open task whose demonstration vine (or tank) is within max_d of the global position, else {}.
func nearest(global_pos: Vector3, max_d: float) -> Dictionary:
	var best := {}
	var bd := max_d
	var p := to_local(global_pos)
	for id in markers:
		var spot: Array = markers[id]["spot"]
		var hall := String(markers[id]["task"].get("where", "")) == "hall"
		var ref: Vector3 = spot[1] if hall else spot[0]
		var d := minf(Vector2(p.x - ref.x, p.z - ref.z).length(), Vector2(p.x - spot[1].x, p.z - spot[1].z).length())
		if hall and absf(p.y - ref.y) > 2.5:
			continue
		if d <= bd:
			bd = d
			best = markers[id]["task"]
	return best


## Feet position and look target (global) in front of the task's vine or tank.
func stand_point(id: int) -> Array:
	if not markers.has(id):
		return []
	var spot: Array = markers[id]["spot"]
	return [to_global(spot[1]), to_global(spot[0] + Vector3(0, 0.9, 0))]


# ------------------------------------------------------------------ close-up
## Builds the task's clickable parts and returns [camera position, look target] (global).
func open_closeup(task: Dictionary) -> Array:
	close_closeup()
	var id := int(task["id"])
	if not markers.has(id):
		return []
	active = task
	selected = {"morning": false, "afternoon": false}
	parts = Node3D.new()
	parts.name = "TaskCloseup"
	add_child(parts)
	var spot: Array = markers[id]["spot"]
	var kind := String(task["kind"])
	red = bool(task.get("red", true))
	(markers[id]["node"] as Node3D).visible = false
	if kind == "CapManagement":
		return _cap_parts(task, spot)
	var blk := _block(String(task["block"]))
	var fr: Dictionary = vy.call("block_frame", blk)
	var U := Vector3(fr["U"].x, 0, fr["U"].y)
	var W := Vector3(fr["W"].x, 0, fr["W"].y)
	var east: Vector3 = vy.call("_sun_world", 0.0, 90.0)
	morning_sign = 1.0 if W.dot(Vector3(east.x, 0, east.z)) >= 0.0 else -1.0
	var v: Vector3 = spot[0]
	hs = float(heights.get(id, 1.0))
	match kind:
		"Prune": _prune_parts(task, v, U, W)
		"LeafRemoval": _leaf_parts(task, v, U, W)
		"GreenHarvest": _thin_parts(task, v, U, W)
	var cam := v + W * 1.05 + U * 0.25 + Vector3(0, 1.25 * hs + 0.05, 0)
	var target := v + U * 0.3 + Vector3(0, 0.76 * hs, 0)
	return [to_global(cam), to_global(target)]


func close_closeup() -> void:
	if parts:
		parts.queue_free()
	parts = null
	pickables.clear()
	extras.clear()
	if not active.is_empty() and markers.has(int(active["id"])):
		(markers[int(active["id"])]["node"] as Node3D).visible = true
	active = {}


func _pickable(value: String, meshes: Array, box: Vector3, at: Vector3, basis := Basis()) -> Dictionary:
	var body := StaticBody3D.new()
	body.collision_layer = PICK_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = box
	cs.shape = bs
	body.add_child(cs)
	body.transform = Transform3D(basis, at)
	body.set_meta("option", value)
	parts.add_child(body)
	var p := {"body": body, "value": value, "meshes": meshes}
	pickables.append(p)
	return p


func _mesh(mesh: Mesh, mat: Material, xf: Transform3D, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	(parent if parent else parts).add_child(mi)
	return mi


static var _leaf_cache: ArrayMesh
static var _bunch_cache: ArrayMesh

## A five-lobed grape leaf (palmate outline, triangle fan), about 14 cm across, facing +Z.
static func _leaf_mesh() -> ArrayMesh:
	if _leaf_cache:
		return _leaf_cache
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 40
	var pts := []
	for i in n:
		var a := TAU * float(i) / float(n) + PI / 2.0
		var lobe := 0.72 + 0.28 * absf(cos(2.5 * (a - PI / 2.0)))       # five lobes
		var notch := 0.55 if absf(wrapf(a - 1.5 * PI, -PI, PI)) < 0.25 else 1.0   # the petiole sinus at the bottom
		pts.append(Vector3(cos(a), sin(a) + 0.2, 0) * 0.07 * lobe * notch)
	for i in n:
		st.set_normal(Vector3(0, 0, 1)); st.add_vertex(Vector3(0, 0.014, 0.004))
		st.set_normal(Vector3(0, 0, 1)); st.add_vertex(pts[i])
		st.set_normal(Vector3(0, 0, 1)); st.add_vertex(pts[(i + 1) % n])
	_leaf_cache = st.commit()
	return _leaf_cache


## A grape bunch: about 40 berries on a cone (shoulders on top), about 14 cm long, hanging from the origin.
static func _bunch_mesh() -> ArrayMesh:
	if _bunch_cache:
		return _bunch_cache
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var berry := SphereMesh.new(); berry.radius = 0.0105; berry.height = 0.021; berry.radial_segments = 8; berry.rings = 4
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	for i in 42:
		var f := float(i) / 42.0
		var y := -0.01 - f * 0.13
		var r := 0.034 * (1.0 - f * 0.75) * sqrt(rng.randf())
		var a := rng.randf() * TAU
		st.append_from(berry, 0, Transform3D(Basis(), Vector3(cos(a) * r, y, sin(a) * r)))
	_bunch_cache = st.commit()
	return _bunch_cache


func _label(text: String, at: Vector3, col := Color(1, 0.96, 0.88), size := 30) -> Label3D:
	var lab := Label3D.new()
	lab.text = text
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = at
	lab.font_size = size
	lab.pixel_size = 0.0022
	lab.outline_size = 10
	lab.outline_modulate = Color(0, 0, 0, 0.9)
	lab.modulate = col
	lab.no_depth_test = true
	parts.add_child(lab)
	return lab


## Basis whose local +Y points along dir (for cylinders and capsules).
static func _along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, y, x.cross(y).normalized() * -1.0).orthonormalized()


func _prune_parts(task: Dictionary, v: Vector3, U: Vector3, W: Vector3) -> void:
	# three alternatives fanned from the head of the real vine's trunk, drawn as the Block's training system prunes:
	#   Guyot        a long cane with its buds, tied down onto the fruiting wire on confirm
	#   Cordon       a permanent arm carrying two-bud spurs (buds ÷ 2 spurs), laid on the wire on confirm
	#   Einzelpfahl  an arched bow round the stake (no wire: it stays bent on confirm)
	var wood := Color(0.36, 0.23, 0.13)
	var head := v + Vector3(0, 0.66 * hs, 0) + W * 0.03
	var opts: Array = task.get("options", [])
	var training := str(task.get("training", "Guyot"))
	var angles: Array = {"Cordon": [8.0, 20.0, 32.0], "Einzelpfahl": [8.0, 24.0, 40.0]}.get(training, [14.0, 30.0, 46.0])
	var bud := SphereMesh.new(); bud.radius = 0.014; bud.height = 0.022; bud.radial_segments = 6; bud.rings = 3
	for i in opts.size():
		var o: Dictionary = opts[i]
		var buds := int(o.get("buds", [6, 8, 11][mini(i, 2)]))
		var pivot := Node3D.new()                        # rotates the cane down onto the wire on confirm
		pivot.position = head + W * (0.035 * (i - 1))
		var axis := U.cross(Vector3.UP).normalized()
		pivot.basis = Basis(axis, deg_to_rad(angles[mini(i, 2)])) if U.cross(Vector3.UP).length() > 0.01 else Basis()
		parts.add_child(pivot)
		var up := Vector3.UP                             # square to the part in its fan plane: spurs stand upright once laid on the wire
		var mat := _mat(wood)
		var meshes := []
		var pts := []                                    # the part's axis (pivot frame), for picking and the label
		var count_label := "%d buds" % buds
		match training:
			"Cordon":
				var spurs := maxi(1, int(round(buds / 2.0)))
				var length := clampf(spurs * 0.075, 0.35, 0.85)
				meshes.append(_segment(Vector3.ZERO, U * length, 0.02, 0.016, mat, pivot))
				for k in spurs:
					var base := U * (length * (float(k) + 0.5) / float(spurs))
					meshes.append(_segment(base, base + up * 0.06, 0.009, 0.007, mat, pivot))
					for b in 2:
						meshes.append(_mesh(bud, mat, Transform3D(Basis(), base + up * (0.025 + 0.028 * b) + U * 0.008), pivot))
				for k in 11:
					pts.append(U * (length * float(k) / 10.0))
				count_label = "%d spurs · %d buds" % [spurs, spurs * 2]
			"Einzelpfahl":
				var length := clampf(buds * 0.05, 0.3, 0.8)
				var prev := Vector3.ZERO
				for k in range(1, 13):
					var s := float(k) / 12.0
					var q := U * (length * 0.5 * (1.0 - cos(PI * s))) + up * (length * 0.42 * sin(PI * s))
					meshes.append(_segment(prev, q, 0.012, 0.009, mat, pivot))
					prev = q
				for k in buds:
					var s2 := (float(k) + 0.6) / float(buds)
					meshes.append(_mesh(bud, mat, Transform3D(Basis(), U * (length * 0.5 * (1.0 - cos(PI * s2))) + up * (length * 0.42 * sin(PI * s2) + 0.011)), pivot))
				for k in 13:
					var s3 := float(k) / 12.0
					pts.append(U * (length * 0.5 * (1.0 - cos(PI * s3))) + up * (length * 0.42 * sin(PI * s3)))
				pivot.set_meta("tied", true)             # a bow is bent, not laid on a wire
			_:
				var length := clampf(buds * 0.052, 0.35, 0.95)
				var cane := CylinderMesh.new(); cane.top_radius = 0.008; cane.bottom_radius = 0.013; cane.height = length; cane.radial_segments = 6
				meshes.append(_mesh(cane, mat, Transform3D(_along(U), U * length / 2.0), pivot))
				for k in buds:
					meshes.append(_mesh(bud, mat, Transform3D(Basis(), U * (length * (float(k) + 0.6) / float(buds)) + Vector3(0, 0.011, 0)), pivot))
				for k in 11:
					pts.append(U * (length * float(k) / 10.0))
		var mid: Vector3 = pivot.transform * pts[pts.size() / 2]
		var pk := _pickable(String(o["value"]), meshes, Vector3(0.12, 0.12, 0.12), mid)
		pk["pivot"] = pivot
		pk["pts"] = pts
		var far: Vector3 = pts[pts.size() - 1]
		var tip: Vector3 = pivot.transform * (far + U * 0.1)
		_label("%s · %s" % [String(o["label"]).split(" · ")[0], count_label], tip + Vector3(0, 0.05, 0))
		for m in meshes:
			extras.append({"mesh": m, "value": String(o["value"]), "role": "cane", "pivot": pivot})


## A cylinder from a to b (in parent's frame).
func _segment(a: Vector3, b: Vector3, r0: float, r1: float, mat: Material, parent: Node3D) -> MeshInstance3D:
	var cm := CylinderMesh.new(); cm.bottom_radius = r0; cm.top_radius = r1; cm.height = maxf(a.distance_to(b), 0.001); cm.radial_segments = 6
	return _mesh(cm, mat, Transform3D(_along(b - a), (a + b) / 2.0), parent)


func _leaf_parts(task: Dictionary, v: Vector3, U: Vector3, W: Vector3) -> void:
	var leaf := _leaf_mesh()
	var bunch := _bunch_mesh()
	var rng := RandomNumberGenerator.new(); rng.seed = int(task["id"]) * 7
	for side_name in ["morning", "afternoon"]:
		var sgn := morning_sign if side_name == "morning" else -morning_sign
		var value := "Morning" if side_name == "morning" else "Afternoon"
		var mat := _mat(Color(0.22, 0.42, 0.13)); mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var meshes := []
		for k in 16:
			var at := v + W * (sgn * (0.12 + rng.randf() * 0.07)) + U * (-0.36 + 0.048 * k) + Vector3(0, (0.62 + rng.randf() * 0.38) * hs, 0)
			var face := (W * sgn + Vector3(0, rng.randf_range(-0.3, 0.5), 0) + U * rng.randf_range(-0.4, 0.4)).normalized()
			var b := Basis.looking_at(-face, Vector3.UP).rotated(face, rng.randf_range(-0.6, 0.6))
			meshes.append(_mesh(leaf, mat, Transform3D(b, at)))
		for k in 3:
			var bat := v + W * (0.06 * sgn) + U * (-0.2 + 0.2 * k) + Vector3(0, 0.66 * hs, 0)
			_mesh(bunch, _mat(Color(0.42, 0.55, 0.22) if not red else Color(0.28, 0.32, 0.12)), Transform3D(Basis(), bat))
		_pickable(value, meshes, Vector3(0.8, 0.45, 0.2), v + W * (0.16 * sgn) + Vector3(0, 0.82 * hs, 0), Basis(Vector3.UP, atan2(U.x, U.z)))
		_label("%s side" % side_name.capitalize(), v + W * (0.26 * sgn) + U * 0.5 + Vector3(0, 1.1 if sgn * morning_sign > 0 else 1.28, 0))
		for m in meshes:
			extras.append({"mesh": m, "value": value, "role": "leaf"})


func _thin_parts(task: Dictionary, v: Vector3, U: Vector3, W: Vector3) -> void:
	var col := Color(0.28, 0.1, 0.32) if red else Color(0.6, 0.64, 0.3)
	var bunch := _bunch_mesh()
	for k in 10:
		var at := v + U * (-0.34 + 0.075 * k) + W * (0.08 if k % 2 == 0 else 0.12) + Vector3(0, (0.7 + (0.04 if k % 3 == 0 else 0.0)) * hs, 0)
		var mi := _mesh(bunch, _mat(col), Transform3D(Basis(), at))
		extras.append({"mesh": mi, "value": str(k), "role": "bunch"})
	var opts: Array = task.get("options", [])
	for i in opts.size():
		var o: Dictionary = opts[i]
		var at := v + W * 0.34 + U * (0.55 + 0.02 * i) + Vector3(0, 1.12 - 0.17 * i, 0)
		var board := BoxMesh.new(); board.size = Vector3(0.34, 0.13, 0.01)
		var bm := _mesh(board, _mat(Color(0.82, 0.76, 0.62)), Transform3D(Basis(Vector3.UP, atan2(W.x, W.z)), at))
		_pickable(String(o["value"]), [bm], Vector3(0.36, 0.15, 0.05), at, Basis(Vector3.UP, atan2(W.x, W.z)))
		var bl := _label(String(o["label"]), at + W * 0.012, Color(0.14, 0.09, 0.04), 20)
		bl.no_depth_test = false
		bl.outline_size = 0
		bl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		bl.basis = Basis(Vector3.UP, atan2(W.x, W.z))


func _cap_parts(task: Dictionary, spot: Array) -> Array:
	var top: Vector3 = spot[0]
	var tank: Node3D = wy.call("tank_for_lot", String(task.get("lot", "")))
	var front := to_local(tank.global_position + tank.global_transform.basis.z) - to_local(tank.global_position)
	front.y = 0.0
	front = front.normalized()
	var side := front.cross(Vector3.UP).normalized()
	var cap := CylinderMesh.new(); cap.top_radius = 0.62; cap.bottom_radius = 0.62; cap.height = 0.04
	_mesh(cap, _mat(Color(0.22, 0.05, 0.12)), Transform3D(Basis(), top + Vector3(0, 0.03, 0)))
	var ring := TorusMesh.new(); ring.inner_radius = 0.6; ring.outer_radius = 0.68
	_mesh(ring, _mat(Color(0.75, 0.76, 0.78)), Transform3D(Basis(), top + Vector3(0, 0.05, 0)))
	var tools := [
		{"v": "0", "name": "Pump-over hose", "mesh": _torus(0.06, 0.14), "col": Color(0.2, 0.45, 0.25), "box": Vector3(0.32, 0.12, 0.32), "b": Basis(Vector3.RIGHT, PI / 2.0)},
		{"v": "1", "name": "Plunger", "mesh": _cyl(0.018, 1.1), "col": Color(0.78, 0.78, 0.8), "box": Vector3(0.1, 1.1, 0.1), "b": Basis()},
		{"v": "2", "name": "Délestage tank", "mesh": _cyl(0.16, 0.34), "col": Color(0.68, 0.7, 0.74), "box": Vector3(0.34, 0.36, 0.34), "b": Basis()},
		{"v": "3", "name": "Gentle hose", "mesh": _torus(0.03, 0.09), "col": Color(0.3, 0.55, 0.35), "box": Vector3(0.22, 0.1, 0.22), "b": Basis(Vector3.RIGHT, PI / 2.0)},
	]
	for i in tools.size():
		var tl: Dictionary = tools[i]
		var at := top + front * (0.3 - 0.12 * absf(i - 1.5)) + side * (-0.55 + 0.37 * i) + Vector3(0, 0.25 if tl["v"] != "1" else 0.6, 0)
		var mi := _mesh(tl["mesh"], _mat(tl["col"]), Transform3D(tl["b"], at))
		var meshes := [mi]
		if tl["v"] == "1":
			var disc := CylinderMesh.new(); disc.top_radius = 0.12; disc.bottom_radius = 0.12; disc.height = 0.02
			meshes.append(_mesh(disc, _mat(tl["col"]), Transform3D(Basis(), at - Vector3(0, 0.55, 0))))
		_pickable(String(tl["v"]), meshes, tl["box"], at, tl["b"])
		_label(tl["name"], at + Vector3(0, 0.14 if tl["v"] == "1" else 0.24 + 0.12 * (i % 2), 0))   # the plunger's label sits mid-shaft, inside the frame
		for m in meshes:
			extras.append({"mesh": m, "value": String(tl["v"]), "role": "tool"})
	var cam := top + front * 1.05 + side * 0.75 + Vector3(0, 0.95, 0)
	return [to_global(cam), to_global(top + Vector3(0, 0.2, 0))]


static func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = h; c.radial_segments = 12
	return c


static func _torus(inner: float, outer: float) -> TorusMesh:
	var tm := TorusMesh.new(); tm.inner_radius = inner; tm.outer_radius = outer
	return tm


## The option under a ray (global), or "".
func pick(from: Vector3, dir: Vector3) -> String:
	if parts == null:
		return ""
	if String(active.get("kind", "")) == "Prune":
		return _nearest_cane(from, dir)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 12.0, PICK_LAYER)
	q.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not (hit["collider"] as Object).has_meta("option"):
		return ""
	return String((hit["collider"] as Object).get_meta("option"))


## Pruning: the cane whose axis passes closest to the ray (within 6 cm). The three canes fan from one head, so their
## pick boxes overlap near it and the physics ray would often hit the neighbouring cane.
func _nearest_cane(from: Vector3, dir: Vector3) -> String:
	var d := dir.normalized()
	var best := ""
	var bd := 0.06
	for p in pickables:
		var pv: Node3D = p["pivot"]
		for q0 in p["pts"]:
			var q: Vector3 = pv.global_transform * (q0 as Vector3)
			var along := maxf((q - from).dot(d), 0.0)
			var dist := (from + d * along).distance_to(q)
			if dist < bd:
				bd = dist
				best = String(p["value"])
	return best


## Leaf removal: a click toggles a side; returns the resulting option value.
func toggle_side(value: String) -> String:
	if value == "Morning": selected["morning"] = not selected["morning"]
	elif value == "Afternoon": selected["afternoon"] = not selected["afternoon"]
	elif value == "Both": selected = {"morning": true, "afternoon": true}
	elif value == "None": selected = {"morning": false, "afternoon": false}
	var m: bool = selected["morning"]
	var a: bool = selected["afternoon"]
	return "Both" if m and a else "Morning" if m else "Afternoon" if a else "None"


## Tints what the option acts on (the chosen cane, the leaves to pull, the bunches to drop, the tool).
func highlight(value: String) -> void:
	var kind := String(active.get("kind", ""))
	for p in pickables:
		var on := String(p["value"]) == value
		if kind == "LeafRemoval":
			on = (String(p["value"]) == "Morning" and value in ["Morning", "Both"]) or (String(p["value"]) == "Afternoon" and value in ["Afternoon", "Both"])
		for m in p["meshes"]:
			var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
			if mat == null:
				continue
			mat.emission_enabled = on
			mat.emission = Color(1.0, 0.75, 0.25) if kind != "LeafRemoval" else Color(1.0, 0.85, 0.3)
			mat.emission_energy_multiplier = 0.9
	if kind == "GreenHarvest":
		var drop: Array = THIN_DROP.get(value, [])
		for e in extras:
			if String(e["role"]) != "bunch":
				continue
			var mat := (e["mesh"] as MeshInstance3D).material_override as StandardMaterial3D
			mat.emission_enabled = int(e["value"]) in drop
			mat.emission = Color(1.0, 0.25, 0.2)
			mat.emission_energy_multiplier = 1.4


## The result of the choice, animated: canes cut, leaves pulled, bunches dropped, the tool at work.
## Late leaf removal: the chosen leaves stay and a tag says the crew pulls them at véraison.
func play_confirm(value: String, timing: String) -> void:
	var kind := String(active.get("kind", ""))
	var tw: Tween = null             # created on first use: an empty Tween logs an error when it starts
	var later := kind == "LeafRemoval" and timing == "Late"
	if later and parts:
		var anchor := Vector3.ZERO
		var n := 0
		for e in extras:
			if String(e["role"]) == "leaf" and (value == "Both" or String(e["value"]) == value):
				anchor += (e["mesh"] as MeshInstance3D).position; n += 1
		if n > 0:
			_label("The crew pulls these at véraison", anchor / n + Vector3(0, 0.32 * hs, 0), Color(1.0, 0.86, 0.45), 26)
	for e in extras:
		var mi: MeshInstance3D = e["mesh"]
		var role := String(e["role"])
		var falls := false
		match role:
			"cane":
				falls = String(e["value"]) != value
				if not falls and e.has("pivot") and not (e["pivot"] as Node3D).has_meta("tied"):
					var pv: Node3D = e["pivot"]
					pv.set_meta("tied", true)
					create_tween().tween_property(pv, "basis", Basis(), 0.7).set_trans(Tween.TRANS_SINE)
			"leaf": falls = not later and ((String(e["value"]) == "Morning" and value in ["Morning", "Both"]) or (String(e["value"]) == "Afternoon" and value in ["Afternoon", "Both"]))
			"bunch": falls = int(e["value"]) in THIN_DROP.get(value, [])
			"tool":
				if String(e["value"]) == value:
					var p0 := mi.position
					var t2 := create_tween()
					t2.tween_property(mi, "position", p0 - Vector3(0, 0.35, 0), 0.22)
					t2.tween_property(mi, "position", p0, 0.22)
					t2.tween_property(mi, "position", p0 - Vector3(0, 0.35, 0), 0.22)
					t2.tween_property(mi, "position", p0, 0.22)
		if falls and role == "cane" and e.has("pivot"):
			var pv2: Node3D = e["pivot"]
			if not pv2.has_meta("dropped"):
				pv2.set_meta("dropped", true)
				var g2: float = vy.call("ground_height", pv2.position.x, pv2.position.z)
				if tw == null: tw = create_tween().set_parallel(true)
				tw.tween_property(pv2, "position:y", g2 + 0.05, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				tw.tween_property(pv2, "rotation", pv2.rotation + Vector3(0.9, 0.5, 0.3), 0.6)
			continue
		if falls:
			var ground: float = vy.call("ground_height", mi.position.x, mi.position.z) if kind != "CapManagement" else mi.position.y - 0.5
			if tw == null: tw = create_tween().set_parallel(true)
			tw.tween_property(mi, "position:y", ground + 0.03, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(mi, "rotation", mi.rotation + Vector3(1.2, 0.4, 0.8), 0.6)
