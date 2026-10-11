# 3D vineyard bound to the simulation. Rebuilds the landscape when the Plot changes; on every snapshot it
# re-dresses each Block's vines (growth stage, bunch colour, disease/stress cues), the weather and the sun.
# It only *shows* the snapshot: every number comes from the sim (ADR 0001).
#
# Local frame: +Z runs down the fall line (the direction the Plot faces), +X across the slope, Y up.
# The sun is rotated into this frame from the Plot's aspect, so a south-facing slope gets the southern sun.
#
# The Estate's winery stands on a levelled pad at the edge of the Plot (steep Mosel: at the foot of the slope by
# the river road; elsewhere beside the Plot), joined to the Blocks by a farm track (_layout_estate). The terrain
# carries a collision mesh (with a hole under the building) so the player can walk everywhere.
extends Node3D

const A := preload("res://src/view3d/assets3d.gd")
const SH := "res://src/view3d/shaders/"
const EYE := 1.7
const LEAF_CELL := {"Riesling": 0, "Chardonnay": 1, "Pinot Noir": 2, "Cabernet Sauvignon": 3}   # leaf atlas cells
const CHUNK := 12.0           # scatter / trellis cells
const VCHUNK_NEAR := 3.0      # vine cells for the near LODs (visibility ranges are per cell centre, so keep them small)
const VCHUNK_FAR := 18.0      # vine cells for the far LOD
const LOD0_END := 3.0
const LOD1_END := 13.0
const HYBRID_LOD0 := true     # near vines: LOD0 bunches on LOD1 leaves/wood (see _vine_surfaces)
const SHADOW_END := 38.0      # beyond this the far LOD stops casting shadows
const OUT_SHADOW := 70.0      # sun shadow distance outdoors
const PZ0 := -2600.0          # profile start (z) and step
const PSTEP := 1.0
const PN := 5600
const ASPECTS := {"N": 0.0, "NNE": 22.5, "NE": 45.0, "ENE": 67.5, "E": 90.0, "ESE": 112.5, "SE": 135.0, "SSE": 157.5,
	"S": 180.0, "SSW": 202.5, "SW": 225.0, "WSW": 247.5, "W": 270.0, "WNW": 292.5, "NW": 315.0, "NNW": 337.5}
const TRAINING_FILE := {"Einzelpfahl": "einzelpfahl", "Guyot": "guyot", "Cordon": "cordon"}

var cam: Camera3D                 # the player's camera (set by view3d)
var outside_attributes: CameraAttributesPractical
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

# estate: winery pad, yard and farm track (see _layout_estate)
var pad_blend := 9.0              # banks round the levelled pad: longer on sloping ground so they stay walkable
var estate := {}                  # origin (building frame in this node's frame), building/cellar/yard rects, door
var pad_on := false
var pad_y := 0.0
var pad_rect := Rect2()
var bld_rect := Rect2()           # building exterior footprint (terrain has a hole here)
var cellar_rect := Rect2()
var keepout := Rect2()            # no neighbour vines, trees or tufts
var gravel_rect := Rect2()
var track: Array = []             # farm track centre line: [Vector4(x0, z0, x1, z1)]
var outdoors := true

# weather
var rain_node: GPUParticles3D
var splash_node: GPUParticles3D
var rain_hf: GPUParticlesCollisionHeightField3D
var mist_mat: ShaderMaterial
var mist_node: MeshInstance3D
var weather := {}                 # for the ambience: rain 0..1, wind km/h, mist, cloud, day of year
var daytime := -1.0               # hours; < 0 = the afternoon rule (default_hour)
var sky_target := {}              # the day's cloud, darkness and haze the sky blends towards
var sky_now := {}
var blend_weather := false        # the time-lapse blends the weather from day to day; otherwise it snaps
var wind_vec := Vector2.ZERO      # cloud drift
var cloud_uv := Vector2.ZERO
var day_doy := 172
var weather_cloud := 0.3
var weather_mist := 0.0
var weather_rain := 0.0
var sky_pushed := {}              # the sky uniforms last sent (see _apply_light)
var sun_elev := 30.0              # degrees, for the winery's night lights and the HUD
signal light_changed(sun_elev: float)
var hud := ""


func _ready() -> void:
	noise.seed = 7
	noise.frequency = 1.0 / 80.0
	noise.fractal_octaves = 3
	_ensure_globals()
	_setup_environment()
	_setup_sun()
	outside_attributes = CameraAttributesPractical.new()
	outside_attributes.auto_exposure_enabled = false
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
	RenderingServer.global_shader_parameter_add("wind_dir", RenderingServer.GLOBAL_VAR_TYPE_VEC2, Vector2(0.8, 0.6))
	RenderingServer.global_shader_parameter_add("grass_tint", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0.56, 0.84, 0.40))


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
		s += "%s:%s:%s:%s:%s;" % [b.get("id", ""), b.get("training", ""), b.get("density", 0), b.get("area", 0), b.get("rows", "")]
	return s


func _num(d: Dictionary, k: String, def := 0.0) -> float:
	var v = d.get(k, def)
	return float(v) if v != null else def


# =============================================================================================== materials
func _mat(name: String) -> Material:
	if mats.has(name):
		return mats[name]
	var m := make_mat(name)
	mats[name] = m
	return m


## A fresh vineyard material by its GLB name (also used by the training-system model in the learn cards).
static func make_mat(name: String) -> Material:
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
			sm.set_shader_parameter("leaf_atlas", A.tex("models/leaf_atlas.png"))
			sm.set_shader_parameter("leaf_normal", A.tex("models/leaf_normal.png"))
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
	return m


func _prep(mesh: Mesh) -> Mesh:
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		var nm := String(m.resource_name) if m else ""
		if nm != "":
			mesh.surface_set_material(i, _mat(nm))
	return mesh


## Per-Block vine mesh whose leaf/berry surfaces use that Block's own materials, built from CPU arrays (no GPU
## read-back: see A.glb_surfaces).
func _block_mesh(owner: Dictionary, training: String, g: int, seed: int, lod: int) -> Mesh:
	var key := "%s_%d_%d_%d" % [training, g, seed, lod]
	var cache: Dictionary = owner["meshes"]
	if cache.has(key):
		return cache[key]
	var m := ArrayMesh.new()
	for sf in _vine_surfaces(training, g, seed, lod):
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sf[0])
		var nm := String(sf[1])
		var mat: Material = owner["leaf_mat"] if nm == "vine_leaf" else (owner["berry_mat"] if nm == "vine_berry" else (_mat(nm) if nm != "" else sf[2]))
		m.surface_set_material(m.get_surface_count() - 1, mat)
	cache[key] = m
	return m


## Every growth stage's vine meshes, prepared a few per frame after the world is built (≈ 0.1–0.3 ms each from the
## CPU arrays): a stage change during the time-lapse then swaps meshes that already exist.
var warm_queue := []
func _queue_warm() -> void:
	warm_queue.clear()
	var seen := {}                   # meshes are shared per owner, stage, seed and detail level: queue each once
	for blk in blocks:
		for e in blk["mm"]:
			for g in 5:
				var lod: int = [0, 1, 2, 2, 3][int(e["lod"])]
				var k := "%s|%d|%d|%d" % [blk["id"], g, int(e["seed"]), lod]
				if not seen.has(k):
					seen[k] = true
					warm_queue.append([blk, String(blk["training"]), g, int(e["seed"]), lod])
	for e in neighbour_mm:
		for g in 5:
			var k2 := "nb|%d|%d" % [g, int(e["seed"])]
			if not seen.has(k2):
				seen[k2] = true
				warm_queue.append([neighbour_owner, neighbour_training, g, int(e["seed"]), 3])


