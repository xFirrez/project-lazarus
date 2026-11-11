# Client side of the replication test: measures connect time, records the host capsule's
# replicated position against the interpolation playback time, reports to the host and then
# disconnects cleanly.
extends "res://tests/net/autotest_base.gd"

const WARMUP_S: float = 1.5
const RECORD_S: float = 5.0

var _connect_time: float = -1.0
var _record_start: float = -1.0
var _samples: Array = []
var _sent: bool = false
var _last_render: Vector3 = Vector3.INF
var _max_step: float = 0.0


func _ready() -> void:
	timeout = 30.0


func _physics_process(_delta: float) -> void:
	var s: PlayerSync = sync()
	if s == null or _sent:
		return
	if s.avatars.size() < 2:
		return
	if _connect_time < 0.0:
		_connect_time = elapsed()
		check("client_sees_two_capsules", true, "%.3f s after launch" % _connect_time)
		_record_start = elapsed() + WARMUP_S
		var me: PlayerCharacter = s.local_avatar()
		me.bot_driver = circle_driver(1.7)
	if elapsed() < _record_start:
		return
	var host_avatar: PlayerCharacter = s.avatars.get(1, null)
	if host_avatar == null or host_avatar.buffer.is_empty():
		return
	# Rendered puppet position (moved by PlayerCharacter._puppet this frame): per-frame step size.
	if _last_render != Vector3.INF:
		_max_step = maxf(_max_step, host_avatar.global_position.distance_to(_last_render))
	_last_render = host_avatar.global_position
	var t: float = host_avatar.buffer.playback_time(Net.now())
	var p: Vector3 = host_avatar.buffer.sample_position(t)
	_samples.append([t, p.x, p.y, p.z])
	if elapsed() > _record_start + RECORD_S:
		_sent = true
		Net.send_reliable(1, &"_autotest_report", [_connect_time, _samples, true, host_avatar.buffer.delay, _max_step])
		_leave_soon.call_deferred()


func _leave_soon() -> void:
	await get_tree().create_timer(1.0).timeout
	Net.leave_session("autotest done")
	await get_tree().create_timer(0.3).timeout
	finish(true)
