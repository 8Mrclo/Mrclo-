class_name ResearchTreeView
extends Control
## Visual research tree for one branch: tiers as rows, three columns,
## prerequisite links drawn as lines (bright when satisfied).

signal node_pressed(id: String)

const NODE_W := 200.0
const NODE_H := 96.0
const ROW_H := 150.0
const COL_W := 228.0

var branch := "survival"
var _buttons: Dictionary = {}


func build() -> void:
	UIKit.clear(self)
	_buttons.clear()
	var color := Palette.TEAL
	for br in Content.research_meta.get("branches", []):
		if br.id == branch:
			color = JsonUtil.color(br.color, Palette.TEAL)
	var max_tier := 1
	for id in Content.research_order:
		var n := Content.research_node(id)
		if n.branch != branch:
			continue
		max_tier = maxi(max_tier, int(n.tier))
		var b := _node_button(id, color)
		b.position = Vector2(int(n.col) * COL_W + (COL_W - NODE_W) * 0.5, 10.0 + (int(n.tier) - 1) * ROW_H)
		add_child(b)
		_buttons[id] = b
	custom_minimum_size = Vector2(COL_W * 3, 20 + max_tier * ROW_H)
	queue_redraw()


func _node_button(id: String, color: Color) -> Button:
	var n := Content.research_node(id)
	var rank := Research.rank(id)
	var maxr := int(n.max_rank)
	var err := Research.check(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(NODE_W, NODE_H)
	b.size = b.custom_minimum_size
	var border := color if rank > 0 else (Palette.AMBER if err == "" else Palette.border())
	var bg := Palette.panel_bg().lerp(color, 0.3) if rank >= maxr else Palette.panel_bg()
	b.add_theme_stylebox_override("normal", UIKit.box(bg, border, 3 if err == "" or rank > 0 else 2, 14))
	b.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.1), Color.WHITE, 3, 14))
	b.add_theme_stylebox_override("pressed", UIKit.box(bg.darkened(0.2), Palette.AMBER, 3, 14))
	b.text = "%s\n%d/%d" % [Loc.text(n.name), rank, maxr]
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 18)
	if err == "research.err_requires":
		b.modulate = Color(1, 1, 1, 0.55)
	b.pressed.connect(func(): node_pressed.emit(id))
	return b


func _draw() -> void:
	for id in _buttons:
		var b: Button = _buttons[id]
		for req in Content.research_node(id).get("requires", []):
			if not _buttons.has(req):
				continue
			var a: Button = _buttons[req]
			var from := a.position + Vector2(a.size.x * 0.5, a.size.y)
			var to := b.position + Vector2(b.size.x * 0.5, 0)
			var ok := Research.rank(req) > 0
			draw_line(from, to, Palette.AMBER if ok else Color(Palette.border(), 0.7), 4.0 if ok else 2.0)
