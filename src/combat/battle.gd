class_name Battle
extends Node2D
## Battle scene root. Builds every subsystem in code, runs them in a fixed
## order each frame and owns the cross-cutting rules: damage, kills, XP,
## level-ups, revive, victory/defeat and reward hand-off.
##
## Update order: player -> director -> enemies -> abilities -> projectiles ->
## pickups -> hazards -> boss -> fx -> compaction -> end checks -> HUD.

const FLAG_DEVICE := 1
const FLAG_NO_CRIT := 2
const FLAG_NO_FX := 4

var cfg: Dictionary = {}
var map_def: Dictionary = {}
var limits: Dictionary = {}
var rng: RandomNumberGenerator
var seed_used := 0

var pools: ObjectPoolManager
var arena: Arena
var hazards: HazardSystem
var player: Player
var camera: CameraRig
var enemies: EnemySystem
var projectiles: ProjectileSystem
var fx: FxSystem
var numbers: DamageNumbers
var pickups: PickupSystem
var director: SpawnDirector
var loadout: Loadout
var traits: AgentTraits
var boss_ctrl: BossController
var hud: BattleHud
var level_panel: LevelUpPanel
var pause_panel: PausePanel
var ability_layer: Node2D
var device: Node2D
var device_radius := 46.0
var device_hp := 0.0
var device_max_hp := 0.0

var time := 0.0
var frame := 0
var kills := 0
var elite_kills := 0
var boss_kills := 0
var damage_dealt := 0.0
var level := 1
var xp := 0.0
var xp_needed := 10.0
var pending_picks := 0
var bonus_scrap := 0
var evolutions := 0
var rerolls := 1
var locks := 0
var locked_offer: Dictionary = {}
var revives_left := 0
var prism_revive_used := false
var finished := false
var speed_mult := 1.0
var speed_unlocked := false
var aim_mode := "nearest"
var _victory_at := -1.0
var test_mode := false   # set by headless tests: no scene change on finish
var _min_damage := 1.0
var _num_window := 0.18
var _contact_tick := 0.35
var _moved := false
var _first_kill := false
var _xp_curve: Dictionary = {}
var _drop_chance: Dictionary = {}
var _heal_drop_mult := 1.0


func _ready() -> void:
	add_to_group("battle")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	cfg = Game.pending_run if not Game.pending_run.is_empty() else Missions.build_run_config("submerged_avenue", "expedition")
	map_def = Content.map_def(cfg.map)
	limits = Settings.graphics_limits()
	seed_used = Rng.seed_run(DebugTools.forced_seed if DebugTools.forced_seed > 0 else int(cfg.get("seed", 0)))
	rng = Rng.stream(&"run")
	_read_balance()
	_build_world()
	_build_player()
	_build_systems()
	_build_ui()
	loadout.add_active(Content.agent(player.agent_id).start_ability)
	if cfg.has("lab"):
		BattleLab.apply(self, str(cfg.lab))
	Audio.play_music("battle")
	Audio.set_duck(false)
	Tutorial.notify_context("battle_start")


func _read_balance() -> void:
	var run: Dictionary = Content.balance_value("run", {})
	_min_damage = float(run.get("min_damage_taken", 1))
	_contact_tick = float(run.get("contact_tick", 0.35))
	_xp_curve = run.get("xp_curve", {})
	_drop_chance = run.get("drop_chance", {})
	_num_window = float(Content.balance_value("damage_numbers.aggregate_window", 0.18))
	rerolls = int(run.get("base_rerolls", 1)) + int(Research.meta_value("reroll"))
	locks = int(run.get("base_locks", 0)) + int(Research.meta_value("lock"))
	revives_left = int(Research.meta_value("revive"))
	_heal_drop_mult = 1.0 + Research.meta_value("heal_drop_mult")
	speed_unlocked = Research.meta_value("speed_unlock") > 0.0 or int(Game.data.profile.account_level) >= int(Content.economy_value("speed_unlock_account_level", 5))
	speed_mult = float(Settings.get_value("battle_speed")) if speed_unlocked else 1.0
	aim_mode = str(Settings.get_value("aim_mode"))
	xp_needed = xp_for_level(1)


