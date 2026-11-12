# Host side of the Step 11 progression net test (AC-11.1, AC-11.2, AC-11.4, AC-11.5) on vesper_peak
# at --netsim:
#  0. before the client joins: power on, R1 finished, T1 active (late-join replication of flags);
#  1. the client starts R2 by its own interact request; it charges while only the client is in Z05,
#     pauses when the client leaves (flag replicated), resumes; R2 / R3 finished -> the client sees
#     relays_done, the extended bridge (WorldSync), the stabilized reactor and the Forge awake;
#  2. the client forges its M14: the job's owner is the client, the host is refused ("In use"), the
#     client takes the M14 "Mnemonic" (its own inventory);
#  3. the client activates T2: the host kills the zombies in it, the client is paid 50 per kill and
#     sees the ACTIVE phase; a T3-frozen zombie shows FROZEN on the client; an impact splash is shown
#     on the client;
#  4. a shot fuel drum is dead on the client and back after the respawn.
extends "res://tests/net/autotest_base.gd"

var _client: int = 0
var _acks: Dictionary = {}


func _ready() -> void:
	timeout = 150.0
	Net.register_message(&"_t_ack", func(_s: int, p: Array) -> void: _acks[String(p[0])] = p.slice(1))
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


# Asks the client to run step `name`'s checks and waits for its acknowledgement.
func _step(name: String, payload: Array = [], limit: float = 15.0) -> bool:
	Net.send_reliable(_client, &"_t_step", [name] + payload)
	var ok: bool = await _until(func() -> bool: return _acks.has(name), limit)
	check("client_step_%s" % name, ok)
	return ok


func _zombie(pos: Vector3) -> ZombieActor:
	var m: Match = _m()
	return m.zombies.host_spawn(m.zombies.archetype(&"zombie"), 0, pos, 0.0, ZombieSpawner.Kind.VENT)


