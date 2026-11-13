# HitchMonitor — frame-time watchdog for AC-16.3 ("no hitch > 50 ms during gameplay after the
# warm-up"). Measures wall-clock time between frames (independent of --fixed-fps), arms itself
# once the match's shader warm-up has finished plus a settle delay, then counts hitches, keeps a
# 1 ms histogram for p50 / p99, and watches draw-time pipeline compilations (shader stutter: the
# warm-up should leave none). Logged at match end and shown by the `hitches` console command;
# sims read `stats()`.
# Authority: local (every peer measures its own frames).
class_name HitchMonitor
extends Node

const HITCH_MS: float = 50.0
const BUCKETS: int = 251  # 0..250 ms, the last bucket collects everything slower

var settle_seconds: float = 3.0  # after the warm-up (loading, first spawns)
var armed: bool = false
var frames: int = 0
var hitches: int = 0
var worst_ms: float = 0.0
var hitch_log: Array[Dictionary] = []  # first 32 hitches: {t, ms}
var draw_compiles: int = 0  # draw-time pipeline compilations since arming

var _histogram: PackedInt32Array = PackedInt32Array()
var _last_usec: int = 0
var _arm_at_usec: int = -1
var _compiles_at_arm: int = 0
var _armed_at_usec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000
	_histogram.resize(BUCKETS)


# Called when the warm-up is done (or immediately when there is none).
func arm_after_settle() -> void:
	_arm_at_usec = Time.get_ticks_usec() + int(settle_seconds * 1e6)


func reset() -> void:
	frames = 0
	hitches = 0
	worst_ms = 0.0
	hitch_log.clear()
	_histogram.fill(0)
	_compiles_at_arm = _pipeline_compiles()
	draw_compiles = 0
	_armed_at_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if not armed and _arm_at_usec >= 0 and now >= _arm_at_usec:
		armed = true
		reset()
		_last_usec = now
		return
	if not armed or get_tree().paused:
		_last_usec = now
		return
	var ms: float = float(now - _last_usec) / 1000.0
	_last_usec = now
	frames += 1
	_histogram[mini(int(ms), BUCKETS - 1)] += 1
	worst_ms = maxf(worst_ms, ms)
	if ms > HITCH_MS:
		hitches += 1
		if hitch_log.size() < 32:
			hitch_log.append({"t": snappedf(float(now - _armed_at_usec) / 1e6, 0.1), "ms": snappedf(ms, 0.1)})
	if frames % 60 == 0:
		draw_compiles = _pipeline_compiles() - _compiles_at_arm


func percentile_ms(q: float) -> float:
	if frames == 0:
		return 0.0
	var target: int = ceili(frames * clampf(q, 0.0, 1.0))
	var acc: int = 0
	for i: int in BUCKETS:
		acc += _histogram[i]
		if acc >= target:
			return float(i + 1)
	return float(BUCKETS)


func stats() -> Dictionary:
	return {
		"armed": armed,
		"frames": frames,
		"hitches_over_50ms": hitches,
		"worst_ms": snappedf(worst_ms, 0.1),
		"p50_ms": percentile_ms(0.5),
		"p99_ms": percentile_ms(0.99),
		"draw_pipeline_compiles": draw_compiles,
		"seconds": snappedf(float(Time.get_ticks_usec() - _armed_at_usec) / 1e6, 0.1) if armed else 0.0,
	}


func describe() -> String:
	if not armed:
		return "hitch monitor: warming up"
	var s: Dictionary = stats()
	var text: String = (
		"frames %d over %.0f s  p50 %.0f ms  p99 %.0f ms  worst %.1f ms  hitches>50ms %d  draw compiles %d"
		% [
			s["frames"],
			s["seconds"],
			s["p50_ms"],
			s["p99_ms"],
			s["worst_ms"],
			s["hitches_over_50ms"],
			s["draw_pipeline_compiles"]
		]
	)
	for h: Dictionary in hitch_log.slice(0, 8):
		text += "\n  t=%.1f s  %.1f ms" % [float(h["t"]), float(h["ms"])]
	return text


func _pipeline_compiles() -> int:
	if DisplayServer.get_name() == "headless":
		return 0
	return int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW))


func _exit_tree() -> void:
	if armed and frames > 0:
		Log.info(&"perf", "match frame times: %s" % describe().get_slice("\n", 0))
