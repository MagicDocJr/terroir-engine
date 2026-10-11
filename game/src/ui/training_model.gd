# The training systems as a small 3D teaching model (learn card "training-system", learning-core design §7.3): three of
# the game's own vines on their trellis in winter (pruned wood), spring (young shoots) or summer (the full canopy with
# green bunches), with the parts named. It uses the vineyard's meshes and materials (bark, the Variety's leaf from the
# leaf atlas, berries), so the vine you learn on is the vine you walk past. Look only: nothing here is simulated.
# Facts: docs/science/canopy-and-yield.md §2.7 (training systems) and §3.1 (buds per vine).
extends VBoxContainer

const UI := preload("res://src/ui/ui.gd")
const A := preload("res://src/view3d/assets3d.gd")
const VY := preload("res://src/view3d/vineyard.gd")
const KINDS := ["Einzelpfahl", "Guyot", "Cordon"]
const SEASONS := ["Winter", "Spring", "Summer"]
const GROWTH := {"Winter": 0, "Spring": 2, "Summer": 4}       # the vine model's growth level
const WIRE := {"Guyot": [0.80, 1.75], "Cordon": [0.95, 1.95]}  # fruiting wire and canopy top (build_vineyard.py VSP)
const SPACING := {"Guyot": 1.0, "Cordon": 1.2, "Einzelpfahl": 1.15}

var kind := "Guyot"
var season := "Summer"
var variety := "Riesling"
var on_change: Callable           # (kind, season): the learn card remembers the choice
var bar: HBoxContainer
var box: SubViewportContainer
var viewport: SubViewport
var world: Node3D
var cam: Camera3D
var caption: Label
var overlay: Control              # the parts' names, drawn in 2D over the model so they stay sharp and inside the frame
var notes: Array = []             # [text, the part (3D), side "L"/"R"]
var yaw := 0.0
var pitch := -0.10
var dist := 3.9
var target := Vector3(0, 0.95, 0)
var auto := true
var dragging := false
var t := 0.0
var _mats := {}


static func available() -> bool:
	return A.available() and A.exists("models/vine_guyot_g4.glb") and A.exists("models/leaf_atlas.png")


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	bar = UI.hbox(12); add_child(bar)
	var stage := Control.new(); stage.custom_minimum_size = Vector2(0, 420); stage.clip_contents = true; add_child(stage)
	box = SubViewportContainer.new(); box.stretch = true; box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.gui_input.connect(_on_input)
	stage.add_child(box)
	overlay = Control.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_notes)
	stage.add_child(overlay)
	viewport = SubViewport.new(); viewport.own_world_3d = true; viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	box.add_child(viewport)
	VY._ensure_globals()
	var env := WorldEnvironment.new(); env.environment = _environment(); viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_energy = 1.25; sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true; sun.shadow_blur = 1.4; sun.light_angular_distance = 0.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS; sun.directional_shadow_max_distance = 9.0
	viewport.add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-20, 150, 0); fill.light_energy = 0.25; fill.light_color = Color(0.75, 0.85, 1.0)
	viewport.add_child(fill)
	cam = Camera3D.new(); cam.fov = 34.0; viewport.add_child(cam)
	caption = UI.label("", 13, UI.MUTED, null, true); add_child(caption)
	_build()


func set_view(k: String, s: String) -> void:
	kind = k if k in KINDS else "Guyot"
	season = s if s in SEASONS else "Summer"
	if on_change.is_valid(): on_change.call(kind, season)
	if viewport != null: _build()


func _process(delta: float) -> void:
	if cam == null or not is_visible_in_tree(): return
	t += delta
	if auto: yaw = sin(t * 0.22) * 0.5                     # sways round the side view, where the training reads best
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	cam.position = target + b * Vector3(0, 0, dist)
	cam.look_at(target, Vector3.UP)
	overlay.queue_redraw()


func _on_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		dragging = ev.pressed
		if ev.pressed: auto = false
		box.accept_event()
	elif ev is InputEventMouseMotion and dragging:
		yaw -= ev.relative.x * 0.008
		pitch = clampf(pitch - ev.relative.y * 0.005, -0.9, 0.15)
		box.accept_event()


func _environment() -> Environment:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.30, 0.47, 0.72); sky.sky_horizon_color = Color(0.72, 0.79, 0.86)
	sky.ground_horizon_color = Color(0.66, 0.62, 0.55); sky.ground_bottom_color = Color(0.46, 0.40, 0.33)   # the soil's tone, so the bed fades into it
	sky.sun_angle_max = 20.0
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new(); e.sky.sky_material = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; e.ambient_light_energy = 0.75
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_AGX; e.tonemap_exposure = 1.05
	e.ssao_enabled = true; e.ssao_radius = 0.6; e.ssao_intensity = 1.6
	e.fog_enabled = true; e.fog_light_color = Color(0.70, 0.76, 0.82); e.fog_density = 0.012; e.fog_sky_affect = 0.0
	return e


