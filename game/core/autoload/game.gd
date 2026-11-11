# Game — top-level state machine: Boot -> MainMenu -> Lobby -> Loading -> InMatch -> GameOver.
# Owns the current Match and the placeholder screens. Command-line entry points:
#   --solo | --host[=port] | --join=ip[:port]   start a session directly
#   --map=<map_id>                               map to play (default: first non-test map)
#   --exec="cmd; cmd"                            console commands once in a match/menu
#   --autotest=res://path.gd                     attach a scripted test driver node
#   --screenshot=<map_id> --screenshot-out=<dir> capture the map's shot cameras and quit
# Authority: the host chooses the map and tells joining peers (reliable `_match_start`).
extends Node

enum State { BOOT, MAIN_MENU, LOBBY, LOADING, IN_MATCH, GAME_OVER }

const STATE_NAMES: PackedStringArray = ["Boot", "MainMenu", "Lobby", "Loading", "InMatch", "GameOver"]

var state: State = State.BOOT
var current_match: Match = null
var menu_message: String = ""
var selected_map: StringName = &""

var _screen_layer: CanvasLayer = null
var _screen: Control = null
var _world: Node = null
var _pending_exec: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		Engine.max_fps = 120
	_world = Node.new()
	_world.name = "World"
	add_child(_world)
	_screen_layer = CanvasLayer.new()
	_screen_layer.layer = 10
	add_child(_screen_layer)
	Net.session_started.connect(_on_session_started)
	Net.session_ended.connect(_on_session_ended)
	Net.connection_failed.connect(_on_connection_failed)
	Net.peer_joined.connect(_on_peer_joined)
	Net.register_message(&"_match_start", _on_msg_match_start)
	Debug.commands.register("host", _cmd_host, [["port", TYPE_INT, Net.DEFAULT_PORT]], "Host a co-op session")
	Debug.commands.register("join", _cmd_join, [["address", TYPE_STRING]], "Join ip[:port]")
	Debug.commands.register("solo", _cmd_solo, [], "Start a solo session")
	Debug.commands.register("leave", _cmd_leave, [], "Leave the session and return to the menu")
	Debug.commands.register("game_state", _cmd_game_state, [], "Print the game state")
	call_deferred(&"boot")


func boot() -> void:
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
		host_game(port_str.to_int() if port_str.is_valid_int() else Net.DEFAULT_PORT)
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
	if Net.start_solo() != OK:
		go_to_main_menu("Could not start solo session")


func host_game(port: int) -> void:
	if Net.host_session(port) != OK:
		go_to_main_menu("Could not host on port %d" % port)


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
	menu.solo_requested.connect(start_solo)
	menu.host_requested.connect(func() -> void: host_game(Net.DEFAULT_PORT))
	menu.join_requested.connect(join_game)
	menu.quit_requested.connect(func() -> void: get_tree().quit())
	_set_screen(menu)
	menu.set_status(message)
	if message != "":
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


func state_name() -> String:
	return STATE_NAMES[state]


# --- Match lifecycle ---------------------------------------------------------------------


func _start_match(map_id: StringName) -> void:
	_end_match("")
	var def: MapDefinition = Content.get_map(map_id)
	if def == null:
		Log.error(&"game", "Unknown map '%s'" % map_id)
		leave_game("Unknown map '%s'" % map_id)
		return
	_set_state(State.LOADING)
	_show_message("Loading %s ..." % def.display_name)
	current_match = Match.new()
	_world.add_child(current_match)
	if current_match.setup(def) != OK:
		leave_game("Failed to load map '%s'" % map_id)
		return
	_set_screen(null)
	_set_state(State.IN_MATCH)
	EventBus.match_started.emit(map_id)
	_run_pending_exec()


func _end_match(reason: String) -> void:
	if current_match == null:
		return
	current_match.queue_free()
	_world.remove_child(current_match)
	current_match = null
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
		_screen_layer.add_child(screen)


func _show_message(text: String) -> void:
	var screen: MessageScreen = MessageScreen.new()
	screen.title = text
	_set_screen(screen)


# --- Net callbacks -----------------------------------------------------------------------


func _on_session_started(is_host: bool) -> void:
	if is_host:
		_set_state(State.LOBBY)  # Step 7 adds a real lobby; for now start immediately.
		_start_match(selected_map)
	else:
		_set_state(State.LOBBY)
		_show_message("Connected. Waiting for host ...")


func _on_session_ended(reason: String) -> void:
	go_to_main_menu(reason)


func _on_connection_failed(reason: String) -> void:
	go_to_main_menu(reason)


func _on_peer_joined(peer_id: int, _info: Dictionary) -> void:
	if Net.is_host() and peer_id != Net.local_id() and current_match != null:
		Net.send_reliable(peer_id, &"_match_start", [current_match.definition.id])


func _on_msg_match_start(_sender: int, payload: Array) -> void:
	if Net.is_host():
		return
	_start_match(StringName(payload[0]))


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
