# Smoke simulation: solo session on the given map, bot-driven capsule for N seconds.
# Fails on any error logged; later steps extend this into the milestone smoke test.
extends "res://tests/net/autotest_base.gd"

var duration: float = 5.0
var _started: float = -1.0
var _errors: int = 0
var _start_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	duration = CommandLine.get_value("duration", "5").to_float()
	timeout = duration + 15.0
	Log.entry_added.connect(func(e: Dictionary) -> void: _errors += 1 if int(e["level"]) >= Log.Level.ERROR else 0)


func _physics_process(_delta: float) -> void:
	var s: PlayerSync = sync()
	if s == null or s.local_avatar() == null:
		return
	if _started < 0.0:
		_started = elapsed()
		_start_pos = s.local_avatar().global_position
		s.local_avatar().bot_driver = circle_driver(0.3)
		return
	if elapsed() - _started >= duration:
		set_physics_process(false)
		check("in_match", Game.state == Game.State.IN_MATCH, Game.state_name())
		check("avatar_moved", s.local_avatar().global_position.distance_to(_start_pos) > 0.5)
		check("no_logged_errors", _errors == 0, _errors)
		check("orphan_nodes", Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) == 0)
		finish(true)
