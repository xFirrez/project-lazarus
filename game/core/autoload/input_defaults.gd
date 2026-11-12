# InputDefaults — the canonical default input map (GAME_DESIGN §3, §15 settings).
# Source of truth for project.godot's [input] section (tools/gen_input_map.sh) and for
# Config's "reset bindings". Bindings are encoded as short strings so they can be stored
# in settings.cfg and edited by humans:
#   "key:W"  physical key by name   "mouse:1"  mouse button index
#   "joy:0"  joypad button index    "axis:1:-1" joypad axis index and direction
class_name InputDefaults
extends RefCounted

const DEADZONE: float = 0.2

# action -> Array of binding strings
const ACTIONS: Dictionary = {
	"move_forward": ["key:W", "axis:1:-1"],
	"move_back": ["key:S", "axis:1:1"],
	"move_left": ["key:A", "axis:0:-1"],
	"move_right": ["key:D", "axis:0:1"],
	"look_up": ["axis:3:-1"],
	"look_down": ["axis:3:1"],
	"look_left": ["axis:2:-1"],
	"look_right": ["axis:2:1"],
	"jump": ["key:Space", "joy:0"],
	"sprint": ["key:Shift", "joy:7"],
	"crouch": ["key:C", "joy:1"],
	"fire": ["mouse:1", "axis:5:1"],
	"aim": ["mouse:2", "axis:4:1"],
	"reload": ["key:R", "joy:2"],
	"interact": ["key:F", "joy:2"],
	"melee": ["key:V", "joy:8"],
	"lethal": ["key:G", "joy:10"],
	"tactical": ["key:Q", "joy:9"],
	"placeable": ["key:4", "joy:14"],
	"weapon_next": ["mouse:4", "joy:3"],
	"weapon_prev": ["mouse:5"],
	"weapon_slot_1": ["key:1"],
	"weapon_slot_2": ["key:2"],
	"weapon_slot_3": ["key:3"],
	"scoreboard": ["key:Tab", "joy:4"],
	"ping": ["mouse:3", "key:Z", "joy:11"],
	"pause": ["key:Escape", "joy:6"],
	"toggle_console": ["key:QuoteLeft"],
	"toggle_net_overlay": ["key:F3"],
}


static func action_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for action: String in ACTIONS:
		names.append(action)
	return names


static func binding_to_event(binding: String) -> InputEvent:
	var ev: InputEvent = _binding_to_event_raw(binding)
	if ev != null:
		ev.device = -1  # any device
	return ev


static func _binding_to_event_raw(binding: String) -> InputEvent:
	var parts: PackedStringArray = binding.split(":")
	if parts.size() < 2:
		return null
	match parts[0]:
		"key":
			var code: Key = OS.find_keycode_from_string(parts[1])
			if code == KEY_NONE:
				return null
			var key: InputEventKey = InputEventKey.new()
			key.physical_keycode = code
			return key
		"mouse":
			var mb: InputEventMouseButton = InputEventMouseButton.new()
			mb.button_index = int(parts[1]) as MouseButton
			return mb
		"joy":
			var jb: InputEventJoypadButton = InputEventJoypadButton.new()
			jb.button_index = int(parts[1]) as JoyButton
			return jb
		"axis":
			if parts.size() < 3:
				return null
			var jm: InputEventJoypadMotion = InputEventJoypadMotion.new()
			jm.axis = int(parts[1]) as JoyAxis
			jm.axis_value = float(parts[2])
			return jm
	return null


static func event_to_binding(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: InputEventKey = event
		var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return "key:%s" % OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		return "joy:%d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = event
		return "axis:%d:%d" % [jm.axis, 1 if jm.axis_value > 0.0 else -1]
	return ""


# Replaces the bindings of every known action in the live InputMap.
static func apply(bindings: Dictionary) -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		InputMap.action_erase_events(action)
		var list: Array = bindings.get(action, ACTIONS[action])
		for binding: Variant in list:
			var ev: InputEvent = binding_to_event(String(binding))
			if ev != null:
				InputMap.action_add_event(action, ev)
