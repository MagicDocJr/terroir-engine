# Headless-ish test harness for the 3D views: plays real games through the Sim autoload, feeds the snapshots to
# view3d and captures 1920×1080 screenshots into game/shots/3d_<name>.png.
#
#   godot --path game res://src/view3d/view3d_test.tscn -- --capture3d [name,name,...] [--perf]
#   (see game/tools/shot3d.sh). Without --capture3d the scene just opens a Mosel game for manual testing.
extends Node

const View3D := preload("res://src/view3d/view3d.tscn")

# Planting used for the Mosel shots: four Einzelpfahl Blocks and one Guyot (VSP) Block, one of them Pinot Noir
const MOSEL := {"plotId": "mosel-blauschiefer", "plantingYear": 2012, "seed": 42, "estateName": "Weingut Schieferhang", "planting": {
	"A": {"variety": "Riesling", "rootstock": "SO4", "training": "Einzelpfahl", "density": 8000},
	"B": {"variety": "Riesling", "rootstock": "SO4", "training": "Einzelpfahl", "density": 8000},
	"C": {"variety": "Riesling", "rootstock": "R3309C", "training": "Einzelpfahl", "density": 8000},
	"D": {"variety": "PinotNoir", "rootstock": "SO4", "training": "Einzelpfahl", "density": 8000},
	"E": {"variety": "Riesling", "rootstock": "SO4", "training": "Guyot", "density": 5000, "rows": "DownSlope"}}}

