# Host side of the Vigor Tonic / power-up net test (DEVELOPMENT_PLAN Step 10, AC-10.2 co-op part,
# AC-10.4) on vesper_peak at --netsim:
#  1. co-op prices (Second Wind 1500); the client buys Quickdraw at its machine through the real
#     interaction request: paid, drink, perk replicated, the client's reload time halves;
#  2. the client holds Second Wind and revives the downed host in ~2 s (co-op variant);
#  3. power-ups the client walks onto: Max Ammo refills the client's reserve, Insta-Kill's timer
#     flag is identical on both peers, and the client's host-clock estimate is within 100 ms
#     (one-way latency removed), so the countdowns agree (AC-10.4);
#  4. the client goes down: its perks are gone on both peers.
extends "res://tests/net/autotest_base.gd"

var _client: int = 0
var _client_done: bool = false
var _clock_errors: Array = []


func _ready() -> void:
	timeout = 150.0
	Net.register_message(&"_t_cdone", func(_s: int, _p: Array) -> void: _client_done = true)
	Net.register_message(&"_t_clock_r", _on_clock)
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


func _machine(perk: StringName) -> PerkMachine:
	for pm: PerkMachine in _m().perks.machines:
		if pm.perk_id == perk:
			return pm
	return null


func _on_clock(_sender: int, p: Array) -> void:
	# p = [client's host-time estimate when sent, client rtt seconds]
	_clock_errors.append(Net.now() - float(p[0]) - float(p[1]) * 0.5)


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
	m.zombies.host_kill_all()
	Power.host_set(Power.MAIN, true)
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
	await _wait(2.0)
	var ps: PerkSystem = m.perks
	check("coop_not_solo", not ps.is_solo())
	check(
		"second_wind_coop_price", _machine(&"second_wind").get_cost(me) == 1500, _machine(&"second_wind").get_cost(me)
	)
	# 1. Client buys Quickdraw.
	m.points.host_set(_client, 20000)
	var qd: PerkMachine = _machine(&"quickdraw")
	m.players.host_teleport(_client, qd.global_position + qd.global_transform.basis.z * 1.1 + Vector3.UP * 0.05)
	await _wait(1.0)
	await _until(func() -> bool: return c.global_position.distance_to(qd.focus_point()) < 2.0, 6.0)
	await _wait(0.5)
	note(
		(
			"client at %s, machine focus %s (%.2f m)"
			% [c.global_position, qd.focus_point(), c.global_position.distance_to(qd.focus_point())]
		)
	)
	Net.send_reliable(_client, &"_t_use", [qd.interact_id])
	var got: bool = await _until(func() -> bool: return ps.has_perk(_client, &"quickdraw"), 10.0)
	check("client_bought_quickdraw", got)
	check("client_paid_3000", m.points.get_points(_client) == 17000, m.points.get_points(_client))
	await _wait(1.0)
	Net.send_reliable(_client, &"_t_check_perks", [["quickdraw"]])
	await _wait(1.0)
	# 2. Co-op Second Wind revive.
	ps.host_grant(_client, &"second_wind")
	await _wait(0.5)
	check(
		"revive_time_2s_host",
		is_equal_approx(m.downed.revive_time_for(_client), 2.0),
		m.downed.revive_time_for(_client)
	)
	me.motor.teleport(m.players.spawn_point_for(host_id))
	await _wait(0.3)
	m.downed.host_force_down(host_id)
	await _wait(0.5)
	check(
		"host_downed_no_game_over",
		m.downed.state_of(host_id) == DownedSystem.State.DOWNED and not m.downed.is_game_over
	)
	m.players.host_teleport(_client, me.global_position + Vector3(1.0, 0.1, 0.0))
	await _wait(1.0)
	var t0: float = Net.now()
	Net.send_reliable(_client, &"_t_revive", [host_id, true])
	var revived: bool = await _until(func() -> bool: return m.downed.state_of(host_id) == DownedSystem.State.ALIVE, 8.0)
	var took: float = Net.now() - t0
	check("second_wind_revive_2s", revived and took > 1.9 and took < 3.0, took)
	Net.send_reliable(_client, &"_t_revive", [host_id, false])
	me.health.invulnerable = true
	# 3. Power-ups picked by the client.
	var spot: Vector3 = c.global_position
	Net.send_reliable(_client, &"_t_drain", [])
	await _wait(1.0)
	var before: int = m.powerups.picked_total
	m.powerups.host_spawn(&"max_ammo", spot)
	var picked: bool = await _until(func() -> bool: return m.powerups.picked_total > before, 5.0)
	check("client_picked_max_ammo", picked)
	await _wait(1.0)
	m.players.host_teleport(_client, spot + Vector3(0, 0.1, 3.0))
	await _wait(1.0)
	before = m.powerups.picked_total
	m.powerups.host_spawn(&"insta_kill", c.global_position)
	picked = await _until(func() -> bool: return m.powerups.picked_total > before, 5.0)
	check("client_picked_insta_kill", picked)
	var until: float = float(m.session.flag(PowerUpSystem.flag_key(&"insta_kill"), -1.0))
	await _wait(1.0)
	Net.send_reliable(_client, &"_t_pu_check", [until])
	await _until(func() -> bool: return _clock_errors.size() >= 10, 10.0)
	var errs: Array = _clock_errors.duplicate()
	errs.sort()
	var median: float = float(errs[errs.size() / 2]) if not errs.is_empty() else 1.0
	check("clock_error_under_100ms", absf(median) < 0.1, "median %.1f ms over %d" % [median * 1000.0, errs.size()])
	# 4. Client down: perks lost everywhere.
	m.downed.host_force_down(_client)
	await _wait(1.0)
	check("client_perks_lost_host", ps.ids_of(_client).is_empty())
	Net.send_reliable(_client, &"_t_lost", [])
	await _until(func() -> bool: return _client_done, 15.0)
	check("client_done", _client_done)
	m.downed.host_revive(_client, 0)
	finish(true)
