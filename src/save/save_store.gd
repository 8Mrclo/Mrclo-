class_name SaveStore
extends RefCounted
## File layer for saves: atomic writes + rotating backups.
## Write: main.tmp -> verify -> rotate backups (b2->b3, b1->b2, main->b1) -> tmp->main.
## Load: first slot that decodes (main, b1, b2, b3) wins; failures are reported.

const BACKUPS := 3

var dir_path: String
var last_load_report: Dictionary = {}


func _init(path: String = "user://save") -> void:
	dir_path = path


func main_path() -> String:
	return dir_path.path_join("main.sav")

func tmp_path() -> String:
	return dir_path.path_join("main.tmp")

func backup_path(i: int) -> String:
	return dir_path.path_join("backup_%d.sav" % i)


func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(dir_path)


func write(data: Dictionary) -> bool:
	ensure_dir()
	var text := SaveCodec.encode(data)
	var f := FileAccess.open(tmp_path(), FileAccess.WRITE)
	if f == null:
		push_error("Save: não foi possível abrir arquivo temporário (%d)" % FileAccess.get_open_error())
		return false
	f.store_string(text)
	f.flush()
	f.close()
	# Verify the temp file before touching the real slots.
	if not SaveCodec.decode(FileAccess.get_file_as_string(tmp_path())).ok:
		push_error("Save: verificação do temporário falhou")
		return false
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return false
	if dir.file_exists(backup_path(BACKUPS).get_file()):
		dir.remove(backup_path(BACKUPS).get_file())
	for i in range(BACKUPS - 1, 0, -1):
		var src := backup_path(i).get_file()
		if dir.file_exists(src):
			dir.rename(src, backup_path(i + 1).get_file())
	if dir.file_exists(main_path().get_file()):
		dir.rename(main_path().get_file(), backup_path(1).get_file())
	return dir.rename(tmp_path().get_file(), main_path().get_file()) == OK


## Returns {"ok", "data", "source", "corrupted": Array[String]}.
func load_latest() -> Dictionary:
	var corrupted: Array[String] = []
	var candidates: Array[String] = [main_path()]
	for i in range(1, BACKUPS + 1):
		candidates.append(backup_path(i))
	for path in candidates:
		if not FileAccess.file_exists(path):
			continue
		var res := SaveCodec.decode(FileAccess.get_file_as_string(path))
		if res.ok:
			last_load_report = {"ok": true, "data": res.data, "source": path.get_file(), "corrupted": corrupted}
			return last_load_report
		corrupted.append(path.get_file())
	last_load_report = {"ok": false, "data": {}, "source": "", "corrupted": corrupted}
	return last_load_report


func has_any() -> bool:
	if FileAccess.file_exists(main_path()):
		return true
	for i in range(1, BACKUPS + 1):
		if FileAccess.file_exists(backup_path(i)):
			return true
	return false


func wipe() -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
