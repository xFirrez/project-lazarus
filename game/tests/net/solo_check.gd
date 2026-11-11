# Solo (OfflineTransport) runs the same sandbox code path (AC-1.4) and the console commands
# work (AC-1.5). Started with --solo.
extends "res://tests/net/autotest_base.gd"

var _start_pos: Vector3 = Vector3.ZERO
var _started: float = -1.0


func _ready() -> void:
	timeout = 20.0


func _physics_process(_delta: float) -> void:
	var s: PlayerSync = sync()
	if s == null or s.local_avatar() == null:
		return
	var me: PlayerCharacter = s.local_avatar()
	if _started < 0.0:
		_started = elapsed()
		_start_pos = me.global_position
		me.bot_driver = circle_driver(0.0)
		check("offline_transport", Net.transport is OfflineTransport, Net.transport.transport_name())
		check("solo_is_host", Net.is_host() and Net.local_id() == 1)
		check("one_local_capsule", s.avatars.size() == 1 and me.is_local)
		check("game_in_match", Game.state == Game.State.IN_MATCH, Game.state_name())
		return
	if elapsed() - _started > 2.0:
		var moved: float = me.global_position.distance_to(_start_pos)
		check("capsule_moves", moved > 1.0, "%.2f m" % moved)
		check("console_help", Debug.run("help").contains("netsim"))
		check("console_net_status", Debug.run("net_status").contains("state=active role=host"))
		Debug.run("netsim 100 20 0.02")
		check("console_netsim", Net.sim.enabled and is_equal_approx(Net.sim.latency_ms, 100.0))
		Debug.run("netsim 0")
		check("console_netsim_off", not Net.sim.enabled)
		check("console_unknown", Debug.run("nonsense").begins_with("Unknown command"))
		result["pass"] = true
		set_physics_process(false)
		_quit_via_console.call_deferred()


func _quit_via_console() -> void:
	# Write the result first, then prove `quit` actually quits (driver checks exit + time).
	var out: String = CommandLine.get_value("autotest-out", "")
	var ok: bool = true
	for name: String in result["checks"]:
		ok = ok and bool(result["checks"][name]["ok"])
	result["pass"] = ok
	if out != "":
		var f: FileAccess = FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(result, "  "))
		f.close()
	Log.info(&"autotest", "AUTOTEST RESULT %s" % ("PASS" if ok else "FAIL"))
	Debug.run("quit")
