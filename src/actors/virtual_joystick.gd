class_name VirtualJoystick
extends Control
## Floating one-thumb joystick: touch anywhere in the lower 80% of the screen.
## Mouse works too through emulate_touch_from_mouse.

signal moved_once

var output := Vector2.ZERO
var _index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var radius := 110.0
var _notified := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _index < 0 and event.position.y > size.y * 0.16:
			_index = event.index
			_origin = event.position
			_knob = _origin
			queue_redraw()
		elif not event.pressed and event.index == _index:
			_index = -1
			output = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == _index:
		var d: Vector2 = event.position - _origin
		if d.length() > radius:
			_origin += d - d.normalized() * radius
			d = d.normalized() * radius
		_knob = _origin + d
		output = d / radius
		if output.length() < 0.12:
			output = Vector2.ZERO
		elif not _notified:
			_notified = true
			moved_once.emit()
		queue_redraw()


func release() -> void:
	_index = -1
	output = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if _index < 0:
		return
	draw_circle(_origin, radius, Color(Palette.PETROL_DEEP, 0.35))
	draw_arc(_origin, radius, 0, TAU, 48, Color(Palette.TEAL, 0.6), 3.0)
	draw_circle(_knob, radius * 0.38, Color(Palette.TEAL, 0.7))
	draw_circle(_knob, radius * 0.2, Color(Palette.SAND, 0.8))
