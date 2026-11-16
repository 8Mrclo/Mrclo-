extends ScreenBase
## Missions (Operações): tutorial/daily/weekly objectives with individual
## and batch claiming, plus shortcuts to achievements and game modes.

var _tab := "daily"


func build() -> void:
	Objectives.refresh_periods()
	add_header(Loc.t("screen.missions"), false)
	var ids := ["daily", "weekly", "tutorial"]
	var labels: Array = []
	for i in ids:
		var n := Objectives.claimable_count(i)
		labels.append(Loc.t("objectives.tab." + i) + (" (%d)" % n if n > 0 else ""))
	header_box.add_child(tabs(ids, labels, _tab, func(id): _tab = id; rebuild()))
	var row := UIKit.hbox(8)
	if _tab != "tutorial":
		var reset := TimeService.seconds_to_next_day() if _tab == "daily" else TimeService.seconds_to_next_week()
		row.add_child(UIKit.label(Loc.t("common.resets_in", {"time": TimeService.format_duration(reset)}), 19, Palette.text_muted()))
	row.add_child(UIKit.spacer())
	var all := UIKit.button(Loc.t("objectives.claim_all"), func():
		var n := Objectives.claim_all(_tab)
		if n > 0:
			Audio.play_ui(&"reward")
			Router.toast(Loc.t("objectives.claimed_n", {"n": n}), &"reward"), "secondary", 56)
	all.disabled = Objectives.claimable_count(_tab) == 0
	row.add_child(all)
	header_box.add_child(row)
	if _tab == "daily":
		header_box.add_child(_milestones())
	var list := scroll_body()
	var defs := Objectives.defs(_tab)
	if defs.is_empty():
		list.add_child(UIKit.empty_state(Loc.t("objectives.empty"), "clock"))
	for d in defs:
		list.add_child(_row(d))
	var links := UIKit.hbox(8)
	var ach := UIKit.button(Loc.t("lobby.achievements") + (" (%d)" % Achievements.claimable_count() if Achievements.claimable_count() > 0 else ""), func(): Router.goto("achievements"), "ghost")
	ach.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links.add_child(ach)
	var modes := UIKit.button(Loc.t("objectives.modes"), func(): Router.goto("mission_select"), "ghost")
	modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links.add_child(modes)
	body.add_child(links)
	add_nav("missions")


func _row(d: Dictionary) -> Control:
	var e := Objectives.entry(_tab, d.id)
	var done := ObjectiveTracker.is_complete(d, e)
	var p := UIKit.panel(null, Color(0, 0, 0, 0), Palette.AMBER if done and not e.claimed else Color(0, 0, 0, 0))
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.add_child(UIKit.label(ObjectiveTracker.describe(d), 21, Palette.text() if not e.claimed else Palette.text_muted(), true))
	var row := UIKit.hbox(8)
	var prog := UIKit.progress(float(e.progress), float(d.target), Palette.GREEN if done else Palette.TEAL, 16)
	row.add_child(prog)
	row.add_child(UIKit.label("%s/%s" % [Loc.format_number(float(e.progress)), Loc.format_number(float(d.target))], 17, Palette.text_muted()))
	v.add_child(row)
	var row2 := UIKit.hbox(8)
	row2.add_child(UIKit.amounts_row(d.reward, 18))
	row2.add_child(UIKit.spacer())
	if e.claimed:
		row2.add_child(UIKit.label(Loc.t("common.claimed"), 19, Palette.GREEN))
	else:
		var b := UIKit.button(Loc.t("common.claim"), func():
			show_reward_toast(Objectives.claim(_tab, d.id)), "primary" if done else "ghost", 52)
		b.disabled = not done
		row2.add_child(b)
	v.add_child(row2)
	return p


func _milestones() -> Control:
	var p := UIKit.panel(null, Color(Palette.PETROL_DEEP, 0.8), Palette.AMBER)
	var v := UIKit.vbox(6)
	p.add_child(v)
	var track := Objectives.milestone_track()
	var done := Objectives.daily_claimed_count()
	var top := 1
	for m in track:
		top = maxi(top, int(m.at))
	v.add_child(UIKit.label(Loc.t("objectives.milestones", {"n": done, "max": top}), 20, Palette.AMBER))
	v.add_child(UIKit.progress(done, top, Palette.AMBER, 14))
	var row := UIKit.hbox(8)
	for i in track.size():
		var m: Dictionary = track[i]
		var box := UIKit.vbox(2)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(UIKit.label(Loc.t("objectives.milestone_at", {"n": m.at}), 17, Palette.text_muted()))
		box.add_child(UIKit.amounts_row(m.reward, 17))
		var idx := i
		var claimed := Rewards.is_claimed(Objectives.milestone_key(i))
		var b := UIKit.button(Loc.t("common.claimed") if claimed else Loc.t("common.claim"), func(): show_reward_toast(Objectives.claim_milestone(idx)), "primary" if Objectives.can_claim_milestone(i) else "ghost", 52)
		b.disabled = not Objectives.can_claim_milestone(i)
		box.add_child(b)
		row.add_child(box)
	v.add_child(row)
	return p
