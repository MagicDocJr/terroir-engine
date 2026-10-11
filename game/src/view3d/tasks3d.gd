# Staff tasks in the 3D world (docs/superpowers/specs/2026-09-28-tasks-in-3d-design.md §6).
#   markers   each open task gets a stake with a coloured ribbon and a label at its demonstration vine (the vine nearest
#             the headland on the Block's middle row) or above its Lot's tank in the hall
#   close-up  E opens a close view of the vine (or the tank top) with the task's options as clickable parts:
#             pruning   the vine as the pruner finds it, the options' cuts marked; the cut and the tie-down on confirm
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
const INTERNODE := 0.075             # m of cane per count bud in the pruning close-up (Guyot canes, Einzelpfahl bows; look only)

var vy: Node3D                       # vineyard.gd
var wy: Node3D                       # winery.gd
var markers := {}                    # task id -> {node, spot: [vine, stand, marker], task}
var markers_plot := ""               # the world the markers were built in
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
	# markers change only where they must (the time-lapse applies a snapshot every day): a new world clears them;
	# closed tasks lose theirs; a hall task whose Lot moved to another tank moves; tasks without a place retry
	var pk := String(vy.get("plot_key")) if vy else ""
	if pk != markers_plot:
		markers_plot = pk
		for id in markers:
			(markers[id]["node"] as Node3D).queue_free()
		markers.clear()
	var open_ids := {}
	for task in D.get("tasks", []):
		if String(task.get("status", "")) == "Open":
			open_ids[int(task["id"])] = task
	for id in markers.keys():
		if not open_ids.has(id):
			(markers[id]["node"] as Node3D).queue_free()
			markers.erase(id)
	for id in open_ids:
		var task: Dictionary = open_ids[id]
		if markers.has(id):
			markers[id]["task"] = task
			if String(task.get("where", "")) != "hall":
				continue
			var now := demo_spot(task)                   # cheap: a tank lookup
			if not now.is_empty() and (now[0] as Vector3).is_equal_approx(markers[id]["spot"][0]):
				continue
			(markers[id]["node"] as Node3D).queue_free()
			markers.erase(id)
			if now.is_empty():
				continue
			markers[id] = {"node": _marker(task, now), "spot": now, "task": task}
			continue
		var spot := demo_spot(task)
		if spot.is_empty():
			continue
		markers[id] = {"node": _marker(task, spot), "spot": spot, "task": task}


## Finds every Block's demonstration vine ahead of time, one Block per frame (a scan of the Block's vines took
## ~15 ms; four tasks opening on one day made a 66 ms frame in the time-lapse).
var warmed_plot := ""
var warm_label: Node3D
var glyphs_warm := false
var warm_frames := 0
var warm_blocks := []
func _warm_spots() -> void:
	if vy == null:
		return
	var pk := String(vy.get("plot_key"))
	if pk != warmed_plot:
		warmed_plot = pk
		warm_blocks = []
		for b in vy.get("blocks"):
			warm_blocks.append(String(b["id"]))
	if not warm_blocks.is_empty():
		demo_spot({"block": warm_blocks.pop_back(), "where": "vineyard", "id": -1})
	elif warm_label == null and not glyphs_warm:
		# a marker's first label cost one 65 ms frame (text set-up on first use, released when no label is left):
		# one marker lives permanently far below the ground
		warm_label = _marker({"kind": "LeafRemoval", "title": "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz", "block": "0123456789", "due": "·:,.-()éèàüöäß"}, [Vector3.ZERO, Vector3.ZERO, Vector3(0, -1000, 0)])   # far below any terrain
		warm_frames = 6
	elif warm_label != null and not glyphs_warm:
		warm_frames -= 1
		if warm_frames <= 0:
			glyphs_warm = true      # kept: once no marker label is left, the next one paid the 65 ms again


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
	_warm_spots()
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
	if kind == "Prune":
		# far enough back to see the vine whole, up to the tips of last summer's canes; vines in the line of sight are
		# hidden with the demonstration vine (game simplification)
		cam = v + W * 1.75 + U * 0.25 + Vector3(0, 1.2 * hs, 0)
		target = v + Vector3(0, 1.0 * hs, 0)
		var pts := [to_global(v)]
		for f in [0.3, 0.55, 0.8]:
			pts.append(to_global(v.lerp(cam, f)))
		hidden_vines = vy.call("hide_vines_near", String(task["block"]), pts, 0.5)
	return [to_global(cam), to_global(target)]


