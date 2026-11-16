class_name RandomService
extends Node
## RandomService (autoload "Rng").
## Named, independently seedable streams keep runs reproducible: the "run"
## stream drives spawns/offers, "loot" drives drops, "fx" is cosmetic only.

var _streams: Dictionary = {}


func _ready() -> void:
	for stream_name in [&"run", &"loot", &"fx", &"meta"]:
		var r := RandomNumberGenerator.new()
		r.randomize()
		_streams[stream_name] = r


func stream(stream_name: StringName) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		var r := RandomNumberGenerator.new()
		r.randomize()
		_streams[stream_name] = r
	return _streams[stream_name]


## Seeds the battle streams. seed_value <= 0 means "random"; returns the seed used.
func seed_run(seed_value: int) -> int:
	var used := seed_value
	if used <= 0:
		var tmp := RandomNumberGenerator.new()
		tmp.randomize()
		used = tmp.randi_range(1, 2147483646)
	stream(&"run").seed = used
	stream(&"loot").seed = used * 31 + 7
	return used


static func weighted_index(rng: RandomNumberGenerator, weights: PackedFloat32Array) -> int:
	var total := 0.0
	for w in weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return -1
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= maxf(weights[i], 0.0)
		if roll <= 0.0:
			return i
	return weights.size() - 1


static func shuffle_with(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Deterministic integer seed from a string key (daily rotations etc.).
static func seed_from_key(key: String) -> int:
	return absi(key.hash()) + 1
