# AmbienceLibrary — synthesized placeholder ambience loops (no third-party audio; Step 15 replaces
# them with recorded beds): storm wind with gusts, interior room tone with a faint electrical hum.
# Loops are generated once, seamless (whole periods of every modulation), and registered as
# Audio events on the Ambience bus.
# Authority: local presentation.
class_name AmbienceLibrary
extends RefCounted

const RATE: int = 22050
const EVENTS: Dictionary = {&"amb_storm_wind": "_storm_wind", &"amb_room_tone": "_room_tone"}


static func ensure_registered() -> void:
	for event: StringName in EVENTS:
		if not Audio.has_event(event):
			var stream: AudioStreamWAV = Callable(AmbienceLibrary, EVENTS[event]).call() as AudioStreamWAV
			Audio.register_event(event, stream, &"Ambience", -6.0)


static func stream(event: StringName) -> AudioStreamWAV:
	return Callable(AmbienceLibrary, EVENTS[event]).call() as AudioStreamWAV


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
