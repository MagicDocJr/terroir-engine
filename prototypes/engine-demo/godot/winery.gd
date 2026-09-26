# PROTOTYPE — round 2 winery: vaulted slate barrel cellar + fermentation hall. Built at runtime from
# assets/models_r2 (see ../README_r2.md). GI: VoxelGI baked at runtime (fallback SDFGI via GI=sdfgi).
extends Node3D

const Lib := preload("res://lib.gd")
const TankPanel := preload("res://tank_panel.gd")

var room := "cellar"
var layout2: Dictionary
var shot2: Dictionary = {}
var cam: Camera3D
var env: Environment
var voxel: VoxelGI
var probe: ReflectionProbe
var yaw := 0.0
var pitch := 0.0
var frame := 0
var mats := {}
var chalk: SystemFont
var led_mats: Array[StandardMaterial3D] = []
var gi_mode := OS.get_environment("GI") if OS.get_environment("GI") != "" else "voxel"

func settle_frames() -> int:
	return 260

func _ready() -> void:
	chalk = SystemFont.new()
	chalk.font_names = PackedStringArray(["Ink Free", "Segoe Print", "Comic Sans MS"])
	chalk.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_environment()
	if room == "cellar":
		_build_cellar()
	else:
		_build_hall()
	cam = Camera3D.new()
	cam.fov = 64.0
	cam.near = 0.03
	cam.far = 400.0
	add_child(cam)
	cam.make_current()
	# eye adaptation: dark corners open up, bright windows/door stop blowing out
	var ca := CameraAttributesPractical.new()
	ca.auto_exposure_enabled = room == "hall"   # cellar keeps a fixed, moody exposure
	ca.auto_exposure_scale = 0.3 if room == "cellar" else 0.26
	ca.auto_exposure_max_sensitivity = 900.0 if room == "cellar" else 500.0
	ca.auto_exposure_speed = 4.0
	ca.auto_exposure_min_sensitivity = 40.0
	cam.attributes = ca
	var c: Dictionary = shot2.get("camera", {}) if shot2.has("camera") else {}
	if c.is_empty():
		c = layout2["shots"]["cellar_aisle" if room == "cellar" else "hall_overview"]["camera"]
	Lib.apply_camera(cam, c)
	yaw = cam.rotation.y
	pitch = cam.rotation.x
	_setup_gi()

# ------------------------------------------------------------------ environment & GI
func _environment() -> void:
	env = Environment.new()
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.6
	env.ssil_enabled = true
	env.ssil_radius = 1.5
	env.ssil_intensity = 0.8
	env.ssr_enabled = true
	env.ssr_max_steps = 96
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.2
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.volumetric_fog_enabled = true
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_gi_inject = 0.6
	env.volumetric_fog_detail_spread = 2.0
	if room == "cellar":
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0, 0, 0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.03, 0.025, 0.02)
		env.ambient_light_energy = 0.3
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		env.tonemap_exposure = 1.25
		env.volumetric_fog_density = 0.018
		env.volumetric_fog_albedo = Color(0.85, 0.8, 0.72)
		env.volumetric_fog_length = 40.0
	else:
		var sky_mat := PanoramaSkyMaterial.new()
		sky_mat.panorama = _hdr_tex("hdri/sky.hdr")
		sky_mat.energy_multiplier = 1.0
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.25
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.tonemap_exposure = 1.1
		env.volumetric_fog_density = 0.006
		env.volumetric_fog_albedo = Color(0.9, 0.9, 0.9)
		env.volumetric_fog_length = 60.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _hdr_tex(rel: String) -> Texture2D:
	var img := Image.load_from_file(Lib.path(rel))
	return ImageTexture.create_from_image(img)

