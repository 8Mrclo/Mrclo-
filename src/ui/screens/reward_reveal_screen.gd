extends ScreenBase
## RewardReveal: staggered card reveal of everything granted (run rewards,
## first-clear/star rewards, capsule result).

var _cards: Array[Control] = []


func build() -> void:
	_cards.clear()
	var t := UIKit.title(Loc.t("reveal.title"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_box.add_child(t)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var summaries: Array = []
	if Game.last_rewards.has("run"):
		summaries.append(Game.last_rewards.run)
	for u in Game.last_rewards.get("record", {}).get("unique", []):
		summaries.append(u)
	if Game.last_rewards.has("crate"):
		summaries.append(Game.last_rewards.crate)
	var currencies := {}
	var items: Array = []
	for s in summaries:
		for c in s.get("currencies", {}):
			currencies[c] = int(currencies.get(c, 0)) + int(s.currencies[c])
		items.append_array(s.get("items", []))
	for c in currencies:
		grid.add_child(_card(UIKit.currency_shape(c), Palette.currency(c), Loc.format_number(currencies[c]), Loc.currency_name(c), Palette.border()))
	for uid in items:
		var it := Inventory.get_item(int(uid))
		if it.is_empty():
			continue
		var d := Content.item(it.def)
		grid.add_child(_card(d.icon.shape, JsonUtil.color(d.icon.color, Palette.TEAL), Loc.text(d.name), Loc.text(Content.rarity(it.rarity).name), Palette.rarity(it.rarity)))
	if Game.last_rewards.has("crate") and Game.last_rewards.crate.get("guaranteed", false):
		body.add_child(UIKit.label(Loc.t("reveal.guaranteed"), 21, Palette.AMBER, true))
	if _cards.is_empty():
		body.add_child(UIKit.empty_state(Loc.t("reveal.nothing")))
	body.add_child(UIKit.scroll(grid))
	var from: String = Router.params.get("from", "battle")
	footer_box.add_child(UIKit.button(Loc.t("common.continue"), func():
		Game.last_rewards = {}
		Router.goto("store" if from == "store" else "lobby"), "primary", 90))
	_animate()


func _card(shape: String, color: Color, title_text: String, sub: String, border: Color) -> Control:
	var p := UIKit.panel(null, Palette.panel_bg(), border)
	p.custom_minimum_size = Vector2(200, 220)
	var v := UIKit.vbox(4)
	p.add_child(v)
	var ic := UIKit.icon(shape, color, 96)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := UIKit.label(title_text, 21, Palette.text(), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var s := UIKit.label(sub, 17, border if border != Palette.border() else Palette.text_muted(), true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	p.modulate.a = 0.0
	_cards.append(p)
	return p


func _animate() -> void:
	var reduce: bool = bool(Settings.get_value("reduce_motion"))
	for i in _cards.size():
		var c := _cards[i]
		if reduce:
			c.modulate.a = 1.0
			continue
		var tw := create_tween()
		tw.tween_interval(0.12 * i)
		tw.tween_callback(func(): Audio.play_ui(&"reward"))
		tw.tween_property(c, "modulate:a", 1.0, 0.25)
