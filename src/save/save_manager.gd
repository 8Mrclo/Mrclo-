extends Node
## SaveManager (autoload "Saves").
## Owns persistence timing: explicit saves after important transactions,
## debounced saves for frequent changes and a periodic autosave.

signal saved
signal loaded(report: Dictionary)

const AUTOSAVE_SECONDS := 45.0
const DEBOUNCE_SECONDS := 1.5

var store := SaveStore.new()
var enabled := true            # tests disable disk IO
var _dirty := false
var _debounce := -1.0
var _autosave := AUTOSAVE_SECONDS


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _debounce >= 0.0:
		_debounce -= delta
		if _debounce < 0.0:
			save_now()
	_autosave -= delta
	if _autosave <= 0.0:
		_autosave = AUTOSAVE_SECONDS
		if _dirty:
			save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if Game.data.size() > 0:
			Game.touch_clock()
			save_now()


## Loads (or creates) the profile into Game.data. Returns a report for the UI.
func load_profile() -> Dictionary:
	var report := store.load_latest() if enabled else {"ok": false, "corrupted": []}
	var data: Dictionary
	var created := false
	if report.ok:
		data = SaveMigrations.migrate(report.data)
	else:
		data = SaveDefaults.create()
		created = true
	report["created"] = created
	report["recovered"] = report.ok and report.get("source", "") != "main.sav"
	Game.set_data(data)
	if created:
		Game.on_new_profile()
		save_now()
	loaded.emit(report)
	return report


func mark_dirty() -> void:
	_dirty = true
	if _debounce < 0.0:
		_debounce = DEBOUNCE_SECONDS


func save_now() -> bool:
	_debounce = -1.0
	if not enabled or Game.data.is_empty():
		return false
	var ok := store.write(Game.data)
	if ok:
		_dirty = false
		saved.emit()
	return ok


func wipe_and_reset() -> void:
	if enabled:
		store.wipe()
	Game.set_data(SaveDefaults.create())
	Game.on_new_profile()
	save_now()
