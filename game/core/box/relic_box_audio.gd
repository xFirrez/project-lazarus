# RelicBoxAudio — placeholder synthesis of the Relic Box sound set (GAME_DESIGN §10.1, §16): an
# ORIGINAL music-box melody (a slow minor-key figure written for Project Lazarus), the lid bell
# chime, the result chime, the doll's laugh (pitched, wobbling "ha" bursts), the lid slam and the
# teleport-in thump. Final recorded/composed versions replace these in Step 15 under the same names.
# Authority: local presentation.
class_name RelicBoxAudio
extends RefCounted

const RATE: int = 22050
# Original melody: (semitone offset from A4, beats). 1 beat = 0.28 s.
const MELODY: Array = [[0, 1], [3, 1], [7, 2], [5, 1], [3, 1], [2, 2], [-2, 1], [0, 1], [3, 2], [2, 1], [-5, 3]]

static var _done: bool = false


static func ensure() -> void:
	if _done:
		return
	_done = true
	Audio.register_event(&"box_music", _music_box(), &"SFX", -6.0)
	Audio.register_event(&"box_open", _bell(1318.5, 1.4), &"SFX", -6.0)
	Audio.register_event(&"box_chime", _bell(1760.0, 1.0), &"SFX", -4.0)
	Audio.register_event(&"box_doll_laugh", _laugh(), &"SFX", -2.0)
	Audio.register_event(&"box_lid_slam", _thump(70.0, 0.45, 0.9), &"SFX", 0.0)
	Audio.register_event(&"box_land", _thump(48.0, 0.9, 0.7), &"SFX", -2.0)


static func _music_box() -> AudioStreamWAV:
	var beat: float = 0.28
	var total: float = 0.0
	for n: Array in MELODY:
		total += float(n[1]) * beat
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(RATE * (total + 1.0)))
	var at: float = 0.0
	for n: Array in MELODY:
		var hz: float = 440.0 * pow(2.0, float(n[0]) / 12.0) * 2.0
		var start: int = int(at * RATE)
		for i: int in int(RATE * 1.0):
			var t: float = float(i) / RATE
			var s: float = (sin(TAU * hz * t) + 0.35 * sin(TAU * hz * 2.01 * t)) * exp(-t * 5.0) * 0.3
			if start + i < out.size():
				out[start + i] += s
		at += float(n[1]) * beat
	return WeaponAudio._wav(out)


static func _bell(hz: float, seconds: float) -> AudioStreamWAV:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(RATE * seconds))
	for i: int in out.size():
		var t: float = float(i) / RATE
		var s: float = sin(TAU * hz * t) + 0.5 * sin(TAU * hz * 2.76 * t) * exp(-t * 6.0)
		out[i] = s * exp(-t * 3.0) * 0.4 * minf(t * 3000.0, 1.0)
	return WeaponAudio._wav(out)


static func _laugh() -> AudioStreamWAV:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(RATE * 1.6))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1908
	for k: int in 5:  # five "ha" syllables, rising then falling pitch
		var start: int = int((0.05 + k * 0.28) * RATE)
		var f0: float = 620.0 + 80.0 * sin(float(k) * 1.3)
		for i: int in int(0.2 * RATE):
			var t: float = float(i) / RATE
			var env: float = sin(PI * t / 0.2)
			var f: float = f0 * (1.0 + 0.08 * sin(TAU * 7.0 * t))
			var s: float = sin(TAU * f * t) * 0.5 + sin(TAU * f * 3.0 * t) * 0.15 + rng.randf_range(-0.1, 0.1)
			if start + i < out.size():
				out[start + i] += s * env * 0.5
	return WeaponAudio._wav(out)


static func _thump(hz: float, seconds: float, gain: float) -> AudioStreamWAV:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(RATE * seconds))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(hz)
	for i: int in out.size():
		var t: float = float(i) / RATE
		var s: float = sin(TAU * hz * (1.0 - 0.4 * t / seconds) * t) * 0.8 + rng.randf_range(-1.0, 1.0) * exp(-t * 30.0)
		out[i] = s * exp(-t * 7.0) * gain
	return WeaponAudio._wav(out)
