# QuestAudio — placeholder synthesis for the Step 14 quest / lore / secrets set: the subtle quest-step
# chime, carry pick-up / drop, reel click, a babble "voice" (direct and radio-filtered) for VO
# lines, radio static and contact tone, the music box tune and the original "Snowblind" song
# (a slow minor waltz on the Choir motif of East Wing room 3: A C E D / C B A), grinding bookcase,
# ice crack / shatter, drawer pull / slam, pod charge hum, cable spark + alarm, node break, pylon
# hit / repair, finale sting, core flare, raven hit, mirror flash, escort warning. Final recorded
# sounds replace these in Step 15 under the same names. Synthesized on a worker thread (D-065).
# Authority: local presentation.
class_name QuestAudio
extends RefCounted

const RATE: int = 22050
# The Choir motif (VESPER_PEAK §6.2 vignette 3) in Hz: A3 C4 E4 D4 C4 B3 A3.
const MOTIF: Array[float] = [220.0, 261.63, 329.63, 293.66, 261.63, 246.94, 220.0]

static var _done: bool = false


static func ensure() -> void:
	if _done:
		return
	_done = true
	Audio.track_task(WorkerThreadPool.add_task(func() -> void: _build.call_deferred(_synth())))


static func _synth() -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1963
	var voice: PackedFloat32Array = _babble(rng, 1.4)
	return [
		[&"quest_step", ProgressionAudio._chord([659.25, 987.77], 1.2), &"UI", -14.0],
		[&"carry_pick", ProgressionAudio._chord([392.0, 587.33], 0.6), &"SFX", -6.0],
		[&"carry_drop", ProgressionAudio._clank(rng, 160.0, 0.35), &"SFX", -4.0],
		[&"reel_click", ProgressionAudio._clank(rng, 900.0, 0.12), &"SFX", -6.0],
		[&"page_turn", ProgressionAudio._hiss(rng, 0.25, 0.5), &"UI", -10.0],
		[&"vo_voice", ProgressionAudio._wav(voice), &"VO", -4.0],
		[&"vo_voice_radio", ProgressionAudio._wav(_radio(rng, voice)), &"VO", -2.0],
		[&"radio_static", ProgressionAudio._hiss(rng, 1.6, 0.2), &"SFX", -6.0],
		[&"radio_contact", ProgressionAudio._chord([440.0, 554.37, 659.25], 1.4), &"SFX", -4.0],
		[&"radio_dial", ProgressionAudio._clank(rng, 1400.0, 0.06), &"SFX", -10.0],
		[&"music_box", ProgressionAudio._wav(_melody(MOTIF, 0.32, 2.0, 0.0)), &"SFX", -6.0],
		[&"snowblind", ProgressionAudio._wav(_song(rng)), &"Music", -2.0],
		[&"bookcase_grind", ProgressionAudio._sweep(rng, 50.0, 70.0, 2.2, 0.6), &"SFX", 0.0],
		[&"ice_crack", ProgressionAudio._shatter(rng), &"SFX", -4.0],
		[&"ice_shatter", ProgressionAudio._shatter(rng), &"SFX", 2.0],
		[&"drawer_pull", ProgressionAudio._sweep(rng, 120.0, 80.0, 0.5, 0.5), &"SFX", -2.0],
		[&"drawer_slam", ProgressionAudio._clank(rng, 110.0, 0.5), &"SFX", 0.0],
		[&"pod_charge", ProgressionAudio._pulse(220.0, 0.5), &"SFX", -6.0],
		[&"cable_spark", ProgressionAudio._buzz(rng, 300.0, 0.6), &"SFX", -2.0],
		[&"quest_alarm", ProgressionAudio._sweep(rng, 600.0, 900.0, 1.0, 0.0), &"SFX", -4.0],
		[&"node_break", ProgressionAudio._shatter(rng), &"SFX", 0.0],
		[&"pylon_hit", ProgressionAudio._clank(rng, 240.0, 0.3), &"SFX", -6.0],
		[&"pylon_repair", ProgressionAudio._chord([523.25], 0.2), &"SFX", -10.0],
		[&"pylon_down", ProgressionAudio._boom(rng, 1.5), &"SFX", 0.0],
		[&"finale_sting", ProgressionAudio._chord([110.0, 164.81, 220.0, 261.63], 3.0), &"Music", 0.0],
		[&"core_flare", ProgressionAudio._boom(rng, 4.0), &"SFX", 3.0],
		[&"raven_hit", ProgressionAudio._shatter(rng), &"SFX", -4.0],
		[&"mirror_flash", ProgressionAudio._sweep(rng, 1200.0, 200.0, 0.4, 0.3), &"SFX", -6.0],
		[&"escort_warning", ProgressionAudio._chord([880.0, 932.33], 0.3), &"UI", -8.0],
		[&"quest_fail", ProgressionAudio._sweep(rng, 300.0, 70.0, 1.4, 0.2), &"SFX", -2.0],
		[&"marked_whine", ProgressionAudio._sweep(rng, 1800.0, 2400.0, 1.2, 0.1), &"SFX", -6.0],
	]


