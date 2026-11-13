# VesperArt — Vesper Peak's map-wide art and atmosphere (Step 13, VESPER_PEAK §8): the night-storm
# environment with the procedural sky (moon, clouds, aurora), the distant mountain ring and the
# valley cloud sea, the moonlight, the storm (StormSystem gusts), per-zone grading (ZoneAtmosphere
# with `art/zone_atmosphere.tres`), the viewer-local shadow budget (ShadowBudget), the comms-ridge
# searchlights sweeping the Courtyard, and the reactor's energy pulse every round start (aurora
# flash, exposure dip, thump).
# Authority: local presentation on every peer (time-derived; reads replicated round state).
class_name VesperArt
extends Node3D

const CENTRE: Vector3 = Vector3(28, 0, -50)
const ATMOSPHERE: String = "res://maps/vesper_peak/art/zone_atmosphere.tres"
const SKY_SHADER: String = "res://content/shaders/sky_night.gdshader"
const CLOUD_SHADER: String = "res://content/shaders/cloud_layer.gdshader"
const BASE_ENV: String = "res://content/environments/exterior_storm.tres"
const GAMEPLAY_CULL: float = 70.0

var env: Environment = null
var world_env: WorldEnvironment = null
var moon: DirectionalLight3D = null
var storm: StormSystem = null
var atmosphere: ZoneAtmosphere = null
var sky_mat: ShaderMaterial = null
var searchlights: Array[Node3D] = []
var shadows: ShadowBudget = null
var pulses: int = 0
var terrain: VesperTerrain = null

var _pulse: float = 0.0
var _t: float = 0.0


func build(map_root: Node3D) -> void:
	name = "Art"
	map_root.add_child(self)
	_environment(map_root)
	_backdrop()
	_cloud_sea()
	storm = StormSystem.new()
	storm.name = "Storm"
	add_child(storm)
	atmosphere = ZoneAtmosphere.new()
	atmosphere.name = "ZoneAtmosphere"
	var set_res: AtmosphereSet = load(ATMOSPHERE) as AtmosphereSet
	if set_res != null:
		atmosphere.profiles = set_res.profiles
		atmosphere.default_profile = set_res.fallback
	atmosphere.storm = storm
	add_child(atmosphere)
	atmosphere.sky_visibility_changed.connect(_on_sky_visibility)
	_searchlights()
	shadows = ShadowBudget.new()
	shadows.name = "ShadowBudget"
	add_child(shadows)
	if not Audio.has_event(&"reactor_pulse"):
		Audio.register_event(&"reactor_pulse", Audio.make_tone(42.0, 0.9), &"Ambience", -6.0)


# Zones exist by now (map _ready): collect their volumes for the zone lookup.
func finish(map_root: Node3D) -> void:
	# The mountain the complex is built into (map quality pass): needs the zones' colliders.
	var zones: Array = []
	for c: Node in map_root.get_children():
		if c is VesperZone:
			zones.append(c)
	terrain = VesperTerrain.new()
	terrain.build(self, zones)
	atmosphere.setup(map_root, env, moon)
	add_to_group(&"map_art")
	# The art pass replaces the greybox marker posts / labels (debug: `markers_visible 1`).
	MapMarker.set_all_visuals(map_root, false)


# Static art caches (prop meshes, materials, decal textures, primitives) are rebuilt on the next
# load; clearing them here keeps exit-time leak reports clean.
func _exit_tree() -> void:
	VesperProps.clear_cache()
	VesperZoneArt.clear_cache()
	MeshBatch.clear_cache()
	AtmosFx.clear_cache()


func on_match_setup(m: Match) -> void:
	if m.rounds != null and not m.rounds.round_started.is_connected(_on_round_started):
		m.rounds.round_started.connect(_on_round_started)
	# Machines / wall-buys / relays are built during Match.setup: distance-cull them once they exist.
	# (The map can be freed first — leaving within 0.5 s — so the root is re-checked when it fires.)
	var root: Node = get_parent()
	get_tree().create_timer(0.5).timeout.connect(
		func() -> void:
			if is_instance_valid(root) and root.is_inside_tree():
				cull_gameplay_meshes(root)
	)