func close_closeup() -> void:
	if parts:
		parts.queue_free()
	parts = null
	if not hidden_vines.is_empty() and vy:
		vy.call("restore_vines", hidden_vines)
	hidden_vines = []
	prune = {}
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


# ------------------------------------------------------------------ pruning: the vine before the cut, and the cut
# The demonstration vine is shown as a pruner finds it in January (the real vine is hidden while the close-up is open):
# last summer's growth still on it. Guyot: last year's fruiting cane along the wire with its upright canes, and three new
# canes from the renewal spur at the head. Cordon: the permanent arms with one-year canes standing on every spur position.
# Einzelpfahl: last year's two bows round the stake with their canes, and three new canes from the head.
# Each option marks where it cuts (a ring at its bud count on the canes it keeps, and a tag); choosing one shows what stays
# (gold) and what goes (red). On confirm the old wood and the cut-off tips fall, and the kept canes are tied down: along the
# fruiting wire (Guyot; both ways for a double Guyot) or bent into bows round the stake (Einzelpfahl). Cordon keeps the
# option's number of spur positions, each cut to two buds. Bud numbers come from the snapshot (canopy-and-yield.md §3.1, §3.7).
const BUD0 := 0.05                    # m from a cane's base to its first bud
var prune := {}                       # the close-up's pruning state (canes, pieces, plans, materials)
var hidden_vines := []                # vineyard.gd hide_vines_near(): restored when the close-up closes


