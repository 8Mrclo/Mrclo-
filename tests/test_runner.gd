extends Node
## Runs every tests/unit/test_*.gd. Exit code 0 = all passed.
## godot --headless --path . res://tests/test_runner.tscn


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Saves.enabled = false
	Analytics.enabled = false
	InputSetup.ensure_actions()
	var files: Array[String] = []
	var d := DirAccess.open("res://tests/unit")
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append("res://tests/unit/" + f)
	files.sort()
	var total := 0
	var failed: Array[String] = []
	for path in files:
		var script: GDScript = load(path)
		var inst: TestCase = script.new()
		for m in inst.get_method_list():
			var method: String = m.name
			if not method.begins_with("test_"):
				continue
			total += 1
			Game.set_data(SaveDefaults.create())
			TimeService.override_unix = -1
			inst.current = "%s::%s" % [path.get_file(), method]
			var before := inst.failures.size()
			inst.call(method)
			if inst.failures.size() > before:
				print("  ✗ ", inst.current)
			else:
				print("  ✓ ", inst.current)
		failed.append_array(inst.failures)
	TimeService.override_unix = -1
	print("\n%d testes, %d falha(s)" % [total, failed.size()])
	for f in failed:
		print("FALHA: ", f)
	get_tree().quit(0 if failed.is_empty() else 1)
