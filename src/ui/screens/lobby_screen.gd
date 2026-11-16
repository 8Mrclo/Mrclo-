extends ScreenBase
## MainLobby: hangar of Farol Nove. Agent bay on the left diagonal, operation
## card on the right, launch panel below, shortcut chips above.


func _ready() -> void:
	super._ready()
	Audio.play_music("lobby")
	if Router.params.get("offline_check", false):
		Router.params.erase("offline_check")
		_offline_check.call_deferred()


func build() -> void:
	header_box.add_child(CurrencyBar.new())
	var chips := UIKit.hbox(8)
	chips.add_child(_chip("settings", Loc.t("lobby.settings"), "gear", func(): Router.goto("settings"), 0))
	chips.add_child(_chip("mail", Loc.t("lobby.mail"), "box", _open_mail, Game.unclaimed_mail()))
	chips.add_child(_chip("ach", Loc.t("lobby.achievements"), "star", func(): Router.goto("achievements"), Achievements.claimable_count()))
	chips.add_child(_chip("codex", Loc.t("lobby.codex"), "prism", func(): Router.goto("codex"), 0))
	chips.add_child(_chip("workshop", Loc.t("lobby.workshop"), "fist", func(): Router.goto("workshop"), Research.affordable_count()))
	header_box.add_child(chips)
	var bay := UIKit.hbox(12)
	bay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(bay)
	bay.add_child(_agent_bay())
	bay.add_child(_operation_card())
	body.add_child(_launch_panel())
	add_nav("lobby")


func _chip(_id: String, text: String, shape: String, cb: Callable, badge: int) -> Control:
	var b := UIKit.button("", cb, "ghost", 84)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = text
	var v := UIKit.vbox(0)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UIKit.icon(shape, Palette.MINT, 40)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.backdrop = false
	v.add_child(ic)
	var l := UIKit.label(text, 16, Palette.text_muted())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	v.add_child(l)
	b.add_child(v)
	if badge > 0:
		var bd := UIKit.badge(badge)
		bd.position = Vector2(4, 2)
		b.add_child(bd)
	return b


func _agent_bay() -> Control:
	var id := Agents.selected()
	var a := Content.agent(id)
	var p := UIKit.panel(null, Color(Palette.PETROL_DEEP, 0.55), Palette.TEAL)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = 1.3
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.add_child(UIKit.label(Loc.t("lobby.agent_bay"), 18, Palette.text_muted()))
	v.add_child(UIKit.label(Loc.text(a.name), 30, Palette.text()))
	v.add_child(UIKit.label(Loc.text(a.role), 20, Palette.MINT))
	var portrait := AgentPortrait.new()
	portrait.agent_id = id
	portrait.custom_minimum_size = Vector2(0, 300)
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(portrait)
	v.add_child(UIKit.label(Loc.t("common.lv", {"n": Agents.level(id)}) + " · " + Loc.text(a.trait.name), 20, Palette.AMBER, true))
	v.add_child(UIKit.button(Loc.t("lobby.change_agent"), func(): Router.goto("agents"), "secondary"))
	return p


func _operation_card() -> Control:
	var map_id: String = Game.data.missions.selected_map
	if not Missions.is_map_unlocked(map_id):
		map_id = Content.map_order[0]
	var mode_id: String = Game.data.missions.selected_mode
	var m := Content.map_def(map_id)
	var p := UIKit.panel(null, Color(Palette.PETROL_DEEP, 0.55), Palette.AMBER)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(8)
	p.add_child(v)
	v.add_child(UIKit.label(Loc.t("lobby.operation"), 18, Palette.text_muted()))
	v.add_child(UIKit.label(Loc.t("mission.sector", {"n": m.sector}), 20, Palette.AMBER))
	v.add_child(UIKit.label(Loc.text(m.name), 28, Palette.text(), true))
	v.add_child(UIKit.label(Loc.text(Content.mode(mode_id).name), 22, Palette.MINT))
	v.add_child(_stars(map_id))
	var swatch := ColorRect.new()
	swatch.color = JsonUtil.color(m.palette.glow, Palette.TEAL)
	swatch.custom_minimum_size = Vector2(0, 6)
	v.add_child(swatch)
	v.add_child(UIKit.label(Loc.text(m.desc), 18, Palette.text_muted(), true))
	v.add_child(UIKit.spacer(0))
	v.add_child(UIKit.button(Loc.t("lobby.change_mission"), func(): Router.goto("mission_select"), "secondary"))
	return p