# Gives every gameplay mesh (perk machines, wall-buys, relays, the Forge, barricade planks …)
# without a visibility range a distance cull with a short fade (Step 13 draw-call budget).
static func cull_gameplay_meshes(map_root: Node, distance: float = GAMEPLAY_CULL) -> int:
	var n: int = 0
	if map_root == null or not is_instance_valid(map_root):
		return 0
	for z: Node in map_root.get_children():
		var gp: Node = z.get_node_or_null(^"Gameplay")
		if gp == null:
			continue
		for g: Node in gp.find_children("*", "GeometryInstance3D", true, false):
			var gi: GeometryInstance3D = g as GeometryInstance3D
			if gi.visibility_range_end <= 0.0:
				gi.visibility_range_end = distance
				gi.visibility_range_end_margin = 4.0
				gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				n += 1
	return n


# Underground (no-sky profiles): the mountain ring, cloud sea and searchlight beams are hidden so a
# crack in the rock reads as darkness, never as the outside of the map.
func _on_sky_visibility(visible: bool) -> void:
	for c: Node in get_children():
		if c is MeshInstance3D or String(c.name).begins_with("Searchlight"):
			(c as Node3D).visible = visible


func _on_round_started(_r: int) -> void:
	energy_pulse()


# VESPER_PEAK §8.3: a pulse ripples from the reactor at every round start.
func energy_pulse() -> void:
	pulses += 1
	_pulse = 1.0
	Audio.play_event_3d(&"reactor_pulse", Vector3(28, -40, -50))


func _process(delta: float) -> void:
	_t += delta
	_pulse = maxf(_pulse - delta * 0.35, 0.0)
	if sky_mat != null:
		var calm: float = storm.calm_amount if storm != null else 0.0
		sky_mat.set_shader_parameter(
			&"aurora", 0.15 + _pulse * 1.2 + (storm.gust * 0.1 if storm != null else 0.0) + calm * 0.6
		)
	if atmosphere != null:
		atmosphere.exposure_scale = 1.0 - 0.25 * sin(_pulse * PI)
	for i: int in searchlights.size():
		var s: Node3D = searchlights[i]
		var base: float = float(s.get_meta(&"yaw0"))
		s.rotation.y = base + sin(_t * 0.23 + i * 2.1) * 0.55
		s.rotation.x = -0.32 + sin(_t * 0.17 + i) * 0.06


func _environment(map_root: Node3D) -> void:
	world_env = WorldEnvironment.new()
	world_env.name = "Environment"
	var base: Environment = load(BASE_ENV) as Environment
	env = base.duplicate(true) as Environment if base != null else Environment.new()
	var sky: Sky = Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load(SKY_SHADER) as Shader
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.fog_enabled = true
	env.fog_sky_affect = 0.35
	# Height fog pools in the valley below the peak (the base preset's sat above the whole map).
	env.fog_height = -45.0
	env.fog_height_density = 0.03
	env.volumetric_fog_length = 64.0
	world_env.environment = env
	map_root.add_child(world_env)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	# Low angle from the south-west (matches the sky shader's moon direction).
	moon.rotation_degrees = Vector3(-26, 210, 0)
	moon.light_color = Color(0.68, 0.76, 1.0)
	moon.light_energy = 0.75
	moon.light_volumetric_fog_energy = 1.6
	moon.shadow_enabled = true
	moon.shadow_blur = 2.0
	moon.directional_shadow_max_distance = 70.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.add_to_group(&"shadow_light")
	moon.set_meta(&"shadow_priority", 100)
	map_root.add_child(moon)
	# The light travels along the moon's -Z, so the moon sits along +Z in the sky.
	sky_mat.set_shader_parameter(&"moon_dir", moon.global_transform.basis.z.normalized())


