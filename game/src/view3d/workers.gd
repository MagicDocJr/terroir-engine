# People and machines at work on the Estate, shown from the snapshot only (spec §8.2 "processes you can watch").
# Nothing here decides what happens; it stages what the simulation reports:
#   picking Block (`picking`, `pickedPct`, `harvestMethod`, labour Programme) → a picking crew at the picking front
#     (bunches already gone behind it, see vineyard.gd pick_plane), bucket carriers, bins and a tractor with a trailer
#     of bins on the headland; machine harvest → a harvester on the front row and the trailer
#   sorting Table/Rigorous while picking → a sorting table with 2–4 people under the winery's lean-to
#   `daysSinceSpray` ≤ 1 (a pass on the last simulated day) → the sprayer on its pass (tractor + air-blast sprayer, straddle tractor in narrow Côte d'Or
#     rows, a person with a backpack sprayer on steep Mosel slopes and on stake-trained vines)
#   staff tasks (snapshot `tasks` with `crewActive`): after a pruning, leaf-removal or green-harvest task is decided, a
#     crew works that Block until `crewUntil` (pruners for pruning, the canopy crew for leaf removal and thinning)
#   season (Game simplification): May–Jul a canopy crew in one Block for the Canopy Programme's routine work
#     (shoot positioning, hedging), shown only when no task crew is out
# All people are one MultiMesh (shaders/worker.gdshader poses them); animation runs only while the view is shown.
extends Node3D

const A := preload("res://src/view3d/assets3d.gd")
const SH := "res://src/view3d/shaders/"
const MAX_PEOPLE := 32
const CREW := {"Low": 6, "Medium": 9, "High": 12}

var vy: Node3D                      # vineyard.gd (terrain, Blocks, row frames)
var wy: Node3D                      # winery.gd (building frame, lean-to, tractor materials)
var mmi: MultiMeshInstance3D
var mm: MultiMesh
var people: Array = []              # per person: {mode, ...} (see _pose)
var machines: Array = []            # moving machines: {node, path: [a, b], w, alleys, speed, ...}
var nodes := {}                     # template nodes from workers.glb / tractors.glb
var shown: Array[Node3D] = []       # instances placed for the current snapshot
var t := 0.0
var active := false
var summary := ""                   # for the HUD / test log
var focus := Vector3.INF            # where the camera preset "crew" looks
var focus_from := Vector3.INF
var region := ""


func setup(vineyard: Node3D, winery: Node3D) -> void:
	vy = vineyard
	wy = winery
	if not A.exists("models/workers.glb"):
		push_warning("view3d: workers.glb missing (game/tools/sync_assets3d.sh winery)")
		return
	var root := A.scene("models/workers.glb")
	for mi in A.meshes(root):
		nodes[String(mi.name)] = (mi as MeshInstance3D).mesh
	root.free()
	var tr := A.scene("models/tractors.glb")
	for mi in A.meshes(tr):
		nodes[String(mi.name)] = (mi as MeshInstance3D).mesh
	tr.free()
	for k in nodes:
		if k == "person":
			continue
		var mesh: Mesh = nodes[k]
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			mesh.surface_set_material(i, wy.call("_mat", String(m.resource_name) if m else ""))
	# people: one MultiMesh, one ShaderMaterial per surface (skin, shirt, trousers, hat, gear)
	var pm: Mesh = nodes.get("person", BoxMesh.new())
	var shader: Shader = load(SH + "worker.gdshader")
	var kinds := {"w_skin": 0, "w_shirt": 1, "w_trousers": 2, "w_hat": 3, "w_gear": 4}
	for i in pm.get_surface_count():
		var m := pm.surface_get_material(i)
		var sm := ShaderMaterial.new()
		sm.shader = shader
		sm.set_shader_parameter("kind", kinds.get(String(m.resource_name) if m else "", 1))
		pm.surface_set_material(i, sm)
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = pm
	mm.instance_count = MAX_PEOPLE
	mm.visible_instance_count = 0
	mmi = MultiMeshInstance3D.new()
	mmi.name = "People"
	mmi.multimesh = mm
	# instances move every frame and are spread over the Estate: a big culling box and no visibility range (which
	# would be measured from the box centre); there are never more than MAX_PEOPLE
	mmi.custom_aabb = AABB(Vector3(-3000, -3000, -3000), Vector3(6000, 6000, 6000))
	add_child(mmi)


