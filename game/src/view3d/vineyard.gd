# 3D vineyard bound to the simulation. Rebuilds the landscape when the Plot changes; on every snapshot it
# re-dresses each Block's vines (growth stage, bunch colour, disease/stress cues), the weather and the sun.
# It only *shows* the snapshot: every number comes from the sim (ADR 0001).
#
# Local frame: +Z runs down the fall line (the direction the Plot faces), +X across the slope, Y up.
# The sun is rotated into this frame from the Plot's aspect, so a south-facing slope gets the southern sun.
extends Node3D

const A := preload("res://src/view3d/assets3d.gd")
const SH := "res://src/view3d/shaders/"
const EYE := 1.7
const CHUNK := 12.0           # scatter / trellis cells
const VCHUNK_NEAR := 6.0      # vine cells for the near LODs (visibility ranges are per cell, so keep them small)
const VCHUNK_FAR := 18.0      # vine cells for the far LOD
const LOD0_END := 4.5
const LOD1_END := 22.0
const SHADOW_END := 45.0      # beyond this the far LOD stops casting shadows
const PZ0 := -2600.0          # profile start (z) and step
const PSTEP := 1.0
const PN := 5600
const ASPECTS := {"N": 0.0, "NNE": 22.5, "NE": 45.0, "ENE": 67.5, "E": 90.0, "ESE": 112.5, "SE": 135.0, "SSE": 157.5,
	"S": 180.0, "SSW": 202.5, "SW": 225.0, "WSW": 247.5, "W": 270.0, "WNW": 292.5, "NW": 315.0, "NNW": 337.5}
const TRAINING_FILE := {"Einzelpfahl": "einzelpfahl", "Guyot": "guyot", "Cordon": "cordon"}

var cam: Camera3D
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var mats := {}
var world: Node3D                 # everything that depends on the Plot (rebuilt on Plot change)
var plot_key := ""
var region := "mosel"
var D := {}

# terrain
var sv := 0.3                     # Plot slope (rise/run)
var aspect := 180.0
var lat := 50.0
var hz := 30.0                    # half depth of the vineyard band (z)
var band_x0 := -50.0
var band_x1 := 50.0
var prof := PackedFloat32Array()
var noise := FastNoiseLite.new()
var river := Vector2(INF, INF)    # z range of the Moselle (Mosel only)
var river_y := 0.0
var blocks := []                  # per Block: {id, x0, x1, slope, training, vsp, mm: [{mmi, lod, seed}], center}
var block_delta := PackedFloat32Array()   # per-x slope offset table (x from band_x0-40, 1 m)
var bd_x0 := 0.0

# weather
var rain_node: GPUParticles3D
var splash_node: GPUParticles3D
var rain_hf: GPUParticlesCollisionHeightField3D
var mist_mat: ShaderMaterial
var mist_node: MeshInstance3D
var sky_cache := {}
var current_sky := ""
var hud := ""


func _ready() -> void:
	noise.seed = 7
	noise.frequency = 1.0 / 80.0
	noise.fractal_octaves = 3
	_ensure_globals()
	_setup_environment()
	_setup_sun()
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 6000.0
	cam.environment = env
	var ca := CameraAttributesPractical.new()
	ca.auto_exposure_enabled = false
	cam.attributes = ca
	add_child(cam)
	_build_rain()
	_build_mist_layer()


static func _ensure_globals() -> void:
	# global shader uniforms are normally declared in project.godot; declare them at runtime so the view
	# works without touching project settings (guarded: they persist for the whole session)
	if Engine.has_meta("view3d_globals"):
		return
	Engine.set_meta("view3d_globals", true)
	for n in ["wetness", "rain_amount", "wind_strength"]:
		RenderingServer.global_shader_parameter_add(n, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0 if n == "wind_strength" else 0.0)


# =============================================================================================== snapshot
func apply_snapshot(snap: Dictionary) -> void:
	D = snap
	var p: Dictionary = D.get("plot", {})
	var key := "%s|%s" % [p.get("id", ""), _blocks_key()]
	if key != plot_key:
		plot_key = key
		_build_world()
	_dress_blocks()
	_apply_weather()
	_update_hud()


func _blocks_key() -> String:
	var s := ""
	for b in D.get("blocks", []):
		s += "%s:%s:%s:%s;" % [b.get("id", ""), b.get("training", ""), b.get("density", 0), b.get("area", 0)]
	return s


func _num(d: Dictionary, k: String, def := 0.0) -> float:
	var v = d.get(k, def)
	return float(v) if v != null else def


# =============================================================================================== materials
func _mat(name: String) -> Material:
	if mats.has(name):
		return mats[name]
	var m: Material
	match name:
		"vine_wood":
			var s := StandardMaterial3D.new()
			s.albedo_texture = A.tex("textures/bark_willow_02/diff.jpg")
			s.albedo_color = Color(0.56, 0.54, 0.52)
			s.normal_enabled = true
			s.normal_texture = A.tex("textures/bark_willow_02/nor_gl.jpg")
			s.normal_scale = 0.6
			s.roughness = 0.9
			s.uv1_scale = Vector3(1, 1.5, 1)
			m = s
		"vine_bark":
			var s := StandardMaterial3D.new()
			s.albedo_texture = A.tex("textures/bark_willow_02/diff.jpg")
			s.albedo_color = Color(0.62, 0.50, 0.42)
			s.normal_enabled = true
			s.normal_texture = A.tex("textures/bark_willow_02/nor_gl.jpg")
			s.roughness = 0.92
			m = s
		"vine_leaf":
			var sm := ShaderMaterial.new()
			sm.shader = load(SH + "leaf.gdshader")
			sm.set_shader_parameter("leaf_detail", A.tex("models/leaf_detail.png"))
			m = sm
		"vine_berry":
			var sm := ShaderMaterial.new()
			sm.shader = load(SH + "berry.gdshader")
			m = sm
		"grass":
			var s := StandardMaterial3D.new()
			s.vertex_color_use_as_albedo = true
			s.cull_mode = BaseMaterial3D.CULL_DISABLED
			s.roughness = 0.8
			s.backlight_enabled = true
			s.backlight = Color(0.18, 0.22, 0.05)
			m = s
		"post":
			var s := StandardMaterial3D.new()
			s.albedo_texture = A.tex("textures/bark_willow_02/diff.jpg")
			s.albedo_color = Color(0.55, 0.52, 0.48)
			s.roughness = 0.95
			s.uv1_scale = Vector3(0.5, 2.0, 1)
			m = s
		"wire":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.42, 0.43, 0.45)
			s.metallic = 0.7
			s.roughness = 0.5
			m = s
		_:
			m = StandardMaterial3D.new()
	mats[name] = m
	return m


func _prep(mesh: Mesh) -> Mesh:
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		var nm := String(m.resource_name) if m else ""
		if nm != "":
			mesh.surface_set_material(i, _mat(nm))
	return mesh


## Per-Block copy of a vine mesh whose leaf/berry surfaces use that Block's own materials.
func _block_mesh(owner: Dictionary, training: String, g: int, seed: int, lod: int) -> Mesh:
	var key := "%s_%d_%d_%d" % [training, g, seed, lod]
	var cache: Dictionary = owner["meshes"]
	if cache.has(key):
		return cache[key]
	var base := _vine_mesh(training, g, seed, lod)
	var m: Mesh = base.duplicate()
	for i in m.get_surface_count():
		var sm := m.surface_get_material(i)
		if sm == _mat("vine_leaf"):
			m.surface_set_material(i, owner["leaf_mat"])
		elif sm == _mat("vine_berry"):
			m.surface_set_material(i, owner["berry_mat"])
	cache[key] = m
	return m


func _owner_materials(owner: Dictionary) -> void:
	owner["leaf_mat"] = _mat("vine_leaf").duplicate()
	owner["berry_mat"] = _mat("vine_berry").duplicate()
	owner["meshes"] = {}


var _vine_cache := {}
func _vine_mesh(training: String, g: int, seed: int, lod: int) -> Mesh:
	var key := "%s_%d_%d_%d" % [training, g, seed, lod]
	if _vine_cache.has(key):
		return _vine_cache[key]
	var d := A.glb_meshes("models/vine_%s_g%d.glb" % [training, g])
	var mesh: Mesh = d.get("s%d_lod%d" % [seed, lod], BoxMesh.new())
	_prep(mesh)
	_vine_cache[key] = mesh
	return mesh


# =============================================================================================== environment
func _setup_environment() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load(SH + "sky.gdshader")
	sky_mat.set_shader_parameter("radiance_clamp", 3.0)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_512
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4
	env.ssil_enabled = true
	env.ssil_radius = 2.0
	env.ssil_intensity = 0.6
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.3
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.00013
	env.fog_aerial_perspective = 0.55
	env.volumetric_fog_enabled = false


func _setup_sun() -> void:
	sun = DirectionalLight3D.new()
	add_child(sun)
	sun.light_color = Color(1.0, 0.88, 0.74)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_split_1 = 0.05
	sun.directional_shadow_split_2 = 0.15
	sun.directional_shadow_split_3 = 0.4
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.0
	sun.light_volumetric_fog_energy = 1.6


