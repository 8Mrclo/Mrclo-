extends ScreenBase
## Workshop: upgrade (with reset/refund), fusion (manual + batch), recycling
## (multi-select with preview and confirmation), research tree and history.

var _tab := "upgrade"
var _selection: Dictionary = {}


func build() -> void:
	add_header(Loc.t("screen.workshop"))
	var ids := ["upgrade", "fusion", "recycle", "research", "history"]
	var labels: Array = ids.map(func(i): return Loc.t("workshop.tab." + i))
	header_box.add_child(tabs(ids, labels, _tab, func(id): _tab = id; _selection.clear(); rebuild()))
	match _tab:
		"upgrade": _build_upgrade()
		"fusion": _build_fusion()
		"recycle": _build_recycle()
		"research": _build_research()
		"history": _build_history()
	Tutorial.notify_context("screen_workshop")


func _build_upgrade() -> void:
	var list := scroll_body()
	var items := Inventory.list({}, "power")
	if items.is_empty():
		list.add_child(UIKit.empty_state(Loc.t("equip.empty"), "box"))
	for it in items:
		var uid := int(it.uid)
		var def := Content.item(it.def)
		var p := UIKit.panel(null)
		var row := UIKit.hbox(10)
		p.add_child(row)
		row.add_child(UIKit.icon_from(def, 64, Palette.rarity(it.rarity)))
		var v := UIKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(Loc.text(def.name), 21, Palette.text()))
		v.add_child(UIKit.label(Loc.t("common.lv_max", {"n": it.level, "max": ItemRules.max_level(it.rarity)}) + " · " + StatFormat.mod_line(ItemRules.modifiers(it)[0]), 17, Palette.rarity(it.rarity), true))
		if ItemRules.can_upgrade(it):
			v.add_child(UIKit.amounts_row(ItemRules.upgrade_cost(it), 18, true))
		row.add_child(v)
		var col := UIKit.vbox(4)
		var up := UIKit.button(Loc.t("item.upgrade"), func():
			var r := Inventory.upgrade(uid)
			Audio.play_ui(&"confirm" if r.ok else &"error")
			if not r.ok:
				Router.toast(Loc.t(r.error), &"error"), "secondary", 56)
		up.disabled = not ItemRules.can_upgrade(it) or not Economy.can_afford(ItemRules.upgrade_cost(it))
		col.add_child(up)
		if int(it.level) > 1:
			col.add_child(UIKit.button(Loc.t("workshop.reset"), func():
				Dialogs.confirm(Loc.t("workshop.reset"), Loc.t("workshop.reset_body", {"scrap": ItemRules.reset_refund(Inventory.get_item(uid)), "pct": int(float(Content.equipment_meta.upgrade.reset_refund) * 100)}), Loc.t("common.confirm"), func():
					var r := Inventory.reset_upgrade(uid)
					if r.ok:
						Router.toast(Loc.t("workshop.reset_done", {"scrap": r.refund}), &"reward"), true), "ghost", 52))
		row.add_child(col)
		list.add_child(p)


func _build_fusion() -> void:
	body.add_child(UIKit.label(Loc.t("fuse.rule", {"n": ItemRules.fusion_required()}), 20, Palette.text_muted(), true))
	var plan := Inventory.plan_batch_fuse()
	var batch := UIKit.button(Loc.t("fuse.batch", {"n": plan.size()}), func():
		Dialogs.confirm(Loc.t("fuse.batch_title"), Loc.t("fuse.batch_body", {"n": plan.size()}), Loc.t("common.confirm"), func():
			var n := Inventory.batch_fuse()
			Audio.play_ui(&"reward")
			Router.toast(Loc.t("fuse.batch_done", {"n": n}), &"reward")), "primary", 72)
	batch.disabled = plan.is_empty()
	body.add_child(batch)
	var list := scroll_body()
	if plan.is_empty():
		list.add_child(UIKit.empty_state(Loc.t("fuse.none"), "prism"))
	for grp in plan:
		var first := Inventory.get_item(int(grp[0]))
		var def := Content.item(first.def)
		var next := Content.next_rarity(first.rarity)
		var p := UIKit.panel(null)
		var row := UIKit.hbox(10)
		p.add_child(row)
		row.add_child(UIKit.icon_from(def, 64, Palette.rarity(first.rarity)))
		var v := UIKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(Loc.text(def.name), 21, Palette.text()))
		v.add_child(UIKit.label("%d× %s → %s" % [grp.size(), Loc.text(Content.rarity(first.rarity).name), Loc.text(Content.rarity(next).name)], 18, Palette.rarity(next)))
		row.add_child(v)
		var g: Array = grp
		row.add_child(UIKit.button(Loc.t("fuse.fuse"), func():
			var r := Inventory.fuse(g)
			if r.ok:
				Audio.play_ui(&"reward")
				Router.toast(Loc.t("fuse.done"), &"reward")
			else:
				Router.toast(Loc.t(r.error), &"error"), "secondary", 56))
		list.add_child(p)


