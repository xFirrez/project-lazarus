# Client side of the 4-player net test (see host_coop4.gd): an aim bot shoots the nearest visible
# zombie through the normal weapon path (local hit detection -> hit claims -> host validation);
# measures the downstream bandwidth during the 32-zombie phase (AC-7.4: <= 25 KB/s).
extends "res://tests/net/autotest_base.gd"

const BANDWIDTH_BUDGET: float = 25.0 * 1024.0

var _phase: String = ""
var _done: bool = false
var _toggle: bool = false
var _bw: PackedFloat32Array = []


func _ready() -> void:
	var rounds: int = maxi(CommandLine.get_value("rounds", "10").to_int(), 1)
	timeout = 470.0 + maxf(0.0, rounds - 10.0) * 22.0
	Net.register_message(&"_t_phase", func(_s: int, p: Array) -> void: _phase = String(p[0]))
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


func _run() -> void:
	var in_match: bool = await _until(func() -> bool: return _m() != null and _m().players.local_avatar() != null, 30.0)
	check("in_match", in_match)
	if not in_match:
		finish(false)
		return
	var m: Match = _m()
	m.downed.show_screen = false
	var me: PlayerCharacter = m.players.local_avatar()
	me.weapons.recoil_enabled = false
	me.bot_driver = _drive
	await _until(func() -> bool: return _phase == "bandwidth", 120.0)
	var t0: float = elapsed()
	while elapsed() - t0 < 11.5:
		await get_tree().create_timer(1.0).timeout
		if elapsed() - t0 > 2.0:  # skip the spawn burst
			_bw.append(Net.bytes_in_per_sec)
	var avg: float = 0.0
	var peak: float = 0.0
	for v: float in _bw:
		avg += v / _bw.size()
		peak = maxf(peak, v)
	result["bandwidth_avg_kbps"] = avg / 1024.0
	result["bandwidth_peak_kbps"] = peak / 1024.0
	result["zombies_seen"] = m.zombies.alive_count()
	check(
		"bandwidth_within_25kbps",
		avg <= BANDWIDTH_BUDGET,
		"avg %.1f KB/s, peak %.1f KB/s" % [avg / 1024.0, peak / 1024.0]
	)
	var mem0: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	await _until(func() -> bool: return _done, timeout - 30.0)
	var growth: float = (Performance.get_monitor(Performance.MEMORY_STATIC) - mem0) / maxf(mem0, 1.0)
	result["memory_growth"] = snappedf(growth, 0.001)
	check("memory_growth_le_10pct", growth <= 0.10, growth)
	result["kills"] = m.points.stat(me.peer_id, &"kills")
	result["points"] = m.points.get_points(me.peer_id)
	result["rtt_ms"] = Net.rtt_ms()
	check("finished_with_host", _done)
	finish(true)


func _drive(p: PlayerCharacter, _dt: float) -> PlayerInputFrame:
	var f: PlayerInputFrame = PlayerInputFrame.new()
	var m: Match = _m()
	if m == null or p.spectating or _phase != "rounds" or p.health.is_downed:
		return f
	var eye: Vector3 = p.weapons.eye_position()
	var best: ZombieActor = null
	var best_d: float = 28.0
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	for a: Variant in m.zombies.actors.values():
		var z: ZombieActor = a
		if not z.alive:
			continue
		var aim: Vector3 = z.global_position + Vector3.UP * 1.2
		var d: float = eye.distance_to(aim)
		if d >= best_d:
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, aim, 1)
		if not space.intersect_ray(q).is_empty():
			continue
		best = z
		best_d = d
	if best == null:
		return f
	var dir: Vector3 = (best.global_position + Vector3.UP * 1.2 - eye).normalized()
	p.set_view(atan2(-dir.x, -dir.z), asin(clampf(dir.y, -1.0, 1.0)))
	_toggle = not _toggle
	f.fire = _toggle
	return f