func _sky_entry(rel: String) -> Array:
	if sky_cache.has(rel):
		return sky_cache[rel]
	var img := Image.load_from_file(A.path(rel))
	var best := 0.0
	var bu := -1.0
	if img:
		for y in range(0, img.get_height() / 2, 4):
			for x in range(0, img.get_width(), 4):
				var c := img.get_pixel(x, y)
				var l := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
				if l > best:
					best = l
					bu = (x + 0.5) / img.get_width()
	else:
		img = Image.create(8, 4, false, Image.FORMAT_RGBF)
		img.fill(Color(0.5, 0.6, 0.8))
	if best < 20.0:
		bu = -1.0                               # overcast: no baked sun to line up
	var e := [ImageTexture.create_from_image(img), bu]
	sky_cache[rel] = e
	return e


func _sky_rot(entry: Array, sdir: Vector3) -> float:
	if float(entry[1]) < 0.0:
		return 0.0
	return atan2(sdir.x, -sdir.z) - (float(entry[1]) * TAU - PI)


# =============================================================================================== terrain
func _aspect_deg(s: String) -> float:
	return float(ASPECTS.get(s, 180.0))


## Profile keypoints (distance from the band edge, slope as drop per metre towards +z; negative = rising).
func _profile_keys() -> Array:
	var up := []
	var down := []
	match region:
		"mosel":
			var steep := sv >= 0.3
			var hill := maxf(sv, 0.62)
			up = [[0.0, sv], [12.0 if steep else 30.0, sv], [40.0 if steep else 60.0, hill], [170.0, hill * 0.9], [240.0, 0.03]]
			var fd := clampf(sv * 70.0, 6.0, 55.0)
			down = [[0.0, sv], [fd, sv], [fd + 10.0, 0.004], [fd + 175.0, 0.004], [fd + 200.0, -0.5], [fd + 420.0, -0.45], [fd + 490.0, -0.02]]
			river = Vector2(hz + fd + 24.0, hz + fd + 150.0)
		"cote-dor":
			up = [[0.0, sv], [90.0, maxf(sv, 0.10)], [300.0, 0.16], [360.0, 0.55], [440.0, 0.5], [500.0, 0.02]]
			down = [[0.0, sv], [80.0, sv * 0.6], [260.0, 0.004], [2400.0, 0.002]]
			river = Vector2(INF, INF)
		_:
			if sv < 0.1:
				up = [[0.0, sv], [350.0, 0.006], [650.0, 0.30], [1300.0, 0.28], [1650.0, 0.03]]
				down = [[0.0, sv], [250.0, 0.004], [1100.0, 0.004], [1300.0, -0.28], [1900.0, -0.25], [2200.0, -0.02]]
			else:
				up = [[0.0, sv], [60.0, 0.38], [380.0, 0.30], [560.0, 0.04]]
				down = [[0.0, sv], [120.0, 0.16], [300.0, 0.01], [1400.0, 0.004], [1700.0, -0.25], [2100.0, -0.02]]
			river = Vector2(INF, INF)
	return [up, down]


func _key_slope(keys: Array, d: float) -> float:
	if d <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if d <= keys[i][0]:
			var t := smoothstep(keys[i - 1][0], keys[i][0], d)
			return lerpf(keys[i - 1][1], keys[i][1], t)
	return keys[-1][1]


func _build_profile() -> void:
	var kd := _profile_keys()
	prof.resize(PN)
	var i0 := int(-PZ0 / PSTEP)
	prof[i0] = 0.0
	for i in range(i0 + 1, PN):
		var z := PZ0 + (i - 0.5) * PSTEP
		var s := sv if z <= hz else _key_slope(kd[1], z - hz)
		prof[i] = prof[i - 1] - s * PSTEP
	for i in range(i0 - 1, -1, -1):
		var z := PZ0 + (i + 0.5) * PSTEP
		var s := sv if z >= -hz else _key_slope(kd[0], -hz - z)
		prof[i] = prof[i + 1] + s * PSTEP
	if river.x < INF:
		river_y = _prof(river.x - 8.0) - 1.6


func _prof(z: float) -> float:
	var f := (z - PZ0) / PSTEP
	var i := clampi(int(f), 0, PN - 2)
	var t := clampf(f - i, 0.0, 1.0)
	return prof[i] * (1.0 - t) + prof[i + 1] * t


func _delta(x: float) -> float:
	var i := clampi(int(x - bd_x0), 0, block_delta.size() - 1)
	return block_delta[i]


## Terrain height. Inside the band the ground is a clean slope (per-Block slope); away from it the
## landscape gets hills, gullies and fine noise.
func H(x: float, z: float) -> float:
	var y := _prof(z)
	var zc := clampf(z, -hz, hz)
	y -= _delta(x) * zc
	var dx := maxf(maxf(band_x0 - x, x - band_x1), 0.0)
	var dz := maxf(absf(z) - hz, 0.0)
	var far := smoothstep(12.0, 140.0, sqrt(dx * dx + dz * dz))
	var amp := 14.0 if region != "napa" else 22.0
	y += far * (amp * sin(x / 170.0 + 0.4) * smoothstep(0.0, 1.0, absf(sin(z / 900.0 + 0.3)) + 0.3) + amp * 0.6 * noise.get_noise_2d(x, z))
	y += 0.09 * noise.get_noise_2d(x * 9.0, z * 9.0)
	if river.x < INF and z > river.x - 12.0 and z < river.y + 12.0:
		var t := minf(smoothstep(river.x - 12.0, river.x + 4.0, z), smoothstep(river.y + 12.0, river.y - 4.0, z))
		y = lerpf(y, river_y - 1.5, t)
	return y


func _normal(x: float, z: float) -> Vector3:
	var e := 0.4
	return Vector3(H(x - e, z) - H(x + e, z), 2.0 * e, H(x, z - e) - H(x, z + e)).normalized()


func ground_height(x: float, z: float) -> float:
	return H(x, z)


# =============================================================================================== world build
func _build_world() -> void:
	if world:
		world.queue_free()
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	blocks.clear()
	var p: Dictionary = D.get("plot", {})
	region = String(D.get("region", {}).get("id", "mosel"))
	sv = _num(p, "slope", 20.0) / 100.0
	aspect = _aspect_deg(String(p.get("aspect", "S")))
	lat = _num(p, "lat", 49.9)
	_layout_blocks()
	_build_profile()
	var t0 := Time.get_ticks_msec()
	_build_terrain()
	var t1 := Time.get_ticks_msec()
	_build_far()
	var t2 := Time.get_ticks_msec()
	_build_vines()
	var t3 := Time.get_ticks_msec()
	_build_scatter()
	_build_neighbours()
	_build_trees()
	if river.x < INF:
		_build_river()
	print("view3d vineyard: %s terrain %d ms, far %d ms, vines %d ms, rest %d ms" % [p.get("id", ""), t1 - t0, t2 - t1, t3 - t2, Time.get_ticks_msec() - t3])


func _layout_blocks() -> void:
	var bl: Array = D.get("blocks", [])
	var total := 0.0
	for b in bl:
		total += _num(b, "area", 0.3) * 10000.0
	var depth := clampf(sqrt(total) * 0.55, 36.0, 70.0)
	hz = depth / 2.0
	var gap := 3.0
	var width := maxf(total / depth + gap * (bl.size() - 1), 20.0)
	band_x0 = -width / 2.0
	band_x1 = width / 2.0
	var x := band_x0
	for b in bl:
		var w := _num(b, "area", 0.3) * 10000.0 / depth
		var tr := String(b.get("training", "Guyot"))
		blocks.append({"id": b.get("id", ""), "name": b.get("name", ""), "x0": x, "x1": x + w, "slope": _num(b, "slope", sv * 100.0) / 100.0,
			"training": TRAINING_FILE.get(tr, "guyot"), "vsp": tr != "Einzelpfahl", "density": _num(b, "density", 5000.0),
			"stones": _num(b.get("soilProfile", {}), "stones", 20.0), "mm": [], "g": -1})
		_owner_materials(blocks[-1])
		x += w + gap
	# per-x slope offsets, smoothed across the paths and faded out beside the band
	bd_x0 = band_x0 - 40.0
	var n := int(width + 80.0) + 1
	block_delta.resize(n)
	for i in n:
		var xx := bd_x0 + i
		var acc := 0.0
		var wsum := 0.0
		for blk in blocks:
			var wgt := smoothstep(blk["x0"] - 3.0, blk["x0"] + 3.0, xx) * (1.0 - smoothstep(blk["x1"] - 3.0, blk["x1"] + 3.0, xx))
			acc += wgt * (float(blk["slope"]) - sv)
			wsum += wgt
		block_delta[i] = acc / maxf(wsum, 1.0) * (1.0 if wsum > 0.01 else 0.0)
	for blk in blocks:
		blk["center"] = Vector3((blk["x0"] + blk["x1"]) / 2.0, 0.0, 0.0)


func _grass_mask_outside(x: float, z: float) -> float:
	var dx := maxf(maxf(band_x0 - x, x - band_x1), 0.0)
	var dz := maxf(absf(z) - hz, 0.0)
	var d := sqrt(dx * dx + dz * dz)
	var base := 0.55 + 0.45 * noise.get_noise_2d(x * 3.0, z * 3.0)
	if _neighbour_planted(x, z):
		base = 0.2 + 0.3 * base if region != "napa" else 0.1
	return clampf(lerpf(0.9, base, smoothstep(2.0, 8.0, d)), 0.0, 1.0)


