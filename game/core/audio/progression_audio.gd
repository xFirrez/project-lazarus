# ProgressionAudio — placeholder synthesis for the Step 11 progression set (DEVELOPMENT_PLAN Step 11):
# Lazarus Forge (insert clank, charge-up hum, anvil hammer, completion chime, take / lost), Resonance
# Relays (activation, spin-up drone loop pulses, pause, complete, the bridge-extension boom), traps
# (lever, electric buzz, steam hiss, coolant blast, shatter, cooldown click) and hazards (icicle
# crack, breaker thunk, puddle zap). Final recorded sounds replace these in Step 15 under the same
# event names. Synthesized on a worker thread (D-065: never stall match setup or a joining client).
# Authority: local presentation.
class_name ProgressionAudio
extends RefCounted

const RATE: int = 22050

static var _done: bool = false


static func ensure() -> void:
	if _done:
		return
	_done = true
	Audio.track_task(WorkerThreadPool.add_task(func() -> void: _build.call_deferred(_synth())))


static func _synth() -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1111
	return [
		[&"forge_insert", _clank(rng, 180.0, 0.5), &"SFX", -2.0],
		[&"forge_charge", _sweep(rng, 60.0, 420.0, 4.8, 0.25), &"SFX", -4.0],
		[&"forge_hammer", _clank(rng, 95.0, 0.6), &"SFX", 0.0],
		[&"forge_done", _chord([523.25, 659.25, 783.99, 1046.5], 1.6), &"SFX", -3.0],
		[&"forge_take", _chord([783.99, 1046.5], 0.5), &"UI", -4.0],
		[&"forge_lost", _sweep(rng, 400.0, 90.0, 1.0, 0.1), &"SFX", -6.0],
		[&"relay_start", _sweep(rng, 80.0, 300.0, 1.5, 0.2), &"SFX", -2.0],
		[&"relay_pulse", _pulse(140.0, 0.45), &"SFX", -6.0],
		[&"relay_pause", _sweep(rng, 300.0, 120.0, 0.6, 0.05), &"SFX", -4.0],
		[&"relay_done", _chord([392.0, 493.88, 587.33, 783.99], 2.0), &"SFX", -1.0],
		[&"bridge_extend", _boom(rng, 3.5), &"SFX", 2.0],
		[&"trap_lever", _clank(rng, 320.0, 0.35), &"SFX", -3.0],
		[&"trap_electric", _buzz(rng, 120.0, 1.0), &"SFX", -4.0],
		[&"trap_steam", _hiss(rng, 1.0, 0.92), &"SFX", -3.0],
		[&"trap_coolant", _hiss(rng, 1.0, 0.6), &"SFX", -3.0],
		[&"trap_ready", _chord([880.0], 0.25), &"UI", -10.0],
		[&"shatter", _shatter(rng), &"SFX", -2.0],
		[&"icicle_crack", _shatter(rng), &"SFX", 0.0],
		[&"breaker_thunk", _clank(rng, 140.0, 0.4), &"SFX", -2.0],
		[&"puddle_zap", _buzz(rng, 240.0, 0.6), &"SFX", -4.0],
	]


static func _build(events: Array) -> void:
	for e: Array in events:
		Audio.register_event(e[0], e[1], e[2], e[3])


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


static func _buf(seconds: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(RATE * seconds))
	return out


# Metallic strike: inharmonic partials + noise transient.
static func _clank(rng: RandomNumberGenerator, hz: float, seconds: float) -> AudioStreamWAV:
	var out: PackedFloat32Array = _buf(seconds)
	for i: int in out.size():
		var t: float = float(i) / RATE
		var s: float = sin(TAU * hz * t) + 0.6 * sin(TAU * hz * 2.76 * t) + 0.4 * sin(TAU * hz * 5.4 * t)
		s += rng.randf_range(-1.0, 1.0) * exp(-t * 60.0) * 1.5
		out[i] = s * 0.3 * exp(-t * 7.0)
	return _wav(out)


