# PROTOTYPE — engine demo, Godot half. Builds the whole scene at runtime from ../assets
# (copied into res://assets by sync_assets.sh). Follows the shared spec in ../README.md.
extends Node3D

const EYE := 1.7
const LOD_DIST := 20.0
const WALK := 1.6
const RUN := 4.5
const PRESETS := ["row_downhill", "uphill", "valley_view", "drone", "vine_close"]
# HDRI baked-in sun (measured by blender/hdri_sun.py): equirect u from the left edge
const HDRI_SUN_U := 0.6002

var layout: Dictionary
var near: Dictionary
var heights: PackedFloat32Array
var cam: Camera3D
var fps_label: Label
var yaw := 0.0
var pitch := 0.0
var walking := false

var vine_items: Array
var vine_xf: Array[Transform3D] = []
var vine_mmi := {}
var last_bucket := Vector3(INF, INF, INF)
var mats := {}
var texcache := {}

# capture mode
var shot_mode := false
var sun_check := false
var shot_idx := 0
var phase := ""
var frames := 0
var times := PackedFloat32Array()
var perf := {}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shot_mode = "--shot" in args
	sun_check = "--suncheck" in args
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/layout.json"))
	near = layout["near"]
	heights = FileAccess.get_file_as_bytes("res://assets/models/heights.bin").to_float32_array()
	_setup_environment()
	_setup_sun()
	_load_static("terrain_near")
	_load_static("terrain_far")
	_load_static("water")
	# One-shot reflection probe over the river so the water reflects the opposite hillside
	# (SSR can't reach that far). Captured once at start.
	var probe := ReflectionProbe.new()
	probe.position = Vector3(0, 8, 175)
	probe.size = Vector3(3600, 700, 2400)
	probe.max_distance = 4000
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.intensity = 1.0
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	add_child(probe)
	_build_vines()
	_build_scatter("neighbours", 2, false, "vine_lod2_%d")
	_build_scatter("slate", 5, true)
	_build_scatter("grass", 3, false)
	cam = Camera3D.new()
	cam.fov = 65.0
	cam.near = 0.05
	cam.far = 9000.0
	add_child(cam)
	cam.make_current()
	_setup_ui()
	_apply_preset("row_downhill")
	if sun_check:
		var d := _sun_dir()
		cam.global_position = Vector3(0, _ground(0, 0) + EYE, 0)
		cam.look_at(cam.global_position + Vector3(d.x, 0.35, d.z).normalized())
		phase = "suncheck"
	elif shot_mode:
		_start_preset()

# ------------------------------------------------------------------ loading helpers
func _path(rel: String) -> String:
	return ProjectSettings.globalize_path("res://assets/" + rel)

func _tex(rel: String) -> Texture2D:
	if texcache.has(rel):
		return texcache[rel]
	var img := Image.load_from_file(_path(rel))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	texcache[rel] = t
	return t

func _glb(name: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(_path("models/%s.glb" % name), state)
	assert(err == OK, "glb load failed: " + name)
	return doc.generate_scene(state)

func _meshes(n: Node, out: Array) -> Array:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)
	return out

func _prep_mesh(name: String) -> Mesh:
	var root := _glb(name)
	var mi: MeshInstance3D = _meshes(root, [])[0]
	var mesh: Mesh = mi.mesh
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		mesh.surface_set_material(i, _material(m.resource_name if m else ""))
	root.free()
	return mesh

# ------------------------------------------------------------------ materials
func _lin(r: float, g: float, b: float) -> Color:
	return Color(r, g, b).linear_to_srgb()