const COTEDOR := {"plotId": "cotedor-premiercru", "plantingYear": 2012, "seed": 7, "estateName": "Domaine des Pierres"}
const NAPA := {"plotId": "napa-bench", "plantingYear": 2012, "seed": 9, "estateName": "Stonefield Cellars"}

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
	{"name": "mosel_estate", "game": MOSEL, "until": "winery", "dry": true, "view": "vineyard", "cam": "estate"},
	{"name": "mosel_estate_high", "game": MOSEL, "until": "winery", "dry": true, "view": "vineyard", "cam": "estate_high"},
	{"name": "mosel_track", "game": MOSEL, "until": "winery", "dry": true, "view": "vineyard", "cam": "track"},
	{"name": "mosel_door", "game": MOSEL, "until": "winery", "view": "hall", "cam": "door"},
	{"name": "mosel_yard", "game": MOSEL, "until": "winery", "dry": true, "view": "hall", "cam": "yard"},
	{"name": "mosel_leanto", "game": MOSEL, "until": "winery", "dry": true, "view": "hall", "cam": "yard_leanto"},
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
	{"name": "cotedor_yard", "game": COTEDOR, "until": "date:08-16", "dry": true, "view": "hall", "cam": "yard"},
	{"name": "cotedor_track", "game": COTEDOR, "until": "date:08-16", "dry": true, "view": "vineyard", "cam": "track"},
	{"name": "cotedor_hall", "game": COTEDOR, "until": "date:08-16", "dry": true, "view": "hall", "cam": "hall"},
	{"name": "napa_estate", "game": NAPA, "until": "date:09-12", "dry": true, "view": "vineyard", "cam": "estate"},
	{"name": "napa_estate_high", "game": NAPA, "until": "date:09-12", "dry": true, "view": "vineyard", "cam": "estate_high"},
	{"name": "napa_yard", "game": NAPA, "until": "date:09-12", "dry": true, "view": "hall", "cam": "yard"},
	{"name": "napa_track", "game": NAPA, "until": "date:09-12", "dry": true, "view": "vineyard", "cam": "track"},
	{"name": "mosel_drone", "game": MOSEL, "until": "winery", "dry": true, "view": "drone", "cam": "drone"},
	{"name": "cotedor_drone", "game": COTEDOR, "until": "date:08-16", "dry": true, "view": "drone", "cam": "drone"},
	{"name": "napa_drone", "game": NAPA, "until": "date:09-12", "dry": true, "view": "drone", "cam": "drone"},
	{"name": "napa_cellar", "game": NAPA, "until": "date:09-12", "dry": true, "view": "cellar", "cam": "cellar"},
	# people at work (workers.gd): harvest crews, machine harvest, sorting table, sprayer, pruning, canopy work
	{"name": "mosel_harvest_crew", "game": MOSEL, "until": "picking:E:hand:Table:0", "view": "vineyard", "cam": "crew"},
	{"name": "mosel_harvest_late", "game": MOSEL, "until": "picking:B:hand:Table:90", "view": "vineyard", "cam": "crew"},
	{"name": "mosel_harvest_wide", "game": MOSEL, "until": "picking:E:hand:Table:0", "view": "vineyard", "cam": "estate_high"},
	{"name": "mosel_sorting", "game": MOSEL, "until": "picking:E:hand:Table:0", "view": "vineyard", "cam": "sorting"},
	{"name": "cotedor_harvest_crew", "game": COTEDOR, "until": "picking:A:hand:Rigorous:0", "view": "vineyard", "cam": "crew"},
	{"name": "cotedor_sorting", "game": COTEDOR, "until": "picking:A:hand:Rigorous:0", "view": "vineyard", "cam": "sorting"},
	{"name": "napa_harvest_machine", "game": NAPA, "until": "picking:B:machine:None:0", "view": "vineyard", "cam": "crew"},
	{"name": "napa_harvest_crew", "game": NAPA, "until": "picking:C:hand:Table:0:High", "view": "vineyard", "cam": "crew"},
	{"name": "mosel_pruning", "game": MOSEL, "until": "date:02-12", "view": "vineyard", "cam": "crew"},
	{"name": "cotedor_canopy", "game": COTEDOR, "until": "date:06-12", "view": "vineyard", "cam": "crew"},
	{"name": "mosel_spray", "game": MOSEL, "until": "spray", "view": "vineyard", "cam": "crew"},
	{"name": "cotedor_spray", "game": COTEDOR, "until": "spray", "view": "vineyard", "cam": "crew"},
	{"name": "napa_spray", "game": NAPA, "until": "spray", "view": "vineyard", "cam": "crew"},
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
	if "--tasktest" in args:
		_task_test()
		return
	var i := args.find("--capture3d")
	if i < 0:
		_manual()
		return
	perf = "--perf" in args
	if "--trellis" in args:
		_trellis_probe()
		return
	if "--pickrates" in args:
		_pick_rates()
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
	elif until.begins_with("picking:"):
		# picking:<Block>:<hand|machine>:<None|Table|Rigorous>:<pct> — order the harvest once the Block is in its
		# window, then advance until the crew has picked at least pct % (stops a day early if it would finish)
		var a := until.split(":")
		if a.size() > 5:
			Sim.Command("programme", "labour", a[5], "", "", "")          # crew size (Low = 8 pickers)
		while guard < 400 and not _block(s, a[1]).get("inWindow", false):
			Sim.Advance(1, false); guard += 1
			s = _snap()
		Sim.Command("harvest", a[1], a[2], a[3], "", "")
		guard = 0
		while guard < 30:
			s = _snap()
			var b := _block(s, a[1])
			if float(b.get("pickedPct", 0)) >= float(a[4]) or not b.get("picking", false):
				break
			Sim.Advance(1, false); guard += 1
		print("  picking %s (%.2f ha): %s %% after %d day(s), picking=%s" % [a[1], float(_block(_snap(), a[1]).get("area", 0)), str(_block(_snap(), a[1]).get("pickedPct")), guard, str(_block(_snap(), a[1]).get("picking"))])
	elif until == "spray":
		# the first day a spray pass is booked in any Block (daysSinceSpray == 0)
		while guard < 400:
			var hit := false
			for b in s["blocks"]:
				hit = hit or (b.get("daysSinceSpray") != null and int(b["daysSinceSpray"]) <= 1)
			if hit:
				break
			Sim.Advance(1, false); guard += 1
			s = _snap()
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
		var key := JSON.stringify(shot["game"]) + String(shot["until"]) + str(shot.get("extra", 0)) + str(shot.get("harvest", [])) + str(shot.get("dry", false))
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
	var wk: Node = view.get("workers")
	if wk and String(wk.get("summary")) != "":
		print("  at work: ", wk.get("summary"), " (", wk.get("people").size(), " people)")
		if "--debug-workers" in OS.get_cmdline_user_args():
			for m in wk.get("machines"):
				print("  machine at ", (m["node"] as Node3D).global_position, " visible ", (m["node"] as Node3D).is_visible_in_tree(), " span ", m["span"], " w ", m["w"])
			for n in wk.get("shown"):
				print("  shown ", (n as MeshInstance3D).mesh.resource_name, " ", n.name, " at ", (n as Node3D).global_position)
			var mm: MultiMesh = wk.get("mm")
			print("  people mm: visible ", mm.visible_instance_count, " mesh surfaces ", mm.mesh.get_surface_count(), " aabb ", mm.mesh.get_aabb(),
				" first ", mm.get_instance_transform(0).origin, " custom ", mm.get_instance_custom_data(0), " cam ", (view.get("player") as Node).get("cam").global_position)


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
	# a drone flight first (key 4 on, fly, 4 off): walking must carry on from the same spot afterwards
	var before: Vector3 = pl.global_position
	view.set_view("drone")
	for f in 30:
		await get_tree().physics_frame
	view.call("_drone_off", true)
	for f in 10:
		await get_tree().physics_frame
	print("WALK drone round trip: walker moved %.2f m, drone camera current: %s" % [pl.global_position.distance_to(before), str((view.get("drone_cam") as Camera3D).current)])
	# leave the 3D view and come back without set_view (the UI keeps the place): drone and walker must resume
	var mid: Vector3 = pl.global_position
	view.set_view("drone")
	var dpos: Vector3 = (view.get("drone_cam") as Camera3D).global_position
	view.visible = false
	for f in 10:
		await get_tree().process_frame
	view.visible = true
	for f in 10:
		await get_tree().physics_frame
	var drone_ok: bool = view.get("drone") and (view.get("drone_cam") as Camera3D).current and (view.get("drone_cam") as Camera3D).global_position.distance_to(dpos) < 0.5
	view.call("_drone_off", true)
	for f in 10:
		await get_tree().physics_frame
	var walk_ok: bool = pl.global_position.distance_to(mid) < 0.3 and pl.cam.current and bool(pl.get("enabled"))
	print("RESUME %s: drone kept across hide/show: %s, walker back at its spot (%.2f m) with input on: %s, sound running: %s" % [
		"PASS" if drone_ok and walk_ok and bool(view.get("ambience").get("running")) else "FAIL", str(drone_ok), pl.global_position.distance_to(mid), str(walk_ok), str(view.get("ambience").get("running"))])
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