## Stage changes swap meshes over the next frames (≤ 2 ms per frame): swapping every vine group at once made the
## engine re-derive thousands of bounds in one 49 ms frame. While the world is first built the swap is immediate.
var swap_queue := []
func _swap(mmi: MultiMeshInstance3D, mesh: Mesh) -> void:
	if not blend_weather:
		if not swap_queue.is_empty():                     # rare: an immediate swap must not be undone by a queued older one
			swap_queue = swap_queue.filter(func(w): return w[0] != mmi)
		mmi.multimesh.mesh = mesh
		return
	swap_queue.append([mmi, mesh])                        # first in, first out: the newest mesh lands last


func _swap_step() -> void:
	var t0 := Time.get_ticks_usec()
	while not swap_queue.is_empty() and Time.get_ticks_usec() - t0 < 2000:
		var w: Array = swap_queue.pop_front()
		if is_instance_valid(w[0]):
			(w[0] as MultiMeshInstance3D).multimesh.mesh = w[1]


func _warm_step() -> void:
	var t0 := Time.get_ticks_usec()
	while not warm_queue.is_empty() and Time.get_ticks_usec() - t0 < 3000:
		var w: Array = warm_queue.pop_back()
		_block_mesh(w[0], w[1], w[2], w[3], w[4])


func _owner_materials(owner: Dictionary) -> void:
	owner["leaf_mat"] = _mat("vine_leaf").duplicate()
	owner["berry_mat"] = _mat("vine_berry").duplicate()
	owner["meshes"] = {}


var _vine_cache := {}
## A vine's surfaces as [[arrays, material name], …]. Near vines (lod 0) combine the LOD0 bunches with the LOD1 leaves
## and wood, which look the same at arm's length (the full LOD0 foliage cost ~3 ms a frame close up).
func _vine_surfaces(training: String, g: int, seed: int, lod: int) -> Array:
	var key := "%s_%d_%d_%d" % [training, g, seed, lod]
	if _vine_cache.has(key):
		return _vine_cache[key]
	var d := A.glb_surfaces("models/vine_%s_g%d.glb" % [training, g])
	var out: Array = d.get("s%d_lod%d" % [seed, lod], [])
	if lod == 0 and HYBRID_LOD0 and d.has("s%d_lod1" % seed):
		var mix := []
		for sf in out:
			if String(sf[1]) == "vine_berry":
				mix.append(sf)
		for sf in d["s%d_lod1" % seed]:
			if String(sf[1]) != "vine_berry":
				mix.append(sf)
		out = mix
	_vine_cache[key] = out
	return out


# =============================================================================================== environment
func _setup_environment() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load(SH + "sky.gdshader")
	sky_mat.set_shader_parameter("radiance_clamp", 3.0)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL   # the radiance follows the moving sun over a few frames
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
	sun.directional_shadow_max_distance = OUT_SHADOW
	sun.directional_shadow_split_1 = 0.05
	sun.directional_shadow_split_2 = 0.15
	sun.directional_shadow_split_3 = 0.4
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.0
	sun.light_volumetric_fog_energy = 1.6


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
			down = [[0.0, sv], [fd, sv], [fd + 10.0, 0.004], [fd + 195.0, 0.004], [fd + 220.0, -0.5], [fd + 440.0, -0.45], [fd + 510.0, -0.02]]
			river = Vector2(hz + fd + 44.0, hz + fd + 170.0)      # valley floor: winery, yard, river road, river
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
	if prof.size() < 2: return 0.0   # world not built yet (a camera can ask before the first snapshot)
	var f := (z - PZ0) / PSTEP
	var i := clampi(int(f), 0, PN - 2)
	var t := clampf(f - i, 0.0, 1.0)
	return prof[i] * (1.0 - t) + prof[i + 1] * t


func _delta(x: float) -> float:
	if block_delta.is_empty(): return 0.0
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
	if pad_on:
		var d := _rect_dist(pad_rect, x, z)
		if d < pad_blend:
			y = lerpf(y, pad_y, 1.0 - smoothstep(0.0, pad_blend, d))
		y = maxf(y, pad_y + 0.35 - 0.6 * _rect_dist(cellar_rect, x, z))    # keep the vaulted cellar under ground
	if river.x < INF and z > river.x - 12.0 and z < river.y + 12.0:
		var t := minf(smoothstep(river.x - 12.0, river.x + 4.0, z), smoothstep(river.y + 12.0, river.y - 4.0, z))
		y = lerpf(y, river_y - 1.5, t)
	return y


static func _rect_dist(r: Rect2, x: float, z: float) -> float:
	var dx := maxf(maxf(r.position.x - x, x - r.end.x), 0.0)
	var dz := maxf(maxf(r.position.y - z, z - r.end.y), 0.0)
	return sqrt(dx * dx + dz * dz)