func _prune_parts(task: Dictionary, v: Vector3, U: Vector3, W: Vector3) -> void:
	var training := str(task.get("training", "Guyot"))
	var bark: StandardMaterial3D = (vy.call("_mat", "vine_bark") as StandardMaterial3D)
	var mats := {}
	for base in [["old", Color(0.55, 0.50, 0.47)], ["cane", Color(0.80, 0.55, 0.38)]]:
		var m0: StandardMaterial3D = bark.duplicate(); m0.albedo_color = base[1]
		var mk: StandardMaterial3D = m0.duplicate(); mk.emission_enabled = true; mk.emission = Color(1.0, 0.75, 0.25); mk.emission_energy_multiplier = 0.55
		var mc: StandardMaterial3D = m0.duplicate(); mc.albedo_color = Color(base[1]).lerp(Color(0.6, 0.12, 0.08), 0.55)
		mc.emission_enabled = true; mc.emission = Color(0.9, 0.12, 0.08); mc.emission_energy_multiplier = 0.25
		mats[base[0]] = {"": m0, "keep": mk, "cut": mc}
	var trunk_mat: StandardMaterial3D = bark.duplicate()
	prune = {"canes": {}, "pieces": [], "plans": {}, "mats": mats, "rings": [], "training": training, "U": U, "W": W, "v": v}
	var up := Vector3.UP
	var rng := RandomNumberGenerator.new(); rng.seed = int(task["id"]) * 13 + 5
	var opts: Array = task.get("options", [])
	var max_per := 2
	for o in opts:
		max_per = maxi(max_per, int(o.get("buds", 8)))
	match training:
		"Cordon":
			var hw := 0.95 * hs
			var head := v + up * (hw - 0.03)
			_trunk(v, head, trunk_mat)
			var npos := 2
			for o in opts:
				npos = maxi(npos, ceili(maxi(2, int(round(int(o.get("buds", 8)) / 2.0))) / 2.0) + 1)
			var reach := 0.6 * hs
			for sgn in [1.0, -1.0]:
				var dir: Vector3 = U * sgn
				var arm := [head, head + dir * 0.08 + up * 0.03, head + dir * reach + up * 0.03]
				_piece(_segment(arm[0], arm[1], 0.021, 0.019, mats["old"][""], parts), "", 0.0, "arm")
				_piece(_segment(arm[1], arm[2], 0.019, 0.014, mats["old"][""], parts), "", 0.0, "arm")
				for k in npos:
					var at: Vector3 = arm[1] + dir * ((reach - 0.08) * (float(k) + 0.5) / float(npos))
					var stub := at + up * 0.035
					_piece(_segment(at, stub, 0.011, 0.010, mats["old"][""], parts), "", 0.0, "stub")
					var pos_id := "%s%d" % ["R" if sgn > 0 else "L", k]
					for c in 2:                                   # two one-year canes on last year's spur
						var lean: float = (0.05 + 0.04 * c) * (1.0 if c == 0 else -1.0) * float(sgn)
						_cane("%s_%d" % [pos_id, c], stub, dir, 86.0 - 6.0 * c + rng.randf_range(-3, 3), rng.randf_range(0.8, 0.95), W * lean)
			# a plan per option: which spur positions it keeps on each arm (evenly spread), each cut to two buds
			for o in opts:
				var spurs := maxi(2, int(round(int(o.get("buds", 8)) / 2.0)))
				var keep := {}
				for side in [["R", ceili(spurs / 2.0)], ["L", floori(spurs / 2.0)]]:
					for j in int(side[1]):
						var k := int(round((float(j) + 0.5) * float(npos) / float(side[1]) - 0.5))
						keep["%s%d_0" % [side[0], clampi(k, 0, npos - 1)]] = 2
				prune["plans"][String(o["value"])] = {"keep": keep, "bend": {}}
		"Einzelpfahl":
			var head := v + up * (0.62 * hs) + W * 0.06
			var stake := CylinderMesh.new(); stake.top_radius = 0.026; stake.bottom_radius = 0.03; stake.height = 2.05 * hs; stake.radial_segments = 8
			_mesh(stake, vy.call("_mat", "vine_wood"), Transform3D(Basis(), v + up * (stake.height / 2.0 - 0.2 * hs)))
			_trunk(v + W * 0.06, head, trunk_mat)
			for sgn in [1.0, -1.0]:                               # last year's bows, with the canes that grew on them
				var dir: Vector3 = U * sgn
				var bow := _arc_points(head, dir, 0.62, 80.0, -290.0, 14)
				for i in bow.size() - 1:
					_piece(_segment(bow[i], bow[i + 1], 0.012, 0.010, mats["old"][""], parts), "", 0.0, "old", "bow%d" % int(sgn))
				for k in 5:
					var at: Vector3 = bow[2 + k * 2]
					_cane("old%s%d" % ["R" if sgn > 0 else "L", k], at, dir, 70.0 + rng.randf_range(-8, 8), rng.randf_range(0.75, 1.0), W * rng.randf_range(-0.12, 0.12), true)
			_cane("A", head + up * 0.02, U, 78.0, 1.1, W * 0.03)
			_cane("B", head + up * 0.03, -U, 80.0, 1.05, W * -0.03)
			_cane("C", head + up * 0.04, U, 88.0, 0.95, W * 0.08)
			for o in opts:
				var n := int(o.get("buds", 8))
				prune["plans"][String(o["value"])] = {"keep": {"A": ceili(n / 2.0), "B": floori(n / 2.0)}, "bend": {"A": "bow", "B": "bow"}}
		_:
			var hw := 0.80 * hs
			var head := v + up * (hw - 0.08 * hs)
			var post := CylinderMesh.new(); post.top_radius = 0.007; post.bottom_radius = 0.007; post.height = hw + 0.5; post.radial_segments = 6
			_mesh(post, vy.call("_mat", "vine_wood"), Transform3D(Basis(), v - U * 0.035 + W * 0.03 + up * (post.height / 2.0 - 0.2)))
			_trunk(v, head, trunk_mat)
			# last year's fruiting cane, tied along the wire, with the upright canes that grew from its buds (topped)
			var old := [head, head + U * 0.06 + up * 0.08, head + U * 0.17 + up * (hw - head.y + v.y), head + U * 0.84 + up * (hw - head.y + v.y)]
			for i in old.size() - 1:
				_piece(_segment(old[i], old[i + 1], 0.012 - 0.002 * i, 0.010 - 0.002 * i, mats["old"][""], parts), "", 0.0, "old")
			for k in 7:
				var at: Vector3 = (old[2] as Vector3).lerp(old[3], (float(k) + 0.4) / 7.0) + up * 0.008
				_cane("old%d" % k, at, U, 84.0 + rng.randf_range(-5, 5), 1.75 * hs - (hw + 0.01), W * rng.randf_range(-0.06, 0.06), true)
			# last year's renewal spur, and the new canes: A and B from its two buds, C from a base bud lower on the head
			var stub := head - U * 0.035 + up * 0.05
			_piece(_segment(head, stub, 0.013, 0.012, mats["old"][""], parts), "", 0.0, "stub")
			_cane("A", stub, U, 80.0, 1.2, W * 0.04)
			_cane("B", stub + up * 0.01, -U, 79.0, 1.1, W * -0.04)
			_cane("C", head - U * 0.02 - up * 0.03, -U, 66.0, 0.85, W * 0.09)
			for o in opts:
				var n := int(o.get("buds", 8))
				var plan := {"keep": {"C": 2}, "bend": {"A": "wire"}}
				if n > 12:                                        # double Guyot: a cane each way along the wire
					plan["keep"]["A"] = ceili(n / 2.0); plan["keep"]["B"] = floori(n / 2.0); plan["bend"]["B"] = "wire"
				else:
					plan["keep"]["A"] = n
				prune["plans"][String(o["value"])] = plan
	# where each option cuts (rings on the canes it keeps, at its bud count) and a tag per option
	var ring_cols := [Color(0.45, 0.75, 1.0), Color(0.55, 0.95, 0.5), Color(1.0, 0.7, 0.3)]
	for i in opts.size():
		var o: Dictionary = opts[i]
		var val := String(o["value"])
		var plan: Dictionary = prune["plans"][val]
		var col: Color = ring_cols[mini(i, 2)]
		var meshes := []
		if training != "Cordon":
			for cid in plan["bend"].keys():
				var c: Dictionary = prune["canes"][cid]
				var at := _cane_point(c, BUD0 + INTERNODE * float(plan["keep"][cid]) - INTERNODE * 0.35, 0.0)
				var ring := _mesh(_torus(0.016, 0.026), _mat(col, 0.8), Transform3D(_along(_cane_dir(c, 0.0)), at))
				meshes.append(ring)
				prune["rings"].append(ring)
				var lab := _label("%s · %d buds" % [val, int(plan["keep"][cid])] if cid == "A" else "%d" % int(plan["keep"][cid]),
					at + (c["dir"] as Vector3) * 0.13 + Vector3.UP * 0.01 * (i - 1), col.lightened(0.3), 22)
				prune["rings"].append(lab)
				_pickable(val, [ring], Vector3(0.07, 0.07, 0.07), at)
		var over: bool = o.get("warning") != null
		# the tags hang below the wire, in front of the trunk, where nothing of the vine is behind them
		var tag_at := v + W * 0.45 + U * 0.42 + Vector3(0, 0.66 * hs - 0.17 * i, 0)
		var board := BoxMesh.new(); board.size = Vector3(0.62, 0.14, 0.01)
		var bb := Basis(Vector3.UP, atan2(W.x, W.z))
		var bm := _mesh(board, _mat(Color(0.82, 0.76, 0.62) if not over else Color(0.9, 0.6, 0.45)), Transform3D(bb, tag_at))
		meshes.append(bm)
		_pickable(val, [bm], Vector3(0.64, 0.15, 0.05), tag_at, bb)
		var count := String(o.get("detail", "%d buds" % int(o.get("buds", 8))))
		var tl := _label("%s · %s%s" % [val, count, "  ⚠ over the AOC limit" if over else ""], tag_at + W * 0.012, Color(0.14, 0.09, 0.04), 17)
		tl.no_depth_test = false; tl.outline_size = 0; tl.billboard = BaseMaterial3D.BILLBOARD_DISABLED; tl.basis = bb
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tl.width = 270.0
		prune["rings"].append(tl)
		for m in meshes:
			extras.append({"mesh": m, "value": val, "role": "mark"})


