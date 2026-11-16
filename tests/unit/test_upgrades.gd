extends TestCase


func _state(actives: Dictionary = {}, passives: Dictionary = {}, evolved: Dictionary = {}) -> Dictionary:
	return {"actives": actives, "passives": passives, "evolved": evolved, "max_actives": 6, "max_passives": 6, "luck": 1.0}


func _rng(s: int = 7) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_three_unique_offers() -> void:
	var offers := UpgradeOffer.build(_state({"disc_helix": 1}), _rng(), 3)
	eq(offers.size(), 3, "três ofertas")
	var ids := {}
	for o in offers:
		check(not ids.has(o.id), "sem duplicatas")
		ids[o.id] = true


func test_never_offers_maxed() -> void:
	var actives := {}
	for id in Content.active_order:
		actives[id] = 5
	for i in 30:
		for o in UpgradeOffer.build(_state(actives, {}), _rng(i), 3):
			check(o.kind != "active", "nenhuma ativa maximizada oferecida")


func test_evolution_offered_first() -> void:
	var offers := UpgradeOffer.build(_state({"disc_helix": 5}, {"vector_boots": 1}), _rng(), 3)
	eq(offers[0].kind, "evolution", "evolução vem primeiro")
	eq(offers[0].id, "gyro_ring", "evolução correta")


func test_no_evolution_without_passive_or_level() -> void:
	for o in UpgradeOffer.build(_state({"disc_helix": 4}, {"vector_boots": 1}), _rng(), 3):
		check(o.kind != "evolution", "nível 4 não evolui")
	for o in UpgradeOffer.build(_state({"disc_helix": 5}, {}), _rng(), 3):
		check(o.kind != "evolution", "sem módulo não evolui")


func test_fallback_when_everything_maxed() -> void:
	var a := {}
	var p := {}
	var evolved := {}
	for i in 6:
		a[Content.active_order[i]] = 5
		evolved[Content.active_order[i]] = "done"
		p[Content.passive_order[i]] = 5
	var offers := UpgradeOffer.build(_state(a, p, evolved), _rng(), 3)
	check(offers.size() >= 1, "sempre há ao menos uma opção")
	for o in offers:
		eq(o.kind, "fallback", "apenas suprimentos quando tudo está no máximo")


func test_slots_full_blocks_new_items() -> void:
	var a := {}
	for i in 6:
		a[Content.active_order[i]] = 1
	for s in 20:
		for o in UpgradeOffer.build(_state(a), _rng(s), 3):
			if o.kind == "active":
				check(a.has(o.id), "não oferece ativa nova com espaços cheios")


func test_seeded_offers_are_deterministic() -> void:
	var o1 := UpgradeOffer.build(_state({"disc_helix": 2}), _rng(99), 3)
	var o2 := UpgradeOffer.build(_state({"disc_helix": 2}), _rng(99), 3)
	eq(str(o1.map(func(o): return o.id)), str(o2.map(func(o): return o.id)), "mesma seed, mesmas ofertas")


func test_locked_offer_kept() -> void:
	var locked := {"kind": "passive", "id": "regen_core", "level_from": 0, "level_to": 1, "weight": 1.0}
	var offers := UpgradeOffer.build(_state(), _rng(), 3, locked)
	eq(offers[0].id, "regen_core", "opção bloqueada reaparece")
