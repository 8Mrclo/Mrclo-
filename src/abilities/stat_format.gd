class_name StatFormat
extends RefCounted
## Formats stat values and modifiers for UI.


static func value(stat: String, v: float) -> String:
	match str(Content.stats.get(stat, {}).get("fmt", "int")):
		"pct": return "%d%%" % int(round(v * 100.0))
		"mult": return "×%.2f" % v
		"dec": return "%.1f" % v
	return str(int(round(v)))


static func mod_value(stat: String, op: String, v: float) -> String:
	if op == "pct" or op == "mult":
		return "%+d%%" % int(round(v * 100.0))
	if str(Content.stats.get(stat, {}).get("fmt", "int")) == "pct":
		return "%+d%%" % int(round(v * 100.0))
	if absf(v - round(v)) > 0.001:
		return "%+.1f" % v
	return "%+d" % int(round(v))


static func mod_line(m: Dictionary) -> String:
	return "%s %s" % [Loc.t("stat." + str(m.stat)), mod_value(str(m.stat), str(m.op), float(m.value))]
