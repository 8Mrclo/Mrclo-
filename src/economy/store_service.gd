extends Node
## StoreService (autoload "Store").
## Separation: catalog (data/store.json) -> offers() builds the visible list
## (incl. deterministic daily rotation) -> price/limit rules here ->
## execution via Economy.transact + Rewards.grant. UI only calls purchase().
## No real money: all prices are fictional in-game currencies.

signal purchased(offer_id: String, summary: Dictionary)


func period_key(period: String) -> String:
	match period:
		"daily": return TimeService.day_key()
		"weekly": return TimeService.week_key()
	return "forever"


func seconds_to_reset(period: String) -> int:
	match period:
		"daily": return TimeService.seconds_to_next_day()
		"weekly": return TimeService.seconds_to_next_week()
	return 0


## All offers for a tab, including generated daily rotation and shard offers.
func offers(tab: String) -> Array:
	var out: Array = []
	for o in Content.store.get("offers", []):
		if o.tab == tab:
			out.append(o)
	if tab == "featured":
		out.append_array(daily_rotation())
	if tab == "shards":
		var cfg: Dictionary = Content.store.get("shard_offers_per_agent", {})
		for agent_id in Content.agent_order:
			out.append({"id": "shard_" + agent_id, "tab": "shards", "kind": "shards_fixed", "agent": agent_id,
				"name": Content.agent(agent_id).name, "cost": cfg.get("cost", {}),
				"gives": {"shard_" + agent_id: int(cfg.get("amount", 5))}, "period": cfg.get("period", "daily"),
				"limit": int(cfg.get("limit", 1)), "icon": {"shape": "shard", "color": JsonUtil.dig(Content.agent(agent_id), "visual.body", "#ff6f61")}})
	return out


## Deterministic rotation: same local date => same offers on this device.
func daily_rotation(day: String = "") -> Array:
	if day == "":
		day = TimeService.day_key()
	var cfg: Dictionary = Content.store.get("daily_rotation", {})
	var pool: Array = cfg.get("pool", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = RandomService.seed_from_key("store:" + day)
	var out: Array = []
	for i in int(cfg.get("slots", 4)):
		if pool.is_empty():
			break
		var tpl: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var o := tpl.duplicate(true)
		o["id"] = "rot_%s_%d" % [day, i]
		o["tab"] = "featured"
		o["period"] = "daily"
		o["rotating"] = true
		match tpl.get("kind", ""):
			"item":
				var def_id: String = Content.item_order[rng.randi_range(0, Content.item_order.size() - 1)]
				o["gives"] = {"item": {"def": def_id, "rarity": tpl.rarity}}
				o["name"] = Content.item(def_id).name
				o["icon"] = Content.item(def_id).icon
			"shards":
				var agent_id: String = Content.agent_order[rng.randi_range(0, Content.agent_order.size() - 1)]
				o["gives"] = {"shard_" + agent_id: int(tpl.amount)}
				o["name"] = Content.agent(agent_id).name
				o["icon"] = {"shape": "shard", "color": JsonUtil.dig(Content.agent(agent_id), "visual.body", "#ff6f61")}
			_:
				o["gives"] = tpl.get("gives", {})
				o["name"] = {"pt_BR": Loc.t("store.rotation_currency"), "en": Loc.t("store.rotation_currency")}
				o["icon"] = {"shape": "chip", "color": "#3fa7ff"}
		out.append(o)
	return out


func find_offer(offer_id: String) -> Dictionary:
	for tab in Content.store.get("tabs", []):
		for o in offers(tab):
			if o.id == offer_id:
				return o
	return {}


func purchases_in_period(offer: Dictionary) -> int:
	var rec: Dictionary = Game.data.store.purchases.get(offer.id, {})
	if rec.get("period", "") != period_key(offer.get("period", "none")):
		return 0
	return int(rec.get("count", 0))


func remaining(offer: Dictionary) -> int:
	var limit := int(offer.get("limit", 0))
	if limit <= 0:
		return 999999
	return maxi(limit - purchases_in_period(offer), 0)


## Returns "" when purchasable, otherwise a localization key with the reason.
func check(offer: Dictionary, use_alt: bool = false) -> String:
	if offer.is_empty():
		return "store.err_missing"
	if remaining(offer) <= 0:
		return "store.err_limit"
	var req: Dictionary = offer.get("requires", {})
	if int(req.get("account_level", 0)) > int(Game.data.profile.account_level):
		return "store.err_level"
	var cost: Dictionary = offer.get("alt_cost", {}) if use_alt else offer.get("cost", {})
	if not Economy.can_afford(cost):
		return "store.err_funds"
	return ""


## Executes a purchase atomically: cost is taken and the period counter
## incremented before granting; a crash afterwards can't double-charge.
func purchase(offer_id: String, use_alt: bool = false) -> Dictionary:
	var offer := find_offer(offer_id)
	var err := check(offer, use_alt)
	if err != "":
		return {"ok": false, "error": err}
	var cost: Dictionary = offer.get("alt_cost", {}) if use_alt else offer.get("cost", {})
	if not Economy.transact(cost, {}, "store:" + offer_id, false):
		return {"ok": false, "error": "store.err_funds"}
	var rec: Dictionary = Game.data.store.purchases.get(offer_id, {})
	var pk := period_key(offer.get("period", "none"))
	if rec.get("period", "") != pk:
		rec = {"period": pk, "count": 0}
	rec.count = int(rec.count) + 1
	Game.data.store.purchases[offer_id] = rec
	var summary: Dictionary
	if offer.get("kind", "") == "crate":
		summary = open_crate(offer.get("crate", ""))
	else:
		summary = Rewards.grant(offer.get("gives", {}), "store:" + offer_id)
	EventBus.emit_game(GameEvents.STORE_PURCHASE, 1.0, {"offer": offer_id})
	Analytics.log_event("store_purchase", {"offer": offer_id})
	Saves.save_now()
	purchased.emit(offer_id, summary)
	EventBus.notifications_changed.emit()
	return {"ok": true, "summary": summary}


func open_crate(crate_id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var crate: Dictionary = Content.store.get("crates", {}).get(crate_id, {})
	if rng == null:
		rng = Rng.stream(&"loot")
	var pity := int(Game.data.store.pity.get(crate_id, 0))
	var roll := CrateRoller.roll(crate, pity, rng)
	Game.data.store.pity[crate_id] = roll.pity_after
	var summary := Rewards.grant({"item": {"rarity": roll.rarity}}, "crate:" + crate_id)
	summary["rarity"] = roll.rarity
	summary["guaranteed"] = roll.guaranteed
	var log_arr: Array = Game.data.store.crate_log
	log_arr.append({"t": TimeService.now(), "crate": crate_id, "rarity": roll.rarity, "guaranteed": roll.guaranteed})
	while log_arr.size() > 100:
		log_arr.pop_front()
	EventBus.emit_game(GameEvents.CRATE_OPENED, 1.0, {"crate": crate_id})
	return summary


func pity_progress(crate_id: String) -> int:
	return int(Game.data.store.pity.get(crate_id, 0))


func free_available() -> int:
	var n := 0
	for o in offers("supplies"):
		if o.get("cost", {}).is_empty() and remaining(o) > 0:
			n += 1
	return n
