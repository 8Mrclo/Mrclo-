class_name Pickup
extends Node2D
## Pooled collectible: XP fragment, repair kit, magnet, pulse bomb, data cache.

enum Kind { XP, HEAL, MAGNET, BOMB, CACHE }

var kind: int = Kind.XP
var value := 1.0
var active := false
var magnetized := false
var speed := 0.0
var bob := 0.0
var color := Palette.MINT
var size := 6.0


func _draw() -> void:
	match kind:
		Kind.XP:
			draw_colored_polygon(PackedVector2Array([Vector2(0, -size * 1.3), Vector2(size, 0), Vector2(0, size * 1.3), Vector2(-size, 0)]), color)
			draw_line(Vector2(0, -size * 1.3), Vector2(0, size * 1.3), color.lightened(0.5), 1.5)
		Kind.HEAL:
			draw_circle(Vector2.ZERO, 16, Color(Palette.GREEN, 0.3))
			IconPainter.draw(self, "heart", Vector2.ZERO, 11, Palette.GREEN)
		Kind.MAGNET:
			draw_circle(Vector2.ZERO, 16, Color(Palette.TEAL, 0.3))
			IconPainter.draw(self, "magnet", Vector2.ZERO, 12, Palette.TEAL)
		Kind.BOMB:
			draw_circle(Vector2.ZERO, 16, Color(Palette.CORAL, 0.3))
			IconPainter.draw(self, "nova", Vector2.ZERO, 12, Palette.CORAL)
		Kind.CACHE:
			draw_circle(Vector2.ZERO, 22, Color(Palette.AMBER, 0.35))
			IconPainter.draw(self, "box", Vector2.ZERO, 15, Palette.AMBER)
