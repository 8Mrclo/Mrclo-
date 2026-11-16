extends Node
## ContentDatabase (autoload "Content").
## Loads every JSON file under res://data once, indexes entries by id and
## validates cross references. Content is read-only at runtime.

const DATA_DIR := "res://data/"

var stats: Dictionary = {}          # id -> stat def
var balance: Dictionary = {}
var economy: Dictionary = {}
var agents: Dictionary = {}
var agent_order: Array[String] = []
var agent_level_costs: Dictionary = {}
var actives: Dictionary = {}
var active_order: Array[String] = []
var passives: Dictionary = {}
var passive_order: Array[String] = []
var evolutions: Dictionary = {}     # evo id -> def
var evolution_by_active: Dictionary = {}
var fallbacks: Dictionary = {}
var enemies: Dictionary = {}        # commons + elites + bosses
var enemy_order: Array[String] = []
var elite_ids: Array[String] = []
var boss_ids: Array[String] = []
var drops: Dictionary = {}
var maps: Dictionary = {}
var map_order: Array[String] = []
var modes: Dictionary = {}
var mode_order: Array[String] = []
var daily_modifiers: Array = []
var equipment: Dictionary = {}
var item_order: Array[String] = []
var rarities: Dictionary = {}
var rarity_order: Array[String] = []
var slots: Array[String] = []
var research: Dictionary = {}
var research_order: Array[String] = []
var research_meta: Dictionary = {}
var objectives: Dictionary = {}
var achievements: Array = []
var store: Dictionary = {}
var tutorial_steps: Array = []

var validation_errors: PackedStringArray = []
var loaded := false


func _ready() -> void:
	load_all()


func load_all() -> void:
	validation_errors.clear()
	_load_stats()
	balance = _dict(_read("balance.json"))
	economy = _dict(_read("economy.json"))
	_load_agents()
	_load_abilities()
	_load_enemies()
	_load_maps()
	_load_equipment()
	_load_research()
	objectives = _dict(_read("objectives.json"))
	achievements = _dict(_read("achievements.json")).get("achievements", [])
	store = _dict(_read("store.json"))
	tutorial_steps = _dict(_read("tutorial.json")).get("steps", [])
	_validate()
	loaded = true
	for e in validation_errors:
		push_error("[Content] " + e)


# ---------------------------------------------------------------- accessors

func agent(id: String) -> Dictionary:
	return agents.get(id, {})

func active(id: String) -> Dictionary:
	return actives.get(id, {})

func passive(id: String) -> Dictionary:
	return passives.get(id, {})

func evolution(id: String) -> Dictionary:
	return evolutions.get(id, {})

func enemy(id: String) -> Dictionary:
	return enemies.get(id, {})

func map_def(id: String) -> Dictionary:
	return maps.get(id, {})

func mode(id: String) -> Dictionary:
	return modes.get(id, {})

func item(id: String) -> Dictionary:
	return equipment.get(id, {})

func rarity(id: String) -> Dictionary:
	return rarities.get(id, {})

func research_node(id: String) -> Dictionary:
	return research.get(id, {})

func balance_value(path: String, fallback: Variant = null) -> Variant:
	return JsonUtil.dig(balance, path, fallback)

func economy_value(path: String, fallback: Variant = null) -> Variant:
	return JsonUtil.dig(economy, path, fallback)

func rarity_index(id: String) -> int:
	return rarity_order.find(id)

func next_rarity(id: String) -> String:
	var i := rarity_index(id)
	if i < 0 or i >= rarity_order.size() - 1:
		return ""
	return rarity_order[i + 1]

## Returns the definition of any upgrade id (active, passive, evolution, fallback).
func upgrade_def(id: String) -> Dictionary:
	if actives.has(id):
		return actives[id]
	if passives.has(id):
		return passives[id]
	if evolutions.has(id):
		return evolutions[id]
	return fallbacks.get(id, {})


# ---------------------------------------------------------------- loading

func _read(file: String) -> Variant:
	var v: Variant = JsonUtil.load_file(DATA_DIR + file)
	if v == null:
		validation_errors.append("Falha ao ler %s" % file)
	return v

func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}

func _index(list: Array, into: Dictionary, order: Array[String], label: String) -> void:
	for entry in list:
		if not entry is Dictionary or not entry.has("id"):
			validation_errors.append("%s sem id" % label)
			continue
		var id: String = entry["id"]
		if into.has(id):
			validation_errors.append("%s duplicado: %s" % [label, id])
		into[id] = entry
		order.append(id)

func _load_stats() -> void:
	stats.clear()
	for s in _dict(_read("stats.json")).get("stats", []):
		stats[s["id"]] = s

func _load_agents() -> void:
	agents.clear(); agent_order.clear()
	var d := _dict(_read("agents.json"))
	agent_level_costs = d.get("level_costs", {})
	_index(d.get("agents", []), agents, agent_order, "agente")

