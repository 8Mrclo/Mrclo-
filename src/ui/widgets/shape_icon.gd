class_name ShapeIcon
extends Control
## Control that renders an IconPainter shape. Purely decorative.

var shape := "hexagon":
	set(v): shape = v; queue_redraw()
var color := Palette.TEAL:
	set(v): color = v; queue_redraw()
var ring := Color(0, 0, 0, 0):
	set(v): ring = v; queue_redraw()
var backdrop := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	if backdrop:
		draw_circle(c, r * 0.98, Color(0, 0, 0, 0.22))
	IconPainter.draw(self, shape, c, r * 0.72, color, ring)
