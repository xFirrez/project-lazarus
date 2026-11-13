# Visual check (Step 7): the lobby (host, two chat lines, character cards), then the main menu v1
# and the map select screen. Frames go to --autotest-shots (docs/screenshots).
extends "res://tests/net/autotest_base.gd"

var _out: String = ""


func _ready() -> void:
	timeout = 60.0
	_out = CommandLine.get_value("autotest-shots", "user://screenshots")
	DirAccess.make_dir_recursive_absolute(_out)
	_run()


func _frames(n: int) -> void:
	for i: int in n:
		await RenderingServer.frame_post_draw


func _shot(file: String) -> void:
	await _frames(3)
	get_viewport().get_texture().get_image().save_png(_out.path_join(file))


func _run() -> void:
	while not (Game._screen is LobbyScreen):
		await get_tree().process_frame
	if is_instance_valid(Debug.overlay):
		Debug.overlay.visible = false
	Session.request_character(&"brandt")
	Session.send_chat("Ready when you are.")
	Session.send_chat("Bring the M14 money.")
	Session.request_set_ready(true)
	await _frames(10)
	await _shot("lobby.png")
	check("lobby_shown", Game._screen is LobbyScreen)
	Game.leave_game("")
	await _frames(5)
	await _shot("main_menu.png")
	check("menu_shown", Game._screen is MainMenu)
	Game.show_map_select(true)
	await _frames(5)
	await _shot("map_select.png")
	check("map_select_shown", Game._screen is MapSelectScreen)
	Game.go_to_main_menu("")
	await _frames(5)
	finish(true)
