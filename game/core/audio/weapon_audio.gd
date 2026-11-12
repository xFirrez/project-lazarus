# WeaponAudio — registers weapon audio events with the Audio autoload. Placeholder sounds are
# synthesized per WeaponDefinition (body pitch, mechanical click pitch, tail length) so every weapon
# sounds distinct until recorded assets arrive (Step 9 / 15). Fire is three layered events
# (mechanical, body, tail); reload events are keyed from viewmodel animation method tracks.
#   wpn_<id>_mech | _body | _tail | _tail_in (interior) | _mag_out | _mag_in | _bolt | _shell | _pump | _raise
#   wpn_dry, hit_body, hit_head, hit_kill, melee_swing, melee_hit, frag_pin, frag_throw,
#   frag_bounce, frag_explode, bolt_stick, decoy_drum, mine_place, mine_beep, impact_<surface>
# Authority: local presentation.
class_name WeaponAudio
extends RefCounted

const RATE: int = 22050
const LAYERS: PackedStringArray = ["mech", "body", "tail"]
const IMPACT_SURFACES: Dictionary = {
	&"concrete": [0.5, 0.06, 0.0],
	&"metal": [0.15, 0.12, 1900.0],
	&"wood": [0.65, 0.07, 240.0],
	&"snow": [0.88, 0.09, 0.0],
	&"flesh": [0.8, 0.08, 90.0],
	&"gravel": [0.3, 0.07, 0.0],
	&"tile": [0.35, 0.05, 1200.0],
}

static var _registered: Dictionary = {}
static var _common: bool = false


static func event(def: WeaponDefinition, kind: String) -> StringName:
	return StringName("wpn_%s_%s" % [def.id, kind])


# Tail layer for a shot fired at `pos`: interior (a roof within 12 m above) or exterior.
static func tail_event(def: WeaponDefinition, space: PhysicsDirectSpaceState3D, pos: Vector3) -> StringName:
	if space != null:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(pos, pos + Vector3.UP * 12.0, 1)
		if not space.intersect_ray(q).is_empty():
			return event(def, "tail_in")
	return event(def, "tail")


static func ensure(def: WeaponDefinition) -> void:
	ensure_common()
	if _registered.has(def.id):
		return
	_registered[def.id] = true
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(def.id)
	var v: float = def.sound_volume_db
	Audio.register_event(event(def, "mech"), _click(rng, def.sound_mech_hz, 0.03, 0.5), &"Weapons", v - 6.0)
	Audio.register_event(event(def, "body"), _body(rng, def.sound_body_hz, 0.16), &"Weapons", v)
	Audio.register_event(event(def, "tail"), _noise(rng, 0.9, def.sound_tail_s, 0.0, 0.35, 2.0), &"Weapons", v - 4.0)
	# Interior tail: shorter, brighter slap-back (rooms) instead of the long exterior roll.
	var tail_in: AudioStreamWAV = _noise(rng, 0.75, def.sound_tail_s * 0.55, 0.0, 0.32, 5.0)
	Audio.register_event(event(def, "tail_in"), tail_in, &"Weapons", v - 5.0)
	Audio.register_event(event(def, "mag_out"), _click(rng, 900.0, 0.08, 0.6), &"Weapons", -8.0)
	Audio.register_event(event(def, "mag_in"), _click(rng, 650.0, 0.1, 0.8), &"Weapons", -6.0)
	Audio.register_event(event(def, "bolt"), _click(rng, 1400.0, 0.12, 0.7), &"Weapons", -6.0)
	Audio.register_event(event(def, "shell"), _click(rng, 1100.0, 0.07, 0.6), &"Weapons", -8.0)
	Audio.register_event(event(def, "pump"), _noise(rng, 0.4, 0.18, 500.0, 0.7, 6.0), &"Weapons", -5.0)
	Audio.register_event(event(def, "raise"), _noise(rng, 0.6, 0.12, 300.0, 0.4, 8.0), &"Weapons", -12.0)


