extends ScreenBase
## Store (Mercado): fictional currencies only. Each purchase shows price,
## balance and asks for confirmation. Capsules show odds and the guarantee.

var _tab := "featured"


func build() -> void:
	add_header(Loc.t("screen.store"), false)
	var ids: Array = Content.store.get("tabs", [])
	var labels: Array = ids.map(func(i): return Loc.t("store.tab." + i))
	header_box.add_child(tabs(ids, labels, _tab, func(id): _tab = id; rebuild()))
	var note := UIKit.label(Loc.t("store.no_real_money"), 17, Palette.text_muted(), true)
	header_box.add_child(note)
	var list := scroll_body()
	if _tab == "featured":
		list.add_child(UIKit.label(Loc.t("store.rotation_resets", {"time": TimeService.format_duration(TimeService.seconds_to_next_day())}), 19, Palette.AMBER))
	var offers := Store.offers(_tab)
	if offers.is_empty():
		list.add_child(UIKit.empty_state(Loc.t("store.empty"), "box"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for o in offers:
		grid.add_child(_offer_card(o))
	list.add_child(grid)
	add_nav("store")
	Tutorial.notify_context("screen_store")


func _offer_card(o: Dictionary) -> Control:
	var p := UIKit.panel(null)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(6)
	p.add_child(v)
	var ic := UIKit.icon_from(o, 84)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var t := UIKit.label(Loc.text(o.get("name", o.id)), 21, Palette.text(), true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var gives := _gives_text(o)
	if gives != "":
		var g := UIKit.label(gives, 17, Palette.MINT, true)
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(g)
	var limit := int(o.get("limit", 0))
	if limit > 0:
		var rem := Store.remaining(o)
		var lt := Loc.t("store.limit", {"n": rem, "max": limit})
		if o.get("period", "none") != "none":
			lt += " · " + Loc.t("common.resets_in", {"time": TimeService.format_duration(Store.seconds_to_reset(o.period))})
		var ll := UIKit.label(lt, 16, Palette.text_muted(), true)
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ll)
	var cost: Dictionary = o.get("cost", {})
	var err := Store.check(o)
	var btn_text := Loc.t("store.free") if cost.is_empty() else Loc.t("store.buy")
	if err == "store.err_limit":
		btn_text = Loc.t("store.sold_out")
	var row := UIKit.amounts_row(cost, 19, true)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var b := UIKit.button(btn_text, func(): _confirm(o, false), "primary" if cost.is_empty() and err == "" else "secondary", 60)
	b.disabled = err == "store.err_limit" or err == "store.err_level"
	if err == "store.err_level":
		b.text = Loc.t("store.need_level", {"n": o.requires.account_level})
	v.add_child(b)
	if o.has("alt_cost"):
		var alt := UIKit.button(Loc.t("store.use_key", {"n": Economy.balance("crate_key")}), func(): _confirm(o, true), "ghost", 56)
		alt.disabled = Store.check(o, true) != ""
		v.add_child(alt)
	if o.get("kind", "") == "crate":
		v.add_child(UIKit.button(Loc.t("store.odds"), func(): _show_odds(o.crate), "ghost", 52))
	return p


func _gives_text(o: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in o.get("gives", {}):
		var val: Variant = o.gives[k]
		match k:
			"item":
				var r: String = val.get("rarity", "common")
				var nm := Loc.text(Content.item(val.def).name) if val.has("def") else Loc.t("store.random_item")
				parts.append("%s (%s)" % [nm, Loc.text(Content.rarity(r).name)])
			"random_shards":
				parts.append(Loc.t("store.random_shards", {"n": val}))
			_:
				parts.append("%s %s" % [Loc.format_number(float(val)), Loc.currency_name(k)])
	return ", ".join(parts)


func _confirm(o: Dictionary, use_alt: bool) -> void:
	var cost: Dictionary = o.get("alt_cost", {}) if use_alt else o.get("cost", {})
	var err := Store.check(o, use_alt)
	if err != "":
		Audio.play_ui(&"error")
		Router.toast(Loc.t(err), &"error")
		return
	var v := UIKit.vbox(8)
	v.add_child(UIKit.label(Loc.text(o.get("name", o.id)), 24, Palette.text()))
	if not cost.is_empty():
		v.add_child(UIKit.label(Loc.t("common.price"), 19, Palette.text_muted()))
		v.add_child(UIKit.amounts_row(cost, 24, true))
		var bal := {}
		for c in cost:
			bal[c] = Economy.balance(c)
		v.add_child(UIKit.label(Loc.t("common.balance"), 19, Palette.text_muted()))
		v.add_child(UIKit.amounts_row(bal, 22))
	Dialogs.confirm(Loc.t("store.confirm_title"), v, Loc.t("common.confirm"), func():
		var res := Store.purchase(o.id, use_alt)
		if not res.ok:
			Router.toast(Loc.t(res.error), &"error")
			return
		var s: Dictionary = res.summary
		if s.has("rarity"):
			Game.last_rewards = {"crate": s}
			Router.goto("reward_reveal", {"from": "store"})
		else:
			show_reward_toast(s)
			rebuild())


func _show_odds(crate_id: String) -> void:
	var crate: Dictionary = Content.store.crates.get(crate_id, {})
	var v := UIKit.vbox(6)
	for pair in crate.get("odds", []):
		var row := UIKit.hbox(8)
		row.add_child(UIKit.label(Loc.text(Content.rarity(pair[0]).name), 22, Palette.rarity(pair[0])))
		row.add_child(UIKit.spacer())
		row.add_child(UIKit.label("%.1f%%" % (float(pair[1]) * 100.0), 22, Palette.text()))
		v.add_child(row)
	var th := int(crate.get("pity_threshold", 0))
	if th > 0:
		v.add_child(UIKit.label(Loc.t("store.pity", {"n": th, "rarity": Loc.text(Content.rarity(crate.pity_min_rarity).name), "cur": Store.pity_progress(crate_id)}), 20, Palette.AMBER, true))
	v.add_child(UIKit.label(Loc.text(Content.store.crate_progression.desc), 18, Palette.text_muted(), true))
	Dialogs.info(Loc.t("store.odds"), v)
