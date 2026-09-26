# PROTOTYPE — smoke test: boots the interactive app, fires F2/F3/F4/F1 and the vineyard P/T/R keys, reports errors, quits.
extends SceneTree
var t := 0.0
var step := 0
var app: Node
func _initialize() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
func _key(code: Key) -> void:
	var e := InputEventKey.new(); e.physical_keycode = code; e.keycode = code; e.pressed = true
	Input.parse_input_event(e)
	var u := InputEventKey.new(); u.physical_keycode = code; u.keycode = code; u.pressed = false
	Input.parse_input_event(u)
func _process(delta: float) -> bool:
	t += delta
	var plan := [[3.0, KEY_P, "preset"], [6.0, KEY_T, "time"], [8.0, KEY_R, "rain"], [11.0, KEY_F2, "cellar"], [15.0, KEY_F3, "hall"], [19.0, KEY_F4, "dashboard"], [22.0, KEY_F1, "vineyard"], [27.0, KEY_NONE, "done"]]
	if step < plan.size() and t > plan[step][0]:
		var p = plan[step]
		print("smoke: ", p[2], " current=", app.get("current").get_script().resource_path.get_file() if app.get("current") else "?", " fps=", Engine.get_frames_per_second())
		if p[1] == KEY_NONE:
			return true
		_key(p[1])
		step += 1
	return false
