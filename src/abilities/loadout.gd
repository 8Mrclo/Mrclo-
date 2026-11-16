class_name Loadout
extends RefCounted
## In-run build: active ability runtimes (slot-indexed) and passive levels.

var battle: Battle
var actives: Dictionary = {}      # active_id -> AbilityRuntime (key stays base id after evolving)
var active_levels: Dictionary = {}
var passives: Dictionary = {}     # passive_id -> level
var evolved: Dictionary = {}      # active_id -> evo_id
var _next_slot := 0
var picks := 0


func _init(b: Battle) -> void:
	battle = b


func state() -> Dictionary:
	return {
		"actives": active_levels, "passives": passives, "evolved": evolved,
		"max_actives": int(Content.balance_value("run.max_actives", 6)),
		"max_passives": int(Content.balance_value("run.max_passives", 6)),
		"luck": battle.player.stats.get_stat("luck"),
	}


func apply(offer: Dictionary) -> void:
	picks += 1
	match offer.kind:
		"active":
			add_active(offer.id)
		"passive":
			add_passive(offer.id)
		"evolution":
			evolve(offer.from, offer.id)
		"fallback":
			if offer.id == "repair_kit":
				battle.player.heal(battle.player.max_hp * float(Content.balance_value("run.fallback_heal_pct", 0.3)))
			else:
				battle.bonus_scrap += int(Content.balance_value("run.fallback_scrap", 40))
	EventBus.emit_game(GameEvents.ABILITY_SELECTED, 1.0, {"id": offer.id, "kind": offer.kind})


func add_active(id: String) -> void:
	if actives.has(id):
		active_levels[id] = mini(int(active_levels[id]) + 1, UpgradeOffer.MAX_LEVEL)
		actives[id].set_level(active_levels[id])
		return
	var rt := AbilityFactory.create(battle, Content.active(id), _next_slot % Enemy.HIT_SLOTS)
	if rt == null:
		return
	_next_slot += 1
	actives[id] = rt
	active_levels[id] = 1
	Game.discover("abilities", id)


func add_passive(id: String) -> void:
	var lvl := mini(int(passives.get(id, 0)) + 1, UpgradeOffer.MAX_LEVEL)
	passives[id] = lvl
	var d: Dictionary = Content.passive(id)
	var src := "passive:" + id
	battle.player.stats.remove_source(src)
	battle.player.stats.add({"stat": d.stat, "op": d.op, "value": float(d["values"][lvl - 1]), "source": src})
	if d.has("extra"):
		battle.player.stats.add({"stat": d.extra.stat, "op": d.extra.op, "value": float(d.extra["values"][lvl - 1]), "source": src})
	Game.discover("abilities", id)


func evolve(active_id: String, evo_id: String) -> void:
	var old: AbilityRuntime = actives.get(active_id)
	if old == null:
		return
	var slot := old.slot
	old.remove()
	var rt := AbilityFactory.create(battle, Content.evolution(evo_id), slot)
	actives[active_id] = rt
	evolved[active_id] = evo_id
	battle.evolutions += 1
	battle.fx.ring(battle.player.position, 260.0, 0.6, Palette.AMBER)
	battle.announce(Loc.t("battle.evolved", {"name": Loc.text(Content.evolution(evo_id).name)}))
	Audio.play(&"evolve")
	Game.discover("abilities", evo_id)
	EventBus.emit_game(GameEvents.EVOLUTION_FORMED, 1.0, {"id": evo_id})


func update(delta: float) -> void:
	for id in actives:
		actives[id].update(delta)


## For HUD: [{id, def, level, evolved}]
func summary() -> Array:
	var out: Array = []
	for id in actives:
		var evo: String = evolved.get(id, "")
		out.append({"id": evo if evo != "" else id, "def": Content.upgrade_def(evo if evo != "" else id), "level": active_levels[id], "evolved": evo != "", "kind": "active"})
	for id in passives:
		out.append({"id": id, "def": Content.passive(id), "level": passives[id], "evolved": false, "kind": "passive"})
	return out
