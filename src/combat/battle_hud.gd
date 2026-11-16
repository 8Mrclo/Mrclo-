class_name BattleHud
extends CanvasLayer
## In-battle HUD: XP bar, HP, timer, kills, build icons, boss bar, speed toggle,
## pause, announcements, tutorial hints, damage vignette and debug metrics.
## Text refreshes at 10 Hz to avoid per-frame string allocations.

var battle: Battle
var joystick: VirtualJoystick
var _root: Control
var _xp_bar: ProgressBar
var _level_lbl: Label
var _timer_lbl: Label
var _kills_lbl: Label
var _hp_bar: ProgressBar
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _boss_name: Label
var _boss: Enemy
var _device_bar: ProgressBar
var _build_row: HBoxContainer
var _announce: Label
var _vignette: ColorRect
var _metrics: Label
var _speed_btn: Button
var _text_t := 0.0
var _build_sig := ""
var _hint: HintBanner


func setup(b: Battle) -> void:
	battle = b
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = ThemeFactory.shared()
	add_child(_root)
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.color = Color(Palette.CORAL, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vignette)
	joystick = VirtualJoystick.new()
	_root.add_child(joystick)
	var ins := UIKit.safe_insets(get_viewport())
	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 16 + int(ins.left))
	top.add_theme_constant_override("margin_right", 16 + int(ins.right))
	top.add_theme_constant_override("margin_top", 12 + int(ins.top))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	var v := UIKit.vbox(8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(v)
	var xp_row := UIKit.hbox(8)
	_level_lbl = UIKit.label("", 24, Palette.AMBER)
	_level_lbl.custom_minimum_size = Vector2(90, 0)
	xp_row.add_child(_level_lbl)
	_xp_bar = UIKit.progress(0, 1, Palette.MINT, 22)
	xp_row.add_child(_xp_bar)
	v.add_child(xp_row)
	var row := UIKit.hbox(12)
	var hp_box := UIKit.vbox(2)
	hp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar = UIKit.progress(1, 1, Palette.GREEN, 16)
	hp_box.add_child(_hp_bar)
	_kills_lbl = UIKit.label("", 22, Palette.text_muted())
	hp_box.add_child(_kills_lbl)
	row.add_child(hp_box)
	_timer_lbl = UIKit.label("00:00", 34, Palette.SAND)
	_timer_lbl.add_theme_color_override("font_outline_color", Palette.PETROL_DEEP)
	_timer_lbl.add_theme_constant_override("outline_size", 6)
	row.add_child(_timer_lbl)
	if battle.speed_unlocked:
		_speed_btn = UIKit.button("", _toggle_speed, "ghost", 64)
		_speed_btn.custom_minimum_size = Vector2(84, 64)
		row.add_child(_speed_btn)
	var pause := UIKit.button("II", func(): battle.pause_panel.open(), "secondary", 64)
	pause.custom_minimum_size = Vector2(72, 64)
	pause.tooltip_text = Loc.t("battle.pause")
	row.add_child(pause)
	v.add_child(row)
	_build_row = UIKit.hbox(4)
	_build_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_build_row)
	_boss_box = UIKit.vbox(2)
	_boss_name = UIKit.label("", 24, Palette.CORAL)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = UIKit.progress(1, 1, Palette.CORAL, 20)
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false
	v.add_child(_boss_box)
	if battle.device:
		var dl := UIKit.label(Loc.t("battle.device"), 20, Palette.MINT)
		v.add_child(dl)
		_device_bar = UIKit.progress(1, 1, Palette.MINT, 14)
		v.add_child(_device_bar)
	_announce = UIKit.label("", 30, Palette.AMBER, true)
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.set_anchors_preset(Control.PRESET_CENTER)
	_announce.position = Vector2(-320, -260)
	_announce.custom_minimum_size = Vector2(640, 0)
	_announce.add_theme_color_override("font_outline_color", Palette.PETROL_DEEP)
	_announce.add_theme_constant_override("outline_size", 8)
	_announce.modulate.a = 0.0
	_announce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_announce)
	_metrics = UIKit.label("", 18, Palette.MINT)
	_metrics.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_metrics.position = Vector2(12, -150)
	_metrics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_metrics)
	_hint = HintBanner.new()
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.offset_top = -230 - ins.bottom
	_hint.offset_left = 20
	_hint.offset_right = -20
	_root.add_child(_hint)
	_update_speed_label()


