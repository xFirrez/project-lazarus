# CrashLog — crash log capture (Step 16). Godot's file logger writes every run's output to
# `user://logs/godot.log` (rotated: older runs become `godot<timestamp>.log`). Each running
# instance also leaves `user://logs/running_<pid>.lock`; a clean quit removes it. At start-up a
# lock whose process is gone means that run crashed or was killed: its rotated log is copied to
# `user://logs/crash_<date>.log` (with the build description) and the main menu shows a notice.
# Several instances may run at once (local co-op tests), so locks are per process id.
# Authority: local.
class_name CrashLog
extends RefCounted

const MAX_CRASH_LOGS: int = 10

static var dir: String = "user://logs"  # tests point this at a scratch folder

static var last_crash_path: String = ""  # set when the previous run ended unexpectedly
static var _lock_path: String = ""


static func begin() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	_collect_stale_locks()
	_lock_path = "%s/running_%d.lock" % [dir, OS.get_process_id()]
	var f: FileAccess = FileAccess.open(_lock_path, FileAccess.WRITE)
	if f != null:
		f.store_string("%s\n%s\n" % [BuildInfo.describe(), Time.get_datetime_string_from_system()])
		f.close()


# Clean exit: the lock goes away so the next start doesn't report a crash.
static func end() -> void:
	if _lock_path != "" and FileAccess.file_exists(_lock_path):
		DirAccess.remove_absolute(_lock_path)
	_lock_path = ""


static func crash_logs() -> PackedStringArray:
	var out: PackedStringArray = []
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.begins_with("crash_") and f.ends_with(".log"):
			out.append("%s/%s" % [dir, f])
	out.sort()
	return out


static func _collect_stale_locks() -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	for f: String in d.get_files():
		if not (f.begins_with("running_") and f.ends_with(".lock")):
			continue
		var pid: int = f.trim_prefix("running_").trim_suffix(".lock").to_int()
		if pid > 0 and pid != OS.get_process_id() and OS.is_process_running(pid):
			continue  # another live instance
		var lock: String = "%s/%s" % [dir, f]
		var started: String = FileAccess.get_file_as_string(lock)
		last_crash_path = _save_crash_report(started)
		DirAccess.remove_absolute(lock)
	_prune()


# The newest rotated log (the previous run) is what the crashed instance wrote.
static func _save_crash_report(lock_text: String) -> String:
	var d: DirAccess = DirAccess.open(dir)
	var newest: String = ""
	var newest_time: int = -1
	for f: String in d.get_files():
		if f.begins_with("godot") and f.ends_with(".log") and f != "godot.log":
			var t: int = FileAccess.get_modified_time("%s/%s" % [dir, f])
			if t > newest_time:
				newest_time = t
				newest = f
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var out_path: String = "%s/crash_%s_%d.log" % [dir, stamp, randi() % 1000]
	var out: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if out == null:
		return ""
	out.store_string("# Project Lazarus crash report\n# run: %s\n" % lock_text.replace("\n", " "))
	out.store_string("# detected by: %s at %s\n\n" % [BuildInfo.describe(), Time.get_datetime_string_from_system()])
	if newest != "":
		out.store_string(FileAccess.get_file_as_string("%s/%s" % [dir, newest]))
	else:
		out.store_string("(no rotated log found: file logging disabled?)\n")
	out.close()
	return out_path


static func _prune() -> void:
	var logs: PackedStringArray = crash_logs()
	while logs.size() > MAX_CRASH_LOGS:
		DirAccess.remove_absolute(logs[0])
		logs.remove_at(0)
