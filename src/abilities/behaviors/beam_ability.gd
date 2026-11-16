extends AbilityRuntime
## Linha de Fótons / Meridiano: line beams; the evolution sweeps around.

var _sweep_t := 0.0
var _angles: Array[float] = []
var _tick := 0.0


func tick(delta: float) -> void:
	var length := p("length") * stat("area")
	var width := p("width") * stat("area")
	if _sweep_t > 0.0:
		_sweep_t -= delta
		for i in _angles.size():
			_angles[i] += 2.2 * delta
		_tick -= delta
		if _tick <= 0.0:
			_tick = p("tick", 0.2)
			for a in _angles:
				_hit_line(battle.player.position, Vector2.from_angle(a), length, width, true)
		visual.visible = _sweep_t > 0.0
		return
	visual.visible = false
	timer -= delta
	if timer > 0.0:
		return
	timer = interval(p("cooldown"))
	var origin: Vector2 = battle.player.position
	var base := aim_dir(origin, length).angle()
	var beams := int(p("beams")) + (extra_count() / 2)
	_angles.clear()
	for k in beams:
		_angles.append(base + TAU * k / beams)
	if p("sweep") > 0.0:
		_sweep_t = p("sweep") * stat("duration")
		_tick = 0.0
		return
	for a in _angles:
		_hit_line(origin, Vector2.from_angle(a), length, width, false)
		battle.fx.beam(origin, origin + Vector2.from_angle(a) * length, width, 0.25, color)
	Audio.play(&"zap")


func _hit_line(origin: Vector2, dir: Vector2, length: float, width: float, use_lock: bool) -> void:
	var to := origin + dir * length
	for e in battle.enemies.active:
		if not e.alive:
			continue
		var rel := e.position - origin
		var along := rel.dot(dir)
		if along < -e.radius or along > length + e.radius:
			continue
		if absf(rel.cross(dir)) > width * 0.5 + e.radius:
			continue
		if use_lock:
			if e.hit_lock[slot] > battle.time:
				continue
			e.hit_lock[slot] = battle.time + 0.3
		battle.damage_enemy(e, p("damage"), slot, dir, 40.0, flags)
	if use_lock and _tick == p("tick", 0.2):
		battle.fx.beam(origin, to, width, 0.12, color)


func draw_visual() -> void:
	var length := p("length") * stat("area")
	var width := p("width") * stat("area")
	for a in _angles:
		var o: Vector2 = battle.player.position
		visual.draw_line(o, o + Vector2.from_angle(a) * length, Color(color, 0.35), width)
		visual.draw_line(o, o + Vector2.from_angle(a) * length, Color(1, 1, 0.9, 0.85), width * 0.3)
