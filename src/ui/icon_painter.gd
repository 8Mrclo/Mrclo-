class_name IconPainter
extends RefCounted
## Procedural, original placeholder icons drawn with primitives.
## Used by UI (ShapeIcon) and by battle visuals, so no image assets are needed.


static func draw(ci: CanvasItem, shape: String, c: Vector2, r: float, col: Color, outline: Color = Color(0, 0, 0, 0)) -> void:
	var dark := col.darkened(0.55)
	match shape:
		"orbit":
			ci.draw_arc(c, r * 0.7, 0, TAU, 32, col, r * 0.12)
			for i in 3:
				var a := TAU * i / 3.0
				ci.draw_circle(c + Vector2.from_angle(a) * r * 0.7, r * 0.22, col.lightened(0.2))
			ci.draw_circle(c, r * 0.18, col)
		"bolt":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.15, -0.9) * r, c + Vector2(0.45, -0.9) * r, c + Vector2(0.05, -0.1) * r, c + Vector2(0.45, -0.1) * r, c + Vector2(-0.35, 0.95) * r, c + Vector2(-0.05, 0.1) * r, c + Vector2(-0.45, 0.1) * r]), col)
		"drone":
			ci.draw_circle(c, r * 0.4, col)
			for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				ci.draw_line(c, c + d * r * 0.55, dark, r * 0.12)
				ci.draw_circle(c + d * r * 0.6, r * 0.2, col.lightened(0.25))
		"beam":
			ci.draw_line(c + Vector2(-r, r * 0.6), c + Vector2(r, -r * 0.6), col, r * 0.32)
			ci.draw_line(c + Vector2(-r, r * 0.6), c + Vector2(r, -r * 0.6), Color.WHITE, r * 0.1)
		"capsule", "mine", "seal", "key", "box", "chip", "shard", "swap", "gear":
			_draw_misc(ci, shape, c, r, col, dark)
		"mist":
			for i in 4:
				ci.draw_circle(c + Vector2(cos(i * 1.7) * r * 0.4, sin(i * 2.3) * r * 0.3), r * 0.42, Color(col, 0.65))
		"prism", "diamond":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)]), col)
			ci.draw_line(c + Vector2(0, -r), c + Vector2(0, r), col.lightened(0.4), 2)
		"nova":
			ci.draw_circle(c, r * 0.35, col)
			ci.draw_arc(c, r * 0.65, 0, TAU, 32, col, r * 0.1)
			ci.draw_arc(c, r * 0.92, 0, TAU, 32, Color(col, 0.5), r * 0.06)
		"lance":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, r * 0.9), c + Vector2(r * 0.95, -r * 0.95), c + Vector2(-r * 0.6, r)]), col)
		"swarm":
			for i in 6:
				var a := TAU * i / 6.0
				ci.draw_circle(c + Vector2.from_angle(a) * r * (0.35 + 0.3 * (i % 2)), r * 0.15, col)
		"vortex":
			for i in 3:
				ci.draw_arc(c, r * (0.3 + 0.25 * i), i * 1.2, i * 1.2 + PI * 1.4, 24, col, r * 0.1)
		"triangle", "arrow":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r, 0), c + Vector2(-r * 0.7, -r * 0.75), c + Vector2(-r * 0.35, 0), c + Vector2(-r * 0.7, r * 0.75)]), col)
		"hexagon":
			ci.draw_colored_polygon(_ngon(c, r, 6, 0.0), col)
			ci.draw_colored_polygon(_ngon(c, r * 0.55, 6, 0.0), dark)
		"square":
			ci.draw_rect(Rect2(c - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), col)
			ci.draw_circle(c, r * 0.35, dark)
		"blob":
			ci.draw_circle(c, r * 0.9, col)
			ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.25, col.lightened(0.4))
		"star":
			ci.draw_colored_polygon(_star(c, r, r * 0.45, 5), col)
		"cross":
			ci.draw_rect(Rect2(c - Vector2(r * 0.3, r), Vector2(r * 0.6, r * 2)), col)
			ci.draw_rect(Rect2(c - Vector2(r, r * 0.3), Vector2(r * 2, r * 0.6)), col)
		"heart":
			ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.2), r * 0.45, col)
			ci.draw_circle(c + Vector2(r * 0.35, -r * 0.2), r * 0.45, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, 0), c + Vector2(r * 0.8, 0), c + Vector2(0, r * 0.9)]), col)
		"shield":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.8), c + Vector2(r * 0.8, -r * 0.8), c + Vector2(r * 0.7, r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.7, r * 0.2)]), col)
		"magnet":
			ci.draw_arc(c, r * 0.6, PI, TAU, 16, col, r * 0.3)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.75, 0), Vector2(r * 0.3, r * 0.6)), Palette.CORAL)
			ci.draw_rect(Rect2(c + Vector2(r * 0.45, 0), Vector2(r * 0.3, r * 0.6)), Palette.CORAL)
		"clock":
			ci.draw_arc(c, r * 0.8, 0, TAU, 32, col, r * 0.14)
			ci.draw_line(c, c + Vector2(0, -r * 0.55), col, r * 0.12)
			ci.draw_line(c, c + Vector2(r * 0.4, 0), col, r * 0.12)
		_:
			ci.draw_colored_polygon(_ngon(c, r * 0.9, 6, PI / 6.0), col)
			ci.draw_colored_polygon(_ngon(c, r * 0.45, 4, PI / 4.0), dark)
	if outline.a > 0.0:
		ci.draw_arc(c, r * 1.08, 0, TAU, 40, outline, 2.0)


