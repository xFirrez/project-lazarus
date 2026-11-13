# WonderAudio — placeholder synthesis for Step 12 (DEVELOPMENT_PLAN Step 12): the Ray Pistol's
# splash / bounce / disintegration, the Conduit's arc and pulse, Galvanic crackle / leap / death
# burst and energy rifts, the Warden's telegraph / slam / charge / summon / plate break / roar,
# the special-round warning, music sting and start, and buildable pickups / build completion.
# Built with ProgressionAudio's synth voices on a worker thread (D-065); final recorded sounds
# replace these in Step 15 under the same event names.
# Authority: local presentation.
class_name WonderAudio
extends RefCounted

static var _done: bool = false


static func ensure() -> void:
	if _done:
		return
	_done = true
	Audio.track_task(WorkerThreadPool.add_task(func() -> void: _build.call_deferred(_synth())))


# Short headless runs can quit while the worker is still synthesizing: skip if Audio is gone.
static func _build(events: Array) -> void:
	if not is_instance_valid(Audio) or not Audio.is_inside_tree():
		return
	ProgressionAudio._build(events)


static func _synth() -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1212
	return [
		[&"ray_splash", ProgressionAudio._sweep(rng, 900.0, 140.0, 0.6, 0.35), &"SFX", -1.0],
		[&"ray_bounce", ProgressionAudio._sweep(rng, 1400.0, 2200.0, 0.15, 0.05), &"SFX", -6.0],
		[&"ray_disintegrate", ProgressionAudio._hiss(rng, 0.9, 0.7), &"SFX", -5.0],
		[&"conduit_arc", ProgressionAudio._buzz(rng, 180.0, 0.35), &"SFX", -1.0],
		[&"conduit_pulse", ProgressionAudio._sweep(rng, 120.0, 900.0, 0.8, 0.4), &"SFX", 0.0],
		[&"galvanic_crackle", ProgressionAudio._buzz(rng, 420.0, 0.6), &"SFX", -2.0],
		[&"galvanic_leap", ProgressionAudio._sweep(rng, 300.0, 1200.0, 0.3, 0.2), &"SFX", -3.0],
		[&"galvanic_burst", ProgressionAudio._buzz(rng, 90.0, 0.5), &"SFX", 0.0],
		[&"rift_crackle", ProgressionAudio._sweep(rng, 60.0, 700.0, 1.5, 0.5), &"SFX", -2.0],
		[&"warden_telegraph", ProgressionAudio._sweep(rng, 70.0, 160.0, 0.8, 0.1), &"SFX", 2.0],
		[&"warden_slam", ProgressionAudio._boom(rng, 1.4), &"SFX", 3.0],
		[&"warden_charge", ProgressionAudio._sweep(rng, 50.0, 110.0, 1.6, 0.2), &"SFX", 1.0],
		[&"warden_summon", ProgressionAudio._chord([110.0, 146.83, 174.61], 1.2), &"SFX", 0.0],
		[&"warden_plate", ProgressionAudio._clank(rng, 260.0, 0.6), &"SFX", 1.0],
		[&"warden_roar", ProgressionAudio._sweep(rng, 140.0, 55.0, 1.5, 0.3), &"SFX", 3.0],
		[&"special_warning", ProgressionAudio._sweep(rng, 40.0, 220.0, 8.0, 0.3), &"SFX", 0.0],
		[&"special_music", ProgressionAudio._chord([98.0, 116.54, 146.83, 196.0], 6.0), &"Music", -4.0],
		[&"special_round_start", ProgressionAudio._chord([196.0, 233.08, 277.18], 2.0), &"Music", -2.0],
		[&"part_pickup", ProgressionAudio._chord([659.25, 987.77], 0.4), &"UI", -4.0],
		[&"build_done", ProgressionAudio._chord([523.25, 659.25, 783.99, 1046.5], 1.4), &"UI", -3.0],
	]