func _run() -> void:
	await _until(func() -> bool: return _m() != null and _m().players.local_avatar() != null, 20.0)
	var m: Match = _m()
	m.downed.show_screen = false
	var me: PlayerCharacter = m.players.local_avatar()
	var host_id: int = me.peer_id
	me.notarget = true
	me.health.invulnerable = true
	await _until(func() -> bool: return m.zombies.crowd.is_ready(), 20.0)
	m.rounds.enabled = false
	m.zombies.auto_respawn = false
	m.zombies.host_kill_all()
	# 0. State before the join.
	Power.host_set(Power.MAIN, true)
	m.relays.host_complete(0)
	m.traps.host_activate(m.traps.by_id(&"T1"), host_id)
	me.motor.teleport(Vector3(0, 0.1, 2))
	Log.info(&"autotest", "AUTOTEST READY host")
	var found: bool = await _until(func() -> bool: return m.players.avatars.size() >= 2, 30.0)
	check("client_joined", found)
	if not found:
		finish(false)
		return
	for id: int in m.players.avatars:
		if id != host_id:
			_client = id
	var c: PlayerCharacter = m.players.avatars[_client]
	c.notarget = true
	c.health.invulnerable = true
	await _wait(2.0)
	await _step("late_join")
	# 1. R2 by the client.
	var r2: ResonanceRelay = m.relays.relays[1]
	m.players.host_teleport(_client, r2.global_position + Vector3(1.2, 0.05, 0))
	await _wait(1.0)
	Net.send_reliable(_client, &"_t_use", [r2.interact_id])
	var started: bool = await _until(func() -> bool: return m.relays.state(1) == RelaySystem.State.CHARGING, 8.0)
	check("client_started_r2", started)
	await _wait(2.0)
	check(
		"r2_charges_with_client_in_zone",
		m.relays.progress_of(1) > 1.0 and not m.relays.is_paused(1),
		m.relays.progress_of(1)
	)
	m.players.host_teleport(_client, Vector3(2, 0.1, 2))
	var paused: bool = await _until(func() -> bool: return m.relays.is_paused(1), 3.0)
	check("r2_paused_without_players", paused)
	await _step("paused")
	m.players.host_teleport(_client, r2.global_position + Vector3(1.2, 0.05, 0))
	await _until(func() -> bool: return not m.relays.is_paused(1), 3.0)
	m.relays.host_complete(1)
	m.relays.host_complete(2)
	await _wait(0.5)
	check("relays_done", m.relays.all_done() and m.forge.is_unlocked())
	await _step("relays_done")
	# 2. Forge by the client.
	var forge: LazarusForge = m.forge.forges[0]
	m.weapons.host_give(_client, &"m14")
	m.points.host_set(_client, 6000)
	m.players.host_teleport(_client, forge.global_position + Vector3(0, 0.05, 2.0))
	me.motor.teleport(forge.global_position + Vector3(1.5, 0.05, 2.0))
	await _wait(1.5)
	Net.send_reliable(_client, &"_t_use", [forge.interact_id])
	var forging: bool = await _until(func() -> bool: return m.forge.phase(0) == ForgeSystem.Phase.FORGING, 8.0)
	check("client_forging", forging and int(m.forge.job_of(0)[0]) == _client)
	check("client_paid_5000", m.points.get_points(_client) == 1000, m.points.get_points(_client))
	await _step("forging")
	await _until(func() -> bool: return m.forge.phase(0) == ForgeSystem.Phase.OFFER, 7.0)
	check("host_refused_take", not m.interaction.host_handle(host_id, forge.interact_id))
	check("host_refusal_in_use", m.forge.host_check(0, host_id, &"m1911") == "In use")
	Net.send_reliable(_client, &"_t_use", [forge.interact_id])
	var took: bool = await _until(
		func() -> bool: return (m.weapons.loadouts[_client]["ids"] as Array).has(&"m14_up"), 8.0
	)
	check("client_took_m14_up", took)
	await _step("took_upgrade")
	# 3. T2 by the client; T3 freeze + splash replication.
	var t2: Trap = m.traps.by_id(&"T2")
	var pts: PackedVector3Array = t2.def.sample_points(t2.area_marker.global_transform, 2.5)
	var zs: Array[ZombieActor] = []
	for i: int in 3:
		zs.append(_zombie(pts[i * 2]))
	m.points.host_set(_client, 2000)
	m.players.host_teleport(_client, t2.global_position + Vector3(0, -1.15, -1.0))
	await _wait(1.5)
	Net.send_reliable(_client, &"_t_use", [t2.interact_id])
	var active: bool = await _until(func() -> bool: return m.traps.phase(t2) == TrapSystem.Phase.ACTIVE, 8.0)
	check("client_activated_t2", active and m.traps.activator(t2) == _client)
	await _wait(0.8)
	check("t2_killed", zs.all(func(z: ZombieActor) -> bool: return not is_instance_valid(z) or not z.alive))
	check("t2_paid_client", m.points.get_points(_client) == 2000 - 1000 + 150, m.points.get_points(_client))
	await _step("t2")
	var t3: Trap = m.traps.by_id(&"T3")
	var ring: PackedVector3Array = t3.def.sample_points(t3.area_marker.global_transform, 2.5)
	var zf: ZombieActor = _zombie(ring[ring.size() / 2])
	await _wait(0.5)
	m.traps.host_activate(t3, host_id)
	await _until(func() -> bool: return m.status.is_frozen(zf), 2.0)
	check("t3_frozen_host", m.status.is_frozen(zf))
	await _step("frozen", [zf.net_id])
	m.weapons.host_splash(Vector3(0, 0.5, -4), 2.0, 100.0, 10.0, &"kar98k_up", host_id)
	await _step("splash")
	# 4. Fuel drum.
	var d: ExplosiveDrum = m.hazards.drums[0]
	m.targets.host_damage(
		d, DamageInfo.make(60.0, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.BULLET, &"m1911", host_id)
	)
	await _wait(0.3)
	check("drum_dead_host", not d.alive)
	await _step("drum_dead", [d.target_id])
	m.targets.host_revive_target(d)
	await _step("drum_back", [d.target_id])
	finish(true)
