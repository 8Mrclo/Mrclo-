class_name BattleLab
extends RefCounted
## Isolated battle test setups (debug only): abilities, enemies, bosses and
## performance. Activated through RunConfig "lab" from the Lab launcher.


static func config(kind: String, boss_id: String = "") -> Dictionary:
	var cfg := Missions.build_run_config("submerged_avenue", "expedition", "normal", 4242)
	cfg["lab"] = kind
	cfg.events = []
	cfg.duration = 900.0
	match kind:
		"abilities":
			cfg.waves = [{"from": 0, "to": 99999, "budget": 5.0, "pool": [["scrap_sniffer", 6], ["rust_hull", 2]]}]
			cfg.boss = ""
		"enemies":
			cfg.no_director = true
			cfg.boss = ""
		"boss":
			cfg.boss = boss_id if boss_id != "" else "abyssal_digger"
			cfg.boss_time = 2.0
			cfg.waves = [{"from": 0, "to": 99999, "budget": 0.8, "pool": [["scrap_sniffer", 1]]}]
		"perf":
			cfg.waves = [{"from": 0, "to": 99999, "budget": 60.0, "pool": [["scrap_sniffer", 6], ["glass_wasp", 3], ["rust_hull", 1]]}]
			cfg.min_alive = [[0, 450]]
			cfg.boss = ""
	return cfg


static func apply(b: Battle, kind: String) -> void:
	DebugTools.invincible = true
	match kind:
		"abilities":
			for id in Content.active_order.slice(0, 6):
				for i in 5:
					b.loadout.add_active(id)
			for evo_id in Content.evolutions:
				var evo := Content.evolution(evo_id)
				if b.loadout.actives.has(evo.from):
					b.loadout.add_passive(evo.requires)
					b.loadout.evolve(evo.from, evo_id)
		"perf":
			Settings.set_value("show_metrics", true)


static func tick(b: Battle, _delta: float) -> void:
	if str(b.cfg.lab) != "enemies":
		return
	# Every 8s spawn one of each enemy family around the player.
	if int(b.time / 8.0) != int((b.time - 0.0001) / 8.0) or b.frame == 2:
		var ids: Array = Content.enemy_order + Content.elite_ids
		for i in ids.size():
			var p := b.arena.clamp_inside(b.player.position + Vector2.from_angle(TAU * i / ids.size()) * 420.0, 40.0)
			b.enemies.spawn(ids[i], p)
