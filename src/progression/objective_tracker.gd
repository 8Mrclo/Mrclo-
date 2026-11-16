class_name ObjectiveTracker
extends RefCounted
## Pure progress rules shared by objectives and achievements.


static func matches(def: Dictionary, type: StringName, data: Dictionary) -> bool:
	if StringName(def.get("event", "")) != type:
		return false
	var f: Dictionary = def.get("filter", {})
	for k in f:
		if str(data.get(k, "")) != str(f[k]):
			return false
	return true


## Mutates entry {"progress": float, "claimed": bool}. Returns true if changed.
static func apply(def: Dictionary, entry: Dictionary, type: StringName, amount: float, data: Dictionary) -> bool:
	if bool(entry.get("claimed", false)) or not matches(def, type, data):
		return false
	var before := float(entry.get("progress", 0.0))
	var target := float(def.get("target", 1))
	var after := before
	if def.get("mode", "sum") == "max":
		after = maxf(before, amount)
	else:
		after = before + maxf(amount, 0.0)
	after = minf(after, target)
	entry["progress"] = after
	return after != before


static func is_complete(def: Dictionary, entry: Dictionary) -> bool:
	return float(entry.get("progress", 0.0)) >= float(def.get("target", 1))


static func describe(def: Dictionary) -> String:
	if def.has("name"):
		return Loc.text(def.name)
	var key := "objective." + str(def.get("event", ""))
	var f: Dictionary = def.get("filter", {})
	var params := {"target": Loc.format_number(float(def.get("target", 1)))}
	if f.has("screen"):
		params["screen"] = Loc.t("screen." + str(f.screen))
		key += ".screen"
	if f.has("currency"):
		params["currency"] = Loc.currency_name(str(f.currency))
		key += ".currency"
	return Loc.t(key, params)
