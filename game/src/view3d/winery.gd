# The winery building on the Estate, as one walkable place: exterior shell, fermentation hall, the stairs down
# and the vaulted barrel cellar behind the hall under the ground. Building frame: hall floor at y = 0, hall
# interior x∈[-12, 12], z∈[-7, 7], roller door in the east (+x) wall (game/tools/blender/build_winery.py,
# layout in assets3d/models/winery.json). vineyard.gd decides where the building stands; view3d.gd places it.
#
# Bound to the simulation's Lots (nothing is computed here):
#   hall:   each tank's controller screen shows one Lot (tank_panel.gd)
#   cellar: Lots ageing in barriques / Fuder get chalk-labelled casks
# Interior lights, VoxelGI and the tank screens only run while the player is near or inside (set_active).
extends Node3D

const A := preload("res://src/view3d/assets3d.gd")
const TankPanel := preload("res://src/view3d/tank_panel.gd")
const VESSEL_SHORT := ["steel", "Fuder", "neutral", "1st fill", "new FR", "new US"]

var L: Dictionary
var B: Dictionary                  # L.building (extents, zones, collision, occluders, stairs)
var cellar: Node3D                 # the cellar's own frame (child of this node)
var env_hall: Environment
var env_cellar: Environment
var attr_hall: CameraAttributesPractical
var attr_cellar: CameraAttributesPractical
var mats := {}
var chalk: SystemFont
var built := false
var baked := false
var region := ""
var hall_lights: Array[Light3D] = []
var cellar_lights: Array[Light3D] = []
var hall_gi: Array[Node3D] = []
var cellar_gi: Array[Node3D] = []
var voxel_hall: VoxelGI
var voxel_cellar: VoxelGI
var led_mats: Array[StandardMaterial3D] = []
var barrels := []
var fuders := []
var panels := []                   # [{ui, vp, id}]
var tanks := []                    # tank MeshInstance3D nodes (panel order)
var D := {}
var hall_on := true
var cellar_on := true
var screens_on := true
var probes: Array[ReflectionProbe] = []
var probe_frames := 0
var panel_t := 0.0
var Y: Dictionary                  # L.yard: sign, lamp, tractor spot, props
var sign_label: Label3D
var tractors := {}                 # node name -> Node3D (one shown, per Region)


func build() -> void:
	if built:
		return
	built = true
	var t0 := Time.get_ticks_msec()
	L = A.json("models/winery.json")
	B = L.get("building", {})
	chalk = SystemFont.new()
	chalk.font_names = PackedStringArray(["Ink Free", "Segoe Print", "Comic Sans MS"])
	chalk.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_environments()
	_build_exterior()
	_build_yard()
	_build_hall()
	_build_cellar()
	_build_stair_lights()
	_build_collision()
	_build_occluders()
	if not D.is_empty():
		apply_snapshot(D)
	print("view3d winery: build %d ms" % (Time.get_ticks_msec() - t0))


## Region look of the outside (facade render, roof, plinth). Cheap: only swaps material parameters.
func set_region(r: String) -> void:
	if r == region:
		return
	region = r
	for k in ["facade", "roof", "plinth"]:
		if mats.has(k):
			_region_material(k, mats[k])
	# a steep-slope crawler in the Mosel, a straddle tractor in Burgundy, a standard tractor in Napa
	var want := String(Y.get("tractors", {}).get(r, "tractor_standard"))
	for k in tractors:
		(tractors[k] as Node3D).visible = k == want
	if mats.has("tractor_paint"):
		(mats["tractor_paint"] as StandardMaterial3D).albedo_color = {"mosel": Color(0.62, 0.2, 0.05), "cote-dor": Color(0.1, 0.22, 0.45), "napa": Color(0.16, 0.36, 0.12)}.get(r, Color(0.6, 0.1, 0.06))
	if mats.has("bin_plastic"):
		(mats["bin_plastic"] as StandardMaterial3D).albedo_color = {"mosel": Color(0.18, 0.2, 0.22), "cote-dor": Color(0.52, 0.12, 0.08), "napa": Color(0.12, 0.2, 0.4)}.get(r, Color(0.5, 0.1, 0.08))


