extends Node
## TutorialManager (autoload "Tutorial").
## Contextual, non-blocking hints. Steps are "pending" until completed by an
## event or skipped by the player; they can be reset from Settings.

signal step_shown(step: Dictionary)
signal step_closed(step_id: String)

var _shown_this_session: Dictionary = {}


func _ready() -> void:
	EventBus.game_event.connect(_on_event)


func step_def(id: String) -> Dictionary:
	for s in Content.tutorial_steps:
		if s.id == id:
			return s
	return {}


func status(id: String) -> String:
	if Game.data.is_empty():
		return "pending"
	return str(Game.data.tutorial.steps.get(id, "pending"))


func is_enabled() -> bool:
	return not Game.data.is_empty() and bool(Game.data.tutorial.enabled)


## Called by screens/battle when a context is reached. Shows at most one hint.
func notify_context(context: String) -> void:
	if not is_enabled():
		return
	for s in Content.tutorial_steps:
		if s.context == context and status(s.id) == "pending" and not _shown_this_session.has(s.id):
			_shown_this_session[s.id] = true
			step_shown.emit(s)
			return


func complete(id: String) -> void:
	if status(id) == "done":
		return
	Game.data.tutorial.steps[id] = "done"
	EventBus.emit_game(GameEvents.TUTORIAL_STEP, 1.0, {"step": id})
	step_closed.emit(id)
	Game.save_soon()


func skip(id: String) -> void:
	var s := step_def(id)
	if s.is_empty() or not bool(s.get("skippable", true)):
		return
	Game.data.tutorial.steps[id] = "skipped"
	step_closed.emit(id)
	Game.save_soon()


func reset_all() -> void:
	Game.data.tutorial.steps = {}
	Game.data.tutorial.enabled = true
	_shown_this_session.clear()
	Game.save_soon()


func set_enabled(v: bool) -> void:
	Game.data.tutorial.enabled = v
	Game.save_soon()


func progress() -> Vector2i:
	var done := 0
	for s in Content.tutorial_steps:
		if status(s.id) != "pending":
			done += 1
	return Vector2i(done, Content.tutorial_steps.size())


func _on_event(type: StringName, _amount: float, data: Dictionary) -> void:
	if Game.data.is_empty():
		return
	for s in Content.tutorial_steps:
		if status(s.id) != "pending":
			continue
		if StringName(s.complete_on) == type:
			if type == GameEvents.SCREEN_VISITED and data.get("screen", "") != "agents":
				continue
			complete(s.id)