func _terrain_material() -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = load(SH + "terrain.gdshader")
	var soil: String = {"mosel": "rock_ground", "cote-dor": "dry_ground_rocks", "napa": "brown_mud_dry"}.get(region, "rock_ground")
	for pair in [["soil", soil], ["grass", "grass_ground"]]:
		var p: String = pair[0]
		var k: String = pair[1]
		sm.set_shader_parameter(p + "_alb", A.tex("textures/%s/diff.jpg" % k))
		sm.set_shader_parameter(p + "_nrm", A.tex("textures/%s/nor_gl.jpg" % k))
		sm.set_shader_parameter(p + "_rgh", A.tex("textures/%s/rough.jpg" % k))
		sm.set_shader_parameter(p + "_ao", A.tex("textures/%s/ao.jpg" % k) if A.exists("textures/%s/ao.jpg" % k) else A.tex("textures/grass_ground/ao.jpg"))
	match region:
		"mosel":   # weathered blue-grey Devonian slate
			sm.set_shader_parameter("soil_tint", Vector3(0.62, 0.68, 0.82))
			sm.set_shader_parameter("soil_desat", 0.8)
			sm.set_shader_parameter("soil_bright", 0.62)
			sm.set_shader_parameter("soil_scale", 3.0)
		"cote-dor":   # pale limestone / marl
			sm.set_shader_parameter("soil_tint", Vector3(1.08, 1.0, 0.88))
			sm.set_shader_parameter("soil_desat", 0.35)
			sm.set_shader_parameter("soil_bright", 1.15)
			sm.set_shader_parameter("soil_scale", 2.6)
		_:   # Napa: brown loam and gravel
			sm.set_shader_parameter("soil_tint", Vector3(1.05, 0.9, 0.78))
			sm.set_shader_parameter("soil_desat", 0.1)
			sm.set_shader_parameter("soil_bright", 1.0)
			sm.set_shader_parameter("soil_scale", 3.2)
	mats["terrain"] = sm
	return sm


func _build_terrain() -> void:
	var step := 0.8
	var x0 := band_x0 - 110.0
	var x1 := band_x1 + 110.0
	var z0 := -hz - 110.0
	var z1 := hz + 110.0
	var nx := int((x1 - x0) / step) + 1
	var nz := int((z1 - z0) / step) + 1
	var hts := PackedFloat32Array()
	hts.resize(nx * nz)
	for iz in nz:
		var z := z0 + iz * step
		for ix in nx:
			hts[iz * nx + ix] = H(x0 + ix * step, z)
	var verts := PackedVector3Array(); verts.resize(nx * nz)
	var norms := PackedVector3Array(); norms.resize(nx * nz)
	var tans := PackedFloat32Array(); tans.resize(nx * nz * 4)
	var cols := PackedColorArray(); cols.resize(nx * nz)
	for iz in nz:
		var z := z0 + iz * step
		for ix in nx:
			var i := iz * nx + ix
			var x := x0 + ix * step
			var y := hts[i]
			var edge := ix == 0 or iz == 0 or ix == nx - 1 or iz == nz - 1
			verts[i] = Vector3(x, y - (4.0 if edge else 0.0), z)
			var hl := hts[i - 1] if ix > 0 else y
			var hr := hts[i + 1] if ix < nx - 1 else y
			var hu := hts[i - nx] if iz > 0 else y
			var hd := hts[i + nx] if iz < nz - 1 else y
			var n := Vector3(hl - hr, 2.0 * step, hu - hd).normalized()
			norms[i] = n
			var t := Vector3(2.0 * step, hr - hl, 0.0).normalized()
			tans[i * 4] = t.x; tans[i * 4 + 1] = t.y; tans[i * 4 + 2] = t.z; tans[i * 4 + 3] = -1.0
			var g := _grass_mask_outside(x, z)
			var scrub := 0.0
			if region == "mosel" and sv >= 0.1 and not _neighbour_planted(x, z):
				scrub = smoothstep(4.0, 14.0, maxf(maxf(band_x0 - x, x - band_x1), absf(z) - hz))
			cols[i] = Color(maxf(g, scrub), 0.5, scrub)
	var idx := PackedInt32Array()
	idx.resize((nx - 1) * (nz - 1) * 6)
	var k := 0
	for iz in nz - 1:
		for ix in nx - 1:
			var a := iz * nx + ix
			idx[k] = a; idx[k + 1] = a + 1; idx[k + 2] = a + nx
			idx[k + 3] = a + 1; idx[k + 4] = a + nx + 1; idx[k + 5] = a + nx
			k += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TANGENT] = tans
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var sm := _terrain_material()
	_paint_ground_map(sm)
	mi.material_override = sm
	world.add_child(mi)


## Ground map over the band: R = grass cover (inter-row cover crop, paths), G = soil brightness per Block.
func _paint_ground_map(sm: ShaderMaterial) -> void:
	var res := 0.25
	var mx0 := band_x0 - 6.0
	var mz0 := -hz - 6.0
	var w := int((band_x1 - band_x0 + 12.0) / res)
	var h := int((2.0 * hz + 12.0) / res)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bright := {}
	for blk in blocks:
		bright[blk["id"]] = 0.5 + clampf((float(blk["stones"]) - 40.0) / 120.0, -0.25, 0.25)
	for iy in h:
		var z := mz0 + (iy + 0.5) * res
		for ix in w:
			var x := mx0 + (ix + 0.5) * res
			var grass := 0.95
			var gb := 0.5
			var inz := absf(z) < hz - 1.0
			for blk in blocks:
				if x > blk["x0"] + 0.8 and x < blk["x1"] - 0.8 and inz:
					gb = bright[blk["id"]]
					if blk["vsp"]:
						var r := _row_offset(blk, x, z)
						grass = 0.1 if r < 0.35 else clampf(0.55 + 0.4 * noise.get_noise_2d(x * 4.0, z * 4.0), 0.0, 1.0)
					else:
						grass = clampf(0.05 + 0.9 * noise.get_noise_2d(x * 2.5, z * 2.5), 0.0, 0.8)
					break
			img.set_pixel(ix, iy, Color(grass, gb, 1.0, 1.0))
	sm.set_shader_parameter("ground_map", ImageTexture.create_from_image(img))
	sm.set_shader_parameter("map_rect", Vector4(mx0, mz0, w * res, h * res))


# =============================================================================================== vine layout
func _row_dir(blk: Dictionary) -> Vector2:
	# rows follow the sim's default: down the slope on steep Plots, otherwise north-south (as simulated)
	if sv >= 0.3:
		return Vector2(0, 1)
	var a := deg_to_rad(aspect)
	return Vector2(sin(a), cos(a)).normalized()    # world direction of north


func _spacing(blk: Dictionary) -> Vector2:
	# (row spacing, vine spacing) in metres from the planting density
	var dens := maxf(float(blk["density"]), 1000.0)
	var area := 10000.0 / dens
	if not blk["vsp"]:
		var s := sqrt(area)
		return Vector2(s, s)
	var row := clampf(sqrt(area) * 1.45, 1.0, 2.6)
	if dens >= 9000.0:
		row = 1.0
	return Vector2(row, area / row)


func _row_offset(blk: Dictionary, x: float, z: float) -> float:
	var u := _row_dir(blk)
	var sp := _spacing(blk)
	var wv := Vector2(-u.y, u.x)
	var p := Vector2(x, z).dot(wv) / sp.x
	return absf(p - roundf(p)) * sp.x


func _block_vines(blk: Dictionary) -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(blk["id"]) + plot_key)
	var sp := _spacing(blk)
	var margin := 1.2
	var bx0: float = blk["x0"] + margin
	var bx1: float = blk["x1"] - margin
	var bz0 := -hz + margin
	var bz1 := hz - margin
	if not blk["vsp"]:
		var s := sp.x
		var z := bz0
		while z <= bz1:
			var x := bx0 + fmod(absf(z) * 0.37, s * 0.5)
			while x <= bx1:
				out.append([x + rng.randf_range(-0.07, 0.07), z + rng.randf_range(-0.07, 0.07), rng.randf() * TAU, 1.0, 1.0, rng.randi() % 2])
				x += s
			z += s
		return out
	var u := _row_dir(blk)
	var wv := Vector2(-u.y, u.x)
	var corners := [Vector2(bx0, bz0), Vector2(bx1, bz0), Vector2(bx0, bz1), Vector2(bx1, bz1)]
	var wmin := INF; var wmax := -INF; var umin := INF; var umax := -INF
	for c in corners:
		wmin = minf(wmin, c.dot(wv)); wmax = maxf(wmax, c.dot(wv))
		umin = minf(umin, c.dot(u)); umax = maxf(umax, c.dot(u))
	var yaw := atan2(-u.y, u.x)
	var base_v := 1.0 if blk["training"] == "guyot" else 1.3
	var sx := clampf(sp.y / base_v, 0.75, 1.5)
	var sy := 0.78 if region == "cote-dor" else 1.0
	var k := ceilf(wmin / sp.x)
	while k * sp.x <= wmax:
		var t := ceilf(umin / sp.y) * sp.y
		while t <= umax:
			var p := u * t + wv * (k * sp.x)
			if p.x >= bx0 and p.x <= bx1 and p.y >= bz0 and p.y <= bz1:
				out.append([p.x, p.y, yaw, sx, sy, rng.randi() % 2])
			t += sp.y
		k += 1.0
	return out


