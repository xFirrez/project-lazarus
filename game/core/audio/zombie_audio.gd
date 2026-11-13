# ZombieAudio — placeholder zombie sounds (procedural, no third-party audio) registered as Audio
# events, plus the voice priority system (GAME_DESIGN §5.1: max 10 voiced zombies at a time,
# priority by distance to the listener). Voices are idle groans, aggro screams, attack vocals,
# pain and death; footsteps, barricade tearing and gibs are one-shot events.
# Authority: local presentation on every peer.
class_name ZombieAudio
extends RefCounted

const MAX_VOICES: int = 10
const RATE: int = 22050
const GROANS: int = 3

static var _registered: bool = false
static var _active: Dictionary = {}  # ZombieVisual instance id -> [end_time_ms, distance]
static var voices_started: int = 0
static var voices_denied: int = 0


static func ensure_events() -> void:
	if _registered:
		return
	_registered = true
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5150
	for i: int in GROANS:
		Audio.register_event(
			StringName("zombie_groan_%d" % i), _voice(rng, 95.0 + 20.0 * i, 1.3 + 0.3 * i, 0.5), &"Zombies", -8.0
		)
	Audio.register_event(&"zombie_scream", _voice(rng, 230.0, 0.9, 1.4), &"Zombies", -6.0)
	Audio.register_event(&"zombie_attack", _voice(rng, 180.0, 0.5, 1.8), &"Zombies", -3.0)
	Audio.register_event(&"zombie_pain", _voice(rng, 160.0, 0.3, 2.2), &"Zombies", -7.0)
	Audio.register_event(&"zombie_death", _voice(rng, 120.0, 1.1, 0.9), &"Zombies", -4.0)
	Audio.register_event(&"zombie_step", WeaponAudio._noise(rng, 0.85, 0.12, 60.0, 0.5, 30.0), &"Zombies", -14.0)
	Audio.register_event(&"zombie_tear", WeaponAudio._noise(rng, 0.55, 0.35, 0.0, 0.8, 7.0), &"Zombies", -4.0)
	Audio.register_event(&"zombie_gib", WeaponAudio._noise(rng, 0.7, 0.4, 70.0, 0.9, 9.0), &"Zombies", -2.0)
	Audio.register_event(&"zombie_body_fall", WeaponAudio._noise(rng, 0.9, 0.35, 50.0, 0.9, 10.0), &"Zombies", -6.0)
	Audio.register_event(&"barricade_tear", WeaponAudio._noise(rng, 0.45, 0.5, 220.0, 0.8, 6.0), &"SFX", -4.0)
	Audio.register_event(&"barricade_repair", WeaponAudio._click(rng, 380.0, 0.2, 0.8), &"SFX", -4.0)
	Audio.register_event(&"door_open", WeaponAudio._noise(rng, 0.9, 0.9, 70.0, 0.7, 3.0), &"SFX", -4.0)
	Audio.register_event(&"door_close", WeaponAudio._noise(rng, 0.9, 0.5, 60.0, 0.8, 6.0), &"SFX", -4.0)


static func groan_event(index: int) -> StringName:
	return StringName("zombie_groan_%d" % (index % GROANS))


# Voice priority: a zombie may start a voice line if fewer than MAX_VOICES are active, or if it
# is closer to the listener than the farthest active voice (which is then dropped from the count).
static func request_voice(owner_id: int, distance: float, seconds: float) -> bool:
	var now: int = Time.get_ticks_msec()
	for k: int in _active.keys():
		if int(_active[k][0]) <= now:
			_active.erase(k)
	if _active.size() >= MAX_VOICES and not _active.has(owner_id):
		var far_k: int = -1
		var far_d: float = -1.0
		for k: int in _active:
			if float(_active[k][1]) > far_d:
				far_d = float(_active[k][1])
				far_k = k
		if far_d <= distance:
			voices_denied += 1
			return false
		_active.erase(far_k)
	_active[owner_id] = [now + int(seconds * 1000.0), distance]
	voices_started += 1
	return true


static func active_voices() -> int:
	var now: int = Time.get_ticks_msec()
	var n: int = 0
	for k: int in _active:
		if int(_active[k][0]) > now:
			n += 1
	return n


static func reset_voices() -> void:
	_active.clear()
	voices_started = 0
	voices_denied = 0


# Vocal placeholder: a buzzy sawtooth with a wobbling pitch through a crude formant (low-pass).
static func _voice(rng: RandomNumberGenerator, hz: float, seconds: float, roughness: float) -> AudioStreamWAV:
	var n: int = int(RATE * seconds)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var lp: float = 0.0
	var wob: float = rng.randf_range(3.0, 6.0)
	for i: int in n:
		var t: float = float(i) / RATE
		var f: float = hz * (1.0 + 0.12 * sin(TAU * wob * t) + 0.25 * (1.0 - t / seconds))
		phase = fmod(phase + f / RATE, 1.0)
		var saw: float = phase * 2.0 - 1.0
		var noise: float = rng.randf_range(-1.0, 1.0) * 0.35 * roughness
		lp = lerpf(saw + noise, lp, 0.82)
		var env: float = minf(t * 12.0, 1.0) * minf((seconds - t) * 6.0, 1.0)
		out[i] = lp * env * 0.7
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	for i: int in n:
		data.encode_s16(i * 2, int(clampf(out[i], -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
