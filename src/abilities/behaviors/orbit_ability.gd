extends AbilityRuntime
## Disco Helicoidal / Anel Girocinético: orbiting discs with per-enemy hit lock.

var _angle := 0.0
var _on := true
var _phase_t := 0.0
var _shard_t := 0.0
var _positions := PackedVector2Array()


func tick(delta: float) -> void:
	var up := p("uptime") * stat("duration")
	var down := p("downtime") * stat("cooldown")
	if up > 0.0:
		_phase_t += delta
		if _on and _phase_t >= up:
			_on = false
			_phase_t = 0.0
		elif not _on and _phase_t >= down:
			_on = true
			_phase_t = 0.0
	visual.visible = _on
	if not _on:
		return
	_angle += p("rot_speed") * delta
	var n := int(p("count")) + extra_count()
	var r := p("orbit_radius") * stat("area")
	var size := p("size") * sqrt(stat("area"))
	_positions.resize(n)
	var center: Vector2 = battle.player.position
	for i in n:
		_positions[i] = center + Vector2.from_angle(_angle + TAU * i / n) * r
	var lock := p("hit_interval")
	for pos in _positions:
		for j in battle.enemies.query(pos, size):
			var e: Enemy = battle.enemies.active[j]
			if not e.alive or e.hit_lock[slot] > battle.time:
				continue
			if (e.position - pos).length_squared() < (size + e.radius) ** 2:
				e.hit_lock[slot] = battle.time + lock
				battle.damage_enemy(e, p("damage"), slot, (e.position - center).normalized(), 140.0, flags)
	if evolved:
		_shard_t -= delta
		if _shard_t <= 0.0:
			_shard_t = interval(p("shard_interval", 1.2))
			for pos in _positions:
				battle.projectiles.fire(pos, (pos - center).normalized(), 520.0, p("shard_damage"), 7.0, Projectile.Kind.SHARD, Palette.SAND, slot, 0, 0.7)


func draw_visual() -> void:
	var size := p("size") * sqrt(stat("area"))
	for pos in _positions:
		visual.draw_circle(pos, size * 1.3, Color(color, 0.25))
		visual.draw_circle(pos, size, color)
		visual.draw_arc(pos, size * 0.6, _angle * 3.0, _angle * 3.0 + PI, 12, Palette.PETROL_DEEP, 3.0)
