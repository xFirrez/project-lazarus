# Step 16 release plumbing: version / protocol compatibility (BuildInfo) and crash-log capture
# (CrashLog: a stale lock from a dead process -> crash_<date>.log with the previous run's log).
extends GutTest

const SCRATCH: String = "user://test_crashlog"

var _saved_dir: String = ""


func before_each() -> void:
	_saved_dir = CrashLog.dir
	CrashLog.dir = SCRATCH
	_wipe()
	DirAccess.make_dir_recursive_absolute(SCRATCH)


func after_each() -> void:
	CrashLog.end()
	_wipe()
	CrashLog.dir = _saved_dir
	CrashLog.last_crash_path = ""


func _wipe() -> void:
	var d: DirAccess = DirAccess.open(SCRATCH)
	if d == null:
		return
	for f: String in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(SCRATCH)


func _write(name: String, text: String) -> void:
	var f: FileAccess = FileAccess.open("%s/%s" % [SCRATCH, name], FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_version_is_set_and_protocol_compatible() -> void:
	assert_ne(BuildInfo.version(), BuildInfo.FALLBACK_VERSION, "project.godot has application/config/version")
	assert_eq(BuildInfo.protocol_of("1.0.3-rc1"), "1.0")
	assert_true(BuildInfo.compatible("1.0.0", "1.0.7-rc2"))
	assert_false(BuildInfo.compatible("1.0.0", "1.1.0"))
	assert_false(BuildInfo.compatible("1.0.0", "unknown"))
	assert_string_contains(BuildInfo.describe(), BuildInfo.version())


func test_clean_run_leaves_no_crash() -> void:
	CrashLog.begin()
	assert_true(FileAccess.file_exists("%s/running_%d.lock" % [SCRATCH, OS.get_process_id()]))
	CrashLog.end()
	CrashLog.begin()
	assert_eq(CrashLog.last_crash_path, "", "own lock of a clean run is not a crash")
	assert_eq(CrashLog.crash_logs().size(), 0)


func test_stale_lock_produces_crash_report() -> void:
	_write("godot2026-11-13T01.00.00.log", "boot ok\nSIGSEGV: segmentation fault\n")
	_write("running_999999.lock", "v1.0.0 (test)\n")  # no such process
	CrashLog.begin()
	assert_ne(CrashLog.last_crash_path, "")
	var logs: PackedStringArray = CrashLog.crash_logs()
	assert_eq(logs.size(), 1)
	var text: String = FileAccess.get_file_as_string(logs[0])
	assert_string_contains(text, "SIGSEGV")
	assert_false(FileAccess.file_exists("%s/running_999999.lock" % SCRATCH), "stale lock removed")


func test_crash_logs_are_pruned() -> void:
	for i: int in CrashLog.MAX_CRASH_LOGS + 3:
		_write("crash_2026-01-%02d.log" % (i + 1), "x")
	_write("running_999998.lock", "x")
	CrashLog.begin()
	assert_eq(CrashLog.crash_logs().size(), CrashLog.MAX_CRASH_LOGS)
