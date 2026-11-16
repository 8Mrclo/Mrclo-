class_name EnemySystem
extends RefCounted
## Central update of all enemies: state machines, separation, LOD, contact
## damage and status effects. Uses the SpatialGrid for every neighbor query.

const POOL := &"enemy"

var battle: Battle
var active: Array[Enemy] = []
var grid: SpatialGrid
var qbuf := PackedInt32Array()
var _sepbuf := PackedInt32Array()
var _next_uid := 1
var _near_r2 := 900.0 * 900.0
var _lod_interval := 3
var _separation := 0.55
var _aura_timer := 0.0
var boss: Enemy = null
var _grid_valid := false


func _init(b: Battle) -> void:
	battle = b
	grid = SpatialGrid.new(b.arena.bounds, 96.0)
	var near := float(Content.balance_value("run.lod_near_radius", 900))
	_near_r2 = near * near
	_lod_interval = int(Content.balance_value("run.lod_far_interval", 3))
	_separation = float(Content.balance_value("run.enemy_separation", 0.55))


func count() -> int:
	return active.size()


func spawn(id: String, pos: Vector2, champion: bool = false, extra_hp: float = 1.0) -> Enemy:
	var d: Dictionary = Content.enemy(id)
	if d.is_empty():
		return null
	var is_special: bool = d.get("is_boss", false) or d.get("is_elite", false)
	if not is_special and active.size() >= battle.limits.get("enemies", 380):
		return null
	var e: Enemy = battle.pools.acquire(POOL)
	if e == null:
		return null
	var t_min := battle.time / 60.0
	var sc: Dictionary = Content.balance_value("enemy_scaling", {})
	var hp_mult := (1.0 + t_min * float(sc.get("hp_per_minute", 0.3))) * float(battle.cfg.hp_mult) * extra_hp
	var dmg_mult := (1.0 + t_min * float(sc.get("damage_per_minute", 0.1))) * float(battle.cfg.damage_mult)
	var spd_mult := (1.0 + t_min * float(sc.get("speed_per_minute", 0.01))) * float(battle.cfg.enemy_speed_mult)
	if d.get("is_boss", false):
		hp_mult = float(battle.cfg.hp_mult) * extra_hp * (1.0 + t_min * 0.05)
	e.setup(d, int(battle.map_def.get("variant", 0)), hp_mult, dmg_mult, spd_mult, champion)
	e.uid = _next_uid
	_next_uid += 1
	e.position = pos
	if battle.device != null and battle.cfg.device_target_chance > 0.0 and not e.is_boss:
		e.targets_device = battle.rng.randf() < float(battle.cfg.device_target_chance)
	active.append(e)
	Game.discover("enemies", id)
	return e


