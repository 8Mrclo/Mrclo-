class_name HangarBackground
extends Control
## Light animated backdrop: the Farol Nove hangar at night — diagonal light
## shafts, slow floating motes and a lighthouse beam. Static if reduce_motion.

var _t := 0.0
var _motes: Array = []
var _static := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_static = bool(Settings.get_value("reduce_motion"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 26:
		_motes.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.3, 1.0)))
	set_process(not _static)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Palette.bg())
	if Palette.high_contrast():
		return
	draw_colored_polygon(PackedVector2Array([Vector2(0, s.y * 0.55), Vector2(s.x, s.y * 0.35), Vector2(s.x, s.y), Vector2(0, s.y)]), Color(Palette.PETROL, 0.9))
	for i in 4:
		var x := s.x * (0.1 + 0.28 * i) + sin(_t * 0.2 + i) * 20.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 60, 0), Vector2(x - 120, s.y), Vector2(x - 220, s.y)]), Color(Palette.TEAL, 0.035))
	var beam_a := sin(_t * 0.35) * 0.5 - PI * 0.5
	var origin := Vector2(s.x * 0.85, s.y * 0.12)
	draw_colored_polygon(PackedVector2Array([origin, origin + Vector2.from_angle(beam_a - 0.12) * s.y, origin + Vector2.from_angle(beam_a + 0.12) * s.y]), Color(Palette.AMBER, 0.05))
	draw_circle(origin, 10, Color(Palette.AMBER, 0.6))
	for m in _motes:
		var p := Vector2(fmod(m.x * s.x + _t * 8.0 * m.z, s.x), fmod(m.y * s.y - _t * 14.0 * m.z + s.y, s.y))
		draw_circle(p, 2.0 + m.z * 2.0, Color(Palette.MINT, 0.15 * m.z))
