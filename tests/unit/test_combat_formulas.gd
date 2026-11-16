extends TestCase


func test_outgoing_damage_without_crit() -> void:
	var r := DamageCalculator.outgoing(10.0, 1.5, 1.0, 0.0, 2.0, 0.2, 0.5)
	eq(r.amount, 12.0, "10 × 1.5 × (1 - 0.2)")
	check(not r.crit, "sem crítico")


func test_crit_applies_multiplier() -> void:
	var r := DamageCalculator.outgoing(10.0, 1.0, 1.0, 0.5, 2.5, 0.0, 0.1)
	check(r.crit, "roll 0.1 < 0.5 deve critar")
	eq(r.amount, 25.0, "dano crítico")


func test_crit_mult_floor_and_chance_clamp() -> void:
	var r := DamageCalculator.outgoing(10.0, 1.0, 1.0, 5.0, 0.2, 0.0, 0.99)
	check(r.crit, "chance acima de 1 é limitada a 100%")
	eq(r.amount, 10.0, "multiplicador crítico nunca abaixo de 1")


func test_resist_is_capped() -> void:
	var r := DamageCalculator.outgoing(100.0, 1.0, 1.0, 0.0, 1.5, 5.0, 0.9)
	near(r.amount, 10.0, 0.001, "resistência máxima 90%")


func test_negative_inputs_never_heal() -> void:
	var r := DamageCalculator.outgoing(-50.0, -2.0, 1.0, 0.0, 1.5, 0.0, 0.9)
	eq(r.amount, 0.0, "dano negativo vira zero")


func test_incoming_armor_and_reduction() -> void:
	var r := DamageCalculator.incoming(100.0, 100.0, 0.2, 0.0, 0.9)
	near(r.amount, 40.0, 0.001, "100 × 100/200 × 0.8")


func test_incoming_reduction_cap_and_min() -> void:
	var r := DamageCalculator.incoming(1.0, 1000.0, 0.99, 0.0, 0.9, 1.0)
	eq(r.amount, 1.0, "dano mínimo garantido")
	var r2 := DamageCalculator.incoming(100.0, 0.0, 5.0, 0.0, 0.9)
	near(r2.amount, 25.0, 0.001, "redução de dano limitada a 75%")


func test_dodge_cap() -> void:
	var r := DamageCalculator.incoming(50.0, 0.0, 0.0, 0.95, 0.7)
	check(not r.dodged, "esquiva limitada a 60%")
	var r2 := DamageCalculator.incoming(50.0, 0.0, 0.0, 0.95, 0.5)
	check(r2.dodged, "roll 0.5 < 0.6 esquiva")


func test_interval_never_zero() -> void:
	near(DamageCalculator.interval(1.0, 0.0, 999.0), 0.05, 0.0001, "intervalo mínimo")
	near(DamageCalculator.interval(2.0, 0.5, 2.0), 0.5, 0.0001, "2 × 0.5 / 2")


func test_stat_block_order() -> void:
	var sb := StatBlock.new()
	sb.add({"stat": "max_hp", "op": "flat", "value": 20})
	sb.add({"stat": "max_hp", "op": "pct", "value": 0.5})
	sb.add({"stat": "max_hp", "op": "mult", "value": 0.1})
	near(sb.get_stat("max_hp"), (100 + 20) * 1.5 * 1.1, 0.001, "(base+flat)×(1+pct)×mult")


func test_stat_block_clamps_and_floors() -> void:
	var sb := StatBlock.new()
	sb.add({"stat": "cooldown", "op": "pct", "value": -5.0})
	near(sb.get_stat("cooldown"), 0.25, 0.0001, "recarga não passa do mínimo")
	sb.add({"stat": "crit_chance", "op": "flat", "value": 50.0})
	near(sb.get_stat("crit_chance"), 1.0, 0.0001, "chance crítica limitada a 1")
	sb.add({"stat": "damage", "op": "flat", "value": NAN})
	near(sb.get_stat("damage"), 1.0, 0.0001, "NaN ignorado")


func test_stat_block_remove_source() -> void:
	var sb := StatBlock.new()
	sb.add({"stat": "armor", "op": "flat", "value": 10, "source": "a"})
	sb.add({"stat": "armor", "op": "flat", "value": 5, "source": "b"})
	sb.remove_source("a")
	near(sb.get_stat("armor"), 5.0, 0.0001, "remoção por fonte")