func set_active(on: bool) -> void:
	active = on
	set_process(on)


# ------------------------------------------------------------------ plan from the snapshot
func apply(D: Dictionary) -> void:
	if mm == null:
		return
	for n in shown:
		n.queue_free()
	shown.clear()
	people.clear()
	machines.clear()
	focus = Vector3.INF
	focus_from = Vector3.INF
	region = String(D.get("region", {}).get("id", "mosel"))
	var labour := "Medium"
	for p in D.get("programmes", []):
		if String(p.get("id", "")) == "labour":
			labour = String(p.get("current", "Medium"))
	var blocks: Array = vy.get("blocks")
	var parts := []
	var tractor_out := false
	var sorting := ""
	# harvest
	for sb in D.get("blocks", []):
		if not sb.get("picking", false) or sb.get("harvested", false):
			continue
		var bi := _block_index(blocks, String(sb.get("id", "")))
		if bi < 0:
			continue
		var machine := String(sb.get("harvestMethod", "hand")) == "machine"
		_harvest(blocks[bi], clampf(float(sb.get("pickedPct", 0.0)) / 100.0, 0.0, 1.0), machine, int(CREW.get(labour, 9)))
		tractor_out = true
		parts.append("Block %s: %s %d %%" % [sb["id"], "harvester" if machine else "picking crew", int(sb.get("pickedPct", 0))])
		var so := String(sb.get("sorting", ""))
		if not machine and so in ["Table", "Rigorous"]:
			sorting = "Rigorous" if so == "Rigorous" or sorting == "Rigorous" else "Table"
	if sorting != "":
		_sorting_table(4 if sorting == "Rigorous" else 2)
		parts.append("sorting table (%s)" % sorting.to_lower())
	# spray pass today
	for sb in D.get("blocks", []):
		var ds = sb.get("daysSinceSpray")
		if ds == null or int(ds) > 1 or sb.get("picking", false):      # the pass on the last simulated day (the snapshot date is the next morning)
			continue
		var bi := _block_index(blocks, String(sb.get("id", "")))
		if bi < 0:
			continue
		var by_hand: bool = not blocks[bi]["vsp"] or (region == "mosel" and float(vy.get("sv")) >= 0.3)
		_spray(blocks[bi], by_hand)
		tractor_out = tractor_out or not by_hand
		parts.append("Block %s: spraying%s" % [sb["id"], " (backpack)" if by_hand else ""])
		break
	# task crews: the crew finishing a staff task the player decided (or left to the plan)
	var task_crews := 0
	for task in D.get("tasks", []):
		if not task.get("crewActive", false) or people.size() >= MAX_PEOPLE - 3 or String(task.get("where", "")) != "vineyard":
			continue
		var bi := _block_index(blocks, String(task.get("block", "")))
		if bi < 0:
			continue
		var kind := String(task.get("kind", ""))
		_seasonal(blocks[bi], "prune" if kind == "Prune" else "canopy", 3)
		task_crews += 1
		parts.append("Block %s: %s crew until %s" % [task["block"], {"Prune": "pruning", "LeafRemoval": "leaf-removal", "GreenHarvest": "green-harvest"}.get(kind, "vineyard"), task.get("crewUntil", "")])
	# routine canopy work (game simplification), only when no task crew is out
	var date := String(D.get("date", "2000-06-01"))
	var month := int(date.substr(5, 2))
	var doy := int(vy.call("_doy", date))
	if task_crews == 0 and people.size() < 4 and not blocks.is_empty() and month >= 5 and month <= 7:
		var bi := (doy / 9) % blocks.size()
		var st := String(_snap_block(D, String(blocks[bi]["id"])).get("stage", ""))
		if not st in ["Harvested", "Picking"]:
			_seasonal(blocks[bi], "canopy", 3)
			parts.append("Block %s: canopy work" % blocks[bi]["id"])
	wy.call("set_parked_tractor", not tractor_out)
	mm.visible_instance_count = mini(people.size(), MAX_PEOPLE)
	summary = ", ".join(parts)
	_animate(0.0)


