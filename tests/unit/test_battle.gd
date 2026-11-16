extends TestCase
## Integration tests: run the real Battle scene headless for a short time.

const SIM := preload("res://tests/scenes/battle_simulation.gd")


func _run(map_id: String, mode_id: String, seconds: float, setup: Callable = Callable()) -> Dictionary:
	var sim: Node = SIM.new()
	sim.standalone = false
	sim.map_id = map_id
	sim.mode_id = mode_id
	sim.seconds = seconds
	sim.invincible = true
	sim.pre_battle = setup
	(Engine.get_main_loop() as SceneTree).root.add_child(sim)
	var r: Dictionary = sim.run()
	sim.queue_free()
	return r


func test_short_run_is_stable() -> void:
	var r := _run("submerged_avenue", "expedition", 45.0)
	check(r.kills > 0, "inimigos neutralizados")
	check(r.level > 1, "subiu de nível")


func test_every_boss_runs_all_phases() -> void:
	for boss_id in Content.boss_ids:
		var r := _run("submerged_avenue", "expedition", 40.0, func(cfg: Dictionary):
			cfg.boss = boss_id
			cfg.boss_time = 1.0
			cfg.events = [])
		check(r.boss_seen, "%s surgiu" % boss_id)


func test_defense_mode_runs() -> void:
	var r := _run("antenna_garden", "defense", 20.0)
	check(r.time >= 19.0, "modo defesa executa")


func test_all_maps_load() -> void:
	for id in Content.map_order:
		var r := _run(id, "expedition", 5.0)
		check(r.time >= 4.9, "%s carregou" % id)