func _stars(map_id: String) -> Control:
	var row := UIKit.hbox(4)
	var stars: Array = Missions.progress(map_id).stars
	for s in stars:
		row.add_child(UIKit.icon("star", Palette.AMBER if s else Palette.PETROL_LIGHT, 34))
	if Missions.is_cleared(map_id):
		row.add_child(UIKit.label(Loc.t("mission.cleared"), 18, Palette.GREEN))
	return row


func _launch_panel() -> Control:
	var v := UIKit.vbox(8)
	var start := UIKit.button(Loc.t("lobby.start"), _start, "primary", 110)
	v.add_child(start)
	var cost: Dictionary = Content.mode(Game.data.missions.selected_mode).get("cost", {})
	if not cost.is_empty():
		var row := UIKit.amounts_row(cost, 20, true)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(row)
	return v


func _start() -> void:
	var map_id: String = Game.data.missions.selected_map
	if not Missions.is_map_unlocked(map_id):
		map_id = Content.map_order[0]
	var err := Missions.start(map_id, Game.data.missions.selected_mode)
	if err != "":
		Audio.play_ui(&"error")
		Router.toast(Loc.t(err), &"error")
		return
	Router.goto_loaded("battle")


func _offline_check() -> void:
	var p := Rewards.offline_preview()
	if p.anomaly:
		Rewards.claim_offline()
		Dialogs.info(Loc.t("offline.title"), Loc.t("offline.anomaly"))
		return
	if p.rewards.is_empty():
		return
	var v := UIKit.vbox(10)
	v.add_child(UIKit.label(Loc.t("offline.body", {"time": TimeService.format_duration(int(p.seconds))}), 24, Palette.text(), true))
	if p.capped:
		v.add_child(UIKit.label(Loc.t("offline.capped"), 20, Palette.AMBER, true))
	v.add_child(UIKit.amounts_row(p.rewards, 26))
	Dialogs.confirm(Loc.t("offline.title"), v, Loc.t("common.claim"), func():
		var res := Rewards.claim_offline()
		Audio.play_ui(&"reward")
		Router.toast(Loc.t("offline.claimed", {"time": TimeService.format_duration(int(res.seconds))}), &"reward"))


func _open_mail() -> void:
	var v := UIKit.vbox(10)
	var mails: Array = Game.data.mail.duplicate()
	mails.reverse()
	if mails.is_empty():
		v.add_child(UIKit.empty_state(Loc.t("mail.empty"), "box"))
	for m in mails:
		var p := UIKit.panel(null)
		var mv := UIKit.vbox(6)
		p.add_child(mv)
		mv.add_child(UIKit.label(Loc.t(m.title), 24, Palette.AMBER))
		mv.add_child(UIKit.label(Loc.t(m.body), 20, Palette.text(), true))
		var row := UIKit.hbox(8)
		row.add_child(UIKit.amounts_row(m.reward, 20))
		row.add_child(UIKit.spacer())
		if m.claimed:
			row.add_child(UIKit.label(Loc.t("common.claimed"), 20, Palette.GREEN))
		else:
			var mail_ref: Dictionary = m
			row.add_child(UIKit.button(Loc.t("common.claim"), func():
				if mail_ref.claimed:
					return
				mail_ref.claimed = true
				show_reward_toast(Rewards.grant(mail_ref.reward, "mail", "mail:" + str(mail_ref.id)))
				Saves.save_now()
				EventBus.notifications_changed.emit()
				_close_mail_and_reopen(), "secondary", 56))
		mv.add_child(row)
		v.add_child(p)
	var sc := UIKit.scroll(v)
	sc.custom_minimum_size = Vector2(560, 640)
	_mail_layer = Dialogs.info(Loc.t("mail.title"), sc)


var _mail_layer: CanvasLayer


func _close_mail_and_reopen() -> void:
	if is_instance_valid(_mail_layer):
		_mail_layer.queue_free()
	_open_mail.call_deferred()
