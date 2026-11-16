extends ScreenBase
## Settings: audio buses, vibration, accessibility, performance, language,
## aim mode, tutorial reset, credits, typed-confirmation progress wipe.


func build() -> void:
	add_header(Loc.t("screen.settings"))
	var list := scroll_body()
	list.add_child(_section("settings.audio"))
	for k in ["music_volume", "sfx_volume", "ui_volume", "ambience_volume"]:
		list.add_child(_slider(k))
	list.add_child(_toggle("settings.vibration", "vibration"))
	list.add_child(_section("settings.accessibility"))
	list.add_child(_toggle("settings.high_contrast", "high_contrast", true))
	list.add_child(_toggle("settings.reduce_motion", "reduce_motion"))
	list.add_child(_toggle("settings.damage_numbers", "show_damage_numbers"))
	list.add_child(_slider("shake"))
	list.add_child(_section("settings.gameplay"))
	list.add_child(_choice("settings.aim", "aim_mode", ["nearest", "lowest_hp", "threat", "movement"]))
	list.add_child(_choice("settings.language", "language", Loc.SUPPORTED))
	list.add_child(_section("settings.performance"))
	list.add_child(_choice("settings.fps", "fps", [60, 30]))
	list.add_child(_choice("settings.graphics", "graphics", ["low", "medium", "high"]))
	list.add_child(_toggle("settings.metrics", "show_metrics"))
	list.add_child(_section("settings.progress"))
	var tut := Tutorial.progress()
	list.add_child(UIKit.label(Loc.t("settings.tutorial_progress", {"n": tut.x, "max": tut.y}), 19, Palette.text_muted()))
	list.add_child(UIKit.button(Loc.t("settings.reset_tutorial"), func():
		Tutorial.reset_all()
		Router.toast(Loc.t("settings.tutorial_reset_done")), "secondary"))
	list.add_child(UIKit.button(Loc.t("screen.tutorial"), func(): Router.goto("tutorial"), "ghost"))
	list.add_child(UIKit.button(Loc.t("screen.credits"), func(): Router.goto("credits"), "ghost"))
	if DebugTools.available:
		list.add_child(UIKit.button(Loc.t("debug.title"), func(): DebugTools.toggle(), "ghost"))
	list.add_child(UIKit.button(Loc.t("settings.delete"), func():
		Dialogs.typed_confirm(Loc.t("settings.delete_title"), Loc.t("settings.delete_body"), Loc.t("settings.delete_word"), func():
			Saves.wipe_and_reset()
			Router.goto("boot")), "danger"))
	list.add_child(UIKit.label(Loc.t("settings.version", {"v": ProjectSettings.get_setting("application/config/version", "0")}), 16, Palette.text_muted()))


func _section(key: String) -> Control:
	var l := UIKit.label(Loc.t(key), 24, Palette.AMBER)
	return l


func _slider(key: String) -> Control:
	var row := UIKit.hbox(10)
	var l := UIKit.label(Loc.t("settings." + key), 20, Palette.text())
	l.custom_minimum_size = Vector2(240, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Settings.get_value(key))
	s.custom_minimum_size = Vector2(0, 56)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := UIKit.label("%d%%" % int(s.value * 100), 19, Palette.text_muted())
	val.custom_minimum_size = Vector2(70, 0)
	s.value_changed.connect(func(v):
		val.text = "%d%%" % int(v * 100)
		Settings.set_value(key, v))
	row.add_child(s)
	row.add_child(val)
	return row


func _toggle(label_key: String, key: String, rebuild_theme: bool = false) -> Control:
	var c := CheckButton.new()
	c.text = Loc.t(label_key)
	c.button_pressed = bool(Settings.get_value(key))
	c.custom_minimum_size = Vector2(0, 60)
	c.toggled.connect(func(v):
		Settings.set_value(key, v)
		if rebuild_theme:
			get_tree().root.theme = ThemeFactory.build()
			queue_rebuild())
	return c


func _choice(label_key: String, key: String, values: Array) -> Control:
	var row := UIKit.hbox(10)
	var l := UIKit.label(Loc.t(label_key), 20, Palette.text())
	l.custom_minimum_size = Vector2(240, 0)
	row.add_child(l)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(0, 56)
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cur: Variant = Settings.get_value(key)
	for i in values.size():
		ob.add_item(Loc.t("settings.opt.%s" % str(values[i])), i)
		if str(values[i]) == str(cur):
			ob.select(i)
	ob.item_selected.connect(func(i):
		Settings.set_value(key, values[i])
		if key == "language":
			queue_rebuild())
	row.add_child(ob)
	return row
