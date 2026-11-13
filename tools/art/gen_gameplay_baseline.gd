# Writes game/maps/vesper_peak/gameplay_baseline.json: the global transform of every gameplay node
# of Vesper Peak (everything under each zone's `Gameplay/`, plus the NavDoors), keyed by node path
# relative to the map root. Generated ONCE from the Step 8–12 greybox (before the Step 13 art pass);
# tests/integration/test_vesper_art_markers.gd diffs the live map against it (AC-13.1, 0.01 m).
# Re-run only for an intentional, logged marker change: tools/art/gen_gameplay_baseline.sh
extends SceneTree

const MAP: String = "res://maps/vesper_peak/vesper_peak.tscn"
const OUT: String = "res://maps/vesper_peak/gameplay_baseline.json"

var _root: Node3D = null
var _frames: int = 0


func _initialize() -> void:
	_root = (load(MAP) as PackedScene).instantiate() as Node3D
	root.add_child(_root)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	var out: Dictionary = collect(_root)
	var path: String = OUT
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			path = a.trim_prefix("--out=")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"map": "vesper_peak", "nodes": out}, " ", true))
	f.close()
	print("gameplay baseline: %d nodes -> %s" % [out.size(), path])
	_root.queue_free()
	return true


static func collect(map_root: Node3D) -> Dictionary:
	var out: Dictionary = {}
	for z: Node in map_root.get_children():
		var gp: Node = z.get_node_or_null(^"Gameplay")
		if gp != null:
			_walk(map_root, gp, out)
		var geo: Node = z.get_node_or_null(^"Geometry")
		if geo != null:
			for d: Node in geo.find_children("*", "NavDoor", true, false):
				_add(map_root, d as Node3D, out)
	return out


static func _walk(map_root: Node3D, n: Node, out: Dictionary) -> void:
	for c: Node in n.get_children():
		if c is Node3D:
			_add(map_root, c as Node3D, out)
		_walk(map_root, c, out)


static func _add(map_root: Node3D, n: Node3D, out: Dictionary) -> void:
	var p: String = String(map_root.get_path_to(n))
	if p.contains("@"):
		return  # auto-named helper nodes have unstable names
	var t: Transform3D = n.global_transform
	var e: Vector3 = t.basis.get_euler()
	out[p] = [
		snappedf(t.origin.x, 0.001),
		snappedf(t.origin.y, 0.001),
		snappedf(t.origin.z, 0.001),
		snappedf(e.x, 0.0001),
		snappedf(e.y, 0.0001),
		snappedf(e.z, 0.0001),
	]
