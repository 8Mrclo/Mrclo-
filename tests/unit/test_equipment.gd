extends TestCase


func _clear_inventory() -> void:
	Game.data.inventory.items = {}
	for s in Content.slots:
		Game.data.equipped[s] = -1


func test_fusion_upgrades_rarity_and_keeps_level() -> void:
	_clear_inventory()
	var a := Inventory.add_item("wpn_coral_blade", "common")
	var b := Inventory.add_item("wpn_coral_blade", "common")
	var c := Inventory.add_item("wpn_coral_blade", "common")
	Inventory.get_item(b).level = 7
	var r := Inventory.fuse([a, b, c])
	check(r.ok, "fusão válida")
	eq(Inventory.get_item(a).rarity, "adjusted", "raridade seguinte")
	eq(Inventory.get_item(a).level, 7, "mantém maior nível")
	eq(Inventory.items().size(), 1, "consome os outros dois")


func test_fusion_rejects_mismatch_and_protected() -> void:
	_clear_inventory()
	var a := Inventory.add_item("wpn_coral_blade", "common")
	var b := Inventory.add_item("wpn_coral_blade", "common")
	var c := Inventory.add_item("wpn_arc_pistol", "common")
	check(not Inventory.fuse([a, b, c]).ok, "itens diferentes rejeitados")
	var d := Inventory.add_item("wpn_coral_blade", "common")
	Inventory.toggle_favorite(d)
	var r := Inventory.fuse([a, b, d])
	check(not r.ok and r.error == "fuse.err_protected", "favorito não é consumido")
	eq(Inventory.items().size(), 4, "nada perdido")


func test_fusion_max_rarity() -> void:
	_clear_inventory()
	var ids: Array = []
	for i in 3:
		ids.append(Inventory.add_item("dev_pulse_core", "anomalous"))
	check(not Inventory.fuse(ids).ok, "Anômalo não funde")


func test_batch_fuse_respects_protection() -> void:
	_clear_inventory()
	var eq_uid := Inventory.add_item("hlm_diver_dome", "common")
	Inventory.equip(eq_uid)
	for i in 4:
		Inventory.add_item("hlm_diver_dome", "common")
	var plan := Inventory.plan_batch_fuse()
	eq(plan.size(), 1, "um grupo (5 itens => 1 fusão)")
	check(plan[0][0] == eq_uid, "item equipado vira alvo, não consumível")
	Inventory.batch_fuse()
	check(not Inventory.get_item(eq_uid).is_empty(), "item equipado preservado")
	eq(Inventory.get_item(eq_uid).rarity, "adjusted", "e evoluiu")


func test_recycle_with_protection() -> void:
	_clear_inventory()
	var a := Inventory.add_item("glv_spark_grips", "common")
	var b := Inventory.add_item("glv_spark_grips", "adjusted")
	Inventory.equip(b)
	var before := Economy.balance("scrap")
	var r := Inventory.recycle([a, b])
	check(r.ok, "recicla o desprotegido")
	eq(r.count, 1, "apenas um reciclado")
	check(not Inventory.get_item(b).is_empty(), "equipado protegido")
	eq(Economy.balance("scrap"), before + ItemRules.recycle_value({"rarity": "common", "invested": 0}), "valor de reciclagem")


func test_upgrade_cost_and_max_level() -> void:
	_clear_inventory()
	Economy.dev_set("scrap", 1000000)
	Economy.dev_set("field_data", 10000)
	var u := Inventory.add_item("bts_magboots", "common")
	for i in 20:
		Inventory.upgrade(u)
	eq(Inventory.get_item(u).level, ItemRules.max_level("common"), "para no máximo da raridade")
	var r := Inventory.upgrade(u)
	check(not r.ok and r.error == "workshop.err_max_level", "erro no máximo")
	check(Inventory.get_item(u).invested > 0, "investimento registrado")


func test_reset_refund() -> void:
	_clear_inventory()
	Economy.dev_set("scrap", 100000)
	var u := Inventory.add_item("sut_plate_vest", "common")
	Inventory.upgrade(u)
	Inventory.upgrade(u)
	var invested: int = Inventory.get_item(u).invested
	var before := Economy.balance("scrap")
	var r := Inventory.reset_upgrade(u)
	check(r.ok, "redefinição")
	eq(Economy.balance("scrap") - before, int(floor(invested * 0.8)), "devolve 80%")
	eq(Inventory.get_item(u).level, 1, "volta ao nível 1")


func test_item_modifiers_by_rarity() -> void:
	var low := {"def": "wpn_tide_staff", "rarity": "common", "level": 1}
	var high := {"def": "wpn_tide_staff", "rarity": "relic", "level": 1}
	check(ItemRules.modifiers(high).size() > ItemRules.modifiers(low).size(), "raridade desbloqueia efeitos")
	check(ItemRules.power(high) > ItemRules.power(low), "maior poder")


func test_auto_equip_picks_best() -> void:
	_clear_inventory()
	var weak := Inventory.add_item("wpn_arc_pistol", "common")
	var strong := Inventory.add_item("wpn_joint_hammer", "singular")
	Inventory.auto_equip()
	eq(Inventory.equipped_uid("weapon"), strong, "equipa o mais forte")
	check(weak != strong, "uids distintos")
