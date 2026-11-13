# Host side of the lobby net test (Step 7 scope 1-2, AC-7.5 uniqueness): `--host --lobby` on
# vesper_peak with two clients. Lobby: unique characters (a taken pick is refused), chat, host
# settings (late join off, starting round 2), ready-up, countdown -> every peer loads -> the
# RoundDirector holds until all report scene-ready -> round 2 on everyone. A third client is
# refused (late join off). Then everyone goes down -> game over -> "Return to lobby" brings all
# peers back with ready flags reset.
extends "res://tests/net/autotest_base.gd"


func _ready() -> void:
	timeout = 120.0
	_run()


func _until(cond: Callable, limit: float) -> bool:
	var t0: float = elapsed()
	while not cond.call():
		if elapsed() - t0 > limit:
			return false
		await get_tree().process_frame
	return true


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _chat_has(text: String) -> bool:
	for c: Variant in Session.lobby.chat:
		if String((c as Array)[2]) == text:
			return true
	return false


func _run() -> void:
	var in_lobby: bool = await _until(func() -> bool: return Game.state == Game.State.LOBBY and Net.is_host(), 15.0)
	check("host_in_lobby", in_lobby and Game._screen is LobbyScreen and Match.current == null)
	Session.host_set_late_join(false)
	Session.host_set_starting_round(2)
	Log.info(&"autotest", "AUTOTEST READY host")
	var three: bool = await _until(func() -> bool: return Session.lobby.slots.size() == 3, 40.0)
	check("three_in_lobby", three, Session.lobby.slots.size())
	if not three:
		finish(false)
		return
	var chat: bool = await _until(func() -> bool: return _chat_has("hello from netclient2"), 15.0)
	check("chat_received", chat)
	Session.send_chat("welcome")
	Session.request_set_ready(true)
	var ready: bool = await _until(func() -> bool: return Session.lobby.all_ready(), 30.0)
	var chars: Dictionary = {}
	for s: Dictionary in Session.lobby.slots:
		chars[s["character"]] = true
	check("characters_unique", chars.size() == 3 and not chars.has(&""), str(chars.keys()))
	check("client1_took_ashcombe", Session.lobby.peer_with_character(&"ashcombe") != 0)
	check("all_ready", ready)
	var t_start: float = elapsed()
	check("countdown_started", Session.host_start_countdown())
	await _until(func() -> bool: return Game.state == Game.State.IN_MATCH, 15.0)
	var countdown_s: float = elapsed() - t_start
	check("countdown_about_3s", countdown_s > 2.5 and countdown_s < 4.5, "%.2f s" % countdown_s)
	var m: Match = Match.current
	check("round_held_until_loaded", m.rounds.phase == RoundDirector.Phase.WAITING and not m.session.gate_open())
	var released: bool = await _until(func() -> bool: return m.rounds.phase != RoundDirector.Phase.WAITING, 20.0)
	var all_loaded: bool = true
	for id: int in m.session.waiting_ready:
		all_loaded = all_loaded and bool(m.session.waiting_ready[id])
	check("released_after_all_scene_ready", released and all_loaded, str(m.session.waiting_ready))
	for id: int in m.players.avatars:
		var a: PlayerCharacter = m.players.avatars[id]
		check(
			"avatar_%d_character" % m.players.player_ids().find(id),
			a.character_id == Session.character_of(id),
			a.character_id
		)
	var r2: bool = await _until(func() -> bool: return m.rounds.phase == RoundDirector.Phase.ACTIVE, 20.0)
	check("starting_round_2", r2 and m.rounds.current_round == 2, m.rounds.current_round)
	Log.info(&"autotest", "AUTOTEST READY match")
	var refused: bool = await _until(func() -> bool: return Net.refused_joins >= 1, 30.0)
	check("late_join_off_refused", refused, Net.refused_joins)
	check("refused_peer_not_in_roster", Session.lobby.slots.size() == 3 and m.players.avatars.size() == 3)
	for id: int in m.players.avatars:
		m.downed.host_force_down(id)
	var over: bool = await _until(func() -> bool: return Game.state == Game.State.GAME_OVER, 15.0)
	check(
		"game_over_screen",
		over and Game._screen is GameOverScreen and (Game._screen as GameOverScreen).show_lobby_button
	)
	await _wait(1.0)
	Session.host_return_to_lobby()
	check("host_back_in_lobby", Game.state == Game.State.LOBBY and Game._screen is LobbyScreen)
	check("ready_reset", not Session.lobby.is_ready(1) and not Session.in_match)
	var back: bool = await _until(
		func() -> bool: return _chat_has("back netclient1") and _chat_has("back netclient2"), 20.0
	)
	check("clients_back_in_lobby", back)
	Net.send_reliable(0, &"_t_done", [])
	await _wait(1.0)
	finish(true)
