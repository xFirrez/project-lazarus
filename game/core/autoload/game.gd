# Game — top-level state machine: Boot -> MainMenu -> Lobby -> Loading -> InMatch -> GameOver.
# Owns the current Match and the screens (main menu, map select, settings, lobby, game over).
# Menu flow: Solo -> map select -> match; Host -> map select -> lobby (Session) -> countdown ->
# every peer loads -> scene-ready gate (MatchSession) -> round 1; Join (IP / Steam) -> lobby.
# Command-line entry points:
#   --solo | --host[=port] | --join=ip[:port]   start a session directly (--host skips the lobby
#                                                unless --lobby is given; dev / tests)
#   --upnp                                       try a UPnP port mapping when hosting
#   --map=<map_id>                               map to play (default: first non-test map)
#   --exec="cmd; cmd"                            console commands once in a match/menu
#   --autotest=res://path.gd                     attach a scripted test driver node
#   --screenshot=<map_id> --screenshot-out=<dir> capture the map's shot cameras and quit
#   --version                                    print the build version and quit
#   --quit-after=<s>                             quit cleanly s seconds after the match started
# Authority: the host chooses the map and tells peers (reliable `_match_start` [map, from_lobby,
# first_round]; late joiners get it on join).
extends Node

enum State { BOOT, MAIN_MENU, LOBBY, LOADING, IN_MATCH, GAME_OVER }

const STATE_NAMES: PackedStringArray = ["Boot", "MainMenu", "Lobby", "Loading", "InMatch", "GameOver"]

var state: State = State.BOOT
var current_match: Match = null
var menu_message: String = ""
var selected_map: StringName = &""
var last_match_info: Dictionary = {}  # set at game over: map, players, seconds, quest progress

var _screen_layer: CanvasLayer = null
var _screen: Control = null
var _world: Node = null
var _pending_exec: String = ""
var _quick_start: bool = false  # host: skip the lobby (solo, CLI --host)
var _session_joined_at: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		Engine.max_fps = 120
	_world = Node.new()
	_world.name = "World"
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE  # the solo pause menu pauses the match
	add_child(_world)
	_screen_layer = CanvasLayer.new()
	_screen_layer.layer = 10
	add_child(_screen_layer)
	Net.session_started.connect(_on_session_started)
	Net.session_ended.connect(_on_session_ended)
	Net.connection_failed.connect(_on_connection_failed)
	Net.peer_joined.connect(_on_peer_joined)
	Net.register_message(&"_match_start", _on_msg_match_start)
	Session.lobby_changed.connect(_on_lobby_changed)
	Session.countdown_finished.connect(_on_countdown_finished)
	Session.return_to_lobby_requested.connect(return_to_lobby)
	Debug.commands.register("host", _cmd_host, [["port", TYPE_INT, Net.DEFAULT_PORT]], "Host a co-op session")
	Debug.commands.register("join", _cmd_join, [["address", TYPE_STRING]], "Join ip[:port]")
	Debug.commands.register("solo", _cmd_solo, [], "Start a solo session")
	Debug.commands.register("leave", _cmd_leave, [], "Leave the session and return to the menu")
	Debug.commands.register("game_state", _cmd_game_state, [], "Print the game state")
	call_deferred(&"boot")


func boot() -> void:
	if CommandLine.has_flag("version"):
		Log.info(&"build", "Project Lazarus %s" % BuildInfo.describe())
		get_tree().quit()
		return
	var autotest: String = CommandLine.get_value("autotest", "")
	if autotest != "":
		var script: GDScript = load(autotest) as GDScript
		if script == null:
			Log.error(&"game", "Cannot load autotest %s" % autotest)
			get_tree().quit(2)
			return
		var driver: Node = script.new()
		driver.name = "AutoTest"
		get_tree().root.add_child(driver)
	_pending_exec = CommandLine.get_value("exec", "")
	selected_map = StringName(CommandLine.get_value("map", String(default_map_id())))
	var shot: String = CommandLine.get_value("screenshot", "")
	if shot != "":
		selected_map = StringName(shot)
		var capture: ScreenshotCapture = ScreenshotCapture.new()
		capture.out_dir = CommandLine.get_value("screenshot-out", "user://screenshots")
		capture.shot_set = shot
		add_child(capture)
		start_solo()
		return
	if CommandLine.has_flag("solo"):
		start_solo()
	elif CommandLine.has_flag("host"):
		var port_str: String = CommandLine.get_value("host", "")
		host_game(
			port_str.to_int() if port_str.is_valid_int() else Net.DEFAULT_PORT,
			CommandLine.has_flag("lobby"),
			CommandLine.has_flag("upnp")
		)
	elif CommandLine.has_flag("join"):
		join_game(CommandLine.get_value("join", "127.0.0.1"))
	else:
		go_to_main_menu("")
		_run_pending_exec()