func _build_world() -> void:
	pools = ObjectPoolManager.new()
	add_child(pools)
	arena = Arena.new()
	add_child(arena)
	arena.setup(map_def, float(limits.get("decor_density", 1.0)))
	hazards = HazardSystem.new()
	add_child(hazards)
	var pickup_layer := _layer(0)
	var enemy_layer := _layer(1)
	ability_layer = _layer(2)
	var proj_layer := _layer(4)
	var fx_layer := _layer(6)
	numbers = DamageNumbers.new()
	add_child(numbers)
	numbers.setup(int(limits.get("damage_numbers", 24)))
	var proj_limit := int(limits.get("projectiles", 360))
	pools.register(EnemySystem.POOL, func(): return Enemy.new(), enemy_layer, 120, int(limits.get("enemies", 380)) + 12)
	pools.register(ProjectileSystem.POOL, func(): return Projectile.new(), proj_layer, 100, proj_limit)
	pools.register(ProjectileSystem.HOSTILE_POOL, func(): return Projectile.new(), proj_layer, 30, int(limits.get("hostile_projectiles", 140)))
	pools.register(FxSystem.POOL, func(): return FxNode.new(), fx_layer, 30, int(limits.get("fx", 110)))
	pools.register(FxSystem.TELE_POOL, func(): return FxNode.new(), fx_layer, 12, 80)
	pools.register(PickupSystem.POOL, func(): return Pickup.new(), pickup_layer, 120, int(Content.balance_value("run.max_xp_pickups", 260)) + 80)
	if float(cfg.get("device_hp", 0.0)) > 0.0:
		device = Node2D.new()
		device.z_index = 1
		device_max_hp = float(cfg.device_hp)
		device_hp = device_max_hp
		device.draw.connect(_draw_device)
		add_child(device)


func _layer(z: int) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	add_child(n)
	return n


func _build_player() -> void:
	player = Player.new()
	add_child(player)
	var mods: Array = []
	mods.append_array(Agents.modifiers(cfg.agent))
	mods.append_array(Inventory.equipped_modifiers())
	mods.append_array(Research.modifiers())
	mods.append_array(cfg.get("player_mods", []))
	var inv := float(Content.balance_value("run.invuln_seconds", 0.55)) + Research.meta_value("invuln_bonus")
	player.setup(cfg.agent, mods, float(Content.balance_value("run.player_radius", 18)), inv)
	player.position = Vector2(0, 120) if device else Vector2.ZERO
	player.died.connect(_on_player_died)
	camera = CameraRig.new()
	add_child(camera)
	camera.setup(player, arena.bounds)
	camera.make_current()


func _build_systems() -> void:
	enemies = EnemySystem.new(self)
	projectiles = ProjectileSystem.new(self)
	fx = FxSystem.new(self)
	pickups = PickupSystem.new(self)
	hazards.setup(self, cfg.get("hazards", []))
	director = SpawnDirector.new(self)
	loadout = Loadout.new(self)
	traits = AgentTraits.new(self, cfg.agent)


func _build_ui() -> void:
	hud = BattleHud.new()
	add_child(hud)
	hud.setup(self)
	level_panel = LevelUpPanel.new()
	add_child(level_panel)
	level_panel.setup(self)
	pause_panel = PausePanel.new()
	add_child(pause_panel)
	pause_panel.setup(self)


# ---------------------------------------------------------------- frame