static func _block_index(blocks: Array, id: String) -> int:
	for i in blocks.size():
		if String(blocks[i]["id"]) == id:
			return i
	return -1


static func _snap_block(D: Dictionary, id: String) -> Dictionary:
	for b in D.get("blocks", []):
		if String(b.get("id", "")) == id:
			return b
	return {}


# ------------------------------------------------------------------ staging
func _P(fr: Dictionary, u: float, w: float) -> Vector3:
	var p: Vector2 = fr["U"] * u + fr["W"] * w
	return Vector3(p.x, vy.call("ground_height", p.x, p.y), p.y)


func _place(mesh_name: String, pos: Vector3, fwd: Vector2, align := true) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = nodes.get(mesh_name, BoxMesh.new())
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.visibility_range_end = 400.0
	_orient(mi, pos, fwd, align)
	add_child(mi)
	shown.append(mi)
	return mi


## Model +x along fwd (xz), up along the ground normal (align) or straight up.
func _orient(n: Node3D, pos: Vector3, fwd: Vector2, align := true) -> void:
	var up: Vector3 = vy.call("ground_normal", pos.x, pos.z) if align else Vector3.UP
	var x := Vector3(fwd.x, 0, fwd.y).normalized()
	var z := x.cross(up).normalized()
	x = up.cross(z).normalized()
	n.transform = Transform3D(Basis(x, up, z), pos)


## The end of the picking front's alley nearest to the winery door: returns [u_end, sign (+1 = u_max end)].
func _row_end(fr: Dictionary, span: Vector2, w: float) -> Array:
	var est: Dictionary = vy.get("estate")
	var door: Vector2 = est.get("door", Vector2.ZERO)
	var a: Vector2 = fr["U"] * span.x + fr["W"] * w
	var b: Vector2 = fr["U"] * span.y + fr["W"] * w
	return [span.y, 1.0] if b.distance_to(door) < a.distance_to(door) else [span.x, -1.0]


func _alleys(fr: Dictionary) -> Array:
	var out := []
	var sp: float = fr["row"]
	var k := ceilf(float(fr["wmin"]) / sp)
	while (k + 0.5) * sp < float(fr["wmax"]):
		var w := (k + 0.5) * sp
		var span: Vector2 = vy.call("row_span", fr, w)
		if span.y - span.x > 4.0:
			out.append([w, span])
		k += 1.0
	return out


