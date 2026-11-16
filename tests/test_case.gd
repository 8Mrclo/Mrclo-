class_name TestCase
extends RefCounted
## Minimal assertion base. Each method named test_* runs with a fresh,
## in-memory profile (disk saving disabled) prepared by the runner.

var failures: Array[String] = []
var current := ""


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])


func eq(a: Variant, b: Variant, msg: String = "") -> void:
	if typeof(a) in [TYPE_FLOAT, TYPE_INT] and typeof(b) in [TYPE_FLOAT, TYPE_INT]:
		check(absf(float(a) - float(b)) < 0.0001, "%s (esperado %s, obtido %s)" % [msg, b, a])
	else:
		check(a == b, "%s (esperado %s, obtido %s)" % [msg, b, a])


func near(a: float, b: float, tol: float, msg: String = "") -> void:
	check(absf(a - b) <= tol, "%s (esperado ~%s, obtido %s)" % [msg, b, a])


## Fresh profile helper used by tests that need a clean economy.
func fresh_profile() -> void:
	Game.set_data(SaveDefaults.create())
