class_name Player
extends Node2D
## The controlled agent. Movement, health, invulnerability window, regen.
## Damage math lives in DamageCalculator; trait hooks in AgentTraits.

signal hp_changed(hp: float, max_hp: float)
signal died

var agent_id := "lia"
var visual: Dictionary = {}
var stats := StatBlock.new()
var hp := 100.0
var max_hp := 100.0
var radius := 18.0
var move_dir := Vector2.RIGHT
var velocity := Vector2.ZERO
var moving := false
var invuln_t := 0.0
var invuln_time := 0.55
var speed_bonus_t := 0.0
var speed_bonus := 0.0
var shield := false
var damage_taken := 0.0
var dead := false
var _walk_t := 0.0
var _hurt_t := 0.0
var _regen_acc := 0.0


func setup(id: String, mods: Array, run_radius: float, invuln: float) -> void:
	agent_id = id
	visual = Content.agent(id).get("visual", {})
	radius = run_radius
	invuln_time = invuln
	stats.add_all(mods)
	stats.changed.connect(_on_stats_changed)
	max_hp = stats.get_stat("max_hp")
	hp = max_hp
	z_index = 3


func _on_stats_changed() -> void:
	var new_max := stats.get_stat("max_hp")
	if new_max != max_hp:
		# Gaining max HP also heals the difference; losing it clamps.
		hp = clampf(hp + maxf(new_max - max_hp, 0.0), 0.0, new_max)
		max_hp = new_max
		hp_changed.emit(hp, max_hp)


func update(delta: float, input: Vector2, arena: Arena, slow_factor: float, regen_mult: float) -> void:
	if dead:
		return
	if input.length() > 1.0:
		input = input.normalized()
	moving = input.length() > 0.05
	var spd := stats.get_stat("move_speed") * slow_factor
	if speed_bonus_t > 0.0:
		speed_bonus_t -= delta
		spd *= 1.0 + speed_bonus
	velocity = input * spd
	if moving:
		move_dir = input.normalized()
		_walk_t += delta * 10.0
	position = arena.resolve_player(position + velocity * delta, radius)
	if invuln_t > 0.0:
		invuln_t -= delta
	if _hurt_t > 0.0:
		_hurt_t -= delta
	var regen := stats.get_stat("regen") * regen_mult
	if regen > 0.0 and hp < max_hp:
		_regen_acc += regen * delta
		if _regen_acc >= 1.0 or hp + _regen_acc >= max_hp:
			heal(_regen_acc)
			_regen_acc = 0.0
	queue_redraw()


## Returns actual damage applied (0 if dodged/invulnerable/shielded).
func take_damage(raw: float, roll: float, min_dmg: float, ignore_iframes: bool = false) -> Dictionary:
	if dead or (invuln_t > 0.0 and not ignore_iframes):
		return {"amount": 0.0, "dodged": false, "blocked": true}
	if shield and not ignore_iframes:
		shield = false
		invuln_t = invuln_time
		return {"amount": 0.0, "dodged": false, "blocked": true, "shield": true}
	var res := DamageCalculator.incoming(raw, stats.get_stat("armor"), stats.get_stat("damage_reduction"), stats.get_stat("dodge"), roll, min_dmg if not ignore_iframes else 0.0)
	if res.dodged:
		invuln_t = invuln_time * 0.5
		return res
	hp = maxf(hp - res.amount, 0.0)
	damage_taken += res.amount
	if not ignore_iframes:
		invuln_t = invuln_time
		_hurt_t = 0.2
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		dead = true
		died.emit()
	return res


func heal(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	hp = minf(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)


func revive(pct: float) -> void:
	dead = false
	hp = max_hp * clampf(pct, 0.1, 1.0)
	invuln_t = 2.0
	hp_changed.emit(hp, max_hp)


func hp_ratio() -> float:
	return hp / maxf(max_hp, 1.0)


func _draw() -> void:
	var bob := sin(_walk_t) * 2.5 if moving else 0.0
	var blink := invuln_t > 0.0 and int(invuln_t * 20.0) % 2 == 0
	if shield:
		draw_arc(Vector2.ZERO, radius * 1.6, 0, TAU, 32, Color(Palette.AMBER, 0.8), 3.0)
	if not blink:
		AgentPainter.draw(self, visual, Vector2(0, -radius * 0.3), radius * 1.3, move_dir.x, bob, _hurt_t > 0.0)
	var w := radius * 2.6
	draw_rect(Rect2(-w / 2, radius * 1.15, w, 6), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w / 2, radius * 1.15, w * hp_ratio(), 6), Palette.GREEN if hp_ratio() > 0.35 else Palette.CORAL)
	if DebugTools.show_hitboxes:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color.GREEN, 1.5)
		draw_arc(Vector2.ZERO, stats.get_stat("pickup"), 0, TAU, 48, Color(Color.CYAN, 0.4), 1.0)
