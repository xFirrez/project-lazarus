# AmbienceLibrary — synthesized placeholder ambience loops (no third-party audio; Step 15 replaces
# them with recorded beds): storm wind with gusts, interior room tone with a faint electrical hum.
# Loops are generated once, seamless (whole periods of every modulation), cached, and registered as
# Audio events on the Ambience bus. Step 13 adds the per-zone beds (furnace, drips, machinery,
# refrigeration, reactor heartbeat, radio static, fluorescent buzz) and the gust swell one-shot.
# The reactor bed's pulse is exactly REACTOR_BPM so the core's light can follow its playback.
# Authority: local presentation.
class_name AmbienceLibrary
extends RefCounted

const RATE: int = 22050
const REACTOR_BPM: float = 48.0  # 0.8 Hz heartbeat (ReactorState / PoweredLight PULSE)
const EVENTS: Dictionary = {
	&"amb_storm_wind": "_storm_wind",
	&"amb_room_tone": "_room_tone",
	&"amb_furnace": "_furnace",
	&"amb_drips": "_drips",
	&"amb_machinery": "_machinery",
	&"amb_fridge": "_fridge",
	&"amb_reactor": "_reactor",
	&"amb_radio": "_radio",
	&"amb_buzz": "_buzz",
	&"amb_gust": "_gust",
}
const ONE_SHOTS: Array[StringName] = [&"amb_gust"]

static var _cache: Dictionary = {}


static func ensure_registered() -> void:
	for event: StringName in [&"amb_storm_wind", &"amb_room_tone", &"amb_gust"]:
		if not Audio.has_event(event):
			Audio.register_event(event, stream(event), &"Ambience", -6.0 if event != &"amb_gust" else -10.0)


static func stream(event: StringName) -> AudioStreamWAV:
	if not EVENTS.has(event):
		event = &"amb_room_tone"
	if not _cache.has(event):
		_cache[event] = Callable(AmbienceLibrary, EVENTS[event]).call() as AudioStreamWAV
	return _cache[event]


static func _storm_wind() -> AudioStreamWAV:
	var seconds: float = 8.0
	var n: int = int(RATE * seconds)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var lp1: float = 0.0
	var lp2: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		# Gusts: slow swells (periods that divide the loop length so it wraps seamlessly).
		var gust: float = 0.55 + 0.3 * sin(TAU * t / 8.0) + 0.15 * sin(TAU * t / 2.0 + 1.3)
		var cutoff: float = 0.02 + 0.05 * gust  # brighter whistle when it gusts
		lp1 += (rng.randf_range(-1.0, 1.0) - lp1) * cutoff
		lp2 += (lp1 - lp2) * cutoff
		var s: float = lp2 * 6.0 * gust
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 26000.0))
	return _wav(data)


static func _room_tone() -> AudioStreamWAV:
	var seconds: float = 4.0
	var n: int = int(RATE * seconds)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.01
		var hum: float = 0.04 * sin(TAU * 50.0 * t) + 0.015 * sin(TAU * 100.0 * t)
		data.encode_s16(i * 2, int(clampf(lp * 2.5 + hum, -1.0, 1.0) * 20000.0))
	return _wav(data)


static func _buffer(seconds: float) -> PackedByteArray:
	var data: PackedByteArray = PackedByteArray()
	data.resize(int(RATE * seconds) * 2)
	return data


static func _put(data: PackedByteArray, i: int, s: float, gain: float = 20000.0) -> void:
	data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * gain))


# Coal furnace: low roar (filtered noise) + 30 Hz rumble + crackles.
static func _furnace() -> AudioStreamWAV:
	var data: PackedByteArray = _buffer(4.0)
	var n: int = data.size() / 2
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 301
	var lp: float = 0.0
	var crack: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.03
		if rng.randf() < 0.0008:
			crack = rng.randf_range(0.3, 0.7)
		crack *= 0.993
		var swell: float = 0.8 + 0.2 * sin(TAU * t / 2.0)
		_put(data, i, lp * 4.0 * swell + 0.12 * sin(TAU * 30.0 * t) + crack * rng.randf_range(-1.0, 1.0))
	return _wav(data)


# Sparse water drips in a damp room (pitched blips with a short tail) over a quiet bed.
static func _drips() -> AudioStreamWAV:
	var data: PackedByteArray = _buffer(6.0)
	var n: int = data.size() / 2
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 302
	var lp: float = 0.0
	var drip_t: float = -1.0
	var drip_f: float = 900.0
	for i: int in n:
		var t: float = float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.006
		if rng.randf() < 0.00012 and t < 5.6:
			drip_t = t
			drip_f = rng.randf_range(700.0, 1400.0)
		var d: float = 0.0
		if drip_t >= 0.0:
			var dt: float = t - drip_t
			d = sin(TAU * drip_f * dt * (1.0 + dt * 3.0)) * exp(-dt * 30.0) * 0.6
		_put(data, i, lp * 2.0 + d)
	return _wav(data)


