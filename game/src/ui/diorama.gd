# Plot diorama for the Plot comparison screen: a cut-away tabletop model of the land, like a board-game tile.
# The real slope and aspect, each Block coloured and lettered with its vine rows, the river (Mosel), frost-pocket mist,
# a north arrow and the sun from the south, and a soil cut-away on the edges (horizon depths exaggerated ×6).
# Built procedurally from the setup catalog, so it needs no 3D assets. It spins slowly; drag to turn, scroll to zoom.
extends Control

const UI := preload("res://src/ui/ui.gd")
const SOIL_EXAG := 8.0

var plot: Dictionary = {}
var viewport: SubViewport
var world_root: Node3D
var pivot: Node3D
var cam: Camera3D
var yaw := 0.6
var pitch := -0.42
var dist := 16.0
var auto_spin := true
var dragging := false
var scale_k := 0.1
var half := Vector2(50, 50)     # half extents in metres (x across the slope, z downhill)
var slope := 0.1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var c := SubViewportContainer.new()
	c.stretch = true
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	c.add_child(viewport)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("1a2127")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9fb1c0")
	e.ambient_light_energy = 0.3
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	viewport.add_child(env)
	pivot = Node3D.new(); viewport.add_child(pivot)
	cam = Camera3D.new(); cam.fov = 38.0; pivot.add_child(cam)
	if not plot.is_empty(): _build()

func set_plot(p: Dictionary) -> void:
	plot = p
	if viewport != null: _build()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or pivot == null: return
	if auto_spin and not dragging: yaw += delta * 0.18
	pivot.rotation = Vector3(pitch, yaw, 0)
	cam.position = Vector3(0, 0, dist)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			dragging = ev.pressed
			if ev.pressed: auto_spin = false
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed: dist = maxf(7.0, dist * 0.9)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed: dist = minf(30.0, dist * 1.1)
		accept_event()
	elif ev is InputEventMouseMotion and dragging:
		yaw -= ev.relative.x * 0.008
		pitch = clampf(pitch - ev.relative.y * 0.006, -1.35, -0.12)
		accept_event()

# ----------------------------------------------------------------------------------------------- terrain helpers
func _noise(x: float, z: float) -> float:
	return sin(x * 0.11 + z * 0.05) * 0.6 + sin(x * 0.047 - z * 0.13) * 0.8 + sin(x * 0.23 + z * 0.19) * 0.25

func _h(x: float, z: float) -> float:
	# downhill is +z; gentle undulation everywhere, the margin lifts a little at the back like a hillside
	return -slope * z + _noise(x, z) * (0.5 + slope * 2.0)

func _blocks() -> Array:
	return plot.get("blocks", [])

## Block strips across the slope: [{b, x0, x1}] in metres.
func _layout() -> Array:
	var bl := _blocks()
	var total := 0.0
	for b in bl: total += float(b["area"]) * 10000.0
	var depth := clampf(sqrt(total) * 0.8, 50.0, 120.0)
	var gap := 3.0
	var width := total / depth + gap * (bl.size() - 1)
	var out := []
	var x := -width / 2.0
	for b in bl:
		var w := float(b["area"]) * 10000.0 / depth
		out.append({"b": b, "x0": x, "x1": x + w})
		x += w + gap
	half = Vector2(width / 2.0, depth / 2.0)
	return out

func _strip_at(strips: Array, x: float, z: float) -> Variant:
	if absf(z) > half.y: return null
	for s in strips:
		if x >= s["x0"] and x <= s["x1"]: return s
	return null

func _region() -> String: return String(plot.get("region", "mosel"))

func _margin_colour() -> Color:
	match _region():
		"napa": return Color("8f7a45")       # dry golden grass
		"cote-dor": return Color("56703a")
	return Color("3f5a30")                    # Mosel: forest and neighbouring vines

