# Vesper Peak — Step 6 playable slice (DEVELOPMENT_PLAN Step 6 scope 1, VESPER_PEAK §3): the
# Arrival Station (Z01) in greybox plus stub rooms behind D01 (a corner of the Sanatorium Lobby,
# Z03) and D02 (a strip of the Frozen Courtyard, Z06), so door purchases matter. Step 8 replaces
# this with the full kit-based greybox; ids, zone ids and spawner kinds already follow the map doc.
#   Z01 ticket hall 26 x 16 m (x -13..13, z -8..8), waiting gallery +2.5 m along the north side
#       (z 3..8) with two staircases, 4 barricaded windows (2 ground W_G1/W_G2, 2 gallery W_U1/W_U2),
#       a maintenance vent (from round 3), M14 + Coachgun wall-buys, luggage carousel, booths.
#   D01 east (750) -> covered walkway -> Z03 stub (2 windows). D02 south (1000) -> Z06 stub (risers
#       from round 2). Elevations between zones are flattened for the slice (Step 8 restores them).
# Geometry is generated under one NavigationRegion3D (doors re-bake it when bought). Gameplay
# markers live under `Gameplay/`.
# Authority: static map; doors / barricades replicate through WorldSync.
extends Node3D

const AGENT_RADIUS: float = 0.3
const AGENT_HEIGHT: float = 1.8
const HALL_H: float = 6.5
const GALLERY_Y: float = 2.5
const COLORS: Dictionary = {
	&"concrete": Color(0.52, 0.52, 0.54),
	&"tile": Color(0.6, 0.58, 0.52),
	&"wood": Color(0.5, 0.36, 0.24),
	&"metal": Color(0.4, 0.44, 0.5),
	&"snow": Color(0.86, 0.88, 0.93),
}

var nav: NavigationRegion3D = null
var gameplay: Node3D = null
var _materials: Dictionary = {}


func _ready() -> void:
	_environment()
	nav = NavigationRegion3D.new()
	nav.name = "Nav"
	nav.navigation_mesh = make_navmesh()
	add_child(nav)
	gameplay = Node3D.new()
	gameplay.name = "Gameplay"
	add_child(gameplay)
	_build_hall()
	_build_gallery()
	_build_window_exteriors()
	_build_vent()
	_build_d01_and_z03()
	_build_d02_and_z06()
	_markers()
	nav.bake_navigation_mesh(false)
	Log.info(&"map", "vesper_peak (Step 6 slice) navmesh: %d polygons" % nav.navigation_mesh.get_polygon_count())


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


# --- Z01 Arrival Station ------------------------------------------------------------------------


func _build_hall() -> void:
	box("Ground", Vector3(8, -0.5, -4), Vector3(60, 1, 44), &"tile")
	box("Roof", Vector3(0, HALL_H + 0.2, 0), Vector3(26.8, 0.4, 16.8), &"concrete")
	# West wall: ground window W_G1 (z -3), gallery window W_U1 (z 5.5).
	wall_x("WallW", -13.2, -8.4, 8.4, HALL_H, [[-3.0, 1.4, 0.9, 2.1], [5.5, 1.4, GALLERY_Y + 0.9, GALLERY_Y + 2.1]])
	# East wall: D01 opening (z -3, 2.4 x 2.6), gallery window W_U2 (z 5.5).
	wall_x("WallE", 13.2, -8.4, 8.4, HALL_H, [[-3.0, 2.4, 0.0, 2.6], [5.5, 1.4, GALLERY_Y + 0.9, GALLERY_Y + 2.1]])
	# South wall: ground window W_G2 (x -6), D02 opening (x 6).
	wall_z("WallS", -8.2, -13.4, 13.4, HALL_H, [[-6.0, 1.4, 0.9, 2.1], [6.0, 2.4, 0.0, 2.6]])
	# North wall: low maintenance vent opening at x 0 (1.0 x 1.0, floor level).
	wall_z("WallN", 8.2, -13.4, 13.4, HALL_H, [[0.0, 1.0, 0.0, 1.0]])
	for w: Array in [["W_G1", Vector3(-13.2, 1.5, -3.0), -PI * 0.5], ["W_G2", Vector3(-6.0, 1.5, -8.2), PI]]:
		_barricade(w[0], w[1], float(w[2]))
	# Obstacles: ticket booth, benches, luggage carousel (under the gallery).
	box("TicketBooth", Vector3(10, 1.1, -6), Vector3(2, 2.2, 2), &"wood")
	box("Bench_W", Vector3(-4, 0.25, -1), Vector3(2.4, 0.5, 0.6), &"wood")
	box("Bench_E", Vector3(4, 0.25, -1), Vector3(2.4, 0.5, 0.6), &"wood")
	box("Carousel", Vector3(0, 0.4, 5.5), Vector3(6, 0.8, 2), &"metal")


