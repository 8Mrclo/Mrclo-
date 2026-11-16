class_name InputSetup
extends RefCounted
## Registers input actions in code so project.godot stays readable.


static func ensure_actions() -> void:
	_key_action("move_left", [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_key_action("move_right", [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_key_action("move_up", [KEY_W, KEY_UP], JOY_AXIS_LEFT_Y, -1.0)
	_key_action("move_down", [KEY_S, KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_key_action("pause", [KEY_ESCAPE, KEY_P], -1, 0.0, JOY_BUTTON_START)
	_key_action("debug_menu", [KEY_F1], -1, 0.0)
	_key_action("toggle_metrics", [KEY_F3], -1, 0.0)


static func _key_action(action: String, keys: Array, axis: int, axis_dir: float, button: int = -1) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	if axis >= 0:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axis
		jm.axis_value = axis_dir
		InputMap.action_add_event(action, jm)
	if button >= 0:
		var jb := InputEventJoypadButton.new()
		jb.button_index = button
		InputMap.action_add_event(action, jb)
