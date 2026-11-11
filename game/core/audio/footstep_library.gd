# FootstepLibrary — registers per-surface footstep audio events (walk / sprint / land) with the
# Audio autoload: `footstep_<surface>_<kind>`. Placeholder sounds are synthesized noise bursts
# shaped per surface until real recordings arrive (Step 15). Remote players use the 3D variant.
# Authority: local presentation.
class_name FootstepLibrary
extends RefCounted

const KINDS: PackedStringArray = ["walk", "sprint", "land"]
# surface -> [low-pass smoothing 0..1 (higher = darker), length s, tonal Hz (0 = none)]
const SURFACES: Dictionary = {
	&"concrete": [0.55, 0.07, 0.0],
	&"metal": [0.2, 0.12, 420.0],
	&"wood": [0.7, 0.09, 160.0],
	&"snow": [0.85, 0.14, 0.0],
	&"gravel": [0.3, 0.11, 0.0],
	&"tile": [0.4, 0.06, 900.0],
}

static var _registered: bool = false


static func event_name(surface: StringName, kind: String) -> StringName:
	var s: StringName = surface if SURFACES.has(surface) else SurfaceTags.DEFAULT
	return StringName("footstep_%s_%s" % [s, kind])


static func ensure_registered() -> void:
	if _registered:
		return
	_registered = true
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	for surface: StringName in SURFACES:
		var p: Array = SURFACES[surface]
		for kind: String in KINDS:
			var length: float = float(p[1]) * (1.6 if kind == "land" else 1.0)
			var gain: float = 0.5 if kind == "walk" else (0.7 if kind == "sprint" else 0.9)
			var wav: AudioStreamWAV = _make_step(rng, float(p[0]), length, float(p[2]), gain)
			Audio.register_event(event_name(surface, kind), wav, &"SFX", -6.0)
	Audio.register_event(&"player_jump", Audio.make_tone(300.0, 0.05), &"SFX", -14.0)
	Audio.register_event(&"player_slide", _make_step(rng, 0.6, 0.5, 0.0, 0.5), &"SFX", -6.0)
	Audio.register_event(&"player_mantle", _make_step(rng, 0.75, 0.2, 120.0, 0.6), &"SFX", -6.0)


static func _make_step(
	rng: RandomNumberGenerator, smooth: float, seconds: float, tone: float, gain: float
) -> AudioStreamWAV:
	var rate: int = 22050
	var count: int = int(rate * seconds)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	var lp: float = 0.0
	for i: int in count:
		var t: float = float(i) / count
		var env: float = pow(1.0 - t, 3.0) * minf(t * 40.0, 1.0)
		lp = lerpf(rng.randf_range(-1.0, 1.0), lp, smooth)
		var s: float = lp
		if tone > 0.0:
			s = s * 0.6 + sin(TAU * tone * i / rate) * 0.4
		data.encode_s16(i * 2, int(clampf(s * env * gain, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
