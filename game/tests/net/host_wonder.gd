# Host side of the Step 12 net test (AC-12.1..12.5 with 2 peers) on vesper_peak at --netsim:
#  1. the client picks up a Conduit part through its own interact request: the shared team inventory
#     flag is set on the host and replicated to the client;
#  2. the client fires the Lazarus Conduit (real input) at a line of zombies: the host resolves the
#     chain (>= 3 struck, survivors stunned) and the client sees the arcs and ELECTROCUTED copies;
#  3. the client fires the Ray Pistol: the host's authoritative plasma bolt kills the zombie and the
#     client sees the burst and the disintegration;
#  4. a forced special round: special id / next special reach the client, rifts open on the client;
#  5. a Warden: its broken plate count reaches the client (`_warden`).
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


func _step(name: String, payload: Array = [], limit: float = 15.0) -> bool:
	Net.send_reliable(_client, &"_t_step", [name] + payload)
	var ok: bool = await _until(func() -> bool: return _acks.has(name), limit)
	check("client_step_%s" % name, ok)
	return ok


func _line(m: Match, from: Vector3, n: int, hp: float) -> Array[ZombieActor]:
	var out: Array[ZombieActor] = []
	for i: int in n:
		var p: Vector3 = from + Vector3(0, 0, -2.5 * i)
		out.append(m.zombies.host_spawn(m.zombies.archetype(&"zombie"), 0, p, 0.0, ZombieSpawner.Kind.WINDOW, -1, hp))
	return out


func _run() -> void:
	await _until(func() -> bool: return _m() != null and _m().players.local_avatar() != null, 20.0)
	var m: Match = _m()
	m.downed.show_screen = false
	var me: PlayerCharacter = m.players.local_avatar()
	me.notarget = true
	me.health.invulnerable = true
	await _until(func() -> bool: return m.zombies.crowd.is_ready(), 20.0)
	m.rounds.enabled = false
	m.rounds.paused = true
	m.zombies.auto_respawn = false
	m.zombies.host_kill_all()
	Power.host_set(Power.MAIN, true)
	me.motor.teleport(Vector3(0, 0.1, 2))
	Log.info(&"autotest", "AUTOTEST READY host")
	var found: bool = await _until(func() -> bool: return m.players.avatars.size() >= 2, 30.0)
	check("client_joined", found)
	if not found:
		finish(false)
		return
	for id: int in m.players.avatars:
		if id != me.peer_id:
			_client = id
	var cl: PlayerCharacter = m.players.avatars[_client]
	cl.notarget = true
	await _wait(2.0)
	# 1. Part pickup by the client.
	var bs: BuildableSystem = m.buildables
	var part: BuildablePart = null
	for bp: BuildablePart in bs.parts:
		if bp.is_here() and bp.part == &"coil":
			part = bp
	check("coil_live", part != null)
	if part != null:
		# Bring the part to the client (the host's range check is all that matters; ids are unchanged).
		part.global_position = cl.global_position + Vector3(1.0, 0.0, 0.0)
		await _wait(0.5)
		Net.send_reliable(_client, &"_t_use", [part.interact_id])
		var got: bool = await _until(func() -> bool: return bs.has_part(&"conduit", &"coil"), 8.0)
		check("client_picked_coil", got)
		check("coil_credit_client", int(m.session.flag("build.conduit.by.coil", 0)) == _client)
		await _step("part")
	# 2. Conduit chain from the client's own trigger pull.
	var stand: Vector3 = Vector3(0, 0.1, 2)
	m.players.host_teleport(_client, stand)
	await _wait(1.0)
	check("give_conduit", m.weapons.host_give(_client, &"lazarus_conduit"))
	var zs: Array[ZombieActor] = _line(m, Vector3(0, 0, -3), 5, 40000.0)
	await _wait(1.5)
	var chains0: int = m.weapons.chains
	await _step("fire", [zs[0].zone_position(WeaponDefinition.Hitzone.TORSO)])
	var fired: bool = await _until(func() -> bool: return m.weapons.chains > chains0, 6.0)
	check("host_resolved_client_chain", fired)
	check("chain_struck_3plus", m.weapons.last_chain.size() >= 3, m.weapons.last_chain.size())
	check("chain_stunned", m.weapons.last_chain.all(func(e: Array) -> bool: return bool(e[2])))
	await _step("chain_seen", [zs[0].net_id])
	for z: ZombieActor in zs:
		if z.alive:
			m.zombies.host_kill(z)
	# 3. Ray Pistol from the client.
	check("give_ray", m.weapons.host_give(_client, &"ray_pistol"))
	var rz: ZombieActor = _line(m, Vector3(0, 0, -6), 1, 900.0)[0]
	await _wait(1.5)
	var ex0: int = m.weapons.explosions
	await _step("fire", [rz.zone_position(WeaponDefinition.Hitzone.TORSO)])
	var blew: bool = await _until(func() -> bool: return m.weapons.explosions > ex0, 6.0)
	check("host_plasma_splash", blew)
	await _wait(0.3)
	check("ray_killed", not rz.alive)
	await _step("ray_seen", [rz.net_id])
	# 4. Special round.
	m.rounds.enabled = true
	m.rounds.forced_special = &"galvanic"
	m.rounds.host_start_round(6)
	check("host_special", m.rounds.special_id == &"galvanic")
	await _until(func() -> bool: return m.spawns.rifts_opened > 0, 10.0)
	check("rift_opened", m.spawns.rifts_opened > 0)
	await _step("special")
	m.rounds.host_skip_round()
	m.rounds.paused = true
	await _wait(0.5)
	m.zombies.host_kill_all()
	# 5. Warden plate replication.
	var w: ZombieActor = WardenBehavior.host_spawn(m.zombies, Vector3(0, 0, -12), 0.0, 10, 2)
	check("warden", w != null)
	if w != null:
		await _wait(1.0)
		var wb: WardenBehavior = w.behavior as WardenBehavior
		var info: DamageInfo = DamageInfo.make(
			wb.plates[0] + 10.0, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.BULLET, &"m1911", me.peer_id
		)
		m.targets.host_damage(w, info)
		check("plate_broken_host", wb.plates_left() == 2)
		await _step("warden", [w.net_id])
	await _step("done")
	finish(true)
