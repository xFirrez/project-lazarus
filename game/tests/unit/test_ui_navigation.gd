# Step 15 AC-15.1 / AC-15.5: every menu screen takes keyboard / gamepad focus on open, can move focus
# to a neighbour, and has a back path (ui_cancel / a Back button) — no dead ends; key and pad
# rebinding update the live InputMap and persist through save / load; apply / revert; the credits
# list every third-party asset of docs/ASSET_LICENSES.md.
extends GutTest

var _snap: Dictionary = {}
var _layer: CanvasLayer = null


func before_each() -> void:
	_snap = Config.snapshot()
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child_autofree(_layer)


func after_each() -> void:
	Config.restore(_snap)
	Audio.stop_all()


func _open(screen: Control) -> Control:
	_layer.add_child(screen)
	await wait_physics_frames(3)
	return screen


func _cancel() -> InputEventAction:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	return ev


func _focus_inside(screen: Control) -> Control:
	var f: Control = screen.get_viewport().gui_get_focus_owner()
	return f if f != null and screen.is_ancestor_of(f) else null


func _assert_navigable(screen: Control, label: String) -> void:
	var f: Control = _focus_inside(screen)
	assert_not_null(f, "%s: something has focus on open" % label)
	if f != null:
		assert_not_null(f.find_next_valid_focus(), "%s: focus can move" % label)


func test_main_menu_focus_and_multiplayer_back() -> void:
	var m: MainMenu = await _open(MainMenu.new())
	_assert_navigable(m, "main menu")
	for n: String in ["Solo", "Multiplayer", "Journal", "Settings", "Credits", "Quit"]:
		assert_not_null(m.find_child(n, true, false), "main menu has %s" % n)
	m._show_multi()
	await wait_physics_frames(2)
	assert_true((m.find_child("Multiplayer", true, false) as Control).visible)
	m._unhandled_input(_cancel())
	assert_true((m.find_child("Main", true, false) as Control).visible, "ui_cancel leaves the multiplayer panel")
	m.queue_free()


func test_screens_have_focus_and_back() -> void:
	var screens: Array = [
		[MapSelectScreen.new(), "map select"],
		[SettingsScreen.new(), "settings"],
		[CreditsScreen.new(), "credits"],
	]
	for pair: Array in screens:
		var s: UiScreen = pair[0]
		await _open(s)
		_assert_navigable(s, pair[1])
		watch_signals(s)
		s._unhandled_input(_cancel())
		assert_signal_emitted(s, "back_pressed", "%s: ui_cancel goes back" % pair[1])
		s.queue_free()
		await wait_physics_frames(1)


func test_journal_back() -> void:
	var j: JournalScreen = await _open(JournalScreen.new())
	_assert_navigable(j, "journal")
	watch_signals(j)
	j._unhandled_input(_cancel())
	assert_signal_emitted(j, "back_pressed")
	j.queue_free()


func test_game_over_has_exits() -> void:
	var g: GameOverScreen = GameOverScreen.new()
	g.round_reached = 12
	g.rows = [{"peer": 1, "name": "Ann", "character": "brandt", "kills": 80, "perks": 3, "box_spins": 2}]
	g.show_lobby_button = true
	g.info = {"seconds": 1234.0, "quest": "Requiem 3/9", "players": 1}
	g.new_best = true
	await _open(g)
	_assert_navigable(g, "game over")
	assert_not_null(g.find_child("LobbyButton", true, false), "play again")
	assert_not_null(g.find_child("MenuButton", true, false), "main menu")
	assert_string_contains((g.find_child("Record", true, false) as Label).text, "NEW RECORD")
	assert_string_contains((g.find_child("Footer", true, false) as Label).text, "20:34")
	assert_eq(GameOverScreen.time_text(3725.0), "1:02:05")
	g.queue_free()


