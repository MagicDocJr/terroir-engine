extends Control
func _ready() -> void:
	var cat: String = Sim.Catalog()
	print("catalog bytes: ", cat.length(), " err: ", Sim.LastError())
	get_tree().quit()
