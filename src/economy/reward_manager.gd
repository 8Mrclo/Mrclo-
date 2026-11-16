extends Node
## RewardManager (autoload "Rewards").
## Converts reward descriptors into wallet/inventory changes.
## A non-empty unique_key makes a grant idempotent (first clear, achievements,
## daily objectives...) — the key is persisted in data.claimed_keys.
##
## Descriptor keys: <currency>: int, "account_xp": int, "random_shards": int,
## "item": {"def"?: id, "rarity": id}, "items": [ {..}, .. ].


func is_claimed(unique_key: String) -> bool:
	return unique_key != "" and Game.data.claimed_keys.has(unique_key)


## Returns a summary {"currencies": {}, "items": [uid], "account_xp": int, "duplicate": bool}.
func grant(rewards: Dictionary, source: String, unique_key: String = "") -> Dictionary:
	var summary := {"currencies": {}, "items": [], "account_xp": 0, "duplicate": false}
	if is_claimed(unique_key):
		summary.duplicate = true
		return summary
	var gains := {}
	var rng := Rng.stream(&"loot")
	for key in rewards:
		var v: Variant = rewards[key]
		match key:
			"account_xp":
				summary.account_xp += int(v)
			"random_shards":
				var ids: Array[String] = Content.agent_order.duplicate()
				var agent_id: String = ids[rng.randi_range(0, ids.size() - 1)]
				var k := "shard_" + agent_id
				gains[k] = int(gains.get(k, 0)) + int(v)
			"item":
				summary.items.append(_grant_item(v, rng, source))
			"items":
				for entry in v:
					summary.items.append(_grant_item(entry, rng, source))
			_:
				if v is int or v is float:
					gains[key] = int(gains.get(key, 0)) + int(v)
	if unique_key != "":
		Game.data.claimed_keys[unique_key] = TimeService.now()
	if not gains.is_empty():
		Economy.transact({}, gains, source, false)
	summary.currencies = gains
	if summary.account_xp > 0:
		Game.add_account_xp(summary.account_xp)
	Game.save_soon()
	return summary


func _grant_item(entry: Dictionary, rng: RandomNumberGenerator, source: String) -> int:
	var def_id: String = entry.get("def", "")
	if def_id == "" or Content.item(def_id).is_empty():
		def_id = Content.item_order[rng.randi_range(0, Content.item_order.size() - 1)]
	var rarity_id: String = entry.get("rarity", "common")
	if Content.rarity(rarity_id).is_empty():
		rarity_id = "common"
	return Inventory.add_item(def_id, rarity_id, source)


## Pure computation of run rewards from a battle result. No side effects.
func compute_run_rewards(result: Dictionary) -> Dictionary:
	var map_def: Dictionary = Content.map_def(result.get("map", ""))
	var mode_def: Dictionary = Content.mode(result.get("mode", "expedition"))
	var r: Dictionary = map_def.get("rewards", {})
	var out := {}
	var victory: bool = result.get("victory", false)
	var minutes := float(result.get("time", 0.0)) / 60.0
	for c in r.get("per_minute", {}):
		out[c] = int(out.get(c, 0)) + int(floor(float(r.per_minute[c]) * minutes))
	var econ: Dictionary = Content.economy_value("run_rewards", {})
	out["scrap"] = int(out.get("scrap", 0)) + int(float(result.get("kills", 0)) * float(econ.get("scrap_per_kill", 0.3)))
	out["scrap"] += int(result.get("elite_kills", 0)) * int(econ.get("scrap_per_elite", 40))
	out["account_xp"] = int(out.get("account_xp", 0)) + int(result.get("level", 1)) * int(econ.get("account_xp_per_level", 3))
	if victory:
		for c in r.get("clear", {}):
			out[c] = int(out.get(c, 0)) + int(r.clear[c])
		for c in mode_def.get("rules", {}).get("bonus", {}):
			out[c] = int(out.get(c, 0)) + int(mode_def.rules.bonus[c])
	else:
		var ratio := float(r.get("fail_ratio", 0.45))
		for c in r.get("clear", {}):
			out[c] = int(out.get(c, 0)) + int(floor(float(r.clear[c]) * ratio * clampf(float(result.get("progress", 0.0)), 0.0, 1.0)))
	var mult := float(mode_def.get("rules", {}).get("reward_mult", 1.0)) * float(result.get("reward_mult", 1.0))
	mult *= 1.0 + Research.meta_value("scrap_bonus")
	for c in out:
		out[c] = maxi(int(round(float(out[c]) * (mult if c == "scrap" else float(mode_def.get("rules", {}).get("reward_mult", 1.0))))), 0)
	out["scrap"] = int(out.get("scrap", 0)) + int(result.get("bonus_scrap", 0))
	if int(result.get("boss_kills", 0)) > 0 and result.get("crate_key_roll", 1.0) < float(econ.get("crate_key_on_boss_chance", 0.0)):
		out["crate_key"] = int(out.get("crate_key", 0)) + 1
	for k in out.keys():
		if int(out[k]) <= 0:
			out.erase(k)
	return out


# ---------------------------------------------------------------- offline

func offline_preview() -> Dictionary:
	var cfg: Dictionary = Content.economy_value("offline", {})
	var bonus := {"cap_hours": Research.meta_value("offline_cap_hours"), "rate": Research.meta_value("offline_rate")}
	return OfflineRewardCalculator.compute(int(Game.data.offline.last_claim), TimeService.now(), int(Game.data.profile.max_seen), cfg, Missions.highest_sector(), bonus)


func claim_offline() -> Dictionary:
	var p := offline_preview()
	Game.data.offline.anomaly = p.anomaly
	if p.anomaly:
		# Anchor to the highest time ever seen: rolling the clock back and forth
		# can never re-earn the same window (the anchor only ratchets forward).
		Game.data.offline.last_claim = maxi(int(Game.data.profile.max_seen), int(Game.data.offline.last_claim))
		Game.save_soon()
		return p
	if p.rewards.is_empty():
		return p
	Game.data.offline.last_claim = TimeService.now()
	Game.touch_clock()
	grant(p.rewards, "offline")
	Saves.save_now()
	return p
