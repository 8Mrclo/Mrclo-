extends AbilityRuntime
## Mina de Eco: mines dropped along the path, armed after a short delay.

var _mines: Array = []   # {pos, arm, life}
var _last_pos := Vector2.INF
var _dist := 0.0


func tick(delta: float) -> void:
	var pp: Vector2 = battle.player.position
	if _last_pos == Vector2.INF:
		_last_pos = pp
	_dist += pp.distance_to(_last_pos)
	_last_pos = pp
	var step := p("drop_distance") * stat("cooldown")
	if _dist >= step:
		_dist = 0.0
		_mines.append({"pos": pp, "arm": p("arm_time"), "life": p("lifetime") * stat("duration")})
		while _mines.size() > int(p("max_mines")) + extra_count() * 2:
			_mines.pop_front()
	var r := p("radius") * stat("area")
	for i in range(_mines.size() - 1, -1, -1):
		var m: Dictionary = _mines[i]
		m.arm -= delta
		m.life -= delta
		if m.life <= 0.0:
			_mines.remove_at(i)
			continue
		if m.arm > 0.0:
			continue
		var t := battle.enemies.nearest(m.pos, r * 0.55)
		if t:
			battle.area_damage(m.pos, r, p("damage"), slot, 160.0, flags)
			battle.fx.ring(m.pos, r, 0.3, color)
			Audio.play(&"boom")
			_mines.remove_at(i)


func draw_visual() -> void:
	for m in _mines:
		var armed: bool = m.arm <= 0.0
		IconPainter.draw(visual, "mine", m.pos, 11.0, color if armed else Color(color, 0.4))
		if armed and int(battle.time * 4.0) % 2 == 0:
			visual.draw_circle(m.pos, 4.0, Palette.CORAL)
