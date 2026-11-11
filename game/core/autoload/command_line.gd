# CommandLine — parses game arguments (`--host`, `--join=IP[:port]`, `--netsim=ms,jitter,loss`,
# `--profile=name`, `--exec="cmd; cmd"`, ...). Accepts them before or after Godot's `--`
# separator. Pure helper, no state beyond an optional override used by tests.
class_name CommandLine
extends RefCounted

static var override_args: PackedStringArray = []
static var use_override: bool = false


static func args() -> PackedStringArray:
	if use_override:
		return override_args
	var out: PackedStringArray = OS.get_cmdline_args()
	out.append_array(OS.get_cmdline_user_args())
	return out


static func parse(list: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for raw: String in list:
		if not raw.begins_with("--") or raw == "--":
			continue
		var body: String = raw.substr(2)
		var eq: int = body.find("=")
		if eq < 0:
			result[body] = ""
		else:
			result[body.substr(0, eq)] = body.substr(eq + 1)
	return result


static func has_flag(name: String) -> bool:
	return parse(args()).has(name)


static func get_value(name: String, fallback: String = "") -> String:
	var parsed: Dictionary = parse(args())
	if not parsed.has(name):
		return fallback
	return String(parsed[name])