func update(delta: float, frame: int) -> void:
	grid.rebuild(active)
	_grid_valid = true
	var ppos: Vector2 = battle.player.position
	var prad: float = battle.player.radius
	_aura_timer -= delta
	var do_aura := _aura_timer <= 0.0
	if do_aura:
		_aura_timer = 0.5
	var n := active.size()
	for i in n:
		var e := active[i]
		if not e.alive:
			continue
		var d := delta
		var to_p := ppos - e.position
		var dist2 := to_p.length_squared()
		if dist2 > _near_r2 and not e.is_boss and not e.is_elite:
			e.lod_acc += delta
			if (frame + e.uid) % _lod_interval != 0:
				continue
			d = e.lod_acc
			e.lod_acc = 0.0
		_tick_status(e, d)
		if not e.alive:
			continue
		if e.state == Enemy.State.SPAWN:
			e.spawn_t -= d
			if e.spawn_t <= 0.0:
				e.spawn_t = 0.0
				e.state = Enemy.State.MOVE
		var target := ppos
		if e.targets_device and battle.device != null:
			target = battle.device.position
		var to_t := target - e.position
		var dir := to_t.normalized() if to_t.length_squared() > 1.0 else Vector2.ZERO
		var spd := e.speed
		if e.slow_t > 0.0:
			spd *= 1.0 - e.slow_f
		if e.buff_t > 0.0:
			spd *= 1.0 + e.buff_speed
		if e.stun_t > 0.0:
			e.vel = Vector2.ZERO
		elif e.state != Enemy.State.SPAWN:
			match e.behavior:
				Enemy.Behavior.FLYER:
					var amp := float(e.def.get("params", {}).get("weave_amp", 0.8))
					var fq := float(e.def.get("params", {}).get("weave_freq", 4.0))
					e.vel = dir.rotated(sin(battle.time * fq + e.phase) * amp) * spd
					_elite_skill(e, d, to_p, dist2)
				Enemy.Behavior.RANGED:
					_ranged(e, d, dir, spd, dist2)
				Enemy.Behavior.BUFFER:
					_buffer(e, d, dir, spd, dist2, do_aura)
				Enemy.Behavior.CHARGER:
					_charger(e, d, dir, spd, dist2)
				Enemy.Behavior.SHAPER:
					_shaper(e, d, dir, spd)
				Enemy.Behavior.BOSS:
					pass # BossController drives velocity
				_:
					e.vel = dir * spd
					_elite_skill(e, d, to_p, dist2)
		# Separation (staggered: half of the near enemies per frame).
		if not e.is_boss and (frame + e.uid) % 2 == 0 and dist2 < _near_r2:
			e.vel += _separate(e) * spd * _separation
		e.position += (e.vel + e.knock) * d
		e.knock *= maxf(0.0, 1.0 - 8.0 * d)
		if not e.flying and not e.is_boss:
			e.position = battle.arena.resolve_circle(e.position, e.radius * 0.8)
		e.position = battle.arena.clamp_inside(e.position, e.radius)
		if e.vel.x != 0.0 and not e.is_boss:
			e.rotation = e.vel.angle() if e.shape in ["triangle", "arrow"] else 0.0
		# Contact damage.
		if e.state != Enemy.State.SPAWN and not e.hidden_boss:
			var reach := e.radius + prad
			if (ppos - e.position).length_squared() < reach * reach:
				battle.damage_player(e.damage, e.position)
			if battle.device != null:
				var dr: float = e.radius + battle.device_radius
				if (battle.device.position - e.position).length_squared() < dr * dr:
					battle.damage_device(e.damage * d * 1.5)


func _tick_status(e: Enemy, d: float) -> void:
	var tint_needed := e.flash_t > 0.0 or e.spawn_t > 0.0 or e.slow_t > 0.0 or e.stun_t > 0.0 or e.hidden_boss
	if e.flash_t > 0.0: e.flash_t -= d
	if e.slow_t > 0.0: e.slow_t -= d
	if e.stun_t > 0.0: e.stun_t -= d
	if e.mark_t > 0.0: e.mark_t -= d
	if e.buff_t > 0.0: e.buff_t -= d
	if e.invuln_t > 0.0: e.invuln_t -= d
	if tint_needed or e.modulate != Color.WHITE:
		e.refresh_tint()
	if e.dot_t > 0.0:
		e.dot_t -= d
		battle.damage_enemy(e, e.dot_dps * d, -1, Vector2.ZERO, 0.0, Battle.FLAG_NO_CRIT | Battle.FLAG_NO_FX)
	if e.dmg_timer > 0.0:
		e.dmg_timer -= d
		if e.dmg_timer <= 0.0:
			battle.numbers.emit_number(e.position + Vector2(0, -e.radius), e.dmg_accum, e.dmg_crit)
			e.dmg_accum = 0.0
			e.dmg_crit = false


func _separate(e: Enemy) -> Vector2:
	grid.query(e.position, e.radius * 2.0, _sepbuf)
	var push := Vector2.ZERO
	var checked := 0
	for j in _sepbuf:
		if checked >= 8:
			break
		var o := active[j]
		if o == e or not o.alive:
			continue
		checked += 1
		var diff := e.position - o.position
		var min_d := e.radius + o.radius
		var l2 := diff.length_squared()
		if l2 < min_d * min_d and l2 > 0.01:
			var l := sqrt(l2)
			push += diff / l * (1.0 - l / min_d) * (o.mass / (o.mass + e.mass)) * 2.0
	return push


func _p(e: Enemy, key: String, fallback: float) -> float:
	return float(e.def.get("params", {}).get(key, fallback))


