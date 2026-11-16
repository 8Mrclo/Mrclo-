extends Node
## Visits every screen through the Router and exercises a few interactions.
## godot --headless --path . res://tests/scenes/ui_smoke.tscn

const SCREENS := ["lobby", "mission_select", "agents", "equipment", "workshop", "store", "missions", "achievements", "codex", "settings", "tutorial", "credits"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Detach from current_scene so Router scene changes don't free the driver.
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Saves.store = SaveStore.new("user://smoke_save")
	Saves.store.ensure_dir()
	Saves.store.wipe()
	InputSetup.ensure_actions()
	get_tree().root.theme = ThemeFactory.build()
	Saves.load_profile()
	Settings.apply_all()
	Objectives.refresh_periods()
	for id in SCREENS:
		Router.goto(id)
		await _frames(20)
		print("tela ok: ", id, " -> ", get_tree().current_scene.name)
	# Workshop tabs
	for tab in ["fusion", "recycle", "research", "history"]:
		get_tree().current_scene.set("_tab", tab)
		Router.goto("workshop")
		await _frames(3)
		get_tree().current_scene.set("_tab", tab)
		get_tree().current_scene.rebuild()
		await _frames(3)
		print("aba oficina ok: ", tab)
	for tab in Content.store.tabs:
		Router.goto("store")
		await _frames(3)
		get_tree().current_scene.set("_tab", tab)
		get_tree().current_scene.rebuild()
		await _frames(3)
		print("aba loja ok: ", tab)
	# Result + reveal with a fake finished run
	Game.last_result = {"map": "submerged_avenue", "mode": "expedition", "victory": true, "time": 600.0, "kills": 900, "elite_kills": 3, "level": 28, "hp_pct": 0.6, "damage_taken": 120.0, "damage_dealt": 50000.0, "evolutions": 1, "boss_kills": 1}
	Game.last_rewards = {"run": Rewards.grant({"scrap": 100, "item": {"rarity": "advanced"}}, "smoke"), "record": {"first_clear": true, "new_stars": [0], "unique": []}}
	Router.goto("battle_result")
	await _frames(6)
	print("tela ok: battle_result")
	Router.goto("reward_reveal", {"from": "battle"})
	await _frames(20)
	print("tela ok: reward_reveal")
	Router.goto_loaded("battle")
	await _frames(40)
	print("batalha via loading: ", get_tree().current_scene.name)
	var b := get_tree().current_scene
	if b is Battle:
		b.pause_panel.open()
		await _frames(3)
		b.pause_panel.close()
		b.debug_level_up()
		await _frames(5)
		print("painel de nível aberto: ", b.level_panel.is_open())
		b.level_panel._do_reroll()
		b.level_panel._pick(b.level_panel._offers[0])
		await _frames(3)
		b.finish(true)
		await _frames(30)
		print("após vitória: ", get_tree().current_scene.name)
	Saves.store.wipe()
	print("UI_SMOKE_OK")
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