# ------------------------------------------------------------------ the scene
func _build() -> void:
	_bar()
	if world != null: world.queue_free()
	world = Node3D.new(); viewport.add_child(world)
	_ground()
	var sp: float = SPACING[kind]
	if kind != "Einzelpfahl": _trellis(sp)
	var g: int = GROWTH[season]
	# summer: the fruit-zone leaves pulled (as many growers do), so the bunches show
	var red := 1.0 if variety in ["Pinot Noir", "Cabernet Sauvignon"] else 0.0
	(_mat("vine_leaf") as ShaderMaterial).set_shader_parameter("leaf_state2", Vector4(0.0, red, 0.85 if season == "Summer" else 0.0, 0.85 if season == "Summer" else 0.0))
	var center_surfs: Array = []
	for i in [-1, 0, 1]:
		var surfs := _surfaces(kind.to_lower(), g, 0 if i == 0 else 1)
		var mi := MeshInstance3D.new(); mi.mesh = _mesh(surfs)
		mi.position = Vector3(i * sp, 0, 0)
		if kind == "Einzelpfahl": mi.rotation.y = _bow_angle(surfs) + (0.25 * i)
		world.add_child(mi)
		if i == 0: center_surfs = surfs
	_annotate(center_surfs)
	# winter frames the middle vine's wood and buds; spring and summer the whole row section
	match season:
		"Winter":
			target = Vector3(0.15 if kind == "Guyot" else 0.0, 0.78, 0); dist = 2.5; pitch = -0.16
		"Spring":
			target = Vector3(0.0, 0.95, 0); dist = 3.0; pitch = -0.12
		_:
			target = Vector3(0.0, 1.0, 0); dist = 3.6 if kind != "Cordon" else 3.9; pitch = -0.08
	caption.text = _caption()


func _bar() -> void:
	for c in bar.get_children(): c.queue_free()
	bar.add_child(UI.segmented(KINDS, kind, func(x): set_view(x, season), 110))
	bar.add_child(UI.spacer())
	bar.add_child(UI.segmented(SEASONS, season, func(x): set_view(kind, x), 80))


func _surfaces(training: String, g: int, seed: int) -> Array:
	return A.glb_surfaces("models/vine_%s_g%d.glb" % [training, g]).get("s%d_lod0" % seed, [])


func _mat(name: String) -> Material:
	if _mats.has(name): return _mats[name]
	var m: Material = VY.make_mat(name)
	if name == "vine_leaf": (m as ShaderMaterial).set_shader_parameter("variety_cell", int(VY.LEAF_CELL.get(variety, 0)))
	if name == "vine_berry": (m as ShaderMaterial).set_shader_parameter("berry_state2", Vector4(0, 0, 1.0 if variety in ["Pinot Noir", "Cabernet Sauvignon"] else 0.0, 1.0))
	_mats[name] = m
	return m


func _mesh(surfs: Array) -> ArrayMesh:
	var m := ArrayMesh.new()
	for sf in surfs:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sf[0])
		var nm := String(sf[1])
		m.surface_set_material(m.get_surface_count() - 1, _mat(nm) if nm != "" else sf[2])
	return m


