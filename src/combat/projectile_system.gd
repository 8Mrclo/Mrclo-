class_name ProjectileSystem
extends RefCounted
## Moves player and hostile projectiles, resolves hits through the enemy grid,
## handles pierce/split/explode/homing/lob and the Silica Queen mirrors.

const POOL := &"projectile"
const HOSTILE_POOL := &"hostile"

var battle: Battle
var player_list: Array[Projectile] = []
var hostile_list: Array[Projectile] = []


func _init(b: Battle) -> void:
	battle = b


func count() -> int:
	return player_list.size() + hostile_list.size()


func _acquire(pool: StringName) -> Projectile:
	var p: Projectile = battle.pools.acquire(pool)
	if p == null:
		return null
	p.reset()
	return p


func fire(pos: Vector2, dir: Vector2, speed: float, damage: float, radius: float, kind: int, color: Color, slot: int, pierce: int = 0, life: float = 1.6) -> Projectile:
	var p := _acquire(POOL)
	if p == null:
		return null
	p.kind = kind
	p.position = pos
	p.speed = speed * float(battle.player.stats.get_stat("projectile_speed"))
	p.vel = dir.normalized() * p.speed
	p.rotation = p.vel.angle()
	p.damage = damage
	p.radius = radius
	p.color = color
	p.slot = slot
	p.pierce = pierce + int(battle.player.stats.get_stat("pierce"))
	p.life = life * clampf(float(battle.player.stats.get_stat("projectile_speed")), 0.7, 1.6)
	p.queue_redraw()
	player_list.append(p)
	return p


func lob(from: Vector2, to: Vector2, dur: float, color: Color, on_land: Callable) -> void:
	var p := _acquire(POOL)
	if p == null:
		on_land.call(to)
		return
	p.kind = Projectile.Kind.LOB
	p.lob_from = from
	p.lob_to = to
	p.lob_t = 0.0
	p.lob_dur = dur
	p.on_land = on_land
	p.radius = 12.0
	p.color = color
	p.position = from
	p.life = dur + 0.1
	p.queue_redraw()
	player_list.append(p)


func fire_hostile(pos: Vector2, dir: Vector2, speed: float, damage: float, radius: float, color: Color, copies: int = 1) -> void:
	var p := _acquire(HOSTILE_POOL)
	if p == null:
		return
	p.hostile = true
	p.kind = Projectile.Kind.ORB
	p.position = pos
	p.vel = dir.normalized() * speed
	p.damage = damage
	p.radius = radius
	p.color = color
	p.life = 6.0
	p.copies_left = copies
	p.queue_redraw()
	hostile_list.append(p)


## Radial volley with a guaranteed gap centered on gap_angle.
func ring_with_gap(pos: Vector2, count: int, gap_degrees: float, gap_angle: float, speed: float, damage: float) -> void:
	var half_gap := deg_to_rad(clampf(gap_degrees, 30.0, 180.0)) * 0.5
	for k in count:
		var a := TAU * k / count
		if absf(angle_difference(a, gap_angle)) < half_gap:
			continue
		fire_hostile(pos, Vector2.from_angle(a), speed, damage, 10.0, Palette.VIOLET.lightened(0.3))


func update(delta: float) -> void:
	_update_player(delta)
	_update_hostile(delta)


func _update_player(delta: float) -> void:
	var i := 0
	while i < player_list.size():
		var p := player_list[i]
		if p.active:
			_step_player(p, delta)
		if not p.active:
			player_list[i] = player_list[player_list.size() - 1]
			player_list.pop_back()
			battle.pools.release(p)
			continue
		i += 1