func _harvest(blk: Dictionary, p: float, machine: bool, crew: int) -> void:
	var fr: Dictionary = vy.call("block_frame", blk)
	var alleys := _alleys(fr)
	if alleys.is_empty():
		return
	var w_front: float = lerpf(fr["wmin"], fr["wmax"], p)
	var ai := 0
	for i in alleys.size():
		if absf(alleys[i][0] - w_front) < absf(alleys[ai][0] - w_front):
			ai = i
	var span: Vector2 = alleys[ai][1]
	var re := _row_end(fr, span, alleys[ai][0])
	var u_end: float = re[0]
	var sgn: float = re[1]
	# trailer of bins on the headland beyond the row end, hitched to the Region's tractor
	var head := _P(fr, u_end + sgn * 3.4, alleys[ai][0])
	var along: Vector2 = fr["W"]
	var tractor := String(wy.get("Y").get("tractors", {}).get(region, "tractor_standard"))
	_place("trailer", head, along)
	_place(tractor, _P(fr, u_end + sgn * 3.4, alleys[ai][0] + 3.9), along)
	for j in 2:
		_place("bin", _P(fr, u_end + sgn * 1.5, alleys[ai][0] + (j - 0.5) * 1.3), fr["U"])
	focus = _P(fr, (span.x + span.y) * 0.5, alleys[ai][0]) + Vector3(0, 0.9, 0)
	if machine:
		# harvester straddling the front row, going up and down it; one hand at the trailer
		# straddle the vine row next to the front alley (fall back to the alley if that row leaves the Block)
		var w_row: float = alleys[ai][0] + float(fr["row"]) * 0.5
		var rs: Vector2 = vy.call("row_span", fr, w_row)
		if rs.y - rs.x < 4.0:
			w_row = alleys[ai][0] - float(fr["row"]) * 0.5
			rs = vy.call("row_span", fr, w_row)
		if rs.y - rs.x < 4.0:
			w_row = alleys[ai][0]
			rs = span
		var hv := _place("tractor_straddle", _P(fr, rs.x, w_row), fr["U"])
		machines.append({"node": hv, "fr": fr, "w": w_row, "span": rs, "speed": 1.1, "straddle": true})
		people.append({"mode": "stand", "pos": head + Vector3(0, 0, 0) + Vector3(fr["W"].x, 0, fr["W"].y) * -1.8, "face": -sgn * Vector2(fr["U"])})
		focus = _P(fr, (span.x + span.y) * 0.5, w_row) + Vector3(0, 1.0, 0)
		focus_from = _P(fr, (span.x + span.y) * 0.5 + sgn * 4.0, w_row - float(fr["row"]) * 5.0) + Vector3(0, 7.0, 0)
		return
	# a crew works together: two pickers per alley (one on each row) across the alleys at the front, within a few
	# metres of each other along the rows; one in four carries buckets to the bins at the row end
	var used := []
	for d in [0, 1, -1, 2, -2, 3]:
		if ai + d >= 0 and ai + d < alleys.size():
			used.append(ai + d)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(blk["id"]))
	var sp0: Vector2 = alleys[ai][1]
	var u_c: float = lerpf(sp0.x, sp0.y, 0.45)
	var centroid := Vector3.ZERO
	var pickers := 0
	for i in crew:
		var al: Array = alleys[used[(i / 2) % used.size()]]
		var sp: Vector2 = al[1]
		var u0 := clampf(u_c + rng.randf_range(-3.5, 3.5), sp.x + 0.6, sp.y - 0.6)
		var mode := "carry" if i % 4 == 3 else "pick"
		people.append({"mode": mode, "fr": fr, "w": al[0] + rng.randf_range(-0.1, 0.1), "u0": u0, "span": sp, "u_end": u_end - sgn * 0.3,
			"side": 1.0 if i % 2 == 0 else -1.0, "off": rng.randf() * 8.0, "dir": -sgn})
		if mode == "pick":
			centroid += _P(fr, u0, al[0])
			pickers += 1
	centroid /= float(maxi(pickers, 1))
	focus = centroid + Vector3(0, 0.6, 0)
	focus_from = _alley_view(fr, alleys[ai][0], u_c, sgn)


func _sorting_table(n: int) -> void:
	var st: Dictionary = wy.get("Y").get("sortingTable", {})
	if st.is_empty():
		return
	var p: Array = st["pos"]
	var c := Vector3(p[0], p[1], p[2])
	var mi := MeshInstance3D.new()
	mi.mesh = nodes.get("sorting_table", BoxMesh.new())
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mi)
	mi.global_transform = wy.global_transform * Transform3D(Basis(Vector3.UP, float(st["yaw"])), c)
	shown.append(mi)
	var spots := [Vector3(-0.6, 0, -0.75), Vector3(0.5, 0, -0.75), Vector3(-0.1, 0, 0.75), Vector3(0.9, 0, 0.75)]
	for i in n:
		var local: Vector3 = c + spots[i]
		var face := Vector2(0, 1) if spots[i].z < 0 else Vector2(0, -1)
		var gp: Vector3 = wy.to_global(local)
		var gf: Vector3 = wy.global_transform.basis * Vector3(face.x, 0, face.y)
		people.append({"mode": "sort", "pos": gp, "face": Vector2(gf.x, gf.z), "off": i * 1.7})


