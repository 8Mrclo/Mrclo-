extends Node
## LocalizationManager (autoload "Loc").
## UI strings live in res://locale/<lang>.json (flat key -> text).
## Content strings are inline dictionaries {"pt_BR": "...", "en": "..."}
## resolved with text(). Fallback chain: current -> pt_BR -> key.

signal language_changed(lang: String)

const DEFAULT_LANG := "pt_BR"
const SUPPORTED := ["pt_BR", "en"]

var lang: String = DEFAULT_LANG
var _tables: Dictionary = {}


func _ready() -> void:
	for code in SUPPORTED:
		var data: Variant = JsonUtil.load_file("res://locale/%s.json" % code)
		_tables[code] = data if data is Dictionary else {}


func set_language(code: String) -> void:
	if code not in SUPPORTED:
		code = DEFAULT_LANG
	if code == lang:
		return
	lang = code
	TranslationServer.set_locale(code)
	language_changed.emit(code)


func has_key(key: String) -> bool:
	return _tables.get(lang, {}).has(key) or _tables.get(DEFAULT_LANG, {}).has(key)


## Translate a UI key. params are substituted into "{name}" placeholders.
func t(key: String, params: Dictionary = {}) -> String:
	var table: Dictionary = _tables.get(lang, {})
	var s: String
	if table.has(key):
		s = table[key]
	elif _tables.get(DEFAULT_LANG, {}).has(key):
		s = _tables[DEFAULT_LANG][key]
	else:
		s = key
	if not params.is_empty():
		s = s.format(params)
	return s


## Resolve an inline localized value from content data.
func text(value: Variant, params: Dictionary = {}) -> String:
	var s := ""
	if value is Dictionary:
		if value.has(lang):
			s = str(value[lang])
		elif value.has(DEFAULT_LANG):
			s = str(value[DEFAULT_LANG])
		elif not value.is_empty():
			s = str(value.values()[0])
	elif value is String:
		s = t(value) if has_key(value) else value
	else:
		s = str(value) if value != null else ""
	if not params.is_empty():
		s = s.format(params)
	return s


func currency_name(currency: String) -> String:
	if currency.begins_with("shard_"):
		var agent: Dictionary = Content.agent(currency.substr(6))
		return t("currency.shard_of", {"agent": text(agent.get("name", currency))})
	return t("currency." + currency)


func format_number(v: float) -> String:
	var n := int(round(v))
	if absi(n) >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if absi(n) >= 10000:
		return "%.1fk" % (n / 1000.0)
	return str(n)