func _ranged(e: Enemy, d: float, dir: Vector2, spd: float, dist2: float) -> void:
	var rng := _p(e, "range", 330.0)
	e.state_t -= d
	match e.state:
		Enemy.State.MOVE:
			e.vel = dir * spd if dist2 > rng * rng * 0.8 else dir.orthogonal() * spd * 0.35
			e.cooldown -= d
			if dist2 < rng * rng and e.cooldown <= 0.0:
				e.state = Enemy.State.TELEGRAPH
				e.state_t = _p(e, "telegraph", 0.6)
				e.aux = dir
				battle.fx.telegraph_line(e.position, e.position + dir * rng, 10.0, e.state_t, Palette.CORAL)
		Enemy.State.TELEGRAPH:
			e.vel = Vector2.ZERO
			if e.state_t <= 0.0:
				battle.projectiles.fire_hostile(e.position, e.aux, _p(e, "proj_speed", 250.0), e.damage * _p(e, "proj_damage", e.damage) / maxf(float(e.def.damage), 1.0), 9.0, e.body_color.lightened(0.3))
				e.state = Enemy.State.MOVE
				e.cooldown = _p(e, "cooldown", 2.5)


func _buffer(e: Enemy, d: float, dir: Vector2, spd: float, dist2: float, do_aura: bool) -> void:
	var keep := _p(e, "keep_distance", 250.0)
	if dist2 < keep * keep * 0.8:
		e.vel = -dir * spd * 0.8
	elif dist2 > keep * keep * 1.3:
		e.vel = dir * spd
	else:
		e.vel = dir.orthogonal() * spd * 0.5
	if do_aura:
		grid.query(e.position, _p(e, "aura_radius", 170.0), qbuf)
		var r2 := _p(e, "aura_radius", 170.0) ** 2
		for j in qbuf:
			var o := active[j]
			if o != e and o.alive and not o.is_boss and (o.position - e.position).length_squared() < r2:
				o.buff_t = 0.6
				o.buff_speed = _p(e, "speed_bonus", 0.3)
				o.buff_resist = _p(e, "resist_bonus", 0.2)
	_elite_skill(e, d, battle.player.position - e.position, dist2)


func _charger(e: Enemy, d: float, dir: Vector2, spd: float, dist2: float) -> void:
	var trig := _p(e, "trigger_range", 300.0)
	e.state_t -= d
	match e.state:
		Enemy.State.MOVE:
			e.vel = dir * spd
			e.cooldown -= d
			if dist2 < trig * trig and e.cooldown <= 0.0:
				_begin_dash_telegraph(e, dir)
				e.aux_i = int(_p(e, "chain", 1))
		Enemy.State.TELEGRAPH:
			e.vel = Vector2.ZERO
			if e.state_t <= 0.0:
				e.state = Enemy.State.ACTION
				e.state_t = _p(e, "dash_time", 0.5)
		Enemy.State.ACTION:
			e.vel = e.aux * _p(e, "dash_speed", 520.0)
			if e.state_t <= 0.0:
				e.aux_i -= 1
				if e.aux_i > 0:
					_begin_dash_telegraph(e, (battle.player.position - e.position).normalized())
				else:
					e.state = Enemy.State.RECOVER
					e.state_t = _p(e, "recover", 0.9)
		Enemy.State.RECOVER:
			e.vel = dir * spd * 0.25
			if e.state_t <= 0.0:
				e.state = Enemy.State.MOVE
				e.cooldown = randf_range(1.5, 3.0)


func _begin_dash_telegraph(e: Enemy, dir: Vector2) -> void:
	e.state = Enemy.State.TELEGRAPH
	e.state_t = _p(e, "telegraph", 0.75)
	e.aux = dir
	var length := _p(e, "dash_speed", 520.0) * _p(e, "dash_time", 0.5)
	battle.fx.telegraph_line(e.position, e.position + dir * length, e.radius * 2.0, e.state_t, Palette.CORAL)


func _shaper(e: Enemy, d: float, dir: Vector2, spd: float) -> void:
	e.state_t -= d
	match e.state:
		Enemy.State.MOVE:
			e.vel = dir * spd
			e.cooldown -= d
			if e.cooldown <= 0.0 and (battle.player.position - e.position).length() < 520.0:
				e.state = Enemy.State.TELEGRAPH
				e.state_t = _p(e, "telegraph", 0.85)
				# Walls appear ahead of the player's movement, never on top of them.
				var ahead: Vector2 = battle.player.position + battle.player.move_dir * 170.0 + Vector2(battle.rng.randf_range(-60, 60), battle.rng.randf_range(-60, 60))
				e.aux = ahead
				for k in int(_p(e, "wall_count", 3)):
					var p := ahead + Vector2.from_angle(TAU * k / 3.0) * 70.0
					battle.fx.telegraph_circle(p, _p(e, "wall_radius", 34.0), e.state_t, Palette.VIOLET)
		Enemy.State.TELEGRAPH:
			e.vel = Vector2.ZERO
			if e.state_t <= 0.0:
				for k in int(_p(e, "wall_count", 3)):
					var p := e.aux + Vector2.from_angle(TAU * k / 3.0) * 70.0
					if (p - battle.player.position).length() > _p(e, "wall_radius", 34.0) + battle.player.radius + 4.0:
						battle.arena.add_temp_wall(p, _p(e, "wall_radius", 34.0), _p(e, "wall_life", 5.0))
				e.state = Enemy.State.MOVE
				e.cooldown = _p(e, "cooldown", 6.5)


## Elite special skills layered on top of the base behavior.
func _elite_skill(e: Enemy, d: float, to_p: Vector2, dist2: float) -> void:
	var skill: String = e.def.get("elite_skill", "")
	if skill == "" or skill == "triple_dash":
		return
	if e.state == Enemy.State.TELEGRAPH:
		e.vel = Vector2.ZERO
		e.state_t -= d
		if e.state_t <= 0.0:
			_execute_elite(e, skill, to_p)
			e.state = Enemy.State.MOVE
			e.cooldown = _p(e, "skill_cooldown", 5.0)
		return
	e.cooldown -= d
	if e.cooldown <= 0.0 and dist2 < 600.0 * 600.0:
		e.state = Enemy.State.TELEGRAPH
		e.state_t = _p(e, "telegraph", 0.8)
		match skill:
			"slam":
				battle.fx.telegraph_circle(e.position, _p(e, "slam_radius", 170.0), e.state_t, Palette.CORAL)
			"ring_volley":
				battle.fx.telegraph_circle(e.position, e.radius * 2.0, e.state_t, Palette.VIOLET)
			"brood":
				battle.fx.telegraph_circle(e.position, e.radius * 1.6, e.state_t, Palette.MINT)
		Audio.play(&"telegraph")


func _execute_elite(e: Enemy, skill: String, to_p: Vector2) -> void:
	match skill:
		"slam":
			var r := _p(e, "slam_radius", 170.0)
			battle.fx.ring(e.position, r, 0.35, Palette.CORAL)
			if (battle.player.position - e.position).length() < r + battle.player.radius:
				battle.damage_player(_p(e, "slam_damage", 24.0) * float(battle.cfg.damage_mult), e.position)
			battle.shake(0.35)
		"ring_volley":
			battle.projectiles.ring_with_gap(e.position, int(_p(e, "ring_count", 18)), _p(e, "gap_degrees", 60.0), to_p.angle(), _p(e, "proj_speed", 200.0), _p(e, "proj_damage", 11.0) * float(battle.cfg.damage_mult))
		"brood":
			for k in int(_p(e, "brood_count", 6)):
				spawn(e.def.params.get("brood_id", "glass_wasp"), e.position + Vector2.from_angle(TAU * k / 6.0) * (e.radius + 20.0))


# ---------------------------------------------------------------- queries

func query(pos: Vector2, r: float) -> PackedInt32Array:
	if not _grid_valid:
		grid.rebuild(active)
		_grid_valid = true
	grid.query(pos, r + 64.0, qbuf)
	return qbuf


func nearest(pos: Vector2, max_r: float, exclude_uid: int = -1) -> Enemy:
	var best: Enemy = null
	var best_d := max_r * max_r
	for j in query(pos, max_r):
		var e := active[j]
		if not e.alive or e.uid == exclude_uid or e.hidden_boss:
			continue
		var dd := (e.position - pos).length_squared()
		if dd < best_d:
			best_d = dd
			best = e
	return best


## Removes dead enemies (swap-remove) and returns nodes to the pool.
func compact() -> void:
	var i := 0
	while i < active.size():
		var e := active[i]
		if e.alive:
			i += 1
			continue
		active[i] = active[active.size() - 1]
		active.pop_back()
		battle.pools.release(e)
		_grid_valid = false


func clear_all(include_bosses: bool) -> void:
	for e in active:
		if e.alive and (include_bosses or not (e.is_boss or e.is_elite)):
			battle.kill_enemy(e, false)
