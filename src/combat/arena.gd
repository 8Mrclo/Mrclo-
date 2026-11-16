class_name Arena
extends Node2D
## Map ground, procedurally generated obstacles (deterministic per layout
## seed) and temporary walls. Collision is analytic (circles/rects) with a
## coarse static grid so each entity only tests nearby obstacles.

const OBST_CELL := 256.0

var bounds := Rect2()
var map_def: Dictionary
var palette: Dictionary
var obstacles: Array = []        # {"type": "rect"/"circle", "rect": Rect2, "c": Vector2, "r": float, "h": float}
var temp_walls: Array = []       # {"c", "r", "life"}
var _cells: Array = []           # Array[PackedInt32Array]
var _cols := 1
var _rows := 1
var _decor: Array = []
var _walls_layer: Node2D


func setup(m: Dictionary, decor_density: float) -> void:
	map_def = m
	palette = m.get("palette", {})
	var sz: Array = m.get("size", [3200, 3200])
	bounds = Rect2(-float(sz[0]) / 2.0, -float(sz[1]) / 2.0, float(sz[0]), float(sz[1]))
	_generate(m.get("layout", {}), decor_density)
	_build_grid()
	z_index = -10
	_walls_layer = Node2D.new()
	_walls_layer.z_index = 1
	_walls_layer.draw.connect(_draw_walls)
	add_child(_walls_layer)
	queue_redraw()


func _generate(layout: Dictionary, decor_density: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(layout.get("seed", 1))
	var clear := float(layout.get("clear_radius", 300))
	var style: String = layout.get("style", "ruins")
	var mn := float(layout.get("min_size", 50))
	var mx := float(layout.get("max_size", 150))
	var tries := 0
	while obstacles.size() < int(layout.get("count", 30)) and tries < 500:
		tries += 1
		var c := Vector2(rng.randf_range(bounds.position.x + 120, bounds.end.x - 120), rng.randf_range(bounds.position.y + 120, bounds.end.y - 120))
		if c.length() < clear + mx:
			continue
		var round_shape := style in ["antennas", "roots", "dome"] and rng.randf() < 0.6
		var o: Dictionary
		if round_shape:
			o = {"type": "circle", "c": c, "r": rng.randf_range(mn * 0.5, mx * 0.5)}
		else:
			var size := Vector2(rng.randf_range(mn, mx), rng.randf_range(mn, mx))
			o = {"type": "rect", "rect": Rect2(c - size / 2.0, size), "c": c, "r": size.length() / 2.0}
		var overlap := false
		for other in obstacles:
			if c.distance_to(other.c) < o.r + other.r + 90.0:
				overlap = true
				break
		if not overlap:
			obstacles.append(o)
	for i in int(float(layout.get("decor", 120)) * decor_density):
		_decor.append({"p": Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y)), "s": rng.randf_range(6, 22), "k": rng.randi_range(0, 2)})


func _build_grid() -> void:
	_cols = int(ceil(bounds.size.x / OBST_CELL))
	_rows = int(ceil(bounds.size.y / OBST_CELL))
	_cells.resize(_cols * _rows)
	for i in _cells.size():
		_cells[i] = PackedInt32Array()
	for idx in obstacles.size():
		var o: Dictionary = obstacles[idx]
		var r: float = o.r + 40.0
		var x0 := clampi(int((o.c.x - r - bounds.position.x) / OBST_CELL), 0, _cols - 1)
		var x1 := clampi(int((o.c.x + r - bounds.position.x) / OBST_CELL), 0, _cols - 1)
		var y0 := clampi(int((o.c.y - r - bounds.position.y) / OBST_CELL), 0, _rows - 1)
		var y1 := clampi(int((o.c.y + r - bounds.position.y) / OBST_CELL), 0, _rows - 1)
		for cy in range(y0, y1 + 1):
			for cx in range(x0, x1 + 1):
				_cells[cy * _cols + cx].append(idx)


func _cell(p: Vector2) -> int:
	var cx := clampi(int((p.x - bounds.position.x) / OBST_CELL), 0, _cols - 1)
	var cy := clampi(int((p.y - bounds.position.y) / OBST_CELL), 0, _rows - 1)
	return cy * _cols + cx


## Pushes a circle out of nearby obstacles (static + temporary walls).
func resolve_circle(p: Vector2, r: float) -> Vector2:
	for idx in _cells[_cell(p)]:
		p = _push_out(p, r, obstacles[idx])
	return p


func resolve_player(p: Vector2, r: float) -> Vector2:
	p = resolve_circle(p, r)
	for w in temp_walls:
		var d: Vector2 = p - w.c
		var min_d: float = w.r + r
		if d.length_squared() < min_d * min_d and d.length_squared() > 0.001:
			p = w.c + d.normalized() * min_d
	return clamp_inside(p, r)