## Einzelpfahl bows lie in a random vertical plane per vine; turn the plane of the bows across the view (largest spread of
## the bow wood, from the bark vertices above the head).
func _bow_angle(surfs: Array) -> float:
	var sxx := 0.0; var szz := 0.0; var sxz := 0.0
	for sf in surfs:
		if String(sf[1]) != "vine_bark": continue
		for p in (sf[0][Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if p.y < 0.72 or p.y > 1.2 or Vector2(p.x, p.z).length() < 0.08: continue
			sxx += p.x * p.x; szz += p.z * p.z; sxz += p.x * p.z
	return 0.5 * atan2(2.0 * sxz, sxx - szz)


func _ground() -> void:
	var pm := PlaneMesh.new(); pm.size = Vector2(9.0, 6.0); pm.subdivide_width = 1; pm.subdivide_depth = 1
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 half_size = vec2(4.5, 3.0);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec2 uv = lp.xz * 0.7;
	ALBEDO = texture(tex, uv).rgb * vec3(0.95, 0.9, 0.85);
	NORMAL_MAP = texture(nor, uv).rgb;
	ROUGHNESS = 0.96;
	ALPHA = 1.0 - smoothstep(0.45, 1.0, length(lp.xz / half_size));
}
"""
	var sm := ShaderMaterial.new(); sm.shader = sh
	sm.set_shader_parameter("tex", A.tex("textures/dry_ground_rocks/diff.jpg"))
	sm.set_shader_parameter("nor", A.tex("textures/dry_ground_rocks/nor_gl.jpg"))
	var mi := MeshInstance3D.new(); mi.mesh = pm; mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)


## End posts and the vineyard's wires (vineyard.gd _build_trellis): the fruiting wire, two pairs of catch wires, the top wire.
func _trellis(sp: float) -> void:
	var hw: float = WIRE[kind][0]; var top: float = WIRE[kind][1]
	var x0 := -1.5 * sp; var x1 := 1.5 * sp
	var post := CylinderMesh.new(); post.top_radius = 0.035; post.bottom_radius = 0.04; post.height = top + 0.35; post.radial_segments = 10
	post.material = _mat("post")
	for x in [x0, x1]:
		var p := MeshInstance3D.new(); p.mesh = post; p.position = Vector3(x, post.height / 2.0 - 0.05, 0); world.add_child(p)
	for wd in [[0.0, hw], [-0.13, hw + 0.33], [0.13, hw + 0.33], [-0.14, hw + 0.66], [0.14, hw + 0.66], [0.0, top - 0.05]]:
		var w := CylinderMesh.new(); w.top_radius = 0.0022; w.bottom_radius = 0.0022; w.height = x1 - x0; w.radial_segments = 5
		w.material = _mat("wire")
		var wi := MeshInstance3D.new(); wi.mesh = w; wi.rotation.z = PI / 2.0
		wi.position = Vector3(0, float(wd[1]), float(wd[0])); world.add_child(wi)


# ------------------------------------------------------------------ names of the parts
func _annotate(surfs: Array) -> void:
	notes = _notes(surfs)


## Each name sits in a column at the left or right edge, at the height of its part (pushed apart when they would
## overlap), with a leader line to a dot on the part.
func _draw_notes() -> void:
	if cam == null or not cam.is_inside_tree(): return
	var f: Font = UI.f_body_b
	var fs := 13
	var W := overlay.size.x
	var maxw := clampf(W * 0.27, 150.0, 240.0)
	for side in ["L", "R"]:
		var items := []
		for n in notes:
			if String(n[2]) != side: continue
			var a: Vector3 = n[1]
			if cam.is_position_behind(a): continue
			var p := cam.unproject_position(a)
			var sz := f.get_multiline_string_size(String(n[0]), HORIZONTAL_ALIGNMENT_LEFT, maxw, fs)
			items.append([p, String(n[0]), sz])
		items.sort_custom(func(x, y): return x[0].y < y[0].y)
		var y_min := 8.0
		for it in items:
			var sz: Vector2 = it[2]
			var y := maxf(y_min, clampf((it[0] as Vector2).y - sz.y * 0.5, 8.0, overlay.size.y - sz.y - 8.0))
			y_min = y + sz.y + 10.0
			var x := 10.0 if side == "L" else W - sz.x - 10.0
			var r := Rect2(Vector2(x - 6, y - 4), sz + Vector2(12, 8))
			var edge := Vector2(r.end.x if side == "L" else r.position.x, y + sz.y * 0.5)
			overlay.draw_line(edge, it[0], Color(1, 0.94, 0.78, 0.8), 1.5, true)
			overlay.draw_circle(it[0], 3.5, UI.GOLD)
			overlay.draw_circle(it[0], 3.5, Color(0, 0, 0, 0.6), false, 1.0, true)
			overlay.draw_style_box(UI.sb(Color(0.07, 0.09, 0.11, 0.78), 5, Color(1, 0.9, 0.6, 0.35), 1, 0), r)
			overlay.draw_multiline_string(f, Vector2(x, y + f.get_ascent(fs)), String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, maxw, fs, -1, Color(1, 0.96, 0.88))


## [text, the part, which edge the name sits at] for this system and season.
func _notes(surfs: Array) -> Array:
	var sp: float = SPACING[kind]
	match kind:
		"Einzelpfahl":
			var tip := _bow_tip(surfs)
			match season:
				"Winter": return [
					["Stake: one per vine, no wires", Vector3(0, 1.5, 0), "L"],
					["Bows: canes bent round and tied to the stake, the 'heart'", tip, "R"],
					["Trunk", Vector3(0.02, 0.3, 0.06), "L"]]
				"Spring": return [
					["Shoots grow from the buds on the bows, all round the stake", tip + Vector3(0.02, 0.15, 0), "R"],
					["Stake: one per vine, no wires", Vector3(0, 1.5, 0), "L"]]
				_: return [
					["Shoots spread all round: air and light reach the bunches", Vector3(0.25, 1.45, 0.15), "R"],
					["Bunches hang round the bows (fruit-zone leaves pulled here)", tip + Vector3(-0.05, -0.1, 0.05), "R"],
					["Stake", Vector3(0, 1.8, 0), "L"]]
		"Cordon":
			var hw: float = WIRE[kind][0]
			var top: float = WIRE[kind][1]
			match season:
				"Winter": return [
					["Cordon: a permanent arm along the fruiting wire", Vector3(0.45, hw, 0), "R"],
					["Spurs: one-year wood cut to 2 buds, every 15–20 cm", Vector3(-0.29, hw + 0.04, 0), "L"],
					["Trunk", Vector3(0.0, 0.4, 0.03), "L"],
					["Catch wires", Vector3(1.5 * sp - 0.3, hw + 0.66, 0.14), "R"]]
				"Spring": return [
					["One or two shoots from each spur", Vector3(0.29, hw + 0.25, 0), "R"],
					["Catch wires hold the shoots upright", Vector3(-1.5 * sp + 0.3, hw + 0.33, 0.13), "L"]]
				_: return [
					["Vertical shoot positioning (VSP): a thin, upright hedge", Vector3(0.25, 1.55, 0.1), "R"],
					["Fruit zone: bunches just above the arm (leaves pulled here)", Vector3(0.18, hw + 0.05, 0.1), "R"],
					["Shoots hedged at the top wire", Vector3(-0.4, top - 0.05, 0), "L"],
					["Trunk", Vector3(0.0, 0.4, 0.03), "L"]]
		_:
			var hw2: float = WIRE["Guyot"][0]
			var top2: float = WIRE["Guyot"][1]
			match season:
				"Winter": return [
					["Cane: last summer's shoot, cut to 8–12 buds and tied along the fruiting wire", Vector3(0.55, hw2, 0), "R"],
					["Renewal spur: 2 buds that give next winter's cane", Vector3(-0.06, hw2 + 0.05, 0.015), "L"],
					["Trunk", Vector3(0.0, 0.35, 0.03), "L"],
					["Fruiting wire", Vector3(-1.5 * sp + 0.3, hw2, 0), "L"],
					["Catch wires", Vector3(1.5 * sp - 0.3, hw2 + 0.66, 0.14), "R"]]
				"Spring": return [
					["One shoot from each bud along the cane", Vector3(0.5, hw2 + 0.25, 0), "R"],
					["Catch wires hold the shoots upright", Vector3(-1.5 * sp + 0.3, hw2 + 0.33, 0.13), "L"]]
				_: return [
					["Vertical shoot positioning (VSP): a thin, upright hedge", Vector3(0.3, 1.4, 0.1), "R"],
					["Fruit zone: bunches just above the cane (leaves pulled here)", Vector3(0.3, hw2 + 0.06, 0.1), "R"],
					["Shoots hedged at the top wire", Vector3(-0.4, top2 - 0.05, 0), "L"],
					["Trunk", Vector3(0.0, 0.35, 0.03), "L"]]
	return []


## The outermost point of the bows (+X side, after the vine is turned), for the Einzelpfahl names.
func _bow_tip(surfs: Array) -> Vector3:
	var a := _bow_angle(surfs)
	var best := Vector3(0.3, 0.9, 0)
	for sf in surfs:
		if String(sf[1]) != "vine_bark": continue
		for p in (sf[0][Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if p.y < 0.72 or p.y > 1.2: continue
			var q := Basis(Vector3.UP, a) * p
			if q.x > best.x: best = q
	return best


func _caption() -> String:
	var what := {
		"Einzelpfahl": "Einzelpfahl (single stake): each vine on its own stake, one or two canes bent into bows; no wires, so it works on slopes too steep for a trellis.",
		"Guyot": "Guyot (cane pruning, VSP): each winter one new cane (two in double Guyot) is laid along the fruiting wire; the shoots grow up between the catch wires.",
		"Cordon": "Cordon (spur pruning, VSP): a permanent arm along the wire carries short two-bud spurs; easy to prune by machine."}
	var when := {"Winter": "Winter: the pruned wood.", "Spring": "Spring: the young shoots.", "Summer": "Summer: the full canopy, bunches still green before véraison."}
	return "%s %s The game's own vines (%s leaves). Drag to turn." % [what[kind], when[season], variety]