func _build_gallery() -> void:
	box("Gallery", Vector3(0, GALLERY_Y - 0.15, 5.6), Vector3(26.4, 0.3, 5.2), &"wood")
	box("GalleryRail", Vector3(0, GALLERY_Y + 0.5, 3.1), Vector3(19.0, 1.0, 0.12), &"metal")
	for sx: float in [-1.0, 1.0]:
		var x: float = 11.1 * sx
		for i: int in 10:
			var top: float = (i + 1) * 0.25
			box(
				"Stair%s_%02d" % ["W" if sx < 0 else "E", i],
				Vector3(x, top * 0.5, -0.8 + 0.4 * i),
				Vector3(3, top, 0.4),
				&"wood"
			)
	for w: Array in [
		["W_U1", Vector3(-13.2, GALLERY_Y + 1.5, 5.5), -PI * 0.5],
		["W_U2", Vector3(13.2, GALLERY_Y + 1.5, 5.5), PI * 0.5]
	]:
		_barricade(w[0], w[1], float(w[2]))


# Window exteriors: enclosed strips / ledges only zombies use. Spawners hug the outer wall beside
# each window so they are out of sight from inside (GAME_DESIGN §5.2 fairness).
func _build_window_exteriors() -> void:
	# W_G1 west yard (x -16.6..-13.4, z -8..2).
	box("YardW_Wall", Vector3(-16.8, 1.5, -3), Vector3(0.4, 3, 10.4), &"concrete")
	box("YardW_S", Vector3(-15.1, 1.5, -8.2), Vector3(3.8, 3, 0.4), &"concrete")
	spawner("Spawn_Z01_W_G1", Vector3(-14.4, 0, 0.8), ZombieSpawner.Kind.WINDOW, &"Z01")
	# W_G2 south yard (x -13.2..0, z -11.6..-8.4).
	box("YardS_Wall", Vector3(-6.6, 1.5, -11.8), Vector3(13.6, 3, 0.4), &"concrete")
	box("YardS_W", Vector3(-13.4, 1.5, -10), Vector3(0.4, 3, 3.6), &"concrete")
	box("YardS_E", Vector3(0.2, 1.5, -10), Vector3(0.4, 3, 3.6), &"concrete")
	spawner("Spawn_Z01_W_G2", Vector3(-10.5, 0, -9.4), ZombieSpawner.Kind.WINDOW, &"Z01")
	# Gallery ledges (+2.5 m), solid underneath: west x -16.6..-13.4 / east 13.4..16.6, z 2..8.4.
	for sx: float in [-1.0, 1.0]:
		var side: String = "W" if sx < 0 else "E"
		box("Ledge%s" % side, Vector3(15.0 * sx, GALLERY_Y * 0.5, 5.2), Vector3(3.2, GALLERY_Y, 6.4), &"concrete")
		box("Ledge%s_Wall" % side, Vector3(16.8 * sx, GALLERY_Y + 1.5, 5.2), Vector3(0.4, 3, 6.8), &"concrete")
		box("Ledge%s_N" % side, Vector3(15.0 * sx, GALLERY_Y + 1.5, 8.4), Vector3(3.6, 3, 0.4), &"concrete")
		box("Ledge%s_S" % side, Vector3(15.0 * sx, GALLERY_Y + 1.5, 2.0), Vector3(3.6, 3, 0.4), &"concrete")
		spawner(
			"Spawn_Z01_W_U%d" % (1 if sx < 0 else 2),
			Vector3(14.4 * sx, GALLERY_Y, 2.8),
			ZombieSpawner.Kind.WINDOW,
			&"Z01"
		)


