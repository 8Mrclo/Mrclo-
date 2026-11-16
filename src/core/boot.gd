extends Control
## Boot: applies theme/settings, loads the profile (with corruption recovery),
## refreshes periodic content, grants login mail and routes to the lobby.


func _ready() -> void:
	InputSetup.ensure_actions()
	get_tree().root.theme = ThemeFactory.build()
	var bg := ColorRect.new()
	bg.color = Palette.PETROL_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var l := UIKit.label(Loc.t("boot.loading"), 28, Palette.MINT)
	l.set_anchors_preset(Control.PRESET_CENTER)
	add_child(l)
	await get_tree().process_frame
	if not Content.validation_errors.is_empty():
		push_warning("Conteúdo com %d erro(s) de validação" % Content.validation_errors.size())
	var report := Saves.load_profile()
	Game.boot_report = report
	Settings.apply_all()
	ThemeFactory.invalidate()
	get_tree().root.theme = ThemeFactory.shared()
	Objectives.refresh_periods()
	_daily_login()
	Game.touch_clock()
	Saves.save_now()
	if not report.get("corrupted", []).is_empty():
		Router.toast(Loc.t("save.recovered"), &"warn")
	Router.goto("lobby", {"offline_check": true})


func _daily_login() -> void:
	var today := TimeService.day_key()
	if Game.data.profile.last_login_day == today:
		return
	Game.data.profile.last_login_day = today
	Game.data.mail.append({"id": "daily_" + today, "title": "mail.daily.title", "body": "mail.daily.body", "reward": {"scrap": 150, "field_data": 5}, "claimed": false, "time": TimeService.now()})
	while Game.data.mail.size() > 20:
		Game.data.mail.pop_front()
	EventBus.emit_game(GameEvents.LOGIN_DAY)
