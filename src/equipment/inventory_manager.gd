extends Node
## InventoryManager (autoload "Inventory").
## Owns items, equipped slots and the workshop operations
## (upgrade, reset, fuse, batch fuse, recycle). Protected items (favorite or
## equipped) can never be consumed by fusion/recycling.

signal changed


func items() -> Dictionary:
	return Game.data.inventory.items


func get_item(uid: int) -> Dictionary:
	return items().get(str(uid), {})


func add_item(def_id: String, rarity_id: String, source: String = "") -> int:
	if Content.item(def_id).is_empty():
		push_warning("Inventory: item inexistente %s" % def_id)
		return -1
	var inv: Dictionary = Game.data.inventory
	var uid: int = int(inv.next_uid)
	inv.next_uid = uid + 1
	inv.items[str(uid)] = {"uid": uid, "def": def_id, "rarity": rarity_id, "level": 1, "favorite": false, "invested": 0, "source": source}
	Game.discover("items", def_id)
	_changed()
	return uid


func equipped_uid(slot: String) -> int:
	return int(Game.data.equipped.get(slot, -1))


func is_equipped(uid: int) -> bool:
	for s in Game.data.equipped:
		if int(Game.data.equipped[s]) == uid:
			return true
	return false


func is_protected(uid: int) -> bool:
	var it := get_item(uid)
	return it.is_empty() or bool(it.favorite) or is_equipped(uid)


func slot_of(uid: int) -> String:
	return str(Content.item(get_item(uid).get("def", "")).get("slot", ""))


func equip(uid: int) -> bool:
	var it := get_item(uid)
	if it.is_empty():
		return false
	Game.data.equipped[slot_of(uid)] = uid
	EventBus.emit_game(GameEvents.ITEM_EQUIPPED, 1.0, {"slot": slot_of(uid)})
	_changed()
	return true


func unequip(slot: String) -> void:
	Game.data.equipped[slot] = -1
	_changed()


## Equips the highest-power item in every slot.
func auto_equip() -> int:
	var changes := 0
	for slot in Content.slots:
		var best := -1
		var best_p := -1.0
		for key in items():
			var it: Dictionary = items()[key]
			if Content.item(it.def).slot != slot:
				continue
			var p := ItemRules.power(it)
			if p > best_p:
				best_p = p
				best = int(it.uid)
		if best >= 0 and equipped_uid(slot) != best:
			Game.data.equipped[slot] = best
			changes += 1
	if changes > 0:
		EventBus.emit_game(GameEvents.ITEM_EQUIPPED, changes)
		_changed()
	return changes


func toggle_favorite(uid: int) -> void:
	var it := get_item(uid)
	if it.is_empty():
		return
	it.favorite = not bool(it.favorite)
	_changed()


## Filter: {"slot": "", "rarity": ""}; sort: "rarity" | "level" | "power" | "slot".
func list(filter: Dictionary = {}, sort_by: String = "rarity") -> Array:
	var out: Array = []
	for key in items():
		var it: Dictionary = items()[key]
		var def: Dictionary = Content.item(it.def)
		if filter.get("slot", "") != "" and def.slot != filter.slot:
			continue
		if filter.get("rarity", "") != "" and it.rarity != filter.rarity:
			continue
		out.append(it)
	out.sort_custom(func(a, b): return _compare(a, b, sort_by))
	return out


func _compare(a: Dictionary, b: Dictionary, sort_by: String) -> bool:
	var ra := Content.rarity_index(a.rarity)
	var rb := Content.rarity_index(b.rarity)
	match sort_by:
		"level":
			if a.level != b.level: return a.level > b.level
		"power":
			var pa := ItemRules.power(a)
			var pb := ItemRules.power(b)
			if pa != pb: return pa > pb
		"slot":
			var sa := Content.slots.find(Content.item(a.def).slot)
			var sb := Content.slots.find(Content.item(b.def).slot)
			if sa != sb: return sa < sb
	if ra != rb:
		return ra > rb
	if a.level != b.level:
		return a.level > b.level
	return int(a.uid) < int(b.uid)


# ---------------------------------------------------------------- workshop

func upgrade(uid: int) -> Dictionary:
	var it := get_item(uid)
	if it.is_empty():
		return {"ok": false, "error": "workshop.err_missing"}
	if not ItemRules.can_upgrade(it):
		return {"ok": false, "error": "workshop.err_max_level"}
	var cost := ItemRules.upgrade_cost(it)
	if not Economy.transact(cost, {}, "upgrade:%d" % uid, false):
		return {"ok": false, "error": "store.err_funds"}
	it.level = int(it.level) + 1
	it.invested = int(it.invested) + int(cost.get("scrap", 0))
	_history("upgrade", {"def": it.def, "level": it.level})
	EventBus.emit_game(GameEvents.EQUIPMENT_UPGRADED, 1.0, {"uid": uid})
	_changed(true)
	return {"ok": true, "cost": cost}


func reset_upgrade(uid: int) -> Dictionary:
	var it := get_item(uid)
	if it.is_empty() or int(it.level) <= 1:
		return {"ok": false, "error": "workshop.err_nothing_to_reset"}
	var refund := ItemRules.reset_refund(it)
	it.level = 1
	it.invested = 0
	Economy.transact({}, {"scrap": refund}, "reset:%d" % uid, false)
	_history("reset", {"def": it.def, "refund": refund})
	_changed(true)
	return {"ok": true, "refund": refund}


