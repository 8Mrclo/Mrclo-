extends Node
## DebugTools (autoload "DebugTools").
## Developer menu (F1, or the button in Settings) available only in debug
## builds: OS.is_debug_build() is false in release exports, so the menu and
## its commands are unreachable for players.

var available := OS.is_debug_build()
var invincible := false
var show_hitboxes := false
var forced_seed := 0
var _layer: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if available and event.is_action_pressed("debug_menu"):
		toggle()


func battle() -> Node:
	return get_tree().get_first_node_in_group("battle")


func toggle() -> void:
	if not available:
		return
	if is_instance_valid(_layer):
		_layer.queue_free()
		_layer = null
		return
	_build()


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 80
	add_child(_layer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.02, 0.02, 0.05, 0.94), Palette.AMBER, 2, 12))
	panel.position = Vector2(20, 120)
	panel.custom_minimum_size = Vector2(680, 0)
	panel.theme = ThemeFactory.shared()
	_layer.add_child(panel)
	var v := UIKit.vbox(8)
	panel.add_child(v)
	v.add_child(UIKit.label(Loc.t("debug.title"), 28, Palette.AMBER))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var cmds := [
		["debug.invincible", func(): invincible = not invincible; Router.toast("invencível: %s" % invincible)],
		["debug.add_currency", func(): Economy.dev_grant_all(); Router.toast(Loc.t("debug.done"))],
		["debug.remove_currency", func(): _zero_currencies()],
		["debug.unlock_agents", func(): _unlock_agents()],
		["debug.spawn_boss", func(): _battle_call("debug_spawn_boss")],
		["debug.speed", func(): Engine.time_scale = 2.0 if Engine.time_scale < 1.5 else 1.0],
		["debug.level_up", func(): _battle_call("debug_level_up")],
		["debug.seed", func(): forced_seed = 424242 if forced_seed == 0 else 0; Router.toast("seed: %d" % forced_seed)],
		["debug.give_item", func(): Rewards.grant({"item": {"rarity": "singular"}}, "dev"); Router.toast(Loc.t("debug.done"))],
		["debug.clear_enemies", func(): _battle_call("debug_clear_enemies")],
		["debug.hitboxes", func(): show_hitboxes = not show_hitboxes],
		["debug.metrics", func(): Settings.set_value("show_metrics", not bool(Settings.get_value("show_metrics")))],
		["debug.win", func(): _battle_call("debug_finish", [true])],
		["debug.lose", func(): _battle_call("debug_finish", [false])],
		["debug.offline", func(): _simulate_offline()],
		["debug.unlock_maps", func(): _unlock_maps()],
		["debug.reset_save", func(): Dialogs.typed_confirm(Loc.t("settings.delete_title"), Loc.t("settings.delete_body"), Loc.t("settings.delete_word"), func(): Saves.wipe_and_reset(); Router.goto("boot"))],
		["lab.title", func(): toggle(); Router.goto("lab")],
		["common.close", func(): toggle()],
	]
	for c in cmds:
		var b := UIKit.button(Loc.t(c[0]), c[1], "secondary", 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)


func _battle_call(method: String, args: Array = []) -> void:
	var b := battle()
	if b and b.has_method(method):
		b.callv(method, args)
	else:
		Router.toast(Loc.t("debug.need_battle"), &"warn")


func _zero_currencies() -> void:
	for c in Content.economy_value("currencies", []):
		Economy.dev_set(c, 0)
	Router.toast(Loc.t("debug.done"))


func _unlock_agents() -> void:
	for id in Content.agent_order:
		Game.data.agents[id].unlocked = true
	Saves.save_now()
	EventBus.profile_changed.emit()
	Router.toast(Loc.t("debug.done"))


func _unlock_maps() -> void:
	for id in Content.map_order:
		Missions.progress(id).cleared = true
	Saves.save_now()
	Router.toast(Loc.t("debug.done"))


func _simulate_offline() -> void:
	Game.data.offline.last_claim = TimeService.now() - 3 * 3600
	var p := Rewards.claim_offline()
	Router.toast(Loc.t("offline.claimed", {"time": TimeService.format_duration(int(p.seconds))}), &"reward")
