class_name AgentPainter
extends RefCounted
## Original procedural agent silhouettes. Each agent combines a body shape and
## a piece of improvised gear so silhouettes stay distinct at small sizes.


static func draw(ci: CanvasItem, visual: Dictionary, c: Vector2, s: float, facing: float, bob: float, hurt: bool) -> void:
	var body := JsonUtil.color(visual.get("body", ""), Palette.TEAL)
	var accent := JsonUtil.color(visual.get("accent", ""), Palette.AMBER)
	var trim := JsonUtil.color(visual.get("trim", ""), Palette.PETROL)
	if hurt:
		body = body.lerp(Color.WHITE, 0.6)
	var f := 1.0 if facing >= 0.0 else -1.0
	var p := c + Vector2(0, bob)
	ci.draw_circle(c + Vector2(0, s * 0.95), s * 0.62, Color(0, 0, 0, 0.28))
	# Legs
	ci.draw_line(p + Vector2(-s * 0.22, s * 0.4), p + Vector2(-s * 0.26, s * 0.9 - bob), trim, s * 0.18)
	ci.draw_line(p + Vector2(s * 0.22, s * 0.4), p + Vector2(s * 0.26, s * 0.9 + bob), trim, s * 0.18)
	match visual.get("shape", "hood"):
		"bulky":
			ci.draw_rect(Rect2(p + Vector2(-s * 0.6, -s * 0.3), Vector2(s * 1.2, s * 0.85)), body)
			ci.draw_circle(p + Vector2(0, -s * 0.55), s * 0.34, body.lightened(0.15))
		"slim":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.32, s * 0.5), p + Vector2(s * 0.32, s * 0.5), p + Vector2(s * 0.2 * f, -s * 0.3), p + Vector2(-s * 0.25 * f, -s * 0.3)]), body)
			ci.draw_circle(p + Vector2(s * 0.05 * f, -s * 0.55), s * 0.3, body.lightened(0.15))
		"visor":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.4, s * 0.5), p + Vector2(s * 0.4, s * 0.5), p + Vector2(s * 0.3, -s * 0.3), p + Vector2(-s * 0.3, -s * 0.3)]), body)
			ci.draw_circle(p + Vector2(0, -s * 0.55), s * 0.32, body.lightened(0.1))
			ci.draw_rect(Rect2(p + Vector2(-s * 0.1 + s * 0.05 * f, -s * 0.65), Vector2(s * 0.4, s * 0.14)), accent)
		"pack":
			ci.draw_rect(Rect2(p + Vector2(-s * 0.55 * f - (s * 0.3 if f < 0 else 0.0), -s * 0.25), Vector2(s * 0.3, s * 0.6)), trim.lightened(0.3))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.36, s * 0.5), p + Vector2(s * 0.36, s * 0.5), p + Vector2(s * 0.3, -s * 0.3), p + Vector2(-s * 0.3, -s * 0.3)]), body)
			ci.draw_circle(p + Vector2(0, -s * 0.55), s * 0.3, body.lightened(0.15))
		"cloak":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.55, s * 0.6), p + Vector2(s * 0.55, s * 0.6), p + Vector2(s * 0.15, -s * 0.4), p + Vector2(-s * 0.15, -s * 0.4)]), body)
			ci.draw_circle(p + Vector2(0, -s * 0.55), s * 0.28, trim)
		_:
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.42, s * 0.5), p + Vector2(s * 0.42, s * 0.5), p + Vector2(s * 0.28, -s * 0.3), p + Vector2(-s * 0.28, -s * 0.3)]), body)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.38, -s * 0.35), p + Vector2(s * 0.38, -s * 0.35), p + Vector2(s * 0.1 * f, -s * 1.0)]), body.darkened(0.15))
	# Eye
	ci.draw_circle(p + Vector2(s * 0.14 * f, -s * 0.55), s * 0.08, Color.WHITE)
	match visual.get("gear", ""):
		"satchel":
			ci.draw_rect(Rect2(p + Vector2(-s * 0.5 * f - s * 0.12, s * 0.05), Vector2(s * 0.28, s * 0.32)), accent)
		"fins":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.3 * f, -s * 0.1), p + Vector2(-s * 0.85 * f, -s * 0.3), p + Vector2(-s * 0.35 * f, s * 0.2)]), accent)
		"prisms":
			for i in 3:
				var a := Time.get_ticks_msec() / 600.0 + TAU * i / 3.0
				IconPainter.draw(ci, "diamond", p + Vector2(cos(a) * s * 0.8, -s * 0.2 + sin(a) * s * 0.3), s * 0.14, accent)
		"shoulder":
			ci.draw_circle(p + Vector2(-s * 0.55, -s * 0.25), s * 0.24, accent)
			ci.draw_circle(p + Vector2(s * 0.55, -s * 0.25), s * 0.24, accent)
		"antenna":
			ci.draw_line(p + Vector2(-s * 0.1, -s * 0.8), p + Vector2(-s * 0.3, -s * 1.3), trim, 3)
			ci.draw_circle(p + Vector2(-s * 0.3, -s * 1.3), s * 0.1, accent)
		"halo":
			ci.draw_arc(p + Vector2(0, -s * 0.95), s * 0.32, 0, TAU, 24, accent, 3)