func _process(raw_delta: float) -> void:
	if finished:
		return
	var delta := minf(raw_delta, 0.05) * speed_mult
	frame += 1
	time += delta
	var input := hud.move_input()
	if not _moved and input.length() > 0.2:
		_moved = true
		Tutorial.complete("move")
	player.update(delta, input, arena, hazards.player_slow, traits.regen_mult())
	if not cfg.get("no_director", false):
		director.update(delta)
	if cfg.has("lab"):
		BattleLab.tick(self, delta)
	enemies.update(delta, frame)
	loadout.update(delta)
	projectiles.update(delta)
	pickups.update(delta)
	hazards.update(delta)
	arena.update(delta)
	traits.update(delta)
	if boss_ctrl:
		boss_ctrl.update(delta)
		if time > float(cfg.duration):
			boss_ctrl.enrage = 1.5
	fx.update(delta)
	numbers.update(delta)
	camera.update(delta)
	enemies.compact()
	_check_end()
	hud.refresh(delta)
	if pending_picks > 0 and not level_panel.is_open() and not finished and not player.dead:
		level_panel.open()


func _check_end() -> void:
	if _victory_at > 0.0 and time >= _victory_at:
		finish(true)
		return
	if bool(cfg.get("victory_on_timer", false)) and time >= float(cfg.duration):
		finish(true)
	elif cfg.get("boss", "") == "" and not bool(cfg.get("victory_on_timer", false)) and time >= float(cfg.duration):
		finish(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not finished and not level_panel.is_open():
		pause_panel.open()
	elif event.is_action_pressed("toggle_metrics"):
		Settings.set_value("show_metrics", not bool(Settings.get_value("show_metrics")))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not finished and not level_panel.is_open() and pause_panel:
			pause_panel.open()


# ---------------------------------------------------------------- targeting

func find_target(origin: Vector2, max_range: float, mode: String = "") -> Enemy:
	if mode == "":
		mode = aim_mode
	if mode == "movement":
		var ahead := enemies.nearest(origin + player.move_dir * max_range * 0.5, max_range * 0.6)
		return ahead if ahead else enemies.nearest(origin, max_range)
	if mode == "nearest":
		return enemies.nearest(origin, max_range)
	var best: Enemy = null
	var best_score := -INF
	var r2 := max_range * max_range
	for j in enemies.query(origin, max_range):
		var e: Enemy = enemies.active[j]
		if not e.alive or e.hidden_boss:
			continue
		var d2 := (e.position - origin).length_squared()
		if d2 > r2:
			continue
		var score := 0.0
		if mode == "lowest_hp":
			score = -e.hp
		else:
			score = (1000.0 if e.is_boss else 0.0) + (500.0 if e.is_elite else 0.0) + e.threat * 10.0 + e.damage - sqrt(d2) * 0.05
		if score > best_score:
			best_score = score
			best = e
	return best


func view_rect() -> Rect2:
	var size := get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size * 0.5, size)


# ---------------------------------------------------------------- damage

func damage_enemy(e: Enemy, base: float, slot: int, knock_dir: Vector2 = Vector2.ZERO, knock_force: float = 0.0, flags: int = 0) -> float:
	if not e.alive or e.invuln_t > 0.0 or e.hidden_boss:
		return 0.0
	var st := player.stats
	var resist := e.resist + (e.buff_resist if e.buff_t > 0.0 else 0.0)
	var crit_chance := 0.0 if flags & FLAG_NO_CRIT else st.get_stat("crit_chance")
	var res := DamageCalculator.outgoing(base, st.get_stat("damage"), traits.damage_mult(flags), crit_chance, st.get_stat("crit_mult"), resist, rng.randf())
	var amount: float = res.amount
	e.hp -= amount
	damage_dealt += amount
	if not flags & FLAG_NO_FX:
		e.flash_t = 0.08
		Audio.play(&"crit" if res.crit else &"hit")
	if knock_force > 0.0 and knock_dir != Vector2.ZERO:
		var resist_knock := 0.15 if e.is_boss else 1.0
		e.knock += knock_dir * knock_force * st.get_stat("knockback") / maxf(e.mass, 0.5) * resist_knock
	if numbers.enabled:
		e.dmg_accum += amount
		if res.crit:
			e.dmg_crit = true
		if e.dmg_timer <= 0.0:
			e.dmg_timer = _num_window
	if res.crit:
		traits.on_crit(e, amount)
	if e.is_elite:
		e.queue_redraw()
	if e.hp <= 0.0:
		kill_enemy(e, true)
	return amount


