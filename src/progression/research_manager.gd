extends Node
## ResearchManager (autoload "Research").
## Permanent tree. A node can be bought when every prerequisite has rank >= 1,
## it is below max rank and the player can afford the rank cost.


func rank(id: String) -> int:
	return int(Game.data.research.get(id, 0))


func cost(id: String) -> Dictionary:
	var node: Dictionary = Content.research_node(id)
	var growth := pow(float(Content.research_meta.get("cost_growth", 1.6)), rank(id))
	var out := {}
	for c in node.get("cost", {}):
		out[c] = int(round(float(node.cost[c]) * growth))
	return out


func missing_requirements(id: String) -> Array:
	var out: Array = []
	for req in Content.research_node(id).get("requires", []):
		if rank(req) < 1:
			out.append(req)
	return out


## "" when purchasable, otherwise a localization key.
func check(id: String) -> String:
	var node: Dictionary = Content.research_node(id)
	if node.is_empty():
		return "research.err_missing"
	if rank(id) >= int(node.get("max_rank", 1)):
		return "research.err_max"
	if not missing_requirements(id).is_empty():
		return "research.err_requires"
	if not Economy.can_afford(cost(id)):
		return "store.err_funds"
	return ""


func buy(id: String) -> String:
	var err := check(id)
	if err != "":
		return err
	if not Economy.transact(cost(id), {}, "research:" + id, false):
		return "store.err_funds"
	Game.data.research[id] = rank(id) + 1
	EventBus.emit_game(GameEvents.RESEARCH_PURCHASED, 1.0, {"node": id})
	Saves.save_now()
	EventBus.notifications_changed.emit()
	return ""


func modifiers() -> Array:
	var out: Array = []
	for id in Game.data.research:
		var r := rank(id)
		var eff: Dictionary = Content.research_node(id).get("effect", {})
		if r > 0 and eff.get("type", "") == "stat":
			out.append({"stat": eff.stat, "op": eff.op, "value": float(eff.value) * r, "source": "research"})
	return out


func meta_value(key: String) -> float:
	if Game.data.is_empty():
		return 0.0
	var total := 0.0
	for id in Game.data.research:
		var eff: Dictionary = Content.research_node(id).get("effect", {})
		if eff.get("type", "") == "meta" and eff.get("key", "") == key:
			total += float(eff.value) * rank(id)
	return total


func affordable_count() -> int:
	var n := 0
	for id in Content.research_order:
		if check(id) == "":
			n += 1
	return n
