# Z01 Arrival Station (VESPER_PEAK §3 Z01): the start. Ticket hall 26 x 16 m (x -13..13,
# z -8..8, datum y 0), waiting gallery +2.5 m along the north side with two staircases, 4
# barricaded windows (2 ground, 2 gallery), a maintenance vent (round 3+), M14 + Coachgun
# wall-buys, the gondola dock (south-west; cabin to the Comms Array) and doors D01 (east, covered
# walkway to the Lobby) / D02 (south, cargo ramp to the Courtyard). The ticket-hall layout and the
# positions the co-op tests use are unchanged from the Step 6 slice.
extends VesperZone

const HALL_H: float = 6.5
const GALLERY_Y: float = 2.5
const DOCK_X: float = -4.5


func build() -> void:
	box_mm("Ground", Vector3(-13.4, -0.5, -8.4), Vector3(13.4, 0, 8.4), &"marble")
	box("Roof", Vector3(0, HALL_H + 0.2, 0), Vector3(26.8, 0.4, 16.8), &"concrete")
	var gal: float = GALLERY_Y
	wall_x("WallW", -13.2, -8.4, 8.4, 0.0, HALL_H, [win_hole(-3.0), [5.5, 1.4, gal + 0.9, gal + 2.1]], &"facade")
	wall_x(
		"WallE", 13.2, -8.4, 8.4, 0.0, HALL_H, [door_hole(-3.0, 2.4, 2.6), [5.5, 1.4, gal + 0.9, gal + 2.1]], &"facade"
	)
	wall_z(
		"WallS",
		-8.2,
		-13.4,
		13.4,
		0.0,
		HALL_H,
		[win_hole(-10.0), door_hole(DOCK_X, 2.4, 2.8), door_hole(6.0, 2.4, 2.6)],
		&"facade"
	)
	wall_z("WallN", 8.2, -13.4, 13.4, 0.0, HALL_H, [[0.0, 1.0, 0.0, 1.0]], &"facade")
	window("W_G1", Vector3(-13.2, 0, -3), Vector3.LEFT)
	window("W_G2", Vector3(-10, 0, -8.2), Vector3.FORWARD)
	window("W_U1", Vector3(-13.2, gal, 5.5), Vector3.LEFT)
	window("W_U2", Vector3(13.2, gal, 5.5), Vector3.RIGHT)
	vent("Vent", Vector3(0, 0, 8.2), Vector3.BACK)
	# Gallery + staircases.
	box("Gallery", Vector3(0, gal - 0.15, 5.6), Vector3(26.4, 0.3, 5.2), &"wood")
	box("GalleryRail", Vector3(0, gal + 0.5, 3.1), Vector3(19.0, 1.0, 0.12), &"metal")
	for sx: float in [-1.0, 1.0]:
		stairs("Stair%s" % ("W" if sx < 0 else "E"), Vector3(11.2 * sx, 0, -1.0), Vector3(11.2 * sx, gal, 3.0), 3.2)
	# Obstacles: ticket booth, benches, luggage carousel (under the gallery).
	box("TicketBooth", Vector3(10, 1.3, -6), Vector3(2, 2.6, 2), &"wood")
	box("Bench_W", Vector3(-4, 0.25, -1), Vector3(2.4, 0.5, 0.6), &"wood")
	box("Bench_E", Vector3(4, 0.25, -1), Vector3(2.4, 0.5, 0.6), &"wood")
	box("Carousel", Vector3(0, 0.15, 5.5), Vector3(6, 0.3, 2), &"metal")
	box("CarouselHub", Vector3(0, 1.3, 5.5), Vector3(1.2, 2.6, 1.2), &"metal")
	_doors()
	_gondola()
	_gameplay()
	lamp(Vector3(0, 5, -1), Color(1.0, 0.78, 0.5), 2.0, 16.0, false)  # the swinging tungsten lamp
	lamp(Vector3(-8, 5.5, 4), Color(0.85, 0.9, 1.0), 1.2, 12.0)
	lamp(Vector3(8, 5.5, 4), Color(0.85, 0.9, 1.0), 1.2, 12.0)
	lamp(Vector3(DOCK_X, 3.0, -12), Color(1.0, 0.25, 0.15), 1.5, 8.0, false)  # flare in the dock
	ambience(Vector3(0, 3, 0), &"interior_wind")
	occluder("Occ_Floor", Vector3(0, -1.5, 0), Vector3(26, 2, 16))


