# Movement course (Step 2 test arena): sprint lane with timing gates, stairs of several rises
# (0.15 / 0.30 / 0.35 m), 20° / 30° / 45° ramps (plus an unwalkable 50° one), 1.0 / 1.2 m
# mantle ledges and a 1.5 m ledge that must NOT be mantled, a 0.8 m gap, a doorway, a slide tunnel
# with a 1.3 m ceiling, a call elevator (vertical moving platform) to a 10 m deck with a 5 m shelf
# below it (5 m and 10 m drops) and a horizontal shuttle platform beside the start.
# Geometry is generated in code so the route and the bot waypoints stay in one place.
# Waypoints: Marker3D in group "course_waypoint", named WPnn_*, with metadata for BotInputDriver.
# Authority: the elevator / shuttle move on every peer from the shared clock (presentation-level
# platforms; Step 8 makes traversal machines host-driven).
extends Node3D

const SURFACE_COLORS: Dictionary = {
	&"concrete": Color(0.46, 0.47, 0.49),
	&"wood": Color(0.55, 0.4, 0.26),
	&"metal": Color(0.42, 0.48, 0.55),
	&"gravel": Color(0.5, 0.47, 0.42),
	&"tile": Color(0.62, 0.64, 0.6),
	&"snow": Color(0.86, 0.88, 0.92),
}
const ELEVATOR_BOTTOM: float = 0.15
const ELEVATOR_TOP: float = 9.85
const ELEVATOR_SPEED: float = 2.5
const ELEVATOR_DWELL: float = 2.0
const SHUTTLE_SPAN: float = 6.0
const SHUTTLE_PERIOD: float = 8.0

var gate_times: Array[float] = []
var last_lap: float = -1.0
var elevator: AnimatableBody3D = null
var shuttle: AnimatableBody3D = null

var _materials: Dictionary = {}
var _physics_materials: Dictionary = {}
var _wp_count: int = 0
var _elevator_state: int = 0  # 0 idle bottom, 1 rising, 2 dwell top, 3 descending
var _elevator_timer: float = 0.0
var _elevator_riders: int = 0
var _elevator_blocked: int = 0  # bodies under the descending platform (safety stop)
var _shuttle_t: float = 0.0
var _gate_label: Label3D = null


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_sprint_lane()
	_build_stairs_and_ramps()
	_build_mantles()
	_build_gap_door_tunnel()
	_build_elevator_tower()
	_build_shuttle()
	_build_spawns_and_cameras()


func _physics_process(delta: float) -> void:
	_update_elevator(delta)
	_shuttle_t += delta
	var x: float = -10.0 - SHUTTLE_SPAN * 0.5 * (1.0 - cos(TAU * _shuttle_t / SHUTTLE_PERIOD))
	shuttle.position = Vector3(x, 0.15, -8.0)


# --- builders ---------------------------------------------------------------------------------


func _mat(surface: StringName) -> StandardMaterial3D:
	if not _materials.has(surface):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = SURFACE_COLORS.get(surface, Color(0.5, 0.5, 0.5))
		m.roughness = 0.85
		_materials[surface] = m
		_physics_materials[surface] = SurfaceTags.make_material(surface)
	return _materials[surface]