func _load_abilities() -> void:
	actives.clear(); active_order.clear(); passives.clear(); passive_order.clear()
	evolutions.clear(); evolution_by_active.clear(); fallbacks.clear()
	var d := _dict(_read("abilities.json"))
	_index(d.get("actives", []), actives, active_order, "habilidade")
	_index(d.get("passives", []), passives, passive_order, "módulo")
	var evo_order: Array[String] = []
	_index(d.get("evolutions", []), evolutions, evo_order, "evolução")
	for id in evo_order:
		evolution_by_active[evolutions[id]["from"]] = id
	var fb_order: Array[String] = []
	_index(d.get("fallbacks", []), fallbacks, fb_order, "fallback")

func _load_enemies() -> void:
	enemies.clear(); enemy_order.clear(); elite_ids.clear(); boss_ids.clear()
	var d := _dict(_read("enemies.json"))
	_index(d.get("enemies", []), enemies, enemy_order, "inimigo")
	for e in d.get("elites", []):
		e["is_elite"] = true
		enemies[e["id"]] = e
		elite_ids.append(e["id"])
	for b in d.get("bosses", []):
		b["is_boss"] = true
		enemies[b["id"]] = b
		boss_ids.append(b["id"])
	drops = d.get("drops", {})

func _load_maps() -> void:
	maps.clear(); map_order.clear(); modes.clear(); mode_order.clear()
	var d := _dict(_read("maps.json"))
	_index(d.get("maps", []), maps, map_order, "mapa")
	_index(d.get("modes", []), modes, mode_order, "modo")
	daily_modifiers = d.get("daily_modifiers", [])

func _load_equipment() -> void:
	equipment.clear(); item_order.clear(); rarities.clear(); rarity_order.clear(); slots.clear()
	var d := _dict(_read("equipment.json"))
	for s in d.get("slots", []):
		slots.append(s)
	var rlist: Array = d.get("rarities", [])
	rlist.sort_custom(func(a, b): return a["order"] < b["order"])
	_index(rlist, rarities, rarity_order, "raridade")
	_index(d.get("items", []), equipment, item_order, "item")
	equipment_meta = d

var equipment_meta: Dictionary = {}

func _load_research() -> void:
	research.clear(); research_order.clear()
	research_meta = _dict(_read("research.json"))
	_index(research_meta.get("nodes", []), research, research_order, "pesquisa")


# ---------------------------------------------------------------- validation

func _validate() -> void:
	for id in agents:
		var a: Dictionary = agents[id]
		if not actives.has(a.get("start_ability", "")):
			validation_errors.append("Agente %s: habilidade inicial inválida" % id)
		_validate_mods(a.get("base_mods", []), "agente " + id)
	for id in actives:
		var levels: Array = actives[id].get("levels", [])
		if levels.size() != 5:
			validation_errors.append("Habilidade %s deve ter 5 níveis" % id)
	for id in passives:
		if not stats.has(passives[id].get("stat", "")):
			validation_errors.append("Módulo %s: atributo inválido" % id)
		if passives[id].get("values", []).size() != 5:
			validation_errors.append("Módulo %s deve ter 5 níveis" % id)
	for id in evolutions:
		var e: Dictionary = evolutions[id]
		if not actives.has(e.get("from", "")) or not passives.has(e.get("requires", "")):
			validation_errors.append("Evolução %s com referência inválida" % id)
	for id in maps:
		var m: Dictionary = maps[id]
		if m.get("boss", "") != "" and not enemies.has(m["boss"]):
			validation_errors.append("Mapa %s: chefe inválido" % id)
		for w in m.get("waves", []):
			for pair in w.get("pool", []):
				if not enemies.has(pair[0]):
					validation_errors.append("Mapa %s: inimigo %s inexistente" % [id, pair[0]])
		for ev in m.get("events", []):
			if ev.has("enemy") and not enemies.has(ev["enemy"]):
				validation_errors.append("Mapa %s: evento com inimigo %s inexistente" % [id, ev["enemy"]])
	for id in equipment:
		var it: Dictionary = equipment[id]
		if not it.get("slot", "") in slots:
			validation_errors.append("Item %s: espaço inválido" % id)
		if not stats.has(JsonUtil.dig(it, "main.stat", "")):
			validation_errors.append("Item %s: atributo principal inválido" % id)
	for id in research:
		for req in research[id].get("requires", []):
			if not research.has(req):
				validation_errors.append("Pesquisa %s requer nó inexistente %s" % [id, req])
	if _has_research_cycle():
		validation_errors.append("Árvore de pesquisa contém ciclo")

func _validate_mods(mods: Array, ctx: String) -> void:
	for m in mods:
		if not stats.has(m.get("stat", "")):
			validation_errors.append("%s: atributo %s inválido" % [ctx, m.get("stat", "?")])
		if not m.get("op", "") in ["flat", "pct", "mult"]:
			validation_errors.append("%s: operação inválida" % ctx)

func _has_research_cycle() -> bool:
	var state: Dictionary = {}
	for id in research_order:
		if _cycle_visit(id, state):
			return true
	return false

func _cycle_visit(id: String, state: Dictionary) -> bool:
	if state.get(id, 0) == 1:
		return true
	if state.get(id, 0) == 2:
		return false
	state[id] = 1
	for req in research.get(id, {}).get("requires", []):
		if _cycle_visit(req, state):
			return true
	state[id] = 2
	return false
