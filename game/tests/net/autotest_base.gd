# AutoTestBase — scripted driver attached with --autotest=res://tests/net/<x>.gd.
# Writes a JSON result to --autotest-out (if given), prints "AUTOTEST RESULT ...", and quits
# with exit code 0 (pass) or 1 (fail). A hard timeout guards against hangs.
extends Node

var timeout: float = 30.0
var result: Dictionary = {"pass": false, "checks": {}, "notes": []}

var _elapsed: float = 0.0
var _finished: bool = false


func _process(delta: float) -> void:
	_elapsed += delta
	if not _finished and _elapsed > timeout:
		note("timeout after %.1f s" % timeout)
		finish(false)


func elapsed() -> float:
	return _elapsed


func check(name: String, ok: bool, detail: Variant = null) -> bool:
	result["checks"][name] = {"ok": ok, "detail": detail}
	Log.info(&"autotest", "%s %s %s" % ["PASS" if ok else "FAIL", name, str(detail) if detail != null else ""])
	return ok


func note(text: String) -> void:
	(result["notes"] as Array).append(text)
	Log.info(&"autotest", text)


func finish(ok: bool) -> void:
	if _finished:
		return
	_finished = true
	for name: String in result["checks"]:
		if not bool(result["checks"][name]["ok"]):
			ok = false
	result["pass"] = ok
	var out: String = CommandLine.get_value("autotest-out", "")
	if out != "":
		var f: FileAccess = FileAccess.open(out, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(result, "  "))
			f.close()
	Log.info(&"autotest", "AUTOTEST RESULT %s" % ("PASS" if ok else "FAIL"))
	Audio.shutdown()
	# Give the audio mixer a few frames to release stopped playbacks before quitting.
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(0 if ok else 1)


func sync() -> PlayerSync:
	if Match.current == null:
		return null
	return Match.current.players


# Circle bot: deterministic wish direction from the local clock.
static func circle_driver(phase: float) -> Callable:
	return func() -> Vector3:
		var t: float = Time.get_ticks_msec() / 1000.0 * 1.2 + phase
		return Vector3(cos(t), 0.0, sin(t))
