# Gun range (Step 3 test arena): range dummies at 5 / 10 / 20 / 40 m, a killable dummy that
# respawns, a dummy on a moving track (shared clock), a penetration lane with 4 dummies in a row
# 1 m apart, surface test walls (concrete, wood, metal, snow, flesh; wood and metal are thin props
# bullets pass through) and a backstop. Geometry is generated in code; markers named Mark_* give
# tests their firing positions. Players spawn on the firing line facing -Z.
# Authority: dummies are HitTargets (host-authoritative health via TargetRegistry).
extends Node3D

const SURFACE_COLORS: Dictionary = {
	&"concrete": Color(0.46, 0.47, 0.49),
	&"wood": Color(0.55, 0.4, 0.26),
	&"metal": Color(0.42, 0.48, 0.55),
	&"snow": Color(0.88, 0.9, 0.94),
	&"flesh": Color(0.62, 0.32, 0.3),
}
const RANGE_DISTANCES: Array[float] = [5.0, 10.0, 20.0, 40.0]

var dummies: Dictionary = {}  # name -> TargetDummy

var _materials: Dictionary = {}


func _ready() -> void:
	_build_environment()
	box("Ground", Vector3(0, -0.5, -30), Vector3(64, 1, 110), &"concrete")
	box("BoundaryW", Vector3(-32.25, 2, -30), Vector3(0.5, 4, 110), &"concrete")
	box("BoundaryE", Vector3(32.25, 2, -30), Vector3(0.5, 4, 110), &"concrete")
	box("BoundaryN", Vector3(0, 2, 25.25), Vector3(65, 4, 0.5), &"concrete")
	box("Backstop", Vector3(0, 4, -60), Vector3(64, 8, 1), &"concrete")
	box("FiringLine", Vector3(0, 0.02, 0), Vector3(40, 0.04, 0.15), &"metal")
	# Lane A: range dummies (indestructible, show damage numbers with `damage_numbers on`).
	for i: int in RANGE_DISTANCES.size():
		var d: float = RANGE_DISTANCES[i]
		_dummy("Dummy_%02dm" % int(d), Vector3(-3.0 + 2.0 * i, 0, -d), 0.0)
		_sign("%d m" % int(d), Vector3(-3.0 + 2.0 * i, 2.4, -d))
		_marker("Mark_LaneA_%02dm" % int(d), Vector3(-3.0 + 2.0 * i, 0.05, 0.0))
	# Killable dummy: 150 HP (one knife hit), respawns after 3 s.
	_dummy("Dummy_Kill", Vector3(-7, 0, -8), 150.0)
	_sign("150 HP", Vector3(-7, 2.4, -8))
	_marker("Mark_Kill", Vector3(-7, 0.05, 0.0))
	# Moving dummy on a 6 m track (6 s period), driven by the host clock.
	var mover: TargetDummy = _dummy("Dummy_Moving", Vector3(6, 0, -15), 0.0)
	mover.track_offset = Vector3(6, 0, 0)
	mover.track_period = 6.0
	box("Track", Vector3(9, 0.02, -15), Vector3(7, 0.04, 0.3), &"metal")
	_marker("Mark_Moving", Vector3(9, 0.05, 0.0))
	# Penetration lane: 4 dummies in a row, 1 m apart.
	for i: int in 4:
		_dummy("Pen_%d" % (i + 1), Vector3(-14, 0, -10.0 - i), 0.0)
	_sign("PENETRATION", Vector3(-14, 2.6, -9.5))
	_marker("Mark_Pen", Vector3(-14, 0.05, 0.0))
	# Surface walls (wood + metal are thin props: bullets pass through with 25% loss).
	var surfaces: Array[StringName] = [&"concrete", &"wood", &"metal", &"snow", &"flesh"]
	for i: int in surfaces.size():
		var s: StringName = surfaces[i]
		var thin: bool = s == &"wood" or s == &"metal"
		var wall: StaticBody3D = box(
			"Wall_%s" % s, Vector3(16.0 + 3.0 * i, 1.5, -12.0), Vector3(2.4, 3.0, 0.06 if thin else 0.4), s
		)
		if thin:
			wall.set_meta(&"thin_prop", true)
		_sign(String(s).to_upper(), Vector3(16.0 + 3.0 * i, 3.4, -12.0))
	_dummy("Dummy_BehindWood", Vector3(19, 0, -14), 0.0)
	_marker("Mark_Walls", Vector3(22, 0.05, 0.0))
	for i: int in 4:
		var m: Marker3D = Marker3D.new()
		m.name = "PlayerSpawn%d" % i
		m.position = Vector3(-1.5 + 1.0 * i, 0.05, 2.0)
		m.add_to_group(&"player_spawn")
		add_child(m)
	_shot("ShotA_Range", Vector3(0, 2.2, 3.5), Vector3(0, 1.2, -20))
	_shot("ShotB_Overview", Vector3(-22, 14, 12), Vector3(2, 0, -18))
	_shot("ShotC_Walls", Vector3(22, 2.0, -4), Vector3(22, 1.5, -12))


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
	add_child(body)
	return body


func _mat(surface: StringName) -> StandardMaterial3D:
	if not _materials.has(surface):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = SURFACE_COLORS.get(surface, Color(0.5, 0.5, 0.5))
		m.roughness = 0.85
		_materials[surface] = m
	return _materials[surface]


func _dummy(node_name: String, pos: Vector3, hp: float) -> TargetDummy:
	var d: TargetDummy = TargetDummy.new()
	d.name = node_name
	d.position = pos
	d.max_health = hp
	add_child(d)
	dummies[node_name] = d
	return d


func _marker(node_name: String, pos: Vector3) -> void:
	var m: Marker3D = Marker3D.new()
	m.name = node_name
	m.position = pos
	add_child(m)


func _sign(text: String, pos: Vector3) -> void:
	var l: Label3D = Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = 64
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(l)


func _shot(node_name: String, from: Vector3, at: Vector3) -> void:
	var cam: Camera3D = Camera3D.new()
	cam.name = node_name
	add_child(cam)
	cam.look_at_from_position(from, at)
	cam.add_to_group(&"screenshot_shot")


func _build_environment() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.42, 0.58)
	sky_mat.sky_horizon_color = Color(0.7, 0.72, 0.76)
	sky_mat.ground_horizon_color = Color(0.7, 0.72, 0.76)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