# Distant peaks: a ring of jagged ridges (snow above ~60 % height) 230–420 m from the map centre,
# plus the near ridge masses behind the Comms Array and the Courtyard cliff. One mesh, vertex
# colours, no collision.
func _backdrop() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1952
	var rock: Color = Color(0.035, 0.045, 0.06)
	var snow: Color = Color(0.3, 0.34, 0.42)
	var rock0: Color = rock
	var snow0: Color = snow
	for ring: int in 3:
		var r0: float = 230.0 + ring * 85.0
		# aerial perspective: farther ranges fade toward the haze colour
		rock = rock0.lerp(Color(0.1, 0.13, 0.19), ring * 0.35)
		snow = snow0.lerp(Color(0.22, 0.27, 0.36), ring * 0.35)
		var segs: int = 72
		var heights: PackedFloat32Array = PackedFloat32Array()
		for i: int in segs:
			var a: float = TAU * float(i) / segs
			var h: float = 40.0 + ring * 35.0 + rng.randf_range(0.0, 70.0 + ring * 30.0)
			h += 50.0 * maxf(sin(a * 3.0 + ring), 0.0)
			heights.append(h)
		for i: int in segs:
			var a0: float = TAU * float(i) / segs
			var a1: float = TAU * float(i + 1) / segs
			var am: float = (a0 + a1) * 0.5
			var h0: float = heights[i]
			var h1: float = heights[(i + 1) % segs]
			var hm: float = maxf(h0, h1) + rng.randf_range(5.0, 30.0)
			var base_y: float = -160.0
			var p0: Vector3 = CENTRE + Vector3(cos(a0) * r0, base_y, sin(a0) * r0)
			var p1: Vector3 = CENTRE + Vector3(cos(a1) * r0, base_y, sin(a1) * r0)
			var q0: Vector3 = CENTRE + Vector3(cos(a0) * r0, h0, sin(a0) * r0)
			var q1: Vector3 = CENTRE + Vector3(cos(a1) * r0, h1, sin(a1) * r0)
			var peak: Vector3 = CENTRE + Vector3(cos(am) * (r0 + 12.0), hm, sin(am) * (r0 + 12.0))
			var c0: Color = snow if h0 > 95.0 else rock
			var c1: Color = snow if h1 > 95.0 else rock
			_tri(st, p0, q0, p1, rock, c0, rock)
			_tri(st, p1, q0, q1, rock, c0, c1)
			_tri(st, q0, peak, q1, c0, snow if hm > 85.0 else rock, c1)
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "MountainRing"
	mi.mesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Distance haze is baked into the vertex colours; scene fog would flatten the ridges into a
	# pale wall (map quality pass).
	mat.disable_fog = true
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 50.0
	add_child(mi)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


func _cloud_sea() -> void:
	var shader: Shader = load(CLOUD_SHADER) as Shader
	for layer: Array in [[-70.0, 0.62, 0.004, 0.9], [-40.0, 0.38, 0.006, 0.5], [240.0, 0.42, 0.003, 0.45]]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "CloudLayer_%d" % int(layer[0])
		var pm: PlaneMesh = PlaneMesh.new()
		pm.size = Vector2(1100, 1100)
		mi.mesh = pm
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter(&"coverage", float(layer[1]))
		m.set_shader_parameter(&"scale", float(layer[2]))
		m.set_shader_parameter(&"alpha", float(layer[3]))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = CENTRE + Vector3(0, float(layer[0]), 0)
		add_child(mi)


# Two searchlights on the comms ridge sweeping the Courtyard (VESPER_PEAK §3 Z06), with a faint
# beam cone. Non-shadowed; the beams read through the volumetric fog.
func _searchlights() -> void:
	var beam_mat: StandardMaterial3D = StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.albedo_color = Color(0.55, 0.6, 0.7, 0.035)
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	for p: Vector3 in [Vector3(-16, 22.5, -101), Vector3(12, 22.5, -101)]:
		var pivot: Node3D = Node3D.new()
		pivot.name = "Searchlight_%d" % searchlights.size()
		pivot.position = p
		var to: Vector3 = Vector3(28, -8, -49) - p
		var yaw0: float = atan2(-to.x, -to.z)
		pivot.rotation.y = yaw0
		pivot.set_meta(&"yaw0", yaw0)
		add_child(pivot)
		var housing: MeshInstance3D = VesperProps.make(&"searchlight")
		pivot.add_child(housing)
		var sl: SpotLight3D = SpotLight3D.new()
		sl.light_color = Color(0.85, 0.9, 1.0)
		sl.light_energy = 6.0
		sl.spot_range = 95.0
		sl.spot_angle = 7.0
		sl.spot_attenuation = 0.6
		sl.light_volumetric_fog_energy = 3.0
		sl.shadow_enabled = false
		pivot.add_child(sl)
		var beam: MeshInstance3D = MeshInstance3D.new()
		beam.name = "Beam"
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.3
		cm.bottom_radius = 7.0
		cm.height = 60.0
		cm.radial_segments = 16
		cm.cap_top = false
		cm.cap_bottom = false
		beam.mesh = cm
		beam.material_override = beam_mat
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.rotation.x = -PI / 2.0
		beam.position = Vector3(0, 0, -30.0)
		pivot.add_child(beam)
		searchlights.append(pivot)
