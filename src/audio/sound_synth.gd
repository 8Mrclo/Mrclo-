class_name SoundSynth
extends RefCounted
## Generates original placeholder sounds at startup (no third-party audio).
## Each recipe is a short PCM16 mono AudioStreamWAV.

const RATE := 22050


static func make(recipe: Dictionary) -> AudioStreamWAV:
	var dur := float(recipe.get("dur", 0.1))
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var f0 := float(recipe.get("f0", 440.0))
	var f1 := float(recipe.get("f1", f0))
	var wave: String = recipe.get("wave", "sine")
	var vol := float(recipe.get("vol", 0.5))
	var noise := float(recipe.get("noise", 0.0))
	var phase := 0.0
	var seed_state := 12345
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += TAU * f / RATE
		var s := 0.0
		match wave:
			"square": s = 1.0 if sin(phase) >= 0.0 else -1.0
			"saw": s = fmod(phase / TAU, 1.0) * 2.0 - 1.0
			"tri": s = asin(sin(phase)) * 2.0 / PI
			_: s = sin(phase)
		if noise > 0.0:
			seed_state = (seed_state * 1103515245 + 12345) & 0x7fffffff
			s = lerpf(s, float(seed_state) / 0x7fffffff * 2.0 - 1.0, noise)
		var env := minf(t * 40.0, 1.0) * pow(1.0 - t, float(recipe.get("decay", 2.0)))
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Simple procedural music loop: arpeggio over a bass line in a minor key.
static func make_music(root_hz: float, bars: int, bpm: float, mood: float) -> AudioStreamWAV:
	var beat := 60.0 / bpm
	var steps := bars * 8
	var step_len := beat / 2.0
	var n := int(steps * step_len * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var scale := [0, 3, 5, 7, 10, 12, 15, 17]
	var prog := [0, 5, 3, 4] if mood > 0.5 else [0, 3, 5, 3]
	var phase_a := 0.0
	var phase_b := 0.0
	for i in n:
		var tsec := float(i) / RATE
		var step := int(tsec / step_len)
		var in_step := fmod(tsec, step_len) / step_len
		var bar := (step / 8) % prog.size()
		var chord_root: int = scale[prog[bar]]
		var arp: int = scale[(step * 3 + prog[bar]) % scale.size()]
		var fa := root_hz * 2.0 * pow(2.0, (chord_root + arp) / 12.0)
		var fb := root_hz * 0.5 * pow(2.0, chord_root / 12.0)
		phase_a += TAU * fa / RATE
		phase_b += TAU * fb / RATE
		var lead := asin(sin(phase_a)) * 2.0 / PI * pow(1.0 - in_step, 3.0) * 0.22
		var bass := sin(phase_b) * 0.28
		var hat := 0.0
		if step % 2 == 1 and in_step < 0.08:
			hat = (randf() * 2.0 - 1.0) * 0.06 * (1.0 - in_step / 0.08)
		data.encode_s16(i * 2, int(clampf(lead + bass + hat, -1.0, 1.0) * 26000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w