func area_damage(pos: Vector2, r: float, dmg: float, slot: int, knock: float, flags: int) -> int:
	var hits := 0
	for j in enemies.query(pos, r):
		var e: Enemy = enemies.active[j]
		if not e.alive:
			continue
		var d := e.position - pos
		if d.length_squared() < (r + e.radius) ** 2:
			damage_enemy(e, dmg, slot, d.normalized(), knock, flags)
			hits += 1
	return hits


func kill_enemy(e: Enemy, with_drops: bool) -> void:
	if not e.alive:
		return
	e.alive = false
	if e.dmg_accum > 0.0:
		numbers.emit_number(e.position, e.dmg_accum, e.dmg_crit)
	if e.is_boss:
		_on_boss_killed(e, with_drops)
	if not with_drops:
		return
	kills += 1
	if not _first_kill:
		_first_kill = true
		Tutorial.notify_context("first_kill")
	pickups.spawn_xp(e.position, e.xp_value)
	_roll_drops(e)
	if e.is_elite:
		elite_kills += 1
		pickups.spawn(Pickup.Kind.CACHE, e.position)
		EventBus.emit_game(GameEvents.ELITE_DEFEATED, 1.0, {"id": e.enemy_id})
		EventBus.enemy_killed.emit(StringName(e.enemy_id), true, false, e.position)
		shake(0.3)
	if e.behavior == Enemy.Behavior.SPLITTER:
		var params: Dictionary = e.def.get("params", {})
		for k in int(params.get("split_count", 2)):
			var child := enemies.spawn(params.get("split_into", "neon_slimelet"), e.position + Vector2.from_angle(TAU * k / 2.0 + rng.randf()) * e.radius)
			if child:
				child.spawn_t = 0.05
	fx.burst(e.position, e.body_color, e.radius * 0.4)
	Audio.play(&"kill")


func _roll_drops(e: Enemy) -> void:
	var luck := player.stats.get_stat("luck")
	var roll := rng.randf()
	var heal_c := float(_drop_chance.get("heal", 0.004)) * luck * _heal_drop_mult
	var mag_c := float(_drop_chance.get("magnet", 0.002)) * luck
	var bomb_c := float(_drop_chance.get("pulse_bomb", 0.0015)) * luck
	if roll < heal_c:
		pickups.spawn(Pickup.Kind.HEAL, e.position)
	elif roll < heal_c + mag_c:
		pickups.spawn(Pickup.Kind.MAGNET, e.position)
	elif roll < heal_c + mag_c + bomb_c:
		pickups.spawn(Pickup.Kind.BOMB, e.position)


func damage_player(amount: float, src: Vector2, continuous: bool = false, delta: float = 0.0) -> void:
	if finished or player.dead or DebugTools.invincible:
		return
	var raw := amount * delta if continuous else amount
	var res := player.take_damage(raw, rng.randf(), _min_damage, continuous)
	if res.get("shield", false):
		fx.ring(player.position, 40.0, 0.3, Palette.AMBER)
		return
	if float(res.amount) <= 0.0 or continuous:
		return
	shake(0.25)
	Audio.play(&"hurt")
	Settings.vibrate(40)
	traits.on_player_damaged()
	hud.flash_damage()
	EventBus.player_damaged.emit(res.amount)


func damage_device(amount: float) -> void:
	if device == null or finished:
		return
	device_hp -= amount
	device.queue_redraw()
	if device_hp <= 0.0:
		device_hp = 0.0
		announce(Loc.t("battle.device_lost"))
		finish(false)


func shake(v: float) -> void:
	camera.add_trauma(v)


