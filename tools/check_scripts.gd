extends Node
## Dev tool: loads every script under res://src and res://tests and reports
## compile failures. Run: godot --headless --path . res://tools/check_scripts.tscn


func _ready() -> void:
	var failures := 0
	var files: Array[String] = []
	for root in ["res://src", "res://tests", "res://tools"]:
		_collect(root, files)
	for f in files:
		var s: Script = load(f)
		if s == null or not s.can_instantiate() and not f.ends_with("_runtime.gd"):
			print("FALHA: ", f)
			failures += 1
	print("Scripts verificados: %d, falhas: %d" % [files.size(), failures])
	get_tree().quit(1 if failures > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for sub in d.get_directories():
		_collect(dir_path.path_join(sub), out)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