func box(
	node_name: String, center: Vector3, size: Vector3, surface: StringName = &"concrete", rot_x: float = 0.0
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.rotation.x = rot_x
	body.collision_layer = 1
	body.collision_mask = 0
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = _mat(surface)
	body.physics_material_override = _physics_materials[surface]
	body.add_child(mesh)
	var col: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	col.shape = bs
	body.add_child(col)
	add_child(body)
	return body


# Solid box resting on the ground: x/z centre, footprint, height.
func block(node_name: String, x: float, z0: float, z1: float, width: float, height: float, surface: StringName) -> void:
	box(node_name, Vector3(x, height * 0.5, (z0 + z1) * 0.5), Vector3(width, height, absf(z1 - z0)), surface)


# Ramp whose top surface runs from (z0, y0) to (z1, y1) (z1 < z0 = further down the course).
func ramp(
	node_name: String, x: float, z0: float, y0: float, z1: float, y1: float, width: float, surface: StringName
) -> void:
	var run: float = absf(z1 - z0)
	var rise: float = y1 - y0
	var angle: float = atan2(rise, run)
	var length: float = sqrt(run * run + rise * rise)
	var th: float = 0.3
	var mid: Vector3 = Vector3(x, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	var normal: Vector3 = Vector3(0.0, cos(angle), sin(angle))
	box(node_name, mid - normal * th * 0.5, Vector3(width, th, length), surface, angle)


func waypoint(
	label: String, pos: Vector3, action: StringName = &"walk", radius: float = 0.6, until_y: float = 0.0
) -> void:
	var m: Marker3D = Marker3D.new()
	m.name = "WP%02d_%s" % [_wp_count, label]
	_wp_count += 1
	m.position = pos
	m.set_meta(&"action", action)
	m.set_meta(&"radius", radius)
	m.set_meta(&"until_y", until_y)
	m.add_to_group(&"course_waypoint")
	add_child(m)


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


func _build_ground() -> void:
	box("Ground", Vector3(0.0, -0.5, -55.0), Vector3(44.0, 1.0, 140.0), &"concrete")
	# Perimeter walls keep players (and random-input bots) on the course.
	box("BoundaryW", Vector3(-22.25, 2.0, -55.0), Vector3(0.5, 4.0, 140.0), &"concrete")
	box("BoundaryE", Vector3(22.25, 2.0, -55.0), Vector3(0.5, 4.0, 140.0), &"concrete")
	box("BoundaryN", Vector3(0.0, 2.0, 15.25), Vector3(45.0, 4.0, 0.5), &"concrete")
	box("BoundaryS", Vector3(0.0, 2.0, -125.25), Vector3(45.0, 4.0, 0.5), &"concrete")


func _build_sprint_lane() -> void:
	for i: int in 2:
		var z: float = -2.0 - 20.0 * i
		var gate: Area3D = Area3D.new()
		gate.name = "SprintGate%d" % i
		gate.position = Vector3(0.0, 1.0, z)
		gate.collision_layer = 1 << 6  # trigger
		gate.collision_mask = 1 << 1  # player
		var col: CollisionShape3D = CollisionShape3D.new()
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = Vector3(8.0, 2.0, 0.2)
		col.shape = bs
		gate.add_child(col)
		gate.body_entered.connect(_on_gate.bind(i))
		add_child(gate)
		box("GatePostL%d" % i, Vector3(-4.2, 1.25, z), Vector3(0.2, 2.5, 0.2), &"metal")
		box("GatePostR%d" % i, Vector3(4.2, 1.25, z), Vector3(0.2, 2.5, 0.2), &"metal")
	_gate_label = Label3D.new()
	_gate_label.text = "20 m sprint lane"
	_gate_label.position = Vector3(0.0, 3.0, -2.0)
	_gate_label.font_size = 64
	add_child(_gate_label)
	waypoint("Start", Vector3(0.0, 0.0, -0.5))
	waypoint("SprintLaneEnd", Vector3(0.0, 0.0, -23.0), &"sprint")


func _build_stairs_and_ramps() -> void:
	# Stairs A: 8 × 0.15 m up, landing 1.2 m, 3 × 0.30 m down.
	for i: int in 8:
		block("StairA_Up%d" % i, 0.0, -24.0 - 0.3 * i, -24.3 - 0.3 * i, 6.0, 0.15 * (i + 1), &"wood")
	block("StairA_Landing", 0.0, -26.4, -29.4, 6.0, 1.2, &"wood")
	for i: int in 3:
		block("StairA_Down%d" % i, 0.0, -29.4 - 0.3 * i, -29.7 - 0.3 * i, 6.0, 0.9 - 0.3 * i, &"wood")
	waypoint("StairsA_Landing", Vector3(0.0, 1.2, -28.0))
	waypoint("StairsA_Bottom", Vector3(0.0, 0.0, -31.0))
	# Stairs B: 4 × 0.35 m (maximum step height) up, landing 1.4 m, 20° ramp down.
	for i: int in 4:
		block("StairB_Up%d" % i, 0.0, -32.0 - 0.3 * i, -32.3 - 0.3 * i, 6.0, 0.35 * (i + 1), &"metal")
	block("StairB_Landing", 0.0, -33.2, -36.2, 6.0, 1.4, &"metal")
	ramp("Ramp20_Down", 0.0, -36.2, 1.4, -36.2 - 1.4 / tan(deg_to_rad(20.0)), 0.0, 6.0, &"metal")
	waypoint("StairsB_Landing", Vector3(0.0, 1.4, -34.7))
	waypoint("Ramp20_Bottom", Vector3(0.0, 0.0, -41.5))
	# 30° up to a 2 m deck, 45° down.
	var r30: float = 2.0 / tan(deg_to_rad(30.0))
	ramp("Ramp30_Up", 0.0, -43.0, 0.0, -43.0 - r30, 2.0, 6.0, &"gravel")
	block("RampDeck", 0.0, -43.0 - r30, -48.5, 6.0, 2.0, &"gravel")
	ramp("Ramp45_Down", 0.0, -48.5, 2.0, -50.5, 0.0, 6.0, &"gravel")
	waypoint("RampDeck", Vector3(0.0, 2.0, -47.5))
	waypoint("Ramp45_Bottom", Vector3(0.0, 0.0, -52.0))
	# Side area: a 1.5 m ceiling you cannot stand up under (AC-2.6).
	box("LowCeiling_1_5m", Vector3(-10.0, 1.75, -30.0), Vector3(4.0, 0.5, 4.0), &"concrete")
	box("LowCeilingPost", Vector3(-11.8, 0.75, -31.8), Vector3(0.3, 1.5, 0.3), &"concrete")
	# Side lane: an unwalkable 50° ramp (slides back) for the human feel review.
	ramp("Ramp50_Side", 12.0, -40.0, 0.0, -40.0 - 2.0 / tan(deg_to_rad(50.0)), 2.0, 3.0, &"gravel")


func _build_mantles() -> void:
	block("Ledge_1_0m", 0.0, -54.0, -56.0, 12.0, 1.0, &"wood")
	waypoint("Mantle_1_0m", Vector3(0.0, 1.0, -55.0), &"mantle")
	waypoint("Mantle_1_0m_Off", Vector3(0.0, 0.0, -57.5))
	block("Ledge_1_2m", 0.0, -59.0, -61.0, 12.0, 1.2, &"wood")
	waypoint("Mantle_1_2m", Vector3(0.0, 1.2, -60.0), &"mantle")
	# Side lane: 1.5 m ledge, too high to mantle (AC check).
	block("Ledge_1_5m", 10.0, -54.0, -56.0, 3.0, 1.5, &"wood")
	var m: Marker3D = Marker3D.new()
	m.name = "Ledge_1_5m_Approach"
	m.position = Vector3(10.0, 0.0, -52.5)
	m.add_to_group(&"course_marker")
	add_child(m)


func _build_gap_door_tunnel() -> void:
	# 0.8 m gap in a 3 m wall.
	box("GapWallL", Vector3(-7.7, 1.5, -65.0), Vector3(14.6, 3.0, 0.3), &"concrete")
	box("GapWallR", Vector3(7.7, 1.5, -65.0), Vector3(14.6, 3.0, 0.3), &"concrete")
	waypoint("Gap_Approach", Vector3(0.0, 0.0, -63.0), &"walk", 0.25)
	waypoint("Gap_Through", Vector3(0.0, 0.0, -67.5), &"walk", 0.3)
	# Doorway 1.0 × 2.1 m.
	box("DoorWallL", Vector3(-7.75, 1.5, -70.0), Vector3(14.5, 3.0, 0.3), &"concrete")
	box("DoorWallR", Vector3(7.75, 1.5, -70.0), Vector3(14.5, 3.0, 0.3), &"concrete")
	box("DoorLintel", Vector3(0.0, 2.55, -70.0), Vector3(1.0, 0.9, 0.3), &"concrete")
	waypoint("Door_Through", Vector3(0.0, 0.0, -71.5), &"walk", 0.3)
	# Slide tunnel: 2 m wide, 1.3 m ceiling, 6 m long.
	box("TunnelCeiling", Vector3(0.0, 1.55, -80.0), Vector3(2.6, 0.5, 6.0), &"tile")
	box("TunnelWallL", Vector3(-1.15, 0.65, -80.0), Vector3(0.3, 1.3, 6.0), &"tile")
	box("TunnelWallR", Vector3(1.15, 0.65, -80.0), Vector3(0.3, 1.3, 6.0), &"tile")
	box("TunnelFloor", Vector3(0.0, -0.005, -80.0), Vector3(2.0, 0.01, 6.0), &"tile")
	waypoint("Slide_Start", Vector3(0.0, 0.0, -76.4), &"slide", 0.6)
	waypoint("Tunnel_Exit", Vector3(0.0, 0.0, -86.0))


func _build_elevator_tower() -> void:
	elevator = AnimatableBody3D.new()
	elevator.name = "Elevator"
	elevator.sync_to_physics = true
	elevator.position = Vector3(0.0, ELEVATOR_BOTTOM, -91.5)
	elevator.collision_layer = 1
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(3.0, 0.3, 3.0)
	mesh.mesh = bm
	mesh.material_override = _mat(&"metal")
	elevator.physics_material_override = _physics_materials[&"metal"]
	elevator.add_child(mesh)
	var col: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(3.0, 0.3, 3.0)
	col.shape = bs
	elevator.add_child(col)
	var sensor: Area3D = Area3D.new()
	sensor.name = "RiderSensor"
	sensor.position = Vector3(0.0, 0.6, 0.0)
	sensor.collision_layer = 1 << 6
	sensor.collision_mask = 1 << 1
	var scol: CollisionShape3D = CollisionShape3D.new()
	var sbs: BoxShape3D = BoxShape3D.new()
	sbs.size = Vector3(2.6, 0.9, 2.6)
	scol.shape = sbs
	sensor.add_child(scol)
	sensor.body_entered.connect(func(_b: Node3D) -> void: _elevator_riders += 1)
	sensor.body_exited.connect(func(_b: Node3D) -> void: _elevator_riders = maxi(_elevator_riders - 1, 0))
	elevator.add_child(sensor)
	# Safety sensor under the platform: it never descends onto a player.
	var below: Area3D = Area3D.new()
	below.name = "UnderSensor"
	below.position = Vector3(0.0, -1.2, 0.0)
	below.collision_layer = 1 << 6
	below.collision_mask = 1 << 1
	var bcol: CollisionShape3D = CollisionShape3D.new()
	var bbs: BoxShape3D = BoxShape3D.new()
	bbs.size = Vector3(3.4, 2.1, 3.4)
	bcol.shape = bbs
	below.add_child(bcol)
	below.body_entered.connect(func(_b: Node3D) -> void: _elevator_blocked += 1)
	below.body_exited.connect(func(_b: Node3D) -> void: _elevator_blocked = maxi(_elevator_blocked - 1, 0))
	elevator.add_child(below)
	add_child(elevator)
	waypoint("Elevator_Ride", Vector3(0.0, 0.3, -91.5), &"ride", 0.6, 10.0)
	# 10 m deck (thin slab, so its open sides are a 10 m drop) and a 5 m shelf beyond it.
	box("TowerDeck", Vector3(0.0, 9.75, -96.5), Vector3(8.0, 0.5, 7.0), &"metal")
	box("TowerRailL", Vector3(-4.05, 10.5, -96.5), Vector3(0.1, 1.0, 7.0), &"metal")
	block("Shelf_5m", 0.0, -100.0, -105.0, 8.0, 5.0, &"snow")
	waypoint("Tower_Deck", Vector3(0.0, 10.0, -97.0))
	waypoint("Drop5_Shelf", Vector3(0.0, 5.0, -102.5))
	waypoint("Drop5_Ground", Vector3(0.0, 0.0, -108.0))
	waypoint("Finish", Vector3(0.0, 0.0, -110.0))
	var label: Label3D = Label3D.new()
	label.text = "10 m drop →"
	label.position = Vector3(3.5, 11.2, -96.5)
	label.font_size = 48
	add_child(label)


func _build_shuttle() -> void:
	shuttle = AnimatableBody3D.new()
	shuttle.name = "Shuttle"
	shuttle.sync_to_physics = true
	shuttle.position = Vector3(-10.0, 0.15, -8.0)
	shuttle.collision_layer = 1
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(3.0, 0.3, 3.0)
	mesh.mesh = bm
	mesh.material_override = _mat(&"metal")
	shuttle.physics_material_override = _physics_materials[&"metal"]
	shuttle.add_child(mesh)
	var col: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(3.0, 0.3, 3.0)
	col.shape = bs
	shuttle.add_child(col)
	add_child(shuttle)


func _build_spawns_and_cameras() -> void:
	for i: int in 4:
		var m: Marker3D = Marker3D.new()
		m.name = "PlayerSpawn%d" % i
		m.position = Vector3(-2.25 + 1.5 * i, 0.05, 2.0)
		m.add_to_group(&"player_spawn")
		add_child(m)
	_shot("ShotA_Overview", Vector3(26.0, 20.0, -30.0), Vector3(0.0, 1.0, -58.0))
	_shot("ShotB_StartLane", Vector3(0.0, 2.2, 5.0), Vector3(0.0, 1.0, -25.0))
	_shot("ShotC_Tower", Vector3(-16.0, 12.0, -78.0), Vector3(0.0, 5.0, -98.0))


func _shot(node_name: String, from: Vector3, at: Vector3) -> void:
	var cam: Camera3D = Camera3D.new()
	cam.name = node_name
	add_child(cam)
	cam.look_at_from_position(from, at)
	cam.add_to_group(&"screenshot_shot")


# --- moving parts -----------------------------------------------------------------------------


func elevator_height() -> float:
	return elevator.position.y + 0.15


func _update_elevator(delta: float) -> void:
	var y: float = elevator.position.y
	match _elevator_state:
		0:
			if _elevator_riders > 0:
				_elevator_timer += delta
				if _elevator_timer > 0.5:
					_elevator_state = 1
			else:
				_elevator_timer = 0.0
		1:
			y = move_toward(y, ELEVATOR_TOP, ELEVATOR_SPEED * delta)
			if y >= ELEVATOR_TOP:
				_elevator_state = 2
				_elevator_timer = 0.0
		2:
			_elevator_timer += delta
			if _elevator_timer > ELEVATOR_DWELL and _elevator_riders == 0:
				_elevator_state = 3
		3:
			if _elevator_blocked == 0:
				y = move_toward(y, ELEVATOR_BOTTOM, ELEVATOR_SPEED * delta)
			if y <= ELEVATOR_BOTTOM:
				_elevator_state = 0
				_elevator_timer = 0.0
	elevator.position.y = y


func _on_gate(_body: Node3D, gate: int) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if gate == 0:
		gate_times = [now]
	elif gate_times.size() == 1:
		last_lap = now - gate_times[0]
		gate_times.clear()
		_gate_label.text = "20 m: %.2f s (%.2f m/s)" % [last_lap, 20.0 / last_lap]
		Log.info(&"course", "Sprint lane 20 m in %.2f s" % last_lap)
