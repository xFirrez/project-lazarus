# Visual check (Step 15): every out-of-match screen in the final dossier style over the 3D menu
# backdrop (main menu, multiplayer panel, map select, settings tabs, journal, credits). Frames go
# to --autotest-shots (docs/screenshots/ui_*.png). Run without --solo (menu boot).
extends "res://tests/net/autotest_base.gd"

var _out: String = ""


func _ready() -> void:
	timeout = 120.0
	_out = CommandLine.get_value("autotest-shots", "user://screenshots")
	DirAccess.make_dir_recursive_absolute(_out)
	_run()


func _frames(n: int) -> void:
	for i: int in n:
		await RenderingServer.frame_post_draw


func _shot(file: String) -> void:
	await _frames(4)
	get_viewport().get_texture().get_image().save_png(_out.path_join(file))


func _run() -> void:
	while not (Game._screen is MainMenu):
		await get_tree().process_frame
	if is_instance_valid(Debug.overlay):
		Debug.overlay.visible = false
	await _frames(40)
	check("menu_backdrop", Game._world.get_node_or_null(^"MenuBackdrop") != null)
	await _shot("ui_main_menu.png")
	(Game._screen as MainMenu)._show_multi()
	await _frames(10)
	await _shot("ui_multiplayer.png")
	Game.show_map_select(false)
	await _frames(10)
	await _shot("ui_map_select.png")
	check("map_select", Game._screen is MapSelectScreen)
	Game.show_settings()
	await _frames(6)
	check("settings", Game._screen is SettingsScreen)
	var tabs: TabContainer = Game._screen.find_child("Tabs", true, false) as TabContainer
	if tabs != null:
		for i: int in tabs.get_tab_count():
			tabs.current_tab = i
			await _frames(4)
			await _shot("ui_settings_%d.png" % i)
	Game.show_journal()
	await _frames(6)
	await _shot("ui_journal.png")
	Game.show_credits()
	await _frames(6)
	await _shot("ui_credits.png")
	check("credits", Game._screen is CreditsScreen)
	Game.go_to_main_menu("")
	await _frames(5)
	finish(true)
