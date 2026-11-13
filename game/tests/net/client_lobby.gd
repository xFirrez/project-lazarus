# Client side of the lobby net test (see host_lobby.gd). Role from --profile:
#   netclient1: tries the host's character (refused), takes Ashcombe, readies up
#   netclient2: chats, readies up
#   netclient3: joins after the match started with late join off -> refused, back in the menu
extends "res://tests/net/autotest_base.gd"

var _role: String = ""
var _done: bool = false


func _ready() -> void:
	timeout = 110.0
	_role = CommandLine.get_value("profile", "")
	Net.register_message(&"_t_done", func(_s: int, _p: Array) -> void: _done = true)
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


func _me() -> int:
	return Net.local_id()


func _run() -> void:
	if _role == "netclient3":
		var back: bool = await _until(
			func() -> bool: return Game.state == Game.State.MAIN_MENU and Game.menu_message.contains("late join"), 20.0
		)
		check("refused_with_reason", back, Game.menu_message)
		check("never_loaded_match", Match.current == null)
		finish(true)
		return
	var lobby: bool = await _until(
		func() -> bool:
			return Game.state == Game.State.LOBBY and Session.lobby.has_peer(_me()) and Game._screen is LobbyScreen,
		20.0
	)
	check("in_lobby_screen", lobby)
	check("late_join_setting_mirrored", not Session.lobby.late_join and Session.lobby.starting_round == 2)
	if _role == "netclient1":
		var taken: StringName = Session.character_of(1)
		Session.request_character(taken)
		await _wait(1.0)
		check("taken_character_refused", Session.character_of(_me()) != taken, Session.character_of(_me()))
		Session.request_character(&"ashcombe")
		var got: bool = await _until(func() -> bool: return Session.character_of(_me()) == &"ashcombe", 5.0)
		check("picked_ashcombe", got)
	else:
		await _until(func() -> bool: return Session.lobby.slots.size() == 3, 20.0)
		Session.send_chat("hello from netclient2")
	await _wait(0.5)
	Session.request_set_ready(true)
	var in_match: bool = await _until(func() -> bool: return Game.state == Game.State.IN_MATCH, 30.0)
	check("match_started", in_match)
	var m: Match = Match.current
	var me: PlayerCharacter = m.players.local_avatar()
	check("my_character", me != null and me.character_id == Session.character_of(_me()), me.character_id if me else "")
	var host: PlayerCharacter = m.players.avatars.get(1, null)
	check("host_colour", host != null and host.player_color() == Session.character_def(1).color)
	var r2: bool = await _until(func() -> bool: return m.rounds.phase == RoundDirector.Phase.ACTIVE, 30.0)
	check("round_2_started", r2 and m.rounds.current_round == 2, m.rounds.current_round)
	var over: bool = await _until(func() -> bool: return Game.state == Game.State.GAME_OVER, 40.0)
	check("game_over", over)
	var back: bool = await _until(
		func() -> bool: return Game.state == Game.State.LOBBY and Game._screen is LobbyScreen, 20.0
	)
	check("returned_to_lobby", back and not Session.lobby.is_ready(_me()))
	Session.send_chat("back %s" % _role)
	await _until(func() -> bool: return _done, 15.0)
	finish(true)
