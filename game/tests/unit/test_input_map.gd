extends GutTest


func test_project_input_map_matches_defaults() -> void:
	for action: String in InputDefaults.ACTIONS:
		var setting: Variant = ProjectSettings.get_setting("input/" + action)
		assert_not_null(setting, "project.godot missing action %s (run tools/gen_input_map.sh)" % action)
		if setting == null:
			continue
		var bindings: PackedStringArray = []
		for ev: InputEvent in (setting as Dictionary)["events"]:
			bindings.append(InputDefaults.event_to_binding(ev))
		assert_eq(bindings, PackedStringArray(InputDefaults.ACTIONS[action]), action)


func test_binding_round_trip() -> void:
	for action: String in InputDefaults.ACTIONS:
		for binding: Variant in InputDefaults.ACTIONS[action]:
			var ev: InputEvent = InputDefaults.binding_to_event(String(binding))
			assert_not_null(ev, String(binding))
			assert_eq(InputDefaults.event_to_binding(ev), String(binding))


func test_live_input_map_has_actions() -> void:
	for action: String in ["move_forward", "fire", "toggle_console", "interact"]:
		assert_true(InputMap.has_action(action), action)