## Distance to the farm track's centre line.
func track_dist(x: float, z: float) -> float:
	var best := INF
	var p := Vector2(x, z)
	for sg in track:
		var a := Vector2(sg.x, sg.y)
		var ba := Vector2(sg.z, sg.w) - a
		var h := clampf((p - a).dot(ba) / maxf(ba.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, (p - a - ba * h).length())
	return best


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
	aspect = _num(p, "aspectDeg", _aspect_deg(String(p.get("aspect", "S"))))
	lat = _num(p, "lat", 49.9)
	_layout_blocks()
	pad_on = false
	_build_profile()
	_layout_estate()
	var t0 := Time.get_ticks_msec()
	_build_terrain()
	var t1 := Time.get_ticks_msec()
	_build_far()
	var t2 := Time.get_ticks_msec()
	_build_vines()
	var t3 := Time.get_ticks_msec()
	_build_scatter()
	_build_groundcover()
	grass_chunks.clear()                    # the old chunks went with the old world node
	grass_job = {}
	grass_centre = Vector2i(99999, 99999)
	_build_neighbours()
	_queue_warm()
	_build_near_trees()
	_build_trees()
	if river.x < INF:
		_build_river()
	print("view3d vineyard: %s terrain %d ms, far %d ms, vines %d ms, rest %d ms" % [p.get("id", ""), t1 - t0, t2 - t1, t3 - t2, Time.get_ticks_msec() - t3])


## Where the winery stands: at the foot of steep Mosel slopes by the river road (the cellar runs into the hill),
## otherwise beside the Plot with its door towards the Blocks. A farm track joins the yard to the Blocks.
func _layout_estate() -> void:
	var lay = A.json("models/winery.json")
	var bi: Dictionary = lay.get("building", {}) if lay is Dictionary else {}
	var ext: Array = bi.get("extent", [-12.3, 12.3, -7.3, 7.3])
	var cex: Array = bi.get("cellarExtent", [-14.2, -7.3, -31.3, -8.6])
	var steep := region == "mosel" and sv >= 0.3
	var fd := clampf(sv * 70.0, 6.0, 55.0)
	var c := Vector2(band_x0 + 4.0, hz + fd + 15.0) if steep else Vector2(band_x0 - 10.0 - float(ext[1]), 0.0)
	var door := Vector2(c.x + float(ext[1]), c.y)
	pad_on = false
	pad_y = H(c.x, c.y)
	pad_blend = 9.0 if steep else clampf(9.0 + sv * 60.0, 9.0, 30.0)
	bld_rect = Rect2(c.x + float(ext[0]), c.y + float(ext[2]), float(ext[1]) - float(ext[0]), float(ext[3]) - float(ext[2]))
	cellar_rect = Rect2(c.x + float(cex[0]), c.y + float(cex[2]), float(cex[1]) - float(cex[0]), float(cex[3]) - float(cex[2]))
	var yard := Rect2(door.x, c.y - 9.0, 11.0 if steep else 9.0, 18.0)
	if steep and river.x < INF:                 # the yard runs down to the river road
		yard = Rect2(door.x, c.y - 9.0, 11.0, maxf(18.0, river.x - 14.0 - (c.y - 9.0)))
	pad_rect = bld_rect.grow(3.0).merge(yard)
	gravel_rect = bld_rect.grow(1.5).merge(yard)
	keepout = bld_rect.merge(cellar_rect).merge(yard).grow(4.0)
	track.clear()
	if steep:
		var mid := Vector2(minf(band_x0 + 60.0, band_x1 - 6.0), hz + fd * 0.5)
		var top := Vector2(band_x0 + 24.0, hz + 1.3)
		track = [Vector4(door.x + 6.0, c.y, mid.x, mid.y), Vector4(mid.x, mid.y, top.x, top.y),
			Vector4(band_x0 - 1.0, hz + 1.3, band_x1 + 1.0, hz + 1.3)]
	else:
		var x := band_x0 - 3.0
		track = [Vector4(door.x + 2.0, c.y, x, c.y), Vector4(x, -hz - 3.0, x, hz + 3.0)]
	estate = {"origin": Vector3(c.x, pad_y + 0.03, c.y), "door": door, "steep": steep}
	pad_on = true


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
			"training": TRAINING_FILE.get(tr, "guyot"), "vsp": tr != "Einzelpfahl", "density": _num(b, "density", 5000.0), "rows": String(b.get("rows", "")),
			"stones": _num(b.get("soilProfile", {}), "stones", 20.0), "mm": [], "g": -1})
		_owner_materials(blocks[-1])
		if not LEAF_CELL.has(String(b.get("variety", ""))):
			push_warning("view3d: no leaf drawing for Variety '%s'; using Riesling's" % b.get("variety", ""))
		(blocks[-1]["leaf_mat"] as ShaderMaterial).set_shader_parameter("variety_cell", int(LEAF_CELL.get(String(b.get("variety", "")), 0)))
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
	var segs := []
	for sg in track:
		segs.append(sg)
	while segs.size() < 8:
		segs.append(Vector4.ZERO)
	sm.set_shader_parameter("track_seg", segs)
	sm.set_shader_parameter("track_n", mini(track.size(), 8))
	sm.set_shader_parameter("yard_rect", Vector4(gravel_rect.position.x, gravel_rect.position.y, gravel_rect.end.x, gravel_rect.end.y))
	sm.set_shader_parameter("road_z", Vector2(river.x - 14.0, river.x - 6.0) if river.x < INF else Vector2.ZERO)
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
	# collision: the same triangles inside the walkable area
	var wr := walk_rect()
	var faces := PackedVector3Array()
	faces.resize((nx - 1) * (nz - 1) * 6)
	var fk := 0
	var hole := bld_rect
	for iz in nz - 1:
		var z := z0 + iz * step
		for ix in nx - 1:
			var x := x0 + ix * step
			# the building has its own floor: drop quads that lie completely inside its footprint
			if hole.has_point(Vector2(x, z)) and hole.has_point(Vector2(x + step, z + step)):
				continue
			var a := iz * nx + ix
			idx[k] = a; idx[k + 1] = a + 1; idx[k + 2] = a + nx
			idx[k + 3] = a + 1; idx[k + 4] = a + nx + 1; idx[k + 5] = a + nx
			k += 6
			if x > wr.position.x - 2.0 and x < wr.end.x + 2.0 and z > wr.position.y - 2.0 and z < wr.end.y + 2.0:
				faces[fk] = verts[a]; faces[fk + 1] = verts[a + 1]; faces[fk + 2] = verts[a + nx]
				faces[fk + 3] = verts[a + 1]; faces[fk + 4] = verts[a + nx + 1]; faces[fk + 5] = verts[a + nx]
				fk += 6
	idx.resize(k)
	faces.resize(fk)
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
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	cs.shape = shape
	body.add_child(cs)
	world.add_child(body)


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
	# rows as planted (snapshot "rows"); older snapshots: the sim's default (down the slope on steep Plots,
	# otherwise north-south)
	var rows := String(blk.get("rows", ""))
	if rows == "":
		rows = "DownSlope" if sv >= 0.3 else "NorthSouth"
	if rows == "DownSlope":
		return Vector2(0, 1)
	var a := deg_to_rad(aspect)
	var north := Vector2(sin(a), cos(a)).normalized()    # world direction of north
	return north if rows == "NorthSouth" else Vector2(-north.y, north.x)


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


## Hides (scales away) every vine instance of a Block, in all its detail levels, whose foot lies within r of one of the
## points (xz, global): the pruning close-up draws the demonstration vine itself, unpruned, and clears the line of sight.
## Returns what restore_vines() needs.
func hide_vines_near(blk_id: String, points: Array, r: float) -> Array:
	var hidden := []
	for blk in blocks:
		if String(blk["id"]) != blk_id:
			continue
		for e in blk["mm"]:
			var mmi: MultiMeshInstance3D = e["mmi"]
			var mm := mmi.multimesh
			for i in mm.instance_count:
				var xf := mm.get_instance_transform(i)
				var g := mmi.global_transform * xf.origin
				for q in points:
					if Vector2(g.x - (q as Vector3).x, g.z - (q as Vector3).z).length() < r:
						hidden.append([mm, i, xf])
						mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), xf.origin))
						break
	return hidden


