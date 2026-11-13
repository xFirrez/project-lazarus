# ScoreAudio — the final score and presentation sound set (DEVELOPMENT_PLAN Step 15 scope 6,
# GAME_DESIGN §16), composed and synthesized by the project (no third-party audio):
#   round_start      low brass / cello swell under a distorted children's-choir hum
#   round_end        descending piano figure over tolling bells
#   match_intro      the reactor drone rising into the round-start chord
#   special_warning  air-raid siren + radio static + a distorted, unintelligible announcement
#   special_music    the special-round sting (siren swells over the drone)
#   game_over        the slow descending bell / piano coda
#   game_over_sting  short low stab when the game-over dossier appears
#   music_<layer>    the dynamic-music loops (drone, pulse, tension, storm): 8 s, phase-locked so
#                    they play together in an AudioStreamSynchronized (MusicDirector)
#   ann_*            "Voice of the Mountain" announcer lines (layered whisper + low voice)
#   ui_*             menu focus tick, accept, back, page turn, pause
# The streams are rendered offline to `content/audio/score/*.wav` by tools/gen_audio.sh (this
# script's `render_all`), so a match never pays the synthesis; if a file is missing the event is
# synthesized at runtime on a worker thread.
# Authority: local presentation.
class_name ScoreAudio
extends RefCounted

const DIR: String = "res://content/audio/score"
const RATE: int = 22050
const LOOP_SECONDS: float = 8.0
const LAYERS: PackedStringArray = ["drone", "pulse", "tension", "storm"]
# event -> [bus, volume_db]
const EVENTS: Dictionary = {
	&"round_start": [&"Music", -1.0],
	&"round_end": [&"Music", -2.0],
	&"match_intro": [&"Music", -2.0],
	&"special_warning": [&"Music", -1.0],
	&"special_music": [&"Music", -3.0],
	&"game_over": [&"Music", 0.0],
	&"game_over_sting": [&"Music", -2.0],
	&"music_drone": [&"Music", 0.0],
	&"music_pulse": [&"Music", 0.0],
	&"music_tension": [&"Music", 0.0],
	&"music_storm": [&"Music", 0.0],
	&"ann_round_one": [&"VO", 0.0],
	&"ann_special": [&"VO", 0.0],
	&"ui_click": [&"UI", -6.0],
	&"ui_error": [&"UI", -6.0],
	&"ui_focus": [&"UI", -14.0],
	&"ui_accept": [&"UI", -6.0],
	&"ui_back": [&"UI", -8.0],
	&"ui_page": [&"UI", -10.0],
	&"ui_pause": [&"UI", -6.0],
}

static var _done: bool = false


static func ensure() -> void:
	if _done:
		return
	_done = true
	var missing: Array[StringName] = []
	for e: StringName in EVENTS:
		var path: String = "%s/%s.wav" % [DIR, e]
		var stream: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
		if stream == null:
			missing.append(e)
			continue
		_register(e, stream)
	if not missing.is_empty():
		Log.warn(&"audio", "ScoreAudio: %d streams not rendered, synthesizing (tools/gen_audio.sh)" % missing.size())
		Audio.track_task(WorkerThreadPool.add_task(func() -> void: _register_all.call_deferred(_synth(missing))))


