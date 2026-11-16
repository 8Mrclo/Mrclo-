extends Node
## AchievementManager (autoload "Achievements").
## Tracks lifetime counters per event (data.stats) and maps them to
## achievements. Counters are kept even after claiming, for the codex/records.


func _ready() -> void:
	EventBus.game_event.connect(_on_event)


func _on_event(type: StringName, amount: float, data: Dictionary) -> void:
	if Game.data.is_empty():
		return
	var stats: Dictionary = Game.data.stats
	var key := str(type)
	if type in [GameEvents.ACCOUNT_LEVEL, GameEvents.RUN_LEVEL_REACHED]:
		stats[key] = maxf(float(stats.get(key, 0.0)), amount)
	else:
		stats[key] = float(stats.get(key, 0.0)) + maxf(amount, 0.0)
	var changed := false
	for a in Content.achievements:
		var e := entry(a.id)
		if ObjectiveTracker.apply(a, e, type, amount, data):
			changed = true
	if changed:
		EventBus.notifications_changed.emit()
	Game.save_soon()


func entry(id: String) -> Dictionary:
	var all: Dictionary = Game.data.achievements
	if not all.has(id):
		all[id] = {"progress": 0.0, "claimed": false}
	return all[id]


func claim(id: String) -> Dictionary:
	for a in Content.achievements:
		if a.id != id:
			continue
		var e := entry(id)
		if bool(e.claimed) or not ObjectiveTracker.is_complete(a, e):
			return {}
		e.claimed = true
		var s := Rewards.grant(a.get("reward", {}), "achievement", "ach:" + id)
		Saves.save_now()
		EventBus.notifications_changed.emit()
		return s
	return {}


func claim_all() -> int:
	var n := 0
	for a in Content.achievements:
		if not claim(a.id).is_empty():
			n += 1
	return n


func claimable_count() -> int:
	if Game.data.is_empty():
		return 0
	var n := 0
	for a in Content.achievements:
		var e := entry(a.id)
		if not bool(e.claimed) and ObjectiveTracker.is_complete(a, e):
			n += 1
	return n


func completed_count() -> int:
	var n := 0
	for a in Content.achievements:
		if bool(entry(a.id).claimed):
			n += 1
	return n
