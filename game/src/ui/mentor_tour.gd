# The Mentor's tour after the intro flight (shell.gd play_intro): a few spoken lines that bridge from the sunset over the
# Estate to the dashboard, each with a spotlight on the part it talks about (the Inbox, the menu, the Mentor's plan, the
# time controls, the 3D button). Lines and their targets come from game/src/view3d/intro.json "tour"; the voice from
# game/assets3d/audio/voice/tour_<id>.mp3. Next (Enter/Space) goes on, Skip tour (Esc) ends it; a line moves on by itself
# shortly after the voice ends. It blocks clicks on the game while it runs. Look only.
extends Control

signal step_done
signal skipped

const UI := preload("res://src/ui/ui.gd")
const A := preload("res://src/view3d/assets3d.gd")
const Avatar := preload("res://src/ui/avatar.gd")

var target_fn: Callable            # (target name) -> Rect2 in this control's coordinates (empty Rect2 = no spotlight)
var target := ""
var dim := 0.0                     # darkness outside the spotlight, eased
var dim_want := 0.0
var t := 0.0
var card: PanelContainer
var text_l: Label
var step_l: Label
var next_b: Button
var voice: AudioStreamPlayer
var auto_left := -1.0
var done := false
var is_skipped := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.sb(Color(0.08, 0.10, 0.12, 0.94), 10, UI.GOLD.darkened(0.25), 1, 18))
	card.custom_minimum_size = Vector2(720, 0)
	card.modulate.a = 0.0
	add_child(card)
	var h := UI.hbox(16); card.add_child(h)
	var av: Control = Avatar.make(String(get_meta("mentor", "The Mentor")), "mentor", 64)
	av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(av)
	var v := UI.vbox(8); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(v)
	v.add_child(UI.label("THE MENTOR · %s" % String(get_meta("mentor", "")), 12, UI.GOLD, UI.f_body_b))
	text_l = UI.label("", 18, UI.INK, null, true)
	text_l.custom_minimum_size = Vector2(560, 0)
	v.add_child(text_l)
	var row := UI.hbox(10); v.add_child(row)
	step_l = UI.label("", 13, UI.MUTED); step_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER; row.add_child(step_l)
	row.add_child(UI.spacer())
	var sk := UI.button("Skip tour", false, 14); sk.flat = true; sk.pressed.connect(skip); row.add_child(sk)
	next_b = UI.button("Next ›", true, 15); next_b.custom_minimum_size = Vector2(110, 36); next_b.pressed.connect(next); row.add_child(next_b)
	voice = AudioStreamPlayer.new(); add_child(voice)
	voice.finished.connect(func(): auto_left = 1.6)


## Shows one line: its text, its spotlight and its voice. Returns when the player (or the timer) moves on.
func show_step(id: String, text: String, tgt: String, n: int, total: int, dim_level := 0.6) -> void:
	if is_skipped:
		return
	target = tgt
	dim_want = dim_level if tgt != "" else (0.0 if id == "vista" else 0.35)
	text_l.text = text
	step_l.text = "%d / %d" % [n, total]
	next_b.text = "Let's go ›" if n == total else "Next ›"
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.35)
	auto_left = -1.0
	var st = _stream("audio/voice/tour_" + id)
	voice.stop()
	if st != null:
		voice.stream = st
		voice.play()
	else:
		auto_left = 2.5 + text.length() * 0.055
	done = false
	await step_done


func next() -> void:
	if done:
		return
	done = true
	voice.stop()
	step_done.emit()


func skip() -> void:
	is_skipped = true
	voice.stop()
	skipped.emit()
	if not done:
		done = true
		step_done.emit()


func _gui_input(e: InputEvent) -> void:
	accept_event()


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		next(); get_viewport().set_input_as_handled()
	elif e.physical_keycode == KEY_ESCAPE:
		skip(); get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	t += delta
	dim = move_toward(dim, dim_want, delta * 1.2)
	if auto_left > 0.0:
		auto_left -= delta
		if auto_left <= 0.0:
			next()
	_place_card()
	queue_redraw()


func _spot() -> Rect2:
	if target == "" or not target_fn.is_valid():
		return Rect2()
	var r: Rect2 = target_fn.call(target)
	return r.grow(8.0) if r.size != Vector2.ZERO else Rect2()


## The card sits below a spotlight in the top half, above one in the bottom half, inside a spotlight that fills the
## screen, and at the bottom centre when there is none.
func _place_card() -> void:
	var sz := card.get_combined_minimum_size()
	card.size = sz
	var W := size
	var r := _spot()
	var p := Vector2((W.x - sz.x) * 0.5, W.y - sz.y - 48.0)
	if r.size != Vector2.ZERO:
		if r.size.y > W.y * 0.5:
			p = Vector2(r.get_center().x - sz.x * 0.5, r.end.y - sz.y - 28.0)
		elif r.get_center().y < W.y * 0.5:
			p = Vector2(r.get_center().x - sz.x * 0.5, r.end.y + 18.0)
		else:
			p = Vector2(r.get_center().x - sz.x * 0.5, r.position.y - sz.y - 18.0)
		if r.size.x < W.x * 0.3 and r.get_center().x < W.x * 0.3:     # a narrow column on the left: beside it
			p = Vector2(r.end.x + 24.0, clampf(r.get_center().y - sz.y * 0.5, 24.0, W.y - sz.y - 24.0))
	p.x = clampf(p.x, 24.0, W.x - sz.x - 24.0)
	p.y = clampf(p.y, 24.0, W.y - sz.y - 24.0)
	card.position = card.position.lerp(p, 0.25) if card.modulate.a > 0.05 else p


func _draw() -> void:
	if dim < 0.005:
		return
	var W := size
	var r := _spot()
	var c := Color(0, 0, 0, dim)
	if r.size == Vector2.ZERO:
		draw_rect(Rect2(Vector2.ZERO, W), c)
		return
	draw_rect(Rect2(0, 0, W.x, r.position.y), c)
	draw_rect(Rect2(0, r.end.y, W.x, W.y - r.end.y), c)
	draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), c)
	draw_rect(Rect2(r.end.x, r.position.y, W.x - r.end.x, r.size.y), c)
	var glow := 0.55 + 0.45 * sin(t * 3.0)
	draw_style_box(UI.sb(Color(0, 0, 0, 0), 8, Color(UI.GOLD, 0.5 + 0.5 * glow), 2, 0), r)


func _stream(rel: String) -> Variant:
	var path := A.path(rel + ".mp3")
	if not FileAccess.file_exists(path):
		return null
	var m := AudioStreamMP3.new()
	m.data = FileAccess.get_file_as_bytes(path)
	return m
