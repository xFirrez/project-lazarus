# Host side of the speed-hack test (AC-2.5): the client runs `speed_hack 3`; the host's
# MovementValidator must correct it, and the client's *validated* track (what the host keeps and
# relays) must never exceed the allowed horizontal speed on average.
extends "res://tests/net/autotest_base.gd"

var _client_id: int = 0
var _corrections: int = 0
var _window: Array = []  # [stamp, pos] of accepted client states during the hack window
var _hacking: bool = false
var _last_stamp: float = -1.0


func _ready() -> void:
	timeout = 30.0
	Net.register_message(&"_autotest_hack", _on_hack)


func _physics_process(_delta: float) -> void:
	var s: PlayerSync = sync()
	if s == null:
		return
	if _client_id == 0:
		for id: int in s.avatars:
			if id != Net.local_id():
				_client_id = id
				s.corrected.connect(func(_i: int, _r: String) -> void: _corrections += 1 if _hacking else 0)
				Log.info(&"autotest", "AUTOTEST READY host")
		return
	if _hacking and s.validators.has(_client_id):
		var v: MovementValidator = s.validators[_client_id]
		if v.stamp != _last_stamp:
			_last_stamp = v.stamp
			_window.append([v.stamp, v.position])


func _on_hack(_sender: int, payload: Array) -> void:
	if String(payload[0]) == "start":
		_hacking = true
		return
	_hacking = false
	var client_corrections: int = int(payload[1])
	var client_distance: float = float(payload[2])
	var t: PlayerTuning = load(PlayerCharacter.DEFAULT_TUNING) as PlayerTuning
	var path: float = 0.0
	for i: int in range(1, _window.size()):
		var a: Vector3 = _window[i - 1][1]
		var b: Vector3 = _window[i][1]
		path += Vector2(b.x - a.x, b.z - a.z).length()
	var span: float = float(_window[-1][0]) - float(_window[0][0]) if _window.size() > 1 else 0.0
	var speed: float = path / maxf(span, 0.001)
	result["validated_speed_mps"] = speed
	result["client_local_distance_m"] = client_distance
	result["host_corrections"] = _corrections
	check("host_corrected_speed_hack", _corrections > 0, _corrections)
	check("client_received_corrections", client_corrections > 0, client_corrections)
	check(
		"validated_speed_within_limit",
		speed <= t.validation_max_horizontal_speed * 1.15,
		"%.2f m/s over %.2f s (limit %.1f)" % [speed, span, t.validation_max_horizontal_speed]
	)
	check("hack_would_have_been_faster", client_distance / maxf(span, 0.001) > speed * 1.3)
	finish(true)