static func _draw_misc(ci: CanvasItem, shape: String, c: Vector2, r: float, col: Color, dark: Color) -> void:
	match shape:
		"capsule":
			ci.draw_circle(c + Vector2(0, -r * 0.35), r * 0.45, col)
			ci.draw_circle(c + Vector2(0, r * 0.35), r * 0.45, col.darkened(0.2))
			ci.draw_rect(Rect2(c - Vector2(r * 0.45, r * 0.35), Vector2(r * 0.9, r * 0.7)), col)
			ci.draw_line(c + Vector2(-r * 0.45, 0), c + Vector2(r * 0.45, 0), dark, 3)
		"mine":
			ci.draw_circle(c, r * 0.6, col)
			for i in 8:
				ci.draw_line(c, c + Vector2.from_angle(TAU * i / 8.0) * r * 0.9, col, r * 0.1)
			ci.draw_circle(c, r * 0.25, Palette.CORAL)
		"seal":
			ci.draw_colored_polygon(_star(c, r, r * 0.75, 10), col)
			ci.draw_circle(c, r * 0.45, dark)
		"key":
			ci.draw_circle(c + Vector2(-r * 0.4, 0), r * 0.4, col)
			ci.draw_circle(c + Vector2(-r * 0.4, 0), r * 0.17, dark)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.05, -r * 0.1), Vector2(r * 0.9, r * 0.2)), col)
			ci.draw_rect(Rect2(c + Vector2(r * 0.55, 0), Vector2(r * 0.15, r * 0.35)), col)
		"box":
			ci.draw_rect(Rect2(c - Vector2(r * 0.8, r * 0.6), Vector2(r * 1.6, r * 1.3)), col)
			ci.draw_rect(Rect2(c - Vector2(r * 0.9, r * 0.75), Vector2(r * 1.8, r * 0.35)), col.lightened(0.2))
			ci.draw_rect(Rect2(c - Vector2(r * 0.12, r * 0.75), Vector2(r * 0.24, r * 1.45)), dark)
		"chip":
			ci.draw_rect(Rect2(c - Vector2(r * 0.6, r * 0.6), Vector2(r * 1.2, r * 1.2)), col)
			for i in 3:
				var o := -0.4 + 0.4 * i
				ci.draw_line(c + Vector2(-r, o * r), c + Vector2(r, o * r), col, 2)
			ci.draw_rect(Rect2(c - Vector2(r * 0.3, r * 0.3), Vector2(r * 0.6, r * 0.6)), dark)
		"shard":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.5, -r * 0.1), c + Vector2(r * 0.15, r), c + Vector2(-r * 0.55, r * 0.2)]), col)
		"swap":
			ci.draw_line(c + Vector2(-r * 0.7, -r * 0.3), c + Vector2(r * 0.7, -r * 0.3), col, r * 0.18)
			ci.draw_line(c + Vector2(-r * 0.7, r * 0.3), c + Vector2(r * 0.7, r * 0.3), col, r * 0.18)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r, -r * 0.3), c + Vector2(r * 0.5, -r * 0.7), c + Vector2(r * 0.5, r * 0.1)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, r * 0.3), c + Vector2(-r * 0.5, -r * 0.1), c + Vector2(-r * 0.5, r * 0.7)]), col)
		"gear":
			ci.draw_colored_polygon(_star(c, r, r * 0.75, 8), col)
			ci.draw_circle(c, r * 0.3, dark)


static func _ngon(c: Vector2, r: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(c + Vector2.from_angle(rot + TAU * i / n) * r)
	return pts


static func _star(c: Vector2, r_out: float, r_in: float, points: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var rr := r_out if i % 2 == 0 else r_in
		pts.append(c + Vector2.from_angle(-PI / 2 + PI * i / points) * rr)
	return pts
