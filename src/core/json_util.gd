class_name JsonUtil
extends RefCounted
## Small helpers around JSON IO and dictionary defaults.


static func load_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("JSON ausente: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("JSON inválido: %s" % path)
	return parsed


## Recursively fills keys missing in target with copies from defaults.
## Existing values are kept even if their type differs (handled by migrations).
static func merge_defaults(target: Dictionary, defaults: Dictionary) -> void:
	for key in defaults:
		if not target.has(key):
			target[key] = _copy(defaults[key])
		elif target[key] is Dictionary and defaults[key] is Dictionary:
			merge_defaults(target[key], defaults[key])


static func _copy(v: Variant) -> Variant:
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	return v


static func get_path(d: Dictionary, path: String, fallback: Variant = null) -> Variant:
	var cur: Variant = d
	for part in path.split("."):
		if cur is Dictionary and cur.has(part):
			cur = cur[part]
		else:
			return fallback
	return cur


static func color(value: Variant, fallback: Color = Color.WHITE) -> Color:
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback
