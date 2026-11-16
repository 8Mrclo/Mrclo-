extends Node
## AnalyticsLocal (autoload "Analytics").
## Local-only ring buffer of gameplay events for balancing/debugging.
## Nothing leaves the device; the buffer is flushed to user://analytics.jsonl.

const MAX_EVENTS := 300
const FILE := "user://analytics.jsonl"

var events: Array = []
var enabled := true


func log_event(name: String, props: Dictionary = {}) -> void:
	if not enabled:
		return
	events.append({"t": TimeService.now(), "e": name, "p": props})
	if events.size() > MAX_EVENTS:
		events.pop_front()


func flush() -> void:
	if not enabled or events.is_empty():
		return
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f == null:
		return
	for e in events:
		f.store_line(JSON.stringify(e))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush()
