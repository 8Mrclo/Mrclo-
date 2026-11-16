extends TestCase


func test_content_validates() -> void:
	eq(Content.validation_errors.size(), 0, "sem erros: %s" % str(Content.validation_errors))


func test_required_counts() -> void:
	eq(Content.agent_order.size(), 6, "6 agentes")
	eq(Content.active_order.size(), 12, "12 ativas")
	eq(Content.passive_order.size(), 12, "12 passivas")
	check(Content.evolutions.size() >= 8, "8+ evoluções")
	check(Content.item_order.size() >= 24, "24+ equipamentos")
	var commons := Content.enemy_order.filter(func(id): return not Content.enemy(id).get("spawn_only", false))
	eq(commons.size(), 8, "8 inimigos comuns")
	eq(Content.elite_ids.size(), 4, "4 elites")
	eq(Content.boss_ids.size(), 4, "4 chefes")
	eq(Content.map_order.size(), 5, "5 mapas")
	eq(Content.mode_order.size(), 5, "5 modos")
	eq(Content.objectives.tutorial.size(), 20, "20 tutoriais")
	eq(Content.objectives.daily.size(), 30, "30 diárias")
	eq(Content.objectives.weekly.size(), 20, "20 semanais")
	eq(Content.achievements.size(), 40, "40 conquistas")
	check(Content.research_order.size() >= 30, "30+ nós de pesquisa")


func test_bosses_have_three_phases() -> void:
	for id in Content.boss_ids:
		eq(Content.enemy(id).phases.size(), 3, "%s com 3 fases" % id)
		check(Content.enemy(id).has("rewards"), "%s com recompensas" % id)


func test_each_map_has_three_objectives() -> void:
	for id in Content.map_order:
		eq(Content.map_def(id).objectives.size(), 3, id)


func test_all_ui_keys_localized() -> void:
	var missing: Array[String] = []
	var regex := RegEx.new()
	regex.compile("Loc\\.t\\(\"([a-zA-Z0-9_.]+)\"[,)]")
	var files: Array[String] = []
	_collect("res://src", files)
	for f in files:
		var text := FileAccess.get_file_as_string(f)
		for m in regex.search_all(text):
			var key := m.get_string(1)
			for lang in Loc.SUPPORTED:
				var table: Variant = JsonUtil.load_file("res://locale/%s.json" % lang)
				if not table.has(key):
					missing.append("%s (%s)" % [key, lang])
	eq(missing.size(), 0, "chaves ausentes: %s" % str(missing))


func test_dynamic_keys_localized() -> void:
	var missing: Array[String] = []
	for s in Content.stats:
		if not Loc.has_key("stat." + s): missing.append("stat." + s)
	for s in Content.slots:
		if not Loc.has_key("slot." + s): missing.append("slot." + s)
	for id in Content.active_order:
		for k in Content.active(id).levels[0]:
			if not Loc.has_key("param." + k): missing.append("param." + k)
	for o in Content.objectives.daily + Content.objectives.weekly + Content.objectives.tutorial + Content.achievements:
		if not Loc.has_key("objective." + o.event): missing.append("objective." + o.event)
	for c in Content.economy.currencies:
		if not Loc.has_key("currency." + c): missing.append("currency." + c)
	for s in Content.tutorial_steps:
		if not Loc.has_key("tutorial.step." + s.id): missing.append("tutorial.step." + s.id)
	for id in Content.research_order:
		var eff: Dictionary = Content.research_node(id).effect
		if eff.type == "meta" and not Loc.has_key("research.meta." + eff.key): missing.append(eff.key)
	eq(missing.size(), 0, "chaves dinâmicas ausentes: %s" % str(missing))


func _collect(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	for sub in d.get_directories():
		_collect(dir_path.path_join(sub), out)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
