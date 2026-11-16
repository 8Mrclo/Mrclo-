extends AbilityRuntime
## Pulso Reverso / Coração de Maré: radial knockback blasts (heal on evolution).

var _echo_at := -1.0


func tick(delta: float) -> void:
	if _echo_at > 0.0 and battle.time >= _echo_at:
		_echo_at = -1.0
		_pulse(0.6)
	timer -= delta
	if timer > 0.0:
		return
	timer = interval(p("cooldown"))
	_pulse(1.0)
	if int(p("echo", 0)) > 0:
		_echo_at = battle.time + 0.35


func _pulse(mult: float) -> void:
	var r := p("radius") * stat("area")
	var hits := battle.area_damage(battle.player.position, r, p("damage") * mult, slot, p("knockback"), flags)
	battle.fx.ring(battle.player.position, r, 0.35, color)
	if evolved and hits > 0:
		battle.player.heal(minf(hits * p("heal_per_hit", 0.5), p("heal_cap", 8.0)))
	Audio.play(&"boom")
