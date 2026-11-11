# Host side of the client course run: stands still at spawn; when the client reports, checks that
# its own validator never corrected the client (no false positives on stairs, mantles, slides,
# the elevator or drops) and that the client's replicated position ended near the finish.
extends "res://tests/net/autotest_base.gd"

var _client_id: int = 0
var _corrections: int = 0
var _min_z: float = 0.0


func _ready() -> void:
	timeout = 160.0
	Net.register_message(&"_autotest_course", _on_report)


func _physics_process(_delta: float) -> void:
	var s: PlayerSync = sync()
	if s == null:
		return
	if _client_id == 0:
		for id: int in s.avatars:
			if id != Net.local_id():
				_client_id = id
				s.corrected.connect(
					func(_i: int, r: String) -> void:
						_corrections += 1
						note("correction: " + r)
				)
		return
	if s.avatars.has(_client_id):
		_min_z = minf(_min_z, (s.avatars[_client_id] as PlayerCharacter).global_position.z)


func _on_report(_sender: int, payload: Array) -> void:
	check("client_finished_course", bool(payload[0]))
	check("host_never_corrected_client", _corrections == 0, _corrections)
	check("host_saw_client_reach_finish", _min_z < -105.0, "min z %.1f" % _min_z)
	finish(true)
