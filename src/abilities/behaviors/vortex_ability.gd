extends AbilityRuntime
## Vórtice de Sucção: temporary area that pulls enemies to its center.

var _vortices: Array = []   # {pos, life, tick}


func tick(delta: float) -> void:
	var r := p("radius") * stat("area")
	for i in range(_vortices.size() - 1, -1, -1):
		var v: Dictionary = _vortices[i]
		v.life -= delta
		if v.life <= 0.0:
			_vortices.remove_at(i)
			continue
		v.tick -= delta
		var do_tick: bool = v.tick <= 0.0
		if do_tick:
			v.tick = 0.3
		for j in battle.enemies.query(v.pos, r):
			var e: Enemy = battle.enemies.active[j]
			if not e.alive or e.is_boss:
				continue
			var to: Vector2 = v.pos - e.position
			var d2 := to.length_squared()
			if d2 > r * r:
				continue
			if d2 > 64.0:
				e.position += to.normalized() * p("pull") / maxf(e.mass, 0.5) * delta
			if do_tick:
				battle.damage_enemy(e, p("dps") * 0.3, slot, Vector2.ZERO, 0.0, flags | Battle.FLAG_NO_FX)
	timer -= delta
	if timer > 0.0:
		return
	timer = interval(p("cooldown"))
	var origin: Vector2 = battle.player.position
	var t := aim(origin, p("range"))
	var pos: Vector2 = t.position if t else origin + battle.player.move_dir * p("range") * 0.6
	_vortices.append({"pos": pos, "life": p("duration") * stat("duration"), "tick": 0.0})


func draw_visual() -> void:
	var r := p("radius") * stat("area")
	for v in _vortices:
		for k in 3:
			var a: float = battle.time * 4.0 + k * 2.1
			visual.draw_arc(v.pos, r * (0.35 + 0.25 * k), a, a + PI * 1.3, 20, Color(color, 0.6 - 0.15 * k), 4.0)
		visual.draw_circle(v.pos, r, Color(color, 0.1))
