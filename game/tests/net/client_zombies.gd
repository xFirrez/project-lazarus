# Client side of the zombie net test (AC-5.6, AC-5.3 replication, late join): checks the zombie
# snapshot bandwidth (<= 15 KB/s for 32 zombies), interpolated motion smoothness (no per-frame
# snaps), then fires the M1911 with scripted aim at the torso hurtbox of the nearest visible moving
# zombie for ~12 s and reports the number of hit claims; the host compares with what it accepted.
# Finally compares barricade planks and zombie count with the host's report.
extends "res://tests/net/autotest_base.gd"

const MAX_KBPS: float = 15.0
const MAX_FRAME_STEP_M: float = 0.25
const SHOOT_TIME: float = 12.0

var _spawned_count: int = -1
var _first_count: int = -1
var _bytes_at: int = 0
var _bytes_t0: float = -1.0
var _measure_done: bool = false
var _last_pos: Dictionary = {}
var _max_step: float = 0.0
var _steps_checked: int = 0
var _shoot_t0: float = -1.0
var _claims: int = 0
var _input: Dictionary = {"fire": false}
var _fire_frame: int = 0
var _done_sent: bool = false
var _moving_targets: int = 0
var _alive_at_done: int = -1
var _all_spawned: bool = false


func _ready() -> void:
	timeout = 70.0
	Net.register_message(&"_autotest_phase", _on_phase)
	Net.register_message(&"_autotest_report", _on_report)


func _zs() -> ZombieSync:
	return Match.current.zombies if Match.current != null else null


func _on_phase(_s: int, p: Array) -> void:
	if String(p[0]) == "spawned":
		_spawned_count = int(p[1])


func _physics_process(delta: float) -> void:
	var s: PlayerSync = sync()
	var zs: ZombieSync = _zs()
	if s == null or zs == null or s.avatars.size() < 2:
		return
	var me: PlayerCharacter = s.local_avatar()
	if me == null or me.weapons.held() == null:
		return
	if _first_count < 0 and zs.alive_count() > 0:
		_first_count = zs.alive_count()
		check("late_join_full_state", _first_count >= 8, _first_count)
	if not _all_spawned:
		# Gate once: later re-queues briefly despawn / respawn zombies (count may dip by one).
		if _spawned_count < 0 or zs.alive_count() < _spawned_count:
			return
		_all_spawned = true
	_track_smoothness(zs, delta)
	if _bytes_t0 < 0.0:
		_bytes_t0 = elapsed() + 1.0  # let the counts settle
		return
	if elapsed() < _bytes_t0:
		_bytes_at = zs.snapshot_bytes_in
		return
	if not _measure_done and elapsed() > _bytes_t0 + 8.0:
		_measure_done = true
		var kbps: float = (zs.snapshot_bytes_in - _bytes_at) / 8.0 / 1024.0
		result["zombie_snapshot_kbps"] = kbps
		result["zombies"] = zs.alive_count()
		check(
			"snapshot_bandwidth_le_15kbps",
			kbps <= MAX_KBPS and kbps > 1.0,
			"%.2f KB/s for %d" % [kbps, zs.alive_count()]
		)
		_start_shooting(me)
	if _shoot_t0 >= 0.0:
		_shoot(me)


func _track_smoothness(zs: ZombieSync, _delta: float) -> void:
	for a: ZombieActor in zs.actors.values():
		var p: Vector3 = a.global_position
		if (
			_last_pos.has(a.net_id)
			and a.flags & ZombieActor.Flag.TRAVERSING == 0
			and a.action != ZombieActor.Action.RISE
		):
			var step: float = (p - (_last_pos[a.net_id] as Vector3)).length()
			_max_step = maxf(_max_step, step)
			_steps_checked += 1
		_last_pos[a.net_id] = p


func _start_shooting(me: PlayerCharacter) -> void:
	_shoot_t0 = elapsed()
	var input: Dictionary = _input
	me.bot_driver = func(_p: PlayerCharacter, _d: float) -> PlayerInputFrame:
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.fire = bool(input["fire"])
		return f
	me.weapons.recoil_enabled = false
	me.weapons.perfect_accuracy = true
	me.weapons.hit_confirmed.connect(
		func(t: HitTarget, _a: float, _z: int, _k: bool) -> void:
			if t is ZombieActor:
				_claims += 1
	)


func _shoot(me: PlayerCharacter) -> void:
	_fire_frame += 1
	_input["fire"] = false
	if elapsed() - _shoot_t0 > SHOOT_TIME:
		if not _done_sent:
			_done_sent = true
			check(
				"smooth_motion",
				_max_step <= MAX_FRAME_STEP_M and _steps_checked > 1000,
				"max step %.3f m over %d" % [_max_step, _steps_checked]
			)
			result["claims"] = _claims
			result["moving_targets_shot_at"] = _moving_targets
			_alive_at_done = _zs().alive_count()
			Net.send_reliable(1, &"_autotest_phase", ["done", _claims])
		return
	var t: ZombieActor = _pick_target(me)
	if t == null:
		return
	var aim: Vector3 = t.zone_position(WeaponDefinition.Hitzone.TORSO)
	var d: Vector3 = (aim - me.weapons.eye_position()).normalized()
	me.set_view(atan2(-d.x, -d.z), asin(d.y))
	if _fire_frame % 8 == 0 and me.weapons.held().state == WeaponRuntime.State.IDLE:
		_input["fire"] = true
		if t.speed > 0.5:
			_moving_targets += 1


func _pick_target(me: PlayerCharacter) -> ZombieActor:
	var eye: Vector3 = me.weapons.eye_position()
	var space: PhysicsDirectSpaceState3D = me.get_world_3d().direct_space_state
	var best: ZombieActor = null
	var best_d: float = 25.0
	for a: ZombieActor in _zs().actors.values():
		if not a.alive or a.flags & ZombieActor.Flag.TRAVERSING != 0:
			continue
		var p: Vector3 = a.zone_position(WeaponDefinition.Hitzone.TORSO)
		var dist: float = eye.distance_to(p)
		if dist < best_d and dist > 2.0 and HitValidator.has_line_of_sight(space, eye, p):
			best_d = dist
			best = a
	return best


func _on_report(_s: int, p: Array) -> void:
	var zs: ZombieSync = _zs()
	var w: Array = []
	for b: Barricade in Match.current.world.barricades:
		w.append(b.planks)
	var corpses: int = 0
	for n: Node in zs.get_children():
		if n is ZombieActor and (n as ZombieActor).visual.dead:
			corpses += 1
	check("zombie_count_matches_host", _alive_at_done == int(p[0]), [_alive_at_done, p[0]])
	check("deaths_replicated", zs.alive_count() == 0 and corpses >= int(p[0]), [zs.alive_count(), corpses])
	check("barricades_replicated", w == (p[1] as Array), [w, p[1]])
	finish(true)
