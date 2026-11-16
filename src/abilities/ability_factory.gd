class_name AbilityFactory
extends RefCounted
## Maps data "behavior" strings to runtime classes.

const BEHAVIORS := {
	"orbit": preload("res://src/abilities/behaviors/orbit_ability.gd"),
	"chain": preload("res://src/abilities/behaviors/chain_ability.gd"),
	"drone": preload("res://src/abilities/behaviors/drone_ability.gd"),
	"beam": preload("res://src/abilities/behaviors/beam_ability.gd"),
	"lob": preload("res://src/abilities/behaviors/lob_ability.gd"),
	"zone_slow": preload("res://src/abilities/behaviors/zone_ability.gd"),
	"split": preload("res://src/abilities/behaviors/split_ability.gd"),
	"nova": preload("res://src/abilities/behaviors/nova_ability.gd"),
	"trail_mine": preload("res://src/abilities/behaviors/mine_ability.gd"),
	"lance": preload("res://src/abilities/behaviors/lance_ability.gd"),
	"swarm": preload("res://src/abilities/behaviors/swarm_ability.gd"),
	"vortex": preload("res://src/abilities/behaviors/vortex_ability.gd"),
}


static func create(b: Battle, def: Dictionary, slot: int) -> AbilityRuntime:
	var script: GDScript = BEHAVIORS.get(def.get("behavior", ""))
	if script == null:
		push_error("Comportamento desconhecido: %s" % def.get("behavior", ""))
		return null
	var a: AbilityRuntime = script.new()
	a.setup(b, def, slot)
	return a
