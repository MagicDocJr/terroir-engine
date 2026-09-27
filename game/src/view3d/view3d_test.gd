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

const SHOTS := [
	{"name": "mosel_budburst", "game": MOSEL, "until": "stage:Budburst", "extra": 6, "dry": true, "view": "vineyard", "cam": "row", "block": 1},
	{"name": "mosel_budburst_close", "game": MOSEL, "until": "stage:Budburst", "extra": 6, "dry": true, "view": "vineyard", "cam": "close", "block": 1},
	{"name": "mosel_flowering", "game": MOSEL, "until": "stage:Flowering", "extra": 3, "dry": true, "view": "vineyard", "cam": "row", "block": 4},
	{"name": "mosel_veraison", "game": MOSEL, "until": "stage:Veraison", "extra": 12, "dry": true, "view": "vineyard", "cam": "close", "block": 3},
	{"name": "mosel_harvest", "game": MOSEL, "until": "window", "extra": 0, "harvest": ["A"], "after": 1, "dry": true, "view": "vineyard", "cam": "close", "block": 4},
	{"name": "mosel_harvest_overview", "game": MOSEL, "until": "window", "extra": 0, "harvest": ["A"], "after": 1, "dry": true, "view": "vineyard", "cam": "overview"},
	{"name": "mosel_leaffall", "game": MOSEL, "until": "stage:LeafFall", "extra": 12, "dry": true, "view": "vineyard", "cam": "row", "block": 4},
	{"name": "cotedor_winter", "game": {"plotId": "cotedor-premiercru", "plantingYear": 2012, "seed": 7}, "until": "date:02-10", "dry": true, "view": "vineyard", "cam": "row", "block": 1},
	{"name": "cotedor_august", "game": {"plotId": "cotedor-premiercru", "plantingYear": 2012, "seed": 7}, "until": "date:08-16", "dry": true, "view": "vineyard", "cam": "row", "block": 0},
	{"name": "napa_september", "game": {"plotId": "napa-bench", "plantingYear": 2012, "seed": 9}, "until": "date:09-12", "dry": true, "view": "vineyard", "cam": "row", "block": 1},
	{"name": "cellar", "game": MOSEL, "until": "winery", "view": "cellar", "cam": "cellar"},
	{"name": "cellar_labels", "game": MOSEL, "until": "winery", "view": "cellar", "cam": "cellar_heads"},
	{"name": "hall", "game": MOSEL, "until": "winery", "view": "hall", "cam": "hall"},
	{"name": "hall_panel", "game": MOSEL, "until": "winery", "view": "hall", "cam": "hall_panel"},
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
	var i := args.find("--capture3d")
	if i < 0:
		_manual()
		return
	perf = "--perf" in args
	if "--trellis" in args:
		_trellis_probe()
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
			if "--breakdown" in OS.get_cmdline_user_args() and shot["view"] == "vineyard":
				await _breakdown()
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
	var vy: Node3D = view.get("vineyard")
	var env: Environment = vy.get("env")
	var sun: DirectionalLight3D = vy.get("sun")
	var out := {}
	env.ssil_enabled = false
	out["no_ssil"] = await _fps()
	env.ssr_enabled = false
	env.ssao_enabled = false
	out["no_ssil_ssr_ssao"] = await _fps()
	sun.shadow_enabled = false
	out["+no_sun_shadow"] = await _fps()
	view.get("viewport").msaa_3d = Viewport.MSAA_DISABLED
	out["+no_msaa"] = await _fps()
	for n in vy.get("world").get_children():
		if n is MultiMeshInstance3D and n.visibility_range_end > 0.0 and n.visibility_range_end <= 5.0:
			n.visible = false      # vines at LOD0 (nearest cells)
	out["+no_lod0"] = await _fps()
	print("  breakdown ", out)
	env.ssil_enabled = true; env.ssr_enabled = true; env.ssao_enabled = true
	sun.shadow_enabled = true
	view.get("viewport").msaa_3d = Viewport.MSAA_2X
	for n in vy.get("world").get_children():
		if n is MultiMeshInstance3D:
			n.visible = true


func _log_state(shot: Dictionary) -> void:
	var parts := []
	for b in snap.get("blocks", []):
		var m = b.get("must")
		parts.append("%s:%s/%s%s" % [b["id"], b["training"], b["stage"], (" %d°Oe" % int(m["oe"])) if m is Dictionary else ""])
	var lots := []
	for l in snap.get("lots", []):
		lots.append("%s %s %s v%s" % [l["id"], l["variety"], l["phase"], str(l.get("choices", {}).get("Vessel", "-"))])
	print("  state: ", ", ".join(parts), " | lots: ", "; ".join(lots))


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
