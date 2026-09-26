# Winery rooms from the engine demo, bound to the simulation's Lots:
#   "cellar": vaulted slate barrel cellar. Lots ageing in barriques / Fuder get chalk-labelled casks.
#   "hall":   fermentation hall. Each tank's controller screen shows one Lot (tank_panel.gd).
# GI: VoxelGI baked at runtime the first time the room is shown (LightmapGI needs the editor).
extends Node3D

const A := preload("res://src/view3d/assets3d.gd")
const TankPanel := preload("res://src/view3d/tank_panel.gd")
const VESSEL := ["Stainless steel", "Old Fuder (1 000 L)", "Neutral barriques", "Barriques 1st fill", "New French barriques", "New American barriques"]
const VESSEL_SHORT := ["steel", "Fuder", "neutral", "1st fill", "new FR", "new US"]

var room := "cellar"
var L: Dictionary
var cam: Camera3D
var env: Environment
var voxel: VoxelGI
var probe: ReflectionProbe
var mats := {}
var chalk: SystemFont
var built := false
var baked := false
var frame := 0
var led_mats: Array[StandardMaterial3D] = []
var barrels := []          # [{node, label_holder}]
var fuders := []
var panels := []           # [{ui, vp}]
var D := {}


func build() -> void:
	if built:
		return
	built = true
	L = A.json("models/winery.json")
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
	cam.environment = env
	var ca := CameraAttributesPractical.new()
	ca.auto_exposure_enabled = room == "hall"
	ca.auto_exposure_scale = 0.26
	ca.auto_exposure_max_sensitivity = 500.0
	ca.auto_exposure_speed = 4.0
	ca.auto_exposure_min_sensitivity = 40.0
	cam.attributes = ca
	add_child(cam)
	if not D.is_empty():
		apply_snapshot(D)