func _build_vent() -> void:
	# Maintenance crawlspace behind the north wall; zombies come through the low vent (round 3+).
	box("Crawl_W", Vector3(-2.2, 1.5, 9.9), Vector3(0.4, 3, 3.0), &"concrete")
	box("Crawl_E", Vector3(2.2, 1.5, 9.9), Vector3(0.4, 3, 3.0), &"concrete")
	box("Crawl_N", Vector3(0, 1.5, 11.6), Vector3(4.8, 3, 0.4), &"concrete")
	box("Crawl_Roof", Vector3(0, 3.2, 9.9), Vector3(4.8, 0.4, 3.8), &"concrete")
	var vent: TraversalLink = TraversalLink.create(TraversalLink.Action.VENT, Vector3(0, 0, 9.3), Vector3(0, 0, 7.3))
	vent.name = "Vent_Z01"
	gameplay.add_child(vent)
	var s: ZombieSpawner = spawner("Spawn_Z01_Vent", Vector3(-1.2, 0, 10.8), ZombieSpawner.Kind.VENT, &"Z01")
	s.min_round = 3


# --- D01 -> Z03 Sanatorium Lobby (stub) ---------------------------------------------------------


func _build_d01_and_z03() -> void:
	var d: NavDoor = door("D01_Debris", Vector3(13.2, 1.3, -3), Vector3(0.3, 2.6, 2.4))
	buy_door("D01_Buy", Vector3(12.5, 1.3, -3), &"D01", "debris", 750, [&"Z03"], [d])
	# Covered walkway (x 13.4..21, z -4.6..-1.4).
	box("Walk_N", Vector3(17.2, 1.75, -1.2), Vector3(7.6, 3.5, 0.4), &"concrete")
	box("Walk_S", Vector3(17.2, 1.75, -4.8), Vector3(7.6, 3.5, 0.4), &"concrete")
	box("Walk_Roof", Vector3(17.2, 3.7, -3), Vector3(7.6, 0.4, 4), &"concrete")
	# Lobby corner (x 21..33, z -9..5) with two ground windows in the north wall.
	wall_x("Z03_WallW", 21.2, -9.4, 5.4, 5.0, [[-3.0, 3.2, 0.0, 3.5]])
	wall_x("Z03_WallE", 33.2, -9.4, 5.4, 5.0, [])
	wall_z("Z03_WallS", -9.2, 21.0, 33.4, 5.0, [])
	wall_z("Z03_WallN", 5.2, 21.0, 33.4, 5.0, [[24.0, 1.4, 0.9, 2.1], [30.0, 1.4, 0.9, 2.1]])
	box("Z03_Roof", Vector3(27.2, 5.2, -2), Vector3(12.4, 0.4, 14.8), &"concrete")
	box("Z03_Desk", Vector3(27, 0.55, -5), Vector3(4, 1.1, 1), &"wood")
	for w: Array in [["W_Z03_1", Vector3(24, 1.5, 5.2)], ["W_Z03_2", Vector3(30, 1.5, 5.2)]]:
		_barricade(w[0], w[1], 0.0)
	box("Z03_YardN", Vector3(27.2, 1.5, 8.2), Vector3(12.4, 3, 0.4), &"concrete")
	box("Z03_YardW", Vector3(21.2, 1.5, 6.8), Vector3(0.4, 3, 3.2), &"concrete")
	box("Z03_YardE", Vector3(33.2, 1.5, 6.8), Vector3(0.4, 3, 3.2), &"concrete")
	spawner("Spawn_Z03_W1", Vector3(21.9, 0, 6.1), ZombieSpawner.Kind.WINDOW, &"Z03")
	spawner("Spawn_Z03_W2", Vector3(32.4, 0, 6.1), ZombieSpawner.Kind.WINDOW, &"Z03")


# --- D02 -> Z06 Frozen Courtyard (stub) ---------------------------------------------------------


func _build_d02_and_z06() -> void:
	var d: NavDoor = door("D02_Shutter", Vector3(6, 1.3, -8.2), Vector3(2.4, 2.6, 0.3))
	buy_door("D02_Buy", Vector3(6, 1.3, -7.5), &"D02", "cargo shutter", 1000, [&"Z06"], [d])
	box("Z06_WallW", Vector3(0.2, 2, -18.2), Vector3(0.4, 4, 12.8), &"concrete")
	box("Z06_WallE", Vector3(16.2, 2, -16.2), Vector3(0.4, 4, 16), &"concrete")
	box("Z06_WallS", Vector3(8.2, 2, -24.4), Vector3(16.4, 4, 0.4), &"concrete")
	box("Z06_WallN", Vector3(14.8, 2, -8.4), Vector3(2.8, 4, 0.4), &"concrete")
	box("Z06_Fountain", Vector3(8, 0.6, -17), Vector3(3, 1.2, 3), &"snow")
	box("Z06_Truck", Vector3(13.5, 1.2, -13), Vector3(2.5, 2.4, 5), &"metal")
	var risers: Array = [
		["Spawn_Z06_R1", Vector3(3, 0, -21)],
		["Spawn_Z06_R2", Vector3(13, 0, -21.5)],
		["Spawn_Z06_R3", Vector3(3, 0, -13.5)],
		["Spawn_Z06_R4", Vector3(10.5, 0, -11.5)],
	]
	for r: Array in risers:
		var s: ZombieSpawner = spawner(r[0], r[1], ZombieSpawner.Kind.RISER, &"Z06")
		s.min_round = 2


