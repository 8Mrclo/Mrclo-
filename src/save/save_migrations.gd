class_name SaveMigrations
extends RefCounted
## Sequential migrations. Each step upgrades exactly one version so old saves
## always walk the full chain. Missing fields are filled by merge_defaults().
##
## v1 (prototype): {"coins": int, "gems": int, "hero": String, "items": Array}
## v2: wallet dictionary, inventory with uids.
## v3: research, store, codex, mail (handled by defaults merge) + JSON ints fix.


static func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 1))
	if version < 2:
		data = _v1_to_v2(data)
	if version < 3:
		data = _v2_to_v3(data)
	JsonUtil.merge_defaults(data, SaveDefaults.create())
	_normalize(data)
	data["version"] = SaveDefaults.VERSION
	return data


static func _v1_to_v2(old: Dictionary) -> Dictionary:
	var d := {"version": 2}
	d["wallet"] = {"scrap": int(old.get("coins", 0)), "prisms": int(old.get("gems", 0))}
	d["selected_agent"] = str(old.get("hero", "lia"))
	var inv := {"next_uid": 1, "items": {}}
	for raw in old.get("items", []):
		if raw is String and Content.item(raw).size() > 0:
			var uid: int = inv["next_uid"]
			inv["items"][str(uid)] = {"uid": uid, "def": raw, "rarity": "common", "level": 1, "favorite": false, "invested": 0}
			inv["next_uid"] = uid + 1
	d["inventory"] = inv
	return d


static func _v2_to_v3(d: Dictionary) -> Dictionary:
	d["version"] = 3
	if d.has("hero"):
		d.erase("hero")
	return d


## JSON turns every number into float; restore integers where code expects them.
static func _normalize(d: Dictionary) -> void:
	for k in d.wallet.keys():
		d.wallet[k] = maxi(int(d.wallet[k]), 0)
	d.inventory.next_uid = int(d.inventory.next_uid)
	var fixed: Dictionary = {}
	for key in d.inventory.items:
		var it: Dictionary = d.inventory.items[key]
		it.uid = int(it.get("uid", int(key)))
		it.level = maxi(int(it.get("level", 1)), 1)
		it.invested = maxi(int(it.get("invested", 0)), 0)
		if Content.item(str(it.get("def", ""))).is_empty():
			continue # drop items whose definition was removed
		fixed[str(it.uid)] = it
	d.inventory.items = fixed
	for s in d.equipped.keys():
		var uid := int(d.equipped[s])
		d.equipped[s] = uid if fixed.has(str(uid)) else -1
	for id in d.agents:
		d.agents[id].level = maxi(int(d.agents[id].get("level", 1)), 1)
	for id in d.research.keys():
		d.research[id] = int(d.research[id])
	d.profile.account_level = maxi(int(d.profile.account_level), 1)
	d.profile.account_xp = maxi(int(d.profile.account_xp), 0)
	for k in ["created_at", "last_seen", "max_seen"]:
		d.profile[k] = int(d.profile[k])
	d.offline.last_claim = int(d.offline.last_claim)
	if not Content.agents.has(d.selected_agent):
		d.selected_agent = "lia"