func announce(text: String) -> void:
	hud.announce(text)


# ---------------------------------------------------------------- xp & picks

func xp_for_level(l: int) -> float:
	return float(_xp_curve.get("base", 6)) + float(_xp_curve.get("linear", 4.5)) * l + float(_xp_curve.get("power_mult", 1.6)) * pow(l, float(_xp_curve.get("power", 1.28)))


func gain_xp(v: float) -> void:
	xp += v * player.stats.get_stat("xp_gain")
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		xp_needed = xp_for_level(level)
		pending_picks += 1
		EventBus.player_leveled.emit(level)
		Audio.play(&"level_up")


func grant_bonus_pick() -> void:
	pending_picks += 1
	announce(Loc.t("battle.data_cache"))


func current_offers() -> Array:
	var count := int(Content.balance_value("run.offer_count", 3))
	var offers := UpgradeOffer.build(loadout.state(), rng, count, locked_offer)
	locked_offer = {}
	return offers


func choose_offer(offer: Dictionary) -> void:
	loadout.apply(offer)
	pending_picks = maxi(pending_picks - 1, 0)


func reroll() -> Array:
	if rerolls <= 0:
		return []
	rerolls -= 1
	return current_offers()


## Keeps an offer for the next level-up (consumes a lock charge).
func lock_offer(offer: Dictionary) -> bool:
	if locks <= 0 or offer.get("kind", "") == "fallback":
		return false
	locks -= 1
	locked_offer = offer
	return true


# ---------------------------------------------------------------- bosses

func on_elite_spawned(_e: Enemy) -> void:
	pass


func start_boss(b: Enemy, mid: bool) -> void:
	if boss_ctrl:
		boss_ctrl.queue_free()
	boss_ctrl = BossController.new()
	add_child(boss_ctrl)
	boss_ctrl.setup(self, b, mid)
	hud.show_boss(b)
	announce(Loc.t("battle.boss_incoming", {"name": Loc.text(b.def.name)}))
	Audio.play(&"boss")
	Audio.play_music("boss")
	Audio.set_duck(true)
	Tutorial.notify_context("battle_boss")
	EventBus.boss_spawned.emit(StringName(b.enemy_id))


func boss_active() -> bool:
	return boss_ctrl != null and is_instance_valid(boss_ctrl.boss) and boss_ctrl.boss.alive


func _on_boss_killed(e: Enemy, counted: bool) -> void:
	var mid := boss_ctrl != null and boss_ctrl.is_mid
	if boss_ctrl and boss_ctrl.boss == e:
		boss_ctrl.queue_free()
		boss_ctrl = null
	hud.hide_boss()
	Audio.play_music("battle")
	Audio.set_duck(false)
	projectiles.clear_hostile()
	if counted:
		boss_kills += 1
		EventBus.emit_game(GameEvents.BOSS_DEFEATED, 1.0, {"id": e.enemy_id})
		EventBus.boss_defeated.emit(StringName(e.enemy_id))
		for k in 6:
			pickups.spawn_xp(e.position + Vector2.from_angle(TAU * k / 6.0) * 40.0, e.xp_value / 6.0)
		pickups.magnet_all()
		shake(0.8)
	if not mid and not bool(cfg.get("victory_on_timer", false)):
		_victory_at = time + 1.5
		announce(Loc.t("battle.boss_down"))


# ---------------------------------------------------------------- death & end

func _on_player_died() -> void:
	if finished:
		return
	var prism_cost := int(Content.economy_value("revive_prism_cost", 30))
	var can_prism := not prism_revive_used and Economy.can_afford({"prisms": prism_cost})
	if revives_left > 0 or can_prism:
		pause_panel.open_revive(revives_left > 0, can_prism, prism_cost)
	else:
		finish(false)