## Diagnostic: how fast real crews pick each Block (pickedPct per day after the order), per Plot and labour tier.
func _pick_rates() -> void:
	var plots := ["mosel-blauschiefer", "mosel-terrassen", "mosel-seitental", "cotedor-premiercru", "cotedor-plaine", "napa-bench", "napa-mountain", "napa-floor"]
	for pid in plots:
		for lab in ["Low", "High"]:
			Sim.NewGame(JSON.stringify({"plotId": pid, "plantingYear": 2012, "seed": 5}))
			Sim.Command("programme", "labour", lab, "", "", "")
			var s := _snap()
			var g := 0
			while g < 400 and not s["blocks"].any(func(b): return b.get("inWindow", false)):
				Sim.Advance(1, false); g += 1
				s = _snap()
			var ids := []
			for b in s["blocks"]:
				if b.get("inWindow", false):
					ids.append([b["id"], float(b.get("area", 0))])
			var line := "PICK %s %s:" % [pid, lab]
			for e in ids:
				Sim.Command("harvest", e[0], "hand", "Table", "", "")
			var days := []
			for d in 4:
				Sim.Advance(1, false)
				var row := []
				for e in ids:
					row.append(str(_block(_snap(), e[0]).get("pickedPct")) + ("" if _block(_snap(), e[0]).get("picking", false) else "✓"))
				days.append(" ".join(row))
			print(line, " blocks ", ids, " | ", " / ".join(days))
	get_tree().quit()


# ------------------------------------------------------------------ staff tasks (--tasktest)
var _chosen := []

func _frames(n: int) -> void:
	for f in n:
		await get_tree().process_frame


func _save_shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var out := ProjectSettings.globalize_path("res://shots/3d_%s.png" % name)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	view.capture().save_png(out)
	print("  saved ", out)


func _open_task(kind: String) -> Dictionary:
	for t in snap.get("tasks", []):
		if String(t["kind"]) == kind and String(t["status"]) == "Open":
			return t
	return {}


