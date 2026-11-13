# Client side of the weapon net test (AC-3.4) at --netsim latency: (1) a legit M1911 hit shows the
# hit marker in the same physics frame as the shot; (2) the host applies damage and the killable
# dummy's health replicates back; (3) once it is dead, a forged hit claim on it; (4) forged claims
# beyond weapon range; (5) forged claims faster than the RPM allows. The host checks the
# rejections. The client also checks that it saw the host's relayed fire burst.
extends "res://tests/net/autotest_base.gd"

enum Phase { WAIT, LEGIT_HIT, REPLICATE, KILL, CHEATS, DONE }

var _phase: Phase = Phase.WAIT
var _input: Dictionary = {"fire": false}
var _shot_frame: int = -1
var _marker_frame: int = -1
var _phase_start: float = 0.0
var _shots_in_phase: int = 0
var _wait_frames: int = 0


func _ready() -> void:
	timeout = 45.0
	Net.register_message(&"_autotest_phase", func(_s: int, _p: Array) -> void: pass)


func _me() -> PlayerCharacter:
	return sync().local_avatar() if sync() != null else null


func _dummy(n: String) -> TargetDummy:
	return Match.current.map_root.find_child(n, true, false) as TargetDummy


func _aim(me: PlayerCharacter, point: Vector3) -> void:
	var d: Vector3 = (point - me.weapons.eye_position()).normalized()
	me.set_view(atan2(-d.x, -d.z), asin(d.y))


func _physics_process(_delta: float) -> void:
	var s: PlayerSync = sync()
	if s == null or s.avatars.size() < 2:
		return
	var me: PlayerCharacter = _me()
	if me == null or me.weapons.held() == null:
		return
	match _phase:
		Phase.WAIT:
			if elapsed() < 3.0 or me.weapons.held().state != WeaponRuntime.State.IDLE:
				return
			var input: Dictionary = _input
			me.bot_driver = func(_p: PlayerCharacter, _d: float) -> PlayerInputFrame:
				var f: PlayerInputFrame = PlayerInputFrame.new()
				f.fire = bool(input["fire"])
				return f
			me.weapons.recoil_enabled = false
			me.weapons.perfect_accuracy = true
			me.weapons.shot_fired.connect(
				func(_d: WeaponDefinition, _r: Ballistics.ShotResult) -> void: _shot_frame = Engine.get_physics_frames()
			)
			me.weapons.hit_confirmed.connect(
				func(_t: HitTarget, _a: float, _z: int, _k: bool) -> void: _marker_frame = Engine.get_physics_frames()
			)
			_next(Phase.LEGIT_HIT)
		Phase.LEGIT_HIT:
			_aim(me, _dummy("Dummy_10m").zone_position(WeaponDefinition.Hitzone.TORSO))
			if _fire_shots(me, 1):
				check(
					"hit_marker_same_frame_as_shot",
					_marker_frame == _shot_frame and _shot_frame > 0,
					[_shot_frame, _marker_frame]
				)
				check("hud_marker_shown", me.weapons.hud.markers_shown >= 1, me.weapons.hud.markers_shown)
				_next(Phase.REPLICATE)
		Phase.REPLICATE:
			var kill: TargetDummy = _dummy("Dummy_Kill")
			_aim(me, kill.zone_position(WeaponDefinition.Hitzone.TORSO))
			if _shots_in_phase < 2:
				_fire_shots(me, 2)
				return
			if is_equal_approx(kill.health, 70.0):
				check(
					"dummy_health_replicated",
					true,
					"150 -> %.0f after 2 torso hits (%.2f s)" % [kill.health, elapsed() - _phase_start]
				)
				_next(Phase.KILL)
			elif elapsed() - _phase_start > 4.0:
				check("dummy_health_replicated", false, kill.health)
				_next(Phase.KILL)
		Phase.KILL:
			var kill2: TargetDummy = _dummy("Dummy_Kill")
			_aim(me, kill2.zone_position(WeaponDefinition.Hitzone.TORSO))
			if kill2.alive and _shots_in_phase < 2:
				_fire_shots(me, 2)
			elif not kill2.alive:
				check("dummy_killed_and_replicated", true)
				_next(Phase.CHEATS)
			elif elapsed() - _phase_start > 4.0:
				check("dummy_killed_and_replicated", false, kill2.health)
				_next(Phase.CHEATS)
		Phase.CHEATS:
			if elapsed() - _phase_start > 1.0:  # well clear of the last legit shot's fire interval
				_send_cheats(me)
				_next(Phase.DONE)
		Phase.DONE:
			if elapsed() - _phase_start > 2.0 and _phase_start > 0.0:
				_phase_start = -1.0
				var host_avatar: PlayerCharacter = s.avatars.get(1, null)
				var replays: int = host_avatar.weapons.remote_replays if host_avatar != null else 0
				check("client_saw_host_fire_burst", replays >= 1, replays)
				Net.send_reliable(1, &"_autotest_phase", ["done"])
				_leave_soon.call_deferred()


func _next(p: Phase) -> void:
	_phase = p
	_phase_start = elapsed()
	_shots_in_phase = 0
	_wait_frames = 0
	Log.info(&"autotest", "client phase %s" % Phase.keys()[p])


# Fires `n` shots in this phase, one press at a time, ~0.4 s apart. Returns true when done.
func _fire_shots(me: PlayerCharacter, n: int) -> bool:
	_input["fire"] = false
	if _shots_in_phase >= n:
		return true
	_wait_frames += 1
	if _wait_frames < 24:
		return false
	var before: int = me.weapons.shots_total
	_input["fire"] = true
	if me.weapons.shots_total > before:
		pass
	_shots_in_phase += 1
	_wait_frames = 0
	return false


func _claim(me: PlayerCharacter, weapon: StringName, t: float, hits: Array) -> Array:
	me.weapons._shot_seq += 1
	var o: Vector3 = me.weapons.eye_position()
	var f: Vector3 = me.weapons.aim_forward()
	return [String(weapon), me.weapons._shot_seq, t, o.x, o.y, o.z, f.x, f.y, f.z, 0.0, 1, hits]


func _send_cheats(me: PlayerCharacter) -> void:
	var torso: int = WeaponDefinition.Hitzone.TORSO
	var dead: TargetDummy = _dummy("Dummy_Kill")
	var far: TargetDummy = _dummy("Dummy_40m")
	var near: TargetDummy = _dummy("Dummy_10m")
	# Stamps stay within the host's future slack and respect the M1911's rate for the first two.
	var t: float = Net.host_time()
	var claims: Array = []
	claims.append(_claim(me, &"m1911", t - 0.3, [[dead.target_id, torso, 8.0, 0, 0]]))  # dead target
	claims.append(_claim(me, &"m1911", t - 0.15, [[far.target_id, torso, 300.0, 0, 0]]))  # claimed range
	claims.append(_claim(me, &"knife", t, [[near.target_id, torso, 12.0, 0, 0]]))  # knife at 12 m
	for i: int in 4:  # 5 ms apart: far faster than 400 RPM (the first one is legal)
		claims.append(_claim(me, &"m1911", t + 0.05 + i * 0.005, [[near.target_id, torso, 12.0, 0, 0]]))
	Net.send_reliable(1, &"_autotest_phase", ["cheats", claims.size()])
	Net.send_reliable(1, &"_wshots", claims)


func _leave_soon() -> void:
	await get_tree().create_timer(1.5).timeout
	Net.leave_session("autotest done")
	await get_tree().create_timer(0.3).timeout
	finish(true)
