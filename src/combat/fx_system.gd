class_name FxSystem
extends RefCounted
## Spawns pooled effects. Cosmetic effects respect the graphics-profile limit
## and are skipped when it is reached; telegraphs use a separate pool that is
## never starved, because they carry gameplay information.

const POOL := &"fx"
const TELE_POOL := &"fx_tele"

var battle: Battle
var nodes: Array[FxNode] = []
var reduce_motion := false


func _init(b: Battle) -> void:
	battle = b
	reduce_motion = bool(Settings.get_value("reduce_motion"))


func _spawn(kind: int, pos: Vector2, life: float, color: Color, tele: bool = false) -> FxNode:
	var n: FxNode = battle.pools.acquire(TELE_POOL if tele else POOL)
	if n == null:
		return null
	n.kind = kind
	n.position = pos
	n.t = 0.0
	n.life = maxf(life, 0.05)
	n.color = color
	n.z_index = -1 if tele else 2
	nodes.append(n)
	return n


func ring(pos: Vector2, radius: float, life: float, color: Color) -> void:
	var n := _spawn(FxNode.Kind.RING, pos, life, color)
	if n:
		n.radius = radius


func burst(pos: Vector2, color: Color, size: float = 6.0) -> void:
	if reduce_motion:
		return
	var n := _spawn(FxNode.Kind.BURST, pos, 0.25, color)
	if n:
		n.width = size
		n.radius = randf() * TAU


func chain(points: PackedVector2Array, color: Color, width: float = 6.0) -> void:
	if points.size() < 2:
		return
	var n := _spawn(FxNode.Kind.CHAIN, points[0], 0.22, color)
	if n:
		n.points = points
		n.width = width


func beam(from: Vector2, to: Vector2, width: float, life: float, color: Color) -> void:
	var n := _spawn(FxNode.Kind.BEAM, from, life, color)
	if n:
		n.target = to
		n.width = width


func telegraph_circle(pos: Vector2, radius: float, duration: float, color: Color) -> void:
	var n := _spawn(FxNode.Kind.TELE_CIRCLE, pos, duration, color, true)
	if n:
		n.radius = radius


func telegraph_line(from: Vector2, to: Vector2, width: float, duration: float, color: Color) -> void:
	var n := _spawn(FxNode.Kind.TELE_LINE, from, duration, color, true)
	if n:
		n.target = to
		n.width = width


func flash(pos: Vector2, radius: float, color: Color) -> void:
	var n := _spawn(FxNode.Kind.FLASH, pos, 0.18, color)
	if n:
		n.radius = radius


func update(delta: float) -> void:
	var i := 0
	while i < nodes.size():
		var n := nodes[i]
		n.t += delta
		if n.t >= n.life:
			nodes[i] = nodes[nodes.size() - 1]
			nodes.pop_back()
			battle.pools.release(n)
			continue
		n.queue_redraw()
		i += 1


func count() -> int:
	return nodes.size()
