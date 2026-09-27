# Headless-ish test harness for the 3D views: plays real games through the Sim autoload, feeds the snapshots to
# view3d and captures 1920×1080 screenshots into game/shots/3d_<name>.png.
#
#   godot --path game res://src/view3d/view3d_test.tscn -- --capture3d [name,name,...] [--perf]
#   (see game/tools/shot3d.sh). Without --capture3d the scene just opens a Mosel game for manual testing.
extends Node

const View3D := preload("res://src/view3d/view3d.tscn")

# Planting used for the Mosel shots: four Einzelpfahl Blocks and one Guyot (VSP) Block, one of them Pinot Noir
const MOSEL := {"plotId": "mosel-blauschiefer", "plantingYear": 2012, "seed": 42, "planting": {
	"A": {"variety": "Riesling", "rootstock": "SO4", "training": "Einzelpfahl", "density": 8000},
	"B": {"variety": "Riesling", "rootstock": "SO4", "training": "Einzelpfahl", "density": 8000},
	"C": {"variety": "Riesling", "rootstock": "R3309C", "training": "Einzelpfahl", "density": 8000},
	"D": {"variety": "PinotNoir", "rootstock": "SO4", "training": "Einzelpfahl", "density": 8000},
	"E": {"variety": "Riesling", "rootstock": "SO4", "training": "Guyot", "density": 5000, "rows": "DownSlope"}}}

const COTEDOR := {"plotId": "cotedor-premiercru", "plantingYear": 2012, "seed": 7}
const NAPA := {"plotId": "napa-bench", "plantingYear": 2012, "seed": 9}

