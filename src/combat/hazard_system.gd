class_name HazardSystem
extends Node2D
## Environmental hazards from map data, plus dynamic zones created by bosses.
## Types: slow_zone, pulse_zone (telegraphed periodic damage), dot_zone,
## flare (telegraphed line across the player), debris (telegraphed impacts).

var battle: Battle
var zones: Array = []        # {type, c, r, color, factor, dps, period, t, tele, damage, life}
var _timers: Dictionary = {}
var player_slow := 1.0


func setup(b: Battle, defs: Array) -> void:
	battle = b
	z_index = -5
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b.map_def.get("layout", {}).get("seed", 1)) + 77
	for h in defs:
		match h.type:
			"slow_zone", "pulse_zone", "dot_zone":
				for i in int(h.get("count", 4)):
					var c := _free_point(rng, float(h.radius))
					zones.append({"type": h.type, "c": c, "r": float(h.radius), "color": JsonUtil.color(h.get("color", ""), Palette.TEAL),
						"factor": float(h.get("factor", 1.0)), "dps": float(h.get("dps", 0.0)), "period": float(h.get("period", 6.0)),
						"t": rng.randf() * float(h.get("period", 6.0)), "tele": float(h.get("telegraph", 1.0)), "damage": float(h.get("damage", 0.0)), "life": -1.0})
			"flare", "debris":
				_timers[h.type] = {"def": h, "t": float(h.get("interval", 8.0))}


func _free_point(rng: RandomNumberGenerator, r: float) -> Vector2:
	for i in 30:
		var p := Vector2(rng.randf_range(battle.arena.bounds.position.x + r, battle.arena.bounds.end.x - r), rng.randf_range(battle.arena.bounds.position.y + r, battle.arena.bounds.end.y - r))
		if p.length() > 360.0 and not battle.arena.is_blocked(p, r * 0.5):
			return p
	return battle.arena.bounds.position + Vector2(r, r)


func add_dynamic_zone(c: Vector2, r: float, dps: float, life: float, color: Color) -> void:
	zones.append({"type": "dot_zone", "c": c, "r": r, "color": color, "factor": 1.0, "dps": dps, "period": 1.0, "t": 0.0, "tele": 0.0, "damage": 0.0, "life": life})


func update(delta: float) -> void:
	var pp: Vector2 = battle.player.position
	var pr: float = battle.player.radius
	player_slow = 1.0
	var dm := float(battle.cfg.damage_mult)
	for i in range(zones.size() - 1, -1, -1):
		var z: Dictionary = zones[i]
		if z.life > 0.0:
			z.life -= delta
			if z.life <= 0.0:
				zones.remove_at(i)
				continue
		var inside: bool = pp.distance_to(z.c) < z.r + pr * 0.5
		match z.type:
			"slow_zone":
				if inside:
					player_slow = minf(player_slow, z.factor)
			"dot_zone":
				if inside:
					battle.damage_player(z.dps * dm, z.c, true, delta)
			"pulse_zone":
				z.t -= delta
				if z.t <= 0.0:
					z.t = z.period
					battle.fx.telegraph_circle(z.c, z.r, z.tele, z.color)
					z["fire_at"] = battle.time + z.tele
				if z.has("fire_at") and battle.time >= float(z.fire_at):
					z.erase("fire_at")
					battle.fx.ring(z.c, z.r, 0.3, z.color)
					if inside:
						battle.damage_player(z.damage * dm, z.c)
	for key in _timers:
		var tm: Dictionary = _timers[key]
		tm.t -= delta
		if tm.t <= 0.0:
			tm.t = float(tm.def.get("interval", 8.0))
			_fire_timed(key, tm.def)
	_resolve_pending()
	queue_redraw()


var _pending: Array = []


func _fire_timed(kind: String, h: Dictionary) -> void:
	var pp: Vector2 = battle.player.position
	var tele := maxf(float(h.get("telegraph", 1.0)), 0.6)
	var color := JsonUtil.color(h.get("color", ""), Palette.AMBER)
	if kind == "flare":
		var a := battle.rng.randf() * PI
		var dir := Vector2.from_angle(a)
		var from := pp - dir * 900.0
		var to := pp + dir * 900.0
		battle.fx.telegraph_line(from, to, float(h.width), tele, color)
		_pending.append({"kind": "line", "from": from, "to": to, "w": float(h.width), "at": battle.time + tele, "damage": float(h.damage), "color": color})
	else:
		var p := pp + Vector2(battle.rng.randf_range(-140, 140), battle.rng.randf_range(-140, 140))
		battle.fx.telegraph_circle(p, float(h.radius), tele, color)
		_pending.append({"kind": "circle", "c": p, "r": float(h.radius), "at": battle.time + tele, "damage": float(h.damage), "color": color})


func _resolve_pending() -> void:
	var pp: Vector2 = battle.player.position
	var pr: float = battle.player.radius
	var dm := float(battle.cfg.damage_mult)
	for i in range(_pending.size() - 1, -1, -1):
		var e: Dictionary = _pending[i]
		if battle.time < float(e.at):
			continue
		_pending.remove_at(i)
		if e.kind == "line":
			battle.fx.beam(e.from, e.to, e.w, 0.3, e.color)
			if Geometry2D.get_closest_point_to_segment(pp, e.from, e.to).distance_to(pp) < e.w * 0.5 + pr:
				battle.damage_player(e.damage * dm, e.from)
		else:
			battle.fx.ring(e.c, e.r, 0.3, e.color)
			if pp.distance_to(e.c) < e.r + pr:
				battle.damage_player(e.damage * dm, e.c)


func _draw() -> void:
	var t := battle.time if battle else 0.0
	for z in zones:
		var col: Color = z.color
		match z.type:
			"slow_zone":
				draw_circle(z.c, z.r, Color(col, 0.18))
				draw_arc(z.c, z.r * (0.7 + 0.05 * sin(t * 2.0)), 0, TAU, 32, Color(col, 0.35), 2)
			"dot_zone":
				draw_circle(z.c, z.r, Color(col, 0.25))
				draw_circle(z.c + Vector2(sin(t) * 10, 0), z.r * 0.5, Color(col, 0.2))
			"pulse_zone":
				draw_circle(z.c, 14, col)
				draw_line(z.c, z.c + Vector2(0, -50), col, 4)
				draw_arc(z.c, z.r, 0, TAU, 32, Color(col, 0.25), 2)
