class_name ItemTile
extends Button
## Inventory tile: rarity frame, procedural icon, level, favorite and
## equipped markers. Selection mode shows a check overlay.

var item: Dictionary
var selected := false:
	set(v): selected = v; _style()


func setup(it: Dictionary, size_px: float = 120.0) -> ItemTile:
	item = it
	custom_minimum_size = Vector2(size_px, size_px)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var def := Content.item(it.def)
	var ic := UIKit.icon_from(def, size_px * 0.6)
	ic.set_anchors_preset(Control.PRESET_CENTER)
	ic.position = -Vector2(size_px, size_px) * 0.3
	add_child(ic)
	var lvl := UIKit.label(Loc.t("common.lv", {"n": it.level}), 17, Palette.SAND)
	lvl.position = Vector2(8, size_px - 30)
	add_child(lvl)
	if it.favorite:
		var f := UIKit.icon("star", Palette.AMBER, 28)
		f.backdrop = false
		f.position = Vector2(size_px - 34, 4)
		add_child(f)
	if Inventory.is_equipped(int(it.uid)):
		var e := UIKit.label("E", 18, Palette.MINT)
		e.position = Vector2(10, 4)
		add_child(e)
	_style()
	return self


func _style() -> void:
	if item.is_empty():
		return
	var col := Palette.rarity(item.rarity)
	var bg := Palette.panel_bg().lerp(col, 0.12)
	add_theme_stylebox_override("normal", UIKit.box(bg, Palette.AMBER if selected else col, 4 if selected else 3, 14))
	add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.1), Color.WHITE, 3, 14))
	add_theme_stylebox_override("pressed", UIKit.box(bg.darkened(0.2), Palette.AMBER, 4, 14))
	modulate = Color(1, 1, 1, 1) if not selected else Color(1.15, 1.1, 0.9)
