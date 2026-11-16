extends ScreenBase
## AgentSelect: roster grid + detail panel (trait, milestones, permanent
## level, shards, unlock condition).

var _focus := ""


func build() -> void:
	if _focus == "":
		_focus = Agents.selected()
	add_header(Loc.t("screen.agents"), false)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for id in Content.agent_order:
		grid.add_child(_tile(id))
	body.add_child(grid)
	var detail := scroll_body()
	detail.add_child(_details(_focus))
	add_nav("agents")
	Tutorial.notify_context("screen_agents")


func _tile(id: String) -> Control:
	var a := Content.agent(id)
	var unlocked := Agents.is_unlocked(id)
	var on := id == _focus
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 170)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var accent := Palette.AMBER if on else (Palette.TEAL if id == Agents.selected() else Palette.border())
	b.add_theme_stylebox_override("normal", UIKit.box(Palette.panel_bg(), accent, 3 if on else 2, 18))
	b.add_theme_stylebox_override("hover", UIKit.box(Palette.panel_alt(), Palette.TEAL, 2, 18))
	b.add_theme_stylebox_override("pressed", UIKit.box(Palette.PETROL, Palette.AMBER, 3, 18))
	var v := UIKit.vbox(2)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := AgentPortrait.new()
	portrait.agent_id = id
	portrait.locked = not unlocked
	portrait.custom_minimum_size = Vector2(0, 110)
	v.add_child(portrait)
	var l := UIKit.label(Loc.text(a.name), 19, Palette.text() if unlocked else Palette.text_muted())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	v.add_child(l)
	var sub := UIKit.label(Loc.t("common.lv", {"n": Agents.level(id)}) if unlocked else Loc.t("common.locked"), 16, Palette.AMBER)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	b.add_child(v)
	if (not unlocked and Agents.unlock_status(id).can) or Agents.can_level(id):
		var bd := UIKit.badge(0)
		bd.visible = true
		bd.position = Vector2(6, 6)
		b.add_child(bd)
	b.pressed.connect(func():
		Audio.play_ui(&"click")
		_focus = id
		rebuild())
	return b


func _details(id: String) -> Control:
	var a := Content.agent(id)
	var unlocked := Agents.is_unlocked(id)
	var p := UIKit.panel(null)
	var v := UIKit.vbox(10)
	p.add_child(v)
	var head := UIKit.hbox(10)
	var hv := UIKit.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.label(Loc.text(a.name), 32, Palette.text()))
	hv.add_child(UIKit.label(Loc.text(a.role), 21, Palette.MINT))
	head.add_child(hv)
	var shards := UIKit.hbox(4)
	shards.add_child(UIKit.icon("shard", Palette.currency("shard_" + id), 34))
	shards.add_child(UIKit.label(str(Agents.shards(id)), 22, Palette.text()))
	shards.tooltip_text = Loc.currency_name("shard_" + id)
	head.add_child(shards)
	v.add_child(head)
	v.add_child(UIKit.label(Loc.text(a.desc), 20, Palette.text_muted(), true))
	var tp := UIKit.panel(null, Color(Palette.PETROL_DEEP, 0.7), Palette.AMBER)
	var tv := UIKit.vbox(4)
	tp.add_child(tv)
	tv.add_child(UIKit.label(Loc.t("agent.trait") + ": " + Loc.text(a.trait.name), 22, Palette.AMBER))
	tv.add_child(UIKit.label(Loc.text(a.trait.desc), 20, Palette.text(), true))
	var start := Content.active(a.start_ability)
	tv.add_child(UIKit.label(Loc.t("agent.start_ability", {"name": Loc.text(start.name)}), 19, Palette.MINT, true))
	v.add_child(tp)
	v.add_child(UIKit.label(Loc.t("agent.attributes"), 22, Palette.AMBER))
	for m in Agents.modifiers(id):
		v.add_child(UIKit.label("• " + StatFormat.mod_line(m), 19, Palette.text(), true))
	v.add_child(UIKit.label(Loc.t("agent.milestones"), 22, Palette.AMBER))
	for ms in a.milestones:
		var reached := unlocked and Agents.level(id) >= int(ms.level)
		v.add_child(UIKit.label(("✓ " if reached else "○ ") + Loc.t("common.lv", {"n": ms.level}) + " — " + Loc.text(ms.desc), 19, Palette.GREEN if reached else Palette.text_muted(), true))
	if not unlocked:
		var st := Agents.unlock_status(id)
		v.add_child(UIKit.label(Loc.t(st.reason_key, st.params), 21, Palette.CORAL, true))
		var ub := UIKit.button(Loc.t("agent.unlock"), func(): _unlock(id), "primary", 72)
		ub.disabled = not st.can
		v.add_child(ub)
		return p
	var lvl := Agents.level(id)
	var row := UIKit.hbox(10)
	row.add_child(UIKit.label(Loc.t("agent.level", {"n": lvl, "max": Agents.max_level(id)}), 22, Palette.text()))
	row.add_child(UIKit.spacer())
	if lvl < Agents.max_level(id):
		row.add_child(UIKit.amounts_row(Agents.level_cost(id), 20, true))
	v.add_child(row)
	var actions := UIKit.hbox(10)
	var lb := UIKit.button(Loc.t("agent.level_up"), func(): _level(id), "secondary", 72)
	lb.disabled = not Agents.can_level(id)
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(lb)
	var sel := UIKit.button(Loc.t("agent.selected") if Agents.selected() == id else Loc.t("agent.select"), func(): _select(id), "primary", 72)
	sel.disabled = Agents.selected() == id
	sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(sel)
	v.add_child(actions)
	return p


func _unlock(id: String) -> void:
	var st := Agents.unlock_status(id)
	var go := func():
		if Agents.unlock(id):
			Audio.play_ui(&"reward")
			Router.toast(Loc.t("agent.unlocked", {"name": Loc.text(Content.agent(id).name)}), &"reward")
		rebuild()
	if st.cost.is_empty():
		go.call()
	else:
		Dialogs.confirm(Loc.t("agent.unlock"), _cost_body(st.cost), Loc.t("common.confirm"), go)


func _level(id: String) -> void:
	Dialogs.confirm(Loc.t("agent.level_up"), _cost_body(Agents.level_cost(id)), Loc.t("common.confirm"), func():
		if Agents.level_up(id):
			Audio.play_ui(&"confirm")
		else:
			Router.toast(Loc.t("store.err_funds"), &"error")
		rebuild())


func _select(id: String) -> void:
	Agents.select(id)
	Router.toast(Loc.t("agent.selected_toast", {"name": Loc.text(Content.agent(id).name)}))


static func _cost_body(cost: Dictionary) -> Control:
	var v := UIKit.vbox(8)
	v.add_child(UIKit.label(Loc.t("common.price"), 20, Palette.text_muted()))
	v.add_child(UIKit.amounts_row(cost, 24, true))
	v.add_child(UIKit.label(Loc.t("common.balance"), 20, Palette.text_muted()))
	var bal := {}
	for c in cost:
		bal[c] = Economy.balance(c)
	v.add_child(UIKit.amounts_row(bal, 22))
	return v