func _build_vines() -> void:
	for bi in blocks.size():
		var blk: Dictionary = blocks[bi]
		var vines := _block_vines(blk)
		blk["count"] = vines.size()
		# a vine for the close-up camera: mid-Block for VSP rows, on the lower edge for stake-trained vines
		var best := Vector2(blk["center"].x, 0.0)
		var bd := INF
		var want := Vector2(blk["center"].x, 2.0) if blk["vsp"] else Vector2(blk["center"].x, hz)
		for v in vines:
			var dd := Vector2(v[0], v[1]).distance_squared_to(want)
			if dd < bd:
				bd = dd
				best = Vector2(v[0], v[1])
		blk["focus"] = best
		for pass_lods in [[0, 1, 3], [2, 4]]:
			var cs: float = VCHUNK_NEAR if pass_lods[0] == 0 else VCHUNK_FAR
			var chunks := {}
			for v in vines:
				var key := Vector2i(floori(v[0] / cs), floori(v[1] / cs))
				if not chunks.has(key):
					chunks[key] = [[], []]
				chunks[key][int(v[5])].append(v)
			for key in chunks:
				var center := Vector3((key.x + 0.5) * cs, 0.0, (key.y + 0.5) * cs)
				center.y = H(center.x, center.z)
				for seed in 2:
					var list: Array = chunks[key][seed]
					if list.is_empty():
						continue
					var xfs := []
					for v in list:
						var pos := Vector3(v[0], H(v[0], v[1]), v[1])
						var b := Basis(Vector3.UP, float(v[2])) * Basis.from_scale(Vector3(v[3], v[4], v[3] if not blk["vsp"] else 1.0))
						xfs.append(Transform3D(b, pos - center))
					for lod in pass_lods:   # 0,1,2 visible LODs; 3 = LOD2-mesh shadow proxy for the LOD0+LOD1 rings; 4 = LOD3 mesh, no shadows
						_vine_mmi(blk, xfs, center, lod, seed)
		if blk["vsp"]:
			_build_trellis(blk)


func _vine_mmi(blk: Dictionary, xfs: Array, center: Vector3, lod: int, seed: int) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.position = center
	match lod:
		0:
			mmi.visibility_range_end = LOD0_END
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		1:
			mmi.visibility_range_begin = LOD0_END
			mmi.visibility_range_end = LOD1_END
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		2:
			mmi.visibility_range_begin = LOD1_END
			mmi.visibility_range_end = SHADOW_END
		3:
			mmi.visibility_range_end = LOD1_END
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		4:
			mmi.visibility_range_begin = SHADOW_END
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end_margin = 1.0
	world.add_child(mmi)
	blk["mm"].append({"mmi": mmi, "lod": lod, "seed": seed})


func _build_trellis(blk: Dictionary) -> void:
	var u := _row_dir(blk)
	var wv := Vector2(-u.y, u.x)
	var sp := _spacing(blk)
	var margin := 0.6
	var bx0: float = blk["x0"] + margin
	var bx1: float = blk["x1"] - margin
	var bz0 := -hz + margin
	var bz1 := hz - margin
	var hw := (0.80 if blk["training"] == "guyot" else 0.95) * (0.78 if region == "cote-dor" else 1.0)
	var top := (1.75 if blk["training"] == "guyot" else 1.95) * (0.78 if region == "cote-dor" else 1.0)
	var wires := [[0.0, hw], [-0.13, hw + 0.33], [0.13, hw + 0.33], [-0.14, hw + 0.66], [0.14, hw + 0.66], [0.0, top - 0.05]]
	var posts := {}
	var segs := {}
	var corners := [Vector2(bx0, bz0), Vector2(bx1, bz0), Vector2(bx0, bz1), Vector2(bx1, bz1)]
	var wmin := INF; var wmax := -INF; var umin := INF; var umax := -INF
	for c in corners:
		wmin = minf(wmin, c.dot(wv)); wmax = maxf(wmax, c.dot(wv))
		umin = minf(umin, c.dot(u)); umax = maxf(umax, c.dot(u))
	var k := ceilf(wmin / sp.x)
	while k * sp.x <= wmax:
		# clip this row line to the block rectangle
		var pts := []
		var t := umin
		while t <= umax + 0.01:
			var p := u * t + wv * (k * sp.x)
			if p.x >= bx0 and p.x <= bx1 and p.y >= bz0 and p.y <= bz1:
				pts.append(p)
			t += 0.5
		if pts.size() >= 2:
			var a: Vector2 = pts[0]
			var b: Vector2 = pts[-1]
			var n := maxi(1, int(ceil(a.distance_to(b) / 6.0)))
			var prev := Vector3.ZERO
			for i in n + 1:
				var q := a.lerp(b, float(i) / n)
				var p3 := Vector3(q.x, H(q.x, q.y), q.y)
				var key := Vector2i(floori(q.x / CHUNK), floori(q.y / CHUNK))
				if not posts.has(key):
					posts[key] = []; segs[key] = []
				posts[key].append([p3, i == 0 or i == n])
				if i > 0:
					for wdef in wires:
						var off := Vector3(wv.x, 0, wv.y) * float(wdef[0])
						segs[key].append([prev + off + Vector3(0, wdef[1], 0), p3 + off + Vector3(0, wdef[1], 0)])
				prev = p3
		k += 1.0
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.035; post_mesh.bottom_radius = 0.04; post_mesh.height = 1.0; post_mesh.radial_segments = 8
	post_mesh.material = _mat("post")
	var wire_mesh := BoxMesh.new()
	wire_mesh.size = Vector3(1, 1, 1)
	wire_mesh.material = _mat("wire")
	for key in posts:
		var center := Vector3((key.x + 0.5) * CHUNK, 0, (key.y + 0.5) * CHUNK)
		center.y = H(center.x, center.z)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = post_mesh
		mm.instance_count = posts[key].size()
		for i in posts[key].size():
			var pp: Vector3 = posts[key][i][0]
			var hgt := top + 0.35
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(1, hgt, 1)), pp - center + Vector3(0, hgt / 2.0 - 0.3, 0)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.position = center
		mmi.visibility_range_end = 120.0
		world.add_child(mmi)
		var wm := MultiMesh.new()
		wm.transform_format = MultiMesh.TRANSFORM_3D
		wm.mesh = wire_mesh
		wm.instance_count = segs[key].size()
		for i in segs[key].size():
			var s0: Vector3 = segs[key][i][0]
			var s1: Vector3 = segs[key][i][1]
			var d := s1 - s0
			var len := d.length()
			var xa := d / maxf(len, 0.001)
			var side := xa.cross(Vector3.UP).normalized()
			var upv := side.cross(xa).normalized()
			var basis := Basis(xa * len, upv * 0.0026, side * 0.0026)
			wm.set_instance_transform(i, Transform3D(basis, (s0 + s1) / 2.0 - center))
		var wmi := MultiMeshInstance3D.new()
		wmi.multimesh = wm
		wmi.position = center
		wmi.visibility_range_end = 60.0
		wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(wmi)


# =============================================================================================== dressing
func _stage_growth(b: Dictionary) -> int:
	var st := String(b.get("stage", "Dormant"))
	match st:
		"Dormant":
			return 0
		"Budburst":
			return 1
		"Shoots":
			return 3 if _num(b, "lai") > 1.0 else 2
		"Flowering", "FruitSet":
			return 3
		_:
			return 4


func _dress_blocks() -> void:
	var date := String(D.get("date", "2000-06-01"))
	var doy := _doy(date)
	for bi in blocks.size():
		var blk: Dictionary = blocks[bi]
		var b: Dictionary = {}
		for x in D.get("blocks", []):
			if x.get("id", "") == blk["id"]:
				b = x
		if b.is_empty():
			continue
		var g := _stage_growth(b)
		if g != blk["g"]:
			blk["g"] = g
			for e in blk["mm"]:
				var lod: int = e["lod"]
				(e["mmi"] as MultiMeshInstance3D).multimesh.mesh = _block_mesh(blk, blk["training"], g, e["seed"], [0, 1, 2, 2, 3][lod])
		var st := String(b.get("stage", ""))
		var red: bool = b.get("red", false)
		var must: Dictionary = b.get("must", {}) if b.get("must") is Dictionary else {}
		var oe := _num(must, "oe", 0.0)
		# ripening colour: véraison starts the change (~25-30 °Oe); fully coloured by ~60 °Oe
		var t := 0.0
		if st in ["Veraison", "Ripening", "Picking", "Harvested", "LeafFall"] and must.size() > 0:
			t = clampf((oe - 22.0) / 38.0, 0.08, 1.0)
		var t2 := clampf((oe - 55.0) / 40.0, 0.0, 1.0)
		var ripe := Color(0.10, 0.012, 0.03).lerp(Color(0.022, 0.008, 0.036), t2) if red else Color(0.36, 0.42, 0.10).lerp(Color(0.50, 0.42, 0.11), t2)
		var show := 1.0
		if b.get("harvested", false) or st == "Harvested":
			show = 0.0
		elif b.get("picking", false) or st == "Picking":
			show = 1.0 - _num(b, "pickedPct") / 100.0
		show *= 1.0 - clampf(_num(b, "frostLoss") / 100.0, 0.0, 0.9)
		var flowering := 1.0 if st == "Flowering" else 0.0
		var autumn := 0.0
		var drop := 0.0
		if st == "LeafFall":
			autumn = clampf(0.55 + (doy - 290) / 40.0, 0.55, 1.0)
			drop = clampf((doy - 295) / 30.0, 0.05, 0.92)
		elif doy > 268 and g == 4:
			autumn = clampf((doy - 268) / 50.0, 0.0, 0.6)
		var wc := String(b.get("waterClass", "none"))
		var stress: float = {"severe": 1.0, "moderate–severe": 0.55, "weak–moderate": 0.2}.get(wc, 0.0)
		var removal := 0.0
		if st in ["FruitSet", "BunchClosure", "Veraison", "Ripening", "Picking"]:
			var side := String(b.get("leafSide", "None"))
			removal = {"Both": 0.9, "Morning": 0.5, "Afternoon": 0.5}.get(side, 0.0)
		var leaf_state := Vector4(clampf(_num(b, "downyLeaf") / 30.0, 0.0, 1.0), clampf(_num(b, "chlorosis") / 100.0, 0.0, 1.0), autumn, drop)
		var leaf_state2 := Vector4(stress, 1.0 if red else 0.0, removal, 0.0)
		var berry_col := Vector4(ripe.r, ripe.g, ripe.b, t)
		var berry_state := Vector4(show, _num(b, "greyRot") / 100.0, _num(b, "powderyBunch") / 100.0, _num(b, "sunburn") / 100.0)
		var berry_state2 := Vector4(flowering, _num(b, "nobleRot") / 100.0, 1.0 if red else 0.0, 0.0)
		var lm: ShaderMaterial = blk["leaf_mat"]
		var bm: ShaderMaterial = blk["berry_mat"]
		lm.set_shader_parameter("leaf_state", leaf_state)
		lm.set_shader_parameter("leaf_state2", leaf_state2)
		bm.set_shader_parameter("berry_col", berry_col)
		bm.set_shader_parameter("berry_state", berry_state)
		bm.set_shader_parameter("berry_state2", berry_state2)
	_dress_neighbours()
	_dress_season(doy)