func _setup_gi() -> void:
	var dims: Dictionary = layout2[room]["dims"]
	var size: Vector3
	var center: Vector3
	if room == "cellar":
		size = Vector3(float(dims["L"]) + 1.0, 5.4, float(dims["W"]) + 1.0)
		center = Vector3(0, 2.6, 0)
	else:
		size = Vector3(26, 7.6, 16)
		center = Vector3(0, 3.7, 0)
	if gi_mode == "sdfgi":
		env.sdfgi_enabled = true
		env.sdfgi_use_occlusion = true
		env.sdfgi_min_cell_size = 0.1
		env.sdfgi_cascades = 4
		env.sdfgi_energy = 1.2
		return
	voxel = VoxelGI.new()
	voxel.size = size
	voxel.position = center
	voxel.subdiv = VoxelGI.SUBDIV_256
	add_child(voxel)
	voxel.bake()
	voxel.data.energy = 1.6 if room == "cellar" else 1.4
	voxel.data.propagation = 0.75
	voxel.data.bias = 1.5
	voxel.data.normal_bias = 0.2
	# box-projected probe so the steel/wet floor reflect the room, captured after GI is on
	probe = ReflectionProbe.new()
	probe.size = size
	probe.position = center
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.max_distance = 60
	add_child(probe)

# ------------------------------------------------------------------ materials
func _mat(name: String) -> Material:
	if mats.has(name):
		return mats[name]
	var m: StandardMaterial3D
	match name:
		"cellar_wall":
			m = Lib.pbr("castle_wall_slates", 0.42, Color(0.66, 0.66, 0.70), 1.0)
			m.roughness_texture = null
			m.roughness = 0.86
			m.normal_scale = 0.8
		"cellar_floor":
			m = Lib.pbr("cobblestone_floor_04", 0.55, Color(0.60, 0.58, 0.56), 0.72)   # damp: darker + a bit glossier
		"rack_wood", "cellar_door":
			m = Lib.pbr("oak_veneer_01", 0.8, Color(0.30, 0.22, 0.16), 1.0)
		"barrel_oak":
			m = Lib.pbr("oak_veneer_01", 1.0, Color(0.66, 0.56, 0.46), 1.0)
			m.vertex_color_use_as_albedo = true
		"barrel_head":
			m = Lib.pbr("oak_veneer_01", 1.3, Color(0.52, 0.44, 0.36), 1.0)
			m.vertex_color_use_as_albedo = true
		"barrel_hoop":
			m = Lib.pbr("rusty_metal_02", 2.0, Color(0.22, 0.22, 0.23), 0.9)
			m.metallic = 0.75
		"barrel_bung":
			m = StandardMaterial3D.new(); m.albedo_color = Color(0.86, 0.84, 0.78); m.roughness = 0.5
		"hall_floor":
			m = Lib.pbr("concrete_floor_worn_001", 0.33, Color(0.74, 0.75, 0.77), 0.7)
		"hall_wall":
			m = Lib.pbr("grey_plaster_02", 0.35, Color(0.80, 0.82, 0.86), 1.0)
		"hall_steel":
			m = StandardMaterial3D.new(); m.albedo_color = Color(0.20, 0.23, 0.27); m.metallic = 0.6; m.roughness = 0.45
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"grate":
			m = StandardMaterial3D.new(); m.albedo_color = Color(0.25, 0.26, 0.27); m.metallic = 0.8; m.roughness = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"window_glass":
			m = StandardMaterial3D.new(); m.albedo_color = Color(0.75, 0.85, 0.9, 0.12)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.roughness = 0.05; m.metallic = 0.2
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"tank_steel", "tank_jacket":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.70, 0.715, 0.74) if name == "tank_steel" else Color(0.64, 0.655, 0.68)
			m.metallic = 1.0
			m.roughness = 0.34 if name == "tank_steel" else 0.42
			m.roughness_texture = _brushed_tex()
			m.normal_enabled = true
			m.normal_texture = _brushed_nrm() if name == "tank_steel" else _dimple_nrm()
			m.normal_scale = 0.12 if name == "tank_steel" else 0.3
			m.anisotropy_enabled = name == "tank_steel"
			m.anisotropy = 0.65
			m.uv1_scale = Vector3(1.0, 1.0, 1.0) if name == "tank_steel" else Vector3(16, 16, 16)
		"tank_dark":
			m = StandardMaterial3D.new(); m.albedo_color = Color(0.05, 0.05, 0.055); m.roughness = 0.4
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_:
			m = StandardMaterial3D.new()
	mats[name] = m
	return m

