class_name SaveDefaults
extends RefCounted
## Canonical shape of the save file. Migrations and merge_defaults rely on it,
## so every new persisted field must be added here first.

const VERSION := 3


static func settings_defaults() -> Dictionary:
	return {
		"music_volume": 0.7, "sfx_volume": 0.8, "ui_volume": 0.8, "ambience_volume": 0.6,
		"vibration": true, "shake": 0.7, "reduce_motion": false, "high_contrast": false,
		"show_damage_numbers": true, "fps": 60, "graphics": "medium", "language": "pt_BR",
		"aim_mode": "nearest", "battle_speed": 1.0, "show_metrics": false,
	}


static func create() -> Dictionary:
	var now := TimeService.now()
	var wallet: Dictionary = {}
	for c in Content.economy_value("currencies", []):
		wallet[c] = 0
	for c in Content.economy_value("starting_wallet", {}):
		wallet[c] = int(Content.economy.starting_wallet[c])
	var agents: Dictionary = {}
	for id in Content.agent_order:
		var unlocked: bool = Content.agent(id).get("unlock", {}).get("type", "") == "default"
		agents[id] = {"unlocked": unlocked, "level": 1}
	var equipped: Dictionary = {}
	for s in Content.slots:
		equipped[s] = -1
	return {
		"version": VERSION,
		"profile": {"account_level": 1, "account_xp": 0, "created_at": now, "last_seen": now, "max_seen": now, "last_login_day": ""},
		"wallet": wallet,
		"agents": agents,
		"selected_agent": "lia",
		"inventory": {"next_uid": 1, "items": {}},
		"equipped": equipped,
		"missions": {"progress": {}, "selected_map": "submerged_avenue", "selected_mode": "expedition", "daily_sim_claimed": ""},
		"objectives": {"tutorial": {}, "daily": {"period": "", "active": [], "items": {}}, "weekly": {"period": "", "active": [], "items": {}}, "milestones": {}},
		"achievements": {},
		"stats": {},
		"research": {},
		"tutorial": {"steps": {}, "enabled": true},
		"store": {"purchases": {}, "pity": {}, "crate_log": []},
		"claimed_keys": {},
		"workshop_history": [],
		"transactions": [],
		"settings": settings_defaults(),
		"records": {"best_time": 0, "best_kills": 0, "best_level": 0, "runs": 0},
		"codex": {"enemies": {}, "abilities": {}, "items": {}},
		"mail": [],
		"offline": {"last_claim": now, "anomaly": false},
		"flags": {"seen_intro": false, "dev_invincible": false},
	}
