# Host side of the Step 14 quest net test (AC-14.3) on vesper_peak at --netsim:
#  0. before the client joins: power, relays, the quest jumped to stage 4 (stages 0-3 done through
#     their objectives) and the host carrying the Heart;
#  1. late join: the client sees every quest flag, the step states, the carrier's restrictions and
#     the escort HUD line;
#  2. the host drops the Heart, the client picks it up through its own interact request ->
#     pistol-only loadout + no sprint on the client;
#  3. the client is killed (SIGKILL) while carrying: the Heart is auto-dropped on the host; the
#     client rejoins (reconnect by uid) with its loadout restored and the quest state intact;
#  4. finale: the round display "∞", the Warden and the pylons on the client; victory -> the
#     client's Journal gets R09 + the badge, its own Lazarus Blessing (7 tonics) and token.
extends "res://tests/net/autotest_base.gd"

var _client: int = 0
var _host_id: int = 1
var _acks: Dictionary = {}


func _ready() -> void:
	timeout = 170.0
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


func _wait_client() -> bool:
	var found: bool = await _until(func() -> bool: return _m().players.avatars.size() >= 2, 40.0)
	for id: int in _m().players.avatars:
		if id != _host_id:
			_client = id
	if found:
		var c: PlayerCharacter = _m().players.avatars[_client]
		c.notarget = true
		c.health.invulnerable = true
	return found


func _run() -> void:
	await _until(func() -> bool: return _m() != null and _m().players.local_avatar() != null, 20.0)
	var m: Match = _m()
	m.downed.show_screen = false
	var me: PlayerCharacter = m.players.local_avatar()
	_host_id = me.peer_id
	me.notarget = true
	me.health.invulnerable = true
	await _until(func() -> bool: return m.zombies.crowd.is_ready(), 20.0)
	m.rounds.paused = true
	m.zombies.host_kill_all()
	var q: QuestSystem = m.quest
	var w: VesperQuestWorld = VesperQuestWorld.of(m)
	Power.host_set(Power.MAIN, true)
	m.relays.host_complete_all()
	check("jump_stage4", q.host_jump(&"stage4"), q.describe())
	check("heart_present", w.heart.is_present())
	check("host_picks", w.heart.host_pick(_host_id))
	m.zombies.host_kill_all()
	Log.info(&"autotest", "AUTOTEST READY host")
	if not await _wait_client():
		check("client_joined", false)
		finish(false)
		return
	await _wait(2.0)
	await _step("late_join", [_host_id])
	# 2. Pass the Heart to the client.
	w.heart.host_drop(_host_id)
	var at: Vector3 = w.heart.ground_position()
	for attempt: int in 2:
		m.players.host_teleport(_client, at + Vector3(0.8, 0.1, 0.0))
		var near: Callable = func() -> bool: return m.players.avatars[_client].global_position.distance_to(at) < 2.0
		if await _until(near, 3.0):
			break
	await _wait(1.0)
	Net.send_reliable(_client, &"_t_use", [w.heart.interact_id])
	var got: bool = await _until(func() -> bool: return w.heart.carrier() == _client, 8.0)
	check("client_carries", got, w.heart.carrier())
	check("host_side_pistol_only", m.weapons.is_carrying(_client))
	await _step("carrying")
	Log.info(&"autotest", "AUTOTEST READY carry")
	# 3. The client is killed: auto-drop, then it reconnects.
	var old_client: int = _client
	var gone: bool = await _until(func() -> bool: return not m.players.avatars.has(old_client), 30.0)
	check("client_left", gone)
	check("auto_drop_on_leave", w.heart.carrier() == 0 and w.heart.is_present())
	if not await _until(func() -> bool: return m.players.avatars.size() >= 2, 40.0) or not await _wait_client():
		check("client_rejoined", false)
		finish(false)
		return
	await _wait(2.0)
	check("rejoined_loadout_restored", not m.weapons.is_carrying(_client))
	await _step("rejoined")
	# 4. Finale and victory.
	check("jump_stage6", q.host_jump(&"stage6"), q.describe())
	m.rounds.host_start_round(m.rounds.current_round + 1)
	await _until(func() -> bool: return int(q.flag("ee.finale", 0)) == 1, 5.0)
	await _step("finale")
	check("skip_finale", q.host_skip(&"stage6"))
	await _wait(0.5)
	await _step("victory", [], 20.0)
	finish(true)