## The trunk from the ground to the head: a slightly crooked, tapering stem.
func _trunk(foot: Vector3, head: Vector3, mat: Material) -> void:
	var pts := []
	for k in 6:
		var t := float(k) / 5.0
		var wob := Vector3(sin(t * 7.0 + foot.x) * 0.012, 0, cos(t * 5.0 + foot.z) * 0.012) * (1.0 - absf(t - 0.5) * 2.0)
		pts.append(foot.lerp(head, t) + wob + Vector3(0, -0.1 if k == 0 else 0.0, 0))
	for k in 5:
		_piece(_segment(pts[k], pts[k + 1], 0.034 - 0.002 * k, 0.032 - 0.002 * k, mat, parts), "", 0.0, "trunk")


## Points of an arc in the vertical plane of dir: starting at a0° above dir and turning by turn° over length L.
func _arc_points(base: Vector3, dir: Vector3, L: float, a0: float, turn: float, n: int) -> Array:
	var pts := [base]
	for i in n:
		var th := deg_to_rad(a0 + turn * (float(i) + 0.5) / float(n))
		pts.append(pts[-1] + (dir * cos(th) + Vector3.UP * sin(th)) * (L / float(n)))
	return pts


## A one-year cane: n straight segments from base, leaning th° above dir (and sideways by lat at its tip), with a bud every
## INTERNODE from BUD0. Old canes (last summer's growth on the wood that goes) are pieces with no cane id: they always go.
func _cane(id: String, base: Vector3, dir: Vector3, th: float, L: float, lat: Vector3, old := false) -> void:
	var n := maxi(6, int(ceil(L / 0.06)))
	var c := {"id": id, "base": base, "dir": dir, "lat": lat, "n": n, "L": L, "seg": L / float(n), "up": [], "segs": [], "buds": [], "k": 0.0, "shape": ""}
	for i in n:
		c["up"].append(th + 4.0 * sin(float(i) * 0.9 + base.x * 3.0) - 6.0 * float(i) / float(n))   # a gentle natural curve
	var mats: Dictionary = prune["mats"]["old" if old else "cane"]
	for i in n:
		var cm := CylinderMesh.new(); cm.top_radius = 0.0075 - 0.003 * float(i + 1) / float(n); cm.bottom_radius = 0.0075 - 0.003 * float(i) / float(n)
		cm.height = c["seg"]; cm.radial_segments = 6
		var mi := _mesh(cm, mats[""], Transform3D())
		c["segs"].append(mi)
		_piece(mi, "" if old else id, (float(i) + 0.5) * float(c["seg"]), "old" if old else "cane", id)
	var bud := SphereMesh.new(); bud.radius = 0.0085; bud.height = 0.016; bud.radial_segments = 6; bud.rings = 3
	var s := BUD0
	while s < L - 0.02:
		var bm := _mesh(bud, mats[""], Transform3D())
		c["buds"].append({"mesh": bm, "s": s})
		_piece(bm, "" if old else id, s, "old" if old else "cane", id)
		s += INTERNODE
	if not old:
		prune["canes"][id] = c
	_shape(c, 0.0, "")


