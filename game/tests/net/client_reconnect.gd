# Client side of the reconnect net test (see host_reconnect.gd). First run (--reconnect-phase=a):
# waits until it holds the M14 with 3210 points, prints READY and is SIGKILLed by the driver.
# Second run (phase b, same profile/uid): checks the restored points + weapons locally, spectates
# until the next round, then respawns holding the M14.
extends "res://tests/net/autotest_base.gd"

var _phase: String = "a"
var _done: bool = false


func _ready() -> void:
	timeout = 100.0
	_phase = CommandLine.get_value("reconnect-phase", "a")
	Net.register_message(&"_t_done", func(_s: int, _p: Array) -> void: _done = true)
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


func _has_m14(m: Match) -> bool:
	var me: PlayerCharacter = m.players.local_avatar()
	return me != null and me.weapons.inventory.ids().has(&"m14")


func _run() -> void:
	var in_match: bool = await _until(func() -> bool: return _m() != null and _m().players.local_avatar() != null, 20.0)
	check("in_match", in_match, Game.menu_message)
	if not in_match:
		finish(false)
		return
	var m: Match = _m()
	var me: PlayerCharacter = m.players.local_avatar()
	if _phase == "a":
		var ok: bool = await _until(
			func() -> bool: return _has_m14(m) and m.points.get_points(me.peer_id) == 3210, 30.0
		)
		check("got_points_and_m14", ok)
		Log.info(&"autotest", "AUTOTEST READY client-a")
		await get_tree().create_timer(60.0).timeout  # killed by the driver
		finish(false)
		return
	var restored: bool = await _until(
		func() -> bool: return _has_m14(m) and m.points.get_points(me.peer_id) == 3210, 20.0
	)
	check("points_and_m14_restored_locally", restored, [m.points.get_points(me.peer_id), me.weapons.inventory.ids()])
	check("spectating_until_next_round", me.spectating)
	var spawned: bool = await _until(func() -> bool: return m.rounds.current_round == 2 and not me.spectating, 30.0)
	check("respawned_next_round_with_m14", spawned and _has_m14(m))
	await _until(func() -> bool: return _done, 20.0)
	finish(true)
