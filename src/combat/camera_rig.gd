class_name CameraRig
extends Camera2D
## Smooth follow with trauma-based shake (scaled by the accessibility setting).

var target: Node2D
var trauma := 0.0
var strength := 1.0


func setup(t: Node2D, bounds: Rect2) -> void:
	target = t
	strength = Settings.shake_strength()
	position = t.position
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)
	position_smoothing_enabled = true
	position_smoothing_speed = 9.0


func add_trauma(v: float) -> void:
	trauma = minf(trauma + v, 1.0)


func update(delta: float) -> void:
	if target:
		position = target.position
	if trauma > 0.0 and strength > 0.0:
		var s := trauma * trauma * 14.0 * strength
		offset = Vector2(randf_range(-s, s), randf_range(-s, s))
		trauma = maxf(trauma - delta * 1.8, 0.0)
	else:
		offset = Vector2.ZERO
