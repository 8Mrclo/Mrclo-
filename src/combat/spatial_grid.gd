class_name SpatialGrid
extends RefCounted
## Uniform grid rebuilt once per frame with a counting sort (allocation-free
## after warm-up). Queries return indices into the caller's entity array.

var cell_size: float
var origin: Vector2
var cols: int
var rows: int
var _cell_start := PackedInt32Array()
var _cell_count := PackedInt32Array()
var _items := PackedInt32Array()
var _item_cell := PackedInt32Array()


func _init(bounds: Rect2, cell: float = 96.0) -> void:
	cell_size = cell
	origin = bounds.position
	cols = maxi(1, int(ceil(bounds.size.x / cell)))
	rows = maxi(1, int(ceil(bounds.size.y / cell)))
	_cell_start.resize(cols * rows + 1)
	_cell_count.resize(cols * rows)


func cell_of(p: Vector2) -> int:
	var cx := clampi(int((p.x - origin.x) / cell_size), 0, cols - 1)
	var cy := clampi(int((p.y - origin.y) / cell_size), 0, rows - 1)
	return cy * cols + cx


## positions: array of entities exposing .position (Node2D)
func rebuild(entities: Array) -> void:
	var n := entities.size()
	if _items.size() < n:
		_items.resize(n * 2)
		_item_cell.resize(n * 2)
	_cell_count.fill(0)
	for i in n:
		var c := cell_of(entities[i].position)
		_item_cell[i] = c
		_cell_count[c] += 1
	var acc := 0
	for c in cols * rows:
		_cell_start[c] = acc
		acc += _cell_count[c]
	_cell_start[cols * rows] = acc
	_cell_count.fill(0)
	for i in n:
		var c := _item_cell[i]
		_items[_cell_start[c] + _cell_count[c]] = i
		_cell_count[c] += 1


## Appends indices of entities whose cells overlap the circle (broad phase).
func query(p: Vector2, radius: float, out: PackedInt32Array) -> void:
	out.clear()
	var x0 := clampi(int((p.x - radius - origin.x) / cell_size), 0, cols - 1)
	var x1 := clampi(int((p.x + radius - origin.x) / cell_size), 0, cols - 1)
	var y0 := clampi(int((p.y - radius - origin.y) / cell_size), 0, rows - 1)
	var y1 := clampi(int((p.y + radius - origin.y) / cell_size), 0, rows - 1)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var c := cy * cols + cx
			var s := _cell_start[c]
			for k in _cell_count[c]:
				out.append(_items[s + k])
