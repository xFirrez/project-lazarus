# Journal — persistent local lore unlocks and Easter-egg badges (DEVELOPMENT_PLAN Step 14 scope 2 / 6,
# AC-14.4 / AC-14.5): documents read, reels heard and story entries earned in any match are kept in
# `user://journal.cfg` (per --profile, like Config) and listed by the main menu's Journal screen;
# badges ("requiem" on Vesper Peak, per player count) show on the map card. Saved on every change.
# Authority: local (each player's own progress).
class_name Journal
extends RefCounted

static var path_override: String = ""
static var _cfg: ConfigFile = null
static var _loaded_path: String = ""


static func path() -> String:
	if path_override != "":
		return path_override
	var profile: String = CommandLine.get_value("profile", "")
	return "user://journal_%s.cfg" % profile if profile != "" else "user://journal.cfg"


static func _file() -> ConfigFile:
	var p: String = path()
	if _cfg == null or _loaded_path != p:
		_cfg = ConfigFile.new()
		_loaded_path = p
		if FileAccess.file_exists(p):
			_cfg.load(p)
	return _cfg


# Drops the in-memory copy (tests: simulates a fresh launch reading the file again).
static func forget_cache() -> void:
	_cfg = null
	_loaded_path = ""


static func clear() -> void:
	_cfg = ConfigFile.new()
	_loaded_path = path()
	_cfg.save(_loaded_path)


static func unlock(entry_id: StringName) -> bool:
	var f: ConfigFile = _file()
	if f.has_section_key("unlocked", String(entry_id)):
		return false
	f.set_value("unlocked", String(entry_id), int(Time.get_unix_time_from_system()))
	f.save(_loaded_path)
	Log.info(&"journal", "Journal: %s unlocked" % entry_id)
	return true


static func is_unlocked(entry_id: StringName) -> bool:
	return _file().has_section_key("unlocked", String(entry_id))


static func unlocked_ids() -> PackedStringArray:
	var f: ConfigFile = _file()
	return f.get_section_keys("unlocked") if f.has_section("unlocked") else PackedStringArray()


static func award_badge(map_id: StringName, badge: StringName, players: int) -> void:
	var f: ConfigFile = _file()
	var k: String = "%s.%s" % [map_id, badge]
	var counts: Array = f.get_value("badges", k, [])
	if not counts.has(players):
		counts.append(players)
		counts.sort()
		f.set_value("badges", k, counts)
		f.save(_loaded_path)
		Log.info(&"journal", "Badge %s (%d players)" % [k, players])


# badge -> sorted player counts it was earned with, for one map.
static func badges(map_id: StringName) -> Dictionary:
	var f: ConfigFile = _file()
	var out: Dictionary = {}
	if not f.has_section("badges"):
		return out
	for k: String in f.get_section_keys("badges"):
		if k.begins_with("%s." % map_id):
			out[StringName(k.substr(String(map_id).length() + 1))] = f.get_value("badges", k, [])
	return out


# Local best round per map and player count (GAME_DESIGN §15 game over, Step 15). Returns true when
# `round_reached` is a new best (shown highlighted on the game-over screen and on the map card).
static func record_round(map_id: StringName, players: int, round_reached: int) -> bool:
	var f: ConfigFile = _file()
	var k: String = "%s.%dp" % [map_id, players]
	var best: int = int(f.get_value("records", k, 0))
	if round_reached <= best:
		return false
	f.set_value("records", k, round_reached)
	f.save(_loaded_path)
	return true


static func best_round(map_id: StringName, players: int) -> int:
	return int(_file().get_value("records", "%s.%dp" % [map_id, players], 0))
