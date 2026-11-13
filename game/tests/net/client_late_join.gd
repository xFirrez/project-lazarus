# Client side of the late-join net test (see host_late_join.gd): measures welcome -> full join
# snapshot (< 2 s), checks doors / barricades / round / flag / points / waiting state against the
# host, spawns at round 4, then pings the M14 wall-buy from in front of it.
extends "res://tests/net/autotest_base.gd"

var _done: bool = false


func _ready() -> void:
	timeout = 110.0
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


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _run() -> void:
	var got: bool = await _until(
		func() -> bool: return _m() != null and _m().session.join_snapshot_seconds >= 0.0, 20.0
	)
	check("join_snapshot_received", got)
	if not got:
		finish(false)
		return
	var m: Match = _m()
	var me: PlayerCharacter = m.players.local_avatar()
	check("full_state_under_2s", m.session.join_snapshot_seconds < 2.0, "%.2f s" % m.session.join_snapshot_seconds)
	await _wait(0.3)  # loadout / downed events queued right behind the marker
	var d01: PurchasableDoor = m.interaction.find_by_name("D01_Buy") as PurchasableDoor
	check("door_d01_open", d01.is_open())
	check("barricade_0_two_planks", m.world.barricades[0].planks == 2, m.world.barricades[0].planks)
	check("round_3_active", m.rounds.current_round == 3 and m.rounds.phase == RoundDirector.Phase.ACTIVE)
	check("flag_power_off", String(m.session.flags.get("power", "")) == "off", str(m.session.flags))
	check("late_points_1250", m.points.get_points(me.peer_id) == 1250, m.points.get_points(me.peer_id))
	check("spectating_until_next_round", me.spectating and m.downed.state_of(me.peer_id) == DownedSystem.State.WAITING)
	check("zombies_visible", m.zombies.alive_count() >= 2, m.zombies.alive_count())
	Net.send_reliable(1, &"_t_digest", [m.world.digest()])
	var r4: bool = await _until(func() -> bool: return m.rounds.current_round == 4 and not me.spectating, 30.0)
	check("spawned_next_round", r4 and m.downed.state_of(me.peer_id) == DownedSystem.State.ALIVE)
	check(
		"starting_loadout",
		m.weapons.mirror_digest_of(me.peer_id).begins_with("m1911"),
		m.weapons.mirror_digest_of(me.peer_id)
	)
	m.players.request_teleport(Vector3(-1.5, 0.05, -5.6))
	await _wait(1.0)
	me.set_view(0.0, -0.05)
	await _wait(0.2)
	var info: Dictionary = m.pings.classify(me, me.camera.global_position, -me.camera.global_transform.basis.z)
	check("classified_wall_buy", int(info["kind"]) == PingSystem.Kind.ITEM, str(info))
	check("ping_sent", m.pings.ping_from_view())
	var shown: bool = await _until(func() -> bool: return m.pings.active.has(me.peer_id), 5.0)
	check("ping_marker_shown", shown)
	await _until(func() -> bool: return _done, 20.0)
	finish(true)