func default_map_id() -> StringName:
	var fallback: StringName = &""
	for res: Resource in Content.get_all(&"MapDefinition"):
		var def: MapDefinition = res as MapDefinition
		if not def.is_test_map:
			return def.id
		if fallback == &"" or String(def.id) < String(fallback):
			fallback = def.id
	return fallback


func start_solo() -> void:
	_quick_start = true
	if Net.start_solo() != OK:
		go_to_main_menu("Could not start solo session")


# use_lobby = false: dev quick host (CLI): the match starts immediately, peers join late.
func host_game(port: int, use_lobby: bool = true, try_upnp: bool = false) -> void:
	_quick_start = not use_lobby
	if Net.host_session(port, try_upnp) != OK:
		go_to_main_menu("Could not host on port %d" % port)


func host_steam_game() -> void:
	_quick_start = false
	if Net.host_steam() != OK:
		go_to_main_menu("Steam is not available (GodotSteam + a running Steam client are needed)")


# Map select (menu): Solo / Host pick the map first.
func show_map_select(for_host: bool) -> void:
	var screen: MapSelectScreen = MapSelectScreen.new()
	screen.selected = selected_map
	screen.confirm_text = "Host lobby" if for_host else "Start solo"
	screen.map_chosen.connect(
		func(map_id: StringName) -> void:
			selected_map = map_id
			if for_host:
				host_game(Net.DEFAULT_PORT, true, bool(Config.get_value(&"gameplay", &"upnp", true)))
			else:
				start_solo()
	)
	screen.back_pressed.connect(func() -> void: go_to_main_menu(""))
	_set_screen(screen)


func show_settings() -> void:
	var screen: SettingsScreen = SettingsScreen.new()
	screen.back_pressed.connect(func() -> void: go_to_main_menu(""))
	_set_screen(screen)


func show_journal() -> void:
	var screen: JournalScreen = JournalScreen.new()
	screen.back_pressed.connect(func() -> void: go_to_main_menu(""))
	_set_screen(screen)


func show_credits() -> void:
	var screen: CreditsScreen = CreditsScreen.new()
	screen.back_pressed.connect(func() -> void: go_to_main_menu(""))
	_set_screen(screen)


func show_lobby() -> void:
	_set_state(State.LOBBY)
	if _screen is LobbyScreen:
		return
	var screen: LobbyScreen = LobbyScreen.new()
	screen.leave_pressed.connect(func() -> void: leave_game(""))
	_set_screen(screen)


# Everyone back to the lobby after a game over (host: Session.host_return_to_lobby).
func return_to_lobby() -> void:
	_end_match("return to lobby")
	if not Net.is_active():
		go_to_main_menu("")
		return
	if Net.transport != null and not Net.transport.supports_clients():
		start_solo()  # solo "play again"
		return
	show_lobby()


func join_game(address: String) -> void:
	var host: String = address
	var port: int = Net.DEFAULT_PORT
	var colon: int = address.rfind(":")
	if colon > 0 and address.substr(colon + 1).is_valid_int():
		host = address.substr(0, colon)
		port = address.substr(colon + 1).to_int()
	Config.set_value(&"gameplay", &"last_join_address", address)
	_set_state(State.LOBBY)
	_show_message("Connecting to %s:%d ..." % [host, port])
	if Net.join_session(host, port) != OK:
		go_to_main_menu("Could not connect to %s" % address)


func leave_game(reason: String) -> void:
	Net.leave_session(reason)
	go_to_main_menu(reason)


