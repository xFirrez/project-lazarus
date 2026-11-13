# Client for AC-1.6 part 2: after joining, announces READY; the driver kills the host process.
# Passes when the client is back in the main menu showing "Host disconnected".
extends "res://tests/net/autotest_base.gd"

var _ready_at: float = -1.0


func _ready() -> void:
	timeout = 25.0


func _process(delta: float) -> void:
	super(delta)
	var s: PlayerSync = sync()
	if _ready_at < 0.0 and s != null and s.avatars.size() == 2:
		_ready_at = elapsed()
		Log.info(&"autotest", "AUTOTEST READY client")
	if _ready_at >= 0.0 and Game.state == Game.State.MAIN_MENU:
		check("returned_to_menu", true, "%.2f s after ready" % (elapsed() - _ready_at))
		check("menu_message", Game.menu_message == "Host disconnected", Game.menu_message)
		check("no_avatars_left", Match.current == null)
		finish(true)
