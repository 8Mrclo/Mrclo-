class_name ItemRules
extends RefCounted
## Pure equipment math: stats by rarity/level, upgrade costs, fusion and
## recycling values. Inventory applies these rules to persisted data.


static func max_level(rarity_id: String) -> int:
	return int(Content.rarity(rarity_id).get("max_level", 10))


static func stat_mult(rarity_id: String) -> float:
	return float(Content.rarity(rarity_id).get("stat_mult", 1.0))


static func main_value(item: Dictionary) -> float:
	var def: Dictionary = Content.item(item.def)
	var m: Dictionary = def.get("main", {})
	return (float(m.get("base", 0)) + float(m.get("per_level", 0)) * (int(item.level) - 1)) * stat_mult(item.rarity)


## Full modifier list contributed by an item: main + secondary + unlocked rarity effects.
static func modifiers(item: Dictionary) -> Array:
	var def: Dictionary = Content.item(item.def)
	if def.is_empty():
		return []
	var out: Array = []
	var m: Dictionary = def.main
	out.append({"stat": m.stat, "op": m.op, "value": main_value(item), "source": "item"})
	for s in def.get("secondary", []):
		if float(s.value) != 0.0:
			out.append({"stat": s.stat, "op": s.op, "value": float(s.value) * stat_mult(item.rarity), "source": "item"})
	var ri := Content.rarity_index(item.rarity)
	for e in def.get("rarity_effects", []):
		if ri >= Content.rarity_index(e.rarity):
			out.append({"stat": e.stat, "op": e.op, "value": float(e.value), "source": "item"})
	return out


## Single comparable number for sorting/auto-equip.
static func power(item: Dictionary) -> float:
	var p := 0.0
	for mod in modifiers(item):
		var w := 100.0
		match mod.stat:
			"max_hp": w = 1.0
			"armor": w = 3.0
			"regen": w = 30.0
			"projectile_count", "pierce": w = 25.0
		p += absf(float(mod.value)) * w
	return p * (1.0 + Content.rarity_index(item.rarity) * 0.1)


static func upgrade_cost(item: Dictionary) -> Dictionary:
	var cfg: Dictionary = Content.equipment_meta.get("upgrade", {})
	var lvl := int(item.level)
	var scrap := int(round(float(cfg.get("scrap_base", 30)) * pow(1.0 + lvl, float(cfg.get("scrap_power", 1.35))) * float(Content.rarity(item.rarity).get("cost_mult", 1.0))))
	var cost := {"scrap": scrap}
	var every := int(cfg.get("data_every", 10))
	if every > 0 and lvl % every == every - 1:
		cost["field_data"] = int(cfg.get("data_amount", 5)) * (1 + lvl / every)
	return cost


static func can_upgrade(item: Dictionary) -> bool:
	return int(item.level) < max_level(item.rarity)


static func reset_refund(item: Dictionary) -> int:
	return int(floor(float(item.get("invested", 0)) * float(Content.equipment_meta.get("upgrade", {}).get("reset_refund", 0.8))))


static func recycle_value(item: Dictionary) -> int:
	var base := int(Content.rarity(item.rarity).get("recycle_scrap", 40))
	var refund := float(Content.equipment_meta.get("upgrade", {}).get("recycle_refund", 0.8))
	return base + int(floor(float(item.get("invested", 0)) * refund))


static func fusion_required() -> int:
	return int(Content.equipment_meta.get("fusion", {}).get("required", 3))


## Fusion rule: N items with the same definition and rarity -> one item of
## the next rarity. Level kept = highest among inputs (clamped).
static func can_fuse(items: Array) -> String:
	if items.size() != fusion_required():
		return "fuse.err_count"
	var first: Dictionary = items[0]
	for it in items:
		if it.def != first.def or it.rarity != first.rarity:
			return "fuse.err_mismatch"
	if Content.next_rarity(first.rarity) == "":
		return "fuse.err_max"
	return ""
