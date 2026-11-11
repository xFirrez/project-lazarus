# Host side of the weapon net test (AC-3.4): fires one shot so the client sees a relayed fire
# burst, applies the client's legit hits, and checks that the forged claims were rejected for the
# right reasons (dead target, range, rate) with no rejections during the legit phase.
extends "res://tests/net/autotest_base.gd"

var _client_id: int = 0
var _input: Dictionary = {"fire": false}
var _fired: bool = false
var _rejections_before_cheats: int = -1


func _ready() -> void:
	timeout = 45.0
	Net.register_message(&"_autotest_phase", _on_phase)


func _physics_process(_delta: float) -> void:
	var s: PlayerSync = sync()
	if s == null or Match.current.weapons == null:
		return
	if _client_id == 0:
		for id: int in s.avatars:
			if id != Net.local_id():
				_client_id = id
				Log.info(&"autotest", "AUTOTEST READY host")
				var input: Dictionary = _input
				var me: PlayerCharacter = s.local_avatar()
				me.weapons.recoil_enabled = false
				me.bot_driver = func(_p: PlayerCharacter, _d: float) -> PlayerInputFrame:
					var f: PlayerInputFrame = PlayerInputFrame.new()
					f.fire = bool(input["fire"])
					input["fire"] = false
					return f
		return
	if not _fired and elapsed() > 4.0:
		_fired = true
		var me2: PlayerCharacter = s.local_avatar()
		var d: TargetDummy = Match.current.map_root.find_child("Dummy_20m", true, false) as TargetDummy
		var dir: Vector3 = (d.zone_position(WeaponDefinition.Hitzone.TORSO) - me2.weapons.eye_position()).normalized()
		me2.set_view(atan2(-dir.x, -dir.z), asin(dir.y))
		_input["fire"] = true


func _on_phase(_sender: int, p: Array) -> void:
	var ws: WeaponSync = Match.current.weapons
	var v: HitValidator = ws.validator
	if String(p[0]) == "cheats":
		_rejections_before_cheats = v.rejection_count()
		return
	# "done": the forged claims were sent in one reliable batch right after the cheats marker.
	var rej: Dictionary = v.rejections
	result["rejections"] = rej
	result["accepted_shots"] = v.accepted_shots
	result["accepted_hits"] = v.accepted_hits
	check("no_rejections_for_legit_play", _rejections_before_cheats == 0, _rejections_before_cheats)
	check("legit_hits_applied", v.accepted_hits >= 5, v.accepted_hits)
	var near: TargetDummy = Match.current.map_root.find_child("Dummy_10m", true, false) as TargetDummy
	check(
		"dummy_10m_took_client_hit",
		near.damage_log.size() >= 1 and is_equal_approx(float(near.damage_log[0][0]), 40.0),
		near.damage_log
	)
	check("rejected_dead_target", int(rej.get("DEAD_TARGET", 0)) >= 1, rej)
	check("rejected_beyond_range", int(rej.get("RANGE", 0)) >= 2, rej)
	check("rejected_faster_than_rpm", int(rej.get("RATE", 0)) >= 3, rej)
	check("only_the_legal_forged_shot_applied", near.damage_log.size() == 2, near.damage_log.size())
	check("host_relayed_client_fire", ws.shots_relayed >= 6, ws.shots_relayed)
	await get_tree().create_timer(0.5).timeout
	finish(true)
