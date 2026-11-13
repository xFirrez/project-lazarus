# Writes InputDefaults.ACTIONS into game/project.godot's [input] section.
# Run via tools/gen_input_map.sh (headless). Re-run whenever input_defaults.gd changes;
# tests/unit/test_input_map.gd fails if project.godot drifts from InputDefaults.
extends SceneTree


func _init() -> void:
	var input_defaults: GDScript = load("res://core/autoload/input_defaults.gd")
	var actions: Dictionary = input_defaults.get("ACTIONS")
	for prop: Dictionary in ProjectSettings.get_property_list():
		var key: String = prop["name"]
		if key.begins_with("input/"):
			ProjectSettings.clear(key)
	for action: String in actions:
		var events: Array[InputEvent] = []
		for binding: Variant in actions[action]:
			var ev: InputEvent = input_defaults.call("binding_to_event", String(binding))
			if ev != null:
				events.append(ev)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	var err: Error = ProjectSettings.save()
	print("gen_input_map: wrote %d actions (%s)" % [actions.size(), error_string(err)])
	quit(0 if err == OK else 1)
