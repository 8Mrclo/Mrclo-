extends Node
## MissionManager (autoload "Missions").
## Map/mode unlocks, RunConfig assembly (map + mode rules + daily modifiers)
## and recording of results (stars, first clear, records).


func progress(map_id: String) -> Dictionary:
	var p: Dictionary = Game.data.missions.progress
	if not p.has(map_id):
		p[map_id] = {"cleared": false, "stars": [false, false, false], "best_time": 0, "clears": 0, "attempts": 0}
	return p[map_id]


func is_cleared(map_id: String) -> bool:
	return Game.data.missions.progress.has(map_id) and bool(progress(map_id).cleared)


func is_map_unlocked(map_id: String) -> bool:
	var sector := int(Content.map_def(map_id).get("sector", 1))
	if sector <= 1:
		return true
	for id in Content.map_order:
		if int(Content.map_def(id).sector) == sector - 1:
			return is_cleared(id)
	return false


func highest_sector() -> int:
	var best := 1
	for id in Content.map_order:
		if is_cleared(id):
			best = maxi(best, int(Content.map_def(id).sector) + 1)
	return mini(best, Content.map_order.size())


func star_count(map_id: String) -> int:
	var n := 0
	for s in progress(map_id).stars:
		if s:
			n += 1
	return n


func total_stars() -> int:
	var n := 0
	for id in Content.map_order:
		if Game.data.missions.progress.has(id):
			n += star_count(id)
	return n


func mode_unlock_status(mode_id: String) -> Dictionary:
	var u: Dictionary = Content.mode(mode_id).get("unlock", {})
	match u.get("type", "default"):
		"mission":
			var m: Dictionary = Content.map_def(u.value)
			return {"ok": is_cleared(u.value), "key": "mode.unlock_mission", "params": {"map": Loc.text(m.get("name", ""))}}
		"account_level":
			return {"ok": int(Game.data.profile.account_level) >= int(u.value), "key": "mode.unlock_level", "params": {"n": int(u.value)}}
	return {"ok": true, "key": "", "params": {}}


func daily_modifiers(day: String = "") -> Array:
	if day == "":
		day = TimeService.day_key()
	var pool: Array = Content.daily_modifiers.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = RandomService.seed_from_key("dailysim:" + day)
	RandomService.shuffle_with(rng, pool)
	var count := int(Content.mode("daily_sim").get("rules", {}).get("modifier_count", 2))
	return pool.slice(0, mini(count, pool.size()))


func daily_map(day: String = "") -> String:
	if day == "":
		day = TimeService.day_key()
	var unlocked: Array = Content.map_order.filter(func(id): return is_map_unlocked(id))
	var rng := RandomNumberGenerator.new()
	rng.seed = RandomService.seed_from_key("dailymap:" + day)
	return unlocked[rng.randi_range(0, unlocked.size() - 1)]


## Returns "" if the run may start, else a localization key.
func can_start(map_id: String, mode_id: String) -> String:
	if not is_map_unlocked(map_id):
		return "mission.err_locked"
	if not mode_unlock_status(mode_id).ok:
		return "mission.err_mode_locked"
	if not Economy.can_afford(Content.mode(mode_id).get("cost", {})):
		return "store.err_funds"
	return ""


func build_run_config(map_id: String, mode_id: String, difficulty: String = "normal", seed_value: int = 0) -> Dictionary:
	var m: Dictionary = Content.map_def(map_id)
	var rules: Dictionary = Content.mode(mode_id).get("rules", {})
	var diff: Dictionary = Content.balance_value("difficulty." + difficulty, {})
	var cfg := {
		"map": map_id, "mode": mode_id, "difficulty": difficulty, "seed": seed_value,
		"agent": Agents.selected(),
		"duration": float(rules.get("duration", m.get("duration", 600))),
		"boss": "" if rules.get("no_boss", false) else str(m.get("boss", "")),
		"boss_time": float(rules.get("boss_time", m.get("boss_time", 540))),
		"waves": m.get("waves", []),
		"min_alive": m.get("min_alive", []),
		"events": [] if mode_id in ["hunt", "defense"] else m.get("events", []),
		"hazards": m.get("hazards", []),
		"budget_mult": float(rules.get("budget_mult", 1.0)) * float(diff.get("budget", 1.0)),
		"hp_mult": float(rules.get("hp_mult", 1.0)) * float(diff.get("hp", 1.0)) * float(m.get("scaling", {}).get("hp", 1.0)),
		"damage_mult": float(diff.get("damage", 1.0)) * float(m.get("scaling", {}).get("damage", 1.0)),
		"enemy_speed_mult": 1.0,
		"elite_interval": float(rules.get("elite_interval", 0)),
		"device_hp": float(rules.get("device_hp", 0)),
		"device_target_chance": float(rules.get("device_target_chance", 0)),
		"victory_on_timer": bool(rules.get("victory_on_timer", false)),
		"reward_mult": float(diff.get("reward", 1.0)),
		"player_mods": [],
		"modifiers": [],
	}
	if mode_id == "hunt":
		cfg.events = [{"t": 30, "type": "elite", "enemy": Content.elite_ids[0]}]
	if mode_id == "daily_sim":
		for mod in daily_modifiers():
			cfg.modifiers.append(mod.id)
			cfg.player_mods.append_array(mod.get("player_mods", []))
			cfg.enemy_speed_mult *= float(mod.get("enemy_speed", 1.0))
			cfg.hp_mult *= float(mod.get("enemy_hp", 1.0))
			cfg.budget_mult *= float(mod.get("budget", 1.0))
			cfg.damage_mult *= float(mod.get("enemy_damage", 1.0))
			cfg.reward_mult *= float(mod.get("reward", 1.0))
			if mod.has("elite_interval"):
				cfg.elite_interval = float(mod.elite_interval)
		if Game.data.missions.daily_sim_claimed == TimeService.day_key():
			cfg.reward_mult *= 0.25
	return cfg


