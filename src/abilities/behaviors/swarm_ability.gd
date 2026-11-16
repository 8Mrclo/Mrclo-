extends AbilityRuntime
## Enxame Magnético: marks targets, then homing fragments chase the marks.


func tick(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	timer = interval(p("cooldown"))
	var origin: Vector2 = battle.player.position
	var marked: Array[Enemy] = []
	for k in int(p("marks")):
		var e := battle.find_target(origin + Vector2.from_angle(battle.rng.randf() * TAU) * 80.0, 600.0)
		if e and not e in marked:
			e.mark_t = 3.0
			marked.append(e)
			battle.fx.flash(e.position, e.radius * 1.6, color)
	if marked.is_empty():
		timer = 0.3
		return
	var n := int(p("count")) + extra_count()
	for k in n:
		var t: Enemy = marked[k % marked.size()]
		var dir := Vector2.from_angle(TAU * k / n)
		var pr := battle.projectiles.fire(origin, dir, p("proj_speed"), p("damage"), 5.0, Projectile.Kind.SWARM, color, slot, 0, 2.2)
		if pr:
			pr.homing = p("turn_rate")
			pr.target = t
			pr.target_uid = t.uid
			pr.flags = flags