func _markers() -> void:
	for i: int in 4:
		var m: Marker3D = marker("PlayerSpawn%d" % i, Vector3(-1.5 + i, 0.05, -3.0))
		m.add_to_group(&"player_spawn")
	zone("Zone_Z01", &"Z01", Vector3(0, 3.25, 0), Vector3(26.4, 7.5, 16.4))
	zone("Zone_Z03_Walk", &"Z03", Vector3(17.3, 2, -3), Vector3(7.8, 4, 3.4))
	zone("Zone_Z03", &"Z03", Vector3(27.2, 2.5, -2), Vector3(12, 5, 14.4))
	zone("Zone_Z06", &"Z06", Vector3(8.2, 2.5, -16.4), Vector3(15.6, 5, 15.6))
	var wb: WallBuy = WallBuy.new()
	wb.name = "WallBuy_M14"
	wb.weapon_id = &"m14"
	wb.position = Vector3(-1.5, 1.5, -7.95)
	gameplay.add_child(wb)
	var wb2: WallBuy = WallBuy.new()
	wb2.name = "WallBuy_Coachgun"
	wb2.weapon_id = &"coachgun"
	wb2.position = Vector3(-4, GALLERY_Y + 1.5, 7.95)
	wb2.rotation.y = PI
	gameplay.add_child(wb2)
	# Bot route (soak tests): a loop of the hall with detours through D01 / D02 once open.
	var route: Array = [
		[Vector3(-7, 0, -5), &""],
		[Vector3(-6, 0, -7.0), &""],
		[Vector3(7, 0, -5), &""],
		[Vector3(12, 0, -3), &""],
		[Vector3(17, 0, -3), &"D01"],
		[Vector3(26, 0, -2), &"D01"],
		[Vector3(17, 0, -3), &"D01"],
		[Vector3(12, 0, -3), &""],
		[Vector3(7, 0, -5), &""],
		[Vector3(6, 0, -7), &""],
		[Vector3(6, 0, -12), &"D02"],
		[Vector3(7, 0, -20), &"D02"],
		[Vector3(6, 0, -12), &"D02"],
		[Vector3(6, 0, -7), &""],
		[Vector3(7, 0, 2), &""],
		[Vector3(-7, 0, 2), &""],
		[Vector3(-12, 0, -3), &""],
	]
	for i: int in route.size():
		var m: Marker3D = marker("BotRoute_%02d" % i, route[i][0])
		m.add_to_group(&"bot_waypoint")
		m.set_meta(&"requires_door", route[i][1])
	_shot("ShotA_Hall", Vector3(-11, 5.5, -7), Vector3(4, 1, 4))
	_shot("ShotB_Gallery", Vector3(10, 4.2, 7.5), Vector3(-6, 1.5, -4))
	_shot("ShotC_Overview", Vector3(8, 34, -36), Vector3(8, 0, -4))


# --- helpers ------------------------------------------------------------------------------------


func _barricade(id: String, pos: Vector3, yaw: float) -> void:
	# Barricade frame: +Z is outside. yaw rotates that toward the exterior.
	var b: Barricade = Barricade.new()
	b.name = "%s_Barricade" % id
	b.position = pos
	b.rotation.y = yaw
	gameplay.add_child(b)
	var out: Vector3 = Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
	var sill_y: float = pos.y - 1.5
	var link: TraversalLink = TraversalLink.create(
		TraversalLink.Action.WINDOW,
		Vector3(pos.x, sill_y, pos.z) + out * 0.8,
		Vector3(pos.x, sill_y, pos.z) - out * 1.0,
		b
	)
	link.name = "%s_Link" % id
	gameplay.add_child(link)
	# Players can't climb out through an open window (player-only clip, not world / nav / bullets).
	var clip: StaticBody3D = StaticBody3D.new()
	clip.name = "%s_PlayerClip" % id
	clip.collision_layer = MotorComponent.PLAYER_CLIP_LAYER
	clip.collision_mask = 0
	clip.position = pos
	clip.rotation.y = yaw
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(1.6, 1.4, 0.3)
	cs.shape = bs
	clip.add_child(cs)
	gameplay.add_child(clip)


