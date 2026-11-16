extends Node
## Headless battle simulation used by tests and performance checks.
## Runs a full mission with scripted input, auto-picking the first offer.
## Usage: godot --headless --path . res://tests/scenes/battle_simulation.tscn -- [map] [mode] [seconds] [invincible]

signal finished(report: Dictionary)

var map_id := "submerged_avenue"
var mode_id := "expedition"
var seconds := 660.0
var invincible := true
var step := 1.0 / 30.0
var standalone := true
var report: Dictionary = {}
var battle_ref: Battle
var pre_battle: Callable


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: map_id = args[0]
	if args.size() > 1: mode_id = args[1]
	if args.size() > 2: seconds = float(args[2])
	if args.size() > 3: invincible = args[3] == "1"
	if standalone:
		run.call_deferred()


func run() -> Dictionary:
	Saves.enabled = false
	if standalone:
		Game.set_data(SaveDefaults.create())
		Game.on_new_profile()
	Settings.apply_all()
	InputSetup.ensure_actions()
	DebugTools.invincible = invincible
	if map_id.begins_with("lab:"):
		Game.pending_run = BattleLab.config(map_id.substr(4))
	else:
		Game.pending_run = Missions.build_run_config(map_id, mode_id, "normal", 1234)
	if pre_battle.is_valid():
		pre_battle.call(Game.pending_run)
	var battle: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	battle.set_process(false)
	battle.test_mode = not standalone
	battle_ref = battle
	add_child(battle)
	var t0 := Time.get_ticks_msec()
	var worst_ms := 0.0
	var total := 0.0
	var frames := 0
	var max_enemies := 0
	var evolutions_seen := 0
	var boss_seen := false
	var angle := 0.0
	var death_time := -1.0
	while total < seconds and not battle.finished:
		angle += step * 0.6
		battle.hud.joystick.output = _steer(battle, angle)
		var f0 := Time.get_ticks_usec()
		battle._process(step)
		worst_ms = maxf(worst_ms, (Time.get_ticks_usec() - f0) / 1000.0)
		if battle.player.dead and death_time < 0.0:
			death_time = battle.time
			if battle.pause_panel._open:
				battle.pause_panel.close()
				battle.finish(false)
			break
		while battle.level_panel.is_open():
			battle.level_panel._pick(_best_offer(battle.level_panel._offers))
		total += step
		frames += 1
		max_enemies = maxi(max_enemies, battle.enemies.count())
		boss_seen = boss_seen or battle.boss_ctrl != null
	report = {
		"finished": battle.finished, "victory": Game.last_result.get("victory", false), "time": battle.time,
		"kills": battle.kills, "level": battle.level, "evolutions": battle.evolutions, "boss_seen": boss_seen,
		"max_enemies": max_enemies, "avg_ms": float(Time.get_ticks_msec() - t0) / maxf(frames, 1), "worst_ms": worst_ms,
		"rewards": Game.last_rewards.get("run", {}).get("currencies", {}),
		"death_time": death_time, "hp": int(battle.player.hp), "damage_dealt": int(battle.damage_dealt), "boss_hp": int(battle.boss_ctrl.boss.hp) if battle.boss_ctrl else -1,
		"build": battle.loadout.summary().map(func(x): return "%s:%d" % [x.id, x.level]),
	}
	DebugTools.invincible = false
	if not battle.finished:
		battle.finished = true
	battle.queue_free()
	if standalone:
		print("SIMULAÇÃO: ", JSON.stringify(report))
		get_tree().quit(0 if report.finished else 1)
	finished.emit(report)
	return report


## Greedy policy: evolutions, then owned actives, then evolution-enabling passives.
func _best_offer(offers: Array) -> Dictionary:
	var best: Dictionary = offers[0]
	var best_score := -1.0
	for o in offers:
		var score := 0.0
		match o.kind:
			"evolution": score = 100.0
			"active": score = 20.0 + float(o.level_from) * 5.0 if int(o.level_from) > 0 else (30.0 if battle_ref.loadout.actives.size() < 4 else 12.0)
			"passive":
				score = 10.0 + float(o.level_from)
				for evo_id in Content.evolutions:
					if Content.evolution(evo_id).requires == o.id:
						score += 8.0
		if score > best_score:
			best_score = score
			best = o
	return best


## Simple evasive steering: flee from nearby enemies, orbit the arena center.
func _steer(b: Battle, angle: float) -> Vector2:
	var flee := Vector2.ZERO
	for j in b.enemies.query(b.player.position, 120.0):
		var e: Enemy = b.enemies.active[j]
		var d := b.player.position - e.position
		var l2 := maxf(d.length_squared(), 100.0)
		if l2 < (e.radius + 70.0) ** 2:
			flee += d / l2 * 300.0
	var seek := Vector2.ZERO
	var best := 450.0 * 450.0
	for it in b.pickups.items:
		var d2 := (it.position - b.player.position).length_squared()
		if d2 < best:
			best = d2
			seek = (it.position - b.player.position).normalized() * 0.7
	var home := (-b.player.position).limit_length(1.0) * 0.4 if b.player.position.length() > 900.0 else Vector2.ZERO
	var wander := Vector2.from_angle(angle) * 0.5
	if seek != Vector2.ZERO:
		wander *= 0.3
	return (flee + seek + home + wander).limit_length(1.0)