## Called when the room becomes visible: bake GI once (needs the geometry visible in the tree).
func on_shown() -> void:
	var t0 := Time.get_ticks_msec()
	build()
	var t1 := Time.get_ticks_msec()
	if not baked:
		baked = true
		_setup_gi()
		print("view3d %s: build %d ms, GI bake %d ms" % [room, t1 - t0, Time.get_ticks_msec() - t1])
	for p in panels:
		(p["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS


func on_hidden() -> void:
	for p in panels:
		(p["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED


func camera_preset(name: String) -> Array:
	var cams: Dictionary = L.get("cameras", {})
	var c: Dictionary = cams.get(name, cams.get(room, {"position": [0, 1.6, 0], "target": [1, 1.6, 0]}))
	var p: Array = c["position"]
	var t: Array = c["target"]
	return [Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2])]


func constrain(p: Vector3) -> Vector3:
	var w: Dictionary = L[room]["walk"]
	p.x = clampf(p.x, w["x"][0], w["x"][1])
	p.z = clampf(p.z, w["z"][0], w["z"][1])
	p.y = 1.65
	return p


func hud_text(_pos: Vector3) -> String:
	var n := 0
	for l in D.get("lots", []):
		n += 1
	if room == "cellar":
		return "Barrel cellar · %s · %d Lot(s) in the winery" % [D.get("dateLabel", ""), n]
	return "Fermentation hall · %s · %d Lot(s) in the winery" % [D.get("dateLabel", ""), n]


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
		var img := Image.load_from_file(A.path("hdri/clear.hdr"))
		sky_mat.panorama = ImageTexture.create_from_image(img)
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


func _setup_gi() -> void:
	var dims: Dictionary = L[room]["dims"]
	var size: Vector3
	var center: Vector3
	if room == "cellar":
		size = Vector3(float(dims["L"]) + 1.0, 5.4, float(dims["W"]) + 1.0)
		center = Vector3(0, 2.6, 0)
	else:
		size = Vector3(26, 7.6, 16)
		center = Vector3(0, 3.7, 0)
	voxel = VoxelGI.new()
	voxel.size = size
	voxel.position = center
	voxel.subdiv = VoxelGI.SUBDIV_128
	add_child(voxel)
	voxel.bake()
	voxel.data.energy = 1.6 if room == "cellar" else 1.4
	voxel.data.propagation = 0.75
	voxel.data.bias = 1.5
	voxel.data.normal_bias = 0.2
	probe = ReflectionProbe.new()
	probe.size = size
	probe.position = center
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.max_distance = 60
	add_child(probe)
	frame = 0


# ------------------------------------------------------------------ materials
func _mat(name: String) -> Material:
	if mats.has(name):
		return mats[name]
	var m: StandardMaterial3D
	match name:
		"cellar_wall":
			m = A.pbr("castle_wall_slates", 0.42, Color(0.66, 0.66, 0.70), 1.0)
			m.roughness_texture = null
			m.roughness = 0.86
			m.normal_scale = 0.8
		"cellar_floor":
			m = A.pbr("cobblestone_floor_04", 0.55, Color(0.60, 0.58, 0.56), 0.72)
		"rack_wood", "cellar_door":
			m = A.pbr("oak_veneer_01", 0.8, Color(0.30, 0.22, 0.16), 1.0)
		"barrel_oak":
			m = A.pbr("oak_veneer_01", 1.0, Color(0.66, 0.56, 0.46), 1.0)
			m.vertex_color_use_as_albedo = true
		"barrel_head":
			m = A.pbr("oak_veneer_01", 1.3, Color(0.52, 0.44, 0.36), 1.0)
			m.vertex_color_use_as_albedo = true
		"barrel_hoop":
			m = A.pbr("rusty_metal_02", 2.0, Color(0.22, 0.22, 0.23), 0.9)
			m.metallic = 0.75
		"barrel_bung":
			m = StandardMaterial3D.new(); m.albedo_color = Color(0.86, 0.84, 0.78); m.roughness = 0.5
		"hall_floor":
			m = A.pbr("concrete_floor_worn_001", 0.33, Color(0.74, 0.75, 0.77), 0.7)
		"hall_wall":
			m = A.pbr("grey_plaster_02", 0.35, Color(0.80, 0.82, 0.86), 1.0)
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
	var w := 256; var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var col := PackedFloat32Array(); col.resize(w)
	for x in w: col[x] = rng.randf()
	for x in w:
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
	var mesh := A.first_mesh(rel)
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
	var root := A.scene(rel)
	for mi in A.meshes(root):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			mesh.surface_set_material(i, _mat(String(m.resource_name) if m else ""))
		(mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_STATIC
	add_child(root)
	return root


var _prop_cache := {}
func _prop(rel: String, xf: Transform3D, only := "") -> Node3D:
	if not _prop_cache.has(rel):
		_prop_cache[rel] = A.scene(rel)
	var root: Node3D = (_prop_cache[rel] as Node3D).duplicate()
	if only != "":
		for c in root.get_children():
			if c.name != only:
				c.queue_free()
			else:
				(c as Node3D).position = Vector3.ZERO
	root.transform = xf
	add_child(root)
	for mi in A.meshes(root):
		(mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return root


func _exit_tree() -> void:
	for k in _prop_cache:
		(_prop_cache[k] as Node).free()
	_prop_cache.clear()


# ------------------------------------------------------------------ cellar
func _label(parent: Node3D, local_z: float, size: int, col: Color, width := 540.0) -> Label3D:
	var l := Label3D.new()
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
	l.rotation = Vector3(0, PI, randf_range(-0.06, 0.06))
	parent.add_child(l)
	return l


func _build_cellar() -> void:
	var C: Dictionary = L["cellar"]
	_add_static("models/" + String(C["model"]))
	var bq := _prep("models/" + String(C["barriqueModel"]))
	var fd := _prep("models/" + String(C["fuderModel"]))
	seed(11)
	for it in C["barriques"]:
		var mi := MeshInstance3D.new()
		mi.mesh = bq
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var p: Array = it["pos"]
		mi.transform = Transform3D(Basis(Vector3.UP, float(it["yaw"])) * Basis(Vector3.BACK, float(it["roll"])), Vector3(p[0], p[1], p[2]))
		add_child(mi)
		var holder := Node3D.new()
		holder.rotation = Vector3(0, 0, -float(it["roll"]))
		mi.add_child(holder)
		var lb := _label(holder, -(0.475 - 0.035) - 0.003, 42, Color(0.93, 0.92, 0.88, 0.82), 520.0)
		barrels.append({"node": mi, "label": lb, "slot": int(it.get("slot", 0))})
	for it in C["fuder"]:
		var mi := MeshInstance3D.new()
		mi.mesh = fd
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var p: Array = it["pos"]
		mi.transform = Transform3D(Basis(Vector3.UP, float(it["yaw"])), Vector3(p[0], p[1], p[2]))
		add_child(mi)
		var lb := _label(mi, -(0.61 - 0.035) - 0.016, 44, Color(0.95, 0.93, 0.86, 0.9), 560.0)
		fuders.append({"node": mi, "label": lb})
	for l in C["lights"]:
		var p: Array = l["pos"]
		var pos := Vector3(p[0], p[1], p[2])
		var col := Color(l["color"][0], l["color"][1], l["color"][2])
		if l["type"] == "sconce":
			var f: Array = l["facing"]
			var fwd := Vector3(f[0], f[1], f[2])
			var wall := Vector3(pos.x, pos.y, -fwd.z * 3.04)
			_prop("props/industrial_caged_sconce/industrial_caged_sconce.gltf", Transform3D(A.look_basis(fwd), wall), "industrial_caged_sconce_c")
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
	var Hd: Dictionary = L["hall"]
	_add_static("models/" + String(Hd["model"]))
	var yard := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(200, 200)
	yard.mesh = pm
	yard.position = Vector3(112.0, -0.01, 0)
	yard.material_override = A.pbr("concrete_floor_worn_001", 0.25, Color(0.75, 0.75, 0.72), 0.9)
	add_child(yard)
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
	var tank_mesh := _with_tangents(_prep("models/" + String(Hd["tankModel"])))
	var info: Dictionary = Hd["tankInfo"]
	var pnl: Dictionary = info["panel"]
	for td in Hd["tanks"]:
		var p: Array = td["pos"]
		var tank := MeshInstance3D.new()
		tank.mesh = tank_mesh
		tank.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		tank.transform = Transform3D(Basis(Vector3.UP, float(td["yaw"])), Vector3(p[0], p[1], p[2]))
		add_child(tank)
		_tank_panel(tank, String(td["id"]), pnl)
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
		_prop("props/hanging_industrial_lamp/hanging_industrial_lamp.gltf", Transform3D(Basis(), top))
		var sp := SpotLight3D.new()
		sp.position = top + Vector3(0, -1.25, 0)
		sp.rotation = Vector3(-PI / 2, 0, 0)
		sp.light_color = Color(l["color"][0], l["color"][1], l["color"][2])
		sp.light_energy = 5.0
		sp.spot_range = 14.0
		sp.spot_angle = 58.0
		sp.spot_attenuation = 1.2
		sp.shadow_enabled = int(p[0]) % 8 == 2 or int(p[0]) % 8 == -6
		sp.light_volumetric_fog_energy = 0.8
		add_child(sp)
	for pr in Hd["props"]:
		var p: Array = pr["pos"]
		var rel := "props/%s/%s.gltf" % [pr["model"], pr["model"]]
		_prop(rel, Transform3D(Basis(Vector3.UP, float(pr["yaw"])), Vector3(p[0], p[1], p[2])))


func _tank_panel(tank: Node3D, id: String, pnl: Dictionary) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(600, 392)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var ui := Control.new()
	ui.set_script(TankPanel)
	ui.size = Vector2(600, 392)
	vp.add_child(ui)
	add_child(vp)
	ui.call("setup", id, {}, "oe")
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
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(float(pnl["w"]) + 0.03, float(pnl["h"]) + 0.03, 0.02)
	b.mesh = bm
	b.material_override = _mat("tank_dark")
	b.position = Vector3(float(pnl["x"]), float(pnl["y"]), float(pnl["z"]) - 0.008)
	tank.add_child(b)
	panels.append({"ui": ui, "vp": vp, "id": id})


# ------------------------------------------------------------------ snapshot binding
static func in_barrel(lot: Dictionary) -> bool:
	var vessel := int(lot.get("choices", {}).get("Vessel", 0))
	return vessel >= 1 and String(lot.get("phase", "")) in ["Ageing", "Ready"]


func apply_snapshot(snap: Dictionary) -> void:
	D = snap
	if not built:
		return
	var lots: Array = []
	for l in D.get("lots", []):
		if String(l.get("phase", "")) != "Blended":
			lots.append(l)
	var vintage := int(D.get("vintage", 0))
	if room == "hall":
		var units := String(D.get("region", {}).get("units", "oe"))
		var tank_lots := lots.filter(func(l): return not in_barrel(l))
		for i in panels.size():
			var p: Dictionary = panels[i]
			(p["ui"] as Control).call("setup", p["id"], tank_lots[i] if i < tank_lots.size() else {}, units)
			if i < led_mats.size():
				led_mats[i].emission = Color(0.2, 1.0, 0.35) if i < tank_lots.size() else Color(0.3, 0.3, 0.3)
	else:
		for b in barrels:
			(b["label"] as Label3D).text = ""
		for f in fuders:
			(f["label"] as Label3D).text = ""
		var bi := 0
		var fi := 0
		for l in lots:
			if not in_barrel(l):
				continue
			var vessel := int(l.get("choices", {}).get("Vessel", 0))
			var month := int(l.get("ageingDay", 0)) / 30 + 1
			var target := int(l.get("ageingMonths", 0))
			var ready := String(l.get("phase", "")) == "Ready"
			var line3 := "ready to bottle" if ready else "month %d of %d" % [month, target]
			if vessel == 1:
				var nf := maxi(1, ceili(float(l.get("volume", 0.0)) / 1000.0))
				for k in nf:
					if fi >= fuders.size():
						break
					(fuders[fi]["label"] as Label3D).text = "Lot %s · %d\n%s\n%s" % [l.get("id", ""), vintage, l.get("variety", ""), line3]
					fi += 1
			else:
				var nb := maxi(1, ceili(float(l.get("volume", 0.0)) / 225.0))
				for k in nb:
					if bi >= barrels.size():
						break
					(barrels[bi]["label"] as Label3D).text = "Lot %s  %d\n%s\n%s · %s" % [l.get("id", ""), vintage, l.get("variety", ""), VESSEL_SHORT[vessel], line3]
					bi += 1


func _process(_delta: float) -> void:
	frame += 1
	if probe and frame == 200:
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.6
	for m in led_mats:
		if m.emission.g > 0.5:
			m.emission_energy_multiplier = 8.0 if blink else 0.6
