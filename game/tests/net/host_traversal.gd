# Host side of the traversal net test (DEVELOPMENT_PLAN Step 8, AC-8.4 / AC-8.5) on vesper_peak
# at --netsim. The host turns the power on BEFORE the client joins (late-join power state), then:
#  1. gondola: the client is moved into the Arrival Station cabin, the host starts the ride; the
#     client must arrive at the Comms Array station without a single movement correction;
#  2. freight lift: the client and a zombie board at the Courtyard (the host waits in Specimen
#     Storage below, so the lift is the zombie's only route); the host calls the lift -> both
#     arrive at the bottom, the zombie walks off it toward the host;
#  3. chute: the host shoots the grate, the client steps into the chute -> lands in Specimen
#     Storage after the slide.
extends "res://tests/net/autotest_base.gd"

var _client: int = 0
var _corrections: int = 0


func _ready() -> void:
	timeout = 170.0
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


func _cpos() -> Vector3:
	return (_m().players.avatars[_client] as PlayerCharacter).global_position


func _run() -> void:
	await _until(func() -> bool: return _m() != null and _m().players.local_avatar() != null, 20.0)
	var m: Match = _m()
	m.downed.show_screen = false
	var me: PlayerCharacter = m.players.local_avatar()
	me.health.invulnerable = true
	await _until(func() -> bool: return m.zombies.crowd.is_ready(), 20.0)
	m.rounds.enabled = false
	m.zombies.host_kill_all()
	Power.host_set(Power.MAIN, true)
	check("power_on_host", Power.is_on())
	Log.info(&"autotest", "AUTOTEST READY host")
	var ok_join: bool = await _until(func() -> bool: return m.players.avatars.size() >= 2, 40.0)
	check("client_joined", ok_join)
	for id: int in m.players.avatars:
		if id != me.peer_id:
			_client = id
	m.players.corrected.connect(func(peer: int, _r: String) -> void: _corrections += 1 if peer == _client else 0)
	var c: PlayerCharacter = m.players.avatars[_client]
	c.health.invulnerable = true
	await _wait(3.0)
	m.zombies.host_kill_all()
	# 1. Gondola.
	var cab: TraversalMachine = m.map_root.find_child("GND_Gondola", true, false) as TraversalMachine
	m.players.host_teleport(_client, cab.station_position(0) + Vector3(0, 0.1, 0))
	await _wait(1.5)
	_corrections = 0
	check("gondola_request", cab.host_request() == "")
	await _wait(cab.boarding_delay + cab.ride_time + 1.5)
	var at: Vector3 = _cpos()
	check("gondola_rider_arrived", at.distance_to(cab.station_position(1)) < 2.0, at)
	check("gondola_no_corrections", _corrections == 0, _corrections)
	# 2. Freight lift with a zombie aboard (host below: the lift is the only route).
	var lift: TraversalMachine = m.map_root.find_child("LFT_FreightLift", true, false) as TraversalMachine
	me.motor.teleport(Vector3(75, -27.9, -44))
	m.players.host_teleport(_client, lift.station_position(0) + Vector3(0.6, 0.1, 0.6))
	await _wait(1.0)
	var z: ZombieActor = m.zombies.host_spawn(
		Content.get_def(&"ZombieArchetype", &"zombie") as ZombieArchetype,
		ZombieArchetype.Tier.RUN,
		Vector3(60.0, -8.0, -31.5),
		PI * 0.5,
		ZombieSpawner.Kind.RISER
	)
	c.notarget = true
	var boarded: bool = await _until(func() -> bool: return lift.contains(z.global_position, Net.host_time()), 25.0)
	check("lift_zombie_boarded", boarded, z.global_position)
	_corrections = 0
	check("lift_request", lift.host_request() == "")
	await _wait(lift.boarding_delay + lift.ride_time + 0.5)
	var cz: Vector3 = _cpos()
	check(
		"lift_rider_arrived", absf(cz.y - lift.station_position(1).y) < 1.0 and lift.contains(cz, Net.host_time()), cz
	)
	check("lift_no_corrections", _corrections == 0, _corrections)
	check("lift_zombie_rode", is_instance_valid(z) and absf(z.global_position.y + 28.0) < 1.0, z.global_position)
	var d0: float = z.global_position.distance_to(me.global_position)
	await _wait(3.0)
	check(
		"lift_zombie_walks_off",
		is_instance_valid(z) and z.global_position.distance_to(me.global_position) < d0 - 2.0,
		[d0, z.global_position]
	)
	m.zombies.host_kill_all()
	# 3. Chute: shoot the grate, step in.
	var grate: ShootableGrate = m.map_root.find_child("CHT_GrateTarget", true, false) as ShootableGrate
	m.targets.host_damage(
		grate, DamageInfo.make(50.0, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.BULLET, &"m1911", me.peer_id)
	)
	await _wait(0.5)
	var ch: Chute = m.map_root.find_child("CHT_LaundryChute", true, false) as Chute
	check("chute_grate_open", ch.is_open())
	m.players.host_teleport(_client, ch.global_position + Vector3(-0.3, -0.9, 0))
	await _wait(ch.travel_time + 2.0)
	check("chute_rider_landed", _cpos().distance_to(ch.exit_point) < 3.0, _cpos())
	Net.send_reliable(_client, &"_t_done", [])
	await _wait(2.0)
	finish(true)
