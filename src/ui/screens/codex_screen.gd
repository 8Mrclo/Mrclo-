extends ScreenBase
## Codex: discovered enemies, abilities/modules/evolutions, equipment, agents.

var _tab := "enemies"


func build() -> void:
	add_header(Loc.t("screen.codex"))
	var ids := ["enemies", "abilities", "items", "agents"]
	var labels: Array = ids.map(func(i): return Loc.t("codex.tab." + i))
	header_box.add_child(tabs(ids, labels, _tab, func(id): _tab = id; rebuild()))
	var list := scroll_body()
	var entries: Array = []
	match _tab:
		"enemies":
			for id in Content.enemy_order + Content.elite_ids + Content.boss_ids:
				entries.append({"def": Content.enemy(id), "known": Game.is_discovered("enemies", id), "shape": JsonUtil.dig(Content.enemy(id), "visual.shape", "hexagon"), "color": JsonUtil.dig(Content.enemy(id), "visual.color", "#ffffff"), "tag": _enemy_tag(id)})
		"abilities":
			for id in Content.active_order + Content.passive_order + Content.evolutions.keys():
				var d := Content.upgrade_def(id)
				entries.append({"def": d, "known": Game.is_discovered("abilities", id), "shape": JsonUtil.dig(d, "icon.shape", ""), "color": JsonUtil.dig(d, "icon.color", "#ffffff"), "tag": _ability_tag(id)})
		"items":
			for id in Content.item_order:
				var d := Content.item(id)
				entries.append({"def": d, "known": Game.is_discovered("items", id), "shape": d.icon.shape, "color": d.icon.color, "tag": Loc.t("slot." + d.slot)})
		"agents":
			for id in Content.agent_order:
				var d := Content.agent(id)
				entries.append({"def": d, "known": Agents.is_unlocked(id), "shape": "star", "color": d.visual.body, "tag": Loc.text(d.role)})
	var known := entries.filter(func(e): return e.known).size()
	list.add_child(UIKit.label(Loc.t("codex.progress", {"n": known, "max": entries.size()}), 20, Palette.text_muted()))
	for e in entries:
		var p := UIKit.panel(null)
		var h := UIKit.hbox(10)
		p.add_child(h)
		h.add_child(UIKit.icon(str(e.shape), JsonUtil.color(e.color, Palette.TEAL) if e.known else Palette.PETROL_LIGHT, 64))
		var v := UIKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(Loc.text(e.def.get("name", "")) if e.known else "???", 22, Palette.text()))
		v.add_child(UIKit.label(e.tag, 17, Palette.AMBER))
		v.add_child(UIKit.label(Loc.text(e.def.get("desc", "")) if e.known else Loc.t("codex.unknown"), 18, Palette.text_muted(), true))
		h.add_child(v)
		list.add_child(p)


func _enemy_tag(id: String) -> String:
	if id in Content.boss_ids:
		return Loc.t("codex.boss")
	if id in Content.elite_ids:
		return Loc.t("codex.elite")
	return Loc.t("codex.common")


func _ability_tag(id: String) -> String:
	if Content.evolutions.has(id):
		return Loc.t("codex.evolution")
	if Content.passives.has(id):
		return Loc.t("codex.module")
	return Loc.t("codex.active")
