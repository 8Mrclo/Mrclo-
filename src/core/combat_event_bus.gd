extends Node
## CombatEventBus (autoload "EventBus").
## Decouples producers (battle, economy, inventory) from consumers (objectives,
## achievements, analytics, UI badges). Signals carry plain data only.

signal game_event(type: StringName, amount: float, data: Dictionary)

# Combat-scope signals (only valid while a Battle scene is alive).
signal enemy_killed(enemy_id: StringName, is_elite: bool, is_boss: bool, pos: Vector2)
signal player_damaged(amount: float)
signal player_leveled(level: int)
signal boss_spawned(boss_id: StringName)
signal boss_phase_changed(phase: int)
signal boss_defeated(boss_id: StringName)

# Meta-scope signals.
signal currency_changed(currency: StringName, value: int)
signal inventory_changed
signal profile_changed
signal notifications_changed
signal toast_requested(text: String, kind: StringName)
signal hint_requested(step_id: StringName)


func emit_game(type: StringName, amount: float = 1.0, data: Dictionary = {}) -> void:
	game_event.emit(type, amount, data)


func toast(text: String, kind: StringName = &"info") -> void:
	toast_requested.emit(text, kind)
