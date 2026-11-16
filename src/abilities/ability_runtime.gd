class_name AbilityRuntime
extends RefCounted
## Base for active abilities. Params come from the level table (or the
## evolution's fixed params). Global stats are read live, so passives apply
## instantly. Subclasses implement tick() and optionally draw_visual().

var battle: Battle
var id := ""
var def: Dictionary = {}
var level := 1
var slot := 0
var evolved := false
var params: Dictionary = {}
var flags := 0
var color := Color.WHITE
var timer := 0.3
var visual: Node2D


func setup(b: Battle, d: Dictionary, slot_index: int) -> void:
	battle = b
	def = d
	id = d.id
	slot = slot_index
	evolved = bool(d.get("evolved", false))
	color = JsonUtil.color(JsonUtil.dig(d, "icon.color", ""), Palette.TEAL)
	if "device" in d.get("tags", Content.active(d.get("from", "")).get("tags", [])):
		flags |= Battle.FLAG_DEVICE
	visual = Node2D.new()
	visual.z_index = 2
	visual.draw.connect(draw_visual)
	b.ability_layer.add_child(visual)
	set_level(1)
	on_setup()


func set_level(n: int) -> void:
	level = n
	if evolved:
		params = def.get("params", {})
	else:
		var levels: Array = def.get("levels", [])
		params = levels[clampi(n - 1, 0, levels.size() - 1)]
	on_level_changed()


func p(key: String, fallback: float = 0.0) -> float:
	return float(params.get(key, fallback))


func stat(name: String) -> float:
	return battle.player.stats.get_stat(name)


## Period scaled by cooldown and attack speed stats.
func interval(base: float) -> float:
	return DamageCalculator.interval(base, stat("cooldown"), stat("attack_speed"))


func extra_count() -> int:
	return int(stat("projectile_count"))


func aim(origin: Vector2, max_range: float) -> Enemy:
	return battle.find_target(origin, max_range)


func aim_dir(origin: Vector2, max_range: float) -> Vector2:
	var t := aim(origin, max_range)
	if t:
		return (t.position - origin).normalized()
	return battle.player.move_dir


func update(delta: float) -> void:
	tick(delta)
	if visual.visible:
		visual.queue_redraw()


func remove() -> void:
	if is_instance_valid(visual):
		visual.queue_free()


# Overridables -----------------------------------------------------------
func on_setup() -> void: pass
func on_level_changed() -> void: pass
func tick(_delta: float) -> void: pass
func draw_visual() -> void: pass