func _doy(iso: String) -> int:
	var parts := iso.split("-")
	if parts.size() < 3:
		return 180
	var d := Time.get_unix_time_from_datetime_dict({"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2])})
	var j := Time.get_unix_time_from_datetime_dict({"year": int(parts[0]), "month": 1, "day": 1})
	return int((d - j) / 86400.0) + 1


func _dress_season(doy: int) -> void:
	# cover-crop colour through the year (Napa grass goes golden in the dry summer)
	var sm: ShaderMaterial = mats.get("terrain")
	var tint := Vector3(0.56, 0.84, 0.40)
	if region == "napa":
		var dry := smoothstep(110.0, 160.0, doy) * (1.0 - smoothstep(320.0, 350.0, doy))
		tint = tint.lerp(Vector3(1.25, 1.0, 0.5), dry)
	else:
		var winter := 1.0 - smoothstep(75.0, 115.0, doy) + smoothstep(300.0, 340.0, doy)
		tint = tint.lerp(Vector3(0.78, 0.8, 0.5), clampf(winter, 0.0, 1.0))
		tint = tint.lerp(Vector3(0.72, 0.82, 0.42), smoothstep(200.0, 240.0, doy) * (1.0 - smoothstep(280.0, 310.0, doy)) * 0.5)
	if sm:
		sm.set_shader_parameter("grass_tint", tint)
	var g := mats.get("grass") as StandardMaterial3D
	if g:
		g.albedo_color = Color(tint.x * 1.1, tint.y * 1.05, tint.z * 1.4)
	var fm: ShaderMaterial = mats.get("terrain_far")
	if fm and blocks.size() > 0:
		var canopy: float = [0.0, 0.1, 0.45, 0.8, 1.0][maxi(0, int(blocks[0]["g"]))]
		fm.set_shader_parameter("canopy", canopy)


# =============================================================================================== far terrain
func _parcel(x: float, z: float) -> float:
	# neighbours' vineyards come in parcels: strips down the fall line, each planted or fallow
	var px := floorf((x + 5000.0) / 26.0)
	var pz := floorf((z + 5000.0) / 70.0)
	return fposmod(sin(px * 12.9898 + pz * 78.233) * 43758.5453, 1.0)


func _neighbour_planted(x: float, z: float) -> bool:
	# vineyards on the slopes around the Plot (not on roads, the river or the forest)
	var p := _parcel(x, z)
	match region:
		"mosel":
			return (z > -hz - 190.0 and z < hz + clampf(sv * 70.0, 6.0, 55.0)) and p > 0.22
		"cote-dor":
			return z > -hz - 300.0 and z < hz + 90.0 and p > 0.1
		_:
			return absf(z) < 700.0 and p > 0.2 and H(x, z) < 60.0
	return false


func _far_color(x: float, z: float, y: float, slope: float) -> Color:
	var n := noise.get_noise_2d(x * 0.6, z * 0.6)
	var forest := Color(0.024, 0.048, 0.018)
	var scrub := Color(0.045, 0.07, 0.025)
	match region:
		"mosel":
			if river.x < INF and z > river.x - 14.0 and z < river.x - 2.0:
				return Color(0.09, 0.095, 0.085, 0.0)           # riverside road
			if river.x < INF and z > river.y + 2.0 and z < river.y + 160.0:
				var f := noise.get_noise_2d(x * 0.3 + 50.0, z * 0.3)
				return Color(0.12, 0.17, 0.06, 0.0) if f > 0.0 else Color(0.20, 0.18, 0.09, 0.0)
			if _neighbour_planted(x, z) and slope > 0.12:
				return Color(0.0, 0.0, 0.0, 1.0)
			if slope > 0.9 or n < -0.45:
				return Color(0.11, 0.105, 0.11, 0.0)            # slate outcrop
			if z < -hz - 200.0 or z > (river.y + 160.0 if river.x < INF else 400.0):
				return Color(forest.r, forest.g, forest.b, 0.0)
			return Color(scrub.r, scrub.g, scrub.b, 0.0)
		"cote-dor":
			if z > -hz - 300.0 and z < hz + 150.0 and n > -0.35:
				return Color(0.0, 0.0, 0.0, 1.0)
			if z <= -hz - 300.0:
				return Color(forest.r * 1.1, forest.g, forest.b, 0.0) if slope < 0.45 or n > -0.2 else Color(0.30, 0.28, 0.24, 0.0)
			var f := noise.get_noise_2d(x * 0.25 + 70.0, z * 0.25)
			if absf(f) < 0.05:
				return Color(0.22, 0.12, 0.09, 0.0)             # village roofs
			return Color(0.13, 0.17, 0.06, 0.0) if f > 0.0 else Color(0.25, 0.22, 0.11, 0.0)
		_:
			if y < 45.0 and n > -0.3:
				return Color(0.0, 0.0, 0.0, 1.0)
			var oak := noise.get_noise_2d(x * 2.5, z * 2.5)
			if y > 320.0:
				return Color(forest.r, forest.g * 1.1, forest.b, 0.0)
			return Color(0.05, 0.07, 0.03, 0.0) if oak > 0.25 else Color(0.36, 0.30, 0.14, 0.0)    # oak clumps in golden grass
	return Color(scrub.r, scrub.g, scrub.b, 0.0)


var far_grid := {}
func _build_far() -> void:
	var step := 20.0
	var ext := 2500.0
	var n := int(2.0 * ext / step) + 1
	var verts := PackedVector3Array(); verts.resize(n * n)
	var cols := PackedColorArray(); cols.resize(n * n)
	var norms := PackedVector3Array(); norms.resize(n * n)
	var tans := PackedFloat32Array(); tans.resize(n * n * 4)
	var hts := PackedFloat32Array(); hts.resize(n * n)
	var nx0 := band_x0 - 110.0; var nx1 := band_x1 + 110.0
	var nz0 := -hz - 110.0; var nz1 := hz + 110.0
	for iz in n:
		for ix in n:
			var x := -ext + ix * step
			var z := -ext + iz * step
			var y := H(x, z)
			if x > nx0 and x < nx1 and z > nz0 and z < nz1:      # tuck under the near terrain
				y -= 4.0 if (x > nx0 + 22.0 and x < nx1 - 22.0 and z > nz0 + 22.0 and z < nz1 - 22.0) else 0.8
			hts[iz * n + ix] = y
	for iz in n:
		for ix in n:
			var i := iz * n + ix
			var x := -ext + ix * step
			var z := -ext + iz * step
			var y := hts[i]
			verts[i] = Vector3(x, y, z)
			var hl := hts[i - 1] if ix > 0 else y
			var hr := hts[i + 1] if ix < n - 1 else y
			var hu := hts[i - n] if iz > 0 else y
			var hd := hts[i + n] if iz < n - 1 else y
			var nn := Vector3(hl - hr, 2.0 * step, hu - hd).normalized()
			norms[i] = nn
			var t := Vector3(2.0 * step, hr - hl, 0.0).normalized()
			tans[i * 4] = t.x; tans[i * 4 + 1] = t.y; tans[i * 4 + 2] = t.z; tans[i * 4 + 3] = -1.0
			var slope := sqrt(1.0 / maxf(nn.y * nn.y, 0.0001) - 1.0)
			cols[i] = _far_color(x, z, y, slope)
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var k := 0
	for iz in n - 1:
		for ix in n - 1:
			var a := iz * n + ix
			idx[k] = a; idx[k + 1] = a + 1; idx[k + 2] = a + n
			idx[k + 3] = a + 1; idx[k + 4] = a + n + 1; idx[k + 5] = a + n
			k += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TANGENT] = tans
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	far_grid = {"n": n, "step": step, "ext": ext, "h": hts, "c": cols, "nrm": norms}
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sm := ShaderMaterial.new()
	sm.shader = load(SH + "terrain_far.gdshader")
	sm.set_shader_parameter("detail_nrm", A.tex("textures/grass_ground/nor_gl.jpg"))
	sm.set_shader_parameter("detail_ao", A.tex("textures/grass_ground/ao.jpg"))
	var soil: Vector3 = {"mosel": Vector3(0.10, 0.105, 0.115), "cote-dor": Vector3(0.36, 0.31, 0.24), "napa": Vector3(0.24, 0.17, 0.11)}.get(region, Vector3(0.2, 0.18, 0.15))
	sm.set_shader_parameter("vine_soil", soil)
	sm.set_shader_parameter("vine_canopy", Vector3(0.06, 0.11, 0.035))
	sm.set_shader_parameter("row_spacing", 1.2 if region == "mosel" else (1.0 if region == "cote-dor" else 2.2))
	mats["terrain_far"] = sm
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)