func fuse(uids: Array) -> Dictionary:
	var list_items: Array = []
	for u in uids:
		var it := get_item(int(u))
		if it.is_empty():
			return {"ok": false, "error": "workshop.err_missing"}
		list_items.append(it)
	var err := ItemRules.can_fuse(list_items)
	if err != "":
		return {"ok": false, "error": err}
	# The result reuses the first item's uid, so it may be equipped/favorite;
	# the other inputs must be unprotected.
	for i in range(1, list_items.size()):
		if is_protected(int(list_items[i].uid)):
			return {"ok": false, "error": "fuse.err_protected"}
	var target: Dictionary = list_items[0]
	var refund := 0
	var top_level := int(target.level)
	for i in range(1, list_items.size()):
		var other: Dictionary = list_items[i]
		top_level = maxi(top_level, int(other.level))
		refund += int(other.invested)
		items().erase(str(other.uid))
	target.rarity = Content.next_rarity(target.rarity)
	target.level = mini(top_level, ItemRules.max_level(target.rarity))
	if refund > 0:
		Economy.transact({}, {"scrap": refund}, "fuse_refund", false)
	_history("fuse", {"def": target.def, "rarity": target.rarity})
	EventBus.emit_game(GameEvents.EQUIPMENT_FUSED, 1.0, {"rarity": target.rarity})
	_changed(true)
	return {"ok": true, "uid": int(target.uid), "refund": refund}


## Groups fusable unprotected items; returns planned groups without applying.
func plan_batch_fuse() -> Array:
	var groups: Dictionary = {}
	for key in items():
		var it: Dictionary = items()[key]
		if Content.next_rarity(it.rarity) == "":
			continue
		var k: String = it.def + "|" + it.rarity
		if not groups.has(k):
			groups[k] = []
		groups[k].append(it)
	var plan: Array = []
	var n := ItemRules.fusion_required()
	for k in groups:
		var g: Array = groups[k]
		# Protected items can only be the fusion target (first slot).
		g.sort_custom(func(a, b): return int(is_protected(int(a.uid))) > int(is_protected(int(b.uid))))
		var free: Array = g.filter(func(it): return not is_protected(int(it.uid)))
		var targets: Array = g.filter(func(it): return is_protected(int(it.uid)))
		while true:
			if targets.size() > 0 and free.size() >= n - 1:
				var grp := [targets.pop_front()]
				for i in n - 1:
					grp.append(free.pop_front())
				plan.append(grp.map(func(it): return int(it.uid)))
			elif free.size() >= n:
				var grp2: Array = []
				for i in n:
					grp2.append(free.pop_front())
				plan.append(grp2.map(func(it): return int(it.uid)))
			else:
				break
	return plan


func batch_fuse() -> int:
	var count := 0
	for grp in plan_batch_fuse():
		if fuse(grp).ok:
			count += 1
	return count


func recycle_preview(uids: Array) -> Dictionary:
	var total := 0
	var blocked := 0
	for u in uids:
		if is_protected(int(u)):
			blocked += 1
		else:
			total += ItemRules.recycle_value(get_item(int(u)))
	return {"scrap": total, "blocked": blocked}


func recycle(uids: Array) -> Dictionary:
	var preview := recycle_preview(uids)
	var removed := 0
	for u in uids:
		if is_protected(int(u)):
			continue
		var it := get_item(int(u))
		if it.is_empty():
			continue
		_history("recycle", {"def": it.def, "rarity": it.rarity})
		items().erase(str(u))
		removed += 1
	if removed == 0:
		return {"ok": false, "error": "recycle.err_none"}
	Economy.transact({}, {"scrap": preview.scrap}, "recycle", false)
	EventBus.emit_game(GameEvents.EQUIPMENT_RECYCLED, removed)
	_changed(true)
	return {"ok": true, "scrap": preview.scrap, "count": removed}


## Combined modifiers of all equipped items, consumed by the combat StatBlock.
func equipped_modifiers() -> Array:
	var out: Array = []
	for slot in Content.slots:
		var it := get_item(equipped_uid(slot))
		if not it.is_empty():
			out.append_array(ItemRules.modifiers(it))
	return out


## True if some unequipped item beats the equipped one in its slot (badge).
func has_better_item() -> bool:
	for slot in Content.slots:
		var cur := get_item(equipped_uid(slot))
		var cur_p := ItemRules.power(cur) if not cur.is_empty() else -1.0
		for key in items():
			var it: Dictionary = items()[key]
			if Content.item(it.def).slot == slot and ItemRules.power(it) > cur_p + 0.001:
				return true
	return false


func history() -> Array:
	return Game.data.workshop_history


func _history(op: String, info: Dictionary) -> void:
	var h: Array = Game.data.workshop_history
	info["op"] = op
	info["t"] = TimeService.now()
	h.append(info)
	while h.size() > int(Content.economy_value("workshop_history_size", 30)):
		h.pop_front()


func _changed(important: bool = false) -> void:
	changed.emit()
	EventBus.inventory_changed.emit()
	EventBus.notifications_changed.emit()
	if important:
		Saves.save_now()
	else:
		Game.save_soon()
