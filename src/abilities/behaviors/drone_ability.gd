extends AbilityRuntime
## Sonda Coral / Recife de Sondas: drones follow the agent and fire.

var _drones: Array = []   # {pos, t}


func tick(delta: float) -> void:
	var n := int(p("count")) + extra_count()
	while _drones.size() < n:
		_drones.append({"pos": battle.player.position, "t": battle.rng.randf() * 0.5})
	while _drones.size() > n:
		_drones.pop_back()
	var center: Vector2 = battle.player.position
	for i in _drones.size():
		var d: Dictionary = _drones[i]
		var home := center + Vector2.from_angle(battle.time * 1.4 + TAU * i / _drones.size()) * 64.0
		d.pos = d.pos.lerp(home, clampf(delta * 6.0, 0.0, 1.0))
		d.t -= delta
		if d.t <= 0.0:
			d.t = interval(p("fire_interval"))
			var t := aim(d.pos, p("range"))
			if t == null:
				d.t = 0.15
				continue
			var dir: Vector2 = (t.position - d.pos).normalized()
			if evolved:
				var m := battle.projectiles.fire(d.pos, dir, p("proj_speed"), p("damage"), 9.0, Projectile.Kind.MISSILE, color, slot, 0, 2.0)
				if m:
					m.homing = p("homing", 6.0)
					m.target = t
					m.target_uid = t.uid
					m.explode_radius = p("explode_radius", 60.0) * stat("area")
					m.flags = flags
			else:
				var b := battle.projectiles.fire(d.pos, dir, p("proj_speed"), p("damage"), 7.0, Projectile.Kind.BOLT, color, slot, int(p("pierce")), 1.2)
				if b:
					b.flags = flags
			Audio.play(&"shoot")


func draw_visual() -> void:
	for d in _drones:
		IconPainter.draw(visual, "drone", d.pos, 14.0, color)
