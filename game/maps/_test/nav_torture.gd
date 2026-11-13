# Nav torture map (Step 5 test arena, DEVELOPMENT_PLAN Step 5 scope 2): a 32 x 32 m building with
# three floors (y = 0 / 4 / 8) and an enclosed exterior yard to the north.
#   F1: west / east halves split by a wall at x = 0 with a toggle door (D1), a 1.2 m corridor and
#       crates in the east half, a double-height atrium (z > 4), stepped stairs up to F2 (x 11..15).
#   F2: south / north parts split by a wall at z = -6 with a 1.2 m doorway, a toggle door (D2) and a
#       vent duct (TraversalLink VENT); the north part is a balcony with a drop-down link to F1.
#   F3: reached by a ramp from F2 (x 0..12, z -15.5..-12.5).
#   Yard: two barricaded windows (W1, W2) in the north wall are the only way in (WINDOW links).
# Geometry is generated in code under a NavigationRegion3D baked at load with the zombie agent
# size. Markers: Target_F1/F2/F3, Spawn_* (ZombieSpawner), PlayerSpawn*, Route_* (bot route).
# Authority: static map; barricades and doors replicate through WorldSync.
extends Node3D

const AGENT_RADIUS: float = 0.3
const AGENT_HEIGHT: float = 1.8
const COLORS: Dictionary = {
	&"concrete": Color(0.5, 0.5, 0.52),
	&"wood": Color(0.52, 0.38, 0.25),
	&"metal": Color(0.42, 0.47, 0.53),
	&"snow": Color(0.88, 0.9, 0.94),
	&"tile": Color(0.62, 0.66, 0.64),
}

var nav: NavigationRegion3D = null
var _materials: Dictionary = {}


func _ready() -> void:
	_environment()
	nav = NavigationRegion3D.new()
	nav.name = "Nav"
	nav.navigation_mesh = make_navmesh()
	add_child(nav)
	_build_ground_floor()
	_build_second_floor()
	_build_third_floor()
	_build_yard()
	_markers()
	nav.bake_navigation_mesh(false)
	Log.info(&"map", "nav_torture navmesh: %d polygons" % nav.navigation_mesh.get_polygon_count())


static func make_navmesh() -> NavigationMesh:
	var nm: NavigationMesh = NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.cell_size = 0.15
	nm.cell_height = 0.1
	nm.agent_radius = AGENT_RADIUS
	nm.agent_height = AGENT_HEIGHT
	nm.agent_max_climb = 0.3
	nm.agent_max_slope = 40.0
	nm.region_min_size = 1.0
	nm.edge_max_error = 1.0
	return nm


# --- floors -----------------------------------------------------------------------------------


func _build_ground_floor() -> void:
	box("Ground", Vector3(0, -0.5, 7), Vector3(34, 1, 48), &"concrete")
	# Outer walls: south / west to F3 height, east to F2 height, north (windows) F1 only.
	box("WallS", Vector3(0, 6, -16.2), Vector3(32.8, 12, 0.4), &"concrete")
	box("WallW", Vector3(-16.2, 6, 0), Vector3(0.4, 12, 32.8), &"concrete")
	box("WallE_F1", Vector3(16.2, 2, 0), Vector3(0.4, 4, 32.8), &"concrete")
	box("WallE_F2", Vector3(16.2, 6, -6), Vector3(0.4, 4, 20.4), &"concrete")
	_north_wall_with_windows()
	# Divider at x = 0 (z -16..4) with door D1 at z -9..-7.
	box("Divider_a", Vector3(0, 2, -12.5), Vector3(0.3, 4, 7), &"concrete")
	box("Divider_b", Vector3(0, 2, -1.5), Vector3(0.3, 4, 11), &"concrete")
	box("Divider_lintel", Vector3(0, 3.2, -8), Vector3(0.3, 1.6, 2), &"concrete")
	door("D1_Door", Vector3(0, 1.2, -8), Vector3(0.2, 2.4, 2.0))
	# Narrow corridor (1.2 m clear) in the east half.
	box("Corridor_a", Vector3(4.0, 1.5, -9), Vector3(0.2, 3, 10), &"tile")
	box("Corridor_b", Vector3(5.4, 1.5, -9), Vector3(0.2, 3, 10), &"tile")
	# Obstacles.
	for c: Array in [
		[Vector3(-8, 0.6, -6), 1.2],
		[Vector3(-5, 0.5, 9), 1.0],
		[Vector3(6, 0.6, 10), 1.2],
		[Vector3(-11, 0.5, 11), 1.0]
	]:
		box("Crate_F1_%d" % int(absf(c[0].x * 10 + c[0].z)), c[0], Vector3.ONE * float(c[1]), &"wood")
	# Stairs F1 -> F2: 16 steps (0.25 rise, 0.5 run) climbing toward -Z, x 11..15, z -2..-10.
	for i: int in 16:
		var top: float = (i + 1) * 0.25
		box("Step%02d" % i, Vector3(13, top * 0.5, -2.25 - 0.5 * i), Vector3(4, top, 0.5), &"concrete")


