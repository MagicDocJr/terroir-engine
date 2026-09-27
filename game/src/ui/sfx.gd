# Dashboard sound effects, synthesised at start-up (no audio files, so no licensing): a soft click for buttons,
# a two-note confirmation, a small bell for Alerts, a cork pop at bottling and a wooden knock for harvest orders.
# Ambient sound lives in the 3D view.
extends Node

const RATE := 44100
var players: Dictionary = {}
var enabled := true
var volume_db := -8.0

func _ready() -> void:
	_load_settings()
	_add("click", _click())
	_add("confirm", _confirm())
	_add("alert", _bell())
	_add("cork", _cork())
	_add("harvest", _knock())
	_add("page", _page())

func play(name: String) -> void:
	if not enabled or not players.has(name): return
	var p: AudioStreamPlayer = players[name]
	p.volume_db = volume_db + (-10.0 if name == "click" or name == "page" else 0.0)
	p.play()

func toggle() -> bool:
	enabled = not enabled
	_save_settings()
	return enabled

func _add(name: String, samples: PackedFloat32Array) -> void:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var bytes := PackedByteArray(); bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	w.data = bytes
	var p := AudioStreamPlayer.new()
	p.stream = w
	add_child(p)
	players[name] = p

func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array(); b.resize(int(sec * RATE)); return b

func _click() -> PackedFloat32Array:
	var b := _buf(0.035)
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	for i in b.size():
		var t := float(i) / RATE
		var env := exp(-t * 180.0)
		b[i] = (0.5 * sin(TAU * 2100.0 * t) + 0.3 * rng.randf_range(-1, 1)) * env * 0.5
	return b

func _confirm() -> PackedFloat32Array:
	var b := _buf(0.26)
	for i in b.size():
		var t := float(i) / RATE
		var f := 660.0 if t < 0.09 else 990.0
		var t0 := t if t < 0.09 else t - 0.09
		var env := minf(1.0, t0 * 400.0) * exp(-t0 * 14.0)
		b[i] = (sin(TAU * f * t) + 0.25 * sin(TAU * 2.0 * f * t)) * env * 0.32
	return b

func _bell() -> PackedFloat32Array:
	# small bell: inharmonic partials (1, 2.76, 5.4) with fast attack and long decay, two strikes
	var b := _buf(1.4)
	for strike in [[0.0, 880.0], [0.18, 660.0]]:
		for i in b.size():
			var t: float = float(i) / RATE - float(strike[0])
			if t < 0: continue
			var f: float = strike[1]
			var env := minf(1.0, t * 800.0)
			b[i] += (sin(TAU * f * t) * exp(-t * 3.0) + 0.5 * sin(TAU * f * 2.76 * t) * exp(-t * 6.0) + 0.25 * sin(TAU * f * 5.4 * t) * exp(-t * 10.0)) * env * 0.22
	return b

func _cork() -> PackedFloat32Array:
	var b := _buf(0.18)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var prev := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1, 1)
		var hp := n - prev; prev = n                       # crude high-pass for the "pop"
		var pop := hp * exp(-t * 90.0) * 0.6
		var thump := sin(TAU * (220.0 - 400.0 * t) * t) * exp(-t * 30.0) * 0.5
		b[i] = (pop + thump) * 0.6
	return b

func _knock() -> PackedFloat32Array:
	var b := _buf(0.22)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (0.7 * sin(TAU * 180.0 * t) * exp(-t * 28.0) + 0.3 * sin(TAU * 420.0 * t) * exp(-t * 45.0) + 0.15 * rng.randf_range(-1, 1) * exp(-t * 120.0)) * 0.5
	return b

func _page() -> PackedFloat32Array:
	# soft paper-like swish for screen changes
	var b := _buf(0.12)
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lp * 0.85 + rng.randf_range(-1, 1) * 0.15
		b[i] = lp * sin(PI * t / 0.12) * 0.35
	return b

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		enabled = bool(cf.get_value("sound", "enabled", true))
		volume_db = float(cf.get_value("sound", "volume_db", -8.0))

func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("sound", "enabled", enabled)
	cf.set_value("sound", "volume_db", volume_db)
	cf.save("user://settings.cfg")
