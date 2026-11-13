# Host side of the 2-peer replication test (AC-1.3, AC-1.6 part 1).
# Drives the host capsule, records its authoritative history, receives the client's
# observations of it, computes the replication error, then verifies the client's capsule is
# removed after the client disconnects.
extends "res://tests/net/autotest_base.gd"

const MAX_ERROR_M: float = 0.3  # AC-2.5 steady-state bound
const MAX_FRAME_STEP_M: float = 0.25  # > ~15 m/s in one frame would read as a visible snap

var _history_t: PackedFloat64Array = []
var _history_p: PackedVector3Array = []
var _report: Array = []
var _client_id: int = 0
var _left_at: float = -1.0
var _removed_at: float = -1.0
var _saw_two: bool = false
var _client_corrections: int = 0
var _two_at: float = -1.0
var _damaged: bool = false


func _ready() -> void:
	timeout = 40.0
	Net.register_message(&"_autotest_report", _on_report)
	Net.peer_left.connect(func(id: int) -> void: _left_at = elapsed() if id == _client_id else _left_at)


func _physics_process(_delta: float) -> void:
	var s: PlayerSync = sync()
	if s == null:
		return
	var me: PlayerCharacter = s.local_avatar()
	if me == null:
		return
	if not me.bot_driver.is_valid():
		me.bot_driver = circle_driver(0.0, true)
	_history_t.append(Net.host_time())
	_history_p.append(me.global_position)
	if s.avatars.size() == 2 and not _saw_two:
		_saw_two = true
		for id: int in s.avatars:
			if id != Net.local_id():
				_client_id = id
		check("host_sees_two_capsules", true, s.avatars.keys())
		s.corrected.connect(func(_id: int, _r: String) -> void: _client_corrections += 1)
		_two_at = elapsed()
	# Host-authoritative damage to the client from its left (AC-2.4 over the network).
	if _two_at >= 0.0 and not _damaged and elapsed() > _two_at + 2.0 and s.avatars.has(_client_id):
		_damaged = true
		var c: PlayerCharacter = s.avatars[_client_id]
		var src: Vector3 = c.global_position + Basis(Vector3.UP, c.rotation.y + PI / 2.0) * Vector3.FORWARD * 6.0
		var applied: float = s.damage_player(_client_id, 40.0, src, HealthComponent.DamageType.ZOMBIE)
		check("host_applied_damage", applied == 40.0, applied)
	if _left_at >= 0.0 and _removed_at < 0.0 and not s.avatars.has(_client_id):
		_removed_at = elapsed()
		check("client_capsule_removed_on_disconnect", true, "%.3f s after peer_left" % (_removed_at - _left_at))
		_evaluate()


func _on_report(_sender: int, payload: Array) -> void:
	_report = payload
	note("report received: %d samples, connect %.3f s" % [(payload[1] as Array).size(), float(payload[0])])


func _authoritative_at(t: float) -> Vector3:
	var n: int = _history_t.size()
	var lo: int = 0
	var hi: int = n - 1
	if t <= _history_t[0]:
		return _history_p[0]
	if t >= _history_t[hi]:
		return _history_p[hi]
	while hi - lo > 1:
		var mid: int = (lo + hi) / 2
		if _history_t[mid] <= t:
			lo = mid
		else:
			hi = mid
	var f: float = (t - _history_t[lo]) / maxf(_history_t[hi] - _history_t[lo], 0.000001)
	return _history_p[lo].lerp(_history_p[hi], f)


func _evaluate() -> void:
	if _report.is_empty():
		check("client_report_received", false)
		finish(false)
		return
	var connect_time: float = float(_report[0])
	check("client_connects_within_2s", connect_time < 2.0, "%.3f s" % connect_time)
	check("client_saw_two_capsules", bool(_report[2]))
	var samples: Array = _report[1]
	var max_err: float = 0.0
	var sum_err: float = 0.0
	for sample: Variant in samples:
		var arr: Array = sample
		var replicated: Vector3 = Vector3(float(arr[1]), float(arr[2]), float(arr[3]))
		var err: float = replicated.distance_to(_authoritative_at(float(arr[0])))
		max_err = maxf(max_err, err)
		sum_err += err
	var mean_err: float = sum_err / maxf(samples.size(), 1)
	result["max_error_m"] = max_err
	result["mean_error_m"] = mean_err
	result["samples"] = samples.size()
	result["interp_delay_s"] = float(_report[3])
	result["max_frame_step_m"] = float(_report[4])
	check("no_visible_snapping", float(_report[4]) < MAX_FRAME_STEP_M, "max per-frame step %.3f m" % float(_report[4]))
	check("legit_client_never_corrected", _client_corrections == 0, _client_corrections)
	check("enough_samples", samples.size() > 120, samples.size())
	check(
		"replicated_within_%.1fm" % MAX_ERROR_M,
		max_err <= MAX_ERROR_M,
		"max %.3f m, mean %.3f m over %d samples" % [max_err, mean_err, samples.size()]
	)
	finish(true)