func _material(name: String) -> Material:
	if mats.has(name):
		return mats[name]
	var m: Material
	match name:
		"vine_wood":
			var s := StandardMaterial3D.new()
			s.albedo_texture = _tex("textures/bark_willow_02/diff.jpg")
			s.albedo_color = Color(0.78, 0.74, 0.68)
			s.normal_enabled = true
			s.normal_texture = _tex("textures/bark_willow_02/nor_gl.jpg")
			s.normal_scale = 0.6
			s.roughness = 0.9
			s.uv1_scale = Vector3(1, 1.5, 1)
			m = s
		"vine_bark":
			var s := StandardMaterial3D.new()
			s.albedo_texture = _tex("textures/bark_willow_02/diff.jpg")
			s.albedo_color = Color(0.62, 0.50, 0.42)
			s.normal_enabled = true
			s.normal_texture = _tex("textures/bark_willow_02/nor_gl.jpg")
			s.roughness = 0.92
			m = s
		"vine_leaf":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://leaf.gdshader")
			sm.set_shader_parameter("leaf_detail", _tex("models/leaf_detail.png"))
			m = sm
		"vine_berry":
			var s := StandardMaterial3D.new()
			s.vertex_color_use_as_albedo = true
			s.roughness = 0.38
			m = s
		"slate":
			var s := StandardMaterial3D.new()
			s.albedo_color = _lin(0.055, 0.062, 0.075)
			s.roughness = 0.42
			s.normal_enabled = true
			s.normal_texture = _tex("textures/rock_ground/nor_gl.jpg")
			s.normal_scale = 0.5
			s.uv1_triplanar = true
			s.uv1_scale = Vector3(4, 4, 4)
			m = s
		"grass":
			var s := StandardMaterial3D.new()
			s.vertex_color_use_as_albedo = true
			s.cull_mode = BaseMaterial3D.CULL_DISABLED
			s.roughness = 0.8
			s.backlight_enabled = true
			s.backlight = Color(0.18, 0.22, 0.05)
			m = s
		"terrain_near":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://terrain_near.gdshader")
			for k in ["rock_ground", "grass_ground"]:
				var p := "rock" if k == "rock_ground" else "grass"
				sm.set_shader_parameter(p + "_alb", _tex("textures/%s/diff.jpg" % k))
				sm.set_shader_parameter(p + "_nrm", _tex("textures/%s/nor_gl.jpg" % k))
				sm.set_shader_parameter(p + "_rgh", _tex("textures/%s/rough.jpg" % k))
				sm.set_shader_parameter(p + "_ao", _tex("textures/%s/ao.jpg" % k))
			m = sm
		"terrain_far":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://terrain_far.gdshader")
			sm.set_shader_parameter("far_albedo", _tex("models/far_albedo.jpg"))
			sm.set_shader_parameter("detail_nrm", _tex("textures/grass_ground/nor_gl.jpg"))
			sm.set_shader_parameter("detail_ao", _tex("textures/rock_ground/ao.jpg"))
			m = sm
		"water":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://water.gdshader")
			var nt := NoiseTexture2D.new()
			nt.width = 512
			nt.height = 512
			nt.seamless = true
			nt.as_normal_map = true
			nt.bump_strength = 6.0
			nt.generate_mipmaps = true
			var fn := FastNoiseLite.new()
			fn.frequency = 0.02
			nt.noise = fn
			sm.set_shader_parameter("wave_nrm", nt)
			m = sm
		_:
			push_warning("unknown material " + name)
			m = StandardMaterial3D.new()
	mats[name] = m
	return m

# ------------------------------------------------------------------ scene
func _sun_dir() -> Vector3:
	var d: Array = layout["sun"]["direction"]
	return Vector3(d[0], d[1], d[2]).normalized()

func _setup_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://sky.gdshader")
	var img := Image.load_from_file(_path("hdri/sky.hdr"))
	sky_mat.set_shader_parameter("panorama", ImageTexture.create_from_image(img))
	var d := _sun_dir()
	var phi_d := atan2(d.x, -d.z)
	var phi_s := HDRI_SUN_U * TAU - PI
	sky_mat.set_shader_parameter("rot_y", phi_d - phi_s)
	sky_mat.set_shader_parameter("energy", 0.9)
	sky_mat.set_shader_parameter("radiance_clamp", 3.0)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_512
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4
	env.ssil_enabled = OS.get_environment("EXPERIMENT") != "lite"
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
	env.fog_light_color = Color(0.70, 0.76, 0.86)
	env.fog_light_energy = 1.0
	env.fog_density = 0.00013
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.0
	env.fog_sun_scatter = 0.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _setup_sun() -> void:
	var sun := DirectionalLight3D.new()
	add_child(sun)
	var d := _sun_dir()
	sun.look_at_from_position(Vector3.ZERO, -d, Vector3.UP)
	sun.light_color = Color(1.0, 0.85, 0.68)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 150.0
	sun.directional_shadow_split_1 = 0.05
	sun.directional_shadow_split_2 = 0.15
	sun.directional_shadow_split_3 = 0.4
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.0