func _doors() -> void:
	var d1: NavDoor = nav_door("D01_Debris", Vector3(13.2, 1.3, -3), Vector3(0.3, 2.6, 2.4))
	buy_door(&"D01", "debris", 750, [&"Z03", &"Z01"], [d1], Vector3(12.5, 1.3, -3))
	var d2: NavDoor = nav_door("D02_Shutter", Vector3(6, 1.3, -8.2), Vector3(2.4, 2.6, 0.3))
	buy_door(&"D02", "cargo shutter", 1000, [&"Z06", &"Z01"], [d2], Vector3(6, 1.3, -7.5))


# Gondola dock (station 0): platform x -7..-2, z -13..-8.2; the cabin hangs in its bay at
# z -16..-13 and rides the cable over the Courtyard to the Comms Array station (VESPER_PEAK §5 GND).
func _gondola() -> void:
	room(
		"Dock",
		Vector3(-7.0, 0.0, -13.0),
		Vector3(-2.0, (0.0) + (4.0), -8.4),
		{"N": false, "S": false},
		[&"concrete", &"concrete"]
	)
	# The gate is cabin-wide (3 m); the dock edge beside it is always closed (no gap to the void).
	var gate_s: StaticBody3D = clip("Gondola_Gate0", Vector3(DOCK_X, 1.5, -13.0), Vector3(3.0, 3.0, 0.3))
	clip("Gondola_EdgeW", Vector3(DOCK_X - 2.0, 1.5, -13.0), Vector3(1.2, 3.0, 0.3))
	clip("Gondola_EdgeE", Vector3(DOCK_X + 2.0, 1.5, -13.0), Vector3(1.2, 3.0, 0.3))
	box("DockRailW", Vector3(DOCK_X - 2.0, 0.5, -13.0), Vector3(1.2, 1.0, 0.15), &"metal")
	box("DockRailE", Vector3(DOCK_X + 2.0, 0.5, -13.0), Vector3(1.2, 1.0, 0.15), &"metal")
	var cab: TraversalMachine = TraversalMachine.new()
	cab.name = "GND_Gondola"
	cab.machine_id = &"gondola"
	cab.display_name = "gondola"
	cab.ride_time = 8.0
	cab.cooldown = 30.0
	cab.boarding_delay = 1.5
	cab.ride_cost = 500
	cab.requires_power = true
	cab.rider_size = Vector3(2.8, 2.4, 2.8)
	cab.waypoints = PackedVector3Array(
		[
			Vector3(DOCK_X, 0.0, -14.6),
			Vector3(DOCK_X, 1.5, -20.0),
			Vector3(DOCK_X, 19.5, -86.0),
			Vector3(DOCK_X, 17.0, -93.6),
		]
	)
	cab.position = cab.waypoints[0]
	_cabin(cab)
	cab.station_gates[0] = gate_s
	gameplay.add_child(cab)
	var cable: MeshInstance3D = MeshInstance3D.new()
	cable.name = "GondolaCable"
	var cm: BoxMesh = BoxMesh.new()
	var a: Vector3 = Vector3(DOCK_X, 3.4, -14.6)
	var b: Vector3 = Vector3(DOCK_X, 20.4, -93.6)
	cm.size = Vector3(0.08, 0.08, a.distance_to(b))
	cable.mesh = cm
	cable.transform = Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), (a + b) * 0.5)
	cable.material_override = _mat(&"metal")
	geometry.add_child(cable)
	var c0: MachineConsole = MachineConsole.new()
	c0.name = "GND_Console_Z01"
	c0.station = 0
	c0.position = Vector3(-2.6, 1.2, -11.5)
	gameplay.add_child(c0)
	c0.machine_path = c0.get_path_to(cab)
	c0.machine = cab


