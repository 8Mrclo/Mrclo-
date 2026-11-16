class_name BossController
extends Node2D
## Drives one boss: 3 phases (hp thresholds), each with a deterministic
## opening sequence followed by weighted-random attacks from its pool.
## Fairness rules (no unavoidable attacks):
##  - every attack is telegraphed for >= 0.5s (data values clamped below);
##  - radial volleys always keep a gap aimed near the player;
##  - beam sweeps cover a bounded arc shown during the telegraph;
##  - darkness always spawns one safe zone within reach of the player;
##  - a rest period separates attacks; phase changes grant brief invulnerability.

const MIN_TELEGRAPH := 0.5

var battle: Battle
var boss: Enemy
var def: Dictionary
var phase := 0
var _seq_index := 0
var _state := "rest"
var _t := 1.5
var _attack := ""
var _a: Dictionary = {}
var _targets: Array = []        # telegraph positions / angles
var _sub_t := 0.0
var _sub_n := 0
var mirrors: Array = []         # {pos, r, life}
var _beams: Array = []          # angles (radians)
var _beam_dir := 1.0
var _dark_active := false
var _dark_center := Vector2.ZERO
var _dark_area := 0.0
var _dark_safe: Array = []
var _dark_t := 0.0
var _dark_cfg: Dictionary = {}
var _beam_tick := 0.0
var is_mid := false
var enrage := 1.0


func setup(b: Battle, e: Enemy, mid: bool) -> void:
	battle = b
	boss = e
	def = e.def
	is_mid = mid
	z_index = 5


func phases() -> Array:
	return def.get("phases", [])


func update(delta: float) -> void:
	if not is_instance_valid(boss) or not boss.alive:
		return
	_check_phase()
	var ph: Dictionary = phases()[phase]
	var spd := boss.speed * float(ph.get("speed_mult", 1.0))
	var to_p: Vector2 = battle.player.position - boss.position
	_t -= delta
	for i in range(mirrors.size() - 1, -1, -1):
		mirrors[i].life -= delta
		if mirrors[i].life <= 0.0:
			mirrors.remove_at(i)
	match _state:
		"rest":
			boss.vel = to_p.normalized() * spd if to_p.length() > boss.radius + 80.0 else Vector2.ZERO
			if _t <= 0.0:
				_choose_attack()
		"telegraph":
			boss.vel = Vector2.ZERO
			if _t <= 0.0:
				_execute()
		"active":
			_active(delta, to_p)
	_update_darkness(delta)
	queue_redraw()


func _check_phase() -> void:
	var ratio := boss.hp / boss.max_hp
	var ph := phases()
	var target := 0
	for i in ph.size():
		if ratio <= float(ph[i].threshold) + 0.0001:
			target = i
	if target > phase:
		phase = target
		_seq_index = 0
		boss.invuln_t = 0.8
		battle.fx.ring(boss.position, boss.radius * 3.0, 0.6, Palette.AMBER)
		battle.shake(0.6)
		EventBus.boss_phase_changed.emit(phase + 1)
		battle.announce(Loc.t("battle.boss_phase", {"n": phase + 1}))
		_end_attack(0.8)