func go_to_main_menu(message: String) -> void:
	_end_match(message)
	menu_message = message
	_set_state(State.MAIN_MENU)
	var menu: MainMenu = MainMenu.new()
	menu.solo_requested.connect(func() -> void: show_map_select(false))
	menu.host_requested.connect(func() -> void: show_map_select(true))
	menu.join_requested.connect(join_game)
	menu.steam_requested.connect(host_steam_game)
	menu.settings_requested.connect(show_settings)
	menu.journal_requested.connect(show_journal)
	menu.credits_requested.connect(show_credits)
	menu.quit_requested.connect(func() -> void: get_tree().quit())
	_set_screen(menu)
	if message != "":  # empty keeps a crash notice (CrashLog) the menu may show
		menu.set_status(message)
		Audio.play_event(&"ui_error")
		Log.info(&"game", "Main menu: %s" % message)


func show_game_over(reason: String) -> void:
	_end_match(reason)
	_set_state(State.GAME_OVER)
	var screen: MessageScreen = MessageScreen.new()
	screen.title = "GAME OVER — %s" % reason
	screen.action_text = "Main menu"
	screen.action_pressed.connect(func() -> void: leave_game(""))
	_set_screen(screen)


# Game over v1 (GAME_DESIGN §15): rounds survived + per-player stats; the host can take the session
# back to the lobby (solo: play again), anyone can leave to the main menu.
func show_match_summary(round_reached: int, rows: Array, subtitle: String = "") -> void:
	_end_match("game over")
	_set_state(State.GAME_OVER)
	var screen: GameOverScreen = GameOverScreen.new()
	screen.round_reached = round_reached
	screen.rows = rows
	screen.subtitle = subtitle
	screen.info = last_match_info
	var map_id: StringName = StringName(last_match_info.get("map", selected_map))
	screen.new_best = Journal.record_round(map_id, maxi(rows.size(), 1), round_reached)
	screen.best_round = Journal.best_round(map_id, maxi(rows.size(), 1))
	screen.local_peer = Net.local_id() if Net.is_active() else 1
	screen.show_lobby_button = Net.is_host()
	if Net.transport != null and not Net.transport.supports_clients():
		screen.lobby_button_text = "Play again"
	elif not Net.is_host() and Net.is_active() and subtitle == "":
		screen.subtitle = "Waiting for the host to return to the lobby ..."
	screen.menu_pressed.connect(func() -> void: leave_game(""))
	screen.lobby_pressed.connect(Session.host_return_to_lobby)
	_set_screen(screen)
	Log.info(&"game", "Game over screen: round %d, %d players" % [round_reached, rows.size()])


func state_name() -> String:
	return STATE_NAMES[state]


# --- Match lifecycle ---------------------------------------------------------------------


func _start_match(map_id: StringName, from_lobby: bool = false, first_round: int = 1) -> void:
	_end_match("")
	var def: MapDefinition = Content.get_map(map_id)
	if def == null:
		Log.error(&"game", "Unknown map '%s'" % map_id)
		leave_game("Unknown map '%s'" % map_id)
		return
	last_match_info = {}
	_set_state(State.LOADING)
	_show_message("Loading %s ..." % def.display_name)
	current_match = Match.new()
	_world.add_child(current_match)
	current_match.session_joined_at = _session_joined_at
	if current_match.setup(def, from_lobby, first_round) != OK:
		leave_game("Failed to load map '%s'" % map_id)
		return
	_set_screen(null)
	_set_state(State.IN_MATCH)
	EventBus.match_started.emit(map_id)
	_run_pending_exec()
	var quit_after: float = CommandLine.get_value("quit-after", "0").to_float()
	if quit_after > 0.0:  # release smoke tests: play N seconds, then quit cleanly
		get_tree().create_timer(quit_after, true, false, true).timeout.connect(func() -> void: Debug.run("quit"))


func _end_match(reason: String) -> void:
	if current_match == null:
		return
	current_match.queue_free()
	_world.remove_child(current_match)
	current_match = null
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.match_ended.emit(reason)


func _run_pending_exec() -> void:
	if _pending_exec == "":
		return
	var script: String = _pending_exec
	_pending_exec = ""
	Debug.run_script(script)


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	var previous: State = state
	state = new_state
	Log.info(&"game", "State %s -> %s" % [STATE_NAMES[previous], STATE_NAMES[new_state]])
	EventBus.game_state_changed.emit(previous, new_state)


func _set_screen(screen: Control) -> void:
	if _screen != null:
		_screen.queue_free()
		_screen = null
	if screen != null:
		_screen = screen
		UiTheme.apply(screen)
		_screen_layer.add_child(screen)
		Audio.play_event(&"ui_page")
	_update_menu_backdrop()