# Cabin geometry on the machine body: floor, side walls, roof, gates (solid while moving) at both
# open ends (north = Z01 dock side, south = Comms Array side), in-cabin ride panel.
func _cabin(cab: TraversalMachine) -> void:
	var parts: Array = [
		["Floor", Vector3(0, -0.15, 0), Vector3(3.0, 0.3, 3.0)],
		["WallE", Vector3(1.45, 1.25, 0), Vector3(0.1, 2.5, 3.0)],
		["WallW", Vector3(-1.45, 1.25, 0), Vector3(0.1, 2.5, 3.0)],
		["Roof", Vector3(0, 2.55, 0), Vector3(3.0, 0.1, 3.0)],
		["Hanger", Vector3(0, 3.0, 0), Vector3(0.2, 0.8, 0.2)],
	]
	for p: Array in parts:
		_cab_shape(cab, String(p[0]), p[1], p[2], true)
	for g: Array in [["GateN", Vector3(0, 1.2, 1.45)], ["GateS", Vector3(0, 1.2, -1.45)]]:
		cab.cabin_gates.append(_cab_shape(cab, String(g[0]), g[1], Vector3(3.0, 2.4, 0.1), false))
	var panel: MachineConsole = MachineConsole.new()
	panel.name = "GND_CabinPanel"
	panel.station = -1
	panel.position = Vector3(1.2, 1.2, 0)
	panel.use_radius = 1.6
	cab.add_child(panel)
	panel.machine_path = ^".."


func _cab_shape(cab: TraversalMachine, n: String, pos: Vector3, size: Vector3, visible_mesh: bool) -> CollisionShape3D:
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = n
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	cab.add_child(cs)
	if visible_mesh:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = _mat(&"olive")
		mi.position = pos
		cab.add_child(mi)
	return cs


func _gameplay() -> void:
	area("Hall", Vector3(-13.2, -0.5, -8.2), Vector3(13.2, 7.0, 8.2))
	area("Dock", Vector3(-7.0, -0.5, -13.0), Vector3(-2.0, 5.0, -8.2))
	nav_areas.clear()
	nav_areas.append(AABB(Vector3(-17.4, -3.0, -13.2), Vector3(30.6, 6.5, 25.2)))
	for i: int in 4:
		var m: Marker3D = Marker3D.new()
		m.name = "PlayerSpawn%d" % i
		m.position = Vector3(-1.5 + i, 0.05, -3.0)
		m.add_to_group(&"player_spawn")
		gameplay.add_child(m)
	wall_buy(&"m14", Vector3(-1.5, 1.5, -7.95), 0.0).name = "WallBuy_M14"
	wall_buy(&"coachgun", Vector3(-4, GALLERY_Y + 1.5, 7.95), PI).name = "WallBuy_Coachgun"
	mark(&"perk", "Perk_SecondWind", Vector3(8, 0, 7.4), "Second Wind Seltzer (no power)")
	mark(&"music_box", "MB1_Luggage", Vector3(2.6, 0, 6.2), "music box #1")
	mark(&"lore", "L01", Vector3(10, 2.6, -6), "cable car timetable")
	mark(&"raven", "Raven_1_Z01Roof", Vector3(0, HALL_H + 0.4, -8.6), "frozen raven (roofline)")
	mark(&"ee", "EE_DeparturesBoard", Vector3(-6, 4.5, 8.0), "departures board")


# --- Step 13 art pass (13A): ticket hall, gallery, gondola dock -----------------------------------