static func _sweep(
	rng: RandomNumberGenerator, from_hz: float, to_hz: float, seconds: float, grit: float
) -> AudioStreamWAV:
	var out: PackedFloat32Array = _buf(seconds)
	var phase: float = 0.0
	for i: int in out.size():
		var u: float = float(i) / float(out.size())
		phase += TAU * lerpf(from_hz, to_hz, u * u) / RATE
		var env: float = minf(u * 8.0, 1.0) * minf((1.0 - u) * 6.0, 1.0)
		out[i] = (sin(phase) * 0.5 + sin(phase * 2.01) * 0.2 + rng.randf_range(-grit, grit)) * env * 0.6
	return _wav(out)


static func _chord(freqs: Array, seconds: float) -> AudioStreamWAV:
	var out: PackedFloat32Array = _buf(seconds)
	for i: int in out.size():
		var t: float = float(i) / RATE
		var s: float = 0.0
		for k: int in freqs.size():
			var on: float = clampf((t - k * 0.06) * 30.0, 0.0, 1.0)
			s += sin(TAU * float(freqs[k]) * t) * on + 0.3 * sin(TAU * float(freqs[k]) * 2.0 * t) * on
		out[i] = s / maxf(freqs.size(), 1.0) * 0.5 * exp(-t * 2.2)
	return _wav(out)


static func _pulse(hz: float, seconds: float) -> AudioStreamWAV:
	var out: PackedFloat32Array = _buf(seconds)
	for i: int in out.size():
		var t: float = float(i) / RATE
		out[i] = (sin(TAU * hz * t) + 0.5 * sin(TAU * hz * 1.5 * t)) * 0.35 * sin(PI * t / seconds)
	return _wav(out)


static func _boom(rng: RandomNumberGenerator, seconds: float) -> AudioStreamWAV:
	var out: PackedFloat32Array = _buf(seconds)
	var lp: float = 0.0
	for i: int in out.size():
		var t: float = float(i) / RATE
		lp = lerpf(rng.randf_range(-1.0, 1.0), lp, 0.97)
		var rumble: float = sin(TAU * (42.0 + 10.0 * sin(t * 1.3)) * t)
		var grind: float = sin(TAU * 230.0 * t + sin(TAU * 7.0 * t) * 3.0) * 0.2 * minf(t, 1.0)
		out[i] = (lp * 2.5 + rumble * 0.6 + grind) * 0.4 * exp(-t * 0.8) * minf(t * 20.0, 1.0)
	return _wav(out)


static func _buzz(rng: RandomNumberGenerator, hz: float, seconds: float) -> AudioStreamWAV:
	var out: PackedFloat32Array = _buf(seconds)
	var phase: float = 0.0
	for i: int in out.size():
		var t: float = float(i) / RATE
		phase += TAU * hz * (1.0 + rng.randf_range(-0.05, 0.05)) / RATE
		var crack: float = rng.randf_range(-1.0, 1.0) if rng.randf() < 0.04 else 0.0
		out[i] = (signf(sin(phase)) * 0.3 + crack * 0.6) * minf(t * 30.0, 1.0) * minf((seconds - t) * 10.0, 1.0)
	return _wav(out)


static func _hiss(rng: RandomNumberGenerator, seconds: float, smooth: float) -> AudioStreamWAV:
	var out: PackedFloat32Array = _buf(seconds)
	var lp: float = 0.0
	for i: int in out.size():
		var t: float = float(i) / RATE
		var w: float = rng.randf_range(-1.0, 1.0)
		lp = lerpf(w, lp, smooth)
		out[i] = (w - lp) * 0.5 * minf(t * 15.0, 1.0) * minf((seconds - t) * 8.0, 1.0)
	return _wav(out)


static func _shatter(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var out: PackedFloat32Array = _buf(0.7)
	for i: int in out.size():
		var t: float = float(i) / RATE
		var tink: float = 0.0
		for k: int in 4:
			tink += sin(TAU * (2400.0 + k * 830.0) * t) * exp(-(t - k * 0.05) * 25.0) * (1.0 if t > k * 0.05 else 0.0)
		out[i] = (rng.randf_range(-1.0, 1.0) * exp(-t * 18.0) + tink * 0.25) * 0.5
	return _wav(out)
