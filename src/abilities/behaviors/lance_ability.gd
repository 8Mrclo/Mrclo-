extends AbilityRuntime
## Lança Solar: heavy piercing lance that prioritises elites and bosses.


func tick(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	timer = interval(p("cooldown"))
	var origin: Vector2 = battle.player.position
	var target := battle.find_target(origin, 900.0, "threat")
	var dir: Vector2 = (target.position - origin).normalized() if target else battle.player.move_dir
	var n := int(p("count")) + extra_count() / 2
	for k in n:
		var d := dir.rotated((k - (n - 1) * 0.5) * 0.12)
		var l := battle.projectiles.fire(origin, d, p("proj_speed"), p("damage"), p("width"), Projectile.Kind.LANCE, color, slot, int(p("pierce")), 1.0)
		if l:
			l.length = 46.0
			l.knock = 220.0
			l.queue_redraw()
	Audio.play(&"zap")
