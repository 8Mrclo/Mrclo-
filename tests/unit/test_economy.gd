extends TestCase


func test_transaction_atomic_on_insufficient_funds() -> void:
	var w := Wallet.new({"scrap": 100, "prisms": 5}, [])
	check(not w.transact({"scrap": 50, "prisms": 10}, {"field_data": 1}, "t"), "falha por saldo")
	eq(w.get_amount("scrap"), 100, "sucata intacta")
	eq(w.get_amount("field_data"), 0, "nenhum ganho parcial")
	eq(w.entries.size(), 0, "nada registrado")


func test_transaction_success_logged() -> void:
	var w := Wallet.new({"scrap": 100}, [])
	check(w.transact({"scrap": 40}, {"prisms": 3}, "teste"), "transação válida")
	eq(w.get_amount("scrap"), 60, "débito")
	eq(w.get_amount("prisms"), 3, "crédito")
	eq(w.entries.size(), 1, "registro no log")


func test_rejects_negative_and_nan() -> void:
	var w := Wallet.new({"scrap": 100}, [])
	check(not w.transact({"scrap": -10}, {}, "neg"), "custo negativo rejeitado")
	check(not w.transact({}, {"scrap": NAN}, "nan"), "NaN rejeitado")
	eq(w.get_amount("scrap"), 100, "saldo intacto")


func test_log_is_bounded() -> void:
	var w := Wallet.new({"scrap": 0}, [], 5)
	for i in 20:
		w.transact({}, {"scrap": 1}, "x")
	eq(w.entries.size(), 5, "log limitado")


func test_economy_manager_never_negative() -> void:
	fresh_profile()
	var bal := Economy.balance("scrap")
	check(not Economy.spend({"scrap": bal + 1}, "x"), "não gasta além do saldo")
	eq(Economy.balance("scrap"), bal, "saldo preservado")
	Economy.dev_set("scrap", -50)
	eq(Economy.balance("scrap"), 0, "dev_set não fica negativo")


func test_store_purchase_flow_and_limits() -> void:
	fresh_profile()
	var r := Store.purchase("free_daily_scrap")
	check(r.ok, "suprimento grátis")
	var r2 := Store.purchase("free_daily_scrap")
	check(not r2.ok and r2.error == "store.err_limit", "limite diário respeitado")


func test_store_insufficient_funds() -> void:
	fresh_profile()
	Economy.dev_set("prisms", 0)
	var r := Store.purchase("ex_prisms_to_scrap")
	check(not r.ok and r.error == "store.err_funds", "saldo insuficiente")


func test_daily_rotation_deterministic() -> void:
	var a := Store.daily_rotation("2026-11-16")
	var b := Store.daily_rotation("2026-11-16")
	var c := Store.daily_rotation("2026-11-17")
	eq(JSON.stringify(a), JSON.stringify(b), "mesma data, mesma rotação")
	check(JSON.stringify(a) != JSON.stringify(c), "datas diferentes mudam a rotação")
