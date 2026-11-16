extends ScreenBase
## Equipment (Arsenal): equipped slots, combat stat preview, inventory with
## slot/rarity filters, sorting, auto-equip and access to the workshop.

var _slot_filter := ""
var _rarity_filter := ""
var _sort := "rarity"


func build() -> void:
	add_header(Loc.t("screen.equipment"), false)
	var slots := GridContainer.new()
	slots.columns = 3
	slots.add_theme_constant_override("h_separation", 8)
	slots.add_theme_constant_override("v_separation", 8)
	for s in Content.slots:
		slots.add_child(_slot_box(s))
	header_box.add_child(slots)
	var row := UIKit.hbox(8)
	row.add_child(_stat_preview())
	header_box.add_child(row)
	var actions := UIKit.hbox(8)
	var ae := UIKit.button(Loc.t("equip.auto"), func():
		var n := Inventory.auto_equip()
		Router.toast(Loc.t("equip.auto_done", {"n": n})), "secondary")
	ae.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(ae)
	var ws := UIKit.button(Loc.t("lobby.workshop"), func(): Router.goto("workshop"), "ghost")
	ws.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(ws)
	header_box.add_child(actions)
	var ids: Array = [""]
	ids.append_array(Content.slots)
	var labels: Array = [Loc.t("common.all")]
	for s in Content.slots:
		labels.append(Loc.t("slot." + s))
	body.add_child(tabs(ids, labels, _slot_filter, func(id): _slot_filter = id; rebuild()))
	var opts := UIKit.hbox(8)
	opts.add_child(_option(Loc.t("equip.rarity"), [""] + Array(Content.rarity_order), _rarity_filter, func(v): _rarity_filter = v; rebuild(), func(v): return Loc.t("common.all") if v == "" else Loc.text(Content.rarity(v).name)))
	opts.add_child(_option(Loc.t("equip.sort"), ["rarity", "level", "power", "slot"], _sort, func(v): _sort = v; rebuild(), func(v): return Loc.t("sort." + v)))
	body.add_child(opts)
	var list := Inventory.list({"slot": _slot_filter, "rarity": _rarity_filter}, _sort)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for it in list:
		var tile := ItemTile.new().setup(it, 140)
		var uid := int(it.uid)
		tile.pressed.connect(func(): ItemDetails.show(uid, rebuild))
		grid.add_child(tile)
	var holder := UIKit.vbox(8)
	if list.is_empty():
		holder.add_child(UIKit.empty_state(Loc.t("equip.empty"), "box"))
	else:
		holder.add_child(UIKit.label(Loc.t("equip.count", {"n": list.size()}), 18, Palette.text_muted()))
		holder.add_child(grid)
	body.add_child(UIKit.scroll(holder))
	add_nav("equipment")
	Tutorial.notify_context("screen_equipment")


func _slot_box(slot: String) -> Control:
	var it := Inventory.get_item(Inventory.equipped_uid(slot))
	if it.is_empty():
		var b := UIKit.button(Loc.t("slot." + slot) + "\n" + Loc.t("equip.empty_slot"), func(): _slot_filter = slot; rebuild(), "ghost", 120)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return b
	var tile := ItemTile.new().setup(it, 120)
	var uid := int(it.uid)
	tile.pressed.connect(func(): ItemDetails.show(uid, rebuild))
	tile.tooltip_text = Loc.text(Content.item(it.def).name)
	return tile


func _stat_preview() -> Control:
	var block := StatBlock.new()
	block.add_all(Agents.modifiers(Agents.selected()))
	block.add_all(Inventory.equipped_modifiers())
	block.add_all(Research.modifiers())
	var p := UIKit.panel(null)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 18)
	p.add_child(g)
	for s in ["max_hp", "damage", "armor", "crit_chance", "move_speed", "pickup"]:
		g.add_child(UIKit.label("%s %s" % [Loc.t("stat." + s), StatFormat.value(s, block.get_stat(s))], 18, Palette.text()))
	return p


func _option(title_text: String, values: Array, current: String, on_pick: Callable, fmt: Callable) -> Control:
	var h := UIKit.hbox(6)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(UIKit.label(title_text, 18, Palette.text_muted()))
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(0, 56)
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in values.size():
		ob.add_item(fmt.call(values[i]), i)
		if values[i] == current:
			ob.select(i)
	ob.item_selected.connect(func(i): on_pick.call(values[i]))
	h.add_child(ob)
	return h