func restore_vines(hidden: Array) -> void:
	for h in hidden:
		if is_instance_valid(h[0]):
			(h[0] as MultiMesh).set_instance_transform(int(h[1]), h[2])


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
	# no hysteresis margin: with fade disabled, a margin makes a LOD that is currently hidden wait until the
	# camera is `margin` metres inside its range, while the neighbouring LOD already switched off at the exact
	# threshold, so the vines nearest the camera vanished (the "disappearing trellis" bug). Adjacent LODs now
	# share exact thresholds; see view3d_test.gd --trellis.
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
				_swap(e["mmi"], _block_mesh(blk, blk["training"], g, e["seed"], [0, 1, 2, 2, 3][lod]))
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
		var plane := Vector4(0.0, 0.0, 0.0, 0.0)
		if b.get("harvested", false) or st == "Harvested":
			show = 0.0
		elif b.get("picking", false) or st == "Picking":
			# the crew works across the Block row by row: rows on the picked side carry no bunches
			var fr := block_frame(blk)
			var w_front: float = lerpf(fr["wmin"], fr["wmax"], clampf(_num(b, "pickedPct") / 100.0, 0.0, 1.0))
			plane = Vector4(fr["W"].x, fr["W"].y, w_front, 1.0)
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
		var rm := 0.0                       # share of the basal leaves pulled on the morning (east) side
		var ra := 0.0                       # … and on the afternoon (west) side
		if st in ["FruitSet", "BunchClosure", "Veraison", "Ripening", "Picking"]:
			var side := String(b.get("leafSide", "None"))
			rm = 0.9 if side in ["Both", "Morning"] else 0.0
			ra = 0.9 if side in ["Both", "Afternoon"] else 0.0
		var leaf_state := Vector4(clampf(_num(b, "downyLeaf") / 30.0, 0.0, 1.0), clampf(_num(b, "chlorosis") / 100.0, 0.0, 1.0), autumn, drop)
		var leaf_state2 := Vector4(stress, 1.0 if red else 0.0, rm, ra)
		var berry_col := Vector4(ripe.r, ripe.g, ripe.b, t)
		var berry_state := Vector4(show, _num(b, "greyRot") / 100.0, _num(b, "powderyBunch") / 100.0, _num(b, "sunburn") / 100.0)
		var berry_state2 := Vector4(flowering, _num(b, "nobleRot") / 100.0, 1.0 if red else 0.0, 0.0)
		var lm: ShaderMaterial = blk["leaf_mat"]
		var bm: ShaderMaterial = blk["berry_mat"]
		lm.set_shader_parameter("leaf_state", leaf_state)
		lm.set_shader_parameter("leaf_state2", leaf_state2)
		var east := _sun_world(0.0, 90.0)
		lm.set_shader_parameter("east_dir", Vector2(east.x, east.z).normalized())
		bm.set_shader_parameter("berry_col", berry_col)
		bm.set_shader_parameter("berry_state", berry_state)
		bm.set_shader_parameter("berry_state2", berry_state2)
		bm.set_shader_parameter("pick_plane", plane)
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
	RenderingServer.global_shader_parameter_set("grass_tint", tint)
	var g := mats.get("grass") as StandardMaterial3D
	if g:
		g.albedo_color = Color(tint.x * 1.1, tint.y * 1.05, tint.z * 1.4)
	var leafy := doy >= LEAF_SEASON.x and doy <= LEAF_SEASON.y
	for e in near_trees:                            # deciduous near trees stand bare in winter (look only)
		if e["deciduous"]:
			for lod in ["lod0", "lod1"]:
				((e[lod] as Array)[1] as Node3D).visible = leafy
	# and turn yellow-brown in the five weeks before they drop (look only)
	var turn := clampf((doy - (LEAF_SEASON.y - 35)) / 35.0, 0.0, 1.0)
	for kind in NEAR_TREES.get(region, []):
		if not bool(kind[2]):
			continue
		for lod in 2:
			var ms: Array = _near_tree_meshes(int(kind[0]), lod)
			if ms.size() < 2:
				continue
			var lm: Mesh = ms[1]
			for i in lm.get_surface_count():
				var mat := lm.surface_get_material(i) as StandardMaterial3D
				if mat:
					mat.albedo_color = Color(1, 1, 1).lerp(Color(1.55, 0.95, 0.35), turn)
	for plant in groundcover:                       # spring flowers only in their season (look only)
		var win: Vector2i = GC_SEASON.get(plant, Vector2i(0, 366))
		for mmi in groundcover[plant]:
			(mmi as Node3D).visible = doy >= win.x and doy <= win.y
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
	if pad_on and (keepout.has_point(Vector2(x, z)) or track_dist(x, z) < 3.5):
		return false
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
				y -= 25.0 if (x > nx0 + 22.0 and x < nx1 - 22.0 and z > nz0 + 22.0 and z < nz1 - 22.0) else 0.8
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
func _add_chunked(items: Array, mesh: Mesh, vis_end: float, shadow: bool, mat: Material = null) -> Array:
	var out := []
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
		out.append(mmi)
	return out


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
		if gravel_rect.grow(0.5).has_point(Vector2(x, z)) or bld_rect.grow(1.0).has_point(Vector2(x, z)):
			continue
		var td := track_dist(x, z)
		if td > 0.35 and td < 1.25:
			continue
		tufts.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.18, 0.42)), Vector3(x, H(x, z) - 0.02, z)))
	_add_chunked(tufts, gm, 34.0, false)


# Ground cover on the verges and the headlands between Blocks (look only): Poly Haven CC0 scans split into variants and
# decimated by blender/build_groundcover.py. Plants grow in clumps; the flowers show only in spring and summer.
const GC_PLANTS := {
	"mosel": {"dandelion": 3.0, "celandine": 2.0, "fern": 0.8, "dry_branches": 0.4},
	"cote-dor": {"dandelion": 3.0, "celandine": 1.2, "dry_branches": 0.5},
	"napa": {"dandelion": 0.8, "dry_branches": 1.2},
}
const GC_SEASON := {"dandelion": Vector2i(90, 285), "celandine": Vector2i(55, 150)}   # day of year shown (look only)
const GC_CLUMPS := 700           # within GC_RING of the Plot, where the walker goes
const GC_RING := 6.0
const GC_SCALE := {"dandelion": Vector2(1.3, 1.7)}   # the scan is a small rosette; flowering ones stand taller
var groundcover := {}             # plant -> [MultiMeshInstance3D]


func _build_groundcover() -> void:
	groundcover.clear()
	var weights: Dictionary = GC_PLANTS.get(region, GC_PLANTS["cote-dor"])
	var variants := {}
	var total := 0.0
	for plant in weights:
		var rel := "models/gc_%s.glb" % plant
		if not A.exists(rel):
			continue
		variants[plant] = A.glb_meshes(rel)
		total += float(weights[plant])
		for m in (variants[plant] as Dictionary).values():   # scanned leaves read silvery in the sun: matte them
			for i in (m as Mesh).get_surface_count():
				var sm := (m as Mesh).surface_get_material(i) as StandardMaterial3D
				if sm:
					sm.roughness = 1.0
					sm.metallic_specular = 0.25
					sm.roughness_texture = null
	if variants.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var per := {}                  # "plant/variant" -> [Transform3D]
	var clumps := 0
	var tries := 0
	while clumps < GC_CLUMPS and tries < GC_CLUMPS * 40:
		tries += 1
		var x := rng.randf_range(band_x0 - GC_RING, band_x1 + GC_RING)
		var z := rng.randf_range(-hz - GC_RING, hz + GC_RING)
		var inside := x > band_x0 and x < band_x1 and absf(z) < hz - 1.0
		if inside and not _block_at(x).is_empty():
			continue                                     # not between the rows
		var g := 0.9 if inside else _grass_mask_outside(x, z)
		if g < 0.6 or (not inside and _neighbour_planted(x, z)):
			continue
		if gravel_rect.grow(1.0).has_point(Vector2(x, z)) or bld_rect.grow(2.0).has_point(Vector2(x, z)) or keepout.grow(1.0).has_point(Vector2(x, z)):
			continue
		if track_dist(x, z) < 1.4 or (river.x < INF and z > river.x - 6.0 and z < river.y + 2.0):
			continue
		# pick a plant by weight, then a clump of 2–6 of its variants
		var r := rng.randf() * total
		var plant := ""
		for k in variants:
			r -= float(weights[k])
			if r <= 0.0:
				plant = k
				break
		if plant == "":
			plant = variants.keys()[0]
		var names: Array = (variants[plant] as Dictionary).keys()
		clumps += 1
		for i in rng.randi_range(3, 8):
			var px := x + rng.randf_range(-0.7, 0.7)
			var pz := z + rng.randf_range(-0.7, 0.7)
			var vname: String = names[rng.randi() % names.size()]
			var sr: Vector2 = GC_SCALE.get(plant, Vector2(0.8, 1.2))
			var sc := rng.randf_range(sr.x, sr.y)
			var key := "%s/%s" % [plant, vname]
			if not per.has(key):
				per[key] = []
			per[key].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(px, H(px, pz) - 0.01, pz)))
	for key in per:
		var parts := String(key).split("/")
		var mesh: Mesh = variants[parts[0]][parts[1]]
		if not groundcover.has(parts[0]):
			groundcover[parts[0]] = []
		groundcover[parts[0]].append_array(_add_chunked(per[key], mesh, 26.0, false))


