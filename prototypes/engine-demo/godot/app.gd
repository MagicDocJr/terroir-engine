# PROTOTYPE — entry point. Picks the scene (vineyard / cellar / hall / dashboard) from the user args,
# runs round-2 capture mode (--shot2 <name> [--perf]), and switches scenes interactively:
#   F1 vineyard · F2 cellar · F3 hall · F4 dashboard   (vineyard: P preset, T +30 min, R rain, 1-5 cameras, F fps)
extends Node

const ShotHelper := preload("res://shot_capture.gd")
var layout2: Dictionary
var current: Node
var shot := ""

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene := "vineyard"
	var i := args.find("--shot2")
	layout2 = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models_r2/layout_r2.json"))
	if i >= 0 and i + 1 < args.size():
		shot = args[i + 1]
		scene = layout2["shots"][shot]["scene"]
	var j := args.find("--scene")
	if j >= 0 and j + 1 < args.size():
		scene = args[j + 1]
	_load(scene)
	if shot != "":
		var cap := Node.new(); cap.set_script(ShotHelper)
		cap.set("shot_name", shot); cap.set("perf", "--perf" in args); cap.set("target", current)
		add_child(cap)

func _load(scene: String) -> void:
	if current:
		current.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var node: Node
	match scene:
		"vineyard":
			node = Node3D.new(); node.set_script(load("res://main.gd"))
		"cellar", "hall":
			node = Node3D.new(); node.set_script(load("res://winery.gd")); node.set("room", scene)
		"dashboard":
			node = Control.new(); node.set_script(load("res://dashboard.gd"))
	node.set("layout2", layout2)
	if shot != "":
		node.set("shot2", layout2["shots"][shot])
	current = node
	add_child(node)

func _unhandled_input(e: InputEvent) -> void:
	if shot != "" or not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.physical_keycode:
		KEY_F1: _load("vineyard")
		KEY_F2: _load("cellar")
		KEY_F3: _load("hall")
		KEY_F4: _load("dashboard")