const SHOTS := [
	{"name": "mosel_budburst", "game": MOSEL, "until": "stage:Budburst", "extra": 6, "dry": true, "view": "vineyard", "cam": "row", "block": 1},
	{"name": "mosel_budburst_close", "game": MOSEL, "until": "stage:Budburst", "extra": 6, "dry": true, "view": "vineyard", "cam": "close", "block": 1},
	{"name": "mosel_flowering", "game": MOSEL, "until": "stage:Flowering", "extra": 3, "dry": true, "view": "vineyard", "cam": "row", "block": 4},
	{"name": "mosel_veraison", "game": MOSEL, "until": "stage:Veraison", "extra": 12, "dry": true, "view": "vineyard", "cam": "close", "block": 3},
	{"name": "mosel_harvest", "game": MOSEL, "until": "window", "extra": 0, "harvest": ["A"], "after": 1, "dry": true, "view": "vineyard", "cam": "close", "block": 4},
	{"name": "mosel_harvest_overview", "game": MOSEL, "until": "window", "extra": 0, "harvest": ["A"], "after": 1, "dry": true, "view": "vineyard", "cam": "overview"},
	{"name": "mosel_leaffall", "game": MOSEL, "until": "stage:LeafFall", "extra": 12, "dry": true, "view": "vineyard", "cam": "row", "block": 4},
	{"name": "cotedor_winter", "game": COTEDOR, "until": "date:02-10", "dry": true, "view": "vineyard", "cam": "row", "block": 1},
	{"name": "cotedor_august", "game": COTEDOR, "until": "date:08-16", "dry": true, "view": "vineyard", "cam": "row", "block": 0},
	{"name": "napa_september", "game": NAPA, "until": "date:09-12", "dry": true, "view": "vineyard", "cam": "row", "block": 1},
	# the one walkable Estate: vineyard → track → door → hall → stairs → cellar
	{"name": "mosel_estate", "game": MOSEL, "until": "winery", "view": "vineyard", "cam": "estate"},
	{"name": "mosel_estate_high", "game": MOSEL, "until": "winery", "view": "vineyard", "cam": "estate_high"},
	{"name": "mosel_track", "game": MOSEL, "until": "winery", "view": "vineyard", "cam": "track"},
	{"name": "mosel_door", "game": MOSEL, "until": "winery", "view": "hall", "cam": "door"},
	{"name": "hall", "game": MOSEL, "until": "winery", "view": "hall", "cam": "hall"},
	{"name": "hall_panel", "game": MOSEL, "until": "winery", "view": "hall", "cam": "hall_panel"},
	{"name": "hall_stairs", "game": MOSEL, "until": "winery", "view": "hall", "cam": "hall_stairs"},
	{"name": "stairs_down", "game": MOSEL, "until": "winery", "view": "hall", "cam": "stairs_down"},
	{"name": "stairs_up", "game": MOSEL, "until": "winery", "view": "cellar", "cam": "stairs_up"},
	{"name": "cellar", "game": MOSEL, "until": "winery", "view": "cellar", "cam": "cellar"},
	{"name": "cellar_labels", "game": MOSEL, "until": "winery", "view": "cellar", "cam": "cellar_heads"},
	{"name": "cellar_door", "game": MOSEL, "until": "winery", "view": "cellar", "cam": "cellar_door"},
	{"name": "cotedor_estate", "game": COTEDOR, "until": "date:08-16", "dry": true, "view": "vineyard", "cam": "estate"},
	{"name": "cotedor_estate_high", "game": COTEDOR, "until": "date:08-16", "dry": true, "view": "vineyard", "cam": "estate_high"},
	{"name": "cotedor_track", "game": COTEDOR, "until": "date:08-16", "dry": true, "view": "vineyard", "cam": "track"},
	{"name": "cotedor_hall", "game": COTEDOR, "until": "date:08-16", "dry": true, "view": "hall", "cam": "hall"},
	{"name": "napa_estate", "game": NAPA, "until": "date:09-12", "dry": true, "view": "vineyard", "cam": "estate"},
	{"name": "napa_estate_high", "game": NAPA, "until": "date:09-12", "dry": true, "view": "vineyard", "cam": "estate_high"},
	{"name": "napa_track", "game": NAPA, "until": "date:09-12", "dry": true, "view": "vineyard", "cam": "track"},
	{"name": "napa_cellar", "game": NAPA, "until": "date:09-12", "dry": true, "view": "cellar", "cam": "cellar"},
	# the steepest Plots: Mosel terraces (winery at the foot) and the Napa mountain site (winery beside the Plot)
	{"name": "terrassen_estate", "game": {"plotId": "mosel-terrassen", "plantingYear": 2012, "seed": 3}, "until": "date:07-10", "dry": true, "view": "vineyard", "cam": "estate"},
	{"name": "terrassen_estate_high", "game": {"plotId": "mosel-terrassen", "plantingYear": 2012, "seed": 3}, "until": "date:07-10", "dry": true, "view": "vineyard", "cam": "estate_high"},
	{"name": "napa_mountain_estate_high", "game": {"plotId": "napa-mountain", "plantingYear": 2012, "seed": 4}, "until": "date:07-10", "dry": true, "view": "vineyard", "cam": "estate_high"},
	{"name": "napa_mountain_track", "game": {"plotId": "napa-mountain", "plantingYear": 2012, "seed": 4}, "until": "date:07-10", "dry": true, "view": "vineyard", "cam": "track"},
]

var view: Control
var perf := false
var queue: Array = []
var results := {}
var last_game_key := ""
var snap := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	view = View3D.instantiate()
	add_child(view)
	if not "--sound" in OS.get_cmdline_user_args():
		view.set("sound_on", false)          # the mix still runs (and is logged); the bus is muted
	var i := args.find("--capture3d")
	if i < 0:
		_manual()
		return
	perf = "--perf" in args
	if "--trellis" in args:
		_trellis_probe()
		return
	if "--walktest" in args:
		_walk_test()
		return
	var only: PackedStringArray = []
	if i + 1 < args.size() and not args[i + 1].begins_with("--"):
		only = args[i + 1].split(",")
	for s in SHOTS:
		if only.is_empty() or String(s["name"]) in only:
			queue.append(s)
	if perf:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	_run()


func _manual() -> void:
	Sim.NewGame(JSON.stringify(MOSEL))
	Sim.Advance(150, false)
	view.apply_snapshot(JSON.parse_string(Sim.Snapshot()))
	view.set_view("vineyard")
	view.exit_requested.connect(func(): print("exit_requested"))


func _snap() -> Dictionary:
	return JSON.parse_string(Sim.Snapshot())


func _block(s: Dictionary, id: String) -> Dictionary:
	for b in s.get("blocks", []):
		if b.get("id", "") == id:
			return b
	return {}


