class_name TimeService
extends RefCounted
## Single source of wall-clock time. Tests override `override_unix` to simulate
## days, weeks and clock manipulation without touching the OS clock.

static var override_unix: int = -1


static func now() -> int:
	if override_unix >= 0:
		return override_unix
	return int(Time.get_unix_time_from_system())


## Local calendar day key, e.g. "2026-11-16". Uses local timezone bias.
static func day_key(unix: int = -1) -> String:
	var t := now() if unix < 0 else unix
	var local := t + _bias_seconds()
	var d := Time.get_date_dict_from_unix_time(local)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## ISO-like week key: days since epoch shifted so weeks start on Monday.
static func week_key(unix: int = -1) -> String:
	var t := now() if unix < 0 else unix
	var days := int(floor(float(t + _bias_seconds()) / 86400.0))
	# 1970-01-01 was a Thursday; +3 aligns week boundaries to Monday.
	return "W%d" % int(floor(float(days + 3) / 7.0))


static func seconds_to_next_day() -> int:
	var local := now() + _bias_seconds()
	return 86400 - (local % 86400)


static func seconds_to_next_week() -> int:
	var local := now() + _bias_seconds()
	var days := int(floor(float(local) / 86400.0))
	var day_in_week := (days + 3) % 7
	return (7 - day_in_week) * 86400 - (local % 86400)


static func format_duration(seconds: int) -> String:
	seconds = maxi(seconds, 0)
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	var s := seconds % 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	return "%02d:%02d" % [m, s]


static func _bias_seconds() -> int:
	if override_unix >= 0:
		return 0
	var tz := Time.get_time_zone_from_system()
	return int(tz.get("bias", 0)) * 60
