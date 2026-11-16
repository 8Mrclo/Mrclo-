extends AbilityRuntime
## Arco de Íons / Tempestade Dendrítica: bolt jumps between nearby targets.

var _pts := PackedVector2Array()


func tick(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	timer = interval(p("cooldown"))
	var origin: Vector2 = battle.player.position
	var first := aim(origin, p("range"))
	if first == null:
		timer = 0.2
		return
	for b in int(p("bolts")) + (extra_count() if evolved else 0):
		var cur := first if b == 0 else battle.enemies.nearest(origin + Vector2.from_angle(battle.rng.randf() * TAU) * 120.0, p("range"))
		if cur == null:
			break
		_pts = PackedVector2Array([origin])
		var visited: Array[int] = []
		for jump in int(p("jumps")) + 1:
			if cur == null:
				break
			visited.append(cur.uid)
			_pts.append(cur.position)
			battle.damage_enemy(cur, p("damage"), slot, Vector2.ZERO, 0.0, flags)
			if evolved and cur.alive:
				cur.slow_t = p("slow_time", 1.0)
				cur.slow_f = p("slow", 0.4)
			cur = _next(cur.position, visited)
		battle.fx.chain(_pts, color, 7.0 if evolved else 5.0)
	Audio.play(&"zap")


func _next(from: Vector2, visited: Array[int]) -> Enemy:
	var best: Enemy = null
	var best_d := (p("jump_range") * stat("area")) ** 2
	for j in battle.enemies.query(from, p("jump_range") * stat("area")):
		var e: Enemy = battle.enemies.active[j]
		if not e.alive or e.uid in visited:
			continue
		var d := (e.position - from).length_squared()
		if d < best_d:
			best_d = d
			best = e
	return best