static func _build(events: Array) -> void:
	for e: Array in events:
		Audio.register_event(e[0], e[1], e[2], e[3])


# Syllable-like noise bursts through two moving formants: unintelligible "speech" placeholder.
static func _babble(rng: RandomNumberGenerator, seconds: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = ProgressionAudio._buf(seconds)
	var t0: int = 0
	while t0 < out.size():
		var syl: int = int(RATE * rng.randf_range(0.09, 0.2))
		var f0: float = rng.randf_range(110.0, 170.0)
		var f1: float = rng.randf_range(400.0, 900.0)
		for i: int in syl:
			if t0 + i >= out.size():
				break
			var t: float = float(i) / RATE
			var env: float = sin(PI * float(i) / syl)
			var s: float = sin(TAU * f0 * t) * 0.45 + sin(TAU * f1 * t) * 0.25 * sin(TAU * f0 * 0.5 * t)
			out[t0 + i] = (s + rng.randf_range(-0.05, 0.05)) * env * 0.6
		t0 += syl + int(RATE * rng.randf_range(0.01, 0.06))
	return out


# Band-limited + crackle: the "radio" version of a voice.
static func _radio(rng: RandomNumberGenerator, src: PackedFloat32Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = src.duplicate()
	var lp: float = 0.0
	var hp: float = 0.0
	for i: int in out.size():
		lp += (out[i] - lp) * 0.35
		var band: float = lp - hp
		hp += (lp - hp) * 0.08
		out[i] = clampf(band * 2.2, -0.7, 0.7) + rng.randf_range(-0.04, 0.04)
	return out


static func _melody(notes: Array[float], step: float, tail: float, detune: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = ProgressionAudio._buf(notes.size() * step + tail)
	for k: int in notes.size():
		var start: int = int(k * step * RATE)
		var f: float = notes[k] * (1.0 + detune)
		for i: int in int((step + tail * 0.5) * RATE):
			if start + i >= out.size():
				break
			var t: float = float(i) / RATE
			var s: float = sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.0 * t) * 0.18 + sin(TAU * f * 4.0 * t) * 0.06
			out[start + i] += s * exp(-t * 3.5) * 0.45
	return out


# "Snowblind" (placeholder, ~19 s): the motif three times over a slow 3/4 bass, the last pass an
# octave higher, with a soft pad.
static func _song(_rng: RandomNumberGenerator) -> PackedFloat32Array:
	var beat: float = 0.6
	var phrase: Array[float] = MOTIF.duplicate()
	var notes: Array[float] = []
	for rep: int in 3:
		for n: float in phrase:
			notes.append(n * (2.0 if rep == 2 else 1.0))
		notes.append(0.0)
		notes.append(0.0)
	var out: PackedFloat32Array = ProgressionAudio._buf(notes.size() * beat + 3.0)
	var bass: Array[float] = [110.0, 87.31, 98.0, 82.41]
	for k: int in notes.size():
		var start: int = int(k * beat * RATE)
		var f: float = notes[k]
		var b: float = bass[int(k / 3.0) % bass.size()]
		for i: int in int(beat * 1.8 * RATE):
			if start + i >= out.size():
				break
			var t: float = float(i) / RATE
			var s: float = 0.0
			if f > 0.0:
				s += (sin(TAU * f * t) * 0.4 + sin(TAU * f * 2.0 * t) * 0.12) * exp(-t * 2.2)
			if k % 3 == 0:
				s += sin(TAU * b * t) * 0.3 * exp(-t * 1.5)
			s += sin(TAU * b * 1.5 * t) * 0.04  # pad
			out[start + i] += s * 0.5
	return out