## Bake (or re-bake after the building moved) the interior GI. Needs the building and the terrain in the tree.
func bake_gi() -> void:
	var t0 := Time.get_ticks_msec()
	for v in [voxel_hall, voxel_cellar]:
		var was: bool = v.visible
		v.visible = true
		v.bake()
		v.data.propagation = 0.75
		v.data.bias = 1.5
		v.data.normal_bias = 0.2
		v.visible = was
	voxel_hall.data.energy = 1.4
	voxel_cellar.data.energy = 1.6
	baked = true
	refresh_probes()
	print("view3d winery: GI bake %d ms" % (Time.get_ticks_msec() - t0))


## Re-render the interior reflection probes for a few seconds (after baking / when the lights change).
func refresh_probes() -> void:
	for p in probes:
		p.update_mode = ReflectionProbe.UPDATE_ALWAYS
	probe_frames = 200


## zone: where the eye is ("" outside, "hall", "cellar"); near: outside but close to the building.
## Hall lights + GI run when near or inside; cellar and stair lights + GI when inside. Light shadows (the
## costly part: cube maps for the omnis) only in the room you are in; the tank screens only in the hall.
func set_active(zone: String, near: bool) -> void:
	var hall := near or zone != ""
	var cel := zone != ""
	if hall != hall_on:
		hall_on = hall
		for l in hall_lights: l.visible = hall
		for g in hall_gi: g.visible = hall
	if cel != cellar_on:
		cellar_on = cel
		for l in cellar_lights: l.visible = cel
		for g in cellar_gi: g.visible = cel
	for l in hall_lights:
		l.shadow_enabled = zone == "hall" and bool(l.get_meta("shadow", false))
	for l in cellar_lights:
		l.shadow_enabled = zone == "cellar" and bool(l.get_meta("shadow", false))
	var screens := zone == "hall"
	if screens != screens_on:
		screens_on = screens
		for p in panels:
			(p["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE if screens else SubViewport.UPDATE_DISABLED


## "hall" | "cellar" | "" (outside) for a point in the building frame. The upper half of the stairs counts as hall.
func zone_at(p: Vector3) -> String:
	var z: Dictionary = B.get("zones", {})
	var st: Array = z.get("stair", [])
	if st.size() == 6 and _inside(st, p):
		return "hall" if p.y > -2.6 else "cellar"
	var h: Array = z.get("hall", [])
	if h.size() == 6 and _inside(h, p):
		return "hall"
	var ce: Array = B.get("cellarExtent", [])
	if ce.size() == 4 and p.x > ce[0] and p.x < ce[1] and p.z > ce[2] and p.z < ce[3] and p.y < -1.0 and p.y > -7.0:
		return "cellar"
	return ""


static func _inside(r: Array, p: Vector3) -> bool:
	return p.x > r[0] and p.x < r[1] and p.y > r[2] and p.y < r[3] and p.z > r[4] and p.z < r[5]


## Named camera spot in the building frame: [position, target].
func camera_preset(name: String) -> Array:
	var c: Dictionary = L.get("cameras", {}).get(name, {})
	if c.is_empty():
		return []
	var p: Array = c["position"]
	var t: Array = c["target"]
	return [Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2])]


## Teleport spot for set_view("hall" | "cellar"): [feet position, look target] in the building frame.
func spawn(kind: String) -> Array:
	var s: Dictionary = L.get("spawn", {}).get(kind, {})
	if s.is_empty():
		return []
	var f: Array = s["feet"]
	var t: Array = s["target"]
	return [Vector3(f[0], f[1], f[2]), Vector3(t[0], t[1], t[2])]


func hud_text(zone: String) -> String:
	var lots := _live_lots()
	var ferm := 0
	for l in lots:
		if String(l.get("phase", "")) == "Fermenting":
			ferm += 1
	if zone == "cellar":
		var wood := lots.filter(func(l): return in_barrel(l)).size()
		return "Barrel cellar · %s · %d Lot(s) in wood" % [D.get("dateLabel", ""), wood]
	return "Fermentation hall · %s · %d Lot(s) in the winery, %d fermenting" % [D.get("dateLabel", ""), lots.size(), ferm]