func set_input_enabled(on: bool) -> void:
	joystick.visible = on
	if not on:
		joystick.release()


func move_input() -> Vector2:
	var kb := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if kb.length() > 0.1:
		return kb
	return joystick.output


func refresh(delta: float) -> void:
	_xp_bar.max_value = battle.xp_needed
	_xp_bar.value = battle.xp
	_hp_bar.max_value = battle.player.max_hp
	_hp_bar.value = battle.player.hp
	if _boss_box.visible and is_instance_valid(_boss):
		_boss_bar.max_value = _boss.max_hp
		_boss_bar.value = maxf(_boss.hp, 0.0)
	if _device_bar:
		_device_bar.max_value = battle.device_max_hp
		_device_bar.value = battle.device_hp
	if _vignette.color.a > 0.0:
		_vignette.color.a = maxf(_vignette.color.a - delta * 1.5, 0.0)
	if _announce.modulate.a > 0.0:
		_announce.modulate.a = maxf(_announce.modulate.a - delta * 0.45, 0.0)
	_text_t -= delta
	if _text_t > 0.0:
		return
	_text_t = 0.1
	_level_lbl.text = Loc.t("battle.level_short", {"n": battle.level})
	var remaining := float(battle.cfg.duration) - battle.time
	_timer_lbl.text = TimeService.format_duration(int(absf(remaining))) if remaining >= 0.0 else "+" + TimeService.format_duration(int(-remaining))
	_kills_lbl.text = Loc.t("battle.kills", {"n": Loc.format_number(battle.kills)})
	_refresh_build()
	_metrics.visible = bool(Settings.get_value("show_metrics"))
	if _metrics.visible:
		_metrics.text = "FPS %d | inimigos %d | proj %d | coletáveis %d | fx %d | mem %.1f MB" % [Engine.get_frames_per_second(), battle.enemies.count(), battle.projectiles.count(), battle.pickups.count(), battle.fx.count(), OS.get_static_memory_usage() / 1048576.0]


func _refresh_build() -> void:
	var s := battle.loadout.summary()
	var sig := ""
	for it in s:
		sig += "%s%d" % [it.id, it.level]
	if sig == _build_sig:
		return
	_build_sig = sig
	UIKit.clear(_build_row)
	for it in s:
		var box := UIKit.vbox(0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ring := Palette.AMBER if it.evolved else (Palette.TEAL if it.kind == "active" else Palette.VIOLET)
		box.add_child(UIKit.icon_from(it.def, 42, ring))
		var l := UIKit.label(str(it.level) if not it.evolved else "★", 14, Palette.SAND)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
		_build_row.add_child(box)


func flash_damage() -> void:
	if not bool(Settings.get_value("reduce_motion")):
		_vignette.color.a = 0.22


func announce(text: String) -> void:
	_announce.text = text
	_announce.modulate.a = 1.0


func show_boss(b: Enemy) -> void:
	_boss = b
	_boss_name.text = Loc.text(b.def.name)
	_boss_box.visible = true


func hide_boss() -> void:
	_boss_box.visible = false
	_boss = null


func _toggle_speed() -> void:
	battle.speed_mult = float(Content.balance_value("run.speed_boost_factor", 1.5)) if battle.speed_mult < 1.1 else 1.0
	Settings.set_value("battle_speed", battle.speed_mult)
	_update_speed_label()


func _update_speed_label() -> void:
	if _speed_btn:
		_speed_btn.text = "×%.1f" % battle.speed_mult
