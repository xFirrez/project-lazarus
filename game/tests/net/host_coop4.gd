# Host side of the 4-player net test (AC-7.1, AC-7.4) on vesper_peak; every peer runs at
# --netsim=150,30,0.03. The host plays with a SurvivalBot; three clients play with aim bots that
# shoot through the real weapon path (hit claims). Phase A: 32 zombies + 4 players for 12 s while
# the clients measure their downstream bandwidth. Phase B: 10 rounds (intermission shortened to
# 3 s; a round still alive after ROUND_LIMIT is finished by the host, no points), D01 / D02 bought
# for two clients along the way. At every round end each client reports its state hash; the host
# requires 30 / 30 matches (round, zones, doors, barricades, flags, points, weapons, zombie count).
extends "res://tests/net/autotest_base.gd"

const ROUND_LIMIT: float = 14.0
const CLIENTS: int = 3

# Step 16 soak: `--rounds=N` (tools/net_tests.sh: COOP4_ROUNDS) plays N rounds instead of 10 and
# checks the host's memory growth (<= 10 %) between round 5 and the end (AC-16.2).
var rounds_target: int = 10
var _clients: Array[int] = []
var _round_t0: float = 0.0
var _mem_r5: float = 0.0
var _orphans_r5: int = 0


func _ready() -> void:
	rounds_target = maxi(CommandLine.get_value("rounds", "10").to_int(), 1)
	timeout = 480.0 + maxf(0.0, rounds_target - 10.0) * 22.0
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
	var rd: RoundDirector = m.rounds
	rd.paused = true
	var curve: RoundCurve = rd.curve.duplicate() as RoundCurve
	curve.intermission = 3.0
	rd.curve = curve
	if m.spawns != null:
		m.spawns.curve = curve
	var me: PlayerCharacter = m.players.local_avatar()
	me.health.invulnerable = true
	await _until(func() -> bool: return m.zombies.crowd.is_ready(), 20.0)
	Log.info(&"autotest", "AUTOTEST READY host")
	var all_in: bool = await _until(func() -> bool: return Net.peer_ids().size() == CLIENTS + 1, 90.0)
	check("four_players", all_in, Net.peer_ids().size())
	if not all_in:
		finish(false)
		return
	await _wait(2.0)
	for id: int in Net.peer_ids():
		if id != me.peer_id:
			_clients.append(id)
		(m.players.avatars[id] as PlayerCharacter).health.invulnerable = true
		m.weapons.host_set_infinite_ammo(id, true)
	_clients.sort()
	# Phase A: bandwidth at 32 zombies + 4 players.
	var arch: ZombieArchetype = m.zombies.archetype(&"zombie")
	for i: int in 32:
		m.zombies.host_spawn_at_spawner(arch, ZombieArchetype.Tier.WALK)
	await _until(func() -> bool: return m.zombies.alive_count() >= 32, 10.0)
	check("phase_a_32_zombies", m.zombies.alive_count() >= 32, m.zombies.alive_count())
	m.zombies.crowd.frozen = false
	Net.send_reliable(0, &"_t_phase", ["bandwidth"])
	var min_alive: int = 99
	for i: int in 24:  # 12 s; zombies the brain re-queues (no path / too far) are topped up
		await _wait(0.5)
		min_alive = mini(min_alive, m.zombies.alive_count())
		for k: int in maxi(32 - m.zombies.alive_count(), 0):
			m.zombies.host_spawn_at_spawner(arch, ZombieArchetype.Tier.WALK)
	result["bandwidth_phase_min_alive"] = min_alive
	check("kept_about_32_zombies", min_alive >= 29, min_alive)
	Net.send_reliable(0, &"_t_phase", ["rounds"])
	m.zombies.host_kill_all()
	await _wait(1.0)
	SurvivalBot.attach(me, m, 7)
	rd.paused = false
	# Phase B: ten rounds with hash checks at every round end.
	var last_round: int = 0
	while elapsed() < timeout - 20.0:
		await get_tree().physics_frame
		if rd.phase == RoundDirector.Phase.ACTIVE and rd.current_round != last_round:
			last_round = rd.current_round
			_round_t0 = elapsed()
			if last_round == 5:
				_mem_r5 = Performance.get_monitor(Performance.MEMORY_STATIC)
				_orphans_r5 = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
			if last_round % 25 == 0:
				Log.info(
					&"autotest",
					(
						"soak round %d t=%.0f s mem %.1f MB"
						% [last_round, elapsed(), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0]
					)
				)
			if last_round > rounds_target:
				break
		if rd.phase == RoundDirector.Phase.ACTIVE and elapsed() - _round_t0 > ROUND_LIMIT:
			rd.host_skip_round()
		if rd.phase == RoundDirector.Phase.INTERMISSION and rd.current_round == 2 and _clients.size() >= 1:
			await _buy_for(m, _clients[0], "D01_Buy", Vector3(11.6, 0.05, -3))
		if rd.phase == RoundDirector.Phase.INTERMISSION and rd.current_round == 4 and _clients.size() >= 2:
			await _buy_for(m, _clients[1], "D02_Buy", Vector3(6.6, 0.05, -6.6))
	check("played_all_rounds", last_round > rounds_target, last_round)
	await _wait(2.0)  # last hash reports in flight
	var per_round: Dictionary = {}
	for e: Variant in m.session.hash_log:
		var row: Array = e
		if bool(row[2]):
			per_round[int(row[0])] = int(per_round.get(int(row[0]), 0)) + 1
	var full: int = 0
	for r: int in range(1, rounds_target + 1):
		if int(per_round.get(r, 0)) == CLIENTS:
			full += 1
	check("hash_mismatches_0", m.session.hash_mismatches == 0, m.session.hash_mismatches)
	var detail: String = "%d / %d rounds" % [full, rounds_target]
	if full != rounds_target and rounds_target <= 20:
		detail += ", %s" % str(per_round)
	check("all_peers_agree_every_round", full == rounds_target, detail)
	result["hash_matches"] = m.session.hash_matches
	result["rounds"] = rounds_target
	result["soak_seconds"] = snappedf(elapsed(), 1.0)
	if rounds_target >= 20 and _mem_r5 > 0.0:
		var mem_end: float = Performance.get_monitor(Performance.MEMORY_STATIC)
		var growth: float = (mem_end - _mem_r5) / _mem_r5
		result["host_memory_growth"] = snappedf(growth, 0.001)
		check("host_memory_growth_le_10pct", growth <= 0.10, [_mem_r5, mem_end])
		var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		check("host_orphans_flat", orphans <= _orphans_r5 + 5, [_orphans_r5, orphans])
	var d01: PurchasableDoor = m.interaction.find_by_name("D01_Buy") as PurchasableDoor
	var d02: PurchasableDoor = m.interaction.find_by_name("D02_Buy") as PurchasableDoor
	check("doors_bought", d01.is_open() and d02.is_open())
	var kills: int = 0
	for id: int in _clients:
		kills += m.points.stat(id, &"kills")
	result["client_kills"] = kills
	check("clients_scored", kills > 0, kills)
	Net.send_reliable(0, &"_t_done", [])
	await _wait(2.0)
	finish(true)


func _buy_for(m: Match, peer: int, door: String, pos: Vector3) -> void:
	var d: PurchasableDoor = m.interaction.find_by_name(door) as PurchasableDoor
	if d.is_open():
		return
	m.points.host_earn(peer, d.cost)
	m.players.host_teleport(peer, pos)
	await _wait(0.6)
	check("bought_%s" % door, m.interaction.host_handle(peer, d.interact_id) and d.is_open())