func _load_static(name: String) -> void:
	var root := _glb(name)
	for mi in _meshes(root, []):
		var mesh: Mesh = mi.mesh
		if OS.get_environment("DEBUG_COLORS") != "":
			var arr := mesh.surface_get_arrays(0)
			var cols = arr[Mesh.ARRAY_COLOR]
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			print(name, " verts=", verts.size(), " colors=", (cols.size() if cols else -1))
			if cols:
				for i in [0, verts.size() / 3, verts.size() / 2, verts.size() * 4 / 5]:
					print("  v", verts[i], " c", cols[i])
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			mesh.surface_set_material(i, _material(m.resource_name if m else name))
		if name != "terrain_near":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if name == "water" else mi.cast_shadow
	add_child(root)

func _vine_transform(it: Array) -> Transform3D:
	var b := Basis(Vector3.UP, float(it[4])).scaled(Vector3.ONE * float(it[5]))
	return Transform3D(b, Vector3(it[1], it[2], it[3]))

func _build_vines() -> void:
	vine_items = layout["vines"]["items"]
	var counts := [0, 0, 0, 0]
	for it in vine_items:
		counts[int(it[0])] += 1
		vine_xf.append(_vine_transform(it))
	var h: Dictionary = layout["vineyard"]
	var aabb := AABB(Vector3(-float(h["halfX"]) - 3, 30, -float(h["halfZ"]) - 3),
		Vector3(2 * float(h["halfX"]) + 6, 60, 2 * float(h["halfZ"]) + 6))
	for v in 4:
		var lod1_mesh := _prep_mesh("vine_%d_lod1" % v)
		for lod in 3:   # 0 = full detail (no shadow), 1 = far, 2 = shadow proxy for the LOD0 set
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = _prep_mesh("vine_%d" % v) if lod == 0 else lod1_mesh
			mm.instance_count = counts[v]
			mm.visible_instance_count = 0
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.custom_aabb = aabb
			if lod == 0:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif lod == 2:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			add_child(mmi)
			vine_mmi["%d_%d" % [v, lod]] = mmi

func _rebucket(pos: Vector3) -> void:
	last_bucket = pos
	var idx := {}
	for k in vine_mmi:
		idx[k] = 0
	for i in vine_items.size():
		var xf: Transform3D = vine_xf[i]
		var lod := 0 if xf.origin.distance_to(pos) < LOD_DIST else 1
		var key := "%d_%d" % [int(vine_items[i][0]), lod]
		(vine_mmi[key] as MultiMeshInstance3D).multimesh.set_instance_transform(idx[key], xf)
		idx[key] += 1
		if lod == 0:
			var sk := "%d_2" % int(vine_items[i][0])
			(vine_mmi[sk] as MultiMeshInstance3D).multimesh.set_instance_transform(idx[sk], xf)
			idx[sk] += 1
	for k in vine_mmi:
		(vine_mmi[k] as MultiMeshInstance3D).multimesh.visible_instance_count = idx[k]

func _build_scatter(kind: String, variants: int, quat: bool, model := "") -> void:
	var items: Array = layout[kind]["items"]
	var per := []
	for v in variants:
		per.append([])
	for it in items:
		per[int(it[0])].append(it)
	for v in variants:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _prep_mesh((model if model != "" else kind + "_%d") % v)
		mm.instance_count = per[v].size()
		for i in per[v].size():
			var it: Array = per[v][i]
			var b: Basis
			if quat:
				b = Basis(Quaternion(it[4], it[5], it[6], it[7])).scaled(Vector3.ONE * float(it[8]))
			else:
				b = Basis(Vector3.UP, float(it[4])).scaled(Vector3.ONE * float(it[5]))
			mm.set_instance_transform(i, Transform3D(b, Vector3(it[1], it[2], it[3])))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if kind == "grass":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)

func _setup_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	fps_label = Label.new()
	fps_label.position = Vector2(12, 8)
	fps_label.add_theme_font_size_override("font_size", 22)
	fps_label.visible = false
	cl.add_child(fps_label)