func _spray(blk: Dictionary, by_hand: bool) -> void:
	var fr: Dictionary = vy.call("block_frame", blk)
	var alleys := _alleys(fr)
	if alleys.is_empty():
		return
	var ai := alleys.size() / 3
	var al: Array = alleys[ai]
	if by_hand:
		people.append({"mode": "spray", "fr": fr, "w": al[0], "span": al[1], "off": 0.0})
		focus = _P(fr, (al[1].x + al[1].y) * 0.5, al[0]) + Vector3(0, 1.0, 0)
		focus_from = _P(fr, al[1].x - 2.0, al[0] + float(fr["row"]) * 1.5) + Vector3(0, 2.2, 0)
		return
	var straddle := region == "cote-dor" or float(fr["row"]) < 1.6
	var name := "tractor_straddle" if straddle else String(wy.get("Y").get("tractors", {}).get(region, "tractor_standard"))
	var w: float = al[0] - (float(fr["row"]) * 0.5 if straddle else 0.0)             # straddle tractors run over a row
	var span: Vector2 = vy.call("row_span", fr, w)
	var tr := _place(name, _P(fr, span.x, w), fr["U"])
	var sp: Node3D = null if straddle else _place("sprayer", _P(fr, span.x, w), fr["U"])
	machines.append({"node": tr, "trailer": sp, "fr": fr, "w": w, "span": span, "speed": 1.6, "straddle": straddle})
	focus = _P(fr, (span.x + span.y) * 0.5, w) + Vector3(0, 1.2, 0)
	focus_from = _P(fr, span.x - 6.0, w + float(fr["row"]) * 2.5) + Vector3(0, 3.0, 0)


func _seasonal(blk: Dictionary, mode: String, n: int) -> void:
	var fr: Dictionary = vy.call("block_frame", blk)
	var alleys := _alleys(fr)
	if alleys.is_empty():
		return
	var ai := alleys.size() / 2
	var centroid := Vector3.ZERO
	for i in n:
		var al: Array = alleys[clampi(ai + i - 1, 0, alleys.size() - 1)]
		var sp: Vector2 = al[1]
		var u0: float = lerpf(sp.x, sp.y, 0.35 + 0.1 * i)
		people.append({"mode": mode, "fr": fr, "w": al[0], "u0": u0, "span": sp, "side": 1.0 if i % 2 else -1.0, "off": i * 2.3, "dir": 1.0})
		centroid += _P(fr, u0, al[0])
	centroid /= float(n)
	focus = centroid + Vector3(0, 0.7, 0)
	focus_from = _overlook(fr, centroid, 1.0)


# ------------------------------------------------------------------ animation
func _process(delta: float) -> void:
	if active:
		_animate(delta)


static func _pingpong(x: float, len: float) -> Vector2:
	var m := fposmod(x, 2.0 * len)
	return Vector2(m, 1.0) if m < len else Vector2(2.0 * len - m, -1.0)


func _animate(delta: float) -> void:
	t += delta
	for i in mini(people.size(), MAX_PEOPLE):
		var r: Array = _pose(people[i])
		mm.set_instance_transform(i, r[0])
		mm.set_instance_custom_data(i, r[1])
	for m in machines:
		var sp: Vector2 = m["span"]
		var len := maxf(sp.y - sp.x - 1.0, 1.0)
		var pp := _pingpong(t * float(m["speed"]), len)
		var fr: Dictionary = m["fr"]
		var u := sp.x + 0.5 + pp.x
		var fwd: Vector2 = fr["U"] * pp.y
		var pos := _P(fr, u, m["w"])
		if m.get("trailer") != null:
			_orient(m["trailer"], pos, fwd)
			pos = _P(fr, u + pp.y * 2.6, m["w"])
		_orient(m["node"], pos, fwd)


