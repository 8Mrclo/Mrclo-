class_name ScreenBase
extends Control
## Common screen scaffold: animated backdrop, safe-area margins, optional
## header (title + back), currency bar, scrollable body and bottom navigation.
## Subclasses implement build() and may call rebuild() on data changes.

var body: VBoxContainer
var header_box: VBoxContainer
var footer_box: VBoxContainer
var screen_id := ""
var _rebuild_queued := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := HangarBackground.new()
	add_child(bg)
	var ins := UIKit.safe_insets(get_viewport())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18 + int(ins.left))
	margin.add_theme_constant_override("margin_right", 18 + int(ins.right))
	margin.add_theme_constant_override("margin_top", 14 + int(ins.top))
	margin.add_theme_constant_override("margin_bottom", 10 + int(ins.bottom))
	add_child(margin)
	var root := UIKit.vbox(12)
	margin.add_child(root)
	header_box = UIKit.vbox(10)
	root.add_child(header_box)
	body = UIKit.vbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	footer_box = UIKit.vbox(0)
	root.add_child(footer_box)
	EventBus.notifications_changed.connect(queue_rebuild)
	EventBus.inventory_changed.connect(queue_rebuild)
	EventBus.profile_changed.connect(queue_rebuild)
	Loc.language_changed.connect(func(_l): queue_rebuild())
	rebuild()


func queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	_do_rebuild.call_deferred()


func _do_rebuild() -> void:
	_rebuild_queued = false
	if is_inside_tree():
		rebuild()


func rebuild() -> void:
	UIKit.clear(header_box)
	UIKit.clear(body)
	UIKit.clear(footer_box)
	build()


## Override.
func build() -> void:
	pass


func add_header(title_text: String, back: bool = true, currencies: bool = true) -> void:
	if currencies:
		header_box.add_child(CurrencyBar.new())
	var row := UIKit.hbox(12)
	if back:
		var b := UIKit.button("‹ " + Loc.t("common.back"), func(): Router.back(), "ghost")
		b.custom_minimum_size = Vector2(150, 64)
		row.add_child(b)
	var t := UIKit.title(title_text)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	header_box.add_child(row)


func add_nav(active: String) -> void:
	var nav := NavBar.new()
	nav.active = active
	footer_box.add_child(nav)


func scroll_body() -> VBoxContainer:
	var v := UIKit.vbox(12)
	body.add_child(UIKit.scroll(v))
	return v


## Horizontal tab strip; returns the selected id via callback.
func tabs(ids: Array, labels: Array, selected: String, on_select: Callable) -> Control:
	var row := UIKit.hbox(6)
	for i in ids.size():
		var b := UIKit.button(labels[i], func(): on_select.call(ids[i]), "secondary" if ids[i] == selected else "ghost", 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		if ids[i] == selected:
			b.add_theme_stylebox_override("normal", UIKit.box(Palette.PETROL_LIGHT, Palette.AMBER, 2, 14))
		row.add_child(b)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 64)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(row)
	return sc


func show_reward_toast(summary: Dictionary) -> void:
	var parts: PackedStringArray = []
	for c in summary.get("currencies", {}):
		parts.append("+%s %s" % [Loc.format_number(summary.currencies[c]), Loc.currency_name(c)])
	for uid in summary.get("items", []):
		var it := Inventory.get_item(uid)
		if not it.is_empty():
			parts.append("+ " + Loc.text(Content.item(it.def).name))
	if summary.get("account_xp", 0) > 0:
		parts.append("+%d %s" % [summary.account_xp, Loc.t("account.xp")])
	if not parts.is_empty():
		Audio.play_ui(&"reward")
		Router.toast(", ".join(parts), &"reward")