func _soil_colour(b: Dictionary) -> Color:
	var tex := String(b.get("texture", "loam")).to_lower()
	if "slate" in tex: return Color("5d5a55")
	if "sand" in tex: return Color("b69a6a")
	if "clay" in tex: return Color("8a5a3c")
	if "gravel" in tex: return Color("8f7f68")
	if "volcanic" in tex: return Color("6e4b42")
	if float(b.get("lime", 0)) > 5: return Color("b8a47f")
	return Color("7c5b3e")

func _bedrock_colour() -> Color:
	match _region():
		"mosel": return Color("454b54")           # blue Devonian slate
		"cote-dor": return Color("cfc3a2")        # Jurassic limestone
	return Color("6b4e46") if String(plot.get("id", "")) == "napa-mountain" else Color("8a7b69")   # volcanic / alluvial fan

# ----------------------------------------------------------------------------------------------- build
func _build() -> void:
	if world_root: world_root.queue_free()
	world_root = Node3D.new(); viewport.add_child(world_root)
	slope = float(plot.get("slope", 10)) / 100.0
	var strips := _layout()
	var m := maxf(half.x, half.y) * 0.22           # neighbour margin
	var ext := Vector2(half.x + m, half.y + m)
	scale_k = 10.0 / (2.0 * maxf(ext.x, ext.y))
	var tile := Node3D.new()
	# rotate so that downhill (+z in the tile) faces the Plot's aspect: world north is −z, east +x
	var a := deg_to_rad(float(plot.get("aspectDeg", 180)))
	tile.rotation.y = PI - a
	tile.scale = Vector3.ONE * scale_k
	world_root.add_child(tile)
	var mid_h := _h(0, 0)
	tile.position.y = -mid_h * scale_k
	_terrain(tile, strips, ext)
	_skirt(tile, strips, ext)
	_vines(tile, strips)
	_labels(tile, strips)
	_water(tile, ext)
	_mist(tile, strips)
	_compass_and_sun(ext)
	dist = 15.0

func _terrain(tile: Node3D, strips: Array, ext: Vector2) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 80
	var mc := _margin_colour()
	for iz in n:
		for ix in n:
			var quad := []
			for c in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var x: float = -ext.x + 2.0 * ext.x * (ix + int(c[0])) / n
				var z: float = -ext.y + 2.0 * ext.y * (iz + int(c[1])) / n
				quad.append(Vector3(x, _h(x, z), z))
			var q0: Vector3 = quad[0]; var q2: Vector3 = quad[2]
			var cx: float = (q0.x + q2.x) / 2.0
			var cz: float = (q0.z + q2.z) / 2.0
			var s: Variant = _strip_at(strips, cx, cz)
			var col := mc.lerp(Color("3c5530"), 0.5 + 0.5 * sin(cx * 0.07) * sin(cz * 0.05)) if s == null else _block_colour(s["b"])
			if s == null and absf(cz) <= half.y and absf(cx) <= half.x: col = Color("8d7656")   # tracks between Blocks
			for t in [0, 1, 2, 0, 2, 3]:
				st.set_color(col)
				st.add_vertex(quad[t])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mi.material_override = mat
	tile.add_child(mi)

func _block_colour(b: Dictionary) -> Color:
	var id := String(b["id"])
	var bc: Color = UI.BLOCK.get(id, Color("888888"))
	return bc.lerp(_soil_colour(b), 0.6).darkened(0.18)

