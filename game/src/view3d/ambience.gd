# Ambient sound for the 3D Estate, per Region and place (spec §8.2). Only *plays* what the snapshot says:
#   outside  wind in the leaves (louder with the day's wind), birds by day in spring/summer (fewer in autumn,
#            none in winter or at night, quieter in rain), rain scaled by the day's rain, the Moselle's murmur
#            near the river, now and then a tractor in the neighbours' rows during the season
#   hall     bubbling + CO₂ puffs at tanks whose Lot is fermenting (softer in malolactic), the glycol chiller
#            hum, a must pump now and then while Lots ferment; outside sounds muffled through the walls
#   cellar   quiet room tone, the odd drip; outside inaudible
#   footsteps: soil/gravel outside, concrete/stone inside
# Sounds: game/assets3d/audio (game/tools/fetch_audio.py; CC0, credits in assets3d/audio/CREDITS.md).
# Mixing (game simplification): levels are set by ear-free rules of thumb, not measured sound levels.
extends Node3D

const A := preload("res://src/view3d/assets3d.gd")
const BUS := "View3D"
const BUS_OUT := "View3DOutside"
const BUS_ROOM := "View3DRoom"
const SILENT := -80.0

## Master volume of the 3D view's sound in dB (0 = as mixed). Also see `muted`.
var master_db := 0.0:
	set(v):
		master_db = v
		_apply_master()
var muted := false:
	set(v):
		muted = v
		_apply_master()

var running := false
var _snap := true                          # next update jumps straight to the target levels
var available := false
var zone := ""
var ctx := {"wind": 10.0, "rain": 0.0, "doy": 180, "day": true, "mist": 0.0}
var river_line := Vector3(INF, 0, 0)      # (z of the bank, water level y, unused)
var tractor_path := []                     # [Vector3 a, Vector3 b] in the neighbours' rows
var hum_pos := Vector3.ZERO
var pump_pos := Vector3.ZERO
var tanks := []                            # [[global position, weight]]
var cellar_xf := Transform3D()
var cellar_dims := Vector2(22, 6.2)

var beds := {}                             # name -> AudioStreamPlayer (non-positional loops)
var spots := {}                            # name -> AudioStreamPlayer3D (positional loops)
var bubbles: Array[AudioStreamPlayer3D] = []
var hiss: AudioStreamPlayer3D
var drip: AudioStreamPlayer3D
var steps: AudioStreamPlayer
var step_streams := {"soil": [], "concrete": []}
var drip_streams := []
var target := {}                           # name -> target volume_db
var t := 0.0
var next_tractor := 12.0
var tractor_t := -1.0
var next_pump := 20.0
var pump_t := -1.0
var next_hiss := 6.0
var next_drip := 3.0
var rng := RandomNumberGenerator.new()
var lowpass: AudioEffectLowPassFilter


func _ready() -> void:
	rng.seed = 1234
	_buses()
	available = A.exists("audio/wind_leaves.wav")
	if not available:
		push_warning("view3d: no ambience (run game/tools/sync_assets3d.sh audio)")
		return
	for n in ["wind_leaves", "birds_day", "rain"]:
		beds[n] = _bed(n, BUS_OUT)
	beds["cellar_tone"] = _bed("cellar_tone", BUS)
	spots["river"] = _spot("river", BUS_OUT, 14.0, 320.0, true)
	spots["tractor"] = _spot("tractor_distant", BUS_OUT, 14.0, 600.0, true)
	spots["hum"] = _spot("cooling_hum", BUS_ROOM, 3.0, 45.0, true)
	spots["pump"] = _spot("pump", BUS_ROOM, 2.5, 40.0, true)
	var bub := _wav("ferment_bubbling").duplicate() as AudioStreamWAV
	bub.loop_mode = AudioStreamWAV.LOOP_FORWARD
	for i in 8:
		var p := _spot_stream(bub, BUS_ROOM, 1.6, 22.0)
		p.name = "bubbles_%d" % i
		bubbles.append(p)
	hiss = _spot_stream(_wav("co2_hiss"), BUS_ROOM, 1.5, 20.0)
	drip = _spot_stream(null, BUS_ROOM, 2.0, 30.0)
	for i in 3:
		drip_streams.append(_wav("drip_%d" % i))
	for i in 5:
		step_streams["soil"].append(_wav("step_soil_%d" % i))
		step_streams["concrete"].append(_wav("step_concrete_%d" % i))
	steps = AudioStreamPlayer.new()
	steps.bus = BUS_OUT
	add_child(steps)
	for k in beds: target[k] = SILENT
	for k in spots: target[k] = SILENT
	_apply_master()