# Wall along z (constant x) from z0 to z1 with openings [[centre_z, width, bottom, top], ...].
func wall_x(prefix: String, x: float, z0: float, z1: float, h: float, openings: Array) -> void:
	_wall(prefix, true, x, z0, z1, h, openings)


func wall_z(prefix: String, z: float, x0: float, x1: float, h: float, openings: Array) -> void:
	_wall(prefix, false, z, x0, x1, h, openings)


func _wall(prefix: String, along_z: bool, fixed: float, a0: float, a1: float, h: float, openings: Array) -> void:
	var cuts: Array = openings.duplicate()
	cuts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var cursor: float = a0
	var n: int = 0
	for o: Array in cuts:
		var lo: float = float(o[0]) - float(o[1]) * 0.5
		var hi: float = float(o[0]) + float(o[1]) * 0.5
		if lo > cursor:
			_wall_box("%s_%d" % [prefix, n], along_z, fixed, cursor, lo, 0.0, h)
			n += 1
		if float(o[2]) > 0.0:
			_wall_box("%s_%d" % [prefix, n], along_z, fixed, lo, hi, 0.0, float(o[2]))
			n += 1
		_wall_box("%s_%d" % [prefix, n], along_z, fixed, lo, hi, float(o[3]), h)
		n += 1
		cursor = hi
	if cursor < a1:
		_wall_box("%s_%d" % [prefix, n], along_z, fixed, cursor, a1, 0.0, h)


func _wall_box(node_name: String, along_z: bool, fixed: float, a0: float, a1: float, y0: float, y1: float) -> void:
	if a1 - a0 < 0.01 or y1 - y0 < 0.01:
		return
	var mid: float = (a0 + a1) * 0.5
	var c: Vector3 = Vector3(fixed, (y0 + y1) * 0.5, mid) if along_z else Vector3(mid, (y0 + y1) * 0.5, fixed)
	var s: Vector3 = Vector3(0.4, y1 - y0, a1 - a0) if along_z else Vector3(a1 - a0, y1 - y0, 0.4)
	box(node_name, c, s, &"concrete")


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


func buy_door(
	node_name: String,
	pos: Vector3,
	door_id: StringName,
	label: String,
	price: int,
	unlocks: Array[StringName],
	doors: Array[NavDoor]
) -> PurchasableDoor:
	var b: PurchasableDoor = PurchasableDoor.new()
	b.name = node_name
	b.position = pos
	b.door_id = door_id
	b.prompt = "%s (%s)" % [label, door_id]
	b.cost = price
	b.unlocks = unlocks
	b.nav_doors = doors
	gameplay.add_child(b)
	return b


func marker(node_name: String, pos: Vector3) -> Marker3D:
	var m: Marker3D = Marker3D.new()
	m.name = node_name
	m.position = pos
	gameplay.add_child(m)
	return m


func zone(node_name: String, zone_id: StringName, center: Vector3, size: Vector3) -> ZoneVolume:
	var v: ZoneVolume = ZoneVolume.new()
	v.name = node_name
	v.zone = zone_id
	v.position = center
	v.size = size
	gameplay.add_child(v)
	return v


func spawner(node_name: String, pos: Vector3, kind: ZombieSpawner.Kind, zone_id: StringName) -> ZombieSpawner:
	var s: ZombieSpawner = ZombieSpawner.new()
	s.name = node_name
	s.position = pos
	s.kind = kind
	s.zone = zone_id
	gameplay.add_child(s)
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
	env.background_color = Color(0.1, 0.12, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.68)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.6, 0.72)
	env.fog_density = 0.01
	we.environment = env
	add_child(we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50, 30, 0)
	moon.light_color = Color(0.7, 0.78, 1.0)
	moon.light_energy = 0.8
	moon.shadow_enabled = true
	moon.add_to_group(&"shadow_light")
	add_child(moon)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.name = "TungstenLamp"
	lamp.position = Vector3(0, 5, -1)
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 2.0
	lamp.omni_range = 16.0
	add_child(lamp)