## Soil cut-away on all four edges: topsoil, subsoil to rooting depth, bedrock to a flat base (depths ×6).
func _skirt(tile: Node3D, strips: Array, ext: Vector2) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := 1e9
	for iz in 21:
		for ix in 21:
			base = minf(base, _h(-ext.x + 2 * ext.x * ix / 20.0, -ext.y + 2 * ext.y * iz / 20.0))
	var deepest := 1.0
	for s in strips: deepest = maxf(deepest, float(s["b"].get("depth", 100)) / 100.0)
	base -= (deepest + 1.2) * SOIL_EXAG   # a slab of bedrock below the deepest roots
	var edges := [[Vector2(-ext.x, ext.y), Vector2(ext.x, ext.y)], [Vector2(ext.x, ext.y), Vector2(ext.x, -ext.y)],
		[Vector2(ext.x, -ext.y), Vector2(-ext.x, -ext.y)], [Vector2(-ext.x, -ext.y), Vector2(-ext.x, ext.y)]]
	var rock := _bedrock_colour()
	for e in edges:
		var segs := 48
		for i in segs:
			var p0: Vector2 = e[0].lerp(e[1], float(i) / segs)
			var p1: Vector2 = e[0].lerp(e[1], float(i + 1) / segs)
			var pm := (p0 + p1) / 2.0
			# nearest Block along this edge decides the soil column (margin gets a generic 1 m profile)
			var s: Variant = _strip_at(strips, clampf(pm.x, -half.x, half.x), clampf(pm.y, -half.y, half.y))
			var depth_m := 1.0
			var sub := Color("7c5b3e")
			var top := Color("4b3526")
			var stones := 20.0
			if s != null:
				depth_m = float(s["b"].get("depth", 100)) / 100.0
				sub = _soil_colour(s["b"])
				stones = float(s["b"].get("stones", 20))
			top = top.lerp(sub, 0.25)
			var layers := [[0.0, 0.3 * SOIL_EXAG, top], [0.3 * SOIL_EXAG, depth_m * SOIL_EXAG, sub.lerp(rock, stones / 250.0)], [depth_m * SOIL_EXAG, 999.0, rock]]
			var y0t := _h(p0.x, p0.y); var y1t := _h(p1.x, p1.y)
			for L in layers:
				var a0 := maxf(base, y0t - float(L[0])); var a1 := maxf(base, y1t - float(L[0]))
				var b0 := maxf(base, y0t - float(L[1])); var b1 := maxf(base, y1t - float(L[1]))
				if a0 - b0 < 0.01 and a1 - b1 < 0.01: continue
				var v := [Vector3(p0.x, a0, p0.y), Vector3(p1.x, a1, p1.y), Vector3(p1.x, b1, p1.y), Vector3(p0.x, b0, p0.y)]
				for t in [0, 1, 2, 0, 2, 3]:
					st.set_color(L[2])
					st.add_vertex(v[t])
	# flat base underneath
	var bv := [Vector3(-ext.x, base, -ext.y), Vector3(ext.x, base, -ext.y), Vector3(ext.x, base, ext.y), Vector3(-ext.x, base, ext.y)]
	for t in [0, 2, 1, 0, 3, 2]:
		st.set_color(rock.darkened(0.4)); st.add_vertex(bv[t])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	tile.add_child(mi)