func test_key_rebind_updates_input_map_and_persists() -> void:
	var s: SettingsScreen = await _open(SettingsScreen.new())
	s.begin_capture("jump", false)
	var k: InputEventKey = InputEventKey.new()
	k.physical_keycode = KEY_K
	k.pressed = true
	s._input(k)
	assert_true(Config.get_bindings(&"jump").has("key:K"), "jump -> K")
	assert_false(Config.get_bindings(&"jump").has("key:Space"), "old key replaced")
	assert_true(Config.get_bindings(&"jump").has("joy:0"), "pad binding kept")
	var probe: InputEventKey = InputEventKey.new()
	probe.physical_keycode = KEY_K
	probe.pressed = true
	assert_true(InputMap.event_is_action(probe, &"jump"), "live InputMap updated")
	# Pad column: joy 3 moves from weapon_next to jump.
	s.begin_capture("jump", true)
	var jb: InputEventJoypadButton = InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_Y
	jb.pressed = true
	s._input(jb)
	assert_true(Config.get_bindings(&"jump").has("joy:3"))
	assert_false(Config.get_bindings(&"jump").has("joy:0"))
	assert_false(Config.get_bindings(&"weapon_next").has("joy:3"), "conflicting binding moved")
	var path: String = "user://test_rebind.cfg"
	assert_eq(Config.save_settings(path), OK)
	Config.reset_to_defaults()
	assert_false(Config.get_bindings(&"jump").has("key:K"))
	assert_eq(Config.load_settings(path), OK)
	assert_true(Config.get_bindings(&"jump").has("key:K"), "rebinding persists")
	assert_true(Config.get_bindings(&"jump").has("joy:3"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	s.queue_free()


func test_capture_cancel_and_wrong_kind() -> void:
	var s: SettingsScreen = await _open(SettingsScreen.new())
	var before: PackedStringArray = Config.get_bindings(&"reload")
	s.begin_capture("reload", true)
	var k: InputEventKey = InputEventKey.new()
	k.physical_keycode = KEY_T
	k.pressed = true
	s._input(k)  # a key in the pad column is ignored
	assert_eq(s.capture_action, "reload", "still waiting for a pad input")
	var esc: InputEventKey = InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	s._input(esc)
	assert_eq(s.capture_action, "", "escape cancels")
	assert_eq(Config.get_bindings(&"reload"), before)
	s.queue_free()


func test_apply_and_revert() -> void:
	var s: SettingsScreen = await _open(SettingsScreen.new())
	var fov0: float = float(Config.get_value(&"video", &"fov", 90.0))
	s._set_value(&"video", &"fov", 104.0)
	assert_eq(float(Config.get_value(&"video", &"fov")), 104.0)
	s.revert_changes()
	assert_eq(float(Config.get_value(&"video", &"fov")), fov0, "revert restores")
	s.queue_free()


func test_settings_cover_game_design_18() -> void:
	var s: SettingsScreen = await _open(SettingsScreen.new())
	var tabs: TabContainer = s.tabs
	assert_eq(tabs.get_tab_count(), 5)
	for i: int in tabs.get_tab_count():
		assert_true(tabs.get_tab_title(i) in ["VIDEO", "AUDIO", "CONTROLS", "GAMEPAD", "GAMEPLAY"])
	var labels: PackedStringArray = []
	for n: Node in s.find_children("*", "Label", true, false):
		labels.append((n as Label).text)
	var all: String = "|".join(labels)
	for want: String in [
		"Quality preset",
		"Resolution scale",
		"SSAO",
		"Volumetric fog",
		"Particle density",
		"View distance",
		"V-sync",
		"FPS cap",
		"Field of view",
		"Camera bob",
		"Screen shake",
		"Music volume",
		"Mouse sensitivity",
		"ADS sensitivity",
		"Invert look",
		"Toggle aim",
		"Toggle crouch",
		"Toggle sprint",
		"HUD scale",
		"Colorblind",
		"Subtitles",
	]:
		assert_string_contains(all, want)
	for a: String in SettingsScreen.REBIND_ACTIONS:
		assert_not_null(s.find_child("Bind_%s_kb" % a, true, false), "kb row %s" % a)
		assert_not_null(s.find_child("Bind_%s_pad" % a, true, false), "pad row %s" % a)
	s.queue_free()


func test_credits_list_every_third_party_asset() -> void:
	var md: String = FileAccess.get_file_as_string(
		ProjectSettings.globalize_path("res://").path_join("../docs/ASSET_LICENSES.md")
	)
	var rows: int = 0
	var in_table: bool = false
	for line: String in md.split("\n"):
		if line.begins_with("| Path"):
			in_table = true
		elif in_table and line.begins_with("|---"):
			continue
		elif in_table and line.begins_with("|"):
			rows += 1
		else:
			in_table = false
	assert_gt(rows, 5)
	var c: CreditsScreen = await _open(CreditsScreen.new())
	assert_eq(c.entries_shown, rows, "every ASSET_LICENSES row is credited")
	var text: String = JSON.stringify(CreditsScreen.load_credits())
	for want: String in ["Black Ops One", "Special Elite", "Barlow", "GUT", "Godot"]:
		assert_string_contains(text, want)
	c.queue_free()


func test_hud_factor_matrix() -> void:
	# AC-15.2 layout: the logical HUD canvas stays >= 853 x 480 for every logical size x scale.
	for res: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440), Vector2(3840, 2160)]:
		for sc: float in [0.75, 1.0, 1.25, 1.5]:
			var f: float = UiTheme.hud_factor(res, sc)
			var logical: Vector2 = res / f
			assert_gte(logical.x, 853.0, "%s @ %.2f" % [res, sc])
			assert_gte(logical.y, 480.0, "%s @ %.2f" % [res, sc])
			assert_gte(f * 14.0, 7.0, "smallest HUD text >= 7 px")