func _north_wall_with_windows() -> void:
	# Window openings 1.4 m wide, sill 0.9, top 2.1 at x = -8 (W1) and x = 8 (W2).
	box("WallN_a", Vector3(-12.55, 2, 16.2), Vector3(7.7, 4, 0.4), &"concrete")
	box("WallN_b", Vector3(0, 2, 16.2), Vector3(14.6, 4, 0.4), &"concrete")
	box("WallN_c", Vector3(12.55, 2, 16.2), Vector3(7.7, 4, 0.4), &"concrete")
	for x: float in [-8.0, 8.0]:
		var wid: String = "W1" if x < 0.0 else "W2"
		box("%s_sill" % wid, Vector3(x, 0.45, 16.2), Vector3(1.4, 0.9, 0.4), &"concrete")
		box("%s_head" % wid, Vector3(x, 3.05, 16.2), Vector3(1.4, 1.9, 0.4), &"concrete")
		var b: Barricade = Barricade.new()
		b.name = "%s_Barricade" % wid
		b.position = Vector3(x, 1.5, 16.2)
		add_child(b)
		var link: TraversalLink = TraversalLink.create(
			TraversalLink.Action.WINDOW, Vector3(x, 0, 17.0), Vector3(x, 0, 15.0), b
		)
		link.name = "%s_Link" % wid
		add_child(link)
		var sp: ZombieSpawner = spawner("Spawn_%s" % wid, Vector3(x, 0, 21), ZombieSpawner.Kind.WINDOW, &"yard")
		sp.barricade = b


