# InterpolationBuffer — buffered snapshot interpolation for remote entities.
# Samples are stamped with the sender's (host) time. Playback time follows the observed
# arrival offset minus `delay`, so the delay is relative to arrival and independent of latency.
# Adaptive: the delay grows with measured jitter (ARCHITECTURE §5.2, 100 ms base).
class_name InterpolationBuffer
extends RefCounted

const MAX_SAMPLES: int = 32
const MAX_EXTRAPOLATION: float = 0.15

var base_delay: float = 0.1
var delay: float = 0.1

var _times: PackedFloat64Array = []
var _positions: PackedVector3Array = []
var _yaws: PackedFloat32Array = []
var _arrival_offset: float = 0.0
var _has_offset: bool = false
var _jitter: float = 0.0


func push(stamp: float, position: Vector3, yaw: float, local_now: float) -> void:
	if not _times.is_empty() and stamp <= _times[_times.size() - 1]:
		return  # stale or duplicate (unreliable channel may reorder)
	var observed: float = stamp - local_now
	if not _has_offset:
		_arrival_offset = observed
		_has_offset = true
	else:
		# Latest-arrival offset: fast to adopt earlier-arriving packets, slow drift otherwise.
		var deviation: float = absf(observed - _arrival_offset)
		_jitter = lerpf(_jitter, deviation, 0.1)
		if observed > _arrival_offset:
			_arrival_offset = observed
		else:
			_arrival_offset = lerpf(_arrival_offset, observed, 0.02)
	delay = base_delay + clampf(_jitter * 2.0, 0.0, 0.1)
	_times.append(stamp)
	_positions.append(position)
	_yaws.append(yaw)
	if _times.size() > MAX_SAMPLES:
		_times.remove_at(0)
		_positions.remove_at(0)
		_yaws.remove_at(0)


func is_empty() -> bool:
	return _times.is_empty()


func playback_time(local_now: float) -> float:
	return local_now + _arrival_offset - delay


func sample_position(t: float) -> Vector3:
	var n: int = _times.size()
	if n == 0:
		return Vector3.ZERO
	if n == 1 or t <= _times[0]:
		return _positions[0]
	for i: int in range(n - 1, 0, -1):
		if t >= _times[i - 1]:
			var t0: float = _times[i - 1]
			var t1: float = _times[i]
			var span: float = maxf(t1 - t0, 0.0001)
			if t <= t1:
				return _positions[i - 1].lerp(_positions[i], (t - t0) / span)
			# Past the newest sample: limited extrapolation.
			var ahead: float = minf(t - t1, MAX_EXTRAPOLATION)
			var vel: Vector3 = (_positions[i] - _positions[i - 1]) / span
			return _positions[i] + vel * ahead
	return _positions[n - 1]


func sample_yaw(t: float) -> float:
	var n: int = _times.size()
	if n == 0:
		return 0.0
	if n == 1 or t <= _times[0]:
		return _yaws[0]
	for i: int in range(1, n):
		if t <= _times[i]:
			var span: float = maxf(_times[i] - _times[i - 1], 0.0001)
			return lerp_angle(_yaws[i - 1], _yaws[i], (t - _times[i - 1]) / span)
	return _yaws[n - 1]
