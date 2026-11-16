extends ScreenBase
## Credits and asset attributions.


func build() -> void:
	add_header(Loc.t("screen.credits"))
	var list := scroll_body()
	for key in ["credits.game", "credits.engine", "credits.art", "credits.audio", "credits.font", "credits.license", "credits.thanks"]:
		var p := UIKit.panel(null)
		p.add_child(UIKit.label(Loc.t(key), 21, Palette.text(), true))
		list.add_child(p)