func _build_second_floor() -> void:
	const Y: float = 3.8
	# Slab z -16..4 with the stairwell hole x 11..15, z -10..-2.
	box("F2_a", Vector3(-2.5, Y, -6), Vector3(27, 0.4, 20), &"concrete")
	box("F2_b", Vector3(13.5, Y, -13), Vector3(5, 0.4, 6), &"concrete")
	box("F2_c", Vector3(13.5, Y, 1), Vector3(5, 0.4, 6), &"concrete")
	box("F2_d", Vector3(15.5, Y, -6), Vector3(1, 0.4, 8), &"concrete")
	box("F2_rail_hole_w", Vector3(11, 4.5, -6), Vector3(0.15, 1.0, 8), &"metal")
	box("F2_rail_hole_e", Vector3(15, 4.5, -6), Vector3(0.15, 1.0, 8), &"metal")
	box("F2_rail_hole_n", Vector3(13, 4.5, -2), Vector3(4, 1.0, 0.15), &"metal")
	# Balcony railing at z = 4 with a gap at x -7..-5 (drop-down to the atrium).
	box("F2_rail_a", Vector3(-11.5, 4.5, 3.9), Vector3(9, 1.0, 0.15), &"metal")
	box("F2_rail_b", Vector3(5.5, 4.5, 3.9), Vector3(21, 1.0, 0.15), &"metal")
	var drop: TraversalLink = TraversalLink.create(TraversalLink.Action.DROP, Vector3(-6, 4, 3.2), Vector3(-6, 0, 5.6))
	drop.name = "Drop_F2_F1"
	add_child(drop)
	# Divider at z = -6 (x -16..11): 1.2 m doorway at x -3..-1.8, door D2 at x 4..5.6, vent at x -12.
	box("F2_div_a", Vector3(-12.6, 6, -6), Vector3(0.8, 4, 0.3), &"concrete")
	box("F2_div_b", Vector3(-14.5, 6, -6), Vector3(3, 4, 0.3), &"concrete")
	box("F2_vent_top", Vector3(-11.6, 6.4, -6), Vector3(1.2, 3.2, 0.3), &"concrete")
	box("F2_div_c", Vector3(-7, 6, -6), Vector3(8, 4, 0.3), &"concrete")
	box("F2_div_d", Vector3(1.1, 6, -6), Vector3(5.8, 4, 0.3), &"concrete")
	box("F2_div_e", Vector3(8.3, 6, -6), Vector3(5.4, 4, 0.3), &"concrete")
	box("F2_div_f", Vector3(15.5, 6, -6), Vector3(1, 4, 0.3), &"concrete")
	box("F2_div_lintel", Vector3(4.8, 7.2, -6), Vector3(1.6, 1.6, 0.3), &"concrete")
	door("D2_Door", Vector3(4.8, 5.2, -6), Vector3(1.6, 2.4, 0.2))
	var vent: TraversalLink = TraversalLink.create(
		TraversalLink.Action.VENT, Vector3(-11.6, 4, -4.9), Vector3(-11.6, 4, -7.1), null, true
	)
	vent.name = "Vent_F2"
	add_child(vent)
	for c: Vector3 in [Vector3(-8, 4.6, -11), Vector3(7, 4.5, 0), Vector3(-12, 4.5, 0)]:
		box("Crate_F2_%d" % int(absf(c.x * 10 + c.z)), c, Vector3.ONE * 1.0, &"wood")


func _build_third_floor() -> void:
	box("F3", Vector3(-8, 7.8, -10), Vector3(16, 0.4, 12), &"concrete")
	box("F3_rail_n", Vector3(-8, 8.5, -4.1), Vector3(16, 1.0, 0.15), &"metal")
	box("F3_rail_e", Vector3(-0.1, 8.5, -8.25), Vector3(0.15, 1.0, 8.5), &"metal")
	box("F3_rail_e2", Vector3(-0.1, 8.5, -15.75), Vector3(0.15, 1.0, 0.5), &"metal")
	# Ramp F2 (x 12, y 4) -> F3 (x 0, y 8): 12 m run, 4 m rise.
	var run: float = 12.0
	var rise: float = 4.0
	var length: float = sqrt(run * run + rise * rise)
	var ramp: StaticBody3D = box("Ramp", Vector3.ZERO, Vector3(length, 0.3, 3), &"metal")
	ramp.transform = Transform3D(
		Basis(Vector3.BACK, -atan2(rise, run)), Vector3(6, 6 - 0.15 / cos(atan2(rise, run)), -14)
	)
	for c: Vector3 in [Vector3(-10, 8.5, -8), Vector3(-5, 8.5, -13)]:
		box("Crate_F3_%d" % int(absf(c.x * 10 + c.z)), c, Vector3.ONE, &"wood")


func _build_yard() -> void:
	box("Yard_N", Vector3(0, 1.5, 30.2), Vector3(32.8, 3, 0.4), &"concrete")
	box("Yard_W", Vector3(-16.2, 1.5, 23.2), Vector3(0.4, 3, 14), &"concrete")
	box("Yard_E", Vector3(16.2, 1.5, 23.2), Vector3(0.4, 3, 14), &"concrete")


