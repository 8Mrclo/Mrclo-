extends Node
## SettingsManager (autoload "Settings").
## Settings are persisted inside the save (data.settings) and applied to the
## engine, audio buses and localization whenever they change.

signal changed(key: String, value: Variant)


func get_value(key: String) -> Variant:
	if Game.data.is_empty():
		return SaveDefaults.settings_defaults().get(key)
	return Game.data.settings.get(key, SaveDefaults.settings_defaults().get(key))


func set_value(key: String, value: Variant) -> void:
	if Game.data.is_empty():
		return
	Game.data.settings[key] = value
	_apply_one(key, value)
	changed.emit(key, value)
	Game.save_soon()


func apply_all() -> void:
	for key in SaveDefaults.settings_defaults():
		_apply_one(key, get_value(key))


func _apply_one(key: String, value: Variant) -> void:
	match key:
		"fps":
			Engine.max_fps = int(value)
		"language":
			Loc.set_language(str(value))
		"music_volume", "sfx_volume", "ui_volume", "ambience_volume":
			Audio.apply_volumes()


func shake_strength() -> float:
	if bool(get_value("reduce_motion")):
		return 0.0
	return clampf(float(get_value("shake")), 0.0, 1.0)


func graphics_limits() -> Dictionary:
	var profile := str(get_value("graphics"))
	return Content.balance_value("limits." + profile, Content.balance_value("limits.medium", {}))


func vibrate(ms: int) -> void:
	if bool(get_value("vibration")) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