# Near trees (look only): trees and shrubs in hedgerow clusters 10–55 m from the Plot, where the far tree cards
# (≥ 70 m) leave the view bare. Poly Haven CC0 scans thinned by blender/build_trees3d.py into a near (lod0) and a mid
# (lod1) model; each tree has its own MeshInstance3Ds with visibility ranges, so the switch happens per tree.
# Napa: wind-sculpted evergreen "coastal" trees (they read like the olive trees kept around Napa wineries); Mosel and
# Côte d'Or: a slender deciduous broadleaf, bare from leaf fall to leaf-out (look only).
const NEAR_TREES := {                # region -> [[model, scale range, deciduous], …]
	"napa": [[1, Vector2(1.5, 2.0), false], [2, Vector2(1.2, 1.6), false], [3, Vector2(1.1, 1.5), false]],
	"mosel": [[4, Vector2(2.2, 2.9), true]],
	"cote-dor": [[4, Vector2(2.2, 2.9), true]],
}
const NEAR_TREE_LOD := 45.0
const LEAF_SEASON := Vector2i(110, 305)   # deciduous leaves shown between these days of the year (look only)
var near_trees := []              # [{pos, lod0: [bark, leaves], lod1: [bark, leaves], deciduous}]


## [bark mesh, leaves mesh] of a near-tree model; leaves get alpha scissor (sorted blending flickers in a canopy).
func _near_tree_meshes(kind: int, lod: int) -> Array:
	var key := "near_tree_%d_%d" % [kind, lod]
	if mats.has(key):
		return mats[key]
	var rel := "models/tree3d_%d_lod%d.glb" % [kind, lod]
	if not A.exists(rel):
		return []
	var root := A.scene(rel)
	var bark := ArrayMesh.new()
	var leaves := ArrayMesh.new()
	for mi in A.meshes(root):
		var m: Mesh = (mi as MeshInstance3D).mesh
		var is_leaf := String(mi.name).ends_with("_leaves")
		for i in m.get_surface_count():
			var mat := m.surface_get_material(i) as StandardMaterial3D
			if mat and is_leaf:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				mat.alpha_scissor_threshold = 0.4
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				mat.roughness = 1.0
			var dst := leaves if is_leaf else bark
			dst.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(i))
			dst.surface_set_material(dst.get_surface_count() - 1, mat)
	root.free()
	mats[key] = [bark, leaves]
	return mats[key]


func _build_near_trees() -> void:
	near_trees.clear()
	var kinds: Array = NEAR_TREES.get(region, NEAR_TREES["cote-dor"])
	if _near_tree_meshes(int(kinds[0][0]), 0).is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var clusters := 5 if region == "napa" else 8
	var placed := []
	var tries := 0
	while placed.size() < clusters * 3 and tries < 4000:
		tries += 1
		var cx := rng.randf_range(band_x0 - 55.0, band_x1 + 55.0)
		var cz := rng.randf_range(-hz - 55.0, hz + 55.0)
		for i in rng.randi_range(2, 4):
			var x := cx + rng.randf_range(-6.0, 6.0)
			var z := cz + rng.randf_range(-6.0, 6.0)
			var dx := maxf(maxf(band_x0 - x, x - band_x1), 0.0)
			var dz := maxf(absf(z) - hz, 0.0)
			var d := sqrt(dx * dx + dz * dz)
			if d < 10.0 or d > 55.0 or _neighbour_planted(x, z) or _grass_mask_outside(x, z) < 0.5:
				continue
			if _rect_dist(keepout, x, z) < 8.0 or bld_rect.grow(8.0).has_point(Vector2(x, z)) or gravel_rect.grow(4.0).has_point(Vector2(x, z)):
				continue
			if track_dist(x, z) < 4.0 or (river.x < INF and z > river.x - 10.0 and z < river.y + 4.0):
				continue
			var near_other := false
			for p in placed:
				if Vector2(p.x, p.z).distance_to(Vector2(x, z)) < 4.5:
					near_other = true
					break
			if near_other:
				continue
			var k: Array = kinds[rng.randi() % kinds.size()]
			var sr: Vector2 = k[1]
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(sr.x, sr.y)), Vector3(x, H(x, z) - 0.05, z))
			var e := {"pos": xf.origin, "deciduous": bool(k[2])}
			for lod in 2:
				var pair := []
				for mesh in _near_tree_meshes(int(k[0]), lod):
					var mi := MeshInstance3D.new()
					mi.mesh = mesh
					mi.transform = xf
					mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
					if lod == 0:
						mi.visibility_range_end = NEAR_TREE_LOD
						mi.visibility_range_end_margin = 4.0
					else:
						mi.visibility_range_begin = NEAR_TREE_LOD
						mi.visibility_range_begin_margin = 4.0
						mi.visibility_range_end = 150.0
						mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # far away: shadows cost more than they show
					mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
					world.add_child(mi)
					pair.append(mi)
				e["lod%d" % lod] = pair
			near_trees.append(e)
			placed.append(xf.origin)


# Grass blades near the camera (look only): 6 m chunks built as the camera approaches (at most two per frame) and freed
# behind it, where the ground is grassed: the alleys of grassed rows, the headlands and the verges (the same rule as
# the grass tufts), none on the tracks, the yard or the neighbours' vines. The blades shrink away by 23 m.
const GRASS_CHUNK := 6.0
const GRASS_RING := 4                   # chunks each side of the camera's chunk
const GRASS_PER_M2 := 26.0
var grass_chunks := {}                  # Vector2i -> MultiMeshInstance3D (or null where no grass grows)
var grass_mesh: ArrayMesh
var grass_mat: ShaderMaterial
var grass_centre := Vector2i(99999, 99999)
var grass_job := {}                     # the chunk being built: {k, rng, i, n, xfs}