## A point at arc length s along the cane, bent by k (0 upright .. 1 its target shape).
func _cane_point(c: Dictionary, s: float, k: float) -> Vector3:
	var p: Vector3 = c["base"]
	var seg: float = c["seg"]
	for i in int(c["n"]):
		var d := _seg_dir(c, i, k)
		if s <= seg * float(i + 1):
			return p + d * (s - seg * float(i))
		p += d * seg
	return p


func _cane_dir(c: Dictionary, s: float) -> Vector3:
	return _seg_dir(c, clampi(int(s / float(c["seg"])), 0, int(c["n"]) - 1), float(c["k"]))


func _seg_dir(c: Dictionary, i: int, k: float) -> Vector3:
	var th: float = c["up"][i]
	var lat: Vector3 = c["lat"]
	match String(c["shape"]):
		"wire":                        # a short rise to the wire, then along it
			th = lerpf(th, 28.0 if i < 2 else (-4.0 if i == 2 else 0.0), k)
			lat = lat * (1.0 - k)
		"bow":                         # over and down round the stake: the "heart"
			var t := (float(i) + 0.5) / float(c["n"])
			th = lerpf(th, 80.0 - 290.0 * t, k)
			lat = lat * (1.0 - k)
	var r := deg_to_rad(th)
	return ((c["dir"] as Vector3) * cos(r) + Vector3.UP * sin(r) + lat / maxf(float(c["L"]), 0.1)).normalized()