## -> [Transform3D, Color(bend, walk phase, walk amount, item)]
func _pose(p: Dictionary) -> Array:
	var mode: String = p["mode"]
	var bend := 0.0
	var phase := 0.0
	var amp := 0.0
	var item := 0.0
	var pos: Vector3
	var face: Vector2
	match mode:
		"stand", "sort":
			pos = p["pos"]
			face = p["face"]
			if mode == "sort":
				bend = 0.28 + 0.06 * sin(t * 1.7 + float(p["off"]))
		"spray":
			var fr: Dictionary = p["fr"]
			var sp: Vector2 = p["span"]
			var pp := _pingpong(t * 0.55, maxf(sp.y - sp.x - 1.0, 1.0))
			pos = _P(fr, sp.x + 0.5 + pp.x, p["w"])
			face = fr["U"] * pp.y
			phase = t * 0.55 / 1.3
			amp = 0.7
			item = 3.0
		"carry":
			var fr: Dictionary = p["fr"]
			var u0: float = p["u0"]
			var ue: float = p["u_end"]
			var dist := absf(ue - u0)
			var cyc := dist / 0.9 * 2.0 + 4.0
			var k := fposmod(t + float(p["off"]), cyc)
			var u: float
			var dirv := signf(ue - u0)
			if k < dist / 0.9:
				u = u0 + dirv * k * 0.9
				face = fr["U"] * dirv
				amp = 1.0
			elif k < dist / 0.9 + 3.0:
				u = ue
				face = fr["U"] * dirv
				bend = 0.35 * sin(clampf((k - dist / 0.9) / 3.0, 0.0, 1.0) * PI)          # tip the bucket into the bin
			else:
				u = ue - dirv * minf(k - dist / 0.9 - 3.0, dist / 0.9) * 0.9
				face = -fr["U"] * dirv
				amp = 1.0 if u != u0 else 0.0
			phase = k * 0.9 / 1.3
			item = 2.0
			pos = _P(fr, u, p["w"])
		_:   # pick / prune / canopy: work at the vines, a step along the row now and then
			var fr: Dictionary = p["fr"]
			var sp: Vector2 = p["span"]
			var cyc: float = {"pick": 8.0, "prune": 7.0, "canopy": 6.0}[mode]
			var step: float = {"pick": 0.7, "prune": 1.0, "canopy": 1.4}[mode]
			var work: float = {"pick": 0.85, "prune": 0.3, "canopy": 0.12}[mode]
			var k := t + float(p["off"])
			var n := floorf(k / cyc)
			var f := fposmod(k, cyc)
			var walking := f > cyc - 1.0
			var adv := n * step + (clampf(f - (cyc - 1.0), 0.0, 1.0) * step if walking else 0.0)
			var len := maxf(sp.y - sp.x - 1.0, 1.0)
			var pp := _pingpong(float(p["u0"]) - sp.x - 0.5 + float(p["dir"]) * adv, len)
			pos = _P(fr, sp.x + 0.5 + pp.x, p["w"])
			if walking:
				face = fr["U"] * pp.y * float(p["dir"])
				amp = 1.0
				phase = f
				item = 2.0 if mode == "pick" else 0.0
			else:
				face = fr["W"] * float(p["side"])
				var ramp := smoothstep(0.0, 0.8, f) * (1.0 - smoothstep(cyc - 1.8, cyc - 1.0, f))
				bend = work * ramp + 0.04 * sin(k * 2.3)
				item = 1.0 if mode == "pick" else 0.0
	# model faces -Z: rotate so that -Z points along face
	var yaw := atan2(-face.x, -face.y)
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	return [xf, Color(bend, fposmod(phase, 1.0), amp, item)]


## Standing in the crew's alley a few metres towards the row end, eye a little raised, looking at them.
func _alley_view(fr: Dictionary, w: float, u: float, sgn: float) -> Vector3:
	var back := 5.5 if float(fr["row"]) > 1.5 else 9.0          # dense stake-trained vines: stand further back
	var p := _P(fr, u + sgn * back, w - float(fr["row"]) * 1.5)
	var c := _P(fr, u, w)
	p.y = maxf(p.y, c.y) + (4.8 if back < 6.0 else 4.0)
	return p


## A raised view onto the crew from the picked side of the Block (over the canopy, like standing on a bank).
func _overlook(fr: Dictionary, c: Vector3, sgn: float) -> Vector3:
	var u := Vector3(fr["U"].x, 0, fr["U"].y)
	var w := Vector3(fr["W"].x, 0, fr["W"].y)
	var p := c - u * sgn * 7.0 - w * 6.0
	p.y = maxf(float(vy.call("ground_height", p.x, p.z)), c.y) + 4.2
	return p


## [camera position, target] for the camera preset "crew" (or empty when nobody is working).
func crew_view() -> Array:
	if focus == Vector3.INF:
		return []
	if not machines.is_empty() and people.size() <= 1:
		# a machine at work: look at where it is now, from beside its row
		var m: Dictionary = machines[0]
		var fr: Dictionary = m["fr"]
		var at: Vector3 = (m["node"] as Node3D).global_position + Vector3(0, 1.2, 0)
		var side := Vector3(fr["W"].x, 0, fr["W"].y) * float(fr["row"]) * 3.5
		var along := Vector3(fr["U"].x, 0, fr["U"].y) * 7.0
		var from := at - side - along
		from.y = maxf(float(vy.call("ground_height", from.x, from.z)), at.y) + 4.5
		return [from, at]
	return [focus_from, focus]
