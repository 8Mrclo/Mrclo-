class_name AgentTraits
extends RefCounted
## Exclusive agent abilities ("traits") implemented as hooks the battle calls.

var battle: Battle
var trait_id := ""
var params: Dictionary = {}
var _timer := 0.0


func _init(b: Battle, agent_id: String) -> void:
	battle = b
	trait_id = str(Content.agent(agent_id).get("trait", {}).get("id", ""))
	params = Agents.trait_params(agent_id)
	_timer = float(params.get("interval", 0.0))
	if trait_id == "iron_bulwark":
		battle.player.shield = true


func update(delta: float) -> void:
	match trait_id:
		"tide_collector":
			_timer -= delta
			if _timer <= 0.0:
				_timer = float(params.get("interval", 18.0))
				battle.pickups.magnet_all()
				battle.fx.ring(battle.player.position, 300.0, 0.5, Palette.TEAL)
		"iron_bulwark":
			if not battle.player.shield:
				_timer -= delta
				if _timer <= 0.0:
					_timer = float(params.get("interval", 12.0))
					battle.player.shield = true


func on_player_damaged() -> void:
	if trait_id == "phase_step":
		battle.player.speed_bonus = float(params.get("bonus", 0.45))
		battle.player.speed_bonus_t = float(params.get("seconds", 1.4))


func on_crit(e: Enemy, amount: float) -> void:
	if trait_id != "prism_focus" or battle.rng.randf() > float(params.get("chance", 0.22)):
		return
	for k in 2:
		var dir := Vector2.from_angle(battle.rng.randf() * TAU)
		var p := battle.projectiles.fire(e.position, dir, 560.0, amount * float(params.get("shard_pct", 0.35)), 6.0, Projectile.Kind.SHARD, Palette.VIOLET.lightened(0.3), -1, 0, 0.45)
		if p:
			p.hits.append(e.uid)


func damage_mult(flags: int) -> float:
	match trait_id:
		"drone_link":
			if flags & Battle.FLAG_DEVICE:
				return 1.0 + float(params.get("bonus", 0.2))
		"edge_of_tide":
			if battle.player.hp_ratio() < float(params.get("threshold", 0.4)):
				return 1.0 + float(params.get("damage", 0.3))
	return 1.0


func regen_mult() -> float:
	if trait_id == "edge_of_tide" and battle.player.hp_ratio() < float(params.get("threshold", 0.4)):
		return float(params.get("regen_mult", 2.0))
	return 1.0