func _build_river() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(5000.0, river.y - river.x + 20.0)
	mi.mesh = pm
	mi.position = Vector3(0, river_y, (river.x + river.y) / 2.0)
	var sm := ShaderMaterial.new()
	sm.shader = load(SH + "water.gdshader")
	var nt := NoiseTexture2D.new()
	nt.width = 512; nt.height = 512; nt.seamless = true; nt.as_normal_map = true; nt.bump_strength = 6.0; nt.generate_mipmaps = true
	var fn := FastNoiseLite.new(); fn.frequency = 0.02
	nt.noise = fn
	sm.set_shader_parameter("wave_nrm", nt)
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)


# =============================================================================================== scatter
func _add_chunked(items: Array, mesh: Mesh, vis_end: float, shadow: bool, mat: Material = null) -> void:
	var chunks := {}
	for it in items:
		var o: Vector3 = (it as Transform3D).origin
		var key := Vector2i(floori(o.x / CHUNK), floori(o.z / CHUNK))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(it)
	for key in chunks:
		var center := Vector3((key.x + 0.5) * CHUNK, 0, (key.y + 0.5) * CHUNK)
		center.y = H(center.x, center.z)
		var list: Array = chunks[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var xf: Transform3D = list[i]
			xf.origin -= center
			mm.set_instance_transform(i, xf)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.position = center
		mmi.visibility_range_end = vis_end
		if mat:
			mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mmi)


func _build_scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var stone_mat := StandardMaterial3D.new()
	var kinds := []
	match region:
		"mosel":
			stone_mat.albedo_color = Color(0.055, 0.062, 0.075).linear_to_srgb()
			stone_mat.roughness = 0.42
			kinds = ["stone_0", "stone_1", "stone_2", "stone_3", "stone_4"]
		"cote-dor":
			stone_mat.albedo_color = Color(0.46, 0.42, 0.34).linear_to_srgb()
			stone_mat.roughness = 0.9
			kinds = ["stone_0", "stone_2", "pebble_0", "pebble_1"]
		_:
			stone_mat.albedo_color = Color(0.20, 0.16, 0.13).linear_to_srgb()
			stone_mat.roughness = 0.75
			kinds = ["pebble_0", "pebble_1", "pebble_2"]
	stone_mat.normal_enabled = true
	stone_mat.normal_texture = A.tex("textures/rock_ground/nor_gl.jpg")
	stone_mat.normal_scale = 0.5
	stone_mat.uv1_triplanar = true
	stone_mat.uv1_scale = Vector3(4, 4, 4)
	mats["stone"] = stone_mat
	var per := {}
	for k in kinds:
		per[k] = []
	for blk in blocks:
		var area: float = (blk["x1"] - blk["x0"]) * 2.0 * hz
		var dens := float(blk["stones"]) / 100.0 * (6.0 if region == "mosel" else 3.0)
		var count := mini(int(area * dens), 30000)
		for i in count:
			var x := rng.randf_range(blk["x0"], blk["x1"])
			var z := rng.randf_range(-hz, hz)
			var s := (0.035 + 0.17 * pow(rng.randf(), 3.0)) * (1.0 if region == "mosel" else 0.7)
			var nrm := _normal(x, z)
			var basis := Basis(Quaternion(Vector3.UP, nrm)) * Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3(1, 0, 0), rng.randf_range(-0.4, 0.4))
			var k: String = kinds[rng.randi() % kinds.size()]
			per[k].append(Transform3D(basis.scaled(Vector3.ONE * s), Vector3(x, H(x, z) + 0.005 - s * 0.05, z)))
	for k in per:
		_add_chunked(per[k], A.first_mesh("models/%s.glb" % k), 38.0, false, stone_mat)
	# grass tufts on paths, margins and the inter-row cover
	var gm := A.first_mesh("models/grass_0.glb")
	for i in gm.get_surface_count():
		gm.surface_set_material(i, _mat("grass"))
	var tufts := []
	var tries := 0
	while tufts.size() < 9000 and tries < 60000:
		tries += 1
		var x := rng.randf_range(band_x0 - 30.0, band_x1 + 30.0)
		var z := rng.randf_range(-hz - 30.0, hz + 30.0)
		var inside := x > band_x0 and x < band_x1 and absf(z) < hz - 1.0
		var g := _grass_mask_outside(x, z)
		if inside:
			var blk := _block_at(x)
			if blk.is_empty():
				g = 0.9
			elif blk["vsp"]:
				g = 0.0 if _row_offset(blk, x, z) < 0.4 else 0.5
			else:
				g = 0.15
		if rng.randf() > g * 0.9:
			continue
		tufts.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.18, 0.42)), Vector3(x, H(x, z) - 0.02, z)))
	_add_chunked(tufts, gm, 34.0, false)


func _block_at(x: float) -> Dictionary:
	for blk in blocks:
		if x >= blk["x0"] and x <= blk["x1"]:
			return blk
	return {}


# =============================================================================================== neighbours & trees
var neighbour_mm := []
var neighbour_training := "guyot"
var neighbour_owner := {}
func _build_neighbours() -> void:
	neighbour_mm.clear()
	neighbour_owner = {}
	_owner_materials(neighbour_owner)
	neighbour_training = "einzelpfahl" if region == "mosel" and sv >= 0.3 else ("cordon" if region == "napa" else "guyot")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var rs := 1.2 if neighbour_training == "einzelpfahl" else (1.0 if region == "cote-dor" else 2.1)
	var vs := 1.2 if neighbour_training == "einzelpfahl" else (1.0 if region == "cote-dor" else 1.3)
	var list := [[], []]
	var ring := 42.0
	var z := -hz - ring
	var sy := 0.78 if region == "cote-dor" else 1.0
	while z <= hz + ring:
		var x := band_x0 - ring
		while x <= band_x1 + ring:
			var dx := maxf(maxf(band_x0 - x, x - band_x1), 0.0)
			var dz := maxf(absf(z) - hz, 0.0)
			var outside := dx > 5.0 or dz > 5.0
			if outside and _neighbour_planted(x, z) and absf(fmod(x + 7000.0, 40.0) - 20.0) > 1.6 and absf(fmod(z + 7000.0, 34.0) - 17.0) > 1.4:
				var y := H(x, z)
				var yaw := rng.randf() * TAU if neighbour_training == "einzelpfahl" else PI / 2.0
				var sc := Vector3(1, sy, 1) if neighbour_training != "einzelpfahl" else Vector3.ONE * rng.randf_range(0.92, 1.06)
				list[rng.randi() % 2].append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(sc), Vector3(x + rng.randf_range(-0.05, 0.05), y, z)))
			x += rs if neighbour_training != "einzelpfahl" else vs
		z += vs if neighbour_training != "einzelpfahl" else rs
	for seed in 2:
		var chunks := {}
		for xf in list[seed]:
			var key := Vector2i(floori(xf.origin.x / 24.0), floori(xf.origin.z / 24.0))
			if not chunks.has(key):
				chunks[key] = []
			chunks[key].append(xf)
		for key in chunks:
			var center := Vector3((key.x + 0.5) * 24.0, 0, (key.y + 0.5) * 24.0)
			center.y = H(center.x, center.z)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = BoxMesh.new()
			mm.instance_count = chunks[key].size()
			for i in chunks[key].size():
				var xf: Transform3D = chunks[key][i]
				xf.origin -= center
				mm.set_instance_transform(i, xf)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.position = center
			mmi.visibility_range_end = 220.0
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world.add_child(mmi)
			neighbour_mm.append({"mmi": mmi, "seed": seed, "g": -1})


func _dress_neighbours() -> void:
	if blocks.is_empty():
		return
	var g: int = blocks[0]["g"]
	for e in neighbour_mm:
		var mmi: MultiMeshInstance3D = e["mmi"]
		if e["g"] != g:
			e["g"] = g
			mmi.multimesh.mesh = _block_mesh(neighbour_owner, neighbour_training, g, e["seed"], 3)
	# neighbours follow the first Block's season (their own health is not simulated)
	for p in ["leaf_state", "leaf_state2"]:
		(neighbour_owner["leaf_mat"] as ShaderMaterial).set_shader_parameter(p, (blocks[0]["leaf_mat"] as ShaderMaterial).get_shader_parameter(p))
	for p in ["berry_col", "berry_state", "berry_state2"]:
		(neighbour_owner["berry_mat"] as ShaderMaterial).set_shader_parameter(p, (blocks[0]["berry_mat"] as ShaderMaterial).get_shader_parameter(p))
	var ls: Vector4 = (blocks[0]["leaf_mat"] as ShaderMaterial).get_shader_parameter("leaf_state")
	(neighbour_owner["leaf_mat"] as ShaderMaterial).set_shader_parameter("leaf_state", Vector4(0.0, 0.0, ls.z, ls.w))


