# AC-4.1: every scripted kit piece imports with the bounds the generator promised
# (content/kits/vesper/kit_manifest.json), lands on the 2 m / 0.5 m grid, has collision with the
# right surface tags, and pieces placed on the grid join without gaps (raycasts across every seam
# of a wall run, a floor patch and a stair-to-landing joint).
extends GutTest

const KIT: String = "res://content/kits/vesper/"

var _manifest: Dictionary = {}
var _root: Node3D = null


func before_all() -> void:
	var f: FileAccess = FileAccess.open(KIT + "kit_manifest.json", FileAccess.READ)
	_manifest = JSON.parse_string(f.get_as_text())


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)


func _place(piece: String, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var n: Node3D = (load(KIT + piece + ".glb") as PackedScene).instantiate() as Node3D
	n.position = pos
	n.rotation_degrees.y = yaw
	_root.add_child(n)
	return n


func _visual_aabb(n: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for m: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		var box: AABB = mi.global_transform * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	return _root.get_world_3d().direct_space_state.intersect_ray(q)


func _settle() -> void:
	for i: int in 3:
		await get_tree().physics_frame


func test_manifest_lists_the_v1_kit() -> void:
	var pieces: Dictionary = _manifest["pieces"]
	for name: String in [
		"wall_2m",
		"wall_2m_exterior",
		"wall_window_2m",
		"wall_window_2m_exterior",
		"wall_door_2m",
		"floor_2m",
		"floor_2m_exterior",
		"stairs_2m",
		"pillar_corner",
		"railing_2m",
		"pipe_2m",
		"pipe_elbow",
		"trim_baseboard_2m",
		"trim_crown_2m",
		"window_glass_2m"
	]:
		assert_true(pieces.has(name), "kit has %s" % name)
	assert_eq(float(_manifest["grid"]), 2.0)
	assert_eq(float(_manifest["sub_grid"]), 0.5)


func test_pieces_match_manifest_bounds_and_collision() -> void:
	var pieces: Dictionary = _manifest["pieces"]
	for name: String in pieces:
		var info: Dictionary = pieces[name]
		var n: Node3D = _place(name, Vector3.ZERO)
		var box: AABB = _visual_aabb(n)
		var b: Array = info["bounds"]
		var lo: Vector3 = Vector3(b[0][0], b[0][1], b[0][2])
		var hi: Vector3 = Vector3(b[1][0], b[1][1], b[1][2])
		var tol: float = 0.06 if info.get("approx", false) else 0.01
		assert_true(box.position.distance_to(lo) < tol, "%s min %s ~ %s" % [name, box.position, lo])
		assert_true(box.end.distance_to(hi) < tol, "%s max %s ~ %s" % [name, box.end, hi])
		var bodies: Array[Node] = n.find_children("*", "StaticBody3D", true, false)
		if bool(info["collision"]):
			assert_true(bodies.size() > 0, "%s has collision" % name)
			for body: Node in bodies:
				assert_eq((body as StaticBody3D).collision_layer, 1, "%s collider on world layer" % name)
				assert_true(body.get_child_count() > 0 and body.get_child(0) is CollisionShape3D)
				assert_true(
					SurfaceTags.KNOWN.has(SurfaceTags.of(body)), "%s surface tag %s" % [name, SurfaceTags.of(body)]
				)
		else:
			assert_eq(bodies.size(), 0, "%s is visual only" % name)
		n.free()


func test_grid_footprints() -> void:
	# Walls and floors span exactly one 2 m cell; heights are multiples of the 0.5 m sub-grid.
	for name: String in ["wall_2m", "wall_2m_exterior", "wall_window_2m", "wall_door_2m"]:
		var b: Array = _manifest["pieces"][name]["bounds"]
		assert_almost_eq(float(b[1][0]) - float(b[0][0]), 2.0, 0.001, "%s width" % name)
		assert_almost_eq(fmod(float(b[1][1]), 0.5), 0.0, 0.001, "%s height on sub-grid" % name)
	for name: String in ["floor_2m", "floor_2m_exterior"]:
		var b: Array = _manifest["pieces"][name]["bounds"]
		assert_almost_eq(float(b[1][0]) - float(b[0][0]), 2.0, 0.001)
		assert_almost_eq(float(b[1][2]) - float(b[0][2]), 2.0, 0.001)
		assert_almost_eq(float(b[1][1]), 0.0, 0.001, "%s top at the origin" % name)


func test_wall_run_has_no_gaps() -> void:
	for x: int in [-2, 0, 2]:
		_place("wall_2m", Vector3(x, 0, 0))
	_place("wall_window_2m", Vector3(4, 0, 0))
	_place("wall_door_2m", Vector3(6, 0, 0))
	await _settle()
	# Rays through the wall line at every seam and between seams, at several heights.
	var blocked: int = 0
	var total: int = 0
	var misses: Array[Vector2] = []
	for xi: int in range(-11, 28):  # x = -2.75 .. 6.75 (piece ends at -3 and 7 are free edges)
		var x: float = xi * 0.25
		if x > 3.4 and x < 4.6 or x > 5.3 and x < 6.7:
			continue  # window and door openings checked below
		for y: float in [0.05, 0.5, 1.2, 2.0, 3.0, 3.95]:
			total += 1
			if not _ray(Vector3(x, y, 1.0), Vector3(x, y, -1.0)).is_empty():
				blocked += 1
			else:
				misses.append(Vector2(x, y))
	assert_eq(blocked, total, "every ray across the wall run is blocked (%d/%d) misses %s" % [blocked, total, misses])
	assert_true(_ray(Vector3(4, 1.6, 1), Vector3(4, 1.6, -1)).is_empty(), "window opening is open")
	assert_false(_ray(Vector3(4, 0.5, 1), Vector3(4, 0.5, -1)).is_empty(), "wall below the sill")
	assert_true(_ray(Vector3(6, 1.2, 1), Vector3(6, 1.2, -1)).is_empty(), "door opening is open")
	var win: Node3D = _root.get_child(3) as Node3D
	var sockets: Array[Node] = win.find_children("Socket_*", "", true, false)
	assert_eq(sockets.size(), 7, "6 barricade plank sockets + climb socket")


func test_floor_patch_and_stairs_join_without_gaps() -> void:
	for x: int in [-2, 0, 2]:
		for z: int in [-2, 0, 2]:
			_place("floor_2m_exterior", Vector3(x, 0, z + 2))
	_place("stairs_2m", Vector3(0, 0, -1))  # runs toward -Z from z=-1 to z=-5, rising 2 m
	_place("floor_2m", Vector3(0, 2, -6))
	await _settle()
	var holes: int = 0
	for xi: int in range(-11, 12):
		for zi: int in range(1, 24):
			var p: Vector3 = Vector3(xi * 0.25, 5, -1.0 + zi * 0.25)
			var hit: Dictionary = _ray(p, p + Vector3.DOWN * 10)
			if hit.is_empty() or absf((hit["position"] as Vector3).y) > 0.001:
				holes += 1
			elif SurfaceTags.of(hit["collider"]) != &"snow":
				holes += 1
	assert_eq(holes, 0, "floor patch is continuous and tagged snow at every sample")
	# Stair ramp: heights climb monotonically and meet the landing floor at 2 m.
	var last: float = -1.0
	var mono: bool = true
	for k: int in 17:
		var z: float = -1.0 - k * 0.25
		var hit: Dictionary = _ray(Vector3(0, 6, z), Vector3(0, -1, z))
		var h: float = (hit["position"] as Vector3).y if not hit.is_empty() else -10.0
		mono = mono and h >= last - 0.001
		last = h
	assert_true(mono, "stair ramp rises monotonically")
	var a: Dictionary = _ray(Vector3(0, 6, -4.95), Vector3(0, -1, -4.95))
	var b: Dictionary = _ray(Vector3(0, 6, -5.05), Vector3(0, -1, -5.05))
	assert_false(a.is_empty() or b.is_empty(), "stair top and landing both solid")
	if not a.is_empty() and not b.is_empty():
		assert_almost_eq((a["position"] as Vector3).y, 2.0, 0.05, "stair top at 2 m")
		assert_almost_eq((b["position"] as Vector3).y, 2.0, 0.001, "landing at 2 m")
