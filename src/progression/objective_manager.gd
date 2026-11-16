extends Node
## ObjectiveManager (autoload "Objectives").
## Tutorial (fixed list), daily and weekly objectives selected deterministically
## from data pools by local date. Progress reacts to EventBus.game_event.
## Claiming uses Rewards unique keys, so double claims are impossible.

const CATEGORIES := ["tutorial", "daily", "weekly"]


func _ready() -> void:
	EventBus.game_event.connect(_on_event)


func refresh_periods() -> void:
	if Game.data.is_empty():
		return
	_refresh("daily", TimeService.day_key(), int(Content.objectives.get("daily_active", 5)))
	_refresh("weekly", TimeService.week_key(), int(Content.objectives.get("weekly_active", 5)))


func _refresh(cat: String, period: String, count: int) -> void:
	var st: Dictionary = Game.data.objectives[cat]
	if st.period == period and not st.active.is_empty():
		return
	var pool: Array = Content.objectives.get(cat, [])
	var ids: Array = pool.map(func(o): return o.id)
	var rng := RandomNumberGenerator.new()
	rng.seed = RandomService.seed_from_key("%s:%s" % [cat, period])
	RandomService.shuffle_with(rng, ids)
	st.period = period
	st.active = ids.slice(0, mini(count, ids.size()))
	st.items = {}
	for id in st.active:
		st.items[id] = {"progress": 0.0, "claimed": false}
	Game.save_soon()


func defs(cat: String) -> Array:
	var pool: Array = Content.objectives.get(cat, [])
	if cat == "tutorial":
		return pool
	var active: Array = Game.data.objectives[cat].active
	return pool.filter(func(o): return o.id in active)


func entry(cat: String, id: String) -> Dictionary:
	if cat == "tutorial":
		var t: Dictionary = Game.data.objectives.tutorial
		if not t.has(id):
			t[id] = {"progress": 0.0, "claimed": false}
		return t[id]
	var items: Dictionary = Game.data.objectives[cat].items
	if not items.has(id):
		items[id] = {"progress": 0.0, "claimed": false}
	return items[id]


func _on_event(type: StringName, amount: float, data: Dictionary) -> void:
	if Game.data.is_empty():
		return
	refresh_periods()
	var changed := false
	for cat in CATEGORIES:
		for d in defs(cat):
			if ObjectiveTracker.apply(d, entry(cat, d.id), type, amount, data):
				changed = true
	if changed:
		Game.save_soon()
		EventBus.notifications_changed.emit()


func reward_key(cat: String, id: String) -> String:
	if cat == "tutorial":
		return "obj:tutorial:" + id
	return "obj:%s:%s:%s" % [cat, Game.data.objectives[cat].period, id]


func can_claim(cat: String, def: Dictionary) -> bool:
	var e := entry(cat, def.id)
	return ObjectiveTracker.is_complete(def, e) and not bool(e.claimed)


func claim(cat: String, id: String) -> Dictionary:
	for d in defs(cat):
		if d.id == id and can_claim(cat, d):
			var e := entry(cat, id)
			e.claimed = true
			var summary := Rewards.grant(d.get("reward", {}), "objective:" + cat, reward_key(cat, id))
			if not summary.duplicate:
				EventBus.emit_game(GameEvents.OBJECTIVE_CLAIMED, 1.0, {"category": cat})
			Saves.save_now()
			EventBus.notifications_changed.emit()
			return summary
	return {}


func claim_all(cat: String) -> int:
	var n := 0
	for d in defs(cat):
		if can_claim(cat, d) and not claim(cat, d.id).is_empty():
			n += 1
	return n


func claimable_count(cat: String = "") -> int:
	if Game.data.is_empty():
		return 0
	var n := 0
	for c in CATEGORIES:
		if cat != "" and c != cat:
			continue
		for d in defs(c):
			if can_claim(c, d):
				n += 1
		if c == "daily":
			for i in milestone_track().size():
				if can_claim_milestone(i):
					n += 1
	return n


# ---------------------------------------------------------------- milestones

## Daily milestone track: rewards at N claimed daily objectives (per day).
func milestone_track() -> Array:
	var ms: Array = Content.objectives.get("milestones", [])
	return ms[0].get("points", []) if not ms.is_empty() else []


func daily_claimed_count() -> int:
	var n := 0
	for d in defs("daily"):
		if bool(entry("daily", d.id).claimed):
			n += 1
	return n


func milestone_key(i: int) -> String:
	return "obj:milestone:%s:%d" % [Game.data.objectives.daily.period, i]


func can_claim_milestone(i: int) -> bool:
	var track := milestone_track()
	return i < track.size() and daily_claimed_count() >= int(track[i].at) and not Rewards.is_claimed(milestone_key(i))


func claim_milestone(i: int) -> Dictionary:
	if not can_claim_milestone(i):
		return {}
	var s := Rewards.grant(milestone_track()[i].reward, "milestone", milestone_key(i))
	Saves.save_now()
	EventBus.notifications_changed.emit()
	return s
