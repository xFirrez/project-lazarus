# Client side of the traversal net test (see host_traversal.gd): joins after power-on (late-join
# power state + lit powered lights), then follows the host's moves; checks that its own avatar
# arrives with the machines (local prediction carried by the deterministic platforms).
extends "res://tests/net/autotest_base.gd"

var _max_y: float = -1000.0
var _min_y: float = 1000.0


func _ready() -> void:
	timeout = 170.0
	Net.register_message(&"_t_done", _on_done)
	_run()


func _m() -> Match:
	return Match.current


func _until(cond: Callable, limit: float) -> bool:
	var t0: float = elapsed()
	while not cond.call():
		if elapsed() - t0 > limit:
			return false
		await get_tree().physics_frame
	return true


func _run() -> void:
	await _until(func() -> bool: return _m() != null and _m().players.local_avatar() != null, 30.0)
	var m: Match = _m()
	m.downed.show_screen = false
	var on: bool = await _until(func() -> bool: return Power.is_on(), 10.0)
	check("late_join_power_on", on)
	await get_tree().create_timer(1.0).timeout
	var lit: int = 0
	for n: Node in get_tree().get_nodes_in_group(&"powered_light"):
		lit += 1 if (n as PoweredLight).powered else 0
	check("late_join_lights_powered", lit > 20, lit)


func _physics_process(_delta: float) -> void:
	var m: Match = _m()
	if m == null or m.players.local_avatar() == null:
		return
	var y: float = m.players.local_avatar().global_position.y
	_max_y = maxf(_max_y, y)
	_min_y = minf(_min_y, y)


func _on_done(_sender: int, _p: Array) -> void:
	var me: PlayerCharacter = _m().players.local_avatar()
	check("visited_comms_array", _max_y > 16.0, _max_y)
	check("visited_specimen_storage", _min_y < -27.0, _min_y)
	check(
		"landed_in_specimen_storage",
		me.global_position.distance_to(Vector3(87.5, -27.9, -31.5)) < 3.0,
		me.global_position
	)
	finish(true)