## Global positions of the tanks whose Lot is fermenting (weight 1) or in malolactic (weight 0.3), for sound.
func active_tanks() -> Array:
	var out := []
	var tank_lots := _live_lots().filter(func(l): return not in_barrel(l))
	for i in mini(tank_lots.size(), tanks.size()):
		var ph := String(tank_lots[i].get("phase", ""))
		var w: float = {"Fermenting": 1.0, "Stuck": 0.15, "Malolactic": 0.3, "ColdSoak": 0.0}.get(ph, 0.0)
		if w > 0.0:
			out.append([(tanks[i] as Node3D).global_position + Vector3(0, 2.6, 0), w])
	return out


# ------------------------------------------------------------------ environments (per zone, set on the camera)
func _environments() -> void:
	env_cellar = Environment.new()
	env_cellar.tonemap_mode = Environment.TONE_MAPPER_AGX
	env_cellar.ssao_enabled = true
	env_cellar.ssao_radius = 0.6
	env_cellar.ssao_intensity = 1.6
	env_cellar.ssil_enabled = true
	env_cellar.ssil_radius = 1.5
	env_cellar.ssil_intensity = 0.8
	env_cellar.ssr_enabled = true
	env_cellar.ssr_max_steps = 96
	env_cellar.glow_enabled = true
	env_cellar.glow_hdr_threshold = 1.2
	env_cellar.glow_intensity = 0.55
	env_cellar.glow_bloom = 0.06
	env_cellar.volumetric_fog_enabled = true
	env_cellar.volumetric_fog_anisotropy = 0.55
	env_cellar.volumetric_fog_gi_inject = 0.6
	env_cellar.volumetric_fog_detail_spread = 2.0
	env_cellar.background_mode = Environment.BG_COLOR
	env_cellar.background_color = Color(0, 0, 0)
	env_cellar.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_cellar.ambient_light_color = Color(0.03, 0.025, 0.02)
	env_cellar.ambient_light_energy = 0.3
	env_cellar.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env_cellar.tonemap_exposure = 1.25
	env_cellar.volumetric_fog_density = 0.018
	env_cellar.volumetric_fog_albedo = Color(0.85, 0.8, 0.72)
	env_cellar.volumetric_fog_length = 40.0
	attr_cellar = CameraAttributesPractical.new()
	attr_cellar.auto_exposure_enabled = false
	attr_hall = CameraAttributesPractical.new()
	attr_hall.auto_exposure_enabled = true
	attr_hall.auto_exposure_scale = 0.26
	attr_hall.auto_exposure_max_sensitivity = 500.0
	attr_hall.auto_exposure_speed = 4.0
	attr_hall.auto_exposure_min_sensitivity = 40.0


