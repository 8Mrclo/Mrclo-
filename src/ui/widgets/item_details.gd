class_name ItemDetails
extends RefCounted
## Item detail dialog with comparison against the equipped item, upgrade
## preview, equip/unequip, favorite and recycle (with confirmation).


static func show(uid: int, on_change: Callable) -> void:
	var it := Inventory.get_item(uid)
	if it.is_empty():
		return
	var def := Content.item(it.def)
	var v := UIKit.vbox(8)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.icon_from(def, 96, Palette.rarity(it.rarity)))
	var hv := UIKit.vbox(2)
	hv.add_child(UIKit.label(Loc.text(def.name), 28, Palette.text()))
	hv.add_child(UIKit.label("%s · %s · %s" % [Loc.text(Content.rarity(it.rarity).name), Loc.t("slot." + def.slot), Loc.t("common.lv_max", {"n": it.level, "max": ItemRules.max_level(it.rarity)})], 19, Palette.rarity(it.rarity), true))
	head.add_child(hv)
	v.add_child(head)
	v.add_child(UIKit.label(Loc.text(def.desc), 19, Palette.text_muted(), true))
	v.add_child(UIKit.label(Loc.t("item.origin", {"origin": Loc.text(def.get("origin", ""))}), 17, Palette.text_muted(), true))
	var mods := ItemRules.modifiers(it)
	for m in mods:
		v.add_child(UIKit.label("• " + StatFormat.mod_line(m), 20, Palette.text(), true))
	for e in def.get("rarity_effects", []):
		var unlocked := Content.rarity_index(it.rarity) >= Content.rarity_index(e.rarity)
		if not unlocked:
			v.add_child(UIKit.label("%s · %s: %s" % [Loc.t("common.locked"), Loc.text(Content.rarity(e.rarity).name), Loc.text(e.desc)], 18, Palette.text_muted(), true))
	var eq := Inventory.get_item(Inventory.equipped_uid(def.slot))
	if not eq.is_empty() and int(eq.uid) != uid:
		var diff := ItemRules.power(it) - ItemRules.power(eq)
		v.add_child(UIKit.label(Loc.t("item.compare", {"name": Loc.text(Content.item(eq.def).name), "diff": "%+d" % int(diff)}), 20, Palette.GREEN if diff >= 0 else Palette.CORAL, true))
	if ItemRules.can_upgrade(it):
		var next := it.duplicate()
		next.level = int(it.level) + 1
		var nm := ItemRules.modifiers(next)
		v.add_child(UIKit.label(Loc.t("item.next_level", {"line": StatFormat.mod_line(nm[0])}), 19, Palette.MINT, true))
		var crow := UIKit.hbox(6)
		crow.add_child(UIKit.label(Loc.t("common.price"), 19, Palette.text_muted()))
		crow.add_child(UIKit.amounts_row(ItemRules.upgrade_cost(it), 20, true))
		v.add_child(crow)
	var layer := Dialogs.info("", v, Loc.t("common.close"))
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	var close_and := func(cb: Callable):
		layer.queue_free()
		cb.call()
		on_change.call()
	var equipped := Inventory.is_equipped(uid)
	actions.add_child(_btn(Loc.t("item.unequip") if equipped else Loc.t("item.equip"), func(): close_and.call(func():
		if equipped:
			Inventory.unequip(def.slot)
		else:
			Inventory.equip(uid)
			Audio.play_ui(&"confirm")), "primary"))
	var up := _btn(Loc.t("item.upgrade"), func(): close_and.call(func():
		var r := Inventory.upgrade(uid)
		if r.ok:
			Audio.play_ui(&"confirm")
			Router.toast(Loc.t("item.upgraded"))
		else:
			Audio.play_ui(&"error")
			Router.toast(Loc.t(r.error), &"error")), "secondary")
	up.disabled = not ItemRules.can_upgrade(it) or not Economy.can_afford(ItemRules.upgrade_cost(it))
	actions.add_child(up)
	actions.add_child(_btn(Loc.t("item.unfavorite") if it.favorite else Loc.t("item.favorite"), func(): close_and.call(func(): Inventory.toggle_favorite(uid)), "ghost"))
	var rec := _btn(Loc.t("item.recycle"), func():
		layer.queue_free()
		Dialogs.confirm(Loc.t("item.recycle"), Loc.t("recycle.confirm", {"n": 1, "scrap": ItemRules.recycle_value(it)}), Loc.t("item.recycle"), func():
			var r := Inventory.recycle([uid])
			if r.ok:
				Router.toast(Loc.t("recycle.done", {"scrap": r.scrap}), &"reward")
			on_change.call(), true), "danger")
	rec.disabled = Inventory.is_protected(uid)
	if rec.disabled:
		rec.tooltip_text = Loc.t("recycle.protected")
	actions.add_child(rec)
	var box: VBoxContainer = v
	box.add_child(actions)
	Tutorial.notify_context("screen_equipment")


static func _btn(text: String, cb: Callable, kind: String) -> Button:
	var b := UIKit.button(text, cb, kind, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b
