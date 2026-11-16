class_name AgentPortrait
extends Control
## Large animated agent preview (idle bob + lighthouse halo). Locked agents
## render as a dark silhouette.

var agent_id := "lia":
	set(v): agent_id = v; queue_redraw()
var locked := false
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not bool(Settings.get_value("reduce_motion")))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := size * Vector2(0.5, 0.56)
	var s := minf(size.x, size.y) * 0.32
	var vis: Dictionary = Content.agent(agent_id).get("visual", {})
	draw_circle(c + Vector2(0, s * 1.05), s * 1.1, Color(Palette.TEAL, 0.10))
	draw_arc(c + Vector2(0, s * 1.05), s * 1.1, 0, TAU, 48, Color(Palette.TEAL, 0.4), 3)
	if locked:
		vis = {"body": "#0a1418", "accent": "#0a1418", "trim": "#050a0c", "shape": vis.get("shape", "hood"), "gear": vis.get("gear", "")}
	AgentPainter.draw(self, vis, c, s, 1.0, sin(_t * 2.0) * s * 0.04, false)