## The hall sees the same sky and weather as outside (door and windows), with interior settings on top.
func sync_hall_env(outside: Environment) -> Environment:
	env_hall = outside.duplicate() as Environment
	env_hall.ambient_light_energy = 0.3
	env_hall.tonemap_exposure = 1.1
	env_hall.ssao_radius = 0.6
	env_hall.ssao_intensity = 1.6
	env_hall.ssil_radius = 1.5
	env_hall.ssil_intensity = 0.8
	env_hall.ssr_max_steps = 96
	env_hall.glow_hdr_threshold = 1.2
	env_hall.glow_intensity = 0.55
	env_hall.glow_bloom = 0.06
	env_hall.volumetric_fog_enabled = true
	env_hall.volumetric_fog_density = 0.006
	env_hall.volumetric_fog_albedo = Color(0.9, 0.9, 0.9)
	env_hall.volumetric_fog_length = 60.0
	env_hall.volumetric_fog_anisotropy = 0.55
	env_hall.volumetric_fog_gi_inject = 0.6
	env_hall.volumetric_fog_ambient_inject = 0.0
	env_hall.volumetric_fog_detail_spread = 2.0
	return env_hall


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
		"rack_wood":
			m = A.pbr("oak_veneer_01", 0.8, Color(0.30, 0.22, 0.16), 1.0)
		"cellar_door":
			m = A.pbr("oak_veneer_01", 0.8, Color(0.30, 0.22, 0.16), 1.0)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
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
		"rail":
			m = StandardMaterial3D.new(); m.albedo_color = Color(0.62, 0.63, 0.64); m.metallic = 0.85; m.roughness = 0.4
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
		"facade", "roof", "plinth":
			m = StandardMaterial3D.new()
			_region_material(name, m)
		"gutter":
			m = StandardMaterial3D.new(); m.albedo_color = Color(0.58, 0.6, 0.62); m.metallic = 0.7; m.roughness = 0.38
		"sign_board":
			m = A.pbr("oak_veneer_01", 0.5, Color(0.16, 0.24, 0.2), 1.0)
		"door_wood":
			m = A.pbr("oak_veneer_01", 0.7, Color(0.42, 0.28, 0.18), 1.0)
		"window_dark":
			m = StandardMaterial3D.new(); m.albedo_color = Color(0.02, 0.025, 0.03); m.metallic = 0.3; m.roughness = 0.06
		"canopy_roof":
			m = A.pbr("rusty_metal_02", 0.6, Color(0.55, 0.56, 0.58), 1.0)
			m.metallic = 0.6
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"bin_plastic":
			m = StandardMaterial3D.new(); m.albedo_color = Color(0.5, 0.1, 0.08); m.roughness = 0.55
		"tractor_paint":
			m = StandardMaterial3D.new(); m.albedo_color = Color(0.6, 0.1, 0.06); m.roughness = 0.35; m.metallic = 0.1
		"tractor_tyre":
			m = StandardMaterial3D.new(); m.albedo_color = Color(0.025, 0.025, 0.025); m.roughness = 0.9
		"tractor_metal":
			m = StandardMaterial3D.new(); m.albedo_color = Color(0.07, 0.07, 0.08); m.metallic = 0.6; m.roughness = 0.5
		"roof_under":
			m = A.pbr("oak_veneer_01", 0.6, Color(0.42, 0.33, 0.24), 1.0)
		"fascia":
			m = StandardMaterial3D.new(); m.albedo_color = Color(0.16, 0.16, 0.17); m.roughness = 0.6
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_:
			m = StandardMaterial3D.new()
	mats[name] = m
	return m


## Regional outside: Mosel white render + slate roof on a slate plinth; Côte d'Or cream render + flat brown
## tiles on limestone; Napa stucco + clay barrel tiles. (Look only; no facts are attached.)
func _region_material(name: String, m: StandardMaterial3D) -> void:
	var tex := ""
	var tint := Color(1, 1, 1)
	var uv := 0.35
	match name:
		"facade":
			tex = "painted_plaster_wall"
			tint = {"mosel": Color(0.95, 0.94, 0.91), "cote-dor": Color(0.96, 0.88, 0.74), "napa": Color(0.92, 0.80, 0.63)}.get(region, Color(0.95, 0.94, 0.91))
			uv = 0.3
		"roof":
			tex = {"mosel": "grey_roof_tiles_02", "cote-dor": "red_slate_roof_tiles_01", "napa": "clay_roof_tiles_02"}.get(region, "grey_roof_tiles_02")
			tint = {"mosel": Color(0.5, 0.53, 0.6), "cote-dor": Color(0.95, 0.85, 0.8), "napa": Color(1.0, 0.92, 0.86)}.get(region, Color(1, 1, 1))
			uv = 0.45
		"plinth":
			tex = "castle_wall_slates"
			tint = {"mosel": Color(0.55, 0.57, 0.62), "cote-dor": Color(1.15, 1.08, 0.95), "napa": Color(0.9, 0.78, 0.66)}.get(region, Color(0.6, 0.6, 0.62))
			uv = 0.5
	var src := A.pbr(tex, uv, tint, 1.0)
	m.albedo_texture = src.albedo_texture
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = src.normal_texture
	m.roughness_texture = src.roughness_texture
	m.roughness = 1.0
	m.ao_enabled = src.ao_enabled
	m.ao_texture = src.ao_texture
	m.uv1_scale = Vector3(uv, uv, uv)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


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