## Walks through one task: focus → E → choose → confirm → command → check. Returns true on success.
func _do_task(kind: String, value: String, timing: String, check: Callable) -> bool:
	var t := _open_task(kind)
	if t.is_empty():
		print("TASKTEST FAIL %s: no open task" % kind); return false
	var id := int(t["id"])
	view.apply_snapshot(snap)
	if String(t["where"]) == "hall":
		view.set_view("hall")
	await _frames(20)
	view.focus_task(id)
	await _frames(30)
	var near: Dictionary = view.get("tasks3d").call("nearest", (view.get("player") as Node3D).global_position, 2.5)
	if near.is_empty() or int(near["id"]) != id:
		print("TASKTEST FAIL %s: walker not at the marker" % kind); return false
	await _save_shot("task_%s_marker" % kind.to_lower())
	if not view.call("_interact") or int(view.get("closeup_id")) != id:
		print("TASKTEST FAIL %s: close-up did not open" % kind); return false
	await _frames(90)
	await _save_shot("task_%s_closeup" % kind.to_lower())
	view.call("_choose", value)
	await _frames(20)
	await _save_shot("task_%s_chosen" % kind.to_lower())
	_chosen.clear()
	view.call("_confirm")
	var guard := 0
	while _chosen.is_empty() and guard < 240:
		await get_tree().process_frame; guard += 1
	if _chosen.is_empty() or int(_chosen[0][0]) != id or String(_chosen[0][1]) != value:
		print("TASKTEST FAIL %s: no task_chosen signal (%s)" % [kind, str(_chosen)]); return false
	Sim.Command("task", str(id), "do", value, timing, "")
	snap = _snap()
	view.apply_snapshot(snap)
	var ok: bool = check.call(snap)
	print("TASKTEST %s %s" % [kind, "ok" if ok else "FAIL: setting not applied"])
	return ok


func _task_test() -> void:
	view.task_chosen.connect(func(id, value, timing): _chosen.append([id, value, timing]))
	var ok := true
	# pruning, leaf removal and green harvest on a Mosel Guyot Plot
	Sim.NewGame(JSON.stringify({"plotId": "mosel-seitental", "plantingYear": 2016, "seed": 5, "estateName": "Task Test"}))
	snap = _snap()
	view.apply_snapshot(snap)
	view.set_view("vineyard")
	await _frames(60)
	var first := _open_task("Prune")
	ok = await _do_task("Prune", "Low", "", func(s): return String(_block(s, String(first["block"])).get("budLoad", "")) == "Low") and ok
	# E with no task in reach does nothing; leaving the 3D view closes a close-up without deciding
	view.set_view("hall")
	await _frames(20)
	var none_ok: bool = not view.call("_interact") and int(view.get("closeup_id")) == -1
	print("TASKTEST no_task_no_closeup %s" % ("ok" if none_ok else "FAIL"))
	ok = ok and none_ok
	var second := _open_task("Prune")
	view.set_view("vineyard")
	view.focus_task(int(second["id"]))
	await _frames(20)
	view.call("_interact")
	await _frames(10)
	_chosen.clear()
	view.visible = false
	await _frames(10)
	var tab_ok: bool = int(view.get("closeup_id")) == -1 and _chosen.is_empty() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	view.visible = true
	print("TASKTEST tab_leaves_closeup %s" % ("ok" if tab_ok else "FAIL"))
	ok = ok and tab_ok
	var guard := 0
	while _open_task("LeafRemoval").is_empty() and guard < 300:
		Sim.Advance(3, false); snap = _snap(); guard += 1
	var lt := _open_task("LeafRemoval")
	ok = await _do_task("LeafRemoval", "Morning", "", func(s): return String(_block(s, String(lt["block"])).get("leafSide", "")) == "Morning") and ok
	guard = 0
	while _open_task("GreenHarvest").is_empty() and guard < 300:
		Sim.Advance(3, false); snap = _snap(); guard += 1
	var gt := _open_task("GreenHarvest")
	ok = await _do_task("GreenHarvest", "2", "", func(s): return int(_block(s, String(gt["block"])).get("thinning", 0)) == 2) and ok
	# the crew at work after a decision
	view.camera_preset("crew")
	await _frames(60)
	await _save_shot("task_crew")
	# cap management on a red Lot (Côte d'Or Pinot Noir)
	Sim.NewGame(JSON.stringify({"plotId": "cotedor-village", "plantingYear": 2013, "seed": 5, "estateName": "Task Test"}))
	snap = _snap()
	guard = 0
	while guard < 400:
		var inwin := false
		for b in snap["blocks"]:
			inwin = inwin or (b.get("inWindow", false) and b.get("red", false))
		if inwin:
			break
		Sim.Advance(2, false); snap = _snap(); guard += 1
	for b in snap["blocks"]:
		if b.get("red", false): Sim.Command("harvest", String(b["id"]), "hand", "Table", "", "")
	guard = 0
	while _open_task("CapManagement").is_empty() and guard < 60:
		Sim.Advance(1, false); snap = _snap(); guard += 1
	var ct := _open_task("CapManagement")
	ok = await _do_task("CapManagement", "1", "", func(s):
		for l in s.get("lots", []):
			if String(l["id"]) == String(ct["lot"]): return int(l["choices"].get("Cap management", -1)) == 1
		return false) and ok
	print("TASKTEST %s" % ("ok" if ok else "FAIL"))
	get_tree().quit()

