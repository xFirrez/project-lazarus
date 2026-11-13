# Host side of the late-join net test (AC-7.2) on vesper_peak at --netsim. Before the client joins:
# D01 bought, a barricade torn to 2 planks, round 3 active (zombies frozen so the world holds still).
# The client joins mid-round: it must get the full state (its world digest equals the host's), be
# WAITING (spectating) until the next round, and have 500 + 250 x 3 = 1250 points. Then the host
# ends round 3; at round 4 the client spawns. The client pings the M14 wall-buy: the host relays it.
extends "res://tests/net/autotest_base.gd"

var _client: int = 0
var _client_digest: PackedStringArray = []
var _pings: Array = []


func _ready() -> void:
	timeout = 120.0
	Net.register_message(
		&"_t_digest",
		func(s: int, p: Array) -> void:
			_client = s
			_client_digest = PackedStringArray(p[0])
	)
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
	await _until(func() -> bool: return _m() != null and _m().players.local_avatar() != null, 20.0)
	var m: Match = _m()
	m.downed.show_screen = false
	var me: PlayerCharacter = m.players.local_avatar()
	me.notarget = true
	me.health.invulnerable = true
	m.pings.pinged.connect(
		func(peer: int, kind: StringName, _p: Vector3, label: String) -> void: _pings.append([peer, kind, label])
	)
	await _until(func() -> bool: return m.zombies.crowd.is_ready(), 20.0)
	m.points.host_set(me.peer_id, 2000)
	me.motor.teleport(Vector3(11.6, 0.05, -3))
	await _wait(0.2)
	var d01: PurchasableDoor = m.interaction.find_by_name("D01_Buy") as PurchasableDoor
	check("host_bought_d01", m.interaction.host_handle(me.peer_id, d01.interact_id) and d01.is_open())
	WorldSync.host_set_barricade(m.world.barricades[0], 2)
	m.rounds.host_start_round(3)
	await _until(func() -> bool: return m.rounds.round_ids.size() >= 2, 20.0)
	m.zombies.crowd.frozen = true
	m.session.host_set_flag("power", "off")
	Log.info(&"autotest", "AUTOTEST READY host")
	var joined: bool = await _until(func() -> bool: return not _client_digest.is_empty(), 40.0)
	check("client_joined_and_reported", joined)
	if not joined:
		finish(false)
		return
	var mine: PackedStringArray = m.world.digest()
	check("client_world_matches_host", mine == _client_digest, "host %s / client %s" % [mine, _client_digest])
	check("client_waiting_on_host", m.downed.state_of(_client) == DownedSystem.State.WAITING)
	check("client_points_1250", m.points.get_points(_client) == 1250, m.points.get_points(_client))
	check("round_still_3", m.rounds.current_round == 3 and m.rounds.phase == RoundDirector.Phase.ACTIVE)
	await _wait(1.0)
	m.zombies.crowd.frozen = false
	m.rounds.host_skip_round()
	var r4: bool = await _until(
		func() -> bool: return m.rounds.current_round == 4 and m.rounds.phase == RoundDirector.Phase.ACTIVE, 25.0
	)
	check("round_4", r4)
	await _wait(0.5)
	check("client_spawned_at_round_4", m.downed.state_of(_client) == DownedSystem.State.ALIVE)
	var cl: PlayerCharacter = m.players.avatars[_client]
	cl.health.invulnerable = true
	cl.notarget = true
	var pinged: bool = await _until(func() -> bool: return not _pings.is_empty(), 20.0)
	check(
		"client_ping_relayed",
		pinged and int(_pings[0][0]) == _client and _pings[0][1] == &"item" and String(_pings[0][2]).contains("M14"),
		str(_pings)
	)
	Net.send_reliable(_client, &"_t_done", [])
	await _wait(1.5)
	finish(true)
