# Host side of the reconnect net test (AC-7.3) on vesper_peak at --netsim. The client gets 3210
# points, the M14 and a (placeholder) perk; the driver SIGKILLs it; the host retains its state by
# player_uid; the relaunched client (same profile = same uid) gets points, weapons (with the
# host-mirrored ammo), perk and character back, waits for the next round and respawns.
extends "res://tests/net/autotest_base.gd"

var _restored_peer: int = 0
var _retained: Dictionary = {}


func _ready() -> void:
	timeout = 120.0
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
	(m.players.avatars[first] as PlayerCharacter).perks = [&"test_tonic"]
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
	var p: int = _restored_peer
	check("new_peer_id", p != first)
	check("points_restored", m.points.get_points(p) == 3210, m.points.get_points(p))
	check("stats_restored", m.points.stat(p, &"kills") == 7, m.points.stat(p, &"kills"))
	check("old_row_dropped", not m.points.points.has(first) and m.points.summary().size() == 2)
	check("weapons_restored", m.weapons.digest_of(p).contains("m14"), m.weapons.digest_of(p))
	check("perks_restored", (m.players.avatars[p] as PlayerCharacter).perks == [&"test_tonic"])
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
