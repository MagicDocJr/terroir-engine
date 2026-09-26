# PROTOTYPE — round-2 capture: wait for the scene to settle, save the PNG, optionally measure FPS, quit.
extends Node

var shot_name := ""
var perf := false
var target: Node
var frames := 0
var times := PackedFloat32Array()
var saved := false

func _process(delta: float) -> void:
	frames += 1
	var settle := 150
	if target and target.has_method("settle_frames"):
		settle = target.settle_frames()
	if not saved:
		if frames >= settle:
			var img := get_viewport().get_texture().get_image()
			var path := ProjectSettings.globalize_path("res://").path_join("../shots/r2/godot_%s.png" % shot_name)
			img.save_png(path)
			print("saved ", path, " ", img.get_size())
			saved = true
			if not perf:
				get_tree().quit()
		return
	times.append(delta)
	var total := 0.0
	for t in times: total += t
	if total < 5.0: return
	var s := times.duplicate(); s.sort()
	var res := {"avg_fps": snappedf(times.size() / total, 0.1), "low1_fps": snappedf(1.0 / s[int(0.99 * (s.size() - 1))], 0.1), "frames": times.size()}
	print("perf ", shot_name, " ", res)
	var p := ProjectSettings.globalize_path("res://").path_join("../shots/r2/godot_perf.json")
	var all := {}
	if FileAccess.file_exists(p): all = JSON.parse_string(FileAccess.get_file_as_string(p))
	all[shot_name] = res
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_string(JSON.stringify(all, "  ")); f.close()
	get_tree().quit()