func _brushed_image(nrm: bool) -> Image:
	# vertical brush streaks (along the tank's lathe UV v), used as roughness and as a subtle normal map
	var w := 512; var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var col := PackedFloat32Array(); col.resize(w)
	for x in w: col[x] = rng.randf()
	for x in w:   # smooth across columns a little
		col[x] = (col[x] * 2.0 + col[(x + 1) % w] + col[(x - 1 + w) % w]) / 4.0
	for y in h:
		for x in w:
			var v := col[x] * 0.8 + rng.randf() * 0.2
			if nrm:
				var dx := col[(x + 1) % w] - col[(x - 1 + w) % w]
				img.set_pixel(x, y, Color(0.5 + dx * 0.5, 0.5, 1.0))
			else:
				img.set_pixel(x, y, Color(0.86 + 0.14 * v, 0.86 + 0.14 * v, 0.86 + 0.14 * v))
	img.generate_mipmaps()
	return img

var _brush_r: Texture2D
var _brush_n: Texture2D
func _brushed_tex() -> Texture2D:
	if _brush_r == null: _brush_r = ImageTexture.create_from_image(_brushed_image(false))
	return _brush_r
func _brushed_nrm() -> Texture2D:
	if _brush_n == null: _brush_n = ImageTexture.create_from_image(_brushed_image(true))
	return _brush_n
