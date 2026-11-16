class_name FxNode
extends Node2D
## Pooled short-lived visual effect (ring, burst, chain line, beam, telegraphs).

enum Kind { RING, BURST, CHAIN, BEAM, TELE_CIRCLE, TELE_LINE, FLASH }

var kind: int = Kind.RING
var t := 0.0
var life := 0.3
var color := Color.WHITE
var radius := 40.0
var width := 6.0
var points := PackedVector2Array()
var target := Vector2.ZERO


func _draw() -> void:
	var k := clampf(t / life, 0.0, 1.0)
	match kind:
		Kind.RING:
			draw_arc(Vector2.ZERO, radius * (0.35 + 0.65 * k), 0, TAU, 40, Color(color, 1.0 - k), maxf(2.0, 10.0 * (1.0 - k)))
		Kind.BURST:
			for i in 8:
				var a := TAU * i / 8.0 + radius
				draw_line(Vector2.from_angle(a) * width * k * 4.0, Vector2.from_angle(a) * width * (1.0 + k * 6.0), Color(color, 1.0 - k), 3.0)
		Kind.CHAIN:
			for i in range(points.size() - 1):
				draw_line(points[i] - position, points[i + 1] - position, Color(color, 1.0 - k), width * (1.0 - k * 0.5))
				draw_line(points[i] - position, points[i + 1] - position, Color(1, 1, 1, 1.0 - k), width * 0.35)
		Kind.BEAM:
			draw_line(Vector2.ZERO, target - position, Color(color, 0.45 * (1.0 - k)), width * 1.8)
			draw_line(Vector2.ZERO, target - position, Color(color.lightened(0.5), 1.0 - k), width * 0.6)
		Kind.TELE_CIRCLE:
			draw_circle(Vector2.ZERO, radius, Color(color, 0.12))
			draw_circle(Vector2.ZERO, radius * k, Color(color, 0.28))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(color, 0.9), 3.0)
		Kind.TELE_LINE:
			var to := target - position
			var n := to.normalized().orthogonal() * width * 0.5
			draw_colored_polygon(PackedVector2Array([n, to + n, to - n, -n]), Color(color, 0.14 + 0.2 * k))
			draw_line(n, to + n, Color(color, 0.8), 2.0)
			draw_line(-n, to - n, Color(color, 0.8), 2.0)
		Kind.FLASH:
			draw_circle(Vector2.ZERO, radius, Color(color, 0.5 * (1.0 - k)))