func _add_static(parent: Node3D, rel: String, double_shadow := false) -> Node3D:
	var root := A.scene(rel)
	for mi in A.meshes(root):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			mesh.surface_set_material(i, _mat(String(m.resource_name) if m else ""))
		(mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_STATIC
		if double_shadow:
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	parent.add_child(root)
	return root


var _prop_cache := {}
func _prop(parent: Node3D, rel: String, xf: Transform3D, only := "") -> Node3D:
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
	parent.add_child(root)
	for mi in A.meshes(root):
		(mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return root


func _exit_tree() -> void:
	for k in _prop_cache:
		(_prop_cache[k] as Node).free()
	_prop_cache.clear()


func _omni(parent: Node3D, pos: Vector3, col: Color, energy: float, rng: float, shadow := true) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = col
	o.light_energy = energy
	o.omni_range = rng
	o.omni_attenuation = 1.6
	o.shadow_enabled = shadow
	o.set_meta("shadow", shadow)
	o.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	o.distance_fade_enabled = true
	o.distance_fade_begin = 24.0
	o.distance_fade_length = 6.0
	o.distance_fade_shadow = 10.0
	o.shadow_blur = 1.5
	o.light_size = 0.04
	o.light_volumetric_fog_energy = 1.4
	o.light_bake_mode = Light3D.BAKE_DYNAMIC
	parent.add_child(o)
	return o


func _gi(parent: Node3D, size: Vector3, center: Vector3) -> VoxelGI:
	var v := VoxelGI.new()
	v.size = size
	v.position = center
	v.subdiv = VoxelGI.SUBDIV_64            # 128 cost ~5 fps for no visible difference in these rooms
	parent.add_child(v)
	var probe := ReflectionProbe.new()
	probe.size = size
	probe.position = center
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probes.append(probe)
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.max_distance = 60
	parent.add_child(probe)
	return v


# ------------------------------------------------------------------ exterior
func _build_exterior() -> void:
	var rel := "models/" + String(L["hall"].get("exteriorModel", "hall_ext.glb"))
	if A.exists(rel):
		_add_static(self, rel, true)


# ------------------------------------------------------------------ yard: gutters, sign, office door, lean-to, props
func _build_yard() -> void:
	Y = L.get("yard", {})
	if Y.is_empty() or not A.exists("models/" + String(Y.get("model", "yard.glb"))):
		return
	_add_static(self, "models/" + String(Y["model"]), true)
	# painted sign over the roller door: the estate name from the snapshot
	var sg: Dictionary = Y["sign"]
	var sp: Array = sg["pos"]
	sign_label = Label3D.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Times New Roman", "serif"])
	f.font_weight = 700
	sign_label.font = f
	sign_label.font_size = 128
	sign_label.outline_size = 0
	sign_label.modulate = Color(0.93, 0.86, 0.62)
	sign_label.shaded = true
	sign_label.double_sided = false
	sign_label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	sign_label.position = Vector3(sp[0], sp[1], sp[2])
	sign_label.rotation = Vector3(0, PI / 2, 0)            # faces +x (out of the east gable)
	sign_label.set_meta("w", float(sg["w"]) * 0.88)
	sign_label.set_meta("h", float(sg["h"]) * 0.62)
	add_child(sign_label)
	# lamp by the doors (switched off: the view shows the afternoon)
	var lp: Dictionary = Y["lamp"]
	var lpos: Array = lp["pos"]
	var lf: Array = lp["facing"]
	_prop(self, "props/industrial_caged_sconce/industrial_caged_sconce.gltf", Transform3D(A.look_basis(Vector3(lf[0], lf[1], lf[2])), Vector3(lpos[0], lpos[1], lpos[2])), "industrial_caged_sconce_c")
	for pr in Y.get("props", []):
		var p: Array = pr["pos"]
		_prop(self, "props/%s/%s.gltf" % [pr["model"], pr["model"]], Transform3D(Basis(Vector3.UP, float(pr["yaw"])), Vector3(p[0], p[1], p[2])))
	# the tractor: one node per Region, the right one shown by set_region
	var rel := "models/" + String(Y.get("tractorModel", "tractors.glb"))
	if A.exists(rel):
		var root := A.scene(rel)
		var t: Dictionary = Y["tractor"]
		var tp: Array = t["pos"]
		root.transform = Transform3D(Basis(Vector3.UP, float(t["yaw"])), Vector3(tp[0], tp[1], tp[2]))
		for mi in A.meshes(root):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for i in mesh.get_surface_count():
				var m := mesh.surface_get_material(i)
				mesh.surface_set_material(i, _mat(String(m.resource_name) if m else ""))
			(mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			tractors[String(mi.name)] = mi
		add_child(root)
		for k in tractors:
			(tractors[k] as Node3D).position = Vector3.ZERO
			(tractors[k] as Node3D).visible = false


## The parked tractor in the yard is hidden while it is out in the vineyard (workers.gd).
func set_parked_tractor(on: bool) -> void:
	var want := String(Y.get("tractors", {}).get(region, "tractor_standard"))
	for k in tractors:
		(tractors[k] as Node3D).visible = on and k == want


func _update_sign() -> void:
	if sign_label == null:
		return
	var name_ := String(D.get("estate", ""))
	if name_ == "":
		name_ = "Weingut" if region == "mosel" else ("Domaine" if region == "cote-dor" else "Winery")
	sign_label.text = name_
	# fit the painted text to the board
	var sz := sign_label.font.get_string_size(name_, HORIZONTAL_ALIGNMENT_LEFT, -1, sign_label.font_size)
	var px := minf(float(sign_label.get_meta("w")) / maxf(sz.x, 1.0), float(sign_label.get_meta("h")) / maxf(sz.y, 1.0))
	sign_label.pixel_size = px


# ------------------------------------------------------------------ fermentation hall + stairs
func _build_hall() -> void:
	var Hd: Dictionary = L["hall"]
	_add_static(self, "models/" + String(Hd["model"]), true)
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
		tanks.append(tank)
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
		_prop(self, "props/hanging_industrial_lamp/hanging_industrial_lamp.gltf", Transform3D(Basis(), top))
		var sp := SpotLight3D.new()
		sp.position = top + Vector3(0, -1.25, 0)
		sp.rotation = Vector3(-PI / 2, 0, 0)
		sp.light_color = Color(l["color"][0], l["color"][1], l["color"][2])
		sp.light_energy = 5.0
		sp.spot_range = 14.0
		sp.spot_angle = 58.0
		sp.spot_attenuation = 1.2
		sp.shadow_enabled = int(p[0]) == -2      # two key lights (one over each tank row); the rest unshadowed
		sp.distance_fade_enabled = true
		sp.distance_fade_begin = 30.0
		sp.distance_fade_length = 8.0
		sp.set_meta("shadow", sp.shadow_enabled)
		sp.light_volumetric_fog_energy = 0.8
		add_child(sp)
		hall_lights.append(sp)
	for pr in Hd["props"]:
		var p: Array = pr["pos"]
		var rel := "props/%s/%s.gltf" % [pr["model"], pr["model"]]
		_prop(self, rel, Transform3D(Basis(Vector3.UP, float(pr["yaw"])), Vector3(p[0], p[1], p[2])))
	var dims: Dictionary = Hd["dims"]
	var size := Vector3(float(dims["x1"]) - float(dims["x0"]) + 0.2, float(dims["h"]) + 0.3, float(dims["z1"]) - float(dims["z0"]) + 0.2)
	voxel_hall = _gi(self, size, Vector3(0, size.y / 2.0 - 0.1, 0))
	hall_gi = [voxel_hall, get_child(get_child_count() - 1)]
	voxel_hall.visible = true


func _tank_panel(tank: Node3D, id: String, pnl: Dictionary) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(600, 392)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
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


func _build_stair_lights() -> void:
	for l in B.get("stairLights", []):
		var p: Array = l["pos"]
		var f: Array = l["facing"]
		var fwd := Vector3(f[0], f[1], f[2])
		var pos := Vector3(p[0], p[1], p[2])
		var col := Color(l["color"][0], l["color"][1], l["color"][2])
		_prop(self, "props/industrial_caged_sconce/industrial_caged_sconce.gltf", Transform3D(A.look_basis(fwd), pos), "industrial_caged_sconce_c")
		cellar_lights.append(_omni(self, pos + fwd * 0.13 + Vector3(0, 0.02, 0), col, 1.8, 7.0, false))


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
	var cx: Dictionary = B.get("cellarXform", {"origin": [0, -6, -20], "yaw": PI / 2})
	var o: Array = cx["origin"]
	cellar = Node3D.new()
	cellar.name = "Cellar"
	cellar.transform = Transform3D(Basis(Vector3.UP, float(cx["yaw"])), Vector3(o[0], o[1], o[2]))
	add_child(cellar)
	_add_static(cellar, "models/" + String(C["model"]))
	var bq := _prep("models/" + String(C["barriqueModel"]))
	var fd := _prep("models/" + String(C["fuderModel"]))
	seed(11)
	for it in C["barriques"]:
		var mi := MeshInstance3D.new()
		mi.mesh = bq
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var p: Array = it["pos"]
		mi.transform = Transform3D(Basis(Vector3.UP, float(it["yaw"])) * Basis(Vector3.BACK, float(it["roll"])), Vector3(p[0], p[1], p[2]))
		cellar.add_child(mi)
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
		cellar.add_child(mi)
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
			_prop(cellar, "props/industrial_caged_sconce/industrial_caged_sconce.gltf", Transform3D(A.look_basis(fwd), wall), "industrial_caged_sconce_c")
			cellar_lights.append(_omni(cellar, wall + fwd * 0.13 + Vector3(0, 0.02, 0), col, 2.2, 10.0, false))
		else:
			var bulb := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = 0.045; sm.height = 0.1
			bulb.mesh = sm
			var em := StandardMaterial3D.new(); em.emission_enabled = true; em.emission = col; em.emission_energy_multiplier = 30.0
			em.albedo_color = col
			bulb.material_override = em
			bulb.position = pos
			bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cellar.add_child(bulb)
			var cord := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 0.006; cm.bottom_radius = 0.006; cm.height = 4.7 - pos.y
			cord.mesh = cm
			cord.material_override = _mat("tank_dark")
			cord.position = pos + Vector3(0, cm.height / 2 + 0.04, 0)
			cellar.add_child(cord)
			cellar_lights.append(_omni(cellar, pos + Vector3(0, -0.06, 0), col, 1.6, 9.0))
	var dims: Dictionary = C["dims"]
	var size := Vector3(float(dims["L"]) + 1.0, 5.4, float(dims["W"]) + 1.0)
	voxel_cellar = _gi(cellar, size, Vector3(0, 2.6, 0))
	cellar_gi = [voxel_cellar, cellar.get_child(cellar.get_child_count() - 1)]


# ------------------------------------------------------------------ collision & occlusion
func _shapes(parent: Node3D, list: Array) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	parent.add_child(body)
	for e in list:
		var c: Array = e["c"]
		var cs := CollisionShape3D.new()
		if e.has("cyl"):
			var cyl := CylinderShape3D.new()
			cyl.radius = float(e["cyl"])
			cyl.height = float(e["h"])
			cs.shape = cyl
			cs.position = Vector3(c[0], c[1], c[2])
		else:
			var s: Array = e["s"]
			var bx := BoxShape3D.new()
			bx.size = Vector3(s[0], s[1], s[2])
			cs.shape = bx
			var basis := Basis()
			if e.has("rx"):
				basis = Basis(Vector3.RIGHT, float(e["rx"]))
			elif e.has("ry"):
				basis = Basis(Vector3.UP, float(e["ry"]))
			cs.transform = Transform3D(basis, Vector3(c[0], c[1], c[2]))
		body.add_child(cs)


func _build_collision() -> void:
	_shapes(self, B.get("collision", []))
	_shapes(cellar, L["cellar"].get("collision", []))


func _build_occluders() -> void:
	for e in B.get("occluders", []):
		var c: Array = e["c"]
		var s: Array = e["s"]
		_occluder(self, Vector3(c[0], c[1], c[2]), Vector3(s[0], s[1], s[2]))
	# the rock round the vaulted cellar (outside its surfaces, leaving the doorway open): from inside the cellar
	# the vineyard above is culled instead of being drawn behind the walls
	var dims: Dictionary = L["cellar"]["dims"]
	var hl := float(dims["L"]) / 2.0
	var hw := float(dims["W"]) / 2.0
	var top := float(dims["wall_h"]) + hw
	var dw := float(L["cellar"].get("doorLeaf", {}).get("len", 1.3)) / 2.0
	var t := 0.35
	_occluder(cellar, Vector3(0, top + 0.05 + t / 2.0, 0), Vector3(2.0 * hl + 1.6, t, 2.0 * hw + 1.6))       # above the vault
	for sz in [-1.0, 1.0]:
		_occluder(cellar, Vector3(0, top / 2.0, sz * (hw + 0.05 + t / 2.0)), Vector3(2.0 * hl + 1.6, top + 1.2, t))
	_occluder(cellar, Vector3(0, -0.05 - t / 2.0, 0), Vector3(2.0 * hl + 1.6, t, 2.0 * hw + 1.6))          # under the floor
	_occluder(cellar, Vector3(hl + 0.05 + t / 2.0, top / 2.0, 0), Vector3(t, top + 1.2, 2.0 * hw + 1.6))    # far end
	var xe := -hl - 0.4 - t / 2.0                                                                           # door end
	for sz in [-1.0, 1.0]:
		var w := hw + 0.8 - dw
		_occluder(cellar, Vector3(xe, top / 2.0, sz * (dw + w / 2.0)), Vector3(t, top + 1.2, w))
	_occluder(cellar, Vector3(xe, (2.1 + top + 0.6) / 2.0 + 0.3, 0), Vector3(t, top + 0.6 - 2.1, 2.0 * dw))


func _occluder(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var oc := OccluderInstance3D.new()
	var bo := BoxOccluder3D.new()
	bo.size = size
	oc.occluder = bo
	oc.position = pos
	parent.add_child(oc)


# ------------------------------------------------------------------ snapshot binding
static func in_barrel(lot: Dictionary) -> bool:
	var vessel := int(lot.get("choices", {}).get("Vessel", 0))
	return vessel >= 1 and String(lot.get("phase", "")) in ["Ageing", "Ready"]


func _live_lots() -> Array:
	var lots: Array = []
	for l in D.get("lots", []):
		if String(l.get("phase", "")) != "Blended":
			lots.append(l)
	return lots


## The tank whose screen shows this Lot (tasks: cap management marker), or null (in barrel / not in a tank).
func tank_for_lot(id: String) -> Node3D:
	var tank_lots := _live_lots().filter(func(l): return not in_barrel(l))
	for i in mini(tank_lots.size(), tanks.size()):
		if String(tank_lots[i].get("id", "")) == id:
			return tanks[i]
	return null


func apply_snapshot(snap: Dictionary) -> void:
	D = snap
	if not built:
		return
	_update_sign()
	var lots := _live_lots()
	var units := String(D.get("region", {}).get("units", "oe"))
	var tank_lots := lots.filter(func(l): return not in_barrel(l))
	for i in panels.size():
		var p: Dictionary = panels[i]
		(p["ui"] as Control).call("setup", p["id"], tank_lots[i] if i < tank_lots.size() else {}, units)
		if i < led_mats.size():
			led_mats[i].emission = Color(0.2, 1.0, 0.35) if i < tank_lots.size() else Color(0.3, 0.3, 0.3)
		if not screens_on:
			(p["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
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
				(fuders[fi]["label"] as Label3D).text = "Lot %s · %d\n%s\n%s" % [l.get("id", ""), int(l.get("vintage", D.get("vintage", 0))), l.get("variety", ""), line3]
				fi += 1
		else:
			var nb := maxi(1, ceili(float(l.get("volume", 0.0)) / 225.0))
			for k in nb:
				if bi >= barrels.size():
					break
				(barrels[bi]["label"] as Label3D).text = "Lot %s  %d\n%s\n%s · %s" % [l.get("id", ""), int(l.get("vintage", D.get("vintage", 0))), l.get("variety", ""), VESSEL_SHORT[vessel], line3]
				bi += 1


func _process(_delta: float) -> void:
	if probe_frames > 0:
		probe_frames -= 1
		if probe_frames == 0:
			for p in probes:
				p.update_mode = ReflectionProbe.UPDATE_ONCE
	if not screens_on:
		return
	panel_t += _delta
	if panel_t >= 0.2:                     # the screens only change with a snapshot and a 0.6 s blink: 5 Hz is plenty
		panel_t = 0.0
		for p in panels:
			(p["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.6
	for m in led_mats:
		if m.emission.g > 0.5:
			m.emission_energy_multiplier = 8.0 if blink else 0.6
