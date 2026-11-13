# SurvivalAudio — placeholder procedural sounds for the survival loop (no third-party audio):
# round start / end stings, the match intro, purchase ok / denied, revive, downed, bleedout,
# respawn and game over. Registered once as Audio events (final audio in Step 15).
# Authority: local presentation.
class_name SurvivalAudio
extends RefCounted

static var _registered: bool = false


static func ensure_events() -> void:
	if _registered:
		return
	_registered = true
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 6061
	Audio.register_event(&"round_start", _sting([110.0, 104.0, 82.0], 0.55), &"Music", -2.0)
	Audio.register_event(&"round_end", _sting([82.0, 98.0, 123.0, 165.0], 0.45), &"Music", -2.0)
	Audio.register_event(&"match_intro", _sting([55.0, 58.0, 55.0], 1.2), &"Music", -4.0)
	Audio.register_event(&"game_over", _sting([98.0, 92.0, 82.0, 73.0, 55.0], 0.8), &"Music", 0.0)
	Audio.register_event(&"purchase", _sting([660.0, 880.0], 0.08), &"UI", -6.0)
	Audio.register_event(&"interact_ok", _sting([520.0], 0.06), &"UI", -10.0)
	Audio.register_event(&"purchase_denied", _sting([180.0, 150.0], 0.12), &"UI", -4.0)
	Audio.register_event(&"player_downed", _sting([196.0, 147.0, 98.0], 0.35), &"SFX", -2.0)
	Audio.register_event(&"player_revived", _sting([294.0, 392.0, 494.0], 0.18), &"SFX", -4.0)
	Audio.register_event(&"revive_start", _sting([330.0], 0.15), &"SFX", -8.0)
	Audio.register_event(&"player_bledout", _sting([110.0, 73.0], 0.6), &"SFX", -2.0)
	Audio.register_event(&"player_respawned", _sting([392.0, 523.0], 0.2), &"SFX", -6.0)
	# Step 8 map machines (placeholders): power cascade, klaxon, gondola / lift, chute, bridge.
	Audio.register_event(&"power_on", _sting([55.0, 73.0, 110.0, 147.0, 220.0], 0.5), &"SFX", 0.0)
	Audio.register_event(&"power_klaxon", _sting([392.0, 330.0, 392.0, 330.0], 0.3), &"SFX", -4.0)
	Audio.register_event(&"machine_depart", _sting([147.0, 165.0], 0.4), &"SFX", -6.0)
	Audio.register_event(&"machine_arrive", _sting([165.0, 131.0], 0.35), &"SFX", -6.0)
	Audio.register_event(&"chute_slide", _sting([220.0, 196.0, 175.0, 147.0], 0.25), &"SFX", -6.0)
	Audio.register_event(&"bridge_extend", _sting([98.0, 110.0, 123.0], 0.5), &"SFX", -4.0)
	Audio.register_event(&"points_tick", WeaponAudio._click(rng, 900.0, 0.03, 0.4), &"UI", -16.0)


# A short sequence of decaying sine notes with a little detune (organ-ish sting).
static func _sting(freqs: Array, note_s: float) -> AudioStreamWAV:
	var rate: int = 22050
	var per: int = int(note_s * rate)
	var data: PackedByteArray = PackedByteArray()
	data.resize(per * freqs.size() * 2)
	for n: int in freqs.size():
		var f: float = float(freqs[n])
		for i: int in per:
			var t: float = float(i) / rate
			var env: float = minf(t * 40.0, 1.0) * exp(-t * 2.5 / note_s)
			var v: float = (sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.003 * t) + 0.25 * sin(TAU * f * 0.5 * t)) * 0.35
			data.encode_s16((n * per + i) * 2, int(clampf(v * env, -1.0, 1.0) * 32000.0))
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	return s
