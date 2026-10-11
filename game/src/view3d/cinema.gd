# The intro cinematic (view3d.gd play_intro): a flight over the Region and the Estate the player has just bought, in
# golden-hour summer light, with letterbox bars, title cards, the narrator's voice and captions. Each shot is a camera
# move from vineyard.gd cinema_shots(); it lasts its own length or as long as its narration clip needs. Esc, Enter,
# Space or a click skips to the end. Look only: nothing here touches the simulation.
extends Control

signal finished
signal held                       # hold_last: the last shot has ended and the camera keeps drifting (release() ends it)

const UI := preload("res://src/ui/ui.gd")
const A := preload("res://src/view3d/assets3d.gd")
const FADE := 0.7                  # s, through black between shots
const BAR := 0.11                  # letterbox bar height, share of the screen

var cam: Camera3D
var ground_fn: Callable            # (x, z) -> ground height, to keep the eye above the land
var shots: Array = []
var i := -1
var t := 0.0
var playing := false
var skipping := false
var bars: Array = []
var black: ColorRect
var title: Label
var sub: Label
var caption: Label
var hint: Label
var voice: AudioStreamPlayer
var cap_lines: Array = []          # [[start s, text]] for the current shot
var hold_last := false             # the last shot does not end in black: the bars open and the camera drifts on
var holding := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for top in [true, false]:
		var b := ColorRect.new(); b.color = Color.BLACK; b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.anchor_right = 1.0
		if top:
			b.anchor_bottom = 0.0
		else:
			b.anchor_top = 1.0; b.anchor_bottom = 1.0
		add_child(b); bars.append(b)
	title = _label(UI.f_head, 64, Color(1.0, 0.96, 0.88))
	title.anchor_top = 0.62; title.anchor_bottom = 0.62
	sub = _label(UI.f_body, 22, Color(0.95, 0.88, 0.7))
	sub.anchor_top = 0.62; sub.anchor_bottom = 0.62; sub.offset_top = 78; sub.offset_bottom = 110
	title.offset_top = -4; title.offset_bottom = 76
	caption = _label(UI.f_body, 22, Color(0.96, 0.96, 0.94))
	caption.anchor_top = 1.0; caption.anchor_bottom = 1.0; caption.offset_top = -86; caption.offset_bottom = -18
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.offset_left = 220; caption.offset_right = -220
	hint = _label(UI.f_body, 14, Color(1, 1, 1, 0.45))
	hint.anchor_top = 0.0; hint.anchor_bottom = 0.0; hint.offset_top = 14; hint.offset_bottom = 34
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; hint.offset_right = -24
	hint.text = "Esc to skip"
	black = ColorRect.new(); black.color = Color.BLACK; black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	voice = AudioStreamPlayer.new(); voice.volume_db = 0.0; add_child(voice)
	visible = false
	set_process(false)


func _label(f: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 2); l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_right = 1.0
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## Black, before the world is built (the first build takes a few seconds).
func cover() -> void:
	visible = true
	black.color.a = 1.0
	(bars[0] as ColorRect).offset_bottom = 0.0
	(bars[1] as ColorRect).offset_top = 0.0


## shots: vineyard.gd cinema_shots() with, per shot, optional "title", "sub", "text" (captions) and "voice" (a file under
## game/assets3d). Emits finished when the last shot ends or the player skips.
func play(list: Array) -> void:
	shots = list
	for s in shots:
		var st = _stream(String(s.get("voice", "")))
		s["stream"] = st
		if st != null:
			s["dur"] = maxf(float(s["dur"]), (st as AudioStream).get_length() + 1.6)
	print("cinema: %d of %d shots narrated" % [shots.filter(func(x): return x["stream"] != null).size(), shots.size()])
	visible = true
	playing = true
	skipping = false
	var h := get_viewport_rect().size.y
	var tw := create_tween().set_parallel(true)
	tw.tween_property(bars[0], "offset_bottom", h * BAR, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bars[1], "offset_top", -h * BAR, 1.2).set_trans(Tween.TRANS_SINE)
	_start(0)
	set_process(true)


## The flight is over but the view stays: the bars open, titles and captions go, and the camera drifts on.
func _hold() -> void:
	holding = true
	caption.text = ""
	cap_lines = []
	var tw := create_tween().set_parallel(true)
	tw.tween_property(bars[0], "offset_bottom", 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bars[1], "offset_top", 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(hint, "modulate:a", 0.0, 0.8)
	held.emit()


## Ends a held view: fades to black and finishes (the game takes over behind the black).
func release() -> void:
	if not playing:
		return
	skipping = true
	_end()


func skip() -> void:
	if not playing or skipping:
		return
	if holding:
		release()
		return
	skipping = true
	voice.stop()
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, 0.4)
	tw.tween_callback(_end)


