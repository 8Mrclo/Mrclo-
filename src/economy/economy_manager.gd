extends Node
## EconomyManager (autoload "Economy").
## The only place that mutates balances. Wraps Wallet with persistence,
## events and the debug commands.

var _wallet: Wallet


func _ready() -> void:
	Game.data_replaced.connect(_rebind)


func _rebind() -> void:
	_wallet = Wallet.new(Game.data.wallet, Game.data.transactions, int(Content.economy_value("transaction_log_size", 120)))


func wallet() -> Wallet:
	if _wallet == null or _wallet.balances != Game.data.wallet:
		_rebind()
	return _wallet


func balance(currency: String) -> int:
	return wallet().get_amount(currency)


func can_afford(costs: Dictionary) -> bool:
	return wallet().can_afford(costs)


func transact(costs: Dictionary, gains: Dictionary, reason: String, save_immediately: bool = true) -> bool:
	if not wallet().transact(costs, gains, reason, TimeService.now()):
		return false
	for c in costs:
		EventBus.currency_changed.emit(c, balance(c))
		if int(costs[c]) > 0:
			EventBus.emit_game(GameEvents.CURRENCY_SPENT, float(costs[c]), {"currency": c})
	for c in gains:
		EventBus.currency_changed.emit(c, balance(c))
		if int(gains[c]) > 0:
			EventBus.emit_game(GameEvents.CURRENCY_EARNED, float(gains[c]), {"currency": c})
	EventBus.notifications_changed.emit()
	if save_immediately:
		Saves.save_now()
	else:
		Game.save_soon()
	return true


func spend(costs: Dictionary, reason: String) -> bool:
	return transact(costs, {}, reason)


func earn(gains: Dictionary, reason: String) -> bool:
	return transact({}, gains, reason, false)


# ---------------------------------------------------------------- dev tools

func dev_grant_all() -> void:
	earn(Content.economy_value("dev.grant_amount", {}), "dev_grant")


func dev_set(currency: String, value: int) -> void:
	var cur := balance(currency)
	if value > cur:
		earn({currency: value - cur}, "dev_set")
	elif value < cur:
		spend({currency: cur - maxi(value, 0)}, "dev_set")
