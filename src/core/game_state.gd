extends Node
## GameState (autoload "Game").
## Holds the persisted profile dictionary plus transient session state
## (pending run config, last run result). Domain rules live in the managers.

signal data_replaced
signal account_leveled(level: int)

var data: Dictionary = {}
var pending_run: Dictionary = {}     # RunConfig built by MissionManager
var last_result: Dictionary = {}     # filled by Battle on finish
var last_rewards: Dictionary = {}    # granted rewards to reveal
var boot_report: Dictionary = {}


func set_data(d: Dictionary) -> void:
	data = d
	data_replaced.emit()
	EventBus.profile_changed.emit()


func on_new_profile() -> void:
	for entry in Content.equipment_meta.get("starter_items", []):
		Inventory.add_item(entry.def, entry.rarity, "starter")
	Inventory.auto_equip()
	data.mail.append({"id": "welcome", "title": "mail.welcome.title", "body": "mail.welcome.body", "reward": {"scrap": 500, "prisms": 50, "crate_key": 1}, "claimed": false, "time": TimeService.now()})


func save_soon() -> void:
	Saves.mark_dirty()


## Records wall-clock observations used by the offline reward clock guard.
func touch_clock() -> void:
	if data.is_empty():
		return
	var now := TimeService.now()
	data.profile.last_seen = now
	data.profile.max_seen = maxi(int(data.profile.max_seen), now)


# ---------------------------------------------------------------- account

func account_xp_needed(level: int) -> int:
	var cfg: Dictionary = Content.economy_value("account_xp", {})
	return int(round(float(cfg.get("base", 100)) * pow(float(cfg.get("growth", 1.25)), level - 1)))


func add_account_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	var cfg: Dictionary = Content.economy_value("account_xp", {})
	var max_level := int(cfg.get("max_level", 60))
	var gained := 0
	data.profile.account_xp += amount
	while data.profile.account_level < max_level and data.profile.account_xp >= account_xp_needed(data.profile.account_level):
		data.profile.account_xp -= account_xp_needed(data.profile.account_level)
		data.profile.account_level += 1
		gained += 1
		Rewards.grant(cfg.get("level_rewards", {}), "account_level", "acct_lvl:%d" % data.profile.account_level)
		account_leveled.emit(data.profile.account_level)
		EventBus.emit_game(GameEvents.ACCOUNT_LEVEL, data.profile.account_level)
	if data.profile.account_level >= max_level:
		data.profile.account_xp = 0
	save_soon()
	return gained


# ---------------------------------------------------------------- codex & stats

func discover(kind: String, id: String) -> void:
	if data.is_empty() or not data.codex.has(kind):
		return
	if not data.codex[kind].has(id):
		data.codex[kind][id] = true
		save_soon()


func is_discovered(kind: String, id: String) -> bool:
	return data.codex.get(kind, {}).has(id)


func unclaimed_mail() -> int:
	var n := 0
	for m in data.get("mail", []):
		if not m.claimed:
			n += 1
	return n


func flag(key: String) -> bool:
	return bool(data.get("flags", {}).get(key, false))


func set_flag(key: String, value: bool) -> void:
	data.flags[key] = value
	save_soon()
