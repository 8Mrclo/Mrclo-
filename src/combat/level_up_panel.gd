class_name LevelUpPanel
extends CanvasLayer
## LevelUpSelection overlay: pauses the tree, shows three cards with level,
## next effect and evolution requirements; supports reroll and lock.

var battle: Battle
var _open := false
var _offers: Array = []
var _cards: VBoxContainer
var _reroll_btn: Button
var _title: Label
var _lock_mode := false
var _lock_btn: Button


func setup(b: Battle) -> void:
	battle = b
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.06, 0.08, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 110)
	margin.add_theme_constant_override("margin_bottom", 60)
	margin.theme = ThemeFactory.shared()
	add_child(margin)
	var v := UIKit.vbox(16)
	margin.add_child(v)
	_title = UIKit.title("")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_cards = UIKit.vbox(16)
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_cards)
	var row := UIKit.hbox(12)
	_reroll_btn = UIKit.button("", _do_reroll, "secondary")
	_reroll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_reroll_btn)
	_lock_btn = UIKit.button("", _toggle_lock_mode, "ghost")
	_lock_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_lock_btn)
	v.add_child(row)


func is_open() -> bool:
	return _open


func open() -> void:
	_open = true
	_lock_mode = false
	visible = true
	get_tree().paused = true
	battle.hud.set_input_enabled(false)
	_offers = battle.current_offers()
	_render()
	Tutorial.notify_context("level_up")


func _close() -> void:
	_open = false
	visible = false
	battle.hud.set_input_enabled(true)
	get_tree().paused = false


func _render() -> void:
	_title.text = Loc.t("levelup.title", {"n": battle.level})
	UIKit.clear(_cards)
	for offer in _offers:
		_cards.add_child(_card(offer))
	_reroll_btn.text = Loc.t("levelup.reroll", {"n": battle.rerolls})
	_reroll_btn.disabled = battle.rerolls <= 0
	_lock_btn.text = Loc.t("levelup.lock_active") if _lock_mode else Loc.t("levelup.lock", {"n": battle.locks})
	_lock_btn.disabled = battle.locks <= 0
	_lock_btn.visible = battle.locks > 0 or _lock_mode


func _card(offer: Dictionary) -> Control:
	var def := Content.upgrade_def(offer.id)
	var accent := Palette.TEAL
	var tag := ""
	match offer.kind:
		"evolution":
			accent = Palette.AMBER
			tag = Loc.t("levelup.evolution")
		"active":
			tag = Loc.t("levelup.new") if int(offer.level_from) == 0 else Loc.t("levelup.level", {"from": offer.level_from, "to": offer.level_to})
		"passive":
			accent = Palette.VIOLET
			tag = Loc.t("levelup.new_module") if int(offer.level_from) == 0 else Loc.t("levelup.level", {"from": offer.level_from, "to": offer.level_to})
		"fallback":
			accent = Palette.GREEN
			tag = Loc.t("levelup.supply")
	# PanelContainer sizes to its content; a flat Button on top catches taps.
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 170)
	card.add_theme_stylebox_override("panel", UIKit.box(Palette.panel_bg(), accent, 3, 22))
	var h := UIKit.hbox(16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(h)
	var b := Button.new()
	b.flat = true
	b.add_theme_stylebox_override("hover", UIKit.box(Color(1, 1, 1, 0.05), Color.WHITE, 3, 22))
	b.add_theme_stylebox_override("pressed", UIKit.box(Color(1, 1, 1, 0.08), Palette.AMBER, 4, 22))
	b.add_theme_stylebox_override("focus", UIKit.box(Color(0, 0, 0, 0), Palette.AMBER, 4, 22))
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var ic := UIKit.icon_from(def, 92, accent)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var top := UIKit.hbox(8)
	top.add_child(UIKit.label(Loc.text(def.get("name", offer.id)), 28, Palette.text()))
	top.add_child(UIKit.spacer())
	top.add_child(UIKit.label(tag, 20, accent))
	v.add_child(top)
	v.add_child(UIKit.label(Loc.text(def.get("desc", "")), 21, Palette.text_muted(), true))
	var lines := UpgradeOffer.diff_lines(offer)
	for i in mini(lines.size(), 3):
		v.add_child(UIKit.label("▸ " + lines[i], 20, Palette.MINT, true))
	var hint := _evolution_hint(offer)
	if hint != "":
		v.add_child(UIKit.label(hint, 19, Palette.AMBER, true))
	for c in v.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(func(): _pick(offer))
	card.add_child(b)
	return card


func _evolution_hint(offer: Dictionary) -> String:
	if offer.kind == "active":
		var evo_id: String = Content.evolution_by_active.get(offer.id, "")
		if evo_id != "":
			var evo := Content.evolution(evo_id)
			return Loc.t("levelup.evolves_with", {"module": Loc.text(Content.passive(evo.requires).name), "evo": Loc.text(evo.name)})
	if offer.kind == "passive":
		for evo_id in Content.evolutions:
			var evo := Content.evolution(evo_id)
			if evo.requires == offer.id:
				return Loc.t("levelup.enables", {"active": Loc.text(Content.active(evo.from).name), "evo": Loc.text(evo.name)})
	return ""


func _pick(offer: Dictionary) -> void:
	if _lock_mode:
		if battle.lock_offer(offer):
			Router.toast(Loc.t("levelup.locked_toast"))
		_lock_mode = false
		_render()
		return
	Audio.play_ui(&"confirm")
	battle.choose_offer(offer)
	if battle.pending_picks > 0:
		_offers = battle.current_offers()
		_render()
	else:
		_close()


func _do_reroll() -> void:
	var o := battle.reroll()
	if not o.is_empty():
		_offers = o
		_render()


func _toggle_lock_mode() -> void:
	_lock_mode = not _lock_mode
	_render()