func _grass_blades() -> ArrayMesh:
	# three tapered, curved blades in a small clump; UV.y = height along the blade, COLOR = a little hue variation
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for b in 6:
		var yaw := b * TAU / 6.0 + rng.randf_range(-0.4, 0.4)
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var side := Vector3(-dir.z, 0, dir.x)
		var h := rng.randf_range(0.11, 0.22)
		var lean := rng.randf_range(0.03, 0.08)
		var off := side * rng.randf_range(-0.04, 0.04) + dir * rng.randf_range(0.0, 0.03)
		var col := Color(rng.randf_range(0.9, 1.1), rng.randf_range(0.95, 1.05), rng.randf_range(0.85, 1.0))
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for k in 5:
			var t := float(k) / 4.0
			var w := 0.008 * (1.0 - t * 0.92)
			var c := off + Vector3(0, h * t, 0) + dir * lean * t * t
			var l := c - side * w
			var r := c + side * w
			if k > 0:
				var n := side.cross(Vector3.UP).normalized()
				for v in [[prev_l, t - 0.25], [prev_r, t - 0.25], [r, t], [prev_l, t - 0.25], [r, t], [l, t]]:
					st.set_normal(n.lerp(Vector3.UP, 0.6).normalized())
					st.set_color(col)
					st.set_uv(Vector2(0.5, float(v[1])))
					st.add_vertex(v[0])
			prev_l = l
			prev_r = r
	return st.commit()


func _grass_density(x: float, z: float) -> float:
	var inside := x > band_x0 and x < band_x1 and absf(z) < hz - 1.0
	var g := _grass_mask_outside(x, z)
	if inside:
		var blk := _block_at(x)
		if blk.is_empty():
			g = 0.9
		elif blk["vsp"]:
			g = 0.0 if _row_offset(blk, x, z) < 0.45 else 0.6
		else:
			g = 0.04                            # stake-trained steep slopes are bare slate between the vines
	elif _neighbour_planted(x, z):
		g *= 0.3
	if gravel_rect.grow(0.5).has_point(Vector2(x, z)) or bld_rect.grow(1.0).has_point(Vector2(x, z)):
		return 0.0
	var td := track_dist(x, z)
	if td > 0.3 and td < 1.3:
		return 0.0
	if river.x < INF and z > river.x - 2.0 and z < river.y:
		return 0.0
	return g


func _grass_step() -> void:
	if cam == null or world == null:
		return
	if grass_mesh == null:
		grass_mesh = _grass_blades()
		grass_mat = ShaderMaterial.new()
		grass_mat.shader = load(SH + "grass_blade.gdshader")
		grass_mesh.surface_set_material(0, grass_mat)
	var p := cam.global_position
	var above := p.y - H(p.x, p.z)
	if above > 25.0 or above < -0.5:        # drone height, or underground in the cellar: no blades to build
		return
	var c := Vector2i(floori(p.x / GRASS_CHUNK), floori(p.z / GRASS_CHUNK))
	if c != grass_centre:
		grass_centre = c
		for k in grass_chunks.keys():
			if absi(k.x - c.x) > GRASS_RING + 1 or absi(k.y - c.y) > GRASS_RING + 1:
				if grass_chunks[k] is Node:
					(grass_chunks[k] as Node).queue_free()
				grass_chunks.erase(k)
		if not grass_job.is_empty() and (absi(grass_job["k"].x - c.x) > GRASS_RING or absi(grass_job["k"].y - c.y) > GRASS_RING):
			grass_chunks.erase(grass_job["k"])
			grass_job = {}
	# build the nearest missing chunk a slice at a time (≤ 1.2 ms a frame): chunks cost ~1–3 ms each in GDScript
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 1200:
		if grass_job.is_empty():
			var k := _next_grass_chunk(c)
			if k == Vector2i(99999, 99999):
				return
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(k)
			grass_job = {"k": k, "rng": rng, "i": 0, "n": int(GRASS_CHUNK * GRASS_CHUNK * GRASS_PER_M2), "xfs": []}
			grass_chunks[k] = false          # reserved: being built
		_grass_job_slice(t0)


func _next_grass_chunk(c: Vector2i) -> Vector2i:
	for r in GRASS_RING + 1:                # nearest rings first
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var k := Vector2i(c.x + dx, c.y + dz)
				if not grass_chunks.has(k):
					return k
	return Vector2i(99999, 99999)


func _grass_job_slice(t0: int) -> void:
	var j := grass_job
	var k: Vector2i = j["k"]
	var rng: RandomNumberGenerator = j["rng"]
	var x0 := k.x * GRASS_CHUNK
	var z0 := k.y * GRASS_CHUNK
	var xfs: Array = j["xfs"]
	while int(j["i"]) < int(j["n"]):
		j["i"] = int(j["i"]) + 1
		var x := x0 + rng.randf() * GRASS_CHUNK
		var z := z0 + rng.randf() * GRASS_CHUNK
		var keep := rng.randf()
		var s := rng.randf_range(0.7, 1.3)
		var yaw := rng.randf() * TAU
		var sy := rng.randf_range(0.8, 1.2)
		if keep <= _grass_density(x, z):
			xfs.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s * sy, s)), Vector3(x, H(x, z) - 0.01, z)))
		if (int(j["i"]) & 31) == 0 and Time.get_ticks_usec() - t0 >= 1200:
			return
	grass_chunks[k] = _grass_chunk_node(k, xfs)
	grass_job = {}


func _grass_chunk_node(k: Vector2i, xfs: Array) -> Variant:
	if xfs.is_empty():
		return null
	var x0 := k.x * GRASS_CHUNK
	var z0 := k.y * GRASS_CHUNK
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = grass_mesh
	mm.instance_count = xfs.size()
	var centre := Vector3(x0 + GRASS_CHUNK / 2.0, 0, z0 + GRASS_CHUNK / 2.0)
	centre.y = H(centre.x, centre.z)
	for i in xfs.size():
		var xf: Transform3D = xfs[i]
		xf.origin -= centre
		mm.set_instance_transform(i, xf)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.position = centre
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 26.0
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	world.add_child(mi)
	return mi


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
	(neighbour_owner["leaf_mat"] as ShaderMaterial).set_shader_parameter("variety_cell", {"mosel": 0, "cote-dor": 2, "napa": 3}.get(region, 0))
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
			_swap(mmi, _block_mesh(neighbour_owner, neighbour_training, g, e["seed"], 3))
	# neighbours follow the first Block's season (their own health is not simulated)
	for p in ["leaf_state", "leaf_state2"]:
		(neighbour_owner["leaf_mat"] as ShaderMaterial).set_shader_parameter(p, (blocks[0]["leaf_mat"] as ShaderMaterial).get_shader_parameter(p))
	for p in ["berry_col", "berry_state", "berry_state2"]:
		(neighbour_owner["berry_mat"] as ShaderMaterial).set_shader_parameter(p, (blocks[0]["berry_mat"] as ShaderMaterial).get_shader_parameter(p))
	var ls2: Vector4 = (blocks[0]["leaf_mat"] as ShaderMaterial).get_shader_parameter("leaf_state2")
	(neighbour_owner["leaf_mat"] as ShaderMaterial).set_shader_parameter("leaf_state2", Vector4(ls2.x, ls2.y, 0.0, 0.0))   # not your leaf removal
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
			if sqrt(dx * dx + dz * dz) < 70.0 or _rect_dist(keepout, px, pz) < 12.0:
				continue
			if river.x < INF and pz > river.x - 16.0 and pz < river.y + 4.0:
				continue                                   # not in the Moselle or on its road
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


