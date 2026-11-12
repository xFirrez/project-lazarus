# NavTiles — tiled navigation for large maps (DEVELOPMENT_PLAN Step 8, D-051): one
# NavigationRegion3D per tile AABB (zone areas on Vesper Peak), all baked from ONE parse of the map's
# static colliders. Tiles use `filter_baking_aabb` + `border_size`, so their edges stay on the AABB
# planes and neighbouring tiles join through the navigation map's edge connections. Opening a door
# re-parses the geometry and re-bakes only the tiles its box touches (threaded), instead of the
# whole map. Clients never bake (they don't run zombie AI).
# Authority: HOST bakes; static map data otherwise.
class_name NavTiles
extends Node3D

signal tile_baked(index: int)
signal all_baked

const GROUP: StringName = &"nav_tiles"

var template: NavigationMesh = null
var geometry_root: Node = null
var regions: Array[NavigationRegion3D] = []
var boxes: Array[AABB] = []
# Threaded re-bakes never reached the navigation map under `--fixed-fps` (headless sims), so
# re-bakes are synchronous by default: only the touched tiles (~10-60 ms each, host only).
var async_rebake: bool = false
var bake_count: int = 0
var parse_usec: int = 0
var bake_usec: int = 0

var _source: NavigationMeshSourceGeometryData3D = null
var _pending: Dictionary = {}  # tile index -> true (bake in flight)
var _dirty: Dictionary = {}  # tile index -> true (re-bake once the in-flight bake ends)
var _bake_started: Dictionary = {}  # tile index -> usec


func _ready() -> void:
	add_to_group(GROUP)


static func find(node: Node) -> NavTiles:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as NavTiles


func add_tile(tile_name: String, box: AABB) -> NavigationRegion3D:
	var r: NavigationRegion3D = NavigationRegion3D.new()
	r.name = tile_name
	r.navigation_mesh = _tile_mesh(box)
	add_child(r)
	regions.append(r)
	boxes.append(box)
	return r


func _tile_mesh(box: AABB) -> NavigationMesh:
	var nm: NavigationMesh = template.duplicate() as NavigationMesh
	# Recast trims `border_size` off the baking box again, so the box is grown by it (x / z only):
	# the tile's polygons then end exactly on its AABB planes, unshrunk by the agent radius.
	var b: float = ceilf((template.agent_radius + template.cell_size) / template.cell_size) * template.cell_size
	nm.border_size = b
	nm.filter_baking_aabb = AABB(box.position - Vector3(b, 0.0, b), box.size + Vector3(b, 0.0, b) * 2.0)
	return nm


func is_baking() -> bool:
	return not _pending.is_empty()


# Parse every static collider once (main thread), then bake all tiles (threaded unless sync).
func bake_all(sync: bool = false) -> void:
	_parse()
	for i: int in regions.size():
		_bake(i, sync)


# A door at `box` changed: re-parse, re-bake the tiles it touches.
func rebake_around(box: AABB) -> void:
	_parse()
	var grown: AABB = box.grow(template.agent_radius + 0.5)
	for i: int in boxes.size():
		if boxes[i].intersects(grown):
			if _pending.has(i):
				_dirty[i] = true
			else:
				_bake(i, not async_rebake)


func tiles_touching(box: AABB) -> Array[int]:
	var out: Array[int] = []
	for i: int in boxes.size():
		if boxes[i].intersects(box):
			out.append(i)
	return out


func _parse() -> void:
	var t0: int = Time.get_ticks_usec()
	_source = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(template, _source, geometry_root if geometry_root != null else self)
	parse_usec = Time.get_ticks_usec() - t0


func _bake(i: int, sync: bool) -> void:
	var nm: NavigationMesh = _tile_mesh(boxes[i])
	_pending[i] = true
	_bake_started[i] = Time.get_ticks_usec()
	if sync:
		NavigationServer3D.bake_from_source_geometry_data(nm, _source)
		_on_baked(i, nm)
	else:
		# The callback may run on a worker thread: hop to the main thread.
		NavigationServer3D.bake_from_source_geometry_data_async(
			nm, _source, func() -> void: _on_baked.call_deferred(i, nm)
		)


func _on_baked(i: int, nm: NavigationMesh) -> void:
	if not is_inside_tree():
		return
	regions[i].navigation_mesh = nm
	bake_usec += Time.get_ticks_usec() - int(_bake_started.get(i, Time.get_ticks_usec()))
	bake_count += 1
	_pending.erase(i)
	tile_baked.emit(i)
	if _dirty.has(i):
		_dirty.erase(i)
		_bake(i, not async_rebake)
	elif _pending.is_empty():
		all_baked.emit()


func polygon_count() -> int:
	var n: int = 0
	for r: NavigationRegion3D in regions:
		if r.navigation_mesh != null:
			n += r.navigation_mesh.get_polygon_count()
	return n