## Places the cane's segments and buds for bend k towards shape ("" upright, "wire", "bow").
func _shape(c: Dictionary, k: float, shape: String) -> void:
	if not is_instance_valid(parts):
		return
	c["k"] = k
	c["shape"] = shape
	var p: Vector3 = c["base"]
	var seg: float = c["seg"]
	for i in int(c["n"]):
		var d := _seg_dir(c, i, k)
		var mi = c["segs"][i]
		if is_instance_valid(mi) and mi.get_parent() == parts:
			mi.transform = Transform3D(_along(d), p + d * seg * 0.5)
		p += d * seg
	for b in c["buds"]:
		var bm = b["mesh"]
		if is_instance_valid(bm) and bm.get_parent() == parts:
			var s: float = b["s"]
			var at := _cane_point(c, s, k)
			var side := (c["dir"] as Vector3).cross(Vector3.UP).normalized() * (0.007 if int(s / INTERNODE) % 2 == 0 else -0.007)
			bm.position = at + side + Vector3.UP * 0.004


## A part of the vine: cane = the new cane it belongs to ("" otherwise), s = its arc position on that cane, role = trunk /
## arm / stub (permanent) · old (goes whatever the option) · cane (kept up to the option's cut); group = what falls together.
func _piece(mi: MeshInstance3D, cane: String, s: float, role: String, group := "") -> void:
	prune["pieces"].append({"mesh": mi, "cane": cane, "s": s, "role": role, "group": group if group != "" else cane})


## What the option does to a piece: "keep" (gold), "cut" (red) or "" (the permanent wood).
func _fate(pc: Dictionary, plan: Dictionary) -> String:
	match String(pc["role"]):
		"trunk", "arm", "stub":
			return ""
		"old":
			return "cut"
	var keep: Dictionary = plan["keep"]
	var cid := String(pc["cane"])
	if not keep.has(cid):
		return "cut"
	return "keep" if float(pc["s"]) <= BUD0 + INTERNODE * float(keep[cid]) - INTERNODE * 0.35 else "cut"