## The hour the static view shows: afternoon light, a little earlier in winter so the sun stays above the hills.
func default_hour(doy: int) -> float:
	var summer := 0.5 - 0.5 * cos(TAU * (doy - 10) / 365.0)
	var hour := 15.0 + 1.5 * summer
	while _solar(doy, hour).x < 9.0 and hour > 12.5:
		hour -= 0.5
	return hour


## Time of day in hours (the time-lapse animates it); < 0 = the afternoon rule of default_hour. Cheap: light only.
func set_daytime(h: float) -> void:
	daytime = h
	_apply_light()


func _apply_weather() -> void:
	var doy := _doy(String(D.get("date", "2000-06-01")))
	var today: Dictionary = D.get("weather", {}).get("today", {})
	var icon := String(today.get("icon", "sun"))
	var rain_mm := _num(today, "rain")
	var wind := _num(today, "wind", 10.0)
	# cloud cover from the day's measured radiation (clear-sky fraction, FAO-56), then the icon's character
	var clear := _num(today, "clear", {"sun": 0.85, "cloud": 0.35, "rain": 0.15, "fog": 0.4}.get(icon, 0.6))
	var cloud := clampf(1.05 - clear, 0.05, 1.0)
	if icon == "rain":
		cloud = maxf(cloud, 0.9)
	var rain := clampf(rain_mm / 12.0, 0.25, 1.0) if icon == "rain" else 0.0
	var wet := 1.0 if icon == "rain" else (0.35 if icon == "fog" else 0.0)
	var mist := 1.0 if icon == "fog" else 0.0
	sky_target = {"cloud": cloud, "dark": clampf((rain_mm - 1.0) / 8.0, 0.0, 0.8) if icon == "rain" else 0.1 * cloud, "haze": maxf(mist * 0.8, rain * 0.3)}
	if sky_now.is_empty() or not blend_weather:
		sky_now = sky_target.duplicate()
	wind_vec = Vector2(cos(float(doy) * 1.7), sin(float(doy) * 1.7)) * clampf(wind / 14.0, 0.3, 3.0)
	if not blend_weather:
		cloud_uv = Vector2(float(doy) * 3.7, float(doy) * 1.3)      # each day its own clouds (the time-lapse keeps drifting them)
	RenderingServer.global_shader_parameter_set("wind_dir", wind_vec.normalized() if wind_vec.length() > 0.01 else Vector2(0.8, 0.6))
	sky_mat.set_shader_parameter("cloud_drift", wind_vec * 0.004)
	day_doy = doy
	weather_cloud = cloud
	weather_mist = mist
	weather_rain = rain
	_apply_light()
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
	rain_level = rain
	_apply_rain_visibility()
	rain_node.amount_ratio = maxf(rain, 0.01)
	weather = {"rain": rain, "wind_kmh": wind, "mist": mist, "cloud": cloud, "doy": doy, "icon": icon}
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


## Sun (or moon), sky, ambient, exposure and fog for the current hour and the day's weather (look only).
func _apply_light() -> void:
	var hour := daytime if daytime >= 0.0 else default_hour(day_doy)
	var sp := _solar(day_doy, hour)
	sun_elev = sp.x
	var d := _sun_world(sp.x, sp.y)
	var cloud: float = sky_now.get("cloud", weather_cloud)
	var low := 1.0 - smoothstep(2.0, 28.0, sp.x)
	var day := smoothstep(-1.0, 4.0, sp.x)             # no light from below the horizon
	var night := 1.0 - smoothstep(-14.0, -3.0, sp.x)
	# key light: the sun by day, a cool moon (opposite azimuth, 35° up) by night; they swap while both are dim
	if sp.x > -4.0:
		var dl := _sun_world(maxf(sp.x, 1.0), sp.y)     # the light itself never comes from under the horizon
		sun.look_at_from_position(Vector3.ZERO, -dl, Vector3.UP)
		sun.light_color = Color(1.0, 0.92, 0.82).lerp(Color(1.0, 0.55, 0.28), low * 0.85)
		sun.light_energy = 2.4 * (1.0 - 0.86 * cloud) * day * (1.0 - 0.25 * low)
	else:
		var m := _sun_world(35.0, fmod(sp.y + 180.0, 360.0))
		sun.look_at_from_position(Vector3.ZERO, -m, Vector3.UP)
		sun.light_color = Color(0.62, 0.70, 0.95)
		sun.light_energy = 0.28 * (1.0 - 0.75 * cloud) * night
	sun.shadow_opacity = 1.0 - 0.7 * cloud
	# sky: every change makes the engine re-render its radiance map (ambient and reflections), so the sky is only
	# updated when it visibly changed, and at most every 6 frames while it blends (updating it every frame of a
	# weather blend cost the time-lapse 20 fps on the day frames)
	var dark: float = sky_now.get("dark", 0.0)
	var haze: float = sky_now.get("haze", 0.0)
	var frame := Engine.get_process_frames()
	var big := sky_pushed.is_empty() or (sky_pushed["d"] as Vector3).angle_to(d) > deg_to_rad(3.0) or absf(float(sky_pushed["c"]) - cloud) > 0.25
	var small := not sky_pushed.is_empty() and ((sky_pushed["d"] as Vector3).angle_to(d) > deg_to_rad(0.25) or absf(float(sky_pushed["c"]) - cloud) > 0.02 \
		or absf(float(sky_pushed["k"]) - dark) > 0.02 or absf(float(sky_pushed["h"]) - haze) > 0.02 or absf(float(sky_pushed["n"]) - night) > 0.01)
	if big or (small and frame - int(sky_pushed.get("f", 0)) >= 6) or not blend_weather:
		sky_pushed = {"d": d, "c": cloud, "k": dark, "h": haze, "n": night, "f": frame}
		sky_mat.set_shader_parameter("sun_dir", d)
		sky_mat.set_shader_parameter("sun_disc_col", Vector3(1.0, 0.93, 0.8).lerp(Vector3(1.0, 0.5, 0.2), low))
		sky_mat.set_shader_parameter("night", night)
		sky_mat.set_shader_parameter("cloud_cover", cloud)
		sky_mat.set_shader_parameter("cloud_dark", dark)
		sky_mat.set_shader_parameter("haze", haze)
		sky_mat.set_shader_parameter("cloud_offset", cloud_uv)
	# ambient and exposure: the sky lights the scene; nights are brought up to a readable blue dark
	env.ambient_light_energy = lerpf(0.8, 1.0, cloud) * lerpf(1.0, 3.0, night)
	env.tonemap_exposure = lerpf(1.0, 1.12, cloud) * lerpf(1.0, 3.6, night)
	env.fog_light_color = Color(0.70, 0.76, 0.86).lerp(Color(0.74, 0.76, 0.79), cloud).lerp(Color(1.0, 0.64, 0.42), low * day * (1.0 - cloud) * 0.8).lerp(Color(0.10, 0.13, 0.22), night)
	env.fog_sun_scatter = lerpf(0.08, 0.45, low) * (1.0 - cloud) * day
	env.fog_aerial_perspective = lerpf(0.55, 0.15, cloud)
	env.fog_sky_affect = lerpf(0.0, 0.5, cloud)
	env.fog_density = lerpf(0.00013, 0.0011, maxf(weather_mist, weather_rain * 0.5))
	if mist_mat:
		mist_mat.set_shader_parameter("lit_color", Vector3(1.0, 0.95, 0.9).lerp(Vector3(1.0, 0.82, 0.7), low).lerp(Vector3(0.25, 0.3, 0.42), night))
	light_changed.emit(sun_elev)


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
	_grass_step()
	if not swap_queue.is_empty():
		_swap_step()
	elif not warm_queue.is_empty():
		_warm_step()
	# the time-lapse blends the weather from one day to the next (~0.6 s); cloud drift runs in the sky shader (TIME)
	var changed := false
	if not sky_target.is_empty():
		for k in sky_target:
			var cur: float = sky_now.get(k, sky_target[k])
			var nv := move_toward(cur, float(sky_target[k]), _delta / 0.6)
			if nv != cur:
				changed = true
			sky_now[k] = nv
	if changed:
		_apply_light()
	if rain_node and cam:
		rain_node.global_position = cam.global_position + Vector3(0, 18, 0)
		var h := cam.global_position.y - H(cam.global_position.x, cam.global_position.z) > 30.0
		if h != high:
			high = h
			_apply_rain_visibility()


