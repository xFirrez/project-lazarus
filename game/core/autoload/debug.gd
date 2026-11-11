# Debug — owns the console command registry, the console UI and the perf/net overlay.
# Authority: local. Commands that change shared state must go through host requests.
# `--exec="cmd1; cmd2"` runs commands after boot (used by headless tests and tools).
extends Node

var commands: CommandRegistry = CommandRegistry.new()
var console: Control = null
var overlay: Control = null

var _layer: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_builtin_commands()
	if DisplayServer.get_name() != "headless":
		_layer = CanvasLayer.new()
		_layer.layer = 100
		add_child(_layer)
		overlay = DebugOverlay.new()
		_layer.add_child(overlay)
		console = DebugConsole.new()
		(console as DebugConsole).registry = commands
		_layer.add_child(console)


func run(line: String) -> String:
	Log.info(&"console", "> %s" % line)
	var result: String = commands.execute(line)
	if result != "":
		for l: String in result.split("\n"):
			Log.info(&"console", l)
	return result


func run_script(script: String) -> void:
	for line: String in script.split(";"):
		if line.strip_edges() != "":
			run(line.strip_edges())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_console") and console != null:
		(console as DebugConsole).toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_net_overlay") and overlay != null:
		overlay.visible = not overlay.visible
		get_viewport().set_input_as_handled()


func _register_builtin_commands() -> void:
	commands.register("help", _cmd_help, [], "List commands")
	commands.register("net_status", _cmd_net_status, [], "Session, peers, RTT, bandwidth, NetSim")
	commands.register(
		"netsim",
		_cmd_netsim,
		[["ms", TYPE_FLOAT], ["jitter", TYPE_FLOAT, 0.0], ["loss", TYPE_FLOAT, 0.0]],
		"Simulate latency (ms), jitter (ms) and loss (0..1) on outgoing traffic; 'netsim 0' = off"
	)
	commands.register("overlay", _cmd_overlay, [["on", TYPE_BOOL]], "Show/hide the FPS + net overlay")
	commands.register("log_level", _cmd_log_level, [["level", TYPE_STRING]], "debug|info|warn|error")
	commands.register("quit", _cmd_quit, [], "Quit the game")
	PlayerCommands.register(commands)
	WeaponCommands.register(commands)
	RenderCommands.register(commands)


func _cmd_help(_args: Array) -> String:
	return commands.help_text()


func _cmd_net_status(_args: Array) -> String:
	var lines: PackedStringArray = []
	var state_name: String = ["idle", "connecting", "active"][Net.state]
	lines.append(
		(
			"state=%s role=%s transport=%s id=%d"
			% [
				state_name,
				"host" if Net.is_host() else ("client" if Net.is_active() else "-"),
				Net.transport.transport_name() if Net.transport != null else "none",
				Net.local_id()
			]
		)
	)
	lines.append(
		(
			"rtt=%.1f ms out=%.0f B/s in=%.0f B/s loss=%.1f%% netsim=%s"
			% [Net.rtt_ms(), Net.bytes_out_per_sec, Net.bytes_in_per_sec, Net.loss_estimate * 100.0, Net.sim.describe()]
		)
	)
	for id: int in Net.peer_ids():
		var info: Dictionary = Net.peers[id]
		lines.append("  peer %d %s uid=%s" % [id, info.get("name", "?"), info.get("uid", "?")])
	return "\n".join(lines)


func _cmd_netsim(args: Array) -> String:
	Net.set_netsim(float(args[0]), float(args[1]), float(args[2]))
	return "NetSim: %s" % Net.sim.describe()


func _cmd_overlay(args: Array) -> String:
	if overlay == null:
		return "No overlay in headless mode"
	overlay.visible = bool(args[0])
	return "overlay %s" % ("on" if overlay.visible else "off")


func _cmd_log_level(args: Array) -> String:
	var idx: int = Array(Log.LEVEL_NAMES).find(String(args[0]).to_upper())
	if idx < 0:
		return "Unknown level"
	Log.min_level = idx as Log.Level
	return "log level %s" % Log.LEVEL_NAMES[idx]


func _cmd_quit(_args: Array) -> String:
	Audio.shutdown()
	Net.leave_session("Quit")
	_quit_after_frames.call_deferred()
	return "Quitting"


func _quit_after_frames() -> void:
	# Let the audio mixer release stopped playbacks so nothing is reported as leaked.
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()
