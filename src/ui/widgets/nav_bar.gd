class_name NavBar
extends PanelContainer
## Bottom navigation with five areas and badge counts computed from state.

const ITEMS := [
	{"id": "lobby", "label": "nav.base", "shape": "hexagon"},
	{"id": "equipment", "label": "nav.arsenal", "shape": "shield"},
	{"id": "agents", "label": "nav.agents", "shape": "star"},
	{"id": "missions", "label": "nav.operations", "shape": "clock"},
	{"id": "store", "label": "nav.market", "shape": "box"},
]

var active := "lobby"


func _ready() -> void:
	add_theme_stylebox_override("panel", UIKit.box(Color(Palette.PETROL_DEEP, 0.96), Palette.border(), 2, 20))
	var row := UIKit.hbox(4)
	add_child(row)
	for it in ITEMS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var on: bool = it.id == active
		b.add_theme_stylebox_override("normal", UIKit.box(Palette.PETROL_LIGHT if on else Color(0, 0, 0, 0), Palette.AMBER if on else Color(0, 0, 0, 0), 2, 16))
		b.add_theme_stylebox_override("hover", UIKit.box(Palette.PETROL_MID, Palette.TEAL, 2, 16))
		b.add_theme_stylebox_override("pressed", UIKit.box(Palette.PETROL, Palette.AMBER, 2, 16))
		var v := UIKit.vbox(2)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := UIKit.icon(it.shape, Palette.AMBER if on else Palette.MINT, 46)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.backdrop = false
		v.add_child(ic)
		var l := UIKit.label(Loc.t(it.label), 19, Palette.text() if on else Palette.text_muted())
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
		b.add_child(v)
		var count := badge_count(it.id)
		if count > 0:
			var badge := UIKit.badge(count)
			badge.position = Vector2(8, 4)
			b.add_child(badge)
		var target: String = it.id
		b.pressed.connect(func():
			Audio.play_ui(&"click")
			if target != active:
				Router.goto(target))
		row.add_child(b)


static func badge_count(id: String) -> int:
	if Game.data.is_empty():
		return 0
	match id:
		"lobby": return Game.unclaimed_mail()
		"equipment": return 1 if Inventory.has_better_item() else 0
		"agents": return Agents.actionable_count()
		"missions": return Objectives.claimable_count() + Achievements.claimable_count()
		"store": return Store.free_available()
	return 0