func _dimple_nrm() -> Texture2D:
	var w := 128
	var img := Image.create(w, w, false, Image.FORMAT_RGB8)
	for y in w:
		for x in w:
			var fx := (float(x) / w) * 2.0 - 1.0
			var fy := (float(y) / w) * 2.0 - 1.0
			var r := sqrt(fx * fx + fy * fy)
			var nx := 0.0; var ny := 0.0
			if r < 0.8:
				nx = -fx * 0.6; ny = -fy * 0.6
			img.set_pixel(x, y, Color(0.5 + nx * 0.5, 0.5 + ny * 0.5, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _prep(rel: String) -> Mesh:
	var mesh := Lib.first_mesh(rel)
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		var nm := String(m.resource_name) if m else ""
		mesh.surface_set_material(i, _mat(nm))
	return mesh

func _with_tangents(mesh: Mesh) -> Mesh:
	var out := ArrayMesh.new()
	for i in mesh.get_surface_count():
		var st := SurfaceTool.new()
		st.create_from(mesh, i)
		st.generate_tangents()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
		out.surface_set_material(i, mesh.surface_get_material(i))
	return out

func _add_static(rel: String) -> Node3D:
	var root := Lib.scene(rel)
	for mi in Lib.meshes(root):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			mesh.surface_set_material(i, _mat(String(m.resource_name) if m else ""))
		(mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_STATIC
	add_child(root)
	return root

func _prop(rel: String, xf: Transform3D, only := "") -> Node3D:
	var root := Lib.scene(rel)
	if only != "":
		for c in root.get_children():
			if c.name != only:
				c.queue_free()
			else:
				(c as Node3D).position = Vector3.ZERO
	root.transform = xf
	add_child(root)
	for mi in Lib.meshes(root):
		(mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_STATIC
	return root

# ------------------------------------------------------------------ cellar
func _label(parent: Node3D, text: String, local_z: float, size: int, col: Color, width := 540.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = chalk
	l.font_size = size
	l.pixel_size = 0.00075
	l.modulate = col
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.width = width
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	l.position = Vector3(0, 0.02, local_z)
	l.rotation = Vector3(0, PI, randf_range(-0.06, 0.06))   # face −Z (the aisle side)
	parent.add_child(l)

func _build_cellar() -> void:
	var C: Dictionary = layout2["cellar"]
	_add_static("models_r2/" + String(C["model"]))
	var bq := _prep("models_r2/" + String(C["barriqueModel"]))
	var fd := _prep("models_r2/" + String(C["fuderModel"]))
	seed(11)
	for it in C["barriques"]:
		var mi := MeshInstance3D.new()
		mi.mesh = bq
		mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		var p: Array = it["pos"]
		mi.transform = Transform3D(Basis(Vector3.UP, float(it["yaw"])) * Basis(Vector3.BACK, float(it["roll"])), Vector3(p[0], p[1], p[2]))
		add_child(mi)
		var lb: Dictionary = it["label"]
		var txt := "Fass %d\n%s %d\n%s · %s · %s" % [int(lb["fass"]), lb["lot"], int(lb["vintage"]), lb["oak"], lb["toast"], lb["fill"]]
		var holder := Node3D.new()
		holder.rotation = Vector3(0, 0, -float(it["roll"]))       # keep the chalk text upright despite the barrel roll
		mi.add_child(holder)
		_label(holder, txt, -(0.475 - 0.035) - 0.003, 42, Color(0.93, 0.92, 0.88, 0.82), 520.0)
	for it in C["fuder"]:
		var mi := MeshInstance3D.new()
		mi.mesh = fd
		mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		var p: Array = it["pos"]
		mi.transform = Transform3D(Basis(Vector3.UP, float(it["yaw"])), Vector3(p[0], p[1], p[2]))
		add_child(mi)
		var lb: Dictionary = it["label"]
		_label(mi, "Fuder %d · %d L\n%s\n%d" % [int(lb["fuder"]), int(lb["litres"]), lb["lot"], int(lb["vintage"])],
			-(0.61 - 0.035) - 0.016, 44, Color(0.95, 0.93, 0.86, 0.9), 560.0)
	# lamps: caged sconces on the vault wall + bare bulbs on cords from the crown
	for l in C["lights"]:
		var p: Array = l["pos"]
		var pos := Vector3(p[0], p[1], p[2])
		var col := Color(l["color"][0], l["color"][1], l["color"][2])
		if l["type"] == "sconce":
			var f: Array = l["facing"]
			var fwd := Vector3(f[0], f[1], f[2])
			var wall := Vector3(pos.x, pos.y, -fwd.z * 3.04)
			_prop("polyhaven_models/industrial_caged_sconce/industrial_caged_sconce.gltf",
				Transform3D(Lib.look_basis(fwd), wall), "industrial_caged_sconce_c")
			_omni(wall + fwd * 0.13 + Vector3(0, 0.02, 0), col, 2.2, 10.0)
		else:
			var bulb := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = 0.045; sm.height = 0.1
			bulb.mesh = sm
			var em := StandardMaterial3D.new(); em.emission_enabled = true; em.emission = col; em.emission_energy_multiplier = 30.0
			em.albedo_color = col
			bulb.material_override = em
			bulb.position = pos
			bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(bulb)
			var cord := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 0.006; cm.bottom_radius = 0.006; cm.height = 4.7 - pos.y
			cord.mesh = cm
			cord.material_override = _mat("tank_dark")
			cord.position = pos + Vector3(0, cm.height / 2 + 0.04, 0)
			add_child(cord)
			_omni(pos + Vector3(0, -0.06, 0), col, 1.6, 9.0)

func _omni(pos: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = col
	o.light_energy = energy
	o.omni_range = rng
	o.omni_attenuation = 1.6
	o.shadow_enabled = true
	o.shadow_blur = 1.5
	o.light_size = 0.04
	o.light_volumetric_fog_energy = 1.4
	o.light_bake_mode = Light3D.BAKE_DYNAMIC
	add_child(o)
	return o

# ------------------------------------------------------------------ fermentation hall
func _build_hall() -> void:
	var Hd: Dictionary = layout2["hall"]
	_add_static("models_r2/" + String(Hd["model"]))
	# courtyard outside the roller door, so the opening shows daylight on the ground
	var yard := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(200, 200)
	yard.mesh = pm
	yard.position = Vector3(112.0, -0.01, 0)
	yard.material_override = Lib.pbr("concrete_floor_worn_001", 0.25, Color(0.75, 0.75, 0.72), 0.9)
	add_child(yard)
	# daylight: sun slants through the high window ribbon (−Z wall) and the open door (+X)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -Vector3(0.35, 0.5, -0.8).normalized(), Vector3.UP)
	sun.light_color = Color(1.0, 0.93, 0.84)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 60.0
	sun.light_volumetric_fog_energy = 2.0
	sun.light_bake_mode = Light3D.BAKE_DYNAMIC
	var tank_mesh := _with_tangents(_prep("models_r2/" + String(Hd["tankModel"])))
	var info: Dictionary = Hd["tankInfo"]
	var pnl: Dictionary = info["panel"]
	for td in Hd["tanks"]:
		var p: Array = td["pos"]
		var tank := MeshInstance3D.new()
		tank.mesh = tank_mesh
		tank.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		tank.transform = Transform3D(Basis(Vector3.UP, float(td["yaw"])), Vector3(p[0], p[1], p[2]))
		add_child(tank)
		_tank_panel(tank, td, pnl)
		var led: Array = info["controllerLed"]
		var lm := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.008; sm.height = 0.016
		lm.mesh = sm
		var em := StandardMaterial3D.new(); em.emission_enabled = true; em.emission = Color(0.2, 1.0, 0.35); em.emission_energy_multiplier = 8.0
		lm.material_override = em
		led_mats.append(em)
		lm.position = Vector3(led[0], led[1], led[2])
		tank.add_child(lm)
	for l in Hd["lights"]:
		var p: Array = l["pos"]
		var top := Vector3(p[0], 6.98, p[2])
		_prop("polyhaven_models/hanging_industrial_lamp/hanging_industrial_lamp.gltf", Transform3D(Basis(), top))
		var sp := SpotLight3D.new()
		sp.position = top + Vector3(0, -1.25, 0)
		sp.rotation = Vector3(-PI / 2, 0, 0)
		sp.light_color = Color(l["color"][0], l["color"][1], l["color"][2])
		sp.light_energy = 5.0
		sp.spot_range = 14.0
		sp.spot_angle = 58.0
		sp.spot_attenuation = 1.2
		sp.shadow_enabled = int(p[0]) % 8 == 2 or int(p[0]) % 8 == -6   # a few shadowed ones
		sp.light_volumetric_fog_energy = 0.8
		add_child(sp)
	for pr in Hd["props"]:
		var p: Array = pr["pos"]
		var rel := "polyhaven_models/%s/%s.gltf" % [pr["model"], pr["model"]]
		_prop(rel, Transform3D(Basis(Vector3.UP, float(pr["yaw"])), Vector3(p[0], p[1], p[2])))

func _tank_panel(tank: Node3D, td: Dictionary, pnl: Dictionary) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(600, 392)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var ui := Control.new()
	ui.set_script(TankPanel)
	ui.size = Vector2(600, 392)
	vp.add_child(ui)
	add_child(vp)
	ui.call("setup", td)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(float(pnl["w"]), float(pnl["h"]))
	q.mesh = qm
	var m := StandardMaterial3D.new()
	var vt := vp.get_texture()
	m.albedo_texture = vt
	m.albedo_color = Color(0.25, 0.25, 0.25)
	m.emission_enabled = true
	m.emission_texture = vt
	m.emission_energy_multiplier = 1.6
	m.roughness = 0.15
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = Vector3(float(pnl["x"]), float(pnl["y"]), float(pnl["z"]) + 0.004)
	tank.add_child(q)
	# bezel
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(float(pnl["w"]) + 0.03, float(pnl["h"]) + 0.03, 0.02)
	b.mesh = bm
	b.material_override = _mat("tank_dark")
	b.position = Vector3(float(pnl["x"]), float(pnl["y"]), float(pnl["z"]) - 0.008)
	tank.add_child(b)

# ------------------------------------------------------------------ loop / controls
func _process(delta: float) -> void:
	frame += 1
	if probe and frame == 200:
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.6
	for m in led_mats:
		m.emission_energy_multiplier = 8.0 if blink else 0.6
	if not shot2.is_empty():
		return
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): dir.z -= 1
	if Input.is_physical_key_pressed(KEY_S): dir.z += 1
	if Input.is_physical_key_pressed(KEY_A): dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D): dir.x += 1
	if dir != Vector3.ZERO:
		var speed := 3.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.4
		var mv := Basis(Vector3.UP, yaw) * dir.normalized() * speed * delta
		cam.global_position += Vector3(mv.x, 0, mv.z)
		cam.global_position.y = 1.65

func _unhandled_input(e: InputEvent) -> void:
	if not shot2.is_empty():
		return
	if e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * 0.0025
		pitch = clampf(pitch - e.relative.y * 0.0025, -1.45, 1.45)
		cam.rotation = Vector3(pitch, yaw, 0)
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
