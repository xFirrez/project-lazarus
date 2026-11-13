# Content — registry of data definitions (maps now; weapons, perks, ... later) by StringName id.
# Scans res://content and res://maps for .tres resources that expose an `id` property.
# Authority: local, read-only data identical on every peer.
extends Node

const SCAN_ROOTS: PackedStringArray = ["res://content", "res://maps"]

var _by_type: Dictionary = {}  # StringName class -> {id -> Resource}


func _ready() -> void:
	rescan()


func rescan() -> void:
	_by_type.clear()
	for root: String in SCAN_ROOTS:
		_scan_dir(root)
	var counts: PackedStringArray = []
	for type_name: StringName in _by_type:
		counts.append("%s=%d" % [type_name, (_by_type[type_name] as Dictionary).size()])
	Log.info(&"content", "Registry: %s" % (", ".join(counts) if not counts.is_empty() else "empty"))


func register(type_name: StringName, def: Resource) -> void:
	if not _by_type.has(type_name):
		_by_type[type_name] = {}
	var table: Dictionary = _by_type[type_name]
	var def_id: StringName = def.get(&"id")
	if table.has(def_id):
		Log.warn(&"content", "Duplicate %s id '%s'" % [type_name, def_id])
	table[def_id] = def


func get_def(type_name: StringName, def_id: StringName) -> Resource:
	var table: Dictionary = _by_type.get(type_name, {})
	return table.get(def_id, null)


func get_all(type_name: StringName) -> Array[Resource]:
	var out: Array[Resource] = []
	var table: Dictionary = _by_type.get(type_name, {})
	for def_id: StringName in table:
		out.append(table[def_id])
	return out


func get_map(map_id: StringName) -> MapDefinition:
	return get_def(&"MapDefinition", map_id) as MapDefinition


func _scan_dir(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan_dir(full)
		else:
			var file: String = full.trim_suffix(".remap")
			if file.ends_with(".tres"):
				_try_register(file)
		entry = dir.get_next()
	dir.list_dir_end()


func _try_register(file: String) -> void:
	var res: Resource = ResourceLoader.load(file)
	if res == null or not ("id" in res):
		return
	var script: Script = res.get_script()
	if script == null:
		return
	var type_name: StringName = script.get_global_name()
	if type_name == &"":
		return
	register(type_name, res)
