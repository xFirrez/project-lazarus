# Log — leveled, categorized logging with an in-memory ring buffer for the debug console.
# Authority: local (both host and client). Never networked.
extends Node

signal entry_added(entry: Dictionary)

enum Level { DEBUG, INFO, WARN, ERROR }

const RING_SIZE: int = 512
const LEVEL_NAMES: PackedStringArray = ["DEBUG", "INFO", "WARN", "ERROR"]

var min_level: Level = Level.INFO
var echo_to_stdout: bool = true

var _ring: Array[Dictionary] = []


func debug(category: StringName, message: String) -> void:
	_write(Level.DEBUG, category, message)


func info(category: StringName, message: String) -> void:
	_write(Level.INFO, category, message)


func warn(category: StringName, message: String) -> void:
	_write(Level.WARN, category, message)


func error(category: StringName, message: String) -> void:
	_write(Level.ERROR, category, message)


func entries() -> Array[Dictionary]:
	return _ring.duplicate()


func clear() -> void:
	_ring.clear()


func format_entry(entry: Dictionary) -> String:
	return (
		"[%8.3f] %s %s: %s"
		% [float(entry["time"]), LEVEL_NAMES[int(entry["level"])], String(entry["category"]), String(entry["message"])]
	)


func _write(level: Level, category: StringName, message: String) -> void:
	if level < min_level:
		return
	var entry: Dictionary = {
		"time": Time.get_ticks_msec() / 1000.0,
		"level": level,
		"category": category,
		"message": message,
	}
	_ring.append(entry)
	if _ring.size() > RING_SIZE:
		_ring.pop_front()
	if echo_to_stdout:
		var line: String = format_entry(entry)
		if level >= Level.ERROR:
			printerr(line)
		else:
			print(line)
	entry_added.emit(entry)
