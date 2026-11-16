class_name StatBlock
extends RefCounted
## Extensible combat stats.
## Order of application (documented in docs/FORMULAS.md):
##   final = clamp((base + Σflat) × max(0.1, 1 + Σpct) × Π max(0.1, 1 + mult), min, max)
## pct sums are floored at -90% and each mult factor at ×0.1, so no stat can
## reach zero/negative by stacking reductions; min/max from stats.json cap growth.

signal changed

var _mods: Dictionary = {}     # stat -> Array[Dictionary]
var _cache: Dictionary = {}


func add(mod: Dictionary) -> void:
	var stat: String = mod.get("stat", "")
	if not Content.stats.has(stat):
		push_warning("StatBlock: atributo desconhecido %s" % stat)
		return
	if not _mods.has(stat):
		_mods[stat] = []
	_mods[stat].append(mod)
	_cache.erase(stat)
	changed.emit()


func add_all(mods: Array, source: String = "") -> void:
	for m in mods:
		var mm: Dictionary = m.duplicate()
		if source != "":
			mm["source"] = source
		add(mm)


func remove_source(source: String) -> void:
	for stat in _mods:
		var before: int = _mods[stat].size()
		_mods[stat] = _mods[stat].filter(func(m): return m.get("source", "") != source)
		if _mods[stat].size() != before:
			_cache.erase(stat)
	changed.emit()


func get_stat(stat: String) -> float:
	if _cache.has(stat):
		return _cache[stat]
	var v := compute(stat, _mods.get(stat, []))
	_cache[stat] = v
	return v


static func compute(stat: String, mods: Array) -> float:
	var def: Dictionary = Content.stats.get(stat, {})
	var base := float(def.get("base", 0.0))
	var flat := 0.0
	var pct := 0.0
	var mult := 1.0
	for m in mods:
		var v := float(m.get("value", 0.0))
		if is_nan(v) or is_inf(v):
			continue
		match m.get("op", "flat"):
			"flat": flat += v
			"pct": pct += v
			"mult": mult *= maxf(0.1, 1.0 + v)
	var result := (base + flat) * maxf(0.1, 1.0 + pct) * mult
	return clampf(result, float(def.get("min", -INF)), float(def.get("max", INF)))


func snapshot() -> Dictionary:
	var out := {}
	for stat in Content.stats:
		out[stat] = get_stat(stat)
	return out