func _step_player(p: Projectile, delta: float) -> void:
	p.life -= delta
	if p.kind == Projectile.Kind.LOB:
		p.lob_t += delta
		var t := clampf(p.lob_t / p.lob_dur, 0.0, 1.0)
		p.position = p.lob_from.lerp(p.lob_to, t) + Vector2(0, -sin(t * PI) * 90.0)
		p.rotation += delta * 8.0
		if t >= 1.0:
			p.active = false
			if p.on_land.is_valid():
				p.on_land.call(p.lob_to)
		return
	if p.homing > 0.0:
		if p.target == null or not p.target.alive or p.target.uid != p.target_uid:
			p.target = battle.enemies.nearest(p.position, 520.0)
			p.target_uid = p.target.uid if p.target else -1
		if p.target:
			var desired := (p.target.position - p.position).normalized() * p.speed
			p.vel = p.vel.lerp(desired, clampf(p.homing * delta, 0.0, 1.0))
			p.rotation = p.vel.angle()
	p.position += p.vel * delta
	if p.life <= 0.0 or not battle.arena.bounds.has_point(p.position):
		p.active = false
		return
	var list := battle.enemies.query(p.position, p.radius)
	for j in list:
		var e: Enemy = battle.enemies.active[j]
		if not e.alive or e.hidden_boss:
			continue
		var reach := p.radius + e.radius
		if (e.position - p.position).length_squared() > reach * reach:
			continue
		if p.hits.has(e.uid):
			continue
		_hit(p, e)
		if not p.active:
			return


func _hit(p: Projectile, e: Enemy) -> void:
	p.hits.append(e.uid)
	var dir := p.vel.normalized()
	if p.explode_radius > 0.0:
		battle.area_damage(p.position, p.explode_radius, p.damage, p.slot, p.knock, p.flags)
		battle.fx.ring(p.position, p.explode_radius, 0.25, p.color)
		p.active = false
		return
	battle.damage_enemy(e, p.damage, p.slot, dir, p.knock, p.flags)
	if p.split_count > 0 and p.split_depth > 0:
		_split(p, e)
	p.pierce -= 1
	if p.pierce < 0:
		p.active = false


func _split(p: Projectile, e: Enemy) -> void:
	var base_a := p.vel.angle()
	for k in p.split_count:
		var a := base_a + (TAU * (k + 0.5) / p.split_count) * 0.8 - 0.8 * PI * 0.5
		var s := fire(e.position, Vector2.from_angle(a), p.speed * 0.9 / maxf(float(battle.player.stats.get_stat("projectile_speed")), 0.1), p.damage * p.split_pct, p.radius * 0.75, Projectile.Kind.SHARD, p.color.lightened(0.2), p.slot, p.split_pierce, 0.5)
		if s == null:
			return
		s.pierce = p.split_pierce
		s.hits.append(e.uid)
		s.split_count = p.split_count if p.split_depth > 1 else 0
		s.split_depth = p.split_depth - 1
		s.split_pct = p.split_pct
		s.split_pierce = p.split_pierce


func _update_hostile(delta: float) -> void:
	var ppos: Vector2 = battle.player.position
	var prad: float = battle.player.radius
	var i := 0
	while i < hostile_list.size():
		var p := hostile_list[i]
		p.life -= delta
		p.position += p.vel * delta
		if p.active and battle.boss_ctrl != null and p.copies_left > 0:
			var m: Dictionary = battle.boss_ctrl.try_mirror(p.position)
			if not m.is_empty():
				p.copies_left -= 1
				var dir := p.vel.normalized()
				fire_hostile(p.position, dir.rotated(0.6), p.vel.length(), p.damage, p.radius, Palette.MINT, 0)
				fire_hostile(p.position, dir.rotated(-0.6), p.vel.length(), p.damage, p.radius, Palette.MINT, 0)
		if p.active and (ppos - p.position).length_squared() < (prad + p.radius) ** 2:
			battle.damage_player(p.damage, p.position)
			p.active = false
		if p.life <= 0.0 or not battle.arena.bounds.has_point(p.position) or (p.active and battle.arena.is_blocked(p.position, 2.0)):
			p.active = false
		if not p.active:
			hostile_list[i] = hostile_list[hostile_list.size() - 1]
			hostile_list.pop_back()
			battle.pools.release(p)
			continue
		i += 1


func clear_hostile() -> void:
	for p in hostile_list:
		p.active = false
