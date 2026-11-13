# Vesper Peak — full greybox (DEVELOPMENT_PLAN Step 8, VESPER_PEAK §2–5). The root instances one
# scene per zone (`zones/Zxx_*.tscn`, each a VesperZone that builds its Geometry / Gameplay /
# Lighting / Audio), then builds the tiled navigation (one NavTiles tile per zone area, baked from
# one parse of the map's static colliders; host only), the environment, the soak-bot route and the
# screenshot shots. Datum: y 0 = the Arrival Station floor (+28 m real elevation); +X east, +Z north.
# Power-on feedback (sound sting + klaxon) plays on every peer from the replicated power flag.
# Authority: static map; doors / barricades / machines / power replicate through core systems.
extends Node3D

const AGENT_RADIUS: float = 0.3
const AGENT_HEIGHT: float = 1.8

var nav: NavTiles = null
var zones: Array[VesperZone] = []
var art: VesperArt = null
var quest_world: VesperQuestWorld = null
var secrets_world: VesperSecretsWorld = null


func _ready() -> void:
	art = VesperArt.new()
	art.build(self)  # environment, sky, moon, backdrop, storm, searchlights (Step 13)
	for c: Node in get_children():
		if c is VesperZone:
			zones.append(c as VesperZone)
	art.finish(self)
	# Step 14 quest / secrets holders (built in _on_match_setup; the map root is busy then).
	quest_world = VesperQuestWorld.new()
	quest_world.name = "QuestWorld"
	add_child(quest_world)
	secrets_world = VesperSecretsWorld.new()
	secrets_world.name = "SecretsWorld"
	add_child(secrets_world)
	nav = NavTiles.new()
	nav.name = "Nav"
	nav.template = make_navmesh()
	nav.geometry_root = self
	add_child(nav)
	for z: VesperZone in zones:
		for i: int in z.nav_areas.size():
			nav.add_tile("%s_Tile%d" % [z.zone_id, i], z.nav_areas[i])
	if Net.is_host() or not Net.is_active():
		nav.bake_all(true)  # synchronous at load (~0.3 s, D-051)
		Log.info(
			&"map",
			(
				"vesper_peak navmesh: %d tiles, %d polygons (parse %.0f ms, bake %.0f ms)"
				% [nav.regions.size(), nav.polygon_count(), nav.parse_usec / 1000.0, nav.bake_usec / 1000.0]
			)
		)
	_bot_route()
	_shots()


func _on_match_setup(m: Match) -> void:
	art.on_match_setup(m)
	# Step 14: Easter-egg objects, lore items and secrets (before the target / interaction scans).
	if m.quest != null:
		quest_world.setup(m)
		secrets_world.setup(m)
	if m.session != null:
		m.session.flag_changed.connect(_on_flag)


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
	nm.region_min_size = 12.0  # drops nav specks on prop tops (< ~3.2 m²)
	nm.edge_max_error = 1.0
	# Long corridors otherwise become a few huge polygons and Godot's polygon A* then picks
	# detours (a bot in the Morgue west tunnel was routed back to the tile seam first).
	nm.edge_max_length = 12.0
	return nm


func zone_scene(zone_id: StringName) -> VesperZone:
	for z: VesperZone in zones:
		if z.zone_id == zone_id:
			return z
	return null


func _on_flag(key: String, value: Variant) -> void:
	if key == Power.key(Power.MAIN) and bool(value):
		var z09: VesperZone = zone_scene(&"Z09")
		var at: Vector3 = Vector3(-31.5, -15, -62) if z09 == null else z09.global_position + Vector3(-31.5, -15, -62)
		Audio.play_event_3d(&"power_on", at)
		Audio.play_event(&"power_klaxon")


# Soak-bot loop (SurvivalBot walks straight between waypoints): the Arrival Station with detours
# through D01 (walkway) and D02 (cargo ramp) once open — the early-game rooms the soak covers.
func _bot_route() -> void:
	var route: Array = [
		[Vector3(-7, 0, -5), &""],
		[Vector3(-6, 0, -7.0), &""],
		[Vector3(7, 0, -5), &""],
		[Vector3(12, 0, -3), &""],
		[Vector3(17, 0, -3), &"D01"],
		[Vector3(26, -2.4, -3), &"D01"],
		[Vector3(17, 0, -3), &"D01"],
		[Vector3(12, 0, -3), &""],
		[Vector3(7, 0, -5), &""],
		[Vector3(6, 0, -7), &""],
		[Vector3(6, -1.5, -12), &"D02"],
		[Vector3(6, -5.0, -18), &"D02"],
		[Vector3(6, -1.5, -12), &"D02"],
		[Vector3(6, 0, -7), &""],
		[Vector3(7, 0, 2), &""],
		[Vector3(-7, 0, 2), &""],
		[Vector3(-12, 0, -3), &""],
	]
	var holder: Node3D = Node3D.new()
	holder.name = "BotRoute"
	add_child(holder)
	for i: int in route.size():
		var m: Marker3D = Marker3D.new()
		m.name = "BotRoute_%02d" % i
		m.position = route[i][0]
		m.add_to_group(&"bot_waypoint")
		m.set_meta(&"requires_door", route[i][1])
		holder.add_child(m)


func _shots() -> void:
	for s: Array in [
		["ShotA_Hall", Vector3(-11, 5.5, -7), Vector3(4, 1, 4)],
		["ShotB_Gallery", Vector3(10, 4.2, 7.5), Vector3(-6, 1.5, -4)],
		["ShotC_Overview", Vector3(28, 90, 10), Vector3(28, -10, -60)],
		["ShotD_Courtyard", Vector3(-6, 4, -24), Vector3(30, -8, -55)],
		["ShotE_Lobby", Vector3(40, -2, 6), Vector3(60, -7, -8)],
		["ShotF_Reactor", Vector3(4, -36, -42), Vector3(28, -46, -54)],
	]:
		var cam: Camera3D = Camera3D.new()
		cam.name = String(s[0])
		cam.far = 600.0
		add_child(cam)
		cam.look_at_from_position(s[1], s[2])
		cam.add_to_group(&"screenshot_shot")
