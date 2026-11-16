class_name Enemy
extends Node2D
## Pooled enemy entity. Holds state only; behavior runs centrally in
## EnemySystem (one loop instead of hundreds of _process callbacks).

enum Behavior { CHASER, FLYER, RANGED, SPLITTER, BUFFER, CHARGER, SHAPER, BOSS }
enum State { SPAWN, MOVE, TELEGRAPH, ACTION, RECOVER }

const HIT_SLOTS := 16
const BEHAVIOR_MAP := {
	"chaser": Behavior.CHASER, "flyer": Behavior.FLYER, "ranged": Behavior.RANGED,
	"splitter": Behavior.SPLITTER, "buffer": Behavior.BUFFER, "charger": Behavior.CHARGER,
	"shaper": Behavior.SHAPER, "boss": Behavior.BOSS,
}

var def: Dictionary
var enemy_id: String = ""
var uid := 0
var alive := false
var hp := 1.0
var max_hp := 1.0
var speed := 100.0
var damage := 5.0
var radius := 14.0
var resist := 0.0
var mass := 1.0
var xp_value := 1.0
var threat := 1.0
var is_elite := false
var is_boss := false
var is_champion := false
var flying := false
var behavior: int = Behavior.CHASER
var state: int = State.SPAWN
var state_t := 0.0
var cooldown := 0.0
var vel := Vector2.ZERO
var knock := Vector2.ZERO
var aux := Vector2.ZERO
var aux_i := 0
var slow_t := 0.0
var slow_f := 0.0
var stun_t := 0.0
var dot_t := 0.0
var dot_dps := 0.0
var mark_t := 0.0
var buff_t := 0.0
var buff_speed := 0.0
var buff_resist := 0.0
var flash_t := 0.0
var spawn_t := 0.0
var invuln_t := 0.0
var lod_acc := 0.0
var phase := 0.0
var targets_device := false
var dmg_accum := 0.0
var dmg_timer := 0.0
var dmg_crit := false
var hit_lock := PackedFloat32Array()
var shape := "triangle"
var body_color := Color.WHITE
var accent_color := Color.BLACK
var hidden_boss := false


func _init() -> void:
	hit_lock.resize(HIT_SLOTS)


func setup(d: Dictionary, variant: int, hp_mult: float, dmg_mult: float, spd_mult: float, champion: bool) -> void:
	def = d
	enemy_id = d.id
	is_elite = bool(d.get("is_elite", false))
	is_boss = bool(d.get("is_boss", false))
	is_champion = champion
	flying = bool(d.get("flying", false))
	behavior = BEHAVIOR_MAP.get(d.get("behavior", "chaser"), Behavior.CHASER)
	var champ_hp := float(Content.balance_value("enemy_scaling.champion_hp", 4.0)) if champion else 1.0
	var champ_size := float(Content.balance_value("enemy_scaling.champion_size", 1.35)) if champion else 1.0
	max_hp = maxf(float(d.hp) * hp_mult * champ_hp, 1.0)
	hp = max_hp
	damage = float(d.damage) * dmg_mult * (1.4 if champion else 1.0)
	speed = float(d.speed) * spd_mult
	radius = float(d.radius) * champ_size
	resist = float(d.get("resist", 0.0))
	mass = float(d.get("mass", 1.0)) * champ_size
	xp_value = float(d.get("xp", 1)) * (5.0 if champion else 1.0)
	threat = float(d.get("threat", 1.0))
	var vis: Dictionary = d.get("visual", {})
	shape = vis.get("shape", "triangle")
	var variants: Array = vis.get("variants", [vis.get("color", "#ffffff")])
	body_color = JsonUtil.color(variants[clampi(variant, 0, variants.size() - 1)], Color.WHITE)
	accent_color = JsonUtil.color(vis.get("accent", "#000000"), Color.BLACK)
	alive = true
	state = State.SPAWN
	state_t = 0.0
	spawn_t = 0.35
	cooldown = randf_range(0.5, 2.0)
	vel = Vector2.ZERO
	knock = Vector2.ZERO
	slow_t = 0.0; stun_t = 0.0; dot_t = 0.0; mark_t = 0.0; buff_t = 0.0; flash_t = 0.0; invuln_t = 0.0
	dmg_accum = 0.0; dmg_timer = 0.0
	aux_i = 0
	hidden_boss = false
	targets_device = false
	phase = randf() * TAU
	hit_lock.fill(0.0)
	modulate = Color(1, 1, 1, 0.3)
	rotation = 0.0
	queue_redraw()


