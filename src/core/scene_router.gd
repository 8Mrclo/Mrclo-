extends Node
## SceneRouter (autoload "Router").
## Maps stable screen ids to scene files, performs short fade transitions,
## keeps a back stack and hosts global overlays (toasts, hints).

signal screen_changed(id: String)

const SCENES := {
	"boot": "res://scenes/boot/boot.tscn",
	"loading": "res://scenes/ui/loading.tscn",
	"lobby": "res://scenes/ui/main_lobby.tscn",
	"mission_select": "res://scenes/ui/mission_select.tscn",
	"agents": "res://scenes/ui/agent_select.tscn",
	"equipment": "res://scenes/ui/equipment.tscn",
	"workshop": "res://scenes/ui/workshop.tscn",
	"store": "res://scenes/ui/store.tscn",
	"missions": "res://scenes/ui/missions.tscn",
	"achievements": "res://scenes/ui/achievements.tscn",
	"codex": "res://scenes/ui/codex.tscn",
	"settings": "res://scenes/ui/settings.tscn",
	"battle": "res://scenes/battle/battle.tscn",
	"battle_result": "res://scenes/ui/battle_result.tscn",
	"reward_reveal": "res://scenes/ui/reward_reveal.tscn",
	"tutorial": "res://scenes/ui/tutorial.tscn",
	"credits": "res://scenes/ui/credits.tscn",
}

## Hub screens share the bottom navigation and never stack on each other.
const HUBS := ["lobby", "equipment", "agents", "missions", "store"]

var current_id := ""
var params: Dictionary = {}
var _stack: Array[String] = []
var _overlay: CanvasLayer
var _fade: ColorRect
var _toasts: VBoxContainer
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = CanvasLayer.new()
	_overlay.layer = 90
	add_child(_overlay)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.08, 0.1, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_fade)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-300, 120)
	_toasts.custom_minimum_size = Vector2(600, 0)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 8)
	_overlay.add_child(_toasts)
	EventBus.toast_requested.connect(_on_toast)
	get_viewport().size_changed.connect(_layout_overlay)
	_layout_overlay()


func goto(id: String, p: Dictionary = {}, push_history: bool = true) -> void:
	if not SCENES.has(id):
		push_error("Router: tela desconhecida %s" % id)
		return
	if _busy:
		return
	_busy = true
	if push_history and current_id != "" and current_id != id:
		if id in HUBS:
			_stack.clear()
		elif not current_id in ["battle", "loading", "boot", "battle_result", "reward_reveal"]:
			_stack.append(current_id)
	params = p
	var reduce: bool = bool(Settings.get_value("reduce_motion"))
	var t := 0.0 if reduce else 0.12
	if t > 0.0:
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, t)
		await tw.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENES[id])
	current_id = id
	screen_changed.emit(id)
	EventBus.emit_game(GameEvents.SCREEN_VISITED, 1.0, {"screen": id})
	Analytics.log_event("screen", {"id": id})
	if t > 0.0:
		var tw2 := create_tween()
		tw2.tween_property(_fade, "color:a", 0.0, t)
	else:
		_fade.color.a = 0.0
	_busy = false


func back() -> void:
	if _stack.is_empty():
		goto("lobby", {}, false)
	else:
		goto(_stack.pop_back(), {}, false)


## Loading screen used for heavy scenes (battle).
func goto_loaded(id: String, p: Dictionary = {}) -> void:
	goto("loading", {"target": id, "target_params": p})


func toast(text: String, kind: StringName = &"info") -> void:
	_on_toast(text, kind)


func _on_toast(text: String, kind: StringName) -> void:
	var panel := PanelContainer.new()
	var color := Palette.TEAL
	match kind:
		&"error": color = Palette.CORAL
		&"reward": color = Palette.AMBER
		&"warn": color = Palette.AMBER
	panel.add_theme_stylebox_override("panel", UIKit.box(Palette.panel_bg(), color, 2, 14))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	panel.add_child(lbl)
	_toasts.add_child(panel)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))
	var tw := panel.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(panel.queue_free)


func _layout_overlay() -> void:
	var vs := get_viewport().get_visible_rect().size
	_toasts.position = Vector2(vs.x * 0.5 - 300, 130)
