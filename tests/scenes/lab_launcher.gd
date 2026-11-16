extends ScreenBase
## Isolated test scenes (debug builds). Uses a separate save slot so labs
## never touch real progress. Reachable from the debug menu.

const LABS := ["abilities", "enemies", "boss", "perf", "equipment", "store", "save", "rewards"]


func _ready() -> void:
	if Saves.store.dir_path != "user://lab_save":
		Saves.save_now()
		Saves.store = SaveStore.new("user://lab_save")
		Saves.load_profile()
	super._ready()


func build() -> void:
	add_header(Loc.t("lab.title"), false)
	header_box.add_child(UIKit.label(Loc.t("lab.note"), 19, Palette.AMBER, true))
	var list := scroll_body()
	for id in LABS:
		if id == "boss":
			for boss_id in Content.boss_ids:
				list.add_child(UIKit.button(Loc.t("lab.boss", {"name": Loc.text(Content.enemy(boss_id).name)}), func(): _battle("boss", boss_id), "secondary"))
		else:
			list.add_child(UIKit.button(Loc.t("lab." + id), func(): _open(id), "secondary"))
	list.add_child(UIKit.button(Loc.t("lab.exit"), _exit, "danger"))


func _battle(kind: String, boss_id: String = "") -> void:
	Game.pending_run = BattleLab.config(kind, boss_id)
	Router.goto_loaded("battle")


func _open(id: String) -> void:
	match id:
		"abilities", "enemies", "perf":
			_battle(id)
		"equipment":
			for i in 30:
				Rewards.grant({"item": {"rarity": Content.rarity_order[i % 4]}}, "lab")
			Economy.dev_grant_all()
			Router.goto("equipment")
		"store":
			Economy.dev_grant_all()
			Router.goto("store")
		"rewards":
			var res := {"map": "submerged_avenue", "mode": "expedition", "victory": true, "time": 600.0, "kills": 1200, "elite_kills": 3, "boss_kills": 1, "level": 30, "hp_pct": 0.7, "damage_taken": 100.0, "damage_dealt": 90000.0, "evolutions": 2, "progress": 1.0, "crate_key_roll": 0.0}
			Game.last_result = res
			Game.last_rewards = {"run": Rewards.grant(Rewards.compute_run_rewards(res), "lab"), "record": Missions.record_result(res)}
			Router.goto("battle_result")
		"save":
			_save_lab()


func _save_lab() -> void:
	var v := UIKit.vbox(8)
	var status := UIKit.label("", 19, Palette.MINT, true)
	v.add_child(status)
	v.add_child(UIKit.button(Loc.t("lab.save_now"), func(): status.text = "save: %s" % Saves.save_now(), "secondary"))
	v.add_child(UIKit.button(Loc.t("lab.corrupt"), func():
		var f := FileAccess.open(Saves.store.main_path(), FileAccess.WRITE)
		f.store_string("{corrompido")
		f.close()
		status.text = "main.sav corrompido", "danger"))
	v.add_child(UIKit.button(Loc.t("lab.reload"), func():
		var r := Saves.load_profile()
		status.text = "fonte: %s · corrompidos: %s · recuperado: %s" % [r.get("source", "-"), str(r.get("corrupted", [])), r.get("recovered", false)], "secondary"))
	v.add_child(UIKit.button(Loc.t("lab.migrate"), func():
		var d := SaveMigrations.migrate({"version": 1, "coins": 500, "gems": 9, "hero": "lia", "items": ["wpn_tide_staff"]})
		status.text = "v%d · sucata %d · itens %d" % [d.version, d.wallet.scrap, d.inventory.items.size()], "secondary"))
	Dialogs.info(Loc.t("lab.save"), v)


func _exit() -> void:
	Saves.store.wipe()
	Saves.store = SaveStore.new()
	Saves.load_profile()
	DebugTools.invincible = false
	Router.goto("lobby")