func dress() -> void:
	trim = "sanatorium"
	var warm: Color = Color(1.0, 0.74, 0.46)
	var moon_c: Color = Color(0.62, 0.72, 1.0)
	skin("Bench_W", &"bench", Vector3.ZERO, 0.0)
	skin("Bench_E", &"bench", Vector3.ZERO, PI)
	skin("TicketBooth", &"desk", Vector3(0, 0, 0.3), PI)
	deco("BoothScreen", Vector3(10, 1.9, -6.0), Vector3(2.0, 1.4, 0.06), &"glass_clear")
	deco("BoothRoof", Vector3(10, 2.65, -6), Vector3(2.3, 0.12, 2.3), &"wood")
	signage("BILLETS · FAHRKARTEN · TICKETS", Vector3(10, 2.45, -4.82), 0.0, 22, Color(0.95, 0.85, 0.55))
	# Luggage carousel: rubber belt + scattered bags (music box #1 hides in the pile).
	deco("CarouselBelt", Vector3(0, 0.32, 5.5), Vector3(6.2, 0.06, 2.2), &"rubber")
	for p: Array in [[Vector3(-2.2, 0.35, 5.0), 0.3], [Vector3(-1.2, 0.35, 6.0), 1.1], [Vector3(1.6, 0.35, 5.1), 2.0]]:
		prop(&"suitcase", p[0], float(p[1]))
	prop(&"trunk", Vector3(3.4, 0, 6.6), 0.4)
	prop(&"suitcase", Vector3(2.9, 0.5, 6.5), 1.4, null, Vector3(0, 0, 0.2))
	prop(&"suitcase", Vector3(-3.6, 0, 4.4), 2.6, null, Vector3(PI / 2.0, 0, 0))
	# Departures board (north wall, flips to the round number in Step 15).
	deco("DeparturesBoard", Vector3(-6, 4.5, 8.0), Vector3(4.2, 1.3, 0.12), &"black")
	deco("DeparturesFrame", Vector3(-6, 4.5, 8.04), Vector3(4.4, 1.5, 0.06), &"brass")
	signage("ABFAHRT  DEPARTURES", Vector3(-6, 5.0, 7.9), PI, 26, Color(1.0, 0.72, 0.3))
	signage("KOMMANDOSTATION   --:--\nSANATORIUM       23:51", Vector3(-6, 4.4, 7.9), PI, 20, Color(1.0, 0.62, 0.2))
	signage("VESPERHÖHE BERGSTATION · 2471 m", Vector3(4, 6.0, 7.95), PI, 40, Color(0.82, 0.78, 0.68))
	signage("GROUP VESPER\nAUTHORISED PERSONNEL ONLY", Vector3(-4.5, 2.9, -7.95), 0.0, 22, Color(0.92, 0.9, 0.82))
	signage("GONDEL > KOMMANDOSTATION", Vector3(-4.5, 3.3, -8.6), PI, 24, Color(0.92, 0.9, 0.82))
	# Gallery furniture.
	prop(&"bench", Vector3(-7.5, 2.5, 7.4), PI)
	prop(&"bench", Vector3(6.0, 2.5, 7.4), PI)
	prop(&"suitcase", Vector3(-9.5, 2.5, 7.0), 0.7)
	# Lights: the swinging tungsten lamp (shadowed), wall sconces (power), moon shafts.
	prop(&"pendant", Vector3(0, 5.6, -1))
	for p: Vector3 in [Vector3(-12.95, 4.2, 0), Vector3(12.95, 4.2, 1.5), Vector3(-12.95, 4.2, -6)]:
		fixture_light(
			&"sconce", p, warm, 0.7, 6.0, PoweredLight.Pattern.NONE, true, 0, PI / 2.0 if p.x < 0 else -PI / 2.0
		)
	var swing: Light3D = fixture_light(&"", Vector3(0, 5.1, -1), warm, 1.6, 15.0, PoweredLight.Pattern.SWING, false, 60)
	swing.set_meta(&"note", "swinging tungsten lamp")
	for w: Array in [[Vector3(-15.5, 5.5, -3), Vector3(-6, 0, -1)], [Vector3(-15.5, 7.0, 5.5), Vector3(-7, 2.5, 4)]]:
		spot_light(w[0], w[1], moon_c, 1.6, 22.0, 18.0)
	# Flare in the dock (red flicker, embers) and the dead gondola bay.
	var flare_at: Vector3 = Vector3(-5.6, 0.05, -11.8)
	prop(&"beacon", flare_at, 0.0, null, Vector3(0, 0, PI / 2.0))
	fixture_light(
		&"", flare_at + Vector3(0, 0.4, 0), Color(1.0, 0.25, 0.12), 1.4, 9.0, PoweredLight.Pattern.FLICKER, false
	)
	fx(AtmosFx.Kind.EMBERS, flare_at + Vector3(0, 0.2, 0), Vector3(0.1, 0.05, 0.1))
	# Vignette 1: a family's luggage, a child's toy sled and a stopped wristwatch (23:51).
	var v: Node3D = vignette(
		"V01_FamilyLuggage", Vector3(-3.0, 0, -11.4), "a family's luggage, a toy sled, a watch stopped at 23:51", 0.4
	)
	prop(&"sled", Vector3(0, 0, 0), 0.3, v)
	prop(&"suitcase", Vector3(-0.8, 0, 0.6), 1.2, v)
	prop(&"suitcase", Vector3(-0.9, 0.45, 0.55), 1.0, v, Vector3(0, 0, 0.1))
	prop(&"trunk", Vector3(0.9, 0, 0.9), -0.3, v)
	prop(&"watch", Vector3(0.25, 0.0, -0.55), 0.9, v)
	var watch_face: Label3D = signage("23:51", Vector3(-3.0, 0.03, -12.0), 0.0, 14, Color(0.9, 0.85, 0.7))
	watch_face.rotation.x = -PI / 2.0
	# Atmosphere FX: snow through the broken panes, dust in the hall, low haze in the dock.
	fx(AtmosFx.Kind.SNOW_DRIFT, Vector3(-12.6, 1.6, -3), Vector3(0.2, 0.5, 0.6), Vector3.RIGHT)
	fx(AtmosFx.Kind.SNOW_DRIFT, Vector3(-12.6, 4.1, 5.5), Vector3(0.2, 0.5, 0.6), Vector3.RIGHT)
	fx(AtmosFx.Kind.DUST, Vector3(0, 3.0, 1), Vector3(9, 2.5, 5))
	fog(Vector3(-4.5, 0.6, -11), Vector3(5, 1.4, 5), Color(0.6, 0.65, 0.75), 0.25)
	# Decals: grime, damp, frost at the windows, blood under W_G2.
	decal(&"grime", Vector3(-6, 0.05, 2), Vector2(4, 4))
	decal(&"water_stain", Vector3(5, 0.05, -4), Vector2(3, 3), Vector3.UP, 1.2)
	decal(&"grime", Vector3(9, 0.05, 4), Vector2(3, 3), Vector3.UP, 2.0)
	decal(&"frost", Vector3(-12.95, 1.4, -3), Vector2(2.4, 2.4), Vector3.RIGHT)
	decal(&"frost", Vector3(-12.95, 3.9, 5.5), Vector2(2.4, 2.4), Vector3.RIGHT)
	decal(&"frost", Vector3(12.95, 3.9, 5.5), Vector2(2.4, 2.4), Vector3.LEFT)
	decal(&"blood", Vector3(-10, 0.05, -6.6), Vector2(1.8, 1.8), Vector3.UP, 0.7)
	decal(&"claws", Vector3(-10.8, 1.3, -7.95), Vector2(1.0, 1.2), Vector3.BACK)
	# Acoustics.
	reverb(&"Reverb_Hall", Vector3(-13, -0.5, -8), Vector3(13, 7, 8))
	reverb(&"Reverb_Exterior", Vector3(-7, -0.5, -16), Vector3(-2, 5, -8.2))
	ambience(Vector3(-4.5, 1.5, -12), &"exterior_storm", -8.0)