func _build_trees() -> void:
	var info = A.json("models/trees.json")
	var cells: Array = info["cellMeters"] if info is Dictionary else [20.0, 20.0, 20.0, 22.0]
	var atlas_img := Image.load_from_file(A.path("models/trees_atlas.png"))
	var fill := []
	var cw := atlas_img.get_width() / 4
	for v in 4:
		var top := atlas_img.get_height()
		for y in range(0, atlas_img.get_height(), 4):
			var hit := false
			for x in range(v * cw, (v + 1) * cw, 6):
				if atlas_img.get_pixel(x, y).a > 0.5:
					hit = true
					break
			if hit:
				top = y
				break
		fill.append(1.0 - float(top) / atlas_img.get_height())
	atlas_img.generate_mipmaps()
	var sm := ShaderMaterial.new()
	sm.shader = load(SH + "tree.gdshader")
	sm.set_shader_parameter("atlas", ImageTexture.create_from_image(atlas_img))
	var mesh: Mesh = A.first_mesh("models/tree_card.glb").duplicate()
	mesh.surface_set_material(0, sm)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var xfs := []
	var custom := []
	var step := 9.0
	var fn: int = far_grid["n"]
	var fstep: float = far_grid["step"]
	var ext: float = far_grid["ext"]
	var fcols: PackedColorArray = far_grid["c"]
	var z := -1600.0
	while z < 1800.0:
		var x := -1800.0
		while x < 1800.0:
			var px := x + rng.randf_range(-4, 4)
			var pz := z + rng.randf_range(-4, 4)
			x += step
			var dx := maxf(maxf(band_x0 - px, px - band_x1), 0.0)
			var dz := maxf(absf(pz) - hz, 0.0)
			if sqrt(dx * dx + dz * dz) < 70.0:
				continue
			var gi := clampi(int(roundf((pz + ext) / fstep)), 0, fn - 1) * fn + clampi(int(roundf((px + ext) / fstep)), 0, fn - 1)
			var c: Color = fcols[gi]
			var y := H(px, pz)
			var is_forest := c.a < 0.5 and c.g < 0.075 and c.r < 0.06
			if not is_forest or noise.get_noise_2d(px * 0.9, pz * 0.9) < -0.35:
				continue
			if region == "napa" and rng.randf() < 0.55:
				continue
			var v := 3 if rng.randf() < (0.35 if region == "napa" and y > 320.0 else 0.18) else rng.randi() % 3
			var hgt := rng.randf_range(15, 25) if v != 3 else rng.randf_range(18, 28)
			if region == "napa" and y < 320.0:
				hgt *= 0.6
			var sc := hgt / maxf(0.2, float(fill[v]))
			xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(px, y - 0.6, pz)))
			custom.append(Color(v, rng.randf(), 0, 0))
		z += step
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_custom_data(i, custom[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mmi)


# =============================================================================================== weather & sun
func _sun_world(elev_deg: float, az_deg: float) -> Vector3:
	# direction towards the sun, in the local frame (+Z = the way the slope faces = azimuth `aspect`)
	var el := deg_to_rad(elev_deg)
	var rel := deg_to_rad(az_deg - aspect)
	return Vector3(-sin(rel) * cos(el), sin(el), cos(rel) * cos(el)).normalized()


func _solar(doy: int, hour: float) -> Vector2:
	var decl := deg_to_rad(-23.44 * cos(TAU / 365.0 * (doy + 10)))
	var phi := deg_to_rad(lat)
	var ha := deg_to_rad(15.0 * (hour - 12.0))
	var el := asin(sin(phi) * sin(decl) + cos(phi) * cos(decl) * cos(ha))
	var az := atan2(sin(ha), cos(ha) * sin(phi) - tan(decl) * cos(phi)) + PI
	return Vector2(rad_to_deg(el), rad_to_deg(az))


func _apply_weather() -> void:
	var doy := _doy(String(D.get("date", "2000-06-01")))
	var today: Dictionary = D.get("weather", {}).get("today", {})
	var icon := String(today.get("icon", "sun"))
	var rain_mm := _num(today, "rain")
	var wind := _num(today, "wind", 10.0)
	# afternoon light: a little earlier in winter so the sun stays above the hills
	var summer := 0.5 - 0.5 * cos(TAU * (doy - 10) / 365.0)
	var hour := 15.0 + 1.5 * summer
	var sp := _solar(doy, hour)
	while sp.x < 9.0 and hour > 12.5:
		hour -= 0.5
		sp = _solar(doy, hour)
	var cloud: float = {"sun": 0.08, "cloud": 0.7, "rain": 1.0, "fog": 0.55}.get(icon, 0.3)
	var rain := clampf(rain_mm / 12.0, 0.25, 1.0) if icon == "rain" else 0.0
	var wet := 1.0 if icon == "rain" else (0.35 if icon == "fog" else 0.0)
	var mist := 1.0 if icon == "fog" else 0.0
	var sky: String = {"sun": "hdri/clear.hdr", "cloud": "hdri/overcast.hdr", "rain": "hdri/overcast.hdr", "fog": "hdri/misty.hdr"}.get(icon, "hdri/clear.hdr")
	if icon == "sun" and sp.x < 16.0:
		sky = "hdri/dusk.hdr"
	var d := _sun_world(sp.x, sp.y)
	sun.look_at_from_position(Vector3.ZERO, -d, Vector3.UP)
	var low := 1.0 - smoothstep(4.0, 28.0, sp.x)
	sun.light_color = Color(1.0, 0.9, 0.78).lerp(Color(1.0, 0.62, 0.36), low * 0.75)
	sun.light_energy = 2.4 * (1.0 - 0.86 * cloud) * (1.0 - 0.15 * low)
	sun.shadow_opacity = 1.0 - 0.7 * cloud
	if sky != current_sky:
		current_sky = sky
		sky_mat.set_shader_parameter("pano_a", _sky_entry(sky)[0])
		sky_mat.set_shader_parameter("blend", 0.0)
	sky_mat.set_shader_parameter("rot_a", _sky_rot(_sky_entry(sky), d))
	var sky_e := lerpf(1.1, 0.75, cloud) * lerpf(1.0, 0.85, low)
	sky_mat.set_shader_parameter("energy_a", sky_e)
	env.ambient_light_energy = lerpf(0.8, 1.0, cloud)
	env.tonemap_exposure = lerpf(1.0, 1.12, cloud)
	env.fog_density = lerpf(0.00013, 0.0011, maxf(mist, rain * 0.5))
	env.fog_light_color = Color(0.70, 0.76, 0.86).lerp(Color(0.74, 0.76, 0.79), cloud).lerp(Color(1.0, 0.72, 0.52), low * (1.0 - cloud) * 0.7)
	env.fog_sun_scatter = lerpf(0.08, 0.35, low) * (1.0 - cloud)
	env.fog_aerial_perspective = lerpf(0.55, 0.15, cloud)
	env.fog_sky_affect = lerpf(0.0, 0.5, cloud)
	var valley := river_y + 22.0 if river.x < INF else -hz * sv - 40.0
	env.fog_height = valley
	env.fog_height_density = 0.3 * mist
	var vol := maxf(mist * 0.008, rain * 0.0025)
	env.volumetric_fog_enabled = vol > 0.0005
	env.volumetric_fog_density = vol
	env.volumetric_fog_albedo = Color(0.95, 0.93, 0.9).lerp(Color(0.8, 0.82, 0.85), cloud)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 140.0
	env.volumetric_fog_detail_spread = 1.5
	env.volumetric_fog_ambient_inject = lerpf(0.25, 0.1, cloud)
	mist_mat.set_shader_parameter("amount", mist if river.x < INF else 0.0)
	mist_node.position = Vector3(0, valley, river.x if river.x < INF else 300.0)
	mist_mat.set_shader_parameter("lit_color", Vector3(1.0, 0.95, 0.9).lerp(Vector3(1.0, 0.82, 0.7), low))
	rain_node.emitting = rain > 0.02
	rain_node.visible = rain > 0.02
	splash_node.visible = rain > 0.02
	rain_hf.visible = rain > 0.02
	rain_node.amount_ratio = rain
	RenderingServer.global_shader_parameter_set("wetness", wet)
	RenderingServer.global_shader_parameter_set("rain_amount", rain)
	RenderingServer.global_shader_parameter_set("wind_strength", clampf(wind / 14.0, 0.4, 2.4) * lerpf(1.0, 0.5, mist))
	for k in ["vine_wood", "vine_bark", "grass", "post"]:
		var m = mats.get(k)
		if m is StandardMaterial3D:
			var base_r: float = {"vine_wood": 0.9, "vine_bark": 0.92, "grass": 0.8, "post": 0.95}[k]
			m.roughness = lerpf(base_r, 0.3, wet)
			if not m.has_meta("base_col"):
				m.set_meta("base_col", m.albedo_color)
			m.albedo_color = (m.get_meta("base_col") as Color).darkened(0.35 * wet)
	var st = mats.get("stone")
	if st is StandardMaterial3D:
		if not st.has_meta("base_r"):
			st.set_meta("base_r", st.roughness)
		st.roughness = lerpf(float(st.get_meta("base_r")), 0.12, wet)
	hud = "%s · %.0f–%.0f °C · %s" % [icon.capitalize(), _num(today, "tmin"), _num(today, "tmax"), ("%.1f mm" % rain_mm) if rain_mm > 0.05 else "dry"]


func _build_rain() -> void:
	splash_node = GPUParticles3D.new()
	splash_node.amount = 12000
	splash_node.lifetime = 0.35
	splash_node.emitting = false
	splash_node.local_coords = false
	var spm := ParticleProcessMaterial.new()
	spm.direction = Vector3(0, 1, 0)
	spm.spread = 70.0
	spm.initial_velocity_min = 0.6
	spm.initial_velocity_max = 1.5
	spm.gravity = Vector3(0, -9.8, 0)
	spm.scale_min = 0.5
	spm.scale_max = 1.0
	splash_node.process_material = spm
	var sq := QuadMesh.new()
	sq.size = Vector2(0.018, 0.018)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smat.billboard_keep_scale = true
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(0.8, 0.84, 0.88, 0.5)
	sq.material = smat
	splash_node.draw_pass_1 = sq
	add_child(splash_node)
	rain_node = GPUParticles3D.new()
	rain_node.amount = 70000
	rain_node.lifetime = 2.4
	rain_node.preprocess = 2.4
	rain_node.local_coords = false
	rain_node.visibility_aabb = AABB(Vector3(-40, -60, -40), Vector3(80, 80, 80))
	var rm := ParticleProcessMaterial.new()
	rm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rm.emission_box_extents = Vector3(24, 1, 24)
	rm.direction = Vector3(0.12, -1, 0.05)
	rm.spread = 3.0
	rm.initial_velocity_min = 8.5
	rm.initial_velocity_max = 10.5
	rm.gravity = Vector3(0, -9.8, 0)
	rm.particle_flag_align_y = true
	rm.scale_min = 0.7
	rm.scale_max = 1.3
	rm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	rm.collision_use_scale = true
	rm.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
	rm.sub_emitter_amount_at_collision = 1
	rain_node.process_material = rm
	var q := QuadMesh.new()
	q.size = Vector2(0.014, 0.65)
	var rd := StandardMaterial3D.new()
	rd.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rd.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	rd.billboard_keep_scale = true
	rd.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.45, Color(1, 1, 1, 1))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	rd.albedo_texture = gt
	rd.albedo_color = Color(0.78, 0.82, 0.86, 0.42)
	q.material = rd
	rain_node.draw_pass_1 = q
	rain_node.emitting = false
	add_child(rain_node)
	rain_node.sub_emitter = rain_node.get_path_to(splash_node)
	# drops stop on the canopy/ground: the heightfield re-renders the scene around the camera, so it only
	# exists while it rains
	rain_hf = GPUParticlesCollisionHeightField3D.new()
	rain_hf.size = Vector3(64, 70, 64)
	rain_hf.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_1024
	rain_hf.follow_camera_enabled = true
	rain_hf.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_ALWAYS
	rain_hf.visible = false
	add_child(rain_hf)