static func _register(e: StringName, stream: AudioStream) -> void:
	var cfg: Array = EVENTS[e]
	if String(e).begins_with("music_") and stream is AudioStreamWAV:
		var w: AudioStreamWAV = (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(LOOP_SECONDS * w.mix_rate)
		stream = w
	Audio.register_final(e, stream, cfg[0], cfg[1])


static func _register_all(pairs: Array) -> void:
	for p: Array in pairs:
		_register(p[0], p[1])


static func _synth(events: Array[StringName]) -> Array:
	var out: Array = []
	for e: StringName in events:
		out.append([e, WeaponAudio._wav(render(e))])
	return out


# Offline renderer (tools/gen_audio.sh): writes every event to content/audio/score/<event>.wav.
static func render_all(dir: String = DIR) -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var n: int = 0
	for e: StringName in EVENTS:
		var w: AudioStreamWAV = WeaponAudio._wav(render(e))
		if w.save_to_wav(ProjectSettings.globalize_path("%s/%s.wav" % [dir, e])) == OK:
			n += 1
	return n


static func render(e: StringName) -> PackedFloat32Array:
	match e:
		&"round_start":
			return _round_start()
		&"round_end":
			return _round_end()
		&"match_intro":
			return _match_intro()
		&"special_warning":
			return _special_warning()
		&"special_music":
			return _special_music()
		&"game_over":
			return _game_over()
		&"game_over_sting":
			return _stab()
		&"music_drone":
			return _layer_drone()
		&"music_pulse":
			return _layer_pulse()
		&"music_tension":
			return _layer_tension()
		&"music_storm":
			return _layer_storm()
		&"ann_round_one":
			return announcer(7, 1962)
		&"ann_special":
			return announcer(5, 1957)
		&"ui_click":
			return _typewriter_key()
		&"ui_error":
			return _buzz()
		&"ui_focus":
			return _tick(2600.0, 0.025, 0.25)
		&"ui_accept":
			return _typewriter_return()
		&"ui_back":
			return _tick(900.0, 0.06, 0.35)
		&"ui_page":
			return _page_turn()
		&"ui_pause":
			return _bell_tone(523.25, 1.2, 0.18)
	return PackedFloat32Array()


# --- DSP building blocks -------------------------------------------------------------------------


static func _buf(seconds: float) -> PackedFloat32Array:
	var b: PackedFloat32Array = PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


static func _midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


# Bowed / brass voice: band-limited saw (harmonics 1..h) with a swell envelope and slow vibrato.
static func _bowed(
	out: PackedFloat32Array, at: float, dur: float, hz: float, gain: float, attack: float, harmonics: int = 8
) -> void:
	var start: int = int(at * RATE)
	var n: int = int(dur * RATE)
	for i: int in n:
		var k: int = start + i
		if k >= out.size():
			return
		var t: float = float(i) / RATE
		var env: float = minf(t / attack, 1.0) * minf((dur - t) / 0.6, 1.0)
		var vib: float = 1.0 + 0.004 * sin(TAU * 5.2 * t) * minf(t / 1.5, 1.0)
		var s: float = 0.0
		for h: int in range(1, harmonics + 1):
			s += sin(TAU * hz * vib * h * t) / h
		out[k] += s * env * gain


# Piano-ish: a few harmonics with a fast exponential decay and a hammer click.
static func _piano(out: PackedFloat32Array, at: float, dur: float, hz: float, gain: float) -> void:
	var start: int = int(at * RATE)
	var n: int = int(dur * RATE)
	for i: int in n:
		var k: int = start + i
		if k >= out.size():
			return
		var t: float = float(i) / RATE
		var env: float = exp(-t * 2.2) * minf(t * 400.0, 1.0)
		var s: float = sin(TAU * hz * t) + 0.45 * sin(TAU * hz * 2.0 * t) * exp(-t * 3.0)
		s += 0.2 * sin(TAU * hz * 3.01 * t) * exp(-t * 5.0)
		out[k] += s * env * gain


# Bell: inharmonic partials with long decays.
static func _bell(out: PackedFloat32Array, at: float, hz: float, gain: float, decay: float = 1.0) -> void:
	var partials: Array = [[1.0, 1.0, 0.9], [2.76, 0.5, 1.6], [5.4, 0.3, 2.6], [8.93, 0.18, 3.8], [0.5, 0.35, 0.7]]
	var start: int = int(at * RATE)
	var n: int = int(minf(5.0 * decay, 6.0) * RATE)
	for i: int in n:
		var k: int = start + i
		if k >= out.size():
			return
		var t: float = float(i) / RATE
		var s: float = 0.0
		for p: Array in partials:
			s += sin(TAU * hz * float(p[0]) * t) * float(p[1]) * exp(-t * float(p[2]) / decay)
		out[k] += s * gain * minf(t * 800.0, 1.0)


# Distorted children's choir hum: detuned "oo" voices, octave doubled, soft-clipped and tremolo'd.
static func _choir(out: PackedFloat32Array, at: float, dur: float, hz: float, gain: float) -> void:
	var start: int = int(at * RATE)
	var n: int = int(dur * RATE)
	var detune: Array = [-0.011, -0.004, 0.0, 0.006, 0.013]
	for i: int in n:
		var k: int = start + i
		if k >= out.size():
			return
		var t: float = float(i) / RATE
		var env: float = minf(t / 1.2, 1.0) * minf((dur - t) / 0.8, 1.0)
		var s: float = 0.0
		for d: float in detune:
			var f: float = hz * (1.0 + d)
			s += sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t) + 0.12 * sin(TAU * f * 3.0 * t)
		s = tanh(s * 0.9) * (0.75 + 0.25 * sin(TAU * 4.5 * t))
		out[k] += s * env * gain