func revive(use_prisms: bool) -> void:
	if use_prisms:
		if not Economy.spend({"prisms": int(Content.economy_value("revive_prism_cost", 30))}, "revive"):
			finish(false)
			return
		prism_revive_used = true
	else:
		revives_left -= 1
	player.revive(float(Content.balance_value("run.revive_hp_pct", 0.5)))
	var r := float(Content.balance_value("run.revive_clear_radius", 420))
	area_damage(player.position, r, 9999.0, -1, 400.0, FLAG_NO_CRIT)
	projectiles.clear_hostile()
	fx.ring(player.position, r, 0.6, Palette.MINT)


func build_result(victory: bool, abandoned: bool = false) -> Dictionary:
	var dur := float(cfg.duration)
	return {
		"map": cfg.map, "mode": cfg.mode, "difficulty": cfg.get("difficulty", "normal"), "agent": cfg.agent,
		"victory": victory, "abandoned": abandoned, "time": time, "kills": kills, "elite_kills": elite_kills,
		"boss_kills": boss_kills, "level": level, "hp_pct": player.hp_ratio(), "damage_taken": player.damage_taken,
		"damage_dealt": damage_dealt, "evolutions": evolutions, "progress": clampf(time / maxf(dur, 1.0), 0.0, 1.0),
		"bonus_scrap": bonus_scrap, "reward_mult": float(cfg.get("reward_mult", 1.0)), "crate_key_roll": rng.randf(),
		"picks": loadout.picks, "seed": seed_used, "build": loadout.summary().map(func(s): return {"id": s.id, "level": s.level, "kind": s.kind}),
		"pickups": pickups.collected_count, "modifiers": cfg.get("modifiers", []),
	}


func finish(victory: bool, abandoned: bool = false) -> void:
	if finished:
		return
	finished = true
	get_tree().paused = false
	var result := build_result(victory, abandoned)
	var record := Missions.record_result(result)
	var rewards := Rewards.compute_run_rewards(result)
	var summary := Rewards.grant(rewards, "run")
	EventBus.emit_game(GameEvents.ENEMY_DEFEATED, kills)
	EventBus.emit_game(GameEvents.DAMAGE_DEALT, damage_dealt)
	EventBus.emit_game(GameEvents.DAMAGE_TAKEN, player.damage_taken)
	EventBus.emit_game(GameEvents.SURVIVE_SECONDS, time)
	EventBus.emit_game(GameEvents.RUN_LEVEL_REACHED, level)
	if pickups.collected_count > 1:
		EventBus.emit_game(GameEvents.PICKUP_COLLECTED, pickups.collected_count - 1)
	Analytics.log_event("mission_end", {"map": cfg.map, "mode": cfg.mode, "victory": victory, "time": int(time), "kills": kills, "level": level})
	Game.last_result = result
	Game.last_rewards = {"run": summary, "record": record}
	Game.pending_run = {}
	Saves.save_now()
	Audio.set_duck(false)
	if not test_mode:
		Router.goto("battle_result")


# ---------------------------------------------------------------- device

func _draw_device() -> void:
	var r := device_radius
	device.draw_circle(Vector2(0, 8), r, Color(0, 0, 0, 0.3))
	IconPainter.draw(device, "hexagon", Vector2.ZERO, r, Palette.TEAL)
	device.draw_circle(Vector2.ZERO, r * 0.35, Palette.AMBER)
	var w := r * 2.4
	device.draw_rect(Rect2(-w / 2, -r - 18, w, 8), Color(0, 0, 0, 0.6))
	device.draw_rect(Rect2(-w / 2, -r - 18, w * device_hp / maxf(device_max_hp, 1.0), 8), Palette.MINT)


# ---------------------------------------------------------------- debug hooks

func debug_spawn_boss() -> void:
	if cfg.boss == "":
		cfg.boss = "abyssal_digger"
	director.spawn_boss()


func debug_level_up() -> void:
	gain_xp(xp_needed - xp + 0.01)


func debug_clear_enemies() -> void:
	enemies.clear_all(false)


func debug_finish(victory: bool) -> void:
	finish(victory)
