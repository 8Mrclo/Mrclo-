class_name PickupSystem
extends RefCounted
## XP fragments and drops. XP fragments over the cap merge into existing ones
## (value is preserved, entity count is bounded).

const POOL := &"pickup"

var battle: Battle
var items: Array[Pickup] = []
var max_xp := 260
var _xp_count := 0
var _magnet_all := false
var _pull_speed := 900.0
var _tiers: Array = []
var collected_count := 0


func _init(b: Battle) -> void:
	battle = b
	max_xp = int(Content.balance_value("run.max_xp_pickups", 260))
	_pull_speed = float(Content.balance_value("run.magnet_pull_speed", 900))
	_tiers = Content.drops.get("xp_tiers", [])


func spawn_xp(pos: Vector2, value: float) -> void:
	if _xp_count >= max_xp:
		# Merge into a random existing fragment instead of spawning.
		for k in 4:
			var it := items[battle.rng.randi_range(0, items.size() - 1)]
			if it.kind == Pickup.Kind.XP and it.active:
				it.value += value
				_style_xp(it)
				return
	var p := _spawn(Pickup.Kind.XP, pos)
	if p:
		p.value = value
		_style_xp(p)
		_xp_count += 1


func _style_xp(p: Pickup) -> void:
	for t in _tiers:
		if p.value >= float(t.min):
			p.color = JsonUtil.color(t.color, Palette.MINT)
			p.size = float(t.size)
	p.queue_redraw()


func spawn(kind: int, pos: Vector2) -> Pickup:
	return _spawn(kind, pos)


func _spawn(kind: int, pos: Vector2) -> Pickup:
	var p: Pickup = battle.pools.acquire(POOL)
	if p == null:
		return null
	p.kind = kind
	p.position = pos + Vector2(battle.rng.randf_range(-8, 8), battle.rng.randf_range(-8, 8))
	p.active = true
	p.magnetized = false
	p.speed = 0.0
	p.value = 1.0
	p.queue_redraw()
	items.append(p)
	return p


func magnet_all() -> void:
	for it in items:
		if it.kind == Pickup.Kind.XP:
			it.magnetized = true


func update(delta: float) -> void:
	var ppos: Vector2 = battle.player.position
	var pick_r: float = battle.player.stats.get_stat("pickup")
	var pick_r2 := pick_r * pick_r
	var collect_r2 := (battle.player.radius + 10.0) ** 2
	var i := 0
	while i < items.size():
		var it := items[i]
		var to := ppos - it.position
		var d2 := to.length_squared()
		if not it.magnetized and d2 < pick_r2:
			it.magnetized = true
		if it.magnetized:
			it.speed = minf(it.speed + _pull_speed * 2.5 * delta, _pull_speed)
			it.position += to.normalized() * it.speed * delta
			d2 = (ppos - it.position).length_squared()
		if d2 < collect_r2:
			_collect(it)
			items[i] = items[items.size() - 1]
			items.pop_back()
			battle.pools.release(it)
			continue
		i += 1


func _collect(it: Pickup) -> void:
	it.active = false
	collected_count += 1
	match it.kind:
		Pickup.Kind.XP:
			_xp_count -= 1
			battle.gain_xp(it.value)
			Audio.play(&"pickup")
			if collected_count == 1:
				EventBus.emit_game(GameEvents.PICKUP_COLLECTED, 1.0)
		Pickup.Kind.HEAL:
			battle.player.heal(battle.player.max_hp * 0.3)
		Pickup.Kind.MAGNET:
			magnet_all()
		Pickup.Kind.BOMB:
			battle.area_damage(battle.player.position, 520.0, 60.0 + battle.time * 0.3, -1, 300.0, Battle.FLAG_NO_CRIT)
			battle.fx.ring(battle.player.position, 520.0, 0.5, Palette.CORAL)
			battle.shake(0.5)
		Pickup.Kind.CACHE:
			battle.grant_bonus_pick()
	if it.kind != Pickup.Kind.XP:
		Audio.play(&"reward")


func count() -> int:
	return items.size()