# ------------------------------------------------------------------ setup
func _buses() -> void:
	var master := _bus(BUS, "Master")
	var out := _bus(BUS_OUT, BUS)
	_bus(BUS_ROOM, BUS)
	if AudioServer.get_bus_effect_count(out) == 0:
		lowpass = AudioEffectLowPassFilter.new()
		lowpass.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(out, lowpass)
	else:
		lowpass = AudioServer.get_bus_effect(out, 0) as AudioEffectLowPassFilter
	var room := AudioServer.get_bus_index(BUS_ROOM)
	if AudioServer.get_bus_effect_count(room) == 0:
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.55
		rv.damping = 0.6
		rv.wet = 0.18
		rv.dry = 1.0
		AudioServer.add_bus_effect(room, rv)
	AudioServer.set_bus_volume_db(master, master_db)


static func _bus(name: String, send: String) -> int:
	var i := AudioServer.get_bus_index(name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
	AudioServer.set_bus_send(i, send)
	return i


func _apply_master() -> void:
	var i := AudioServer.get_bus_index(BUS)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, master_db)
		AudioServer.set_bus_mute(i, muted)


static var _cache := {}
## PCM WAV → AudioStreamWAV (parsed here: assets3d is not imported). Loops play forward over the whole file.
static func _wav(name: String) -> AudioStreamWAV:
	var rel := "audio/%s.wav" % name
	if _cache.has(rel):
		return _cache[rel]
	var b := FileAccess.get_file_as_bytes(A.path(rel))
	var s := AudioStreamWAV.new()
	if b.size() < 44 or b.slice(0, 4).get_string_from_ascii() != "RIFF":
		push_warning("view3d: bad wav " + rel)
		return s
	var pos := 12
	var ch := 1
	var rate := 44100
	var bits := 16
	var data := PackedByteArray()
	while pos + 8 <= b.size():
		var id := b.slice(pos, pos + 4).get_string_from_ascii()
		var n := b.decode_u32(pos + 4)
		if id == "fmt ":
			ch = b.decode_u16(pos + 10)
			rate = b.decode_u32(pos + 12)
			bits = b.decode_u16(pos + 22)
		elif id == "data":
			data = b.slice(pos + 8, pos + 8 + n)
		pos += 8 + n + (n & 1)
	s.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
	s.stereo = ch == 2
	s.mix_rate = rate
	s.data = data
	var frames := data.size() / (ch * bits / 8)
	s.loop_begin = 0
	s.loop_end = frames
	_cache[rel] = s
	return s


func _bed(name: String, bus: String) -> AudioStreamPlayer:
	var s := _wav(name).duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var p := AudioStreamPlayer.new()
	p.name = name
	p.stream = s
	p.bus = bus
	p.volume_db = SILENT
	add_child(p)
	return p


func _spot(name: String, bus: String, unit: float, max_d: float, loop: bool) -> AudioStreamPlayer3D:
	var s := _wav(name).duplicate() as AudioStreamWAV
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var p := _spot_stream(s, bus, unit, max_d)
	p.name = name
	return p


