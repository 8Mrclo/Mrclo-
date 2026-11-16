extends Node
## AudioManager (autoload "Audio").
## Buses: Music, Ambience, SFX, UI. SFX use a fixed voice pool with priorities
## and a per-sound cooldown to cap simultaneous sounds. Music crossfades
## between two players; ducking lowers music during menus/bosses.

const VOICES := 12
const SFX := {
	&"click": {"f0": 900.0, "f1": 1200.0, "dur": 0.05, "wave": "tri", "vol": 0.35, "prio": 1, "bus": "UI"},
	&"confirm": {"f0": 660.0, "f1": 990.0, "dur": 0.14, "wave": "tri", "vol": 0.4, "prio": 1, "bus": "UI"},
	&"error": {"f0": 220.0, "f1": 160.0, "dur": 0.18, "wave": "square", "vol": 0.25, "prio": 1, "bus": "UI"},
	&"reward": {"f0": 520.0, "f1": 1560.0, "dur": 0.35, "wave": "tri", "vol": 0.4, "prio": 2, "bus": "UI"},
	&"hit": {"f0": 320.0, "f1": 120.0, "dur": 0.06, "wave": "square", "vol": 0.18, "noise": 0.4, "prio": 0, "bus": "SFX", "cooldown": 0.045},
	&"crit": {"f0": 880.0, "f1": 440.0, "dur": 0.08, "wave": "saw", "vol": 0.2, "prio": 1, "bus": "SFX", "cooldown": 0.06},
	&"kill": {"f0": 200.0, "f1": 60.0, "dur": 0.1, "wave": "sine", "vol": 0.25, "noise": 0.5, "prio": 0, "bus": "SFX", "cooldown": 0.05},
	&"pickup": {"f0": 1200.0, "f1": 1800.0, "dur": 0.05, "wave": "sine", "vol": 0.18, "prio": 0, "bus": "SFX", "cooldown": 0.04},
	&"level_up": {"f0": 440.0, "f1": 1320.0, "dur": 0.45, "wave": "tri", "vol": 0.45, "prio": 3, "bus": "SFX"},
	&"hurt": {"f0": 180.0, "f1": 90.0, "dur": 0.2, "wave": "saw", "vol": 0.35, "noise": 0.3, "prio": 3, "bus": "SFX", "cooldown": 0.15},
	&"zap": {"f0": 1600.0, "f1": 400.0, "dur": 0.12, "wave": "square", "vol": 0.16, "noise": 0.2, "prio": 1, "bus": "SFX", "cooldown": 0.08},
	&"boom": {"f0": 120.0, "f1": 40.0, "dur": 0.35, "wave": "sine", "vol": 0.45, "noise": 0.6, "prio": 2, "bus": "SFX", "cooldown": 0.1},
	&"shoot": {"f0": 700.0, "f1": 500.0, "dur": 0.05, "wave": "tri", "vol": 0.12, "prio": 0, "bus": "SFX", "cooldown": 0.06},
	&"telegraph": {"f0": 300.0, "f1": 600.0, "dur": 0.3, "wave": "tri", "vol": 0.3, "prio": 3, "bus": "SFX", "cooldown": 0.3},
	&"boss": {"f0": 90.0, "f1": 60.0, "dur": 0.9, "wave": "saw", "vol": 0.5, "prio": 4, "bus": "SFX"},
	&"evolve": {"f0": 330.0, "f1": 1760.0, "dur": 0.7, "wave": "tri", "vol": 0.45, "prio": 4, "bus": "SFX"},
}

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_prio: Array[int] = []
var _last_play: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _music_tracks: Dictionary = {}
var _current_track := ""
var _duck := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["Music", "Ambience", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	for key in SFX:
		_streams[key] = SoundSynth.make(SFX[key])
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)
		_voice_prio.append(0)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	add_child(_ambience)
	# Ambience: low filtered noise bed generated once.
	_ambience.stream = SoundSynth.make({"f0": 60.0, "f1": 70.0, "dur": 2.0, "wave": "sine", "vol": 0.15, "noise": 0.25, "decay": 0.0})
	(_ambience.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	(_ambience.stream as AudioStreamWAV).loop_end = int(2.0 * SoundSynth.RATE)


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func _track(id: String) -> AudioStream:
	if not _music_tracks.has(id):
		match id:
			"lobby": _music_tracks[id] = SoundSynth.make_music(110.0, 4, 92.0, 0.8)
			"battle": _music_tracks[id] = SoundSynth.make_music(98.0, 4, 128.0, 0.3)
			"boss": _music_tracks[id] = SoundSynth.make_music(82.4, 4, 140.0, 0.1)
			_: _music_tracks[id] = SoundSynth.make_music(110.0, 2, 100.0, 0.5)
	return _music_tracks[id]


func play_music(id: String, fade: float = 0.8) -> void:
	if id == _current_track or DisplayServer.get_name() == "headless":
		return
	_current_track = id
	var incoming := _music_b if _music_a.playing and _music_a.volume_db > -40.0 else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	incoming.stream = _track(id)
	incoming.volume_db = -40.0
	incoming.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(incoming, "volume_db", 0.0, fade)
	tw.tween_property(outgoing, "volume_db", -60.0, fade)
	tw.chain().tween_callback(outgoing.stop)
	if not _ambience.playing:
		_ambience.play()


func set_duck(active: bool) -> void:
	_duck = 0.45 if active else 1.0
	apply_volumes()


func play(id: StringName, pitch_jitter: float = 0.06) -> void:
	if not _streams.has(id):
		return
	var recipe: Dictionary = SFX[id]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(id, -10.0)) < float(recipe.get("cooldown", 0.0)):
		return
	_last_play[id] = now
	var prio := int(recipe.get("prio", 0))
	var slot := -1
	var lowest := 999
	for i in VOICES:
		if not _voices[i].playing:
			slot = i
			break
		if _voice_prio[i] < lowest:
			lowest = _voice_prio[i]
			slot = i
	if slot < 0 or (_voices[slot].playing and lowest > prio):
		return
	var p := _voices[slot]
	p.stream = _streams[id]
	p.bus = recipe.get("bus", "SFX")
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	_voice_prio[slot] = prio
	p.play()


func play_ui(id: StringName) -> void:
	play(id, 0.0)


func apply_volumes() -> void:
	_set_bus("Music", float(Settings.get_value("music_volume")) * _duck)
	_set_bus("Ambience", float(Settings.get_value("ambience_volume")))
	_set_bus("SFX", float(Settings.get_value("sfx_volume")))
	_set_bus("UI", float(Settings.get_value("ui_volume")))


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))
