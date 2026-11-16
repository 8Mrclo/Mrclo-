extends Node
## Dev tool: renders key screens to PNG (needs a display, e.g. xvfb-run).
## godot --path . --resolution 720x1280 res://tools/screenshots.tscn -- <out_dir>

const SHOTS := ["lobby", "mission_select", "agents", "equipment", "workshop", "store", "missions", "settings"]

var out_dir := "user://screenshots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Saves.store = SaveStore.new("user://shot_save")
	Saves.store.ensure_dir()
	Saves.store.wipe()
	InputSetup.ensure_actions()
	Saves.load_profile()
	Settings.apply_all()
	get_tree().root.theme = ThemeFactory.build()
	Objectives.refresh_periods()
	for id in SHOTS:
		Router.goto(id)
		await _frames(30)
		_shot(id)
	Router.goto("workshop")
	await _frames(20)
	get_tree().current_scene.set("_tab", "research")
	get_tree().current_scene.rebuild()
	await _frames(10)
	_shot("research")
	Game.pending_run = Missions.build_run_config("submerged_avenue", "expedition", "normal", 7)
	Router.goto("battle")
	await _frames(20)
	var b: Battle = get_tree().current_scene
	DebugTools.invincible = true
	for i in 1500:
		b.hud.joystick.output = Vector2.from_angle(i * 0.01) * 0.7
		b._process(1.0 / 30.0)
		while b.level_panel.is_open():
			b.level_panel._pick(b.level_panel._offers[0])
	b.hud.joystick.output = Vector2.ZERO
	await _frames(10)
	_shot("battle")
	b.debug_level_up()
	await _frames(10)
	_shot("level_up")
	b.level_panel._pick(b.level_panel._offers[0])
	b.time = 538.0
	await _frames(240)
	_shot("boss")
	b.finish(true)
	await _frames(40)
	_shot("result")
	Saves.store.wipe()
	print("SHOTS_OK ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
