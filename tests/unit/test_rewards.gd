extends TestCase


func test_unique_reward_granted_once() -> void:
	var before := Economy.balance("prisms")
	Rewards.grant({"prisms": 50}, "t", "unique:test")
	var s := Rewards.grant({"prisms": 50}, "t", "unique:test")
	check(s.duplicate, "segunda concessão marcada como duplicada")
	eq(Economy.balance("prisms"), before + 50, "apenas uma vez")


func test_grant_item_and_random_shards() -> void:
	var count := Inventory.items().size()
	var s := Rewards.grant({"item": {"rarity": "advanced"}, "random_shards": 5}, "t")
	eq(Inventory.items().size(), count + 1, "item concedido")
	var shard_total := 0
	for c in s.currencies:
		if str(c).begins_with("shard_"):
			shard_total += int(s.currencies[c])
	eq(shard_total, 5, "fragmentos aleatórios")


func test_crate_pity_guarantee() -> void:
	var crate := {"odds": [["common", 1.0]], "pity_threshold": 10, "pity_min_rarity": "singular"}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var pity := 0
	var results: Array = []
	for i in 10:
		var r := CrateRoller.roll(crate, pity, rng)
		pity = r.pity_after
		results.append(r)
	eq(results[8].rarity, "common", "antes da garantia")
	eq(results[9].rarity, "singular", "10ª abertura garantida")
	check(results[9].guaranteed, "marcada como garantia")
	eq(pity, 0, "contador reinicia")


func test_crate_log_recorded() -> void:
	Store.open_crate("supply_capsule")
	eq(Game.data.store.crate_log.size(), 1, "resultado registrado")


func test_offline_reward_cap_and_minimum() -> void:
	var cfg := {"cap_hours": 2, "scrap_per_minute_per_sector": 1.0, "data_per_hour_per_sector": 1.0, "min_minutes": 5, "max_clock_skew_seconds": 300}
	var r := OfflineRewardCalculator.compute(0, 10 * 3600, 10 * 3600, cfg, 1)
	eq(r.seconds, 7200, "limitado a 2h")
	check(r.capped, "marcado como limitado")
	eq(r.rewards.scrap, 120, "120 min × 1")
	var short := OfflineRewardCalculator.compute(0, 60, 60, cfg, 1)
	check(short.rewards.is_empty(), "abaixo do mínimo não rende")


func test_offline_clock_rollback() -> void:
	var cfg := {"cap_hours": 8, "max_clock_skew_seconds": 300}
	var r := OfflineRewardCalculator.compute(100000, 50000, 100000, cfg, 3)
	check(r.anomaly, "relógio voltou: anomalia")
	check(r.rewards.is_empty(), "sem recompensa")
	eq(r.seconds, 0, "nunca negativo")


func test_offline_claim_cannot_repeat() -> void:
	TimeService.override_unix = 1000000
	Game.data.offline.last_claim = 1000000 - 4 * 3600
	Game.data.profile.max_seen = 1000000
	var first := Rewards.claim_offline()
	check(not first.rewards.is_empty(), "primeira coleta rende")
	var second := Rewards.claim_offline()
	check(second.rewards.is_empty(), "coleta imediata não rende de novo")
	TimeService.override_unix = 1000000 - 7200
	var rolled := Rewards.claim_offline()
	check(rolled.anomaly, "volta do relógio detectada")
	TimeService.override_unix = 1000000 + 60
	var after := Rewards.claim_offline()
	check(after.rewards.is_empty(), "não recupera janela após manipulação")
	TimeService.override_unix = -1


func test_run_rewards_victory_vs_defeat() -> void:
	var base := {"map": "submerged_avenue", "mode": "expedition", "time": 600.0, "kills": 1000, "elite_kills": 3, "level": 30, "progress": 1.0, "boss_kills": 1, "crate_key_roll": 0.99}
	var win := base.duplicate()
	win["victory"] = true
	var lose := base.duplicate()
	lose["victory"] = false
	lose["progress"] = 0.5
	var rw := Rewards.compute_run_rewards(win)
	var rl := Rewards.compute_run_rewards(lose)
	check(int(rw.scrap) > int(rl.scrap), "vitória rende mais")
	check(int(rw.get("field_data", 0)) > 0, "dados de campo na vitória")
	for k in rl:
		check(int(rl[k]) > 0, "sem valores zerados/negativos")