const ORDER := ["Dormant", "Budburst", "Shoots", "Flowering", "FruitSet", "BunchClosure", "Veraison", "Ripening", "Harvested", "LeafFall"]


## Advance the game until the shot's condition holds; returns the final snapshot.
func _play(shot: Dictionary) -> Dictionary:
	var g: Dictionary = shot["game"]
	if not Sim.NewGame(JSON.stringify(g)):
		push_error("NewGame failed: " + Sim.LastError())
		return {}
	var until := String(shot["until"])
	var s := _snap()
	var guard := 0
	if until.begins_with("stage:"):
		var want := ORDER.find(until.substr(6))
		while guard < 400:
			var lead := 0
			for b in s["blocks"]:
				lead = maxi(lead, ORDER.find(String(b["stage"])))
			if lead >= want:
				break
			Sim.Advance(1, false); guard += 1
			s = _snap()
		Sim.Advance(int(shot.get("extra", 0)), false)
	elif until.begins_with("date:"):
		var md := until.substr(5)
		while guard < 400 and String(s["date"]).substr(5) < md:
			Sim.Advance(1, false); guard += 1
			s = _snap()
	elif until == "window":
		while guard < 400:
			var any := false
			for b in s["blocks"]:
				any = any or b.get("inWindow", false)
			if any:
				break
			Sim.Advance(1, false); guard += 1
			s = _snap()
		for id in shot.get("harvest", []):
			Sim.Command("harvest", id, "hand", "Table", "", "")
		Sim.Advance(int(shot.get("after", 0)), false)
	elif until == "winery":
		_play_winery()
	if shot.get("dry", false):              # prefer a day without rain for the showcase shots
		s = _snap()
		guard = 0
		while guard < 8 and String(s["weather"]["today"]["icon"]) == "rain":
			Sim.Advance(1, false); guard += 1
			s = _snap()
	return _snap()


## Harvest in two waves so the hall has fermenting Lots while earlier Lots already age in Fuder/barriques.
func _play_winery() -> void:
	var s := _snap()
	var guard := 0
	while guard < 400:
		var any := false
		for b in s["blocks"]:
			any = any or b.get("inWindow", false)
		if any:
			break
		Sim.Advance(1, false); guard += 1
		s = _snap()
	for id in ["A", "B", "D"]:
		Sim.Command("harvest", id, "hand", "Table", "", "")
	Sim.Advance(3, false)
	s = _snap()
	var vessel := {"A": "1", "B": "3", "D": "4"}      # A: old Fuder, B: barriques 1st fill, D (Pinot): new French
	for l in s["lots"]:
		var bid := String(l["block"])
		if vessel.has(bid):
			Sim.Command("lot", l["id"], "Vessel", vessel[bid], "", "")
			Sim.Command("lot", l["id"], "MLF", "0", "", "")
	# wait until an early Lot is in wood, then pick the rest so the hall is busy
	guard = 0
	while guard < 120:
		Sim.Advance(2, false); guard += 1
		s = _snap()
		var ageing := false
		for l in s["lots"]:
			ageing = ageing or String(l["phase"]) == "Ageing"
		if ageing:
			break
	for id in ["C", "E"]:
		Sim.Command("harvest", id, "hand", "Table", "", "")
	Sim.Advance(9, false)


