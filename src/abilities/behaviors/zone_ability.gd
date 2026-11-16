extends AbilityRuntime
## Bruma Criogênica / Zero Absoluto: drifting mist zones that slow (and freeze).

var _zones := PackedVector2Array()
var _tick := 0.0
var _freeze_t := 0.0


func tick(delta: float) -> void:
	var n := int(p("count")) + extra_count() / 2
	var r := p("radius") * stat("area")
	var drift := p("drift")
	_zones.resize(n)
	var c: Vector2 = battle.player.position
	for i in n:
		var a := battle.time * 0.7 + TAU * i / n
		_zones[i] = c + Vector2(cos(a), sin(a * 2.0) * 0.6) * drift
	_tick -= delta
	if evolved:
		_freeze_t -= delta
	var freeze := evolved and _freeze_t <= 0.0
	if freeze:
		_freeze_t = p("freeze_interval", 3.0)
	if _tick > 0.0 and not freeze:
		return
	var tick_len := p("tick")
	_tick = tick_len
	for z in _zones:
		for j in battle.enemies.query(z, r):
			var e: Enemy = battle.enemies.active[j]
			if not e.alive or (e.position - z).length_squared() > (r + e.radius) ** 2:
				continue
			e.slow_t = tick_len + 0.25
			e.slow_f = p("slow")
			if freeze and not e.is_boss:
				e.stun_t = p("freeze_time", 1.0) * stat("duration")
			if e.hit_lock[slot] <= battle.time:
				e.hit_lock[slot] = battle.time + tick_len * 0.9
				battle.damage_enemy(e, p("dps") * tick_len, slot, Vector2.ZERO, 0.0, flags | Battle.FLAG_NO_FX)
		if freeze:
			battle.fx.ring(z, r, 0.4, Palette.SAND)


func draw_visual() -> void:
	var r := p("radius") * stat("area")
	for z in _zones:
		visual.draw_circle(z, r, Color(color, 0.16))
		visual.draw_circle(z + Vector2(sin(battle.time * 2.0) * 12.0, 0), r * 0.6, Color(color, 0.14))
		visual.draw_arc(z, r, 0, TAU, 32, Color(color, 0.45), 2.0)
