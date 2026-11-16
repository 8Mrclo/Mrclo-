class_name UpgradeOffer
extends RefCounted
## Pure level-up offer generation (testable without a Battle).
## state = {"actives": {id: lvl}, "passives": {id: lvl}, "evolved": {active_id: evo_id},
##          "max_actives": int, "max_passives": int, "luck": float}
## Rules:
##  1. Ready evolutions (active at 5 + required passive owned) come first.
##  2. Never offer a maxed item, an evolved active, or the same id twice.
##  3. New items only if a slot is free; owned items get luck-weighted priority.
##  4. If not enough valid options, fill with fallbacks (repair / scrap cache),
##     so there is always at least one useful choice.

const MAX_LEVEL := 5


static func ready_evolutions(state: Dictionary) -> Array:
	var out: Array = []
	for active_id in state.actives:
		if state.evolved.has(active_id) or int(state.actives[active_id]) < MAX_LEVEL:
			continue
		var evo_id: String = Content.evolution_by_active.get(active_id, "")
		if evo_id == "":
			continue
		if int(state.passives.get(Content.evolution(evo_id).requires, 0)) > 0:
			out.append({"kind": "evolution", "id": evo_id, "from": active_id})
	return out


static func candidates(state: Dictionary) -> Array:
	var out: Array = []
	var luck := float(state.get("luck", 1.0))
	for id in Content.active_order:
		var lvl := int(state.actives.get(id, 0))
		if state.evolved.has(id):
			continue
		if lvl == 0 and state.actives.size() >= int(state.max_actives):
			continue
		if lvl >= MAX_LEVEL:
			continue
		out.append({"kind": "active", "id": id, "level_from": lvl, "level_to": lvl + 1, "weight": (2.0 + luck * 0.5) if lvl > 0 else 1.0})
	for id in Content.passive_order:
		var lvl := int(state.passives.get(id, 0))
		if lvl == 0 and state.passives.size() >= int(state.max_passives):
			continue
		if lvl >= MAX_LEVEL:
			continue
		# Passives that complete a pending evolution get a boost.
		var boost := 1.0
		for aid in state.actives:
			var evo_id: String = Content.evolution_by_active.get(aid, "")
			if evo_id != "" and Content.evolution(evo_id).requires == id and not state.evolved.has(aid):
				boost = 1.8
		out.append({"kind": "passive", "id": id, "level_from": lvl, "level_to": lvl + 1, "weight": ((1.6 + luck * 0.4) if lvl > 0 else 0.9) * boost})
	return out


static func build(state: Dictionary, rng: RandomNumberGenerator, count: int, locked: Dictionary = {}) -> Array:
	var offers: Array = []
	var used: Dictionary = {}
	if not locked.is_empty() and is_valid(state, locked):
		offers.append(locked)
		used[locked.id] = true
	for evo in ready_evolutions(state):
		if offers.size() >= count:
			break
		if not used.has(evo.id):
			offers.append(evo)
			used[evo.id] = true
	var pool := candidates(state).filter(func(c): return not used.has(c.id))
	while offers.size() < count and not pool.is_empty():
		var weights := PackedFloat32Array()
		for c in pool:
			weights.append(float(c.weight))
		var i := RandomService.weighted_index(rng, weights)
		offers.append(pool[i])
		used[pool[i].id] = true
		pool.remove_at(i)
	for fb in ["repair_kit", "scrap_cache"]:
		if offers.size() >= count:
			break
		if not used.has(fb):
			offers.append({"kind": "fallback", "id": fb})
	return offers


static func is_valid(state: Dictionary, offer: Dictionary) -> bool:
	match offer.get("kind", ""):
		"evolution":
			return ready_evolutions(state).any(func(e): return e.id == offer.id)
		"active", "passive":
			for c in candidates(state):
				if c.id == offer.id:
					return true
			return false
		"fallback":
			return true
	return false


## Human-readable "next effect" lines by diffing level parameters.
static func diff_lines(offer: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	match offer.kind:
		"active":
			var levels: Array = Content.active(offer.id).levels
			if int(offer.level_from) == 0:
				return lines
			var a: Dictionary = levels[int(offer.level_from) - 1]
			var b: Dictionary = levels[int(offer.level_to) - 1]
			for k in b:
				if a.get(k) != b[k]:
					lines.append("%s: %s → %s" % [Loc.t("param." + k), _fmt(a.get(k)), _fmt(b[k])])
		"passive":
			var d: Dictionary = Content.passive(offer.id)
			var from_v := 0.0 if int(offer.level_from) == 0 else float(d["values"][int(offer.level_from) - 1])
			var to_v := float(d["values"][int(offer.level_to) - 1])
			lines.append("%s: %s → %s" % [Loc.t("stat." + d.stat), StatFormat.mod_value(d.stat, d.op, from_v), StatFormat.mod_value(d.stat, d.op, to_v)])
	return lines


static func _fmt(v: Variant) -> String:
	if v is float and absf(v - round(v)) > 0.001:
		return "%.2f" % v
	return str(int(round(float(v))))
