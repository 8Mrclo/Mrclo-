class_name SpawnDirector
extends RefCounted
## Data-driven spawning. Each second the director earns threat budget from the
## active wave (× mode/difficulty multipliers) and spends it on weighted picks.
## A minimum-alive curve keeps pressure when the player clears fast.
## Spawn points: just outside the camera rect, inside the arena, off obstacles,
## and never closer than spawn_min_player_distance.

var battle: Battle
var budget := 0.0
var _events_done: Dictionary = {}
var _next_elite := 0.0
var boss_spawned := false
var _margin := 90.0
var _min_dist := 380.0
var _champion_chance := 0.012


func _init(b: Battle) -> void:
	battle = b
	_margin = float(Content.balance_value("run.spawn_margin", 90))
	_min_dist = float(Content.balance_value("run.spawn_min_player_distance", 380))
	_champion_chance = float(Content.balance_value("enemy_scaling.champion_chance_per_minute", 0.012))
	_next_elite = float(b.cfg.elite_interval) if float(b.cfg.elite_interval) > 0.0 else INF


func current_wave() -> Dictionary:
	for w in battle.cfg.waves:
		if battle.time >= float(w.from) and battle.time < float(w.to):
			return w
	return battle.cfg.waves.back() if not battle.cfg.waves.is_empty() else {}


func min_alive() -> int:
	var m := 0
	for pair in battle.cfg.min_alive:
		if battle.time >= float(pair[0]):
			m = int(pair[1])
	return m


func update(delta: float) -> void:
	var w := current_wave()
	if not w.is_empty():
		var boss_slow := 0.5 if battle.boss_active() else 1.0
		budget += float(w.budget) * float(battle.cfg.budget_mult) * delta * boss_slow
		budget = minf(budget, 40.0)
		var guard := 0
		while budget > 0.0 and guard < 12:
			guard += 1
			var id := _pick(w)
			var cost := float(Content.enemy(id).get("threat", 1.0))
			if budget < cost and battle.enemies.count() >= min_alive():
				break
			budget -= cost
			_spawn_one(id)
	_run_events()
	if battle.time >= _next_elite:
		_next_elite += float(battle.cfg.elite_interval)
		var ids := Content.elite_ids
		_spawn_one(ids[battle.rng.randi_range(0, ids.size() - 1)])
	if not boss_spawned and battle.cfg.boss != "" and battle.time >= float(battle.cfg.boss_time):
		spawn_boss()


func _pick(w: Dictionary) -> String:
	var weights := PackedFloat32Array()
	for pair in w.pool:
		weights.append(float(pair[1]))
	var i := RandomService.weighted_index(battle.rng, weights)
	return w.pool[maxi(i, 0)][0]


func _spawn_one(id: String, at: Vector2 = Vector2.INF) -> Enemy:
	var pos := at if at != Vector2.INF else spawn_point()
	if pos == Vector2.INF:
		return null
	var champion := false
	var d: Dictionary = Content.enemy(id)
	if not d.get("is_elite", false) and not d.get("is_boss", false):
		champion = battle.rng.randf() < _champion_chance * battle.time / 60.0
	var e := battle.enemies.spawn(id, pos, champion)
	if e and e.is_elite:
		battle.on_elite_spawned(e)
	return e


## Random point on a ring just outside the visible area; validated.
func spawn_point(extra_margin: float = 0.0) -> Vector2:
	var view := battle.view_rect().grow(_margin + extra_margin)
	for attempt in 12:
		var side := battle.rng.randi_range(0, 3)
		var p := Vector2.ZERO
		match side:
			0: p = Vector2(battle.rng.randf_range(view.position.x, view.end.x), view.position.y)
			1: p = Vector2(battle.rng.randf_range(view.position.x, view.end.x), view.end.y)
			2: p = Vector2(view.position.x, battle.rng.randf_range(view.position.y, view.end.y))
			_: p = Vector2(view.end.x, battle.rng.randf_range(view.position.y, view.end.y))
		if is_valid_spawn(p):
			return p
	# Fallback: opposite side of the arena center relative to the player.
	var c := battle.arena.bounds.get_center()
	var p2 := battle.arena.clamp_inside(c + (c - battle.player.position).normalized() * 600.0, 40.0)
	return p2 if is_valid_spawn(p2) else Vector2.INF


func is_valid_spawn(p: Vector2) -> bool:
	if not battle.arena.bounds.grow(-40.0).has_point(p):
		return false
	if battle.arena.is_blocked(p, 24.0):
		return false
	return (p - battle.player.position).length() >= _min_dist


func _run_events() -> void:
	for i in battle.cfg.events.size():
		var ev: Dictionary = battle.cfg.events[i]
		if _events_done.has(i) or battle.time < float(ev.t):
			continue
		_events_done[i] = true
		match ev.type:
			"ring":
				_ring(ev.enemy, int(ev.count))
			"swarm":
				_swarm(ev.enemy, int(ev.count))
			"elite":
				_spawn_one(ev.enemy)
				battle.announce(Loc.t("battle.elite_incoming"))
			"boss_mid":
				var p := spawn_point(60.0)
				if p != Vector2.INF:
					var b := battle.enemies.spawn(ev.enemy, p, false, float(ev.get("hp_mult", 0.5)))
					if b:
						battle.start_boss(b, true)


## Encircling ring that leaves a gap so the player can always escape.
func _ring(id: String, n: int) -> void:
	var c: Vector2 = battle.player.position
	var r := maxf(battle.view_rect().size.length() * 0.45, _min_dist + 40.0)
	var gap := battle.rng.randf() * TAU
	for k in n:
		var a := TAU * k / n
		if absf(angle_difference(a, gap)) < 0.35:
			continue
		var p := battle.arena.clamp_inside(c + Vector2.from_angle(a) * r, 30.0)
		if not battle.arena.is_blocked(p, 20.0):
			battle.enemies.spawn(id, p)
	battle.announce(Loc.t("battle.ring_incoming"))


func _swarm(id: String, n: int) -> void:
	var p0 := spawn_point(80.0)
	if p0 == Vector2.INF:
		return
	for k in n:
		var p := battle.arena.clamp_inside(p0 + Vector2(battle.rng.randf_range(-120, 120), battle.rng.randf_range(-120, 120)), 30.0)
		battle.enemies.spawn(id, p)
	battle.announce(Loc.t("battle.swarm_incoming"))


func spawn_boss() -> void:
	if boss_spawned or battle.cfg.boss == "":
		return
	boss_spawned = true
	var p := spawn_point(80.0)
	if p == Vector2.INF:
		p = battle.arena.clamp_inside(battle.player.position + Vector2(0, -520), 80.0)
	var b := battle.enemies.spawn(battle.cfg.boss, p)
	if b:
		battle.start_boss(b, false)
