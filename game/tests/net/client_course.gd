# AC-2.1 (client part): a client at --netsim latency walks the whole movement course with the
# bot driver. Passes when every waypoint is reached and the host never had to correct it.
extends "res://tests/net/autotest_base.gd"

var _bot: BotInputDriver = null


func _ready() -> void:
	timeout = 150.0


func _physics_process(_delta: float) -> void:
	var s: PlayerSync = sync()
	if s == null or s.avatars.size() < (1 if Net.is_host() else 2):
		return
	var me: PlayerCharacter = s.local_avatar()
	if _bot == null:
		_bot = BotInputDriver.from_markers(get_tree().get_nodes_in_group(&"course_waypoint"))
		me.bot_driver = _bot.as_callable()
		note("course: %d waypoints, rtt %.0f ms" % [_bot.waypoints.size(), Net.rtt_ms()])
		return
	if _bot.failed or _bot.finished:
		set_physics_process(false)
		check("course_completed", _bot.finished, _bot.fail_reason if _bot.failed else "%.1f s" % _bot.elapsed)
		check("no_host_corrections", s.corrections_received == 0, s.corrections_received)
		result["course_time_s"] = _bot.elapsed
		result["rtt_ms"] = Net.rtt_ms()
		if Net.is_host():
			finish(true)  # solo run
			return
		Net.send_reliable(1, &"_autotest_course", [_bot.finished, s.corrections_received])
		_leave_soon.call_deferred()


func _leave_soon() -> void:
	await get_tree().create_timer(1.0).timeout
	Net.leave_session("autotest done")
	await get_tree().create_timer(0.3).timeout
	finish(true)
