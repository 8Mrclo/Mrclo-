class_name DamageNumbers
extends Node2D
## Aggregated floating numbers drawn by a single node (no Label per number).
## Enemies accumulate damage for a short window and emit one number.

var max_count := 24
var enabled := true
var _items: Array = []   # {pos, value, crit, t}
var _font: Font
var _life := 0.6
var _rise := 46.0


func setup(limit: int) -> void:
	max_count = limit
	enabled = limit > 0 and bool(Settings.get_value("show_damage_numbers"))
	_font = ThemeDB.fallback_font
	_life = float(Content.balance_value("damage_numbers.life", 0.6))
	_rise = float(Content.balance_value("damage_numbers.rise", 46))
	z_index = 20


func emit_number(pos: Vector2, value: float, crit: bool) -> void:
	if not enabled or value < 0.5:
		return
	if _items.size() >= max_count:
		_items.pop_front()
	_items.append({"pos": pos, "value": int(round(value)), "crit": crit, "t": 0.0})


func update(delta: float) -> void:
	if _items.is_empty():
		return
	for it in _items:
		it.t += delta
	while not _items.is_empty() and _items[0].t >= _life:
		_items.pop_front()
	queue_redraw()


func _draw() -> void:
	for it in _items:
		var k: float = it.t / _life
		var p: Vector2 = it.pos + Vector2(0, -_rise * k)
		var size := 30 if it.crit else 22
		var col := Palette.AMBER if it.crit else Palette.SAND
		col.a = 1.0 - k * k
		draw_string_outline(_font, p, str(it.value), HORIZONTAL_ALIGNMENT_CENTER, -1, size, 5, Color(0, 0, 0, col.a * 0.8))
		draw_string(_font, p, str(it.value), HORIZONTAL_ALIGNMENT_CENTER, -1, size, col)