# ------------------------------------------------------------------ camera / walking
func _ground(x: float, z: float) -> float:
	var n := int(near["nx"])
	var s := float(near["step"])
	var fx := clampf((x - float(near["x0"])) / s, 0.0, n - 1.001)
	var fz := clampf((z - float(near["z0"])) / s, 0.0, n - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var h0 := lerpf(heights[iz * n + ix], heights[iz * n + ix + 1], tx)
	var h1 := lerpf(heights[(iz + 1) * n + ix], heights[(iz + 1) * n + ix + 1], tx)
	return lerpf(h0, h1, tz)

func _apply_preset(name: String) -> void:
	var c: Dictionary = layout["cameras"][name]
	var p: Array = c["position"]
	var t: Array = c["target"]
	cam.global_position = Vector3(p[0], p[1], p[2])
	cam.look_at(Vector3(t[0], t[1], t[2]))
	yaw = cam.rotation.y
	pitch = cam.rotation.x
	walking = name != "drone"
	_rebucket(cam.global_position)

func _unhandled_input(e: InputEvent) -> void:
	if shot_mode or sun_check:
		return
	if e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * 0.0025
		pitch = clampf(pitch - e.relative.y * 0.0025, -1.45, 1.45)
		cam.rotation = Vector3(pitch, yaw, 0)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_F:
				fps_label.visible = not fps_label.visible
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				_apply_preset(PRESETS[e.physical_keycode - KEY_1])

func _walk(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): dir.z -= 1
	if Input.is_physical_key_pressed(KEY_S): dir.z += 1
	if Input.is_physical_key_pressed(KEY_A): dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D): dir.x += 1
	if dir != Vector3.ZERO:
		walking = true
		var speed := RUN if Input.is_physical_key_pressed(KEY_SHIFT) else WALK
		var move := Basis(Vector3.UP, yaw) * dir.normalized() * speed * delta
		cam.global_position += Vector3(move.x, 0, move.z)
	if walking:
		var p := cam.global_position
		cam.global_position.y = _ground(p.x, p.z) + EYE
	if cam.global_position.distance_to(last_bucket) > 1.0:
		_rebucket(cam.global_position)

func _process(delta: float) -> void:
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if phase == "suncheck":
		frames += 1
		if frames == 90:
			_save("godot_suncheck")
			get_tree().quit()
		return
	if shot_mode:
		_shot_step(delta)
		return
	_walk(delta)

# ------------------------------------------------------------------ capture mode
func _shots_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../shots")

func _save(name: String) -> void:
	if OS.get_environment("EXPERIMENT") != "":
		return
	var img := get_viewport().get_texture().get_image()
	var path := _shots_dir().path_join(name + ".png")
	img.save_png(path)
	print("saved ", path, " ", img.get_size())

func _start_preset() -> void:
	_apply_preset(PRESETS[shot_idx])
	phase = "settle"
	frames = 0

func _shot_step(delta: float) -> void:
	frames += 1
	if phase == "settle":
		if frames >= 90:
			_save("godot_" + PRESETS[shot_idx])
			phase = "measure"
			times = PackedFloat32Array()
		return
	times.append(delta)
	var total := 0.0
	for t in times:
		total += t
	if total < 5.0:
		return
	var sorted := times.duplicate()
	sorted.sort()
	var p99: float = sorted[int(0.99 * (sorted.size() - 1))]
	perf[PRESETS[shot_idx]] = {"avg_fps": snappedf(times.size() / total, 0.1),
		"low1_fps": snappedf(1.0 / p99, 0.1), "frames": times.size()}
	print(PRESETS[shot_idx], " ", perf[PRESETS[shot_idx]])
	shot_idx += 1
	if shot_idx < PRESETS.size():
		_start_preset()
		return
	perf["experiment"] = OS.get_environment("EXPERIMENT")
	perf["renderer"] = RenderingServer.get_video_adapter_name() + " / " + RenderingServer.get_current_rendering_driver_name()
	perf["resolution"] = str(get_viewport().get_texture().get_size())
	var exp := OS.get_environment("EXPERIMENT")
	var f := FileAccess.open(_shots_dir().path_join("godot_perf%s.json" % ("" if exp == "" else "_" + exp)), FileAccess.WRITE)
	f.store_string(JSON.stringify(perf, "  "))
	f.close()
	get_tree().quit()
