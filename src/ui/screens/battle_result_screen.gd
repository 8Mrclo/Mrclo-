extends ScreenBase
## BattleResult: outcome, stats, optional objectives (stars) and rewards.


func build() -> void:
	var r: Dictionary = Game.last_result
	if r.is_empty():
		body.add_child(UIKit.empty_state(Loc.t("result.none")))
		body.add_child(UIKit.button(Loc.t("common.continue"), func(): Router.goto("lobby"), "primary"))
		return
	Audio.play_music("lobby")
	var victory: bool = r.get("victory", false)
	var t := UIKit.title(Loc.t("result.victory") if victory else Loc.t("result.defeat"))
	t.add_theme_color_override("font_color", Palette.AMBER if victory else Palette.CORAL)
	t.add_theme_font_size_override("font_size", 48)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_box.add_child(t)
	var m := Content.map_def(r.map)
	var sub := UIKit.label("%s · %s" % [Loc.text(m.name), Loc.text(Content.mode(r.mode).name)], 22, Palette.text_muted())
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_box.add_child(sub)
	var list := scroll_body()
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 24)
	for pair in [["result.time", TimeService.format_duration(int(r.time))], ["result.kills", Loc.format_number(r.kills)], ["result.elites", str(r.elite_kills)], ["result.level", str(r.level)], ["result.damage", Loc.format_number(r.damage_dealt)], ["result.evolutions", str(r.evolutions)]]:
		stats.add_child(UIKit.label(Loc.t(pair[0]), 21, Palette.text_muted()))
		stats.add_child(UIKit.label(pair[1], 22, Palette.text()))
	list.add_child(UIKit.panel(stats))
	if r.mode == "expedition":
		var objs := Missions.evaluate_objectives(m, r)
		var ov := UIKit.vbox(4)
		ov.add_child(UIKit.label(Loc.t("result.objectives"), 22, Palette.AMBER))
		for i in m.objectives.size():
			var o: Dictionary = m.objectives[i]
			var target := "%d%%" % int(float(o.target) * 100) if o.type == "finish_hp_pct" else str(int(o.target))
			ov.add_child(UIKit.label(("★ " if objs[i] else "☆ ") + Loc.t("mission.obj." + str(o.type), {"n": target}), 20, Palette.AMBER if objs[i] else Palette.text_muted(), true))
		list.add_child(UIKit.panel(ov))
	var rec: Dictionary = Game.last_rewards.get("record", {})
	if rec.get("first_clear", false):
		list.add_child(UIKit.label(Loc.t("result.first_clear"), 24, Palette.AMBER))
	if rec.get("new_stars", []).size() > 0:
		list.add_child(UIKit.label(Loc.t("result.new_stars", {"n": rec.new_stars.size()}), 22, Palette.AMBER))
	var rew: Dictionary = Game.last_rewards.get("run", {})
	var rv := UIKit.vbox(6)
	rv.add_child(UIKit.label(Loc.t("result.rewards"), 22, Palette.AMBER))
	rv.add_child(UIKit.amounts_row(rew.get("currencies", {}), 24))
	if rew.get("account_xp", 0) > 0:
		rv.add_child(UIKit.label("+%d %s" % [rew.account_xp, Loc.t("account.xp")], 20, Palette.MINT))
	list.add_child(UIKit.panel(rv))
	footer_box.add_child(UIKit.button(Loc.t("result.collect"), func(): Router.goto("reward_reveal", {"from": "battle"}), "primary", 96))

