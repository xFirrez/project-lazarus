# Generates game/maps/_test/lookdev.tscn (Step 4B look-dev scene) from the scripted kit and props:
# a 30 x 28 m corner of the Frozen Courtyard in front of the sanatorium façade, plus one lobby
# corner behind it with a perk-machine-sized placeholder. Run: tools/lookdev/build_lookdev.sh
# The output is a normal editable scene (kit pieces and props are scene instances). Once an artist
# has hand-edited lookdev.tscn, edit it in the editor instead of re-running this generator.
extends SceneTree

const KIT: String = "res://content/kits/vesper/"
const PROPS: String = "res://content/props/"
const OUT: String = "res://maps/_test/lookdev.tscn"
const ZOMBIES: String = "res://content/enemies/zombie/"

var scene_root: Node3D = null


func _initialize() -> void:
	scene_root = Node3D.new()
	scene_root.name = "Lookdev"
	scene_root.set_script(load("res://maps/_test/lookdev.gd"))
	var geo: Node3D = _group(scene_root, "Geometry")
	var props: Node3D = _group(scene_root, "Props")
	var lights: Node3D = _group(scene_root, "Lights")
	var fx: Node3D = _group(scene_root, "Atmosphere")
	var gp: Node3D = _group(scene_root, "Gameplay")
	var shots: Node3D = _group(scene_root, "Shots")
	_environment(fx)
	_courtyard(geo)
	_facade(geo)
	_lobby(geo, props)
	_courtyard_props(props)
	_backdrop(geo)
	_lights(lights)
	_zombies(props)
	_gameplay(gp)
	_shots(shots)
	var packed: PackedScene = PackedScene.new()
	var err: Error = packed.pack(scene_root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("[lookdev] saved %s: %s (%d nodes)" % [OUT, error_string(err), _count(scene_root)])
	scene_root.free()
	quit(0 if err == OK else 1)


# --- helpers ---------------------------------------------------------------------------------


func _own(n: Node) -> void:
	n.owner = scene_root


func _group(parent: Node, n: String) -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = n
	parent.add_child(g)
	_own(g)
	return g


func _inst(parent: Node, path: String, n: String, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var node: Node3D = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	node.name = n
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	parent.add_child(node)
	_own(node)
	return node


func _kit(parent: Node, piece: String, n: String, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	return _inst(parent, KIT + piece + ".glb", n, pos, yaw_deg)


func _prop(parent: Node, prop: String, n: String, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	return _inst(parent, PROPS + prop + "/" + prop + ".glb", n, pos, yaw_deg)


func _mesh_of(path: String) -> Mesh:
	var s: Node = (load(path) as PackedScene).instantiate()
	var mi: MeshInstance3D = s.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var m: Mesh = mi.mesh
	s.free()
	return m


# One MultiMesh (one draw call per material) for a grid of identical tiles + one box collider.
# `cells` = Rect2i(x0, z0, x1, z1) of tile centres (inclusive, 2 m steps).
func _tiles(
	parent: Node, piece: String, n: String, cells: Rect2i, y: float, surface: String, flip: bool = false
) -> void:
	var x0: int = cells.position.x
	var z0: int = cells.position.y
	var x1: int = cells.size.x
	var z1: int = cells.size.y
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh_of(KIT + piece + ".glb")
	var xs: Array[int] = []
	var zs: Array[int] = []
	for x: int in range(x0, x1 + 1, 2):
		xs.append(x)
	for z: int in range(z0, z1 + 1, 2):
		zs.append(z)
	mm.instance_count = xs.size() * zs.size()
	var i: int = 0
	for x: int in xs:
		for z: int in zs:
			# flipped tiles (ceilings) face down: slab spans y .. y + 0.2
			var b: Basis = Basis(Vector3.RIGHT, PI) if flip else Basis.IDENTITY
			mm.set_instance_transform(i, Transform3D(b, Vector3(x, y, z)))
			i += 1
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	parent.add_child(mmi)
	_own(mmi)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = n + "_Collision"
	body.set_meta(&"surface", StringName(surface))
	parent.add_child(body)
	_own(body)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(x1 - x0 + 2, 0.2, z1 - z0 + 2)
	cs.shape = box
	cs.position = Vector3((x0 + x1) * 0.5, y + (0.1 if flip else -0.1), (z0 + z1) * 0.5)
	body.add_child(cs)
	_own(cs)


func _prim(
	parent: Node, n: String, mesh: Mesh, mat_id: String, pos: Vector3, scl: Vector3 = Vector3.ONE
) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = load("res://content/materials/%s.tres" % mat_id) as Material
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	_own(mi)
	return mi


func _emitter() -> Node3D:
	var e: Node3D = Node3D.new()
	e.set_script(load("res://core/audio/ambience_emitter.gd"))
	return e


func _count(n: Node) -> int:
	var c: int = 1
	for ch: Node in n.get_children():
		c += _count(ch)
	return c


# --- layout ----------------------------------------------------------------------------------


func _environment(parent: Node) -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = load("res://content/environments/exterior_storm.tres") as Environment
	parent.add_child(we)
	_own(we)
	# (scripts are attached by path: classes that use autoloads can't be referenced statically
	# from a -s tool script, which compiles before the autoloads exist)
	var snow: GPUParticles3D = GPUParticles3D.new()
	snow.set_script(load("res://core/vfx/camera_snow.gd"))
	snow.name = "CameraSnow"
	parent.add_child(snow)
	_own(snow)
	var wind: Node3D = _emitter()
	wind.name = "StormWind"
	wind.set(&"event", &"amb_storm_wind")
	wind.set(&"volume_db", -10.0)
	parent.add_child(wind)
	_own(wind)
	var room: Node3D = _emitter()
	room.name = "LobbyRoomTone"
	room.set(&"event", &"amb_room_tone")
	room.set(&"spatial", true)
	room.position = Vector3(-7, 2, -16)
	parent.add_child(room)
	_own(room)
	# Interior: carve the storm fog out of the lobby and fill it with a warm dusty haze.
	var fv: FogVolume = FogVolume.new()
	fv.name = "LobbyHaze"
	fv.size = Vector3(14, 4.2, 8)
	fv.position = Vector3(-7, 2.1, -16)
	var fm: FogMaterial = FogMaterial.new()
	fm.density = -0.025
	fm.albedo = Color(0.9, 0.75, 0.55)
	fm.edge_fade = 0.3
	fv.material = fm
	parent.add_child(fv)
	_own(fv)


func _courtyard(geo: Node) -> void:
	_tiles(geo, "floor_2m_exterior", "CourtyardGround", Rect2i(-14, -11, 14, 15), 0.0, "snow")
	# east terrace edge: railings between pillars, the drop beyond
	for z: int in range(-10, 16, 2):
		_kit(geo, "railing_2m", "Railing_E_%d" % z, Vector3(15, 0, z), 90.0)
	for z: int in range(-12, 17, 4):
		_kit(geo, "pillar_corner", "Pillar_E_%d" % z, Vector3(15, 0, z)).scale = Vector3(1, 0.3, 1)
	# snow drifts against the façade and pillars (they also guide the eye along the loop)
	var drift: SphereMesh = SphereMesh.new()
	drift.radial_segments = 24
	drift.rings = 8
	var drifts: Array[Vector4] = [
		Vector4(-11, -11.2, 3.0, 1.2),
		Vector4(-4.5, -11.1, 2.2, 1.0),
		Vector4(6, -11.3, 3.5, 1.3),
		Vector4(11, -11.0, 2.0, 0.9),
		Vector4(14, 4, 1.4, 3.0),
		Vector4(-13.8, 9, 1.6, 2.6),
	]
	for i: int in drifts.size():
		var d: Vector4 = drifts[i]
		_prim(geo, "SnowDrift_%d" % i, drift, "cobble_snow", Vector3(d.x, -0.3, d.y), Vector3(d.z, 1.1, d.w))


func _facade(geo: Node) -> void:
	var f: Node3D = _group(geo, "Facade")
	var lit_ground: Array[int] = [-13, -9, -5, 3, 7, 11]
	var lit_upper: Array[int] = [-11, -7, 1, 9]
	for x: int in range(-13, 12, 2):
		for storey: int in 2:
			var y: float = storey * 4.0
			if storey == 0 and x == -1:
				continue  # entrance to the lobby
			var window: bool = storey == 1 or (x + 13) % 4 == 0
			if window:
				_kit(f, "wall_window_2m_exterior", "WallWin_%d_%d" % [x, storey], Vector3(x, y, -12))
				var lit: bool = (lit_ground if storey == 0 else lit_upper).has(x)
				_kit(
					f,
					"window_glass_2m" if lit else "window_glass_2m_frosted",
					"Glass_%d_%d" % [x, storey],
					Vector3(x, y, -12)
				)
			else:
				_kit(f, "wall_2m_exterior", "Wall_%d_%d" % [x, storey], Vector3(x, y, -12))
	for x: int in [-14, -10, -6, -2, 0, 4, 8, 12]:
		for storey: int in 2:
			_kit(f, "pillar_corner", "Pilaster_%d_%d" % [x, storey], Vector3(x, storey * 4.0, -11.85))
	# roof slab with its snow cap and a crown moulding along the eave
	_tiles(f, "floor_2m_exterior", "Roof", Rect2i(-13, -13, 11, -13), 8.2, "snow")
	for x: int in range(-13, 12, 2):
		_kit(f, "trim_crown_2m", "Eave_%d" % x, Vector3(x, 8.0, -11.8))
	# entrance steps
	var step: BoxMesh = BoxMesh.new()
	step.size = Vector3(2.6, 0.12, 0.5)
	for k: int in 2:
		_prim(f, "EntranceStep_%d" % k, step, "stone_facade", Vector3(-1, 0.06 - k * 0.02, -11.5 + k * 0.5))


func _lobby(geo: Node, props: Node) -> void:
	var l: Node3D = _group(geo, "LobbyCorner")
	_tiles(l, "floor_2m", "LobbyFloor", Rect2i(-13, -19, -1, -13), 0.01, "tile")
	_tiles(l, "floor_2m", "LobbyCeiling", Rect2i(-13, -19, -1, -13), 4.0, "concrete", true)
	# interior reflections/ambient come from a baked-once probe, not the storm sky
	var probe: ReflectionProbe = ReflectionProbe.new()
	probe.name = "LobbyProbe"
	probe.size = Vector3(14, 4.2, 8)
	probe.position = Vector3(-7, 2.1, -16)
	probe.interior = true
	probe.box_projection = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color(0.32, 0.22, 0.15)
	probe.ambient_color_energy = 0.6
	l.add_child(probe)
	_own(probe)
	for z: int in range(-19, -12, 2):
		_kit(l, "wall_window_2m" if z == -15 else "wall_2m", "Wall_W_%d" % z, Vector3(-14, 0, z), 90.0)
		_kit(l, "wall_door_2m" if z == -17 else "wall_2m", "Wall_E_%d" % z, Vector3(0, 0, z), 90.0)
	for x: int in range(-13, 0, 2):
		_kit(l, "wall_2m", "Wall_N_%d" % x, Vector3(x, 0, -20))
	_kit(l, "pillar_corner", "Corner_NW", Vector3(-14, 0, -20))
	_kit(l, "pillar_corner", "Corner_NE", Vector3(0, 0, -20))
	# side stair up to a half landing (mezzanine stub) with a railing
	_kit(l, "stairs_2m", "Stairs", Vector3(-4, 0, -13.0), 0.0)
	_tiles(l, "floor_2m", "Landing", Rect2i(-4, -18, -4, -18), 2.0, "wood")
	_kit(l, "railing_2m", "LandingRail", Vector3(-5, 2.0, -18), 90.0)
	for z: int in range(-19, -12, 2):
		_kit(l, "pipe_2m", "Pipe_%d" % z, Vector3(-13.6, 3.7, z), 90.0)
	_prop(props, "machine_placeholder", "MachinePlaceholder", Vector3(-11, 0, -19.4))
	_prop(props, "supply_crate", "LobbyCrate", Vector3(-7.5, 0, -19.3), 8.0)


func _courtyard_props(props: Node) -> void:
	_prop(props, "fountain_frozen", "Fountain", Vector3(2, 0, 2))
	_prop(props, "truck_cargo", "Truck", Vector3(-9.5, 0, 6), 78.0)
	_prop(props, "fuel_drum", "Drum_1", Vector3(-12.2, 0, 1.0))
	_prop(props, "fuel_drum", "Drum_2", Vector3(-11.5, 0, 1.6), 40.0)
	_prop(props, "fuel_drum", "Drum_3", Vector3(-12.6, 0, 1.9), 75.0)
	_prop(props, "supply_crate", "Crate_1", Vector3(10.5, 0, 10.5), 12.0)
	_prop(props, "supply_crate", "Crate_2", Vector3(10.8, 0.6, 10.4), -6.0)
	_prop(props, "sandbag_wall", "Sandbags_1", Vector3(8, 0, 8.5), 25.0)
	_prop(props, "sandbag_wall", "Sandbags_2", Vector3(-2.5, 0, 12.5), -10.0)
	_prop(props, "lamp_post", "LampPost_1", Vector3(-5, 0, -7.5))
	_prop(props, "lamp_post", "LampPost_2", Vector3(9, 0, -7.5))


func _backdrop(geo: Node) -> void:
	var b: Node3D = _group(geo, "Backdrop")
	var box: BoxMesh = BoxMesh.new()
	# mountain wall silhouettes behind the sanatorium, swallowed by fog
	var cliffs: Array[Vector4] = [
		Vector4(-30, -70, 60, 45), Vector4(25, -80, 70, 60), Vector4(-70, -40, 40, 35), Vector4(60, -30, 30, 28)
	]
	for i: int in cliffs.size():
		var c: Vector4 = cliffs[i]
		var m: MeshInstance3D = _prim(
			b, "Cliff_%d" % i, box, "stone_facade", Vector3(c.x, c.w * 0.5, c.y), Vector3(c.z, c.w, 20)
		)
		m.rotation_degrees.y = 12.0 * (i - 1.5)
	# radar tower (Z07 landmark, VESPER_PEAK §8.2): lattice mast with a dish and a red beacon
	var t: Node3D = _group(b, "RadarTower")
	t.position = Vector3(-18, 6, -48)
	var leg: BoxMesh = BoxMesh.new()
	leg.size = Vector3(0.35, 34, 0.35)
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			var lm: MeshInstance3D = _prim(
				t, "Leg_%d_%d" % [sx, sz], leg, "metal_dark", Vector3(sx * 2.2, 17, sz * 2.2)
			)
			lm.rotation_degrees = Vector3(sz * -3.5, 0, sx * 3.5)
	var brace: BoxMesh = BoxMesh.new()
	brace.size = Vector3(4.6, 0.2, 0.2)
	for k: int in 8:
		var y: float = 2.0 + k * 4.0
		var w: float = 1.0 - y / 80.0
		for sz: int in [-1, 1]:
			_prim(t, "Brace_%d_%d" % [k, sz], brace, "metal_dark", Vector3(0, y, sz * 2.2 * w), Vector3(w, 1, 1))
	var dish: CylinderMesh = CylinderMesh.new()
	dish.top_radius = 3.2
	dish.bottom_radius = 0.6
	dish.height = 1.2
	var d: MeshInstance3D = _prim(t, "Dish", dish, "metal_olive", Vector3(0, 34.5, 0))
	d.rotation_degrees = Vector3(70, 30, 0)
	var bulb: SphereMesh = SphereMesh.new()
	bulb.radius = 0.35
	bulb.height = 0.7
	_prim(t, "BeaconBulb", bulb, "emissive_red", Vector3(0, 36.4, 0))


func _light(
	parent: Node, l: Light3D, n: String, pos: Vector3, color: Color, energy: float, shadow: bool, prio: float
) -> Light3D:
	l.name = n
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.shadow_enabled = shadow
	if shadow:
		l.add_to_group(&"shadow_light", true)
		l.set_meta(&"shadow_priority", prio)
	parent.add_child(l)
	_own(l)
	return l


func _lights(parent: Node) -> void:
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.74, 1.0)
	moon.light_energy = 0.95
	moon.shadow_enabled = true
	moon.shadow_blur = 1.5
	moon.light_angular_distance = 1.5
	moon.directional_shadow_max_distance = 60.0
	moon.rotation_degrees = Vector3(-26, 35, 0)  # low moon from the south-east, behind the viewer
	parent.add_child(moon)
	_own(moon)
	# warm windows of the sanatorium spill onto the snow (no shadows: cheap fill)
	for x: int in [-9, 3, 9]:
		var o: OmniLight3D = OmniLight3D.new()
		o.omni_range = 7.0
		o.omni_attenuation = 1.4
		_light(parent, o, "WindowSpill_%d" % x, Vector3(x, 1.8, -10.8), Color(1.0, 0.68, 0.36), 1.6, false, 0)
	for i: int in 2:
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.omni_range = 11.0
		lamp.omni_attenuation = 1.2
		var px: float = -5.0 if i == 0 else 9.0
		_light(parent, lamp, "LampLight_%d" % i, Vector3(px, 3.5, -6.95), Color(1.0, 0.72, 0.42), 2.6, true, 5.0 - i)
	var sconce: OmniLight3D = OmniLight3D.new()
	sconce.omni_range = 8.0
	_light(parent, sconce, "LobbySconce", Vector3(-8, 2.9, -19.4), Color(1.0, 0.66, 0.35), 2.2, true, 6.0)
	var fill: OmniLight3D = OmniLight3D.new()
	fill.omni_range = 9.0
	_light(parent, fill, "LobbyFill", Vector3(-4, 3.2, -15), Color(1.0, 0.75, 0.5), 0.8, false, 0)
	var shaft: SpotLight3D = SpotLight3D.new()  # blue moon shaft through the lobby's west window
	shaft.spot_range = 12.0
	shaft.spot_angle = 18.0
	shaft.rotation_degrees = Vector3(-35, -90, 0)
	_light(parent, shaft, "MoonShaft", Vector3(-15.5, 3.2, -15), Color(0.55, 0.7, 1.0), 3.0, true, 3.0)
	var search: SpotLight3D = SpotLight3D.new()  # comms-ridge searchlight sweeping the yard
	search.spot_range = 70.0
	search.spot_angle = 7.0
	search.spot_attenuation = 0.6
	_light(parent, search, "Searchlight", Vector3(24, 18, 22), Color(0.9, 0.95, 1.0), 9.0, true, 4.0)
	for i: int in 2:
		var b: OmniLight3D = OmniLight3D.new()
		b.omni_range = 4.5
		var local: Vector3 = Vector3(0.95 if i == 0 else -0.95, 1.0, -3.15)
		var at: Vector3 = Vector3(-9.5, 0, 6) + Basis(Vector3.UP, deg_to_rad(78.0)) * local
		_light(parent, b, "TruckBeacon_%d" % i, at, Color(1, 0.08, 0.04), 1.5, false, 0)
	var tower: OmniLight3D = OmniLight3D.new()
	tower.omni_range = 14.0
	_light(parent, tower, "TowerBeacon", Vector3(-18, 42.4, -48), Color(1, 0.1, 0.05), 4.0, false, 0)


func _zombies(props: Node) -> void:
	var z: Node3D = _group(props, "Zombies")
	var defs: Array[Array] = [
		["orderly", Vector3(4.6, 0, 6.6), 20.0, &"walk"],
		["orderly_pallid", Vector3(-2.2, 0, 4.2), 40.0, &"idle"],
		["orderly_frostbitten", Vector3(7.6, 0, 2.8), -15.0, &"attack_swipe"],
		["orderly", Vector3(-9.0, 0, -15.5), 60.0, &"idle"],
	]
	for i: int in defs.size():
		var d: Array = defs[i]
		var zm: Node3D = _inst(z, ZOMBIES + "zombie_%s.tscn" % d[0], "Zombie_%d_%s" % [i, d[0]], d[1], d[2])
		zm.set(&"autoplay", d[3])


func _gameplay(gp: Node) -> void:
	for i: int in 4:
		var m: Marker3D = Marker3D.new()
		m.name = "PlayerSpawn%d" % i
		m.position = Vector3(-1.5 + i, 0.05, 10.5)
		m.add_to_group(&"player_spawn", true)
		gp.add_child(m)
		_own(m)


func _shots(parent: Node) -> void:
	var defs: Array[Array] = [
		["Shot1_Courtyard", Vector3(7, 1.7, 13.5), Vector3(-2, 3.2, -10)],
		["Shot2_Fountain", Vector3(6.5, 1.55, 8.2), Vector3(2.5, 1.6, 2)],
		["Shot3_Truck", Vector3(-3.5, 1.6, 11.5), Vector3(-10, 1.3, 5)],
		["Shot4_Facade", Vector3(-0.5, 1.7, -3.0), Vector3(-1.5, 5.5, -12)],
		["Shot5_Lobby", Vector3(-2.0, 1.7, -13.6), Vector3(-11, 1.2, -19)],
	]
	for d: Array in defs:
		var c: Camera3D = Camera3D.new()
		c.name = d[0]
		c.fov = 70.0
		c.add_to_group(&"screenshot_shot", true)
		parent.add_child(c)
		_own(c)
		var from: Vector3 = d[1]
		var to: Vector3 = d[2]
		c.transform = Transform3D(Basis.looking_at(to - from), from)
