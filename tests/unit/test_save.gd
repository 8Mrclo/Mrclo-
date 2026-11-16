extends TestCase

const DIR := "user://test_saves"


func _store() -> SaveStore:
	var s := SaveStore.new(DIR)
	s.ensure_dir()
	s.wipe()
	return s


func test_codec_roundtrip() -> void:
	var d := {"a": 1, "b": [1, 2], "c": {"x": "y"}}
	var r := SaveCodec.decode(SaveCodec.encode(d))
	check(r.ok, "decodifica")
	eq(r.data.c.x, "y", "conteúdo preservado")


func test_codec_detects_corruption() -> void:
	var text := SaveCodec.encode({"scrap": 10})
	var broken := text.replace("10", "99")
	check(not SaveCodec.decode(broken).ok, "checksum detecta alteração")
	check(not SaveCodec.decode("{lixo").ok, "JSON inválido rejeitado")
	check(not SaveCodec.decode("").ok, "vazio rejeitado")


func test_write_rotates_backups() -> void:
	var s := _store()
	for i in 5:
		check(s.write({"n": i}), "gravação %d" % i)
	check(FileAccess.file_exists(s.backup_path(3)), "terceiro backup existe")
	check(not FileAccess.file_exists(s.tmp_path()), "temporário removido")
	eq(int(s.load_latest().data.n), 4, "último salvo carregado")
	s.wipe()


func test_recovers_from_corrupted_main() -> void:
	var s := _store()
	s.write({"n": 1})
	s.write({"n": 2})
	var f := FileAccess.open(s.main_path(), FileAccess.WRITE)
	f.store_string("corrompido")
	f.close()
	var r := s.load_latest()
	check(r.ok, "recupera")
	eq(r.source, "backup_1.sav", "usa o backup")
	eq(int(r.data.n), 1, "dados do backup")
	check("main.sav" in r.corrupted, "reporta corrupção")
	s.wipe()


func test_all_corrupted_returns_failure() -> void:
	var s := _store()
	var f := FileAccess.open(s.main_path(), FileAccess.WRITE)
	f.store_string("x")
	f.close()
	check(not s.load_latest().ok, "sem dados válidos")
	s.wipe()


func test_full_profile_roundtrip() -> void:
	var s := _store()
	Inventory.add_item("dev_tide_compass", "advanced")
	Economy.earn({"prisms": 77}, "t")
	var prisms := Economy.balance("prisms")
	s.write(Game.data)
	var loaded := SaveMigrations.migrate(s.load_latest().data)
	eq(int(loaded.wallet.prisms), prisms, "moedas persistem")
	var found := false
	for k in loaded.inventory.items:
		if loaded.inventory.items[k].def == "dev_tide_compass":
			found = true
			check(loaded.inventory.items[k].uid is int, "uid volta a ser inteiro")
	check(found, "item persiste")
	s.wipe()


func test_migration_from_v1() -> void:
	var v1 := {"version": 1, "coins": 321, "gems": 12, "hero": "nara", "items": ["wpn_tide_staff", "item_que_nao_existe"]}
	var d := SaveMigrations.migrate(v1)
	eq(d.version, SaveDefaults.VERSION, "versão atual")
	eq(d.wallet.scrap, 321, "moedas migradas")
	eq(d.wallet.prisms, 12, "gemas viram prismas")
	eq(d.inventory.items.size(), 1, "itens inválidos descartados")
	check(d.has("research") and d.has("codex"), "campos novos com padrão")
	eq(d.selected_agent, "nara", "agente preservado")


func test_migration_fills_missing_and_fixes_invalid() -> void:
	var d := SaveDefaults.create()
	d.erase("store")
	d.wallet.scrap = -500
	d.selected_agent = "fantasma"
	d.equipped.weapon = 9999
	var m := SaveMigrations.migrate(d)
	check(m.has("store"), "campo ausente recriado")
	eq(m.wallet.scrap, 0, "saldo negativo corrigido")
	eq(m.selected_agent, "lia", "agente inválido corrigido")
	eq(m.equipped.weapon, -1, "equipado inexistente removido")
