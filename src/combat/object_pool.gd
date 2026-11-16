class_name ObjectPoolManager
extends Node
## Generic node pools keyed by type. Acquired nodes stay in the tree; inactive
## ones are hidden and skipped by systems, which avoids add/remove churn.

var _pools: Dictionary = {}       # type -> Array[Node]
var _factories: Dictionary = {}   # type -> Callable
var _parents: Dictionary = {}     # type -> Node
var _limits: Dictionary = {}
var _active_counts: Dictionary = {}


func register(type: StringName, factory: Callable, parent: Node, prewarm: int, limit: int) -> void:
	_factories[type] = factory
	_parents[type] = parent
	_limits[type] = limit
	_pools[type] = []
	_active_counts[type] = 0
	for i in prewarm:
		_pools[type].append(_create(type))


func _create(type: StringName) -> Node:
	var n: Node = _factories[type].call()
	n.set_meta("pool_type", type)
	if n is CanvasItem:
		n.visible = false
	_parents[type].add_child(n)
	return n


## Returns null when the type's active limit is reached (caller must handle).
func acquire(type: StringName) -> Node:
	if int(_active_counts[type]) >= int(_limits[type]):
		return null
	var pool: Array = _pools[type]
	var n: Node = pool.pop_back() if not pool.is_empty() else _create(type)
	_active_counts[type] += 1
	if n is CanvasItem:
		n.visible = true
	return n


func release(n: Node) -> void:
	var type: StringName = n.get_meta("pool_type")
	if n is CanvasItem:
		n.visible = false
	_pools[type].append(n)
	_active_counts[type] = maxi(int(_active_counts[type]) - 1, 0)


func active_count(type: StringName) -> int:
	return int(_active_counts.get(type, 0))


func pooled_count(type: StringName) -> int:
	return _pools.get(type, []).size()
