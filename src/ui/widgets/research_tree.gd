class_name ResearchTreeView
extends Control
## Visual research tree: three branch columns, tiers as rows, prerequisite
## links drawn as lines (bright when satisfied). Nodes are buttons.

signal node_pressed(id: String)

const NODE_W := 200.0
const NODE_H := 92.0
const ROW_H := 150.0

var _buttons: Dictionary = {}


func build() -> void:
	UIKit.clear(self)
	_buttons.clear()
	var branches: Array = Content.research_meta.get("branches", [])
	var col_w := 720.0 / maxf(branches.size(), 1)
	var max_tier := 1
	for id in Content.research_order:
		max_tier = maxi(max_tier, int(Content.research_node(id).tier))
	custom_minimum_size = Vector2(680, 90 + max_tier * ROW_H)
	for bi in branches.size():
		var br: Dictionary = branches[bi]
		var head := UIKit.label(Loc.text(br.name), 22, JsonUtil.color(br.color, Palette.TEAL))
		head.position = Vector2(bi * col_w + 10, 0)
		add_child(head)
	for id in Content.research_order:
		var n := Content.research_node(id)
		var bi := branches.map(func(b): return b.id).find(n.branch)
		var x := bi * col_w + (col_w - NODE_W * 0.62) * (float(n.col) / 2.0) + 4.0
		var y := 40.0 + (int(n.tier) - 1) * ROW_H
		var b := _node_button(id, JsonUtil.color(branches[bi].color, Palette.TEAL))
		b.position = Vector2(x, y)
		add_child(b)
		_buttons[id] = b
	queue_redraw()


func _node_button(id: String, color: Color) -> Button:
	var n := Content.research_node(id)
	var rank := Research.rank(id)
	var maxr := int(n.max_rank)
	var err := Research.check(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(NODE_W * 0.62, NODE_H)
	b.size = b.custom_minimum_size
	b.clip_text = true
	var border := color if rank > 0 else (Palette.AMBER if err == "" else Palette.border())
	var bg := Palette.panel_bg().lerp(color, 0.25) if rank >= maxr else Palette.panel_bg()
	b.add_theme_stylebox_override("normal", UIKit.box(bg, border, 3 if err == "" else 2, 14))
	b.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.1), Color.WHITE, 3, 14))
	b.add_theme_stylebox_override("pressed", UIKit.box(bg.darkened(0.2), Palette.AMBER, 3, 14))
	b.text = "%s\n%d/%d" % [Loc.text(n.name), rank, maxr]
	b.add_theme_font_size_override("font_size", 15)
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
			draw_line(from, to, Palette.AMBER if ok else Color(Palette.border(), 0.6), 3.0 if ok else 2.0)
