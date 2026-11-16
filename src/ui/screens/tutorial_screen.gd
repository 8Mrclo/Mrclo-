extends ScreenBase
## Tutorial hub: lists contextual steps with status; each can be reviewed,
## skipped (if safe) or the whole tutorial restarted.


func build() -> void:
	add_header(Loc.t("screen.tutorial"))
	var p := Tutorial.progress()
	var row := UIKit.hbox(8)
	row.add_child(UIKit.label(Loc.t("settings.tutorial_progress", {"n": p.x, "max": p.y}), 20, Palette.text_muted()))
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.button(Loc.t("settings.reset_tutorial"), func(): Tutorial.reset_all(); rebuild(), "secondary", 56))
	header_box.add_child(row)
	var en := CheckButton.new()
	en.text = Loc.t("tutorial.enabled")
	en.button_pressed = Tutorial.is_enabled()
	en.toggled.connect(func(v): Tutorial.set_enabled(v))
	header_box.add_child(en)
	var list := scroll_body()
	for s in Content.tutorial_steps:
		var st := Tutorial.status(s.id)
		var panel := UIKit.panel(null)
		var v := UIKit.vbox(6)
		panel.add_child(v)
		var head := UIKit.hbox(8)
		head.add_child(UIKit.label(Loc.t("tutorial.step." + s.id), 22, Palette.AMBER))
		head.add_child(UIKit.spacer())
		head.add_child(UIKit.label(Loc.t("tutorial.status." + st), 19, Palette.GREEN if st == "done" else Palette.text_muted()))
		v.add_child(head)
		v.add_child(UIKit.label(Loc.text(s.text), 20, Palette.text(), true))
		if st == "pending" and s.get("skippable", true):
			var sid: String = s.id
			v.add_child(UIKit.button(Loc.t("tutorial.skip"), func(): Tutorial.skip(sid); rebuild(), "ghost", 52))
		list.add_child(panel)