## Choosing an option shows what stays and what goes.
func _prune_preview(value: String) -> void:
	var plan: Dictionary = prune["plans"].get(value, {})
	for pc in prune["pieces"]:
		var mi = pc["mesh"]
		if not is_instance_valid(mi) or String(pc["role"]) in ["trunk", "arm", "stub"]:
			continue
		var base := "old" if String(pc["role"]) == "old" else "cane"
		mi.material_override = prune["mats"][base][_fate(pc, plan) if not plan.is_empty() else ""]


## The cut: the old wood and every cut-off part fall (each cane's part as one piece), the kept canes are tied down.
func _prune_confirm(value: String) -> void:
	var plan: Dictionary = prune["plans"].get(value, {})
	if plan.is_empty():
		return
	for r in prune["rings"]:
		if is_instance_valid(r): (r as Node3D).visible = false
	for e in extras:                                   # the tags too: the cut speaks for itself
		if String(e["role"]) == "mark" and is_instance_valid(e["mesh"]): (e["mesh"] as Node3D).visible = false
	var groups := {}
	for pc in prune["pieces"]:
		var mi = pc["mesh"]
		if not is_instance_valid(mi) or _fate(pc, plan) != "cut":
			continue
		var key := String(pc["group"]) if String(pc["group"]) != "" else "oldwood"
		if not groups.has(key):
			var holder := Node3D.new(); holder.position = mi.position
			parts.add_child(holder)
			groups[key] = holder
		mi.reparent(groups[key], true)
	var tw := parts.create_tween().set_parallel(true)         # tweens die with the close-up when it closes
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	for key in groups:
		var h: Node3D = groups[key]
		var g: float = vy.call("ground_height", h.position.x, h.position.z)
		tw.tween_property(h, "position:y", g + 0.04, 0.55 + rng.randf() * 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(h, "rotation", Vector3(rng.randf_range(0.8, 1.5), rng.randf_range(-0.6, 0.6), rng.randf_range(-0.4, 0.4)), 0.7)
	# once down, the prunings lie in the alley in their own colour
	tw.chain().tween_callback(func():
		for pc in prune.get("pieces", []):
			var m = pc["mesh"]
			if is_instance_valid(m) and m.get_parent() != parts and String(pc["role"]) in ["old", "cane"]:
				m.material_override = prune["mats"]["old" if String(pc["role"]) == "old" else "cane"][""])
	for cid in plan["bend"]:
		var c: Dictionary = prune["canes"][cid]
		var shape := String(plan["bend"][cid])
		var bend := parts.create_tween()
		bend.tween_interval(0.2)
		bend.tween_method(func(k): _shape(c, k, shape), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)


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
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 12.0, PICK_LAYER)
	q.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not (hit["collider"] as Object).has_meta("option"):
		return ""
	return String((hit["collider"] as Object).get_meta("option"))


## Leaf removal: a click toggles a side; returns the resulting option value.
func toggle_side(value: String) -> String:
	if value == "Morning": selected["morning"] = not selected["morning"]
	elif value == "Afternoon": selected["afternoon"] = not selected["afternoon"]
	elif value == "Both": selected = {"morning": true, "afternoon": true}
	elif value == "None": selected = {"morning": false, "afternoon": false}
	var m: bool = selected["morning"]
	var a: bool = selected["afternoon"]
	return "Both" if m and a else "Morning" if m else "Afternoon" if a else "None"


## Tints what the option acts on (what the cut keeps and removes, the leaves to pull, the bunches to drop, the tool).
func highlight(value: String) -> void:
	var kind := String(active.get("kind", ""))
	if kind == "Prune":
		_prune_preview(value)
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
	if kind == "Prune":
		_prune_confirm(value)
		return
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
		if falls:
			var ground: float = vy.call("ground_height", mi.position.x, mi.position.z) if kind != "CapManagement" else mi.position.y - 0.5
			if tw == null: tw = create_tween().set_parallel(true)
			tw.tween_property(mi, "position:y", ground + 0.03, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(mi, "rotation", mi.rotation + Vector3(1.2, 0.4, 0.8), 0.6)