func _build_mist_layer() -> void:
	var nt := NoiseTexture2D.new()
	nt.width = 512; nt.height = 512; nt.seamless = true; nt.generate_mipmaps = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.012
	fn.fractal_octaves = 4
	nt.noise = fn
	mist_mat = ShaderMaterial.new()
	mist_mat.shader = load(SH + "mist_layer.gdshader")
	mist_mat.set_shader_parameter("noise_tex", nt)
	mist_node = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000, 3200)
	mist_node.mesh = pm
	mist_node.material_override = mist_mat
	mist_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mist_node)


func _process(_delta: float) -> void:
	if rain_node and cam:
		rain_node.global_position = cam.global_position + Vector3(0, 18, 0)


# =============================================================================================== camera & HUD
func block_center(i: int) -> Vector3:
	if blocks.is_empty():
		return Vector3.ZERO
	var blk: Dictionary = blocks[clampi(i, 0, blocks.size() - 1)]
	var c: Vector3 = blk["center"]
	return Vector3(c.x, H(c.x, c.z), c.z)


## Named camera presets: "walk" (default entry), "row", "close", "overview", "valley". Optional Block index.
func camera_preset(name: String, bi := 0) -> Array:
	var blk: Dictionary = blocks[clampi(bi, 0, blocks.size() - 1)] if blocks.size() > 0 else {"x0": -5.0, "x1": 5.0, "vsp": false}
	var cx: float = (blk["x0"] + blk["x1"]) / 2.0
	var pos := Vector3.ZERO
	var tgt := Vector3.ZERO
	match name:
		"row":
			var f: Vector2 = blk.get("focus", Vector2(cx, 0.0))
			var u := _row_dir(blk) if blk.get("vsp", false) else Vector2(0, 1)
			var wv := Vector2(-u.y, u.x)
			var sp := _spacing(blk)
			var sd := sun.global_transform.basis.z          # points towards the sun
			var look := -u if Vector2(sd.x, sd.z).dot(-u) < 0.0 else u
			if sv >= 0.3:                                    # steep: along the rows up the hill (VSP) or across the slope
				look = Vector2(0, -1) if blk.get("vsp", false) else Vector2(1.0, 0.42).normalized()
			var alley := f + wv * sp.x * 0.5
			var c := alley - look * minf(hz * 0.8, 22.0)
			if sv >= 0.3 and not blk.get("vsp", false):
				c = Vector2(blk["x0"] + 1.5, -hz * 0.35) + Vector2(sp.x * 0.5, 0.0)
			c.x = clampf(c.x, blk["x0"] + 0.5, blk["x1"] - 0.5)
			c.y = clampf(c.y, -hz + 1.0, hz - 1.0)
			pos = Vector3(c.x, 0, c.y)
			var t := c + look * 25.0
			tgt = Vector3(t.x, 0, t.y)
			pos.y = H(pos.x, pos.z) + EYE
			tgt.y = H(tgt.x, tgt.z) + 0.6
		"close":
			var f: Vector2 = blk.get("focus", Vector2(cx, 0.0))
			if blk.get("vsp", false):
				var u := _row_dir(blk)
				var wv := Vector2(-u.y, u.x)
				var sp := _spacing(blk)
				var c := f + wv * (sp.x * 0.5) + u * 0.9          # stand in the alley, a step along the row
				pos = Vector3(c.x, 0, c.y)
				tgt = Vector3(f.x, 0, f.y)
			else:
				pos = Vector3(f.x + 0.3, 0, f.y + 0.95)          # crouched on the path below the Block
				tgt = Vector3(f.x - 0.05, 0, f.y)
			pos.y = H(pos.x, pos.z) + (1.3 if blk.get("vsp", false) else 1.0)
			tgt.y = H(tgt.x, tgt.z) + (0.85 if blk.get("vsp", false) else 0.75)
		"overview":
			pos = Vector3(band_x0 - 18.0, 0, hz + 40.0)
			pos.y = H(pos.x, pos.z) + 26.0 + hz * sv * 0.3
			tgt = Vector3((band_x0 + band_x1) * 0.25, 0, -hz * 0.3)
			tgt.y = H(tgt.x, tgt.z)
		"valley":
			pos = Vector3(cx, 0, -hz + 1.5)
			pos.y = H(pos.x, pos.z) + EYE
			tgt = Vector3(cx + 40.0, 0, 380.0)
			tgt.y = H(tgt.x, tgt.z) + 20.0
		_:   # walk: at the bottom corner of the first Block, looking up across the vineyard
			pos = Vector3(band_x0 + 2.0, 0, hz + 3.0)
			pos.y = H(pos.x, pos.z) + EYE
			tgt = Vector3((band_x0 + band_x1) * 0.5, 0, -hz * 0.5)
			tgt.y = H(tgt.x, tgt.z) + 2.0
	return [pos, tgt]


func constrain(p: Vector3) -> Vector3:
	p.x = clampf(p.x, band_x0 - 100.0, band_x1 + 100.0)
	p.z = clampf(p.z, -hz - 100.0, hz + 100.0)
	p.y = H(p.x, p.z) + EYE
	return p


func _update_hud() -> void:
	pass


func hud_text(pos: Vector3) -> String:
	var blk := _block_at(pos.x) if absf(pos.z) < hz else {}
	var s := "%s · %s" % [D.get("plot", {}).get("name", ""), D.get("dateLabel", "")]
	if not blk.is_empty():
		for b in D.get("blocks", []):
			if b.get("id", "") == blk["id"]:
				s += "\nBlock %s — %s · %s · %s · %s" % [b.get("id", ""), b.get("name", ""), b.get("variety", ""), b.get("training", ""), _stage_label(String(b.get("stage", "")))]
				if b.get("must") is Dictionary:
					var units := String(D.get("region", {}).get("units", "oe"))
					var m: Dictionary = b["must"]
					s += (" · %.1f °Bx" % _num(m, "brix")) if units == "brix" else (" · %d °Oe" % int(_num(m, "oe")))
	return s + "\n" + hud


static func _stage_label(st: String) -> String:
	return {"FruitSet": "Fruit set", "BunchClosure": "Bunch closure", "Veraison": "Véraison", "LeafFall": "Leaf fall"}.get(st, st)
