# PerkAudio — synthesis of the Vigor Tonic sound set (GAME_DESIGN §8, §16; DEVELOPMENT_PLAN Step 10
# scope 3, finalized in Step 15): each perk's ORIGINAL jingle (its PerkDefinition melody in its own
# timbre: organ, brass, bell or pluck) arranged as a 30–45 s idle piece (Step 15: an
# AudioStreamPlaylist of the melody, the melody with a bass line, the melody a fourth up and an
# octave-up bell variation, ending on the cadence), a purchase stinger (the jingle's first figure,
# faster, with a final chord), the drink (fizz + gulps + bottle clink), perk loss, the bottle vend
# clunk, the power-on hum and Second Wind's vanish shimmer. Events `perk_jingle_<id>`,
# `perk_sting_<id>`.
# Authority: local presentation.
class_name PerkAudio
extends RefCounted

# The 30–45 s idle arrangement: ABACBA… sections of ~3 s (slower tempo), sequenced in a playlist.
const ARRANGEMENT: String = "AABACBAACBAB"

static var _done: bool = false


static func ensure() -> void:
	if _done:
		return
	_done = true
	# Synthesis takes ~1 s of GDScript: run it on a worker thread so match setup (and a joining
	# client's network session) never stalls; events register on the main thread when ready.
	var defs: Array[PerkDefinition] = PerkCatalog.all()
	Audio.track_task(WorkerThreadPool.add_task(func() -> void: _build.call_deferred(_synth(defs))))


static func _synth(defs: Array[PerkDefinition]) -> Array:
	var out: Array = []
	for d: PerkDefinition in defs:
		out.append([d.jingle_event(), arrangement(d), &"Music", -8.0])
		out.append([d.sting_event(), jingle(d, 0.6, true), &"Music", -4.0])
	out.append([&"perk_drink", _drink(), &"SFX", -4.0])
	out.append([&"perk_lost", _sweep(520.0, 140.0, 0.7), &"UI", -6.0])
	out.append([&"perk_vend", _clunk(), &"SFX", -3.0])
	out.append([&"perk_power_on", _sweep(55.0, 110.0, 1.2), &"SFX", -10.0])
	out.append([&"perk_vanish", _shimmer(1.4), &"SFX", -6.0])
	return out


static func _build(events: Array) -> void:
	for e: Array in events:
		Audio.register_event(e[0], e[1], e[2], e[3])


static func arrangement(d: PerkDefinition) -> AudioStreamPlaylist:
	var sections: Dictionary = {
		"A": jingle(d, 1.3, false, 0, true),
		"B": jingle(d, 1.3, false, 5, true),
		"C": jingle(d, 1.3, false, 12, false, 2),
	}
	var pl: AudioStreamPlaylist = AudioStreamPlaylist.new()
	pl.loop = false
	pl.shuffle = false
	pl.fade_time = 0.05
	pl.stream_count = ARRANGEMENT.length() + 1
	for i: int in ARRANGEMENT.length():
		pl.set_list_stream(i, sections[ARRANGEMENT[i]])
	pl.set_list_stream(ARRANGEMENT.length(), jingle(d, 1.1, true, 0, true))
	return pl


static func arrangement_seconds(pl: AudioStreamPlaylist) -> float:
	var t: float = 0.0
	for i: int in pl.stream_count:
		t += pl.get_list_stream(i).get_length()
	return t


# A melody rendered note by note; `tempo` scales the beat; `sting` keeps the first 4 notes and
# ends on a held major chord on the root; `semis` transposes, `bass` adds a root / fifth pluck per
# bar, `wave_override` (>= 0) swaps the timbre (variation sections).
static func jingle(
	d: PerkDefinition, tempo: float, sting: bool, semis: int = 0, bass: bool = false, wave_override: int = -1
) -> AudioStreamWAV:
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
	var wave: int = d.jingle_wave if wave_override < 0 else wave_override
	var root: float = d.jingle_root_hz * pow(2.0, semis / 12.0)
	for n: Array in notes:
		var hz: float = root * pow(2.0, float(n[0]) / 12.0)
		_note(out, int(at * rate), hz, float(n[1]) * beat * 1.1, wave, 0.28)
		at += float(n[1]) * beat
	if bass:
		var bar: float = beat * 4.0
		var k: int = 0
		var bt: float = 0.0
		while bt < total:
			var bh: float = root * 0.5 * (1.0 if k % 2 == 0 else pow(2.0, 7.0 / 12.0))
			_note(out, int(bt * rate), bh, minf(bar * 0.9, total - bt + tail * 0.5), 3, 0.16)
			bt += bar
			k += 1
	if sting:
		for chord: int in [0, 4, 7, 12]:
			_note(out, int(at * rate), root * pow(2.0, chord / 12.0), tail, wave, 0.16)
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
