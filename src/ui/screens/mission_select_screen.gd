extends ScreenBase
## MissionSelect: sector list with lock state, stars, optional objectives,
## boss preview and mode picker (including the local daily simulation).

var _mode := ""
var _difficulty := "normal"


func build() -> void:
	if _mode == "":
		_mode = Game.data.missions.selected_mode
	add_header(Loc.t("screen.mission_select"))
	var labels: Array = []
	for id in Content.mode_order:
		labels.append(Loc.text(Content.mode(id).name))
	header_box.add_child(tabs(Content.mode_order, labels, _mode, func(id): _mode = id; rebuild()))
	var mode_def := Content.mode(_mode)
	var info := UIKit.vbox(4)
	info.add_child(UIKit.label(Loc.text(mode_def.desc), 21, Palette.text_muted(), true))
	var st := Missions.mode_unlock_status(_mode)
	if not st.ok:
		info.add_child(UIKit.label(Loc.t("common.locked") + " · " + Loc.t(st.key, st.params), 21, Palette.CORAL, true))
	if not mode_def.get("cost", {}).is_empty():
		var row := UIKit.hbox(6)
		row.add_child(UIKit.label(Loc.t("mission.entry_cost"), 20, Palette.text_muted()))
		row.add_child(UIKit.amounts_row(mode_def.cost, 20, true))
		info.add_child(row)
	if _mode == "daily_sim":
		info.add_child(_daily_info())
	header_box.add_child(info)
	var list := scroll_body()
	if _mode == "daily_sim":
		list.add_child(_map_card(Missions.daily_map()))
	else:
		for id in Content.map_order:
			list.add_child(_map_card(id))


func _daily_info() -> Control:
	var v := UIKit.vbox(4)
	for mod in Missions.daily_modifiers():
		v.add_child(UIKit.label("◆ %s — %s" % [Loc.text(mod.name), Loc.text(mod.desc)], 20, Palette.AMBER, true))
	var claimed: bool = Game.data.missions.daily_sim_claimed == TimeService.day_key()
	v.add_child(UIKit.label(Loc.t("mission.daily_claimed") if claimed else Loc.t("mission.daily_available"), 19, Palette.text_muted(), true))
	v.add_child(UIKit.label(Loc.t("common.resets_in", {"time": TimeService.format_duration(TimeService.seconds_to_next_day())}), 19, Palette.text_muted()))
	return v


func _map_card(id: String) -> Control:
	var m := Content.map_def(id)
	var unlocked := Missions.is_map_unlocked(id)
	var glow := JsonUtil.color(m.palette.glow, Palette.TEAL)
	var p := UIKit.panel(null, Color(JsonUtil.color(m.palette.ground, Palette.PETROL), 0.9), glow if unlocked else Palette.border())
	var v := UIKit.vbox(6)
	p.add_child(v)
	var top := UIKit.hbox(8)
	top.add_child(UIKit.label(Loc.t("mission.sector", {"n": m.sector}), 20, glow))
	top.add_child(UIKit.spacer())
	for s in Missions.progress(id).stars:
		top.add_child(UIKit.icon("star", Palette.AMBER if s else Palette.PETROL_LIGHT, 30))
	v.add_child(top)
	v.add_child(UIKit.label(Loc.text(m.name), 30, Palette.text()))
	v.add_child(UIKit.label(Loc.text(m.desc), 19, Palette.text_muted(), true))
	var boss_id: String = m.get("boss", "")
	var facts := Loc.t("mission.duration", {"time": TimeService.format_duration(int(Missions.build_run_config(id, _mode).duration))})
	if boss_id != "" and not Content.mode(_mode).get("rules", {}).get("no_boss", false):
		facts += " · " + Loc.t("mission.boss", {"name": Loc.text(Content.enemy(boss_id).name)})
	v.add_child(UIKit.label(facts, 19, Palette.AMBER, true))
	if _mode == "expedition":
		for i in m.objectives.size():
			var o: Dictionary = m.objectives[i]
			var done: bool = Missions.progress(id).stars[i]
			v.add_child(UIKit.label(("✓ " if done else "○ ") + Loc.t("mission.obj." + str(o.type), {"n": _fmt_target(o)}), 19, Palette.GREEN if done else Palette.text_muted(), true))
		if not Missions.is_cleared(id):
			var fc := UIKit.hbox(6)
			fc.add_child(UIKit.label(Loc.t("mission.first_clear"), 19, Palette.text_muted()))
			fc.add_child(UIKit.amounts_row(m.rewards.first_clear, 18))
			v.add_child(fc)
	if not unlocked:
		v.add_child(UIKit.label(Loc.t("common.locked") + " · " + Loc.t("mission.locked_hint"), 20, Palette.CORAL, true))
		p.modulate = Color(1, 1, 1, 0.6)
		return p
	var row := UIKit.hbox(10)
	if Missions.is_cleared(id) and _mode == "expedition":
		var diff := CheckButton.new()
		diff.text = Loc.t("mission.hard")
		diff.button_pressed = _difficulty == "hard"
		diff.toggled.connect(func(on): _difficulty = "hard" if on else "normal")
		row.add_child(diff)
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.button(Loc.t("mission.select"), func(): _select(id), "secondary"))
	row.add_child(UIKit.button(Loc.t("mission.launch"), func(): _launch(id), "primary", 72))
	v.add_child(row)
	return p


func _fmt_target(o: Dictionary) -> String:
	if o.type == "finish_hp_pct":
		return "%d%%" % int(float(o.target) * 100)
	return str(int(o.target))


func _select(id: String) -> void:
	Game.data.missions.selected_map = id
	Game.data.missions.selected_mode = _mode
	Game.save_soon()
	Router.goto("lobby")


func _launch(id: String) -> void:
	var err := Missions.start(id, _mode, _difficulty)
	if err != "":
		Audio.play_ui(&"error")
		Router.toast(Loc.t(err), &"error")
		return
	Router.goto_loaded("battle")
