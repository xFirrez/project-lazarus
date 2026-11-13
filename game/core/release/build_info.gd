# BuildInfo — the game's version and build identity (Step 16 release builds).
# The version lives in project.godot (`application/config/version`); tools/export.sh writes
# `res://build_info.json` (commit, date, channel) into exported builds. Co-op peers must share
# the same protocol version (major.minor): the host refuses a hello from a different one.
# Authority: local, read-only.
class_name BuildInfo
extends RefCounted

const INFO_PATH: String = "res://build_info.json"
const FALLBACK_VERSION: String = "0.0.0-dev"

static var _cache: Dictionary = {}


static func version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", FALLBACK_VERSION))


# "1.0" for "1.0.3-rc1": peers with the same major.minor can play together.
static func protocol_version() -> String:
	return protocol_of(version())


static func protocol_of(v: String) -> String:
	var core_part: String = v.split("-")[0]
	var parts: PackedStringArray = core_part.split(".")
	if parts.size() < 2:
		return core_part
	return "%s.%s" % [parts[0], parts[1]]


static func compatible(a: String, b: String) -> bool:
	return protocol_of(a) == protocol_of(b)


static func info() -> Dictionary:
	if _cache.is_empty():
		_cache = {"version": version(), "commit": "dev", "date": "", "channel": "dev"}
		if FileAccess.file_exists(INFO_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INFO_PATH))
			if parsed is Dictionary:
				for k: String in ["commit", "date", "channel"]:
					if (parsed as Dictionary).has(k):
						_cache[k] = String((parsed as Dictionary)[k])
	return _cache


# "v1.0.0-rc1 (abc1234, release)" — main menu corner, logs and crash reports.
static func describe() -> String:
	var i: Dictionary = info()
	return "v%s (%s, %s)" % [i["version"], i["commit"], i["channel"]]