func _build_recycle() -> void:
	body.add_child(UIKit.label(Loc.t("recycle.rule"), 20, Palette.text_muted(), true))
	var uids: Array = _selection.keys()
	var preview := Inventory.recycle_preview(uids)
	var row := UIKit.hbox(8)
	row.add_child(UIKit.label(Loc.t("recycle.selected", {"n": uids.size()}), 20, Palette.text()))
	row.add_child(UIKit.amounts_row({"scrap": preview.scrap}, 20))
	row.add_child(UIKit.spacer())
	var go := UIKit.button(Loc.t("item.recycle"), func():
		Dialogs.confirm(Loc.t("item.recycle"), Loc.t("recycle.confirm", {"n": uids.size(), "scrap": preview.scrap}), Loc.t("item.recycle"), func():
			var r := Inventory.recycle(uids)
			_selection.clear()
			if r.ok:
				Router.toast(Loc.t("recycle.done", {"scrap": r.scrap}), &"reward")
			rebuild(), true), "danger", 60)
	go.disabled = uids.is_empty()
	row.add_child(go)
	body.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var count := 0
	for it in Inventory.list({}, "rarity"):
		var uid := int(it.uid)
		if Inventory.is_protected(uid):
			continue
		count += 1
		var tile := ItemTile.new().setup(it, 140)
		tile.selected = _selection.has(uid)
		tile.pressed.connect(func():
			if _selection.has(uid):
				_selection.erase(uid)
			else:
				_selection[uid] = true
			rebuild())
		grid.add_child(tile)
	var holder := UIKit.vbox(8)
	if count == 0:
		holder.add_child(UIKit.empty_state(Loc.t("recycle.none"), "gear"))
	holder.add_child(grid)
	holder.add_child(UIKit.label(Loc.t("recycle.protected_note"), 17, Palette.text_muted(), true))
	body.add_child(UIKit.scroll(holder))


func _build_research() -> void:
	var bal := UIKit.hbox(8)
	bal.add_child(UIKit.label(Loc.t("research.balance"), 20, Palette.text_muted()))
	bal.add_child(UIKit.amounts_row({"field_data": Economy.balance("field_data"), "scrap": Economy.balance("scrap")}, 20))
	body.add_child(bal)
	var tree := ResearchTreeView.new()
	tree.build()
	tree.node_pressed.connect(_research_details)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(tree)
	body.add_child(sc)


func _research_details(id: String) -> void:
	var n := Content.research_node(id)
	var v := UIKit.vbox(8)
	v.add_child(UIKit.label(Loc.t("research.rank", {"n": Research.rank(id), "max": n.max_rank}), 22, Palette.AMBER))
	var eff: Dictionary = n.effect
	if eff.type == "stat":
		v.add_child(UIKit.label(Loc.t("research.per_rank", {"line": StatFormat.mod_line(eff)}), 21, Palette.text(), true))
	else:
		v.add_child(UIKit.label(Loc.t("research.meta." + str(eff.key), {"v": eff.value}), 21, Palette.text(), true))
	var missing := Research.missing_requirements(id)
	if not missing.is_empty():
		var names: PackedStringArray = []
		for m in missing:
			names.append(Loc.text(Content.research_node(m).name))
		v.add_child(UIKit.label(Loc.t("research.requires", {"list": ", ".join(names)}), 20, Palette.CORAL, true))
	var err := Research.check(id)
	if err != "research.err_max":
		var crow := UIKit.hbox(6)
		crow.add_child(UIKit.label(Loc.t("common.price"), 19, Palette.text_muted()))
		crow.add_child(UIKit.amounts_row(Research.cost(id), 21, true))
		v.add_child(crow)
	if err == "":
		Dialogs.confirm(Loc.text(n.name), v, Loc.t("research.buy"), func():
			var e := Research.buy(id)
			if e == "":
				Audio.play_ui(&"reward")
				Router.toast(Loc.t("research.bought"), &"reward")
			else:
				Router.toast(Loc.t(e), &"error"))
	else:
		v.add_child(UIKit.label(Loc.t(err), 20, Palette.CORAL, true))
		Dialogs.info(Loc.text(n.name), v)


func _build_history() -> void:
	var list := scroll_body()
	var h: Array = Inventory.history().duplicate()
	h.reverse()
	if h.is_empty():
		list.add_child(UIKit.empty_state(Loc.t("workshop.history_empty"), "clock"))
	for e in h:
		var item_name := Loc.text(Content.item(str(e.get("def", ""))).get("name", ""))
		list.add_child(UIKit.label("%s · %s %s" % [Time.get_datetime_string_from_unix_time(int(e.t)).replace("T", " "), Loc.t("workshop.op." + str(e.op)), item_name], 19, Palette.text(), true))