func _choose_attack() -> void:
	var ph: Dictionary = phases()[phase]
	var seq: Array = ph.get("sequence", [])
	if _seq_index < seq.size():
		_attack = seq[_seq_index]
		_seq_index += 1
	else:
		var pool: Array = ph.get("random", seq)
		_attack = pool[battle.rng.randi_range(0, pool.size() - 1)]
	_a = def.get("attacks", {}).get(_attack, {})
	_state = "telegraph"
	_t = maxf(float(_a.get("telegraph", 0.8)), MIN_TELEGRAPH)
	_targets.clear()
	Audio.play(&"telegraph")
	var pp: Vector2 = battle.player.position
	match _attack:
		"charge":
			var dir := (pp - boss.position).normalized()
			_targets = [dir]
			battle.fx.telegraph_line(boss.position, boss.position + dir * float(_a.speed) * float(_a.time), boss.radius * 1.6, _t, Palette.CORAL)
		"quake":
			for k in int(_a.count):
				var p := pp + Vector2.from_angle(battle.rng.randf() * TAU) * battle.rng.randf_range(0.0, float(_a.spread))
				p = battle.arena.clamp_inside(p, 30.0)
				_targets.append(p)
				battle.fx.telegraph_circle(p, float(_a.radius), _t, Palette.AMBER)
		"burrow":
			boss.hidden_boss = true
			boss.invuln_t = _t + float(_a.get("hide", 0.6))
			_targets = [pp]
			battle.fx.telegraph_circle(pp, float(_a.radius), _t, Palette.CORAL)
		"summon":
			battle.fx.telegraph_circle(boss.position, boss.radius * 2.0, _t, Palette.MINT)
		"fan", "ring":
			battle.fx.telegraph_circle(boss.position, boss.radius * 1.8, _t, Palette.VIOLET)
		"mirrors":
			for k in int(_a.count):
				var p := battle.arena.clamp_inside(pp + Vector2.from_angle(TAU * k / float(_a.count) + battle.rng.randf()) * 230.0, 40.0)
				_targets.append(p)
				battle.fx.telegraph_circle(p, float(_a.radius), _t, Palette.MINT)
		"sweep":
			var base := (pp - boss.position).angle() + PI * 0.5
			_beams.clear()
			for k in int(_a.beams):
				_beams.append(base + TAU * k / float(_a.beams))
			_beam_dir = 1.0 if battle.rng.randf() < 0.5 else -1.0
			var arc := float(_a.duration) * float(_a.turn) * _beam_dir
			for a in _beams:
				battle.fx.telegraph_line(boss.position, boss.position + Vector2.from_angle(a) * float(_a.length), float(_a.width), _t, Palette.AMBER)
				battle.fx.telegraph_line(boss.position, boss.position + Vector2.from_angle(a + arc) * float(_a.length), 6.0, _t, Palette.AMBER)
		"darkness":
			_dark_center = boss.position
			_dark_area = float(_a.area)
			_dark_safe.clear()
			# First safe zone guaranteed close to the player.
			_dark_safe.append(battle.arena.clamp_inside(pp + Vector2.from_angle(battle.rng.randf() * TAU) * 120.0, 40.0))
			for k in int(_a.safe_count) - 1:
				_dark_safe.append(battle.arena.clamp_inside(_dark_center + Vector2.from_angle(battle.rng.randf() * TAU) * battle.rng.randf_range(150, _dark_area * 0.7), 40.0))
			for s in _dark_safe:
				battle.fx.telegraph_circle(s, float(_a.safe_radius), _t, Palette.MINT)
			battle.fx.telegraph_circle(_dark_center, _dark_area, _t, Palette.VIOLET)
		"roots":
			var base := (pp - boss.position).angle()
			for k in int(_a.lines):
				var a := base + TAU * k / float(_a.lines)
				_targets.append(a)
				battle.fx.telegraph_line(boss.position, boss.position + Vector2.from_angle(a) * float(_a.length), float(_a.width), _t, Palette.GREEN)
		"sludge":
			for k in int(_a.count):
				var p := battle.arena.clamp_inside(pp + Vector2.from_angle(battle.rng.randf() * TAU) * battle.rng.randf_range(60.0, float(_a.spread)), 40.0)
				_targets.append(p)
				battle.fx.telegraph_circle(p, float(_a.radius), _t, Palette.GREEN)


func _execute() -> void:
	var dm := float(battle.cfg.damage_mult) * enrage
	match _attack:
		"charge":
			_state = "active"
			_t = float(_a.time)
			boss.vel = _targets[0] * float(_a.speed)
			return
		"quake":
			for p in _targets:
				_area_hit(p, float(_a.radius), float(_a.damage) * dm)
			battle.shake(0.5)
		"burrow":
			boss.hidden_boss = false
			boss.position = _targets[0]
			_area_hit(boss.position, float(_a.radius), float(_a.damage) * dm)
			battle.shake(0.6)
		"summon":
			for k in int(_a.count):
				battle.enemies.spawn(_a.enemy, battle.arena.clamp_inside(boss.position + Vector2.from_angle(TAU * k / float(_a.count)) * (boss.radius + 50.0), 30.0))
		"fan":
			_state = "active"
			_sub_n = int(_a.volleys)
			_sub_t = 0.0
			_t = 99.0
			return
		"ring":
			var to_p: Vector2 = battle.player.position - boss.position
			battle.projectiles.ring_with_gap(boss.position, int(_a.count), float(_a.gap_degrees), to_p.angle() + battle.rng.randf_range(-0.3, 0.3), float(_a.proj_speed), float(_a.damage) * dm)
		"mirrors":
			for p in _targets:
				mirrors.append({"pos": p, "r": float(_a.radius), "life": float(_a.life), "copies": int(_a.max_copies)})
		"sweep":
			_state = "active"
			_t = float(_a.duration)
			_beam_tick = 0.0
			return
		"darkness":
			_dark_active = true
			_dark_cfg = _a
			_dark_t = float(_a.duration)
		"roots":
			for a in _targets:
				var to := boss.position + Vector2.from_angle(a) * float(_a.length)
				battle.fx.beam(boss.position, to, float(_a.width), 0.4, Palette.GREEN)
				if Geometry2D.get_closest_point_to_segment(battle.player.position, boss.position, to).distance_to(battle.player.position) < float(_a.width) * 0.5 + battle.player.radius:
					battle.damage_player(float(_a.damage) * dm, boss.position)
		"sludge":
			for p in _targets:
				battle.hazards.add_dynamic_zone(p, float(_a.radius), float(_a.dps) * dm, float(_a.life), Palette.GREEN)
	_end_attack(float(phases()[phase].get("rest", 1.0)))