# The animated 3D menu background (MapDefinition.menu_scene_path of the default map) runs behind
# every out-of-match screen; it is freed while a match loads / runs. Skipped headless (tests) and
# with --no-menu-3d.
func _update_menu_backdrop() -> void:
	var want: bool = (
		current_match == null
		and state != State.LOADING
		and state != State.IN_MATCH
		and DisplayServer.get_name() != "headless"
		and not CommandLine.has_flag("no-menu-3d")
		and CommandLine.get_value("screenshot", "") == ""
	)
	var existing: Node = _world.get_node_or_null(^"MenuBackdrop")
	if want and existing == null:
		var def: MapDefinition = Content.get_map(default_map_id())
		if def == null or def.menu_scene_path == "":
			return
		var res: Resource = load(def.menu_scene_path)
		var node: Node = null
		if res is PackedScene:
			node = (res as PackedScene).instantiate()
		elif res is GDScript:
			node = (res as GDScript).new()
		if node != null:
			node.name = "MenuBackdrop"
			_world.add_child(node)
	elif not want and existing != null:
		_world.remove_child(existing)
		existing.queue_free()


func _show_message(text: String) -> void:
	var screen: MessageScreen = MessageScreen.new()
	screen.title = text
	_set_screen(screen)


# --- Net callbacks -----------------------------------------------------------------------


func _on_session_started(is_host: bool) -> void:
	_session_joined_at = Net.now()
	if is_host:
		Session.lobby.map_id = selected_map
		if _quick_start:
			_set_state(State.LOBBY)
			_launch_match(false)
		else:
			Session.lobby_changed.emit()
			show_lobby()
	else:
		_set_state(State.LOBBY)
		_show_message("Connected. Waiting for host ...")


# Host: start the match on every peer (from the lobby countdown or a quick start).
func _launch_match(from_lobby: bool) -> void:
	var first: int = Session.lobby.starting_round if Session.starting_round_allowed else 1
	if Session.lobby.map_id == &"":
		Session.lobby.map_id = selected_map
	Session.host_match_started()
	Net.send_reliable(0, &"_match_start", [String(Session.lobby.map_id), from_lobby, first])
	_start_match(Session.lobby.map_id, from_lobby, first)


func _on_countdown_finished() -> void:
	if Net.is_host() and state == State.LOBBY and current_match == null:
		_launch_match(true)


func _on_lobby_changed() -> void:
	if Net.is_active() and not Net.is_host() and state == State.LOBBY and current_match == null:
		show_lobby()


# Host leaves / crashes: clients in a match see the summary with a clear message (no migration).
func _on_session_ended(reason: String) -> void:
	var survival: bool = current_match != null and current_match.rounds != null and current_match.rounds.enabled
	if survival and state == State.IN_MATCH and current_match.points != null:
		var rows: Array = current_match.points.summary()
		var r: int = maxi(current_match.rounds.current_round, 1) if current_match.rounds != null else 1
		var text: String = "The host left the game — match over" if reason == "Host disconnected" else reason
		Log.info(&"game", "Session ended in match: %s" % reason)
		show_match_summary(r, rows, text)
		return
	go_to_main_menu(reason)


func _on_connection_failed(reason: String) -> void:
	go_to_main_menu(reason)


func _on_peer_joined(peer_id: int, _info: Dictionary) -> void:
	if Net.is_host() and peer_id != Net.local_id() and current_match != null:
		Net.send_reliable(peer_id, &"_match_start", [String(current_match.definition.id), false, 1])


func _on_msg_match_start(_sender: int, payload: Array) -> void:
	if Net.is_host():
		return
	var from_lobby: bool = payload.size() > 1 and bool(payload[1])
	var first: int = int(payload[2]) if payload.size() > 2 else 1
	_start_match(StringName(payload[0]), from_lobby, first)


# --- Console commands --------------------------------------------------------------------


func _cmd_host(args: Array) -> String:
	host_game(int(args[0]))
	return "Hosting on port %d" % int(args[0])


func _cmd_join(args: Array) -> String:
	join_game(String(args[0]))
	return "Joining %s" % args[0]


func _cmd_solo(_args: Array) -> String:
	start_solo()
	return "Solo session"


func _cmd_leave(_args: Array) -> String:
	leave_game("")
	return "Left session"


func _cmd_game_state(_args: Array) -> String:
	return "state=%s map=%s" % [state_name(), current_match.definition.id if current_match != null else "-"]
