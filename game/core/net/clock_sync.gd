# ClockSync — estimates the host clock from ping/pong samples (NTP-style, keeping the
# lowest-RTT samples, which have the least queuing error). Pure logic, unit-testable.
class_name ClockSync
extends RefCounted

const WINDOW: int = 8

var rtt: float = 0.0
var offset: float = 0.0  # host_time = local_time + offset
var synced: bool = false

var _samples: Array[Vector2] = []  # x = rtt, y = offset


func add_sample(client_send: float, host_time: float, client_receive: float) -> void:
	var sample_rtt: float = maxf(client_receive - client_send, 0.0)
	var sample_offset: float = host_time + sample_rtt * 0.5 - client_receive
	_samples.append(Vector2(sample_rtt, sample_offset))
	if _samples.size() > WINDOW:
		_samples.pop_front()
	var best: Vector2 = _samples[0]
	var rtt_sum: float = 0.0
	for s: Vector2 in _samples:
		rtt_sum += s.x
		if s.x < best.x:
			best = s
	rtt = rtt_sum / _samples.size()
	offset = best.y
	synced = true


func host_time(local_time: float) -> float:
	return local_time + offset


func reset() -> void:
	_samples.clear()
	rtt = 0.0
	offset = 0.0
	synced = false