func _vines(tile: Node3D, strips: Array) -> void:
	var steep := slope >= 0.3
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 1.6, 0.7) if steep else Vector3(0.5, 1.6, 1.3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3f7a33") if _region() != "napa" else Color("4f7d34")
	mat.roughness = 0.9
	box.material = mat
	var xf := []
	for s in strips:
		var row := 2.2 if not steep else 1.6
		var step := 1.4 if not steep else 1.6
		var x: float = s["x0"] + row / 2.0
		while x < s["x1"]:
			var z := -half.y + step / 2.0
			while z < half.y:
				xf.append(Transform3D(Basis(), Vector3(x, _h(x, z) + 0.8, z)))
				z += step
			x += row
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = xf.size()
	for i in xf.size(): mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	tile.add_child(mmi)

func _labels(tile: Node3D, strips: Array) -> void:
	for s in strips:
		var id := String(s["b"]["id"])
		var cx := (float(s["x0"]) + float(s["x1"])) / 2.0
		var l := Label3D.new()
		l.text = id
		l.font = UI.f_head
		l.font_size = 96
		l.outline_size = 18
		l.modulate = UI.BLOCK.get(id, Color.WHITE).lightened(0.2)
		l.outline_modulate = Color(0, 0, 0, 0.85)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.pixel_size = 0.004 / scale_k
		l.position = Vector3(cx, _h(cx, 0) + 9.0, 0)
		tile.add_child(l)

func _water(tile: Node3D, ext: Vector2) -> void:
	if _region() != "mosel": return
	var id := String(plot.get("id", ""))
	var river := id != "mosel-seitental"
	var w := ext.y * (0.35 if river else 0.06)
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(ext.x * 2.0, w)
	q.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3b6f8f"); mat.roughness = 0.15; mat.metallic = 0.2
	q.material_override = mat
	var edge_h := _h(0, ext.y)
	q.position = Vector3(0, edge_h - 1.5, ext.y + w / 2.0)
	tile.add_child(q)
	var l := Label3D.new(); l.text = "Mosel" if river else "stream"; l.font = UI.f_body; l.font_size = 64
	l.modulate = Color("cfe3ee"); l.pixel_size = 0.004 / scale_k; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.outline_size = 12; l.outline_modulate = Color(0, 0, 0, 0.7)
	l.position = Vector3(0, edge_h + 2.0, ext.y + w / 2.0)
	tile.add_child(l)

func _mist(tile: Node3D, strips: Array) -> void:
	for s in strips:
		if float(s["b"].get("frostPocket", 0)) <= 0.5: continue
		var cx := (float(s["x0"]) + float(s["x1"])) / 2.0
		var w := float(s["x1"]) - float(s["x0"])
		var q := MeshInstance3D.new()
		var pm := PlaneMesh.new(); pm.size = Vector2(w * 1.1, half.y * 0.9)
		q.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.92, 0.95, 1.0, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		q.material_override = mat
		var z := half.y * 0.5
		q.position = Vector3(cx, _h(cx, z) + 2.5, z)
		q.rotation.x = atan(slope) * 0.8
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tile.add_child(q)

func _compass_and_sun(ext: Vector2) -> void:
	var r := 10.0 * 0.62
	var n := Label3D.new(); n.text = "N"; n.font = UI.f_head; n.font_size = 90; n.outline_size = 14
	n.modulate = UI.GOLD; n.outline_modulate = Color(0, 0, 0, 0.8); n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.pixel_size = 0.004; n.position = Vector3(0, 0.6, -r)
	world_root.add_child(n)
	var arrow := MeshInstance3D.new()
	var pr := PrismMesh.new(); pr.size = Vector3(0.5, 0.9, 0.08)
	arrow.mesh = pr
	var am := StandardMaterial3D.new(); am.albedo_color = UI.GOLD; am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow.material_override = am
	arrow.position = Vector3(0, 0.1, -r + 0.9); arrow.rotation = Vector3(-PI / 2, 0, 0)
	world_root.add_child(arrow)
	# the sun stands in the south at a mid-latitude midday elevation (~45°)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.95
	sun.light_color = Color("fff1d6")
	sun.shadow_enabled = true
	sun.rotation = Vector3(deg_to_rad(-42), 0, 0)    # pointing from +z (south) towards −z
	sun.rotation.y = 0
	world_root.add_child(sun)
	sun.look_at_from_position(Vector3(0, 7, 7), Vector3.ZERO, Vector3.UP)
	var disc := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.28; sm.height = 0.56
	disc.mesh = sm
	var dm := StandardMaterial3D.new(); dm.albedo_color = Color("ffd66b"); dm.emission_enabled = true; dm.emission = Color("ffcf55"); dm.emission_energy_multiplier = 2.0
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = dm
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position = Vector3(0, 4.2, r * 1.05)
	world_root.add_child(disc)
	var sl := Label3D.new(); sl.text = "sun (south)"; sl.font = UI.f_body; sl.font_size = 48; sl.modulate = Color("ffe3a0")
	sl.outline_size = 10; sl.outline_modulate = Color(0, 0, 0, 0.8); sl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; sl.pixel_size = 0.004
	sl.position = disc.position + Vector3(0, 0.55, 0)
	world_root.add_child(sl)