func _spot_stream(s: AudioStream, bus: String, unit: float, max_d: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = bus
	p.unit_size = unit
	p.max_distance = max_d
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.attenuation_filter_cutoff_hz = 6000.0
	p.attenuation_filter_db = -18.0
	p.volume_db = SILENT
	add_child(p)
	return p


# ------------------------------------------------------------------ state from view3d
## Snapshot-driven context: weather, date, the Moselle, the tractor's route, winery hum/pump/tank positions.
func configure(weather: Dictionary, river_z: float, river_y: float, tractor: Array, hum: Vector3, pump: Vector3, cellar_xform: Transform3D, cellar_size: Vector2) -> void:
	ctx["wind"] = float(weather.get("wind_kmh", 10.0))
	ctx["rain"] = float(weather.get("rain", 0.0))
	ctx["doy"] = int(weather.get("doy", 180))
	ctx["mist"] = float(weather.get("mist", 0.0))
	ctx["day"] = bool(weather.get("day", true))
	river_line = Vector3(river_z, river_y, 0.0)
	tractor_path = tractor
	hum_pos = hum
	pump_pos = pump
	cellar_xf = cellar_xform
	cellar_dims = cellar_size


func set_tanks(active: Array) -> void:
	tanks = active


## Jump to the right levels on the next update (after a teleport or when the view opens) instead of fading.
func snap() -> void:
	_snap = true


func set_running(on: bool) -> void:
	if on and not running:
		_snap = true
	running = on and available
	for p in _players():
		if running:
			if not p.playing and _loops(p):
				p.play(rng.randf() * 10.0)
			p.stream_paused = false
		else:
			p.stream_paused = true


func _players() -> Array:
	var out: Array = beds.values() + spots.values()
	out.append_array(bubbles)
	return out


static func _loops(p: Node) -> bool:
	var s: AudioStream = p.get("stream")
	return s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED


func footstep(speed: float) -> void:
	if not running:
		return
	var surf := "soil" if zone == "" else "concrete"
	var list: Array = step_streams[surf]
	steps.stream = list[rng.randi() % list.size()]
	steps.pitch_scale = rng.randf_range(0.9, 1.1)
	steps.volume_db = lerpf(-15.0, -8.0, clampf((speed - 1.2) / 3.0, 0.0, 1.0)) + (1.5 if surf == "concrete" else 0.0)
	steps.bus = BUS_OUT if zone == "" else BUS_ROOM
	steps.play()


# ------------------------------------------------------------------ mixing
## Birds: spring/summer by day; fewer in autumn; none in winter or at night; quieter in rain and fog.
func _bird_level() -> float:
	var d := int(ctx["doy"])
	var season := 0.0
	if d >= 95 and d <= 235:
		season = 1.0
	elif d > 235 and d <= 300:
		season = lerpf(1.0, 0.25, float(d - 235) / 65.0)
	elif d >= 60 and d < 95:
		season = lerpf(0.2, 1.0, float(d - 60) / 35.0)
	if not ctx["day"]:
		season = 0.0
	season *= 1.0 - 0.8 * float(ctx["rain"])
	season *= 1.0 - 0.4 * float(ctx["mist"])
	return SILENT if season < 0.03 else -13.0 + 20.0 * log(season) / log(10.0)


func update(delta: float, z: String, listener: Vector3, near_winery: bool) -> void:
	if not running:
		return
	t += delta
	zone = z
	var inside := z != ""
	var cellar := z == "cellar"
	# outside beds (through the walls: low-passed and quieter in the hall, gone in the cellar)
	var through := 0.0 if not inside else (-7.0 if not cellar else -60.0)
	lowpass.cutoff_hz = lerpf(lowpass.cutoff_hz, 20000.0 if not inside else 900.0, 1.0 if _snap else minf(1.0, delta * 4.0))
	var wind := clampf(float(ctx["wind"]) / 35.0, 0.0, 1.0)
	var gust := 2.5 * sin(t * 0.37) * sin(t * 0.13 + 1.0)
	target["wind_leaves"] = lerpf(-30.0, -11.0, wind) + gust + through
	target["birds_day"] = _bird_level() + through
	var rain := float(ctx["rain"])
	target["rain"] = (SILENT if rain < 0.02 else lerpf(-9.0, 1.0, rain) + (through + 5.0 if inside else 0.0))
	target["cellar_tone"] = -3.0 if cellar else (-26.0 if inside else SILENT)
	# the Moselle: a line source along the bank, heard from the nearest point
	var rv: AudioStreamPlayer3D = spots["river"]
	if river_line.x < INF:
		rv.global_position = Vector3(listener.x, river_line.y + 0.5, river_line.x + 3.0)
		target["river"] = 2.0 + through
	else:
		target["river"] = SILENT
	_tractor(delta, through)
	# hall: chiller hum always (louder with Lots in tanks), pump while fermenting, bubbling at active tanks
	var hall_on := near_winery or inside
	var fermenting := tanks.any(func(e): return float(e[1]) >= 0.9)
	(spots["hum"] as AudioStreamPlayer3D).global_position = hum_pos
	target["hum"] = ((2.0 if not tanks.is_empty() else -4.0) if hall_on else SILENT)
	_pump(delta, fermenting and hall_on)
	for i in bubbles.size():
		var p := bubbles[i]
		if i < tanks.size() and hall_on:
			p.global_position = tanks[i][0]
			var w: float = tanks[i][1]
			p.volume_db = lerpf(p.volume_db, 20.0 * log(maxf(w, 0.01)) / log(10.0) - 3.0, minf(1.0, delta * 2.0))
			if not p.playing:
				p.play(rng.randf() * 15.0)
				p.pitch_scale = rng.randf_range(0.9, 1.12)
		else:
			p.volume_db = lerpf(p.volume_db, SILENT, minf(1.0, delta * 2.0))
	next_hiss -= delta
	if next_hiss <= 0.0:
		next_hiss = rng.randf_range(5.0, 14.0)
		var ferm := tanks.filter(func(e): return float(e[1]) >= 0.9)
		if hall_on and not ferm.is_empty():
			hiss.global_position = ferm[rng.randi() % ferm.size()][0] + Vector3(0, 0.9, 0)
			hiss.volume_db = rng.randf_range(-9.0, -3.0)
			hiss.pitch_scale = rng.randf_range(0.85, 1.15)
			hiss.play()
	# cellar drips somewhere in the vault
	next_drip -= delta
	if next_drip <= 0.0:
		next_drip = rng.randf_range(3.0, 9.0)
		if cellar and not drip_streams.is_empty():
			var local := Vector3(rng.randf_range(-cellar_dims.x * 0.45, cellar_dims.x * 0.45), 0.02, rng.randf_range(-cellar_dims.y * 0.3, cellar_dims.y * 0.3))
			drip.global_position = cellar_xf * local
			drip.stream = drip_streams[rng.randi() % drip_streams.size()]
			drip.volume_db = rng.randf_range(-10.0, -2.0)
			drip.pitch_scale = rng.randf_range(0.92, 1.08)
			drip.play()
	# glide every loop towards its target level
	var dt := 1000.0 if _snap else delta
	_snap = false
	for k in beds:
		var p: AudioStreamPlayer = beds[k]
		p.volume_db = _glide(p.volume_db, target[k], dt)
	for k in spots:
		var p: AudioStreamPlayer3D = spots[k]
		p.volume_db = _glide(p.volume_db, target[k], dt)


static func _glide(v: float, to: float, delta: float) -> float:
	var rate := 18.0 if to > v else 30.0          # dB per second
	return move_toward(v, to, rate * delta)


func _tractor(delta: float, through: float) -> void:
	var p: AudioStreamPlayer3D = spots["tractor"]
	var d := int(ctx["doy"])
	var season := d >= 90 and d <= 290 and float(ctx["rain"]) < 0.05 and bool(ctx["day"])
	if tractor_t < 0.0:
		target["tractor"] = SILENT
		next_tractor -= delta
		if next_tractor <= 0.0:
			next_tractor = rng.randf_range(40.0, 110.0)
			if season and tractor_path.size() == 2:
				tractor_t = 0.0
		return
	tractor_t += delta
	var dur := 34.0
	var u := tractor_t / dur
	if u >= 1.0:
		tractor_t = -1.0
		return
	p.global_position = (tractor_path[0] as Vector3).lerp(tractor_path[1], u)
	var env := minf(1.0, minf(u * 5.0, (1.0 - u) * 5.0))
	target["tractor"] = 6.0 + 20.0 * log(maxf(env, 0.01)) / log(10.0) + through


func _pump(delta: float, allowed: bool) -> void:
	(spots["pump"] as AudioStreamPlayer3D).global_position = pump_pos
	if pump_t >= 0.0:
		pump_t += delta
		if pump_t > 24.0 or not allowed:
			pump_t = -1.0
		target["pump"] = -2.0 if pump_t >= 0.0 else SILENT
		return
	target["pump"] = SILENT
	next_pump -= delta
	if next_pump <= 0.0:
		next_pump = rng.randf_range(50.0, 120.0)
		if allowed:
			pump_t = 0.0


## What is playing, for the test log (text-verifiable): {name: volume_db} of audible players.
func debug_state() -> Dictionary:
	var out := {}
	for k in beds:
		if (beds[k] as AudioStreamPlayer).volume_db > -60.0: out[k] = snappedf(beds[k].volume_db, 0.1)
	for k in spots:
		if (spots[k] as AudioStreamPlayer3D).volume_db > -60.0: out[k] = snappedf(spots[k].volume_db, 0.1)
	var nb := 0
	for p in bubbles:
		if p.volume_db > -60.0: nb += 1
	if nb > 0: out["bubbling_tanks"] = nb
	out["zone"] = zone if zone != "" else "outside"
	out["targets"] = target.keys().filter(func(k): return float(target[k]) > -60.0)
	return out
