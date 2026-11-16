extends Node
## AgentManager (autoload "Agents").
## Unlock conditions, permanent levels (scrap + own shards), milestones and
## the combat modifiers an agent contributes.


func state(id: String) -> Dictionary:
	return Game.data.agents.get(id, {"unlocked": false, "level": 1})


func is_unlocked(id: String) -> bool:
	return bool(state(id).get("unlocked", false))


func level(id: String) -> int:
	return int(state(id).get("level", 1))


func selected() -> String:
	return Game.data.selected_agent


func select(id: String) -> bool:
	if not is_unlocked(id):
		return false
	Game.data.selected_agent = id
	Game.save_soon()
	EventBus.profile_changed.emit()
	return true


func shards(id: String) -> int:
	return Economy.balance("shard_" + id)


## Returns {"can": bool, "reason_key": String, "params": Dictionary, "cost": Dictionary}
func unlock_status(id: String) -> Dictionary:
	var u: Dictionary = Content.agent(id).get("unlock", {})
	match u.get("type", "default"):
		"default":
			return {"can": true, "reason_key": "", "params": {}, "cost": {}}
		"shards":
			var cost := {"shard_" + id: int(u.amount)}
			return {"can": Economy.can_afford(cost), "reason_key": "agent.unlock_shards", "params": {"n": int(u.amount)}, "cost": cost}
		"account_level":
			return {"can": int(Game.data.profile.account_level) >= int(u.value), "reason_key": "agent.unlock_level", "params": {"n": int(u.value)}, "cost": {}}
		"mission":
			var m: Dictionary = Content.map_def(u.value)
			return {"can": Missions.is_cleared(u.value), "reason_key": "agent.unlock_mission", "params": {"map": Loc.text(m.get("name", u.value))}, "cost": {}}
	return {"can": false, "reason_key": "agent.locked", "params": {}, "cost": {}}


func unlock(id: String) -> bool:
	if is_unlocked(id):
		return false
	var st := unlock_status(id)
	if not st.can:
		return false
	if not st.cost.is_empty() and not Economy.transact(st.cost, {}, "unlock:" + id, false):
		return false
	Game.data.agents[id] = {"unlocked": true, "level": level(id)}
	EventBus.emit_game(GameEvents.AGENT_UNLOCKED, 1.0, {"agent": id})
	Analytics.log_event("agent_unlocked", {"id": id})
	Saves.save_now()
	EventBus.notifications_changed.emit()
	return true


func level_cost(id: String) -> Dictionary:
	var lc: Dictionary = Content.agent_level_costs
	var lvl := level(id)
	return {
		"scrap": int(round(float(lc.get("scrap_base", 120)) * pow(float(lc.get("scrap_growth", 1.32)), lvl - 1))),
		"shard_" + id: int(lc.get("shards_base", 4)) + int(lc.get("shards_step", 2)) * (lvl - 1),
	}


func max_level(id: String) -> int:
	return int(Content.agent(id).get("max_level", 20))


func can_level(id: String) -> bool:
	return is_unlocked(id) and level(id) < max_level(id) and Economy.can_afford(level_cost(id))


func level_up(id: String) -> bool:
	if not can_level(id):
		return false
	if not Economy.transact(level_cost(id), {}, "agent_level:" + id, false):
		return false
	Game.data.agents[id].level = level(id) + 1
	EventBus.emit_game(GameEvents.AGENT_LEVELED, 1.0, {"agent": id, "level": level(id)})
	Saves.save_now()
	EventBus.notifications_changed.emit()
	return true


## Stat modifiers: base + per-level + reached milestones.
func modifiers(id: String, lvl: int = -1) -> Array:
	var a: Dictionary = Content.agent(id)
	if lvl < 0:
		lvl = level(id)
	var out: Array = []
	for m in a.get("base_mods", []):
		out.append(m)
	for m in a.get("per_level_mods", []):
		var scaled: Dictionary = m.duplicate()
		scaled.value = float(m.value) * (lvl - 1)
		if scaled.value != 0.0:
			out.append(scaled)
	for ms in a.get("milestones", []):
		if lvl >= int(ms.level):
			out.append_array(ms.get("mods", []))
	return out


## Trait params with milestone overrides applied.
func trait_params(id: String, lvl: int = -1) -> Dictionary:
	var a: Dictionary = Content.agent(id)
	if lvl < 0:
		lvl = level(id)
	var p: Dictionary = a.get("trait", {}).get("params", {}).duplicate()
	for ms in a.get("milestones", []):
		if lvl >= int(ms.level):
			p.merge(ms.get("trait_params", {}), true)
	return p


func actionable_count() -> int:
	var n := 0
	for id in Content.agent_order:
		if (not is_unlocked(id) and unlock_status(id).can) or can_level(id):
			n += 1
	return n