func _markers() -> void:
	marker("Target_F1", Vector3(-8, 0, -11))
	marker("Target_F2", Vector3(-6, 4, 0))
	marker("Target_F3", Vector3(-8, 8, -12))
	marker("Target_Atrium", Vector3(0, 0, 9))
	for i: int in 4:
		var m: Marker3D = marker("PlayerSpawn%d" % i, Vector3(-1.5 + i, 0.05, 8))
		m.add_to_group(&"player_spawn")
	# Bot route across floors (AC-5.2): atrium -> stairs -> F2 south -> F3 -> back down.
	var route: Array[Vector3] = [
		Vector3(2, 0, 8),
		Vector3(13, 0, 0),
		Vector3(13, 4, -11.5),
		Vector3(10, 4, -13.8),
		Vector3(-4, 8, -13.8),
		Vector3(-8, 8, -8),
		Vector3(-4, 8, -13.8),
		Vector3(10, 4, -13.8)
	]
	for i: int in route.size():
		marker("Route_%d" % i, route[i])
	var risers: Array = [
		["Spawn_F1_W1", Vector3(-12, 0, -13)],
		["Spawn_F1_W2", Vector3(-13, 0, 1)],
		["Spawn_F1_E1", Vector3(9, 0, -14)],
		["Spawn_F1_E2", Vector3(8, 0, 2)],
		["Spawn_F1_A", Vector3(10, 0, 12)],
		["Spawn_F2_S1", Vector3(-10, 4, -13)],
		["Spawn_F2_S2", Vector3(6, 4, -9)],
		["Spawn_F2_N1", Vector3(-12, 4, 2)],
		["Spawn_F2_N2", Vector3(8, 4, -3)],
		["Spawn_F3_1", Vector3(-13, 8, -14)],
		["Spawn_F3_2", Vector3(-3, 8, -6)],
	]
	for r: Array in risers:
		spawner(r[0], r[1], ZombieSpawner.Kind.RISER, StringName(String(r[0]).get_slice("_", 1)))
	_shot("ShotA_Overview", Vector3(26, 22, 30), Vector3(0, 2, 0))
	_shot("ShotB_Atrium", Vector3(-12, 6, 14), Vector3(4, 1, 2))
	_shot("ShotC_Windows", Vector3(0, 4, 28), Vector3(0, 1, 16))


# --- helpers ----------------------------------------------------------------------------------


func box(node_name: String, center: Vector3, size: Vector3, surface: StringName) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	body.physics_material_override = SurfaceTags.make_material(surface)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = _mat(surface)
	body.add_child(mesh)
	var col: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	col.shape = bs
	body.add_child(col)
	nav.add_child(body)
	return body


func door(node_name: String, center: Vector3, size: Vector3) -> NavDoor:
	var d: NavDoor = NavDoor.new()
	d.name = node_name
	d.position = center
	d.size = size
	nav.add_child(d)
	return d


func marker(node_name: String, pos: Vector3) -> Marker3D:
	var m: Marker3D = Marker3D.new()
	m.name = node_name
	m.position = pos
	add_child(m)
	return m


func spawner(node_name: String, pos: Vector3, kind: ZombieSpawner.Kind, zone: StringName) -> ZombieSpawner:
	var s: ZombieSpawner = ZombieSpawner.new()
	s.name = node_name
	s.position = pos
	s.kind = kind
	s.zone = zone
	add_child(s)
	return s


func _mat(surface: StringName) -> StandardMaterial3D:
	if not _materials.has(surface):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = COLORS.get(surface, Color(0.5, 0.5, 0.5))
		m.roughness = 0.85
		_materials[surface] = m
	return _materials[surface]


func _shot(node_name: String, from: Vector3, at: Vector3) -> void:
	var cam: Camera3D = Camera3D.new()
	cam.name = node_name
	add_child(cam)
	cam.look_at_from_position(from, at)
	cam.add_to_group(&"screenshot_shot")


func _environment() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.6, 0.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.65, 0.7)
	env.ambient_light_energy = 0.7
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	sun.add_to_group(&"shadow_light")
	add_child(sun)