func _start(n: int) -> void:
	i = n
	t = 0.0
	var s: Dictionary = shots[i]
	_place(0.0)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 0.0, FADE)
	for l in [title, sub]: (l as Label).modulate.a = 0.0
	title.text = String(s.get("title", ""))
	sub.text = String(s.get("sub", ""))
	if title.text != "":
		var tt := create_tween()
		tt.tween_interval(1.0)
		tt.tween_property(title, "modulate:a", 1.0, 1.4)
		tt.parallel().tween_property(sub, "modulate:a", 1.0, 1.8)
		tt.tween_interval(maxf(1.5, float(s["dur"]) - 6.5))
		tt.tween_property(title, "modulate:a", 0.0, 1.2)
		tt.parallel().tween_property(sub, "modulate:a", 0.0, 1.2)
	# captions: the narration's sentences, each shown for its share of the clip
	cap_lines = []
	var text := String(s.get("text", ""))
	if text != "":
		var parts := _sentences(text)
		var total := 0
		for p in parts: total += (p as String).length()
		var span: float = (s["stream"] as AudioStream).get_length() if s["stream"] != null else float(s["dur"]) - 2.0
		var at := 0.8
		for p in parts:
			cap_lines.append([at, p])
			at += span * float((p as String).length()) / float(maxi(total, 1))
	caption.text = ""
	caption.modulate.a = 1.0
	voice.stop()
	if s["stream"] != null:
		voice.stream = s["stream"]
		var tv := create_tween(); tv.tween_interval(0.8); tv.tween_callback(voice.play)


func _sentences(text: String) -> Array:
	var out := []
	var cur := ""
	for ch in text:
		cur += ch
		if ch in [".", "?", "!"] and cur.strip_edges().length() > 18:
			out.append(cur.strip_edges()); cur = ""
	if cur.strip_edges() != "": out.append(cur.strip_edges())
	# pair short sentences so a caption is one or two lines
	var merged := []
	for p in out:
		if not merged.is_empty() and ((merged[-1] as String).length() + (p as String).length()) < 110:
			merged[-1] = String(merged[-1]) + " " + String(p)
		else:
			merged.append(p)
	return merged


func _process(delta: float) -> void:
	if not playing or i < 0:
		return
	t += delta
	var s: Dictionary = shots[i]
	var d: float = s["dur"]
	_place(clampf(t / d, 0.0, 1.0) if not holding else 1.0)
	var line := ""
	for c in cap_lines:
		if t >= float(c[0]): line = String(c[1])
	caption.text = line
	if not skipping and not holding and t >= d - FADE and black.color.a < 0.01 and i < shots.size() - 1:
		var tw := create_tween()
		tw.tween_property(black, "color:a", 1.0, FADE)
	if t >= d and not skipping and not holding:
		if i < shots.size() - 1:
			_start(i + 1)
		elif hold_last:
			_hold()
		else:
			skipping = true
			_end()


## The eye for progress u (0..1) through the current shot: an eased line or orbit, never below the ground.
func _place(u: float) -> void:
	var s: Dictionary = shots[i]
	var e := u * u * (3.0 - 2.0 * u) * 0.65 + u * 0.35         # mostly eased, never quite still
	var p: Vector3
	var tg: Vector3
	if String(s["kind"]) == "orbit":
		var a := lerpf(float(s["a0"]), float(s["a1"]), e)
		if holding:                                     # past its end: keep turning at the shot's final pace
			a = float(s["a1"]) + float(s.get("drift", 0.0)) * (t - float(s["dur"]))
		var r := lerpf(float(s["r0"]), float(s["r1"]), e)
		var c: Vector3 = s["c"]
		p = c + Vector3(sin(a) * r, lerpf(float(s["h0"]), float(s["h1"]), e), cos(a) * r)
		if s.get("above_ground", false) and ground_fn.is_valid():     # the height is over the ground beneath the eye
			p.y = maxf(p.y, float(ground_fn.call(p.x, p.z)) + lerpf(float(s["h0"]), float(s["h1"]), e))
		tg = c
	else:
		p = (s["p0"] as Vector3).lerp(s["p1"], e)
		tg = (s["t0"] as Vector3).lerp(s["t1"], e)
	if ground_fn.is_valid():
		p.y = maxf(p.y, float(ground_fn.call(p.x, p.z)) + (1.6 if i == shots.size() - 1 else 4.0))
	cam.global_position = p
	if p.distance_to(tg) > 0.01:
		cam.look_at(tg, Vector3.UP)


func _end() -> void:
	playing = false
	holding = false
	set_process(false)
	voice.stop()
	caption.text = ""
	for l in [title, sub]: (l as Label).modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, 0.9)        # fade out; the game takes over behind the black
	tw.tween_callback(func():
		finished.emit()
		visible = false
		(bars[0] as ColorRect).offset_bottom = 0.0
		(bars[1] as ColorRect).offset_top = 0.0)


## A narration clip under game/assets3d (mp3, ogg or wav), or null when it has not been recorded.
func _stream(rel: String) -> Variant:
	if rel == "":
		return null
	for ext in ["mp3", "ogg", "wav"]:
		var path := A.path("%s.%s" % [rel, ext])
		if not FileAccess.file_exists(path):
			continue
		match ext:
			"mp3":
				var m := AudioStreamMP3.new(); m.data = FileAccess.get_file_as_bytes(path); return m
			"ogg":
				return AudioStreamOggVorbis.load_from_file(path)
			"wav":
				return AudioStreamWAV.load_from_file(path)
	return null
