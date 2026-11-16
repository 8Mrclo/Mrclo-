class_name CurrencyBar
extends PanelContainer
## Top bar: account level ring + balances. Updates on currency_changed.

var _labels: Dictionary = {}
const SHOWN := ["scrap", "prisms", "field_data", "op_seals"]


func _ready() -> void:
	add_theme_stylebox_override("panel", UIKit.box(Color(Palette.PETROL_DEEP, 0.85), Palette.border(), 1, 16))
	var row := UIKit.hbox(10)
	add_child(row)
	var lvl: int = Game.data.profile.account_level
	var need := Game.account_xp_needed(lvl)
	var acct := UIKit.vbox(0)
	acct.add_child(UIKit.label(Loc.t("account.level_short", {"n": lvl}), 22, Palette.AMBER))
	var bar := UIKit.progress(Game.data.profile.account_xp, need, Palette.AMBER, 8)
	bar.custom_minimum_size = Vector2(80, 8)
	acct.add_child(bar)
	row.add_child(acct)
	for c in SHOWN:
		var chip := UIKit.hbox(4)
		chip.add_child(UIKit.icon(UIKit.currency_shape(c), Palette.currency(c), 34))
		var l := UIKit.label(Loc.format_number(Economy.balance(c)), 21, Palette.text())
		_labels[c] = l
		chip.add_child(l)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.tooltip_text = Loc.currency_name(c)
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.gui_input.connect(_on_chip_input.bind(c))
		row.add_child(chip)
	EventBus.currency_changed.connect(_on_currency)


func _on_currency(c: StringName, v: int) -> void:
	if _labels.has(str(c)) and is_instance_valid(_labels[str(c)]):
		_labels[str(c)].text = Loc.format_number(v)


func _on_chip_input(ev: InputEvent, c: String) -> void:
	if (ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.pressed:
		Router.toast("%s: %s" % [Loc.currency_name(c), Loc.format_number(Economy.balance(c))])