func _draw() -> void:
	var r := radius
	if is_champion:
		draw_circle(Vector2.ZERO, r * 1.25, Color(Palette.AMBER, 0.25))
	if is_elite:
		draw_arc(Vector2.ZERO, r * 1.3, 0, TAU, 40, Palette.AMBER, 3.0)
	if is_boss:
		_draw_boss(r)
	else:
		draw_circle(Vector2(0, r * 0.35), r * 0.9, Color(0, 0, 0, 0.25))
		IconPainter.draw(self, shape, Vector2.ZERO, r, body_color)
		draw_circle(Vector2(r * 0.35, 0), r * 0.16, accent_color)
	if is_elite and not is_boss:
		var w := r * 2.2
		draw_rect(Rect2(-w / 2, -r - 14, w, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2, -r - 14, w * clampf(hp / max_hp, 0, 1), 6), Palette.CORAL)
	if DebugTools.show_hitboxes:
		draw_arc(Vector2.ZERO, r, 0, TAU, 24, Color.RED, 1.5)


func _draw_boss(r: float) -> void:
	draw_circle(Vector2(0, r * 0.3), r, Color(0, 0, 0, 0.3))
	match shape:
		"digger":
			draw_colored_polygon(PackedVector2Array([Vector2(-r, -r * 0.6), Vector2(r * 0.4, -r * 0.7), Vector2(r * 1.2, 0), Vector2(r * 0.4, r * 0.7), Vector2(-r, r * 0.6)]), body_color)
			for i in 4:
				draw_line(Vector2(r * 0.6, -r * 0.5 + i * r * 0.33), Vector2(r * 1.3, -r * 0.5 + i * r * 0.33), accent_color, 5)
			draw_circle(Vector2(-r * 0.2, 0), r * 0.3, accent_color)
		"queen":
			IconPainter.draw(self, "star", Vector2.ZERO, r, body_color)
			IconPainter.draw(self, "diamond", Vector2.ZERO, r * 0.55, accent_color)
		"archon":
			draw_rect(Rect2(-r * 0.45, -r, r * 0.9, r * 2), body_color.darkened(0.2))
			draw_circle(Vector2(0, -r * 0.6), r * 0.45, body_color)
			draw_arc(Vector2(0, -r * 0.6), r * 0.7, 0, TAU, 32, accent_color, 4)
		"colossus":
			draw_circle(Vector2.ZERO, r, body_color)
			for i in 7:
				var a := TAU * i / 7.0
				draw_line(Vector2.from_angle(a) * r * 0.6, Vector2.from_angle(a + 0.3) * r * 1.35, body_color.darkened(0.3), 8)
			draw_circle(Vector2(0, -r * 0.2), r * 0.3, accent_color)
		_:
			IconPainter.draw(self, "hexagon", Vector2.ZERO, r, body_color)


## Called by EnemySystem after flash/spawn timers change.
func refresh_tint() -> void:
	var a := 1.0
	if spawn_t > 0.0:
		a = 1.0 - spawn_t / 0.35 * 0.7
	if hidden_boss:
		a = 0.18
	if flash_t > 0.0:
		modulate = Color(2.2, 2.2, 2.2, a)
	elif stun_t > 0.0:
		modulate = Color(0.6, 0.9, 1.6, a)
	elif slow_t > 0.0:
		modulate = Color(0.75, 0.9, 1.25, a)
	else:
		modulate = Color(1, 1, 1, a)
