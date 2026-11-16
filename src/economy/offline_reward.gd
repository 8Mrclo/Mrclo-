class_name OfflineRewardCalculator
extends RefCounted
## Offline yield ("Rendimento do Farol") computed purely from timestamps.
## Clock guard: a "now" earlier than the highest timestamp ever observed
## (minus tolerance) is treated as clock rollback => zero reward + anomaly.
## Future validation: send last_claim/now to a server and trust its answer.


static func compute(last_claim: int, now: int, max_seen: int, cfg: Dictionary, sector: int, bonus: Dictionary = {}) -> Dictionary:
	var result := {"seconds": 0, "anomaly": false, "rewards": {}, "capped": false}
	var skew := int(cfg.get("max_clock_skew_seconds", 300))
	if now + skew < max_seen or now + skew < last_claim:
		result.anomaly = true
		return result
	var elapsed := maxi(now - last_claim, 0)
	var cap_seconds := int((float(cfg.get("cap_hours", 8)) + float(bonus.get("cap_hours", 0))) * 3600.0)
	if elapsed > cap_seconds:
		elapsed = cap_seconds
		result.capped = true
	result.seconds = elapsed
	if elapsed < int(cfg.get("min_minutes", 5)) * 60:
		return result
	var rate := 1.0 + float(bonus.get("rate", 0.0))
	var minutes := elapsed / 60.0
	var s := maxi(sector, 1)
	var scrap := int(floor(minutes * float(cfg.get("scrap_per_minute_per_sector", 1.6)) * s * rate))
	var data := int(floor(elapsed / 3600.0 * float(cfg.get("data_per_hour_per_sector", 1.2)) * s * rate))
	if scrap > 0:
		result.rewards["scrap"] = scrap
	if data > 0:
		result.rewards["field_data"] = data
	return result
