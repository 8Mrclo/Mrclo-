extends AbilityRuntime
## Estilhaço Prisma / Caleidoscópio: projectiles that split on hit.


func tick(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	timer = interval(p("cooldown"))
	var origin: Vector2 = battle.player.position
	var base := aim_dir(origin, 560.0)
	var n := int(p("count")) + extra_count()
	for k in n:
		var a := base.angle() + (k - (n - 1) * 0.5) * 0.18
		var pr := battle.projectiles.fire(origin, Vector2.from_angle(a), p("proj_speed"), p("damage"), 9.0, Projectile.Kind.SHARD, color, slot, 0, 1.3)
		if pr:
			pr.split_count = int(p("splits"))
			pr.split_pct = p("shard_pct")
			pr.split_depth = int(p("depth", 1))
			pr.split_pierce = int(p("shard_pierce", 0))
	Audio.play(&"shoot")
