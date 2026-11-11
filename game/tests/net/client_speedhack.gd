# Client side of the speed-hack test: after joining, enables `speed_hack 3` and runs a fast
# circle for 3 s, then reports how many corrections it received and how far it *tried* to go.
extends "res://tests/net/autotest_base.gd"

const HACK_S: float = 3.0

var _start: float = -1.0
var _distance: float = 0.0
var _last: Vector3 = Vector3.INF
var _done: bool = false


func _ready() -> void:
	timeout = 25.0


func _physics_process(delta: float) -> void:
	var s: PlayerSync = sync()
	if s == null or s.avatars.size() < 2 or _done:
		return
	var me: PlayerCharacter = s.local_avatar()
	if _start < 0.0:
		_start = elapsed() + 1.0
		me.bot_driver = circle_driver(0.0, true)
		return
	if elapsed() < _start:
		return
	if _last == Vector3.INF:
		Debug.run("speed_hack 3")
		Net.send_reliable(1, &"_autotest_hack", ["start"])
		_last = me.global_position
		return
	# Distance the hacked client simulates per frame (its own speed, ignoring snap-backs).
	_distance += me.motor.horizontal_speed() * delta
	if elapsed() > _start + HACK_S:
		_done = true
		Debug.run("speed_hack 1")
		Net.send_reliable(1, &"_autotest_hack", ["end", s.corrections_received, _distance])
		check("client_received_corrections", s.corrections_received > 0, s.corrections_received)
		_leave_soon.call_deferred()


func _leave_soon() -> void:
	await get_tree().create_timer(1.0).timeout
	Net.leave_session("autotest done")
	await get_tree().create_timer(0.3).timeout
	finish(true)