static func _noise_band(
	out: PackedFloat32Array, at: float, dur: float, gain: float, smooth: float, rng: RandomNumberGenerator
) -> void:
	var start: int = int(at * RATE)
	var n: int = int(dur * RATE)
	var lp: float = 0.0
	var lp2: float = 0.0
	for i: int in n:
		var k: int = start + i
		if k >= out.size():
			return
		var t: float = float(i) / RATE
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), smooth)
		lp2 = lerpf(lp2, lp, smooth)
		var env: float = minf(t / 0.05, 1.0) * minf((dur - t) / 0.1, 1.0)
		out[k] += (lp - lp2) * 2.0 * env * gain


static func _siren(out: PackedFloat32Array, at: float, dur: float, gain: float) -> void:
	var start: int = int(at * RATE)
	var n: int = int(dur * RATE)
	var ph: float = 0.0
	for i: int in n:
		var k: int = start + i
		if k >= out.size():
			return
		var t: float = float(i) / RATE
		var rise: float = 0.5 - 0.5 * cos(TAU * t / dur)
		var hz: float = 300.0 + 520.0 * rise
		ph += hz / RATE
		var s: float = sin(TAU * ph) + 0.35 * sin(TAU * ph * 2.0) + 0.2 * sin(TAU * ph * 3.0)
		out[k] += tanh(s * 1.4) * gain * minf(t / 0.4, 1.0) * minf((dur - t) / 0.4, 1.0)


# "Voice of the Mountain": a low, formant-shaped voice doubled an octave down and layered with a
# breathy whisper (formant-filtered noise) — one burst per syllable (unintelligible by design; the
# words are the subtitles).
static func announcer(syllables: int, seed_value: int) -> PackedFloat32Array:
	var vowels: Array = [[730.0, 1090.0], [270.0, 2290.0], [530.0, 1840.0], [570.0, 840.0], [440.0, 1020.0]]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var syl: float = 0.27
	var out: PackedFloat32Array = _buf(syl * syllables + 1.2)
	var lp: float = 0.0
	for k: int in syllables:
		var v: Array = vowels[rng.randi() % vowels.size()]
		var start: int = int(k * syl * RATE)
		var f0: float = 82.0 * (1.1 if k == 0 else 1.0 - 0.03 * k)
		for i: int in int(syl * RATE):
			var t: float = float(i) / RATE
			var env: float = sin(PI * t / syl)
			var s: float = 0.0
			for h: int in range(1, 24):
				var fh: float = f0 * h
				var g: float = (
					exp(-pow((fh - float(v[0])) / 150.0, 2.0)) + 0.6 * exp(-pow((fh - float(v[1])) / 220.0, 2.0))
				)
				s += sin(TAU * fh * t) * g + 0.5 * sin(TAU * fh * 0.5 * t) * g
			lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.35)
			var whisper: float = lp * (0.5 + 0.5 * sin(TAU * float(v[1]) * t)) * 0.5
			out[start + i] += (s * 0.09 + whisper * 0.35) * env
	# A long, cavernous tail: a cheap multi-tap echo.
	for tap: Array in [[0.11, 0.35], [0.23, 0.22], [0.41, 0.12]]:
		var d: int = int(float(tap[0]) * RATE)
		for i: int in range(out.size() - 1, d, -1):
			out[i] += out[i - d] * float(tap[1])
	return _normalize(out, 0.7)


