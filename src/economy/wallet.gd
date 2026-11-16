class_name Wallet
extends RefCounted
## Pure, atomic balance arithmetic over a Dictionary (no IO, no signals).
## A transaction either applies fully or not at all; balances never go negative.

var balances: Dictionary
var entries: Array
var log_size: int


func _init(balance_dict: Dictionary, log_array: Array, max_log: int = 120) -> void:
	balances = balance_dict
	entries = log_array
	log_size = max_log


func get_amount(currency: String) -> int:
	return int(balances.get(currency, 0))


static func is_valid_amounts(amounts: Dictionary) -> bool:
	for c in amounts:
		var v: Variant = amounts[c]
		if not (v is int or v is float):
			return false
		if float(v) < 0.0 or is_nan(float(v)) or is_inf(float(v)):
			return false
	return true


func can_afford(costs: Dictionary) -> bool:
	if not is_valid_amounts(costs):
		return false
	for c in costs:
		if get_amount(c) < int(costs[c]):
			return false
	return true


func missing(costs: Dictionary) -> Dictionary:
	var out := {}
	for c in costs:
		var lack := int(costs[c]) - get_amount(c)
		if lack > 0:
			out[c] = lack
	return out


## Applies costs then gains atomically. Returns false without side effects on failure.
func transact(costs: Dictionary, gains: Dictionary, reason: String, timestamp: int = 0) -> bool:
	if not is_valid_amounts(costs) or not is_valid_amounts(gains):
		return false
	if not can_afford(costs):
		return false
	var snapshot := balances.duplicate()
	for c in costs:
		balances[c] = get_amount(c) - int(costs[c])
	for c in gains:
		balances[c] = mini(get_amount(c) + int(gains[c]), 2000000000)
	for c in balances:
		if int(balances[c]) < 0:
			balances.clear()
			balances.merge(snapshot)
			return false
	entries.append({"t": timestamp, "reason": reason, "cost": costs.duplicate(), "gain": gains.duplicate()})
	while entries.size() > log_size:
		entries.pop_front()
	return true
