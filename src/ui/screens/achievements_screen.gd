extends ScreenBase
## Achievements: 40 permanent goals over lifetime counters.


func build() -> void:
	add_header(Loc.t("screen.achievements"))
	var row := UIKit.hbox(8)
	row.add_child(UIKit.label(Loc.t("achievements.progress", {"n": Achievements.completed_count(), "max": Content.achievements.size()}), 20, Palette.text_muted()))
	row.add_child(UIKit.spacer())
	var all := UIKit.button(Loc.t("objectives.claim_all"), func():
		var n := Achievements.claim_all()
		if n > 0:
			Audio.play_ui(&"reward")
			Router.toast(Loc.t("objectives.claimed_n", {"n": n}), &"reward"), "secondary", 56)
	all.disabled = Achievements.claimable_count() == 0
	row.add_child(all)
	header_box.add_child(row)
	var list := scroll_body()
	for a in Content.achievements:
		var e := Achievements.entry(a.id)
		var done := ObjectiveTracker.is_complete(a, e)
		var p := UIKit.panel(null)
		var h := UIKit.hbox(10)
		p.add_child(h)
		h.add_child(UIKit.icon("star", Palette.AMBER if e.claimed else (Palette.MINT if done else Palette.PETROL_LIGHT), 56))
		var v := UIKit.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(Loc.text(a.name), 22, Palette.text()))
		v.add_child(UIKit.label(Loc.t("objective." + str(a.event), {"target": Loc.format_number(float(a.target))}), 18, Palette.text_muted(), true))
		var pr := UIKit.hbox(6)
		pr.add_child(UIKit.progress(float(e.progress), float(a.target), Palette.GREEN if done else Palette.TEAL, 14))
		pr.add_child(UIKit.amounts_row(a.reward, 16))
		v.add_child(pr)
		h.add_child(v)
		if e.claimed:
			h.add_child(UIKit.label("✓", 30, Palette.GREEN))
		else:
			var id: String = a.id
			var b := UIKit.button(Loc.t("common.claim"), func(): show_reward_toast(Achievements.claim(id)), "primary" if done else "ghost", 52)
			b.disabled = not done
			h.add_child(b)
		list.add_child(p)