static func _normalize(out: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m: float = 0.0
	for v: float in out:
		m = maxf(m, absf(v))
	if m > 0.0:
		var g: float = peak / m
		for i: int in out.size():
			out[i] *= g
	return out


# --- cues ----------------------------------------------------------------------------------------


static func _round_start() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(5.5)
	# D minor with a flat-six lean: cello D2 + A2, brass F3 -> Bb3 swell, choir hum on D4 / F4.
	_bowed(out, 0.0, 5.0, _midi(38), 0.16, 1.4)
	_bowed(out, 0.2, 4.8, _midi(45), 0.11, 1.6)
	_bowed(out, 0.6, 2.2, _midi(53), 0.09, 0.9, 6)
	_bowed(out, 2.6, 2.6, _midi(58), 0.09, 0.6, 6)
	_choir(out, 0.9, 4.4, _midi(62), 0.05)
	_choir(out, 1.4, 3.9, _midi(65), 0.04)
	return _normalize(out, 0.8)


static func _round_end() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(6.0)
	var notes: Array = [74, 72, 69, 65, 62]
	for i: int in notes.size():
		_piano(out, i * 0.42, 2.6, _midi(notes[i]), 0.22)
		_piano(out, i * 0.42, 2.6, _midi(notes[i] - 12), 0.1)
	_bell(out, 0.0, _midi(62), 0.12, 1.4)
	_bell(out, 2.1, _midi(57), 0.12, 1.6)
	return _normalize(out, 0.75)


static func _match_intro() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(7.0)
	_bowed(out, 0.0, 6.6, _midi(26), 0.2, 3.0, 10)
	_bowed(out, 1.5, 5.1, _midi(38), 0.12, 2.5)
	_choir(out, 3.0, 3.8, _midi(62), 0.05)
	_bell(out, 5.2, _midi(50), 0.15, 1.2)
	return _normalize(out, 0.8)


static func _special_warning() -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 404
	var out: PackedFloat32Array = _buf(6.5)
	_siren(out, 0.0, 4.2, 0.2)
	_noise_band(out, 0.0, 6.4, 0.16, 0.6, rng)
	var voice: PackedFloat32Array = announcer(6, 1961)
	for i: int in voice.size():
		var k: int = i + int(2.2 * RATE)
		if k < out.size():
			# Radio announcement: clipped and band-limited (difference of two smoothings).
			out[k] += tanh(voice[i] * 3.0) * 0.35
	return _normalize(out, 0.8)


static func _special_music() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(9.0)
	_bowed(out, 0.0, 9.0, _midi(37), 0.15, 2.0, 10)
	_siren(out, 0.5, 3.5, 0.08)
	_siren(out, 4.8, 3.5, 0.07)
	_choir(out, 2.0, 6.5, _midi(61), 0.035)
	return _normalize(out, 0.7)


static func _game_over() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(9.0)
	var notes: Array = [69, 67, 65, 64, 62, 61, 62]
	for i: int in notes.size():
		_piano(out, i * 0.7, 3.0, _midi(notes[i]), 0.2)
	_bowed(out, 0.0, 8.5, _midi(38), 0.1, 2.0)
	_bell(out, 4.9, _midi(50), 0.18, 2.0)
	_choir(out, 4.0, 4.6, _midi(62), 0.03)
	return _normalize(out, 0.8)


static func _stab() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(2.5)
	_bowed(out, 0.0, 2.3, _midi(38), 0.2, 0.02, 10)
	_bowed(out, 0.0, 2.3, _midi(44), 0.12, 0.02, 8)
	_bell(out, 0.0, _midi(50), 0.15, 0.8)
	return _normalize(out, 0.7)


# Dynamic-music loops: every frequency / modulation rate is a multiple of 1/8 Hz so the 8 s loops
# are seamless and stay phase-locked when played together.
static func _q(hz: float) -> float:
	return roundf(hz * LOOP_SECONDS) / LOOP_SECONDS


static func _layer_drone() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(LOOP_SECONDS)
	var f: Array = [_q(_midi(26)), _q(_midi(26)) + 0.25, _q(_midi(33)), _q(_midi(38))]
	var g: Array = [0.2, 0.16, 0.08, 0.05]
	for i: int in out.size():
		var t: float = float(i) / RATE
		var s: float = 0.0
		for j: int in f.size():
			var hz: float = float(f[j])
			s += (sin(TAU * hz * t) + 0.3 * sin(TAU * hz * 2.0 * t)) * float(g[j])
		out[i] = s * (0.8 + 0.2 * sin(TAU * 0.125 * t))
	return _normalize(out, 0.55)


static func _layer_pulse() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(LOOP_SECONDS)
	# Heartbeat (lub-dub) every second, a muffled metal tick on the off-beat.
	for beat: int in 8:
		for k: Array in [[0.0, 1.0], [0.24, 0.65]]:
			var start: int = int((beat + float(k[0])) * RATE)
			for i: int in int(0.35 * RATE):
				var t: float = float(i) / RATE
				if start + i < out.size():
					out[start + i] += sin(TAU * (48.0 + 30.0 * exp(-t * 30.0)) * t) * exp(-t * 14.0) * 0.5 * float(k[1])
		var tick: int = int((beat + 0.5) * RATE)
		for i: int in int(0.05 * RATE):
			var t2: float = float(i) / RATE
			if tick + i < out.size():
				out[tick + i] += sin(TAU * 1730.0 * t2) * exp(-t2 * 90.0) * 0.08
	return _normalize(out, 0.6)


static func _layer_tension() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(LOOP_SECONDS)
	# Tremolo string cluster (D5, Eb5, A5) swelling in 4 s waves.
	var f: Array = [_q(_midi(74)), _q(_midi(75)), _q(_midi(81))]
	for i: int in out.size():
		var t: float = float(i) / RATE
		var s: float = 0.0
		for hz: float in f:
			for h: int in range(1, 5):
				s += sin(TAU * hz * h * t) / (h * h)
		var trem: float = 0.6 + 0.4 * sin(TAU * 7.0 * t)
		var swell: float = 0.55 - 0.45 * cos(TAU * 0.25 * t)
		out[i] = s * trem * swell * 0.12
	return _normalize(out, 0.45)


static func _layer_storm() -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 88
	var out: PackedFloat32Array = _buf(LOOP_SECONDS)
	_noise_band(out, 0.0, LOOP_SECONDS, 0.22, 0.25, rng)
	for i: int in out.size():
		var t: float = float(i) / RATE
		var hz: float = _q(140.0) + 60.0 * sin(TAU * 0.25 * t)
		out[i] = out[i] * (0.5 + 0.5 * sin(TAU * 0.5 * t)) + sin(TAU * _q(_midi(25)) * t) * 0.12
		out[i] += sin(TAU * hz * t) * 0.03
	# Seam: fade the noise across the loop boundary.
	var fade: int = int(0.05 * RATE)
	for i: int in fade:
		var k: float = float(i) / fade
		out[i] *= k
		out[out.size() - 1 - i] *= k
	return _normalize(out, 0.5)


# --- UI ------------------------------------------------------------------------------------------


static func _tick(hz: float, dur: float, gain: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(dur + 0.02)
	for i: int in out.size():
		var t: float = float(i) / RATE
		out[i] = sin(TAU * hz * t) * exp(-t * 6.0 / dur) * gain
	return out


static func _typewriter_key() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(0.09)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	_noise_band(out, 0.0, 0.02, 0.7, 0.95, rng)
	for i: int in out.size():
		var t: float = float(i) / RATE
		out[i] += sin(TAU * 310.0 * t) * exp(-t * 70.0) * 0.4
	return out


static func _buzz() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(0.22)
	for i: int in out.size():
		var t: float = float(i) / RATE
		var s: float = sin(TAU * 110.0 * t) + 0.5 * sin(TAU * 117.0 * t)
		out[i] = tanh(s * 2.0) * 0.25 * minf((0.22 - t) / 0.05, 1.0)
	return out


static func _typewriter_return() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(0.5)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	_noise_band(out, 0.0, 0.03, 0.6, 0.9, rng)
	_bell(out, 0.05, 1568.0, 0.12, 0.25)
	return out


static func _page_turn() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(0.35)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	_noise_band(out, 0.0, 0.32, 0.35, 0.5, rng)
	for i: int in out.size():
		var t: float = float(i) / RATE
		out[i] *= sin(PI * t / 0.35)
	return out


static func _bell_tone(hz: float, dur: float, gain: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(dur)
	_bell(out, 0.0, hz, gain, 0.5)
	return out
