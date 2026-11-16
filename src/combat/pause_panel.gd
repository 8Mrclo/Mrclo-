class_name PausePanel
extends CanvasLayer
## Pause overlay: resume, quick accessibility toggles, current build/stats,
## abandon with confirmation. Also hosts the revive prompt.

var battle: Battle
var _box: VBoxContainer
var _open := false


func setup(b: Battle) -> void:
	battle = b
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.05, 0.07, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 28)
	margin.add_theme_constant_override("margin_top", 120)
	margin.add_theme_constant_override("margin_bottom", 60)
	margin.theme = ThemeFactory.shared()
	add_child(margin)
	_box = UIKit.vbox(14)
	margin.add_child(UIKit.scroll(_box))


func open() -> void:
	if battle.finished or _open:
		return
	_open = true
	visible = true
	get_tree().paused = true
	battle.hud.set_input_enabled(false)
	Audio.set_duck(true)
	_render_pause()


func close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	battle.hud.set_input_enabled(true)
	Audio.set_duck(battle.boss_active())


func _render_pause() -> void:
	UIKit.clear(_box)
	var t := UIKit.title(Loc.t("pause.title"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(t)
	var m := Content.map_def(battle.cfg.map)
	_box.add_child(UIKit.label("%s · %s" % [Loc.text(m.name), Loc.text(Content.mode(battle.cfg.mode).name)], 24, Palette.text_muted()))
	_box.add_child(UIKit.button(Loc.t("pause.resume"), close, "primary", 80))
	var build := UIKit.panel(null)
	var bv := UIKit.vbox(8)
	build.add_child(bv)
	bv.add_child(UIKit.label(Loc.t("pause.build"), 24, Palette.AMBER))
	var grid := GridContainer.new()
	grid.columns = 2
	for it in battle.loadout.summary():
		var row := UIKit.hbox(8)
		row.add_child(UIKit.icon_from(it.def, 40))
		row.add_child(UIKit.label("%s %s" % [Loc.text(it.def.name), "★" if it.evolved else Loc.t("common.lv", {"n": it.level})], 20, Palette.text()))
		grid.add_child(row)
	bv.add_child(grid)
	var st := battle.player.stats
	var stats_lbl := ""
	for s in ["max_hp", "damage", "crit_chance", "cooldown", "area", "move_speed", "armor", "pickup"]:
		stats_lbl += "%s: %s   " % [Loc.t("stat." + s), StatFormat.value(s, st.get_stat(s))]
	bv.add_child(UIKit.label(stats_lbl, 19, Palette.text_muted(), true))
	_box.add_child(build)
	_box.add_child(_toggle("settings.damage_numbers", "show_damage_numbers"))
	_box.add_child(_toggle("settings.reduce_motion", "reduce_motion"))
	_box.add_child(_toggle("settings.metrics", "show_metrics"))
	_box.add_child(UIKit.button(Loc.t("pause.abandon"), func():
		Dialogs.confirm(Loc.t("pause.abandon_title"), Loc.t("pause.abandon_body"), Loc.t("pause.abandon"), func():
			close()
			battle.finish(false, true), true), "danger"))


func _toggle(key: String, setting: String) -> Control:
	var c := CheckButton.new()
	c.text = Loc.t(key)
	c.button_pressed = bool(Settings.get_value(setting))
	c.custom_minimum_size = Vector2(0, 60)
	c.toggled.connect(func(v):
		Settings.set_value(setting, v)
		if setting == "show_damage_numbers":
			battle.numbers.enabled = v and battle.numbers.max_count > 0)
	return c


func open_revive(free_revive: bool, prism: bool, cost: int) -> void:
	_open = true
	visible = true
	get_tree().paused = true
	battle.hud.set_input_enabled(false)
	UIKit.clear(_box)
	var t := UIKit.title(Loc.t("revive.title"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(t)
	_box.add_child(UIKit.label(Loc.t("revive.body"), 24, Palette.text(), true))
	if free_revive:
		_box.add_child(UIKit.button(Loc.t("revive.protocol", {"n": battle.revives_left}), func(): close(); battle.revive(false), "primary", 80))
	if prism:
		var b := UIKit.button(Loc.t("revive.prisms", {"n": cost, "bal": Economy.balance("prisms")}), func(): close(); battle.revive(true), "secondary", 80)
		_box.add_child(b)
	_box.add_child(UIKit.button(Loc.t("revive.give_up"), func(): close(); battle.finish(false), "danger"))