func _run() -> void:
	for shot in queue:
		var key := JSON.stringify(shot["game"]) + String(shot["until"]) + str(shot.get("extra", 0)) + str(shot.get("harvest", []))
		if key != last_game_key:
			var t0 := Time.get_ticks_msec()
			snap = _play(shot)
			last_game_key = key
			print("3d shot %s: %s after %d ms of simulation" % [shot["name"], snap.get("date", "?"), Time.get_ticks_msec() - t0])
		var t1 := Time.get_ticks_msec()
		view.apply_snapshot(snap)
		view.set_view(String(shot["view"]))
		view.camera_preset(String(shot["cam"]), int(shot.get("block", 0)))
		print("  build/apply %d ms" % (Time.get_ticks_msec() - t1))
		var settle := 240 if shot["view"] != "vineyard" else 90
		for f in settle:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = view.capture()
		var out := ProjectSettings.globalize_path("res://shots/3d_%s.png" % shot["name"])
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		img.save_png(out)
		print("  saved ", out, " ", img.get_size())
		_log_state(shot)
		if perf:
			var times := PackedFloat32Array()
			var t := 0.0
			while t < 4.0:
				await get_tree().process_frame
				var dt := get_process_delta_time()
				times.append(dt)
				t += dt
			var srt := times.duplicate(); srt.sort()
			results[shot["name"]] = {"avg_fps": snappedf(times.size() / t, 0.1), "low1_fps": snappedf(1.0 / srt[int(0.99 * (srt.size() - 1))], 0.1),
				"frames": times.size(), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
			print("  perf ", results[shot["name"]])
			if "--breakdown" in OS.get_cmdline_user_args():
				if shot["view"] == "vineyard" and String(view.get("zone")) == "":
					await _breakdown()
				else:
					await _breakdown_indoor()
	if perf:
		results["gpu"] = RenderingServer.get_video_adapter_name()
		var f := FileAccess.open(ProjectSettings.globalize_path("res://shots/3d_perf.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(results, "  "))
		f.close()
	get_tree().quit()


func _fps(sec := 2.5) -> float:
	for i in 20:
		await get_tree().process_frame
	var t := 0.0
	var n := 0
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()
		n += 1
	return snappedf(n / t, 0.1)


## Diagnostic: fps with individual features switched off (vineyard only).
func _breakdown() -> void:
	# each group switched off on its own (fps and primitives), then everything back on
	var vy: Node3D = view.get("vineyard")
	var env: Environment = vy.get("env")
	var sun: DirectionalLight3D = vy.get("sun")
	var out := {"base": await _fps_prims()}
	var groups := {
		"lod0": func(n): return n in _lod_nodes(vy, [0]),
		"lod1": func(n): return n in _lod_nodes(vy, [1]),
		"lod2": func(n): return n in _lod_nodes(vy, [2]),
		"lod3_shadow_proxy": func(n): return n in _lod_nodes(vy, [3]),
		"lod4_far": func(n): return n in _lod_nodes(vy, [4]),
		"neighbours": func(n): return (vy.get("neighbour_mm") as Array).any(func(e): return e["mmi"] == n),
		"scatter_trellis": func(n): return n is MultiMeshInstance3D and n.visibility_range_end > 25.0 and n.visibility_range_end <= 120.0 and not n in _lod_nodes(vy, [0, 1, 2, 3, 4]),
		"trees": func(n): return n is MultiMeshInstance3D and n.visibility_range_end == 0.0 and not n in _lod_nodes(vy, [0, 1, 2, 3, 4]) and not (vy.get("neighbour_mm") as Array).any(func(e): return e["mmi"] == n),
	}
	for g in groups:
		var hidden := []
		for n in vy.get("world").get_children():
			if n is GeometryInstance3D and n.visible and groups[g].call(n):
				n.visible = false
				hidden.append(n)
		out["no_" + g] = await _fps_prims()
		for n in hidden:
			n.visible = true
	# the nearest vines drawn with the LOD1 mesh instead (same coverage, far fewer, bigger triangles)
	var swapped := []
	for blk in vy.get("blocks"):
		for e in blk["mm"]:
			if int(e["lod"]) == 0:
				var mm: MultiMesh = (e["mmi"] as MultiMeshInstance3D).multimesh
				swapped.append([mm, mm.mesh])
				mm.mesh = vy.call("_block_mesh", blk, blk["training"], blk["g"], e["seed"], 1)
	out["lod0_as_lod1"] = await _fps_prims()
	for sw in swapped:
		(sw[0] as MultiMesh).mesh = sw[1]
	env.ssil_enabled = false
	env.ssr_enabled = false
	env.ssao_enabled = false
	out["no_ssil_ssr_ssao"] = await _fps_prims()
	env.ssil_enabled = true; env.ssr_enabled = true; env.ssao_enabled = true
	sun.shadow_enabled = false
	out["no_sun_shadow"] = await _fps_prims()
	sun.shadow_enabled = true
	print("  breakdown ", out)


func _lod_nodes(vy: Node, lods: Array) -> Array:
	var out := []
	for blk in vy.get("blocks"):
		for e in blk["mm"]:
			if int(e["lod"]) in lods:
				out.append(e["mmi"])
	return out


func _fps_prims() -> String:
	var f: float = await _fps(1.5)
	return "%.0f fps %.1fM" % [f, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1e6]


## Diagnostic: fps with individual features switched off, for the camera's current (indoor) environment.
func _breakdown_indoor() -> void:
	var cam: Camera3D = (view.get("player") as Node).get("cam")
	var env: Environment = cam.environment
	var wy: Node = view.get("winery")
	var out := {"base": await _fps()}
	env.volumetric_fog_enabled = false
	out["no_volfog"] = await _fps()
	env.ssil_enabled = false
	out["+no_ssil"] = await _fps()
	env.ssr_enabled = false
	out["+no_ssr"] = await _fps()
	var lights: Array = wy.get("cellar_lights") + wy.get("hall_lights")
	for l in lights:
		l.set_meta("sh", l.shadow_enabled)
		l.shadow_enabled = false
	out["+no_light_shadows"] = await _fps()
	for g in [wy.get("voxel_hall"), wy.get("voxel_cellar")]:
		(g as Node3D).visible = false
	out["+no_voxelgi"] = await _fps()
	print("  breakdown ", out)
	env.volumetric_fog_enabled = true
	env.ssil_enabled = true
	env.ssr_enabled = true
	for l in lights:
		l.shadow_enabled = l.get_meta("sh")
	for g in [wy.get("voxel_hall"), wy.get("voxel_cellar")]:
		(g as Node3D).visible = true


func _log_state(shot: Dictionary) -> void:
	var parts := []
	for b in snap.get("blocks", []):
		var m = b.get("must")
		parts.append("%s:%s/%s%s" % [b["id"], b["training"], b["stage"], (" %d°Oe" % int(m["oe"])) if m is Dictionary else ""])
	var lots := []
	for l in snap.get("lots", []):
		lots.append("%s %s %s v%s" % [l["id"], l["variety"], l["phase"], str(l.get("choices", {}).get("Vessel", "-"))])
	print("  state: ", ", ".join(parts), " | lots: ", "; ".join(lots))
	var amb: Node = view.get("ambience")
	if amb:
		print("  sound: ", amb.call("debug_state"))


# ------------------------------------------------------------------ LOD probe (trellis bug)
## The picture at a place must not depend on the way you walked there. Walks the camera along an alley of
## the VSP Block (Block E) towards a vine and back again, looking along the rows, at 35° and across them,
## and compares the two frames at every step. With hysteresis on the vine LOD visibility ranges (the old
## visibility_range_end_margin = 1.0), whole 6 m cells of vines vanished next to the camera while walking
## towards them. `--trellis-old` puts the old margin back to show the bug.
func _trellis_probe() -> void:
	var shot: Dictionary = SHOTS[2]           # mosel_flowering (Block E = Guyot/VSP)
	snap = _play(shot)
	view.apply_snapshot(snap)
	view.set_view("vineyard")
	RenderingServer.global_shader_parameter_set("wind_strength", 0.0)
	var vy: Node3D = view.get("vineyard")
	var blk: Dictionary = vy.get("blocks")[4]
	if "--trellis-old" in OS.get_cmdline_user_args():
		for e in blk["mm"]:
			(e["mmi"] as GeometryInstance3D).visibility_range_end_margin = 1.0
	var f: Vector2 = blk["focus"]
	var u: Vector2 = vy.call("_row_dir", blk)
	var wv := Vector2(-u.y, u.x)
	var sp: Vector2 = vy.call("_spacing", blk)
	var path := []
	for k in 80:
		path.append(f + wv * sp.x * 0.5 - u * (24.0 - k * 0.3))
	var bad := 0
	var worst := 0.0
	var total := 0
	for look in [0.0, 0.6, 1.5]:
		var runs := []
		for dir in [1, -1]:
			view.set_camera(Vector3(0, 400, 0), Vector3(1, 400, 0))      # far away first: every LOD is "far"
			await _grab()
			var order := range(path.size()) if dir > 0 else range(path.size() - 1, -1, -1)
			var imgs := {}
			if dir < 0:                                                   # start the return walk from the far end
				for k in range(path.size() - 1, path.size() - 12, -1):
					_probe_cam(vy, path[k], u, wv, look)
					await _grab()
			for k in order:
				_probe_cam(vy, path[k], u, wv, look)
				imgs[k] = await _grab()
			runs.append(imgs)
		for k in path.size():
			var frac := _diff(runs[0][k], runs[1][k])
			total += 1
			worst = maxf(worst, frac)
			if frac > 0.01:
				bad += 1
				var out := ProjectSettings.globalize_path("res://shots/probe_lod_%d_%02d" % [int(look * 10), k])
				(runs[0][k] as Image).save_png(out + "_towards.png")
				(runs[1][k] as Image).save_png(out + "_away.png")
				print("PROBE look %.1f rad, %.1f m before the vine: %.2f %% of pixels differ" % [look, 24.0 - k * 0.3, frac * 100.0])
	print("PROBE %s: %d of %d frames depend on the walking direction (worst %.2f %%)" % ["PASS" if bad == 0 else "FAIL", bad, total, worst * 100.0])
	get_tree().quit()


func _probe_cam(vy: Node, c2: Vector2, u: Vector2, wv: Vector2, look: float) -> void:
	var p3 := Vector3(c2.x, float(vy.call("ground_height", c2.x, c2.y)) + 1.5, c2.y)
	var d3 := u * cos(look) + wv * sin(look)
	view.set_camera(p3, p3 + Vector3(d3.x, -0.35, d3.y))


func _grab() -> Image:
	for k in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return view.capture()


func _diff(a0: Image, b0: Image) -> float:
	var a := a0.duplicate() as Image
	var b := b0.duplicate() as Image
	a.resize(480, 270, Image.INTERPOLATE_BILINEAR)
	b.resize(480, 270, Image.INTERPOLATE_BILINEAR)
	var n := 0
	var tot := 0
	var w := a.get_width()
	var h := a.get_height()
	for y in h:
		for x in w:
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.25:
				n += 1
			tot += 1
	return float(n) / tot


# ------------------------------------------------------------------ walk test
## Walks the capsule controller (scripted direction, real physics) from the vineyard along the farm track, in at
## the hall door, through the hall, down the stairs into the barrel cellar and back up to the hall. Fails if it
## falls through the world (safety net used), gets stuck (no progress for 4 s) or ends up in the wrong place.
##   --walktest [mosel|cotedor|napa]
func _walk_test() -> void:
	var args := OS.get_cmdline_user_args()
	var which := "mosel"
	var i := args.find("--walktest")
	if i + 1 < args.size() and not args[i + 1].begins_with("--"):
		which = args[i + 1]
	var game: Dictionary = {"mosel": MOSEL, "cotedor": COTEDOR, "napa": NAPA,
		"terrassen": {"plotId": "mosel-terrassen", "plantingYear": 2012, "seed": 3},
		"napa-mountain": {"plotId": "napa-mountain", "plantingYear": 2012, "seed": 4}}[which]
	snap = _play({"game": game, "until": "winery" if which == "mosel" else "date:09-10"})
	view.apply_snapshot(snap)
	view.set_view("vineyard")
	var vy: Node3D = view.get("vineyard")
	var wy: Node3D = view.get("winery")
	var pl: CharacterBody3D = view.get("player")
	var est: Dictionary = vy.get("estate")
	var trk: Array = vy.get("track")
	var o: Vector3 = est["origin"]
	var door: Vector2 = est["door"]
	var b0: float = vy.get("band_x0")
	var hz: float = vy.get("hz")
	var pts := []                       # [name, global target (y ignored outside, used for the finish), radius]
	if est.get("steep", false):
		var top: Vector4 = trk[1]
		pts.append(["track top", Vector3(top.z, 0, top.w), 1.2])
		pts.append(["track bend", Vector3(top.x, 0, top.y), 1.2])
		pts.append(["yard", Vector3((trk[0] as Vector4).x, 0, (trk[0] as Vector4).y), 1.2])
	else:
		pts.append(["headland", Vector3(b0 - 3.0, 0, hz + 2.0), 1.2])
		pts.append(["track junction", Vector3(b0 - 3.0, 0, o.z), 1.2])
		pts.append(["yard", Vector3(door.x + 4.0, 0, o.z), 1.2])
	var B := func(x: float, y: float, z: float) -> Vector3: return wy.to_global(Vector3(x, y, z))
	var cx: Dictionary = (wy.get("B") as Dictionary)["cellarXform"]
	var co: Array = cx["origin"]
	var C := func(x: float, z: float) -> Vector3: return wy.to_global(Vector3(co[0] + z, co[1], co[2] - x))
	pts.append(["door", B.call(13.2, 0.0, 0.0), 0.7])
	pts.append(["in the hall", B.call(9.5, 0.0, 1.6), 0.7])
	pts.append(["hall, west end", B.call(-9.4, 0.0, 1.6), 0.6])
	pts.append(["stair top", B.call(-10.75, 0.0, 2.2), 0.45])
	pts.append(["on the stairs", B.call(-10.75, -1.5, -1.3), 0.45])
	pts.append(["stair bottom", B.call(-10.75, -5.25, -7.6), 0.45])
	pts.append(["cellar door", B.call(-10.75, -5.25, -9.3), 0.45])
	pts.append(["cellar", C.call(-7.0, 0.0), 0.7])
	pts.append(["cellar, far end", C.call(6.0, 0.0), 0.7])
	pts.append(["back to the door", C.call(-10.2, 0.0), 0.5])
	pts.append(["stair bottom (up)", B.call(-10.75, -5.25, -7.6), 0.45])
	pts.append(["stair top (up)", B.call(-10.75, 0.0, 1.9), 0.45])
	pts.append(["hall again", B.call(-6.0, 0.0, 1.6), 0.7])
	var t0 := Time.get_ticks_msec()
	var ok := true
	var log := []
	var game_t := 0.0
	for wp in pts:
		var target: Vector3 = wp[1]
		var rad: float = wp[2]
		var leg_t := 0.0
		var best := INF
		var best_t := 0.0
		while true:
			var p: Vector3 = pl.global_position
			var d := Vector2(target.x - p.x, target.z - p.z)
			if d.length() < rad:
				break
			pl.set("auto_dir", Vector3(d.x, 0, d.y))
			await get_tree().physics_frame
			leg_t += get_physics_process_delta_time()
			if d.length() < best - 0.25:
				best = d.length()
				best_t = leg_t
			if leg_t - best_t > 4.0 or leg_t > 240.0 or int(pl.get("rescues")) > 0:
				ok = false
				break
		game_t += leg_t
		var p2: Vector3 = pl.global_position
		var zn := String(wy.call("zone_at", wy.to_local(p2 + Vector3(0, 1.0, 0))))
		log.append("%s: %.1f s, at (%.1f, %.2f, %.1f), zone %s" % [wp[0], leg_t, p2.x, p2.y, p2.z, zn if zn != "" else "outside"])
		print("WALK ", log[-1])
		if not ok:
			print("WALK FAIL at '%s' (rescues %d)" % [wp[0], int(pl.get("rescues"))])
			break
	pl.set("auto_dir", Vector3.ZERO)
	if ok:
		var fin: Vector3 = pl.global_position
		var zn := String(wy.call("zone_at", wy.to_local(fin + Vector3(0, 1.0, 0))))
		ok = zn == "hall" and absf(fin.y - o.y) < 0.3
		print("WALK %s: %d legs in %.1f s of game time (%d ms wall), ended in zone '%s' at floor height %+.2f m" % [
			"PASS" if ok else "FAIL", pts.size(), game_t, Time.get_ticks_msec() - t0, zn, fin.y - o.y])
	# hiding the view (Tab back to the dashboard) must silence every looping sound and stop the walker
	var amb: Node = view.get("ambience")
	var loops: Array = amb.call("_players")
	var playing_before := loops.filter(func(p): return p.playing and not p.stream_paused).size()
	view.visible = false
	await get_tree().process_frame
	var still := loops.filter(func(p): return p.playing and not p.stream_paused).size()
	var quiet: bool = still == 0 and not bool(amb.get("running")) and not pl.is_physics_processing()
	print("SOUND %s: %d loops playing in the view, %d after hiding it" % ["PASS" if quiet and playing_before > 0 else "FAIL", playing_before, still])
	view.visible = true
	await get_tree().process_frame
	var again := loops.filter(func(p): return p.playing and not p.stream_paused).size()
	print("SOUND %s: %d loops playing again after showing it" % ["PASS" if again == playing_before else "FAIL", again])
	get_tree().quit()
