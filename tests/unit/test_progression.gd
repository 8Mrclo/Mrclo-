extends TestCase


func test_agent_unlock_by_shards() -> void:
	check(not Agents.is_unlocked("breno"), "começa bloqueado")
	check(not Agents.unlock("breno"), "sem fragmentos não desbloqueia")
	Economy.earn({"shard_breno": 20}, "t")
	check(Agents.unlock("breno"), "desbloqueia com fragmentos")
	eq(Economy.balance("shard_breno"), 0, "fragmentos consumidos")
	check(not Agents.unlock("breno"), "não desbloqueia duas vezes")


func test_agent_level_and_milestones() -> void:
	Economy.earn({"scrap": 1000000, "shard_lia": 1000}, "t")
	var before := Agents.modifiers("lia").size()
	for i in 4:
		check(Agents.level_up("lia"), "nível %d" % (i + 2))
	eq(Agents.level("lia"), 5, "nível 5")
	check(Agents.modifiers("lia").size() > before, "marco do nível 5 adiciona modificador")
	eq(Agents.trait_params("lia", 10).interval, 13, "marco 10 altera habilidade exclusiva")


func test_agent_max_level() -> void:
	Economy.earn({"scrap": 99999999, "shard_lia": 99999}, "t")
	for i in 40:
		Agents.level_up("lia")
	eq(Agents.level("lia"), Agents.max_level("lia"), "limite de nível")


func test_research_dependencies() -> void:
	Economy.earn({"field_data": 100000, "scrap": 1000000}, "t")
	eq(Research.check("sv_plating"), "research.err_requires", "exige pré-requisito")
	eq(Research.buy("sv_hull_1"), "", "nó raiz")
	eq(Research.buy("sv_plating"), "", "agora liberado")
	eq(Research.check("sv_hull_2"), "research.err_requires", "exige ambos os pais")
	Research.buy("sv_regen")
	eq(Research.buy("sv_hull_2"), "", "ambos os pais comprados")


func test_research_max_rank_and_cost_growth() -> void:
	Economy.earn({"field_data": 100000, "scrap": 1000000}, "t")
	var c1: int = Research.cost("pw_edge_1").field_data
	Research.buy("pw_edge_1")
	var c2: int = Research.cost("pw_edge_1").field_data
	check(c2 > c1, "custo cresce por rank")
	Research.buy("pw_edge_1")
	Research.buy("pw_edge_1")
	eq(Research.check("pw_edge_1"), "research.err_max", "rank máximo")


func test_research_insufficient_funds() -> void:
	Economy.dev_set("field_data", 0)
	eq(Research.buy("sv_hull_1"), "store.err_funds", "saldo insuficiente")
	eq(Research.rank("sv_hull_1"), 0, "nada aplicado")


func test_research_meta_and_stat_mods() -> void:
	Economy.earn({"field_data": 100000, "scrap": 1000000}, "t")
	Research.buy("ex_xp_1")
	Research.buy("ex_reroll")
	eq(Research.meta_value("reroll"), 1.0, "meta rerrolagem")
	eq(Research.modifiers().size(), 1, "um modificador de atributo")


func test_objectives_progress_and_single_claim() -> void:
	Objectives.refresh_periods()
	var d: Dictionary = Objectives.defs("tutorial")[1]
	EventBus.emit_game(StringName(d.event), float(d.target))
	check(Objectives.can_claim("tutorial", d), "objetivo concluído")
	var s := Objectives.claim("tutorial", d.id)
	check(not s.is_empty(), "resgatado")
	check(Objectives.claim("tutorial", d.id).is_empty(), "não resgata duas vezes")


func test_daily_objectives_rotate_by_day() -> void:
	TimeService.override_unix = 1800000000
	Objectives.refresh_periods()
	var day1: Array = Game.data.objectives.daily.active.duplicate()
	eq(day1.size(), 5, "cinco diárias")
	TimeService.override_unix = 1800000000 + 86400
	Objectives.refresh_periods()
	check(Game.data.objectives.daily.period != "", "período atualizado")
	TimeService.override_unix = -1


func test_objective_filters() -> void:
	var def := {"id": "x", "event": "CurrencySpent", "target": 100, "filter": {"currency": "scrap"}}
	var e := {"progress": 0.0, "claimed": false}
	ObjectiveTracker.apply(def, e, &"CurrencySpent", 50, {"currency": "prisms"})
	eq(e.progress, 0.0, "filtro ignora outra moeda")
	ObjectiveTracker.apply(def, e, &"CurrencySpent", 500, {"currency": "scrap"})
	eq(e.progress, 100.0, "progresso limitado ao alvo")


func test_achievement_claim_once() -> void:
	EventBus.emit_game(GameEvents.ENEMY_DEFEATED, 100)
	var s := Achievements.claim("ach_enemydefeated_1")
	check(not s.is_empty(), "conquista resgatada")
	check(Achievements.claim("ach_enemydefeated_1").is_empty(), "uma vez só")
	check(Game.data.stats.EnemyDefeated >= 100, "contador vitalício")


func test_mission_complete_first_clear_once() -> void:
	var r := {"map": "submerged_avenue", "mode": "expedition", "victory": true, "time": 580.0, "kills": 1000, "elite_kills": 3, "level": 25, "hp_pct": 0.8, "damage_taken": 50.0, "evolutions": 1}
	var prisms := Economy.balance("prisms")
	var rec := Missions.record_result(r)
	check(rec.first_clear, "primeira conclusão")
	eq(rec.new_stars.size(), 3, "três estrelas")
	check(Missions.is_cleared("submerged_avenue"), "mapa concluído")
	check(Missions.is_map_unlocked("antenna_garden"), "próximo setor liberado")
	var mid := Economy.balance("prisms")
	check(mid > prisms, "recompensas únicas concedidas")
	var rec2 := Missions.record_result(r)
	check(not rec2.first_clear, "não repete primeira conclusão")
	eq(rec2.new_stars.size(), 0, "estrelas não repetem")
	eq(Economy.balance("prisms"), mid, "sem recompensa duplicada")


func test_mission_start_pays_mode_cost() -> void:
	Missions.progress("submerged_avenue").cleared = true
	var seals := Economy.balance("op_seals")
	eq(Missions.start("submerged_avenue", "rupture"), "", "inicia Ruptura")
	eq(Economy.balance("op_seals"), seals - 1, "selo cobrado")
	Economy.dev_set("op_seals", 0)
	eq(Missions.start("submerged_avenue", "rupture"), "store.err_funds", "sem selo bloqueia")
	Game.pending_run = {}


func test_account_level_up() -> void:
	var gained := Game.add_account_xp(100000)
	check(gained > 0, "sobe de nível")
	check(Game.data.profile.account_xp >= 0, "xp nunca negativa")