## Pays the mode cost and stores the config for the Battle scene.
func start(map_id: String, mode_id: String, difficulty: String = "normal", seed_value: int = 0) -> String:
	var err := can_start(map_id, mode_id)
	if err != "":
		return err
	var cost: Dictionary = Content.mode(mode_id).get("cost", {})
	if not cost.is_empty() and not Economy.transact(cost, {}, "mode:" + mode_id):
		return "store.err_funds"
	Game.data.missions.selected_map = map_id
	Game.data.missions.selected_mode = mode_id
	progress(map_id).attempts = int(progress(map_id).attempts) + 1
	Game.pending_run = build_run_config(map_id, mode_id, difficulty, seed_value)
	EventBus.emit_game(GameEvents.MISSION_STARTED, 1.0, {"map": map_id, "mode": mode_id})
	Analytics.log_event("mission_start", {"map": map_id, "mode": mode_id})
	Game.save_soon()
	return ""


## Evaluates the 3 optional objectives of a map for a result.
static func evaluate_objectives(map_def: Dictionary, result: Dictionary) -> Array:
	var out: Array = []
	for o in map_def.get("objectives", []):
		var ok := false
		match o.type:
			"kills": ok = int(result.get("kills", 0)) >= int(o.target)
			"elite_kills": ok = int(result.get("elite_kills", 0)) >= int(o.target)
			"finish_hp_pct": ok = result.get("victory", false) and float(result.get("hp_pct", 0.0)) >= float(o.target)
			"reach_level": ok = int(result.get("level", 1)) >= int(o.target)
			"evolutions": ok = int(result.get("evolutions", 0)) >= int(o.target)
			"max_damage_taken": ok = result.get("victory", false) and float(result.get("damage_taken", 0.0)) <= float(o.target)
		out.append(ok)
	return out


## Records a finished run. Returns {"first_clear", "new_stars": [idx], "unique_rewards": {}}.
func record_result(result: Dictionary) -> Dictionary:
	var map_id: String = result.map
	var mode_id: String = result.get("mode", "expedition")
	var p := progress(map_id)
	var m: Dictionary = Content.map_def(map_id)
	var out := {"first_clear": false, "new_stars": [], "unique": []}
	var rec: Dictionary = Game.data.records
	rec.runs = int(rec.runs) + 1
	rec.best_time = maxf(float(rec.best_time), float(result.time))
	rec.best_kills = maxi(int(rec.best_kills), int(result.kills))
	rec.best_level = maxi(int(rec.best_level), int(result.level))
	if mode_id == "expedition":
		var objs := evaluate_objectives(m, result)
		for i in objs.size():
			if objs[i] and not p.stars[i]:
				p.stars[i] = true
				out.new_stars.append(i)
				var star_rewards: Array = m.get("rewards", {}).get("stars", [])
				if i < star_rewards.size():
					out.unique.append(Rewards.grant(star_rewards[i], "star", "star:%s:%d" % [map_id, i]))
		if out.new_stars.size() > 0:
			EventBus.emit_game(GameEvents.STARS_EARNED, out.new_stars.size())
		if result.victory:
			p.best_time = maxf(float(p.best_time), float(result.time))
			if not p.cleared:
				p.cleared = true
				out.first_clear = true
				out.unique.append(Rewards.grant(m.get("rewards", {}).get("first_clear", {}), "first_clear", "first_clear:" + map_id))
	if result.victory:
		p.clears = int(p.clears) + 1
		EventBus.emit_game(GameEvents.MISSION_COMPLETED, 1.0, {"map": map_id, "mode": mode_id})
	else:
		EventBus.emit_game(GameEvents.MISSION_FAILED, 1.0, {"map": map_id, "mode": mode_id})
	if mode_id == "daily_sim" and Game.data.missions.daily_sim_claimed != TimeService.day_key():
		Game.data.missions.daily_sim_claimed = TimeService.day_key()
	Saves.save_now()
	return out
