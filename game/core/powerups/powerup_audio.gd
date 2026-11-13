# PowerUpAudio — synthesis of the power-up sound set (GAME_DESIGN §11, §16): the drop's appearance
# chime, the pickup sting, the "Voice of the Mountain" callout per type (Step 15: the layered
# whisper announcer, ScoreAudio.announcer, one syllable burst per spoken syllable; subtitled),
# the Nuke blast and the Carpenter hammering. Events: pu_spawn, pu_pickup, pu_vo_<type>, pu_nuke,
# pu_carpenter, pu_timer_end.
# Authority: local presentation.
class_name PowerUpAudio
extends RefCounted

const SYLLABLES: Dictionary = {
	&"max_ammo": 3,
	&"insta_kill": 4,
	&"double_points": 4,
	&"nuke": 1,
	&"carpenter": 3,
	&"fire_sale": 3,
	&"free_upgrade": 3,
}

static var _done: bool = false


static func ensure() -> void:
	if _done:
		return
	_done = true
	# Worker-thread synthesis (see PerkAudio.ensure): no stall at match setup.
	Audio.track_task(WorkerThreadPool.add_task(func() -> void: _build.call_deferred(_synth())))


static func _synth() -> Array:
	var out: Array = [
		[&"pu_spawn", _chime([1046.5, 1318.5, 1568.0], 0.09), &"SFX", -6.0],
		[&"pu_pickup", _chime([523.3, 659.3, 784.0, 1046.5], 0.07), &"SFX", -2.0],
		[&"pu_timer_end", _chime([784.0, 523.3], 0.12), &"UI", -6.0],
		[&"pu_nuke", _blast(), &"SFX", 0.0],
		[&"pu_carpenter", _hammer(), &"SFX", -2.0],
	]
	for type: StringName in SYLLABLES:
		var voice: PackedFloat32Array = ScoreAudio.announcer(int(SYLLABLES[type]), type.hash())
		out.append([StringName("pu_vo_%s" % type), WeaponAudio._wav(voice), &"VO", 0.0])
	return out


static func _build(events: Array) -> void:
	for e: Array in events:
		Audio.register_event(e[0], e[1], e[2], e[3])


static func _chime(freqs: Array, step: float) -> AudioStreamWAV:
	var rate: int = WeaponAudio.RATE
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(rate * (step * freqs.size() + 0.8)))
	for k: int in freqs.size():
		var start: int = int(k * step * rate)
		var hz: float = float(freqs[k])
		for i: int in int(0.8 * rate):
			if start + i >= out.size():
				break
			var t: float = float(i) / rate
			out[start + i] += (sin(TAU * hz * t) + 0.3 * sin(TAU * hz * 2.0 * t)) * exp(-t * 5.0) * 0.22
	return WeaponAudio._wav(out)


static func _blast() -> AudioStreamWAV:
	var rate: int = WeaponAudio.RATE
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(rate * 2.5))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	var lp: float = 0.0
	for i: int in out.size():
		var t: float = float(i) / rate
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.08)
		out[i] = (lp * 2.2 + sin(TAU * 38.0 * t) * 0.6) * exp(-t * 1.6) * minf(t * 80.0, 1.0) * 0.6
	return WeaponAudio._wav(out)


static func _hammer() -> AudioStreamWAV:
	var rate: int = WeaponAudio.RATE
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(rate * 1.4))
	for k: int in 4:
		var start: int = int(k * 0.3 * rate)
		for i: int in int(0.25 * rate):
			var t: float = float(i) / rate
			if start + i < out.size():
				out[start + i] += (sin(TAU * 1600.0 * t) * 0.5 + sin(TAU * 220.0 * t)) * exp(-t * 30.0) * 0.5
	return WeaponAudio._wav(out)
