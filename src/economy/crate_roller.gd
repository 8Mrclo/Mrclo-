class_name CrateRoller
extends RefCounted
## Supply capsule roll with displayed odds and a configurable guarantee:
## after (pity_threshold - 1) rolls without reaching pity_min_rarity, the next
## roll is forced to at least that rarity. Fictional currency only.


static func roll(crate: Dictionary, pity_count: int, rng: RandomNumberGenerator) -> Dictionary:
	var odds: Array = crate.get("odds", [])
	var weights := PackedFloat32Array()
	for pair in odds:
		weights.append(float(pair[1]))
	var idx := RandomService.weighted_index(rng, weights)
	var rarity_id: String = odds[maxi(idx, 0)][0] if odds.size() > 0 else "common"
	var threshold := int(crate.get("pity_threshold", 0))
	var min_rarity: String = crate.get("pity_min_rarity", "")
	var guaranteed := false
	if threshold > 0 and pity_count + 1 >= threshold and Content.rarity_index(rarity_id) < Content.rarity_index(min_rarity):
		rarity_id = min_rarity
		guaranteed = true
	var reached := Content.rarity_index(rarity_id) >= Content.rarity_index(min_rarity)
	return {"rarity": rarity_id, "guaranteed": guaranteed, "pity_after": 0 if reached else pity_count + 1}
