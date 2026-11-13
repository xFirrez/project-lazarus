# Host side of the survival net test (AC-6.4, AC-6.5, AC-6.6) on vesper_peak at --netsim:
#  1. Before the client joins the host buys D01 (late-join door state is checked by the client).
#  2. Simultaneous purchases: host and client (twice) request D02 in the same window -> exactly one
#     1000-point charge in total, no negative balances.
#  3. Downed / revive: the host goes down (last-stand pistol), the client holds revive -> revived
#     after revive_time with 50 % HP and the original weapon back.
#  4. Bleedout: the client goes down and bleeds out after bleedout_time (-10 % points, weapons reset,
#     spectating), then respawns at the next round start.
#  5. Both down -> game over on both peers.
extends "res://tests/net/autotest_base.gd"

var _client: int = 0


func _ready() -> void:
	timeout = 150.0
	Net.register_message(&"_t_ack", func(_s: int, _p: Array) -> void: pass)
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
	var host_id: int = me.peer_id
	me.notarget = true
	me.health.invulnerable = true
	await _until(func() -> bool: return m.zombies.crowd.is_ready(), 20.0)
	# 1. D01 before the client joins.
	m.points.host_set(host_id, 2000)
	me.motor.teleport(Vector3(11.6, 0.05, -3))
	await _wait(0.2)
	var d01: PurchasableDoor = m.interaction.find_by_name("D01_Buy") as PurchasableDoor
	check("host_bought_d01", m.interaction.host_handle(host_id, d01.interact_id) and d01.is_open())
	Log.info(&"autotest", "AUTOTEST READY host")
	var found: bool = await _until(func() -> bool: return m.players.avatars.size() >= 2, 30.0)
	check("client_joined", found)
	if not found:
		finish(false)
		return
	for id: int in m.players.avatars:
		if id != host_id:
			_client = id
	var cl: PlayerCharacter = m.players.avatars[_client]
	cl.notarget = true
	cl.health.invulnerable = true
	await _wait(2.0)
	# 2. Simultaneous purchases of D02.
	me.motor.teleport(Vector3(6.6, 0.05, -6.6))
	m.players.host_teleport(_client, Vector3(5.4, 0.05, -6.6))
	await _wait(1.0)
	m.points.host_set(host_id, 1500)
	m.points.host_set(_client, 1500)
	await _wait(0.5)
	var d02: PurchasableDoor = m.interaction.find_by_name("D02_Buy") as PurchasableDoor
	Net.send_reliable(_client, &"_t_buy", [d02.interact_id])
	await _wait(0.11)  # roughly when the client's requests arrive (netsim 100 ms one way)
	m.interaction.host_handle(host_id, d02.interact_id)
	await _wait(1.5)
	var hp: int = m.points.get_points(host_id)
	var cp: int = m.points.get_points(_client)
	check("d02_open", d02.is_open())
	check("single_charge", hp + cp == 2000 and hp >= 0 and cp >= 0, [hp, cp])
	check(
		"refused_counted",
		m.points.spends_refused == 0 and m.interaction.requests_denied >= 2,
		m.interaction.requests_denied
	)
	# 3. Host down, client revives.
	me.motor.teleport(Vector3(0, 0.05, -3))
	m.players.host_teleport(_client, Vector3(1.0, 0.05, -3))
	await _wait(1.0)
	var before_weapon: StringName = StringName((m.weapons.loadouts[host_id] as Dictionary)["current"])
	m.points.host_set(host_id, 1000)
	m.downed.host_force_down(host_id)
	check("host_downed", m.downed.state_of(host_id) == DownedSystem.State.DOWNED and me.health.is_downed)
	check("down_penalty_5pct", m.points.get_points(host_id) == 950, m.points.get_points(host_id))
	check("last_stand_pistol", m.weapons.is_last_stand(host_id))
	Net.send_reliable(_client, &"_t_revive", [])
	await _until(func() -> bool: return m.downed.revivers.has(host_id), 5.0)
	var t_rev: float = elapsed()
	var revived: bool = await _until(func() -> bool: return m.downed.state_of(host_id) == DownedSystem.State.ALIVE, 8.0)
	var took: float = elapsed() - t_rev
	check("revived_by_client", revived and m.points.stat(_client, &"revives") == 1)
	check("revive_time_4s", absf(took - 4.0) < 0.35, took)
	check("revive_half_hp", is_equal_approx(me.health.health, me.health.max_health * 0.5), me.health.health)
	check(
		"weapons_back",
		StringName((m.weapons.loadouts[host_id] as Dictionary)["current"]) == before_weapon,
		before_weapon
	)
	# 4. Client bleeds out, spectates, respawns next round.
	await _wait(1.0)
	m.points.host_set(_client, 2000)
	m.weapons.host_give(_client, &"m14")
	m.downed.host_force_down(_client)
	var t_down: float = elapsed()
	var bled: bool = await _until(
		func() -> bool: return m.downed.state_of(_client) == DownedSystem.State.BLED_OUT, 50.0
	)
	check("bleedout_45s", bled and absf(elapsed() - t_down - 45.0) < 0.5, elapsed() - t_down)
	check("bleedout_penalty", m.points.get_points(_client) == 1900 - 190, m.points.get_points(_client))
	check(
		"bleedout_loses_weapons",
		(m.weapons.loadouts[_client] as Dictionary)["ids"] == [&"m1911"],
		m.weapons.loadouts[_client]
	)
	check("spectating", cl.spectating)
	await _wait(1.0)
	m.rounds.host_start_round(m.rounds.current_round + 1)
	await _wait(0.5)
	check("respawned_next_round", m.downed.state_of(_client) == DownedSystem.State.ALIVE and not cl.spectating)
	check("respawn_full_hp", is_equal_approx(cl.health.health, cl.health.max_health))
	await _wait(2.0)
	# 5. Everyone down -> game over everywhere.
	m.downed.host_force_down(_client)
	await _wait(0.3)
	check("not_over_with_one_up", not m.downed.is_game_over)
	m.downed.host_force_down(host_id)
	check("game_over", m.downed.is_game_over and m.rounds.phase == RoundDirector.Phase.GAME_OVER)
	check("no_unfair_spawns", m.spawns.violations == 0, m.spawns.violations)
	await _wait(4.0)  # let the client receive the event and show its screen
	finish(true)