func _push_out(p: Vector2, r: float, o: Dictionary) -> Vector2:
	if o.type == "circle":
		var d: Vector2 = p - o.c
		var min_d: float = o.r + r
		var l2 := d.length_squared()
		if l2 < min_d * min_d:
			if l2 < 0.001:
				return o.c + Vector2(min_d, 0)
			return o.c + d / sqrt(l2) * min_d
		return p
	var rect: Rect2 = o.rect
	var closest := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
	var diff := p - closest
	var l := diff.length()
	if l >= r:
		return p
	if l < 0.001:
		# Center inside the rect: exit through the nearest edge.
		var dl := p.x - rect.position.x
		var dr := rect.end.x - p.x
		var dt := p.y - rect.position.y
		var db := rect.end.y - p.y
		var m := minf(minf(dl, dr), minf(dt, db))
		if m == dl: return Vector2(rect.position.x - r, p.y)
		if m == dr: return Vector2(rect.end.x + r, p.y)
		if m == dt: return Vector2(p.x, rect.position.y - r)
		return Vector2(p.x, rect.end.y + r)
	return closest + diff / l * r


func is_blocked(p: Vector2, r: float) -> bool:
	for idx in _cells[_cell(p)]:
		if _push_out(p, r, obstacles[idx]) != p:
			return true
	return false


func clamp_inside(p: Vector2, r: float) -> Vector2:
	return Vector2(clampf(p.x, bounds.position.x + r, bounds.end.x - r), clampf(p.y, bounds.position.y + r, bounds.end.y - r))


func add_temp_wall(c: Vector2, r: float, life: float) -> void:
	if temp_walls.size() >= 18:
		temp_walls.pop_front()
	temp_walls.append({"c": c, "r": r, "life": life})
	_walls_layer.queue_redraw()


func update(delta: float) -> void:
	if temp_walls.is_empty():
		return
	for i in range(temp_walls.size() - 1, -1, -1):
		temp_walls[i].life -= delta
		if temp_walls[i].life <= 0.0:
			temp_walls.remove_at(i)
	_walls_layer.queue_redraw()


func _draw_walls() -> void:
	for w in temp_walls:
		var a := clampf(float(w.life), 0.0, 1.0)
		IconPainter.draw(_walls_layer, "hexagon", w.c, w.r, Color(Palette.VIOLET.lightened(0.2), 0.85 * a))
		_walls_layer.draw_arc(w.c, w.r, 0, TAU, 24, Color(Palette.MINT, a), 3)


func _draw() -> void:
	var ground := JsonUtil.color(palette.get("ground", ""), Palette.PETROL)
	var alt := JsonUtil.color(palette.get("ground_alt", ""), Palette.PETROL_MID)
	var detail := JsonUtil.color(palette.get("detail", ""), Palette.PETROL_LIGHT)
	var glow := JsonUtil.color(palette.get("glow", ""), Palette.MINT)
	draw_rect(bounds.grow(600), ground.darkened(0.45))
	draw_rect(bounds, ground)
	# Diagonal tiles: the map's signature pattern.
	var step := 220.0
	var x := bounds.position.x
	var row := 0
	while x < bounds.end.x:
		var y := bounds.position.y
		var col := row
		while y < bounds.end.y:
			if col % 2 == 0:
				draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + step, y), Vector2(x + step * 0.7, y + step), Vector2(x - step * 0.3, y + step)]), alt)
			y += step
			col += 1
		x += step
		row += 1
	var diag := bounds.position.x
	while diag < bounds.end.x + bounds.size.y:
		draw_line(Vector2(diag, bounds.position.y), Vector2(diag - bounds.size.y * 0.5, bounds.end.y), Color(detail, 0.35), 2.0)
		diag += 340.0
	for d in _decor:
		match d.k:
			0:
				draw_circle(d.p, d.s, Color(glow, 0.12))
				draw_circle(d.p, d.s * 0.35, Color(glow, 0.55))
			1:
				for i in 3:
					draw_line(d.p, d.p + Vector2.from_angle(-PI / 2 + (i - 1) * 0.5) * d.s * 1.6, Color(glow.darkened(0.2), 0.6), 3.0)
			_:
				draw_rect(Rect2(d.p, Vector2(d.s * 1.5, d.s * 0.5)), Color(detail, 0.5))
	var obst := JsonUtil.color(palette.get("obstacle", ""), Palette.PETROL_LIGHT)
	var top := JsonUtil.color(palette.get("obstacle_top", ""), Palette.TEAL)
	for o in obstacles:
		if o.type == "circle":
			draw_circle(o.c + Vector2(0, 10), o.r, Color(0, 0, 0, 0.3))
			draw_circle(o.c, o.r, obst)
			draw_circle(o.c + Vector2(-o.r * 0.15, -o.r * 0.15), o.r * 0.7, top)
			draw_circle(o.c, o.r * 0.18, Color(glow, 0.8))
		else:
			var r: Rect2 = o.rect
			draw_rect(Rect2(r.position + Vector2(0, 12), r.size), Color(0, 0, 0, 0.3))
			draw_rect(r, obst)
			draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.72)), top)
			draw_line(r.position + Vector2(6, r.size.y * 0.72), Vector2(r.end.x - 6, r.position.y + r.size.y * 0.72), Color(glow, 0.7), 2.0)
	draw_rect(bounds, Color(glow, 0.6), false, 6.0)
