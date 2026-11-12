# PerkAudio — placeholder synthesis of the Vigor Tonic sound set (GAME_DESIGN §8, §16; DEVELOPMENT_
# PLAN Step 10 scope 3): each perk's ORIGINAL jingle (its PerkDefinition melody in its own timbre:
# organ, brass, bell or pluck), a purchase stinger (the jingle's first figure, faster, with a final
# chord), the drink (fizz + gulps + bottle clink), perk loss, the bottle vend clunk, the power-on
# hum and Second Wind's vanish shimmer. Final composed versions replace these in Step 15 under the
# same event names (`perk_jingle_<id>`, `perk_sting_<id>`).
# Authority: local presentation.
class_name PerkAudio
extends RefCounted

static var _done: bool = false


static func ensure() -> void:
	if _done:
		return
	_done = true
	for d: PerkDefinition in PerkCatalog.all():
		Audio.register_event(d.jingle_event(), jingle(d, 1.0, false), &"Music", -8.0)
		Audio.register_event(d.sting_event(), jingle(d, 0.6, true), &"Music", -4.0)
	Audio.register_event(&"perk_drink", _drink(), &"SFX", -4.0)
	Audio.register_event(&"perk_lost", _sweep(520.0, 140.0, 0.7), &"UI", -6.0)
	Audio.register_event(&"perk_vend", _clunk(), &"SFX", -3.0)
	Audio.register_event(&"perk_power_on", _sweep(55.0, 110.0, 1.2), &"SFX", -10.0)
	Audio.register_event(&"perk_vanish", _shimmer(1.4), &"SFX", -6.0)


# A melody rendered note by note; `tempo` scales the beat; `sting` keeps the first 4 notes and
# ends on a held major chord on the root.
static func jingle(d: PerkDefinition, tempo: float, sting: bool) -> AudioStreamWAV:
	var rate: int = WeaponAudio.RATE
	var notes: Array = []
	for i: int in d.jingle_notes.size():
		var beats: float = d.jingle_beats[i] if i < d.jingle_beats.size() else 1.0
		notes.append([d.jingle_notes[i], beats])
	if sting:
		notes = notes.slice(0, 4)
	var beat: float = d.jingle_beat_seconds * tempo
	var total: float = 0.0
	for n: Array in notes:
		total += float(n[1]) * beat
	var tail: float = 0.9 if sting else 0.5
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(rate * (total + tail)))
	var at: float = 0.0
	for n: Array in notes:
		var hz: float = d.jingle_root_hz * pow(2.0, float(n[0]) / 12.0)
		_note(out, int(at * rate), hz, float(n[1]) * beat * 1.1, d.jingle_wave, 0.28)
		at += float(n[1]) * beat
	if sting:
		for semis: int in [0, 4, 7, 12]:
			_note(out, int(at * rate), d.jingle_root_hz * pow(2.0, semis / 12.0), tail, d.jingle_wave, 0.16)
	return WeaponAudio._wav(out)


static func _note(out: PackedFloat32Array, start: int, hz: float, seconds: float, wave: int, gain: float) -> void:
	var rate: int = WeaponAudio.RATE
	var n: int = int(seconds * rate)
	for i: int in n:
		if start + i >= out.size():
			return
		var t: float = float(i) / rate
		var ph: float = hz * t
		var s: float = 0.0
		match wave:
			0:  # organ: odd harmonics
				s = sin(TAU * ph) + 0.33 * sin(TAU * ph * 3.0) + 0.2 * sin(TAU * ph * 5.0)
			1:  # brass: band-limited saw
				for h: int in range(1, 7):
					s += sin(TAU * ph * h) / h
			2:  # bell
				s = sin(TAU * ph) + 0.4 * sin(TAU * ph * 2.76) * exp(-t * 8.0)
			_:  # pluck
				s = (sin(TAU * ph) + 0.5 * sin(TAU * ph * 2.0)) * exp(-t * 6.0)
		var env: float = minf(t * 200.0, 1.0) * minf((seconds - t) * 30.0, 1.0)
		if wave == 2:
			env *= exp(-t * 3.0)
		out[start + i] += s * env * gain


static func _drink() -> AudioStreamWAV:
	var rate: int = WeaponAudio.RATE
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(rate * 2.4))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 808
	for i: int in int(rate * 0.5):  # cap pop + fizz
		var t: float = float(i) / rate
		out[i] += rng.randf_range(-1.0, 1.0) * exp(-t * 6.0) * 0.25 + sin(TAU * 900.0 * t) * exp(-t * 60.0) * 0.4
	for k: int in 3:  # gulps
		var start: int = int((0.7 + k * 0.42) * rate)
		for i: int in int(0.2 * rate):
			var t: float = float(i) / rate
			var f: float = 180.0 - t * 300.0
			if start + i < out.size():
				out[start + i] += sin(TAU * f * t) * sin(PI * t / 0.2) * 0.5
	var clink: int = int(2.05 * rate)  # bottle set down / clink
	for i: int in int(0.3 * rate):
		var t: float = float(i) / rate
		if clink + i < out.size():
			out[clink + i] += (sin(TAU * 2400.0 * t) + 0.5 * sin(TAU * 3700.0 * t)) * exp(-t * 18.0) * 0.3
	return WeaponAudio._wav(out)


static func _sweep(from_hz: float, to_hz: float, seconds: float) -> AudioStreamWAV:
	var rate: int = WeaponAudio.RATE
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(rate * seconds))
	var ph: float = 0.0
	for i: int in out.size():
		var u: float = float(i) / out.size()
		ph += lerpf(from_hz, to_hz, u) / rate
		out[i] = (sin(TAU * ph) + 0.3 * sin(TAU * ph * 2.0)) * sin(PI * u) * 0.35
	return WeaponAudio._wav(out)


static func _clunk() -> AudioStreamWAV:
	var rate: int = WeaponAudio.RATE
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(rate * 0.5))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	for i: int in out.size():
		var t: float = float(i) / rate
		var s: float = sin(TAU * 95.0 * t) * exp(-t * 14.0) + rng.randf_range(-1.0, 1.0) * exp(-t * 40.0) * 0.6
		if t > 0.33:  # bottle lands in the tray
			s += sin(TAU * 1900.0 * (t - 0.33)) * exp(-(t - 0.33) * 25.0) * 0.4
		out[i] = s * 0.6
	return WeaponAudio._wav(out)


static func _shimmer(seconds: float) -> AudioStreamWAV:
	var rate: int = WeaponAudio.RATE
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(rate * seconds))
	for i: int in out.size():
		var t: float = float(i) / rate
		var s: float = 0.0
		for k: int in 4:
			s += sin(TAU * (1200.0 + k * 370.0 + t * 400.0) * t) * (0.5 + 0.5 * sin(TAU * (5.0 + k) * t))
		out[i] = s * exp(-t * 2.0) * 0.08 * minf(t * 50.0, 1.0)
	return WeaponAudio._wav(out)