# Generator hall machinery: 50 Hz hum with harmonics, a 2 Hz mechanical thump, hiss.
static func _machinery() -> AudioStreamWAV:
	var data: PackedByteArray = _buffer(4.0)
	var n: int = data.size() / 2
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 303
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
		var hum: float = 0.18 * sin(TAU * 50.0 * t) + 0.09 * sin(TAU * 100.0 * t) + 0.04 * sin(TAU * 150.0 * t)
		var ph: float = fmod(t * 2.0, 1.0)
		var thump: float = 0.3 * sin(TAU * 45.0 * ph) * exp(-ph * 14.0)
		_put(data, i, hum + thump + lp * 0.35)
	return _wav(data)


# Refrigeration: compressor hum (detuned 60 / 120 Hz) with a slow beat, faint rattle.
static func _fridge() -> AudioStreamWAV:
	var data: PackedByteArray = _buffer(4.0)
	var n: int = data.size() / 2
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 304
	for i: int in n:
		var t: float = float(i) / RATE
		var hum: float = 0.14 * sin(TAU * 60.0 * t) + 0.1 * sin(TAU * 60.5 * t) + 0.05 * sin(TAU * 120.0 * t)
		_put(data, i, hum + rng.randf_range(-1.0, 1.0) * 0.015)
	return _wav(data)


# Reactor: deep choir-like drone (stacked fifths, slow chorus) + a heartbeat double-thump at
# REACTOR_BPM. 5 s = exactly 4 beats, so the loop wraps on a beat.
static func _reactor() -> AudioStreamWAV:
	var data: PackedByteArray = _buffer(5.0)
	var n: int = data.size() / 2
	var beat: float = 60.0 / REACTOR_BPM
	for i: int in n:
		var t: float = float(i) / RATE
		var drone: float = 0.0
		for f: float in [55.0, 82.4, 110.0, 164.8]:
			drone += sin(TAU * f * t + 0.6 * sin(TAU * 0.2 * t)) * 0.07
		var ph: float = fmod(t, beat)
		var thump: float = 0.5 * sin(TAU * 38.0 * ph) * exp(-ph * 9.0)
		var ph2: float = ph - 0.28
		if ph2 > 0.0:
			thump += 0.3 * sin(TAU * 34.0 * ph2) * exp(-ph2 * 11.0)
		_put(data, i, drone + thump)
	return _wav(data)


# Dead radios that still whisper: band-limited static with a wandering carrier tone.
static func _radio() -> AudioStreamWAV:
	var data: PackedByteArray = _buffer(4.0)
	var n: int = data.size() / 2
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 305
	var lp: float = 0.0
	var hp: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		var x: float = rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.35
		hp = lp - hp * 0.2
		var carrier: float = (
			0.06 * sin(TAU * (700.0 + 80.0 * sin(TAU * 0.5 * t)) * t) * (0.5 + 0.5 * sin(TAU * 0.25 * t))
		)
		_put(data, i, hp * 0.22 * (0.7 + 0.3 * sin(TAU * 1.0 * t)) + carrier)
	return _wav(data)


# Fluorescent tubes: 100 Hz buzz with odd harmonics and a little crackle.
static func _buzz() -> AudioStreamWAV:
	var data: PackedByteArray = _buffer(2.0)
	var n: int = data.size() / 2
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 306
	for i: int in n:
		var t: float = float(i) / RATE
		var b: float = 0.08 * sin(TAU * 100.0 * t) + 0.04 * sin(TAU * 300.0 * t) + 0.02 * sin(TAU * 500.0 * t)
		var c: float = rng.randf_range(-1.0, 1.0) * (0.15 if rng.randf() < 0.002 else 0.005)
		_put(data, i, b + c)
	return _wav(data)


# Gust swell one-shot (3.5 s): bright wind rising and falling.
static func _gust() -> AudioStreamWAV:
	var seconds: float = 3.5
	var data: PackedByteArray = _buffer(seconds)
	var n: int = data.size() / 2
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 307
	var lp1: float = 0.0
	var lp2: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		var env: float = sin(PI * t / seconds)
		var cutoff: float = 0.03 + 0.09 * env
		lp1 += (rng.randf_range(-1.0, 1.0) - lp1) * cutoff
		lp2 += (lp1 - lp2) * cutoff
		_put(data, i, lp2 * 7.0 * env, 24000.0)
	var w: AudioStreamWAV = _wav(data)
	w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return w


static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = data.size() / 2
	return w
