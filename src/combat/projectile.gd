class_name Projectile
extends Node2D
## Pooled projectile. Data only + a cached _draw; ProjectileSystem moves it.

enum Kind { BOLT, SHARD, LANCE, MISSILE, ORB, LOB, SWARM }

var active := false
var hostile := false
var kind: int = Kind.BOLT
var vel := Vector2.ZERO
var speed := 400.0
var damage := 10.0
var radius := 8.0
var life := 2.0
var pierce := 0
var slot := -1
var flags := 0
var homing := 0.0
var target: Enemy = null
var target_uid := -1
var split_count := 0
var split_pct := 0.0
var split_depth := 0
var split_pierce := 0
var explode_radius := 0.0
var knock := 60.0
var color := Color.WHITE
var length := 0.0
var copies_left := 0
var hits := PackedInt32Array()
# Lob flight
var lob_from := Vector2.ZERO
var lob_to := Vector2.ZERO
var lob_t := 0.0
var lob_dur := 0.5
var on_land: Callable


func reset() -> void:
	active = true
	hostile = false
	kind = Kind.BOLT
	pierce = 0
	slot = -1
	flags = 0
	homing = 0.0
	target = null
	target_uid = -1
	split_count = 0
	split_pct = 0.0
	split_depth = 0
	split_pierce = 0
	explode_radius = 0.0
	knock = 60.0
	length = 0.0
	copies_left = 0
	hits.clear()
	on_land = Callable()
	scale = Vector2.ONE


func _draw() -> void:
	match kind:
		Kind.SHARD:
			draw_colored_polygon(PackedVector2Array([Vector2(radius * 1.4, 0), Vector2(0, -radius * 0.6), Vector2(-radius, 0), Vector2(0, radius * 0.6)]), color)
		Kind.LANCE:
			draw_line(Vector2(-length, 0), Vector2(length * 0.3, 0), Color(color, 0.4), radius * 2.2)
			draw_line(Vector2(-length, 0), Vector2(length * 0.3, 0), color, radius)
			draw_circle(Vector2(length * 0.3, 0), radius * 0.8, Color.WHITE)
		Kind.MISSILE:
			draw_rect(Rect2(-radius, -radius * 0.45, radius * 2, radius * 0.9), color)
			draw_circle(Vector2(-radius, 0), radius * 0.5, Palette.AMBER)
		Kind.ORB:
			draw_circle(Vector2.ZERO, radius * 1.4, Color(color, 0.3))
			draw_circle(Vector2.ZERO, radius, color)
			draw_circle(Vector2.ZERO, radius * 0.45, Color.WHITE)
		Kind.LOB:
			IconPainter.draw(self, "capsule", Vector2.ZERO, radius, color)
		Kind.SWARM:
			draw_circle(Vector2.ZERO, radius, color)
			draw_line(Vector2.ZERO, Vector2(-radius * 2.5, 0), Color(color, 0.5), radius * 0.8)
		_:
			draw_circle(Vector2.ZERO, radius * 1.3, Color(color, 0.35))
			draw_circle(Vector2.ZERO, radius, color)
