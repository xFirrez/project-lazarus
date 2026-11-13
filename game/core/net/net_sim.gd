# NetSim — simulated network conditions (latency, jitter, loss) applied to outgoing traffic.
# Unreliable packets may be dropped and reordered by jitter; reliable packets are only delayed
# and keep their order (like ENet's reliable channel). Pure logic: time is passed in so it is
# unit-testable and deterministic with a seeded RNG.
class_name NetSim
extends RefCounted

var enabled: bool = false
var latency_ms: float = 0.0
var jitter_ms: float = 0.0
var loss: float = 0.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var dropped: int = 0
var sent: int = 0

var _queue: Array[Dictionary] = []  # {due: float, payload: Variant, seq: int}
var _last_reliable_due: float = 0.0
var _seq: int = 0


func configure(p_latency_ms: float, p_jitter_ms: float, p_loss: float) -> void:
	latency_ms = maxf(p_latency_ms, 0.0)
	jitter_ms = maxf(p_jitter_ms, 0.0)
	loss = clampf(p_loss, 0.0, 1.0)
	enabled = latency_ms > 0.0 or jitter_ms > 0.0 or loss > 0.0


static func parse_spec(spec: String) -> PackedFloat64Array:
	var parts: PackedStringArray = spec.split(",")
	var out: PackedFloat64Array = [0.0, 0.0, 0.0]
	for i: int in mini(parts.size(), 3):
		out[i] = parts[i].strip_edges().to_float()
	return out


func describe() -> String:
	if not enabled:
		return "off"
	return "%d ms ±%d ms, %.1f%% loss" % [int(latency_ms), int(jitter_ms), loss * 100.0]


# Returns false if the packet was dropped.
func push(payload: Variant, now: float, reliable: bool) -> bool:
	sent += 1
	if not reliable and loss > 0.0 and rng.randf() < loss:
		dropped += 1
		return false
	var delay: float = (latency_ms + rng.randf_range(-jitter_ms, jitter_ms)) / 1000.0
	var due: float = now + maxf(delay, 0.0)
	if reliable:
		due = maxf(due, _last_reliable_due)
		_last_reliable_due = due
	_seq += 1
	_queue.append({"due": due, "payload": payload, "seq": _seq})
	return true


# Returns payloads whose delivery time has come, in delivery order.
func pop_ready(now: float) -> Array:
	var ready: Array[Dictionary] = []
	var remaining: Array[Dictionary] = []
	for item: Dictionary in _queue:
		if float(item["due"]) <= now:
			ready.append(item)
		else:
			remaining.append(item)
	_queue = remaining
	ready.sort_custom(_by_due)
	var out: Array = []
	for item: Dictionary in ready:
		out.append(item["payload"])
	return out


func pending() -> int:
	return _queue.size()


func clear() -> void:
	_queue.clear()
	_last_reliable_due = 0.0


static func _by_due(a: Dictionary, b: Dictionary) -> bool:
	if float(a["due"]) == float(b["due"]):
		return int(a["seq"]) < int(b["seq"])
	return float(a["due"]) < float(b["due"])
