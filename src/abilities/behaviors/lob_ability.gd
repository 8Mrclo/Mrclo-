extends AbilityRuntime
## Cápsula Sísmica / Falha Tectônica: lobbed shells, expanding shockwaves.

var _waves: Array = []   # {pos, at, radius, dmg}


func tick(delta: float) -> void:
	for i in range(_waves.size() - 1, -1, -1):
		var w: Dictionary = _waves[i]
		if battle.time >= w.at:
			_waves.remove_at(i)
			battle.area_damage(w.pos, w.radius, w.dmg, slot, 120.0, flags)
			battle.fx.ring(w.pos, w.radius, 0.3, color)
	timer -= delta
	if timer > 0.0:
		return
	timer = interval(p("cooldown"))
	var origin: Vector2 = battle.player.position
	for k in int(p("count")) + extra_count():
		var t := battle.enemies.nearest(origin + Vector2.from_angle(battle.rng.randf() * TAU) * p("range") * 0.5, p("range"))
		var to: Vector2 = t.position if t else origin + Vector2.from_angle(battle.rng.randf() * TAU) * p("range") * 0.6
		battle.projectiles.lob(origin, to, 0.55, color, _land)


func _land(pos: Vector2) -> void:
	var r := p("radius") * stat("area")
	battle.area_damage(pos, r, p("damage"), slot, 180.0, flags)
	battle.fx.ring(pos, r, 0.35, color)
	battle.shake(0.12)
	Audio.play(&"boom")
	for k in range(1, int(p("waves"))):
		_waves.append({"pos": pos, "at": battle.time + 0.18 * k, "radius": r * (1.0 + 0.4 * k), "dmg": p("damage") * 0.5})
	if evolved:
		var flen := p("fissure_length", 260.0) * stat("area")
		for f in int(p("fissures", 4)):
			var dir := Vector2.from_angle(TAU * f / p("fissures", 4) + PI / 4.0)
			battle.fx.beam(pos, pos + dir * flen, 26.0, 0.35, color)
			for e in battle.enemies.active:
				if e.alive and Geometry2D.get_closest_point_to_segment(e.position, pos, pos + dir * flen).distance_to(e.position) < 18.0 + e.radius:
					battle.damage_enemy(e, p("damage") * 0.7, slot, dir, 60.0, flags)