static func ensure_common() -> void:
	if _common:
		return
	_common = true
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 777
	Audio.register_event(&"wpn_dry", _click(rng, 1800.0, 0.04, 0.5), &"Weapons", -6.0)
	Audio.register_event(&"hit_body", _click(rng, 1500.0, 0.05, 0.5), &"UI", -8.0)
	Audio.register_event(&"hit_head", Audio.make_tone(2600.0, 0.06), &"UI", -4.0)
	Audio.register_event(&"hit_kill", _body(rng, 420.0, 0.12), &"UI", -6.0)
	Audio.register_event(&"melee_swing", _noise(rng, 0.5, 0.2, 0.0, 0.5, 9.0), &"Weapons", -6.0)
	Audio.register_event(&"melee_hit", _body(rng, 140.0, 0.12), &"Weapons", -2.0)
	Audio.register_event(&"frag_pin", _click(rng, 2200.0, 0.06, 0.5), &"Weapons", -6.0)
	Audio.register_event(&"frag_throw", _noise(rng, 0.6, 0.15, 0.0, 0.4, 8.0), &"Weapons", -8.0)
	Audio.register_event(&"frag_bounce", _click(rng, 500.0, 0.06, 0.6), &"Weapons", -6.0)
	Audio.register_event(&"frag_explode", _noise(rng, 0.92, 1.4, 45.0, 1.0, 2.5), &"Weapons", 2.0)
	# Step 9 equipment / projectiles.
	Audio.register_event(&"bolt_stick", _click(rng, 380.0, 0.12, 0.8), &"Weapons", -4.0)
	Audio.register_event(&"decoy_drum", _body(rng, 210.0, 0.12), &"SFX", -6.0)
	Audio.register_event(&"mine_place", _click(rng, 700.0, 0.15, 0.7), &"Weapons", -6.0)
	Audio.register_event(&"mine_beep", Audio.make_tone(1900.0, 0.12), &"SFX", -4.0)
	for surface: StringName in IMPACT_SURFACES:
		var p: Array = IMPACT_SURFACES[surface]
		var wav: AudioStreamWAV = _noise(rng, float(p[0]), float(p[1]), float(p[2]), 0.5, 18.0)
		Audio.register_event(StringName("impact_%s" % surface), wav, &"SFX", -10.0)


static func impact_event(surface: StringName) -> StringName:
	return StringName("impact_%s" % (surface if IMPACT_SURFACES.has(surface) else &"concrete"))


# --- synthesis --------------------------------------------------------------------------------


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav


# Low-passed noise (smooth 0..1, higher = darker) with optional tone, exponential decay.
static func _noise(
	rng: RandomNumberGenerator, smooth: float, seconds: float, tone: float, gain: float, decay: float
) -> AudioStreamWAV:
	var n: int = int(RATE * seconds)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		lp = lerpf(rng.randf_range(-1.0, 1.0), lp, smooth)
		var s: float = lp * (2.0 if smooth > 0.8 else 1.0)
		if tone > 0.0:
			s = s * 0.6 + sin(TAU * tone * t) * 0.4
		out[i] = s * gain * exp(-t * decay) * minf(t * 400.0, 1.0)
	return _wav(out)


# Gunshot body: noise burst + falling sine thump at `hz`.
static func _body(rng: RandomNumberGenerator, hz: float, seconds: float) -> AudioStreamWAV:
	var n: int = int(RATE * seconds)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		lp = lerpf(rng.randf_range(-1.0, 1.0), lp, 0.35)
		phase += TAU * hz * (1.0 - 0.5 * t / seconds) / RATE
		var env: float = exp(-t * 22.0) * minf(t * 2000.0, 1.0)
		out[i] = (lp * 0.7 + sin(phase) * 0.6) * env
	return _wav(out)


# Mechanical click: short bright transient with a ringing tone.
static func _click(rng: RandomNumberGenerator, hz: float, seconds: float, gain: float) -> AudioStreamWAV:
	var n: int = int(RATE * seconds)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		var s: float = rng.randf_range(-1.0, 1.0) * exp(-t * 300.0) + sin(TAU * hz * t) * exp(-t * 60.0) * 0.6
		out[i] = s * gain
	return _wav(out)
