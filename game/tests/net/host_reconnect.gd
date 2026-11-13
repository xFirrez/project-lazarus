# Host side of the reconnect net test (AC-7.3) on vesper_peak at --netsim. The client gets 3210
# points, the M14 + MP40 and Pack Mule (third slot); the driver SIGKILLs it; the host retains its state by
# player_uid; the relaunched client (same profile = same uid) gets points, weapons (with the
# host-mirrored ammo), perk and character back, waits for the next round and respawns.
extends "res://tests/net/autotest_base.gd"

var _restored_peer: int = 0
var _retained: Dictionary = {}

var _cycles: int = 1  # Step 16 reconnect stress: --reconnect-cycles=N kills / relaunches the client N times


func _ready() -> void:
	_cycles = maxi(CommandLine.get_value("reconnect-cycles", "1").to_int(), 1)
	timeout = 120.0 + 25.0 * (_cycles - 1)
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


func _other(m: Match) -> int:
	for id: int in m.players.avatars:
		if id != Net.local_id():
			return id
	return 0


func _run() -> void:
	await _until(func() -> bool: return _m() != null and _m().players.local_avatar() != null, 20.0)
	var m: Match = _m()
	m.downed.show_screen = false
	var me: PlayerCharacter = m.players.local_avatar()
	me.notarget = true
	me.health.invulnerable = true
	m.session.player_restored.connect(func(peer: int, _uid: String) -> void: _restored_peer = peer)
	m.session.player_retained.connect(func(_uid: String, rec: Dictionary) -> void: _retained = rec.duplicate(true))
	await _until(func() -> bool: return m.rounds.phase == RoundDirector.Phase.ACTIVE, 20.0)
	m.zombies.crowd.frozen = true
	Log.info(&"autotest", "AUTOTEST READY host")
	var joined: bool = await _until(func() -> bool: return _other(m) != 0, 30.0)
	check("client_joined", joined)
	var first: int = _other(m)
	var uid: String = String((Net.peers[first] as Dictionary)["uid"])
	var character: StringName = Session.character_of(first)
	await _wait(0.5)
	m.points.host_set(first, 3210)
	m.points.host_add_stat(first, &"kills", 7)
	m.weapons.host_give(first, &"m14")
	m.perks.host_grant(first, &"pack_mule")
	m.weapons.host_give(first, &"mp40")  # third weapon: needs Pack Mule restored before the loadout
	Log.info(&"autotest", "AUTOTEST GAVE client")
	# The fast relaunch drops the stale connection on rejoin, so retain + restore can happen in one
	# frame: observe the retention through the signal.
	var left: bool = await _until(func() -> bool: return not _retained.is_empty(), 30.0)
	check("state_retained_by_uid", left and int(_retained.get("points", 0)) == 3210, str(_retained))
	check("character_retained", StringName(String(_retained.get("character", ""))) == character)
	check("uid_known", uid != "")
	var back: bool = await _until(func() -> bool: return _restored_peer != 0, 40.0)
	check("rejoined_and_restored", back)
	if not back:
		finish(false)
		return
	# Reconnect stress: every further kill / relaunch must retain and restore the same state.
	var cycles_ok: int = 1
	for c: int in range(1, _cycles):
		_retained = {}
		_restored_peer = 0
		var kept: bool = await _until(func() -> bool: return not _retained.is_empty(), 30.0)
		var again: bool = await _until(func() -> bool: return _restored_peer != 0, 40.0)
		if kept and again and m.points.get_points(_restored_peer) == 3210 and int(_retained.get("points", 0)) == 3210:
			cycles_ok += 1
		Log.info(&"autotest", "reconnect cycle %d: retained %s restored %s" % [c + 1, kept, again])
	result["reconnect_cycles"] = [cycles_ok, _cycles]
	check("every_reconnect_restored", cycles_ok == _cycles, [cycles_ok, _cycles])
	if _restored_peer == 0:
		finish(false)
		return
	var p: int = _restored_peer
	check("new_peer_id", p != first)
	check("points_restored", m.points.get_points(p) == 3210, m.points.get_points(p))
	check("stats_restored", m.points.stat(p, &"kills") == 7, m.points.stat(p, &"kills"))
	check("old_row_dropped", not m.points.points.has(first) and m.points.summary().size() == 2)
	check("weapons_restored", m.weapons.digest_of(p).contains("m14"), m.weapons.digest_of(p))
	check("perks_restored", PerkSystem._strings(m.perks.ids_of(p)) == ["pack_mule"], m.perks.ids_of(p))
	check("third_weapon_restored", m.weapons.digest_of(p).contains("mp40"), m.weapons.digest_of(p))
	check("character_kept", Session.character_of(p) == character, Session.character_of(p))
	check("waits_for_next_round", m.downed.state_of(p) == DownedSystem.State.WAITING)
	m.zombies.crowd.frozen = false
	m.rounds.host_skip_round()
	var r2: bool = await _until(
		func() -> bool: return m.rounds.current_round == 2 and m.rounds.phase == RoundDirector.Phase.ACTIVE, 25.0
	)
	await _wait(0.5)
	check("respawned_next_round", r2 and m.downed.state_of(p) == DownedSystem.State.ALIVE)
	Net.send_reliable(p, &"_t_done", [])
	await _wait(1.5)
	finish(true)