## Inside the winery: no rain particles (the roof would stop them anyway) and no rain heightfield pass.
func set_outdoors(on: bool) -> void:
	if on == outdoors:
		return
	outdoors = on
	_apply_rain_visibility()


var rain_level := 0.0
var high := false                 # camera far above the ground (drone): no rain particles around it
func _apply_rain_visibility() -> void:
	var r := rain_level > 0.02 and outdoors and not high
	rain_node.emitting = r
	rain_node.visible = r
	splash_node.visible = r
	rain_hf.visible = r


# =============================================================================================== camera & HUD
## A Block's row frame: U along the rows, W across them (rows at w = k·spacing), the w range of the planted
## rectangle and the rectangle itself. Stake-trained (Einzelpfahl) Blocks: a square grid, "rows" along z.
func block_frame(blk: Dictionary) -> Dictionary:
	var sp := _spacing(blk)
	var u := _row_dir(blk) if blk["vsp"] else Vector2(0, 1)
	var wv := Vector2(-u.y, u.x)
	var r := Rect2(blk["x0"] + 1.2, -hz + 1.2, blk["x1"] - blk["x0"] - 2.4, 2.0 * hz - 2.4)
	var wmin := INF; var wmax := -INF
	for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		wmin = minf(wmin, c.dot(wv)); wmax = maxf(wmax, c.dot(wv))
	return {"U": u, "W": wv, "row": sp.x, "wmin": wmin, "wmax": wmax, "rect": r}


## The part of the line {u·U + w·W} inside the Block's planted rectangle: Vector2(u_min, u_max), or empty (x > y).
func row_span(fr: Dictionary, w: float) -> Vector2:
	var u: Vector2 = fr["U"]
	var wv: Vector2 = fr["W"]
	var r: Rect2 = fr["rect"]
	var o := wv * w
	var lo := -INF
	var hi := INF
	for axis in 2:
		var d := u[axis]
		var a := r.position[axis]
		var b := r.end[axis]
		if absf(d) < 1e-6:
			if o[axis] < a or o[axis] > b:
				return Vector2(1, 0)
			continue
		var t0 := (a - o[axis]) / d
		var t1 := (b - o[axis]) / d
		lo = maxf(lo, minf(t0, t1))
		hi = minf(hi, maxf(t0, t1))
	return Vector2(lo, hi)


func ground_normal(x: float, z: float) -> Vector3:
	return _normal(x, z)


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
		"close", "close_east", "close_west":
			var f: Vector2 = blk.get("focus", Vector2(cx, 0.0))
			if blk.get("vsp", false):
				var u := _row_dir(blk)
				var wv := Vector2(-u.y, u.x)
				var sp := _spacing(blk)
				if name != "close":                           # the alley on the row's east (morning) or west side
					var e := _sun_world(0.0, 90.0)
					var east_side := 1.0 if wv.dot(Vector2(e.x, e.z)) >= 0.0 else -1.0
					wv *= east_side * (1.0 if name == "close_east" else -1.0)
				var c := f + wv * (sp.x * 0.5) + u * 0.9          # stand in the alley, a step along the row
				pos = Vector3(c.x, 0, c.y)
				tgt = Vector3(f.x, 0, f.y)
			else:
				pos = Vector3(f.x + 0.3, 0, f.y + 0.95)          # crouched on the path below the Block
				tgt = Vector3(f.x - 0.05, 0, f.y)
			pos.y = H(pos.x, pos.z) + (1.3 if blk.get("vsp", false) else 1.0)
			tgt.y = H(tgt.x, tgt.z) + (0.85 if blk.get("vsp", false) else 0.75)
			if name != "close":                               # crouched, level with the fruit zone
				pos.y = H(pos.x, pos.z) + 0.75
				tgt.y = H(tgt.x, tgt.z) + 0.7
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
		"estate":   # from the vineyard towards the winery (vines in front, the building beyond)
			var o: Vector3 = estate.get("origin", Vector3.ZERO)
			if estate.get("steep", false):
				pos = Vector3(band_x0 + 34.0, 0, hz - 3.0)
				tgt = Vector3(o.x + 4.0, o.y + 3.0, o.z)
			else:
				pos = Vector3(band_x0 + 9.0, 0, hz * 0.55)
				tgt = Vector3(o.x, o.y + 3.5, o.z)
			pos.y = H(pos.x, pos.z) + EYE + 0.4
		"estate_high":   # raised view over the winery, its yard and track, and the Blocks beyond
			var o: Vector3 = estate.get("origin", Vector3.ZERO)
			if estate.get("steep", false):
				pos = o + Vector3(34.0, 24.0, 30.0)
				tgt = o + Vector3(16.0, 2.0, -34.0)
			else:
				pos = o + Vector3(20.0, 22.0, 44.0)
				tgt = o + Vector3(28.0, 0.0, -12.0)
			pos.y = maxf(pos.y, H(pos.x, pos.z) + 12.0)
		"track":   # on the farm track in the yard, looking at the open hall door
			var o: Vector3 = estate.get("origin", Vector3.ZERO)
			var d: Vector2 = estate.get("door", Vector2(o.x, o.z))
			pos = Vector3(d.x + (13.0 if estate.get("steep", false) else 7.5), 0, o.z + (7.5 if estate.get("steep", false) else 5.5))
			pos.y = H(pos.x, pos.z) + EYE
			tgt = Vector3(d.x - 6.0, o.y + 1.6, o.z - 1.0)
		_:   # walk: at the bottom corner of the first Block, looking up across the vineyard
			pos = Vector3(band_x0 + 2.0, 0, hz + 3.0)
			pos.y = H(pos.x, pos.z) + EYE
			tgt = Vector3((band_x0 + band_x1) * 0.5, 0, -hz * 0.5)
			tgt.y = H(tgt.x, tgt.z) + 2.0
	return [pos, tgt]


## The walkable area (x, z): 100 m round the Plot, and not into the Moselle.
func walk_rect() -> Rect2:
	var z1 := hz + 100.0
	if river.x < INF:
		z1 = minf(z1, river.x - 3.0)
	return Rect2(band_x0 - 100.0, -hz - 100.0, band_x1 - band_x0 + 200.0, z1 + hz + 100.0)


func building_origin() -> Vector3:
	return estate.get("origin", Vector3.ZERO)


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