func _active(delta: float, to_p: Vector2) -> void:
	match _attack:
		"charge":
			if _t <= 0.0:
				boss.vel = Vector2.ZERO
				_end_attack(float(phases()[phase].get("rest", 1.0)))
		"fan":
			_sub_t -= delta
			boss.vel = Vector2.ZERO
			if _sub_t <= 0.0:
				_sub_n -= 1
				_sub_t = 0.45
				var n := int(_a.count)
				var spread := deg_to_rad(float(_a.spread_degrees))
				for k in n:
					var a := to_p.angle() - spread * 0.5 + spread * k / maxf(n - 1, 1)
					battle.projectiles.fire_hostile(boss.position, Vector2.from_angle(a), float(_a.proj_speed), float(_a.damage) * float(battle.cfg.damage_mult) * enrage, 10.0, Palette.MINT)
				if _sub_n <= 0:
					_end_attack(float(phases()[phase].get("rest", 1.0)))
		"sweep":
			boss.vel = Vector2.ZERO
			for i in _beams.size():
				_beams[i] += float(_a.turn) * _beam_dir * delta
			_beam_tick -= delta
			if _beam_tick <= 0.0:
				_beam_tick = float(_a.get("tick", 0.25))
				for a in _beams:
					var to := boss.position + Vector2.from_angle(a) * float(_a.length)
					if Geometry2D.get_closest_point_to_segment(battle.player.position, boss.position, to).distance_to(battle.player.position) < float(_a.width) * 0.5 + battle.player.radius:
						battle.damage_player(float(_a.damage) * float(battle.cfg.damage_mult) * enrage, boss.position)
			if _t <= 0.0:
				_beams.clear()
				_end_attack(float(phases()[phase].get("rest", 1.0)))


func _end_attack(rest: float) -> void:
	_state = "rest"
	_t = rest
	boss.hidden_boss = false


func _area_hit(p: Vector2, r: float, dmg: float) -> void:
	battle.fx.ring(p, r, 0.35, Palette.AMBER)
	if p.distance_to(battle.player.position) < r + battle.player.radius:
		battle.damage_player(dmg, p)


func _update_darkness(delta: float) -> void:
	if not _dark_active:
		return
	_dark_t -= delta
	if _dark_t <= 0.0:
		_dark_active = false
		return
	var pp: Vector2 = battle.player.position
	if pp.distance_to(_dark_center) > _dark_area:
		return
	for s in _dark_safe:
		if pp.distance_to(s) < float(_dark_cfg.get("safe_radius", 150.0)):
			return
	battle.damage_player(float(_dark_cfg.get("dps", 18.0)) * float(battle.cfg.damage_mult), _dark_center, true, delta)


## Mirrors duplicate a hostile projectile once per mirror pass.
func try_mirror(pos: Vector2) -> Dictionary:
	for m in mirrors:
		if m.copies > 0 and pos.distance_to(m.pos) < m.r:
			m.copies -= 1
			return m
	return {}


func _draw() -> void:
	for m in mirrors:
		var p: Vector2 = m.pos - global_position
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -m.r), p + Vector2(m.r * 0.6, 0), p + Vector2(0, m.r), p + Vector2(-m.r * 0.6, 0)]), Color(Palette.MINT, 0.55))
		draw_arc(p, m.r * 1.2, 0, TAU, 24, Palette.SAND, 2)
	if not _beams.is_empty() and _state == "active" and is_instance_valid(boss):
		for a in _beams:
			var from := boss.position - global_position
			var to := from + Vector2.from_angle(a) * float(_a.length)
			draw_line(from, to, Color(Palette.AMBER, 0.5), float(_a.width))
			draw_line(from, to, Color(1, 1, 0.85, 0.9), float(_a.width) * 0.35)
	if _dark_active:
		var c := _dark_center - global_position
		draw_circle(c, _dark_area, Color(0.05, 0.0, 0.12, 0.55))
		for s in _dark_safe:
			draw_circle(s - global_position, float(_dark_cfg.get("safe_radius", 150.0)), Color(1.0, 0.95, 0.7, 0.28))
			draw_arc(s - global_position, float(_dark_cfg.get("safe_radius", 150.0)), 0, TAU, 40, Palette.AMBER, 3)
