# Z05 Operating Theater (VESPER_PEAK §3 Z05), 3F at y +4: the stairwell up from D05, a 20 x 20 m
# amphitheater (x 64..84, z -98..-78) around the electroconvulsive apparatus (Relay R2), a gallery
# ring at +7 m reached by two stairs, the scrub room (east) with the laundry chute grate (shoot it
# once; one-way slide to Specimen Storage), D15 to the Sky Bridge (west, gallery level), 2 skylight
# drops, 2 gallery windows and a vent.
extends VesperZone

const Y: float = 4.0
const GAL: float = 7.0


func build() -> void:
	corridor("Stairwell", Vector3(75, -2.0, -62.2), Vector3(75, Y, -78.0), 3.2, 3.0, &"plaster")
	room(
		"Theater",
		Vector3(64, Y, -98),
		Vector3(84, (Y) + (10.0), -78),
		{
			"N": [[75.0, 3.2, 0.0, 2.5]],
			"W": [[-88.0, 3.0, GAL - Y, GAL - Y + 3.0], [-94.0, 1.4, 0.0, 1.0]],
			"E": [door_hole(-81, 2.4, 2.6), [-90.0, 1.4, GAL - Y + 0.9, GAL - Y + 2.1]],
			"S": [[74.0, 1.4, GAL - Y + 0.9, GAL - Y + 2.1]],
		},
		[&"tile", &"plaster"]
	)
	for g: Array in [
		["GalN", Vector3(64, GAL - 0.4, -81), Vector3(84, GAL, -78)],
		["GalS", Vector3(64, GAL - 0.4, -98), Vector3(84, GAL, -95)],
		["GalW", Vector3(64, GAL - 0.4, -95), Vector3(67, GAL, -81)],
		["GalE", Vector3(81, GAL - 0.4, -95), Vector3(84, GAL, -81)],
	]:
		box_mm(String(g[0]), g[1], g[2], &"wood")
	stairs("GalStairW", Vector3(73, Y, -92), Vector3(67.2, GAL, -92), 2.0)
	stairs("GalStairE", Vector3(75, Y, -84), Vector3(80.8, GAL, -84), 2.0)
	box("Apparatus", Vector3(74, Y + 0.9, -88), Vector3(3, 1.8, 3), &"brass")
	box("Lamp", Vector3(74, Y + 8.5, -88), Vector3(2.5, 0.6, 2.5), &"metal")
	# Scrub room + chute.
	room(
		"Scrub",
		Vector3(84, Y, -84),
		Vector3(90, (Y) + (3.2), -78),
		{"W": false, "E": [[-81.0, 1.6, 0.0, 1.8]]},
		[&"tile", &"plaster"]
	)
	box_mm("ChuteNook", Vector3(90.2, Y - 0.5, -82.2), Vector3(92.2, Y, -79.8), &"metal")
	box_mm("ChuteNookN", Vector3(90.2, Y, -79.9), Vector3(92.2, Y + 2.2, -79.7), &"metal")
	box_mm("ChuteNookS", Vector3(90.2, Y, -82.3), Vector3(92.2, Y + 2.2, -82.1), &"metal")
	box_mm("ChuteNookE", Vector3(92.0, Y, -82.2), Vector3(92.2, Y + 2.2, -79.8), &"metal")
	box_mm("ChuteNookTop", Vector3(90.2, Y + 2.0, -82.2), Vector3(92.2, Y + 2.4, -79.8), &"metal")
	var grate: NavDoor = nav_door("CHT_Grate", Vector3(90, Y + 0.9, -81), Vector3(0.2, 1.8, 1.6))
	var g: ShootableGrate = ShootableGrate.new()
	g.name = "CHT_GrateTarget"
	g.position = Vector3(89.85, Y + 0.9, -81)
	g.hit_size = Vector3(0.3, 1.8, 1.6)
	gameplay.add_child(g)
	g.door_path = g.get_path_to(grate)
	g.door = grate
	var ch: Chute = Chute.new()
	ch.name = "CHT_LaundryChute"
	ch.position = Vector3(91.1, Y + 1.0, -81)
	ch.size = Vector3(2.0, 2.0, 2.6)
	ch.tube_point = Vector3(102, -19.9, -37)
	ch.exit_point = Vector3(87.5, -27.9, -31.5)
	ch.travel_time = 5.0
	gameplay.add_child(ch)
	ch.grate_path = ch.get_path_to(grate)
	ch.grate = grate
	# The sealed slide tube riders wait in (dark; see Chute).
	room("ChuteTube", Vector3(100, -20, -40), Vector3(106, (-20) + (2.6), -34), {}, [&"metal", &"metal"])
	# Spawners.
	drop("Sky1", Vector3(70, 12.0, -82.5), Vector3(70, Y, -85.0), ZombieSpawner.Kind.VENT, 2)
	drop("Sky2", Vector3(79, 12.0, -94.0), Vector3(78, Y, -91.0), ZombieSpawner.Kind.VENT, 2)
	window("W_GalE", Vector3(84, GAL, -90), Vector3.RIGHT)
	window("W_GalS", Vector3(74, GAL, -98), Vector3.FORWARD)
	vent("Vent", Vector3(64, Y, -94), Vector3.LEFT)
	var d15: NavDoor = nav_door("D15_SkyBridge", Vector3(64, GAL + 1.4, -88), Vector3(0.4, 2.8, 3.0))
	buy_door(&"D15", "Sky Bridge", 1500, [&"Z07", &"Z05"], [d15], Vector3(64.9, GAL + 1.4, -88))
	area("Stairwell", Vector3(73.4, -2.5, -78), Vector3(76.6, 7.0, -62))
	area("Theater", Vector3(64, 3.5, -98), Vector3(84, 14.0, -78))
	area("Scrub", Vector3(84, 3.5, -84), Vector3(90, 8.0, -78))
	nav_areas.clear()
	nav_areas.append(AABB(Vector3(64, -3.0, -101.8), Vector3(28.4, 16.0, 39.8)))
	nav_areas.append(AABB(Vector3(60, 3.0, -97.0), Vector3(4, 3.0, 6.0)))  # vent crawl
	mark(&"relay", "R2_Relay", Vector3(74, Y + 1.8, -88), "Resonance Relay #2", true)
	mark(&"part", "Part_Lens_A", Vector3(86, Y, -79), "Conduit Lens (option A)")
	mark(&"lore", "L05", Vector3(66, GAL, -79.5), "Varga surgical note")
	mark(&"reel", "R03", Vector3(82.5, GAL, -96.5), "audio reel R03")
	mark(&"ee", "EE_VargaSeat", Vector3(65.5, GAL, -96.5), "Varga's gallery seat")
	lamp(Vector3(74, Y + 7.5, -88), Color(0.9, 0.95, 1.0), 3.0, 20.0, true, 0.1)
	lamp(Vector3(87, Y + 2.6, -81), Color(0.8, 0.95, 1.0), 0.8, 6.0)
	ambience(Vector3(74, Y + 3, -88), &"interior_wind")
	occluder("Occ_Floor", Vector3(74, Y - 1.5, -88), Vector3(20, 2, 20))


# --- Step 13 art pass (13B): the amphitheater, the glass dome, the apparatus, the scrub room -----


func dress() -> void:
	trim = "lab"
	# The glass dome (the roof slab stays as invisible collision: glass). Snow falls through one
	# broken pane in a single column; moonlight shafts down onto the apparatus.
	hide_greybox("Theater_Roof")
	var roof: Node = geometry.get_node_or_null("Theater_Roof")
	if roof != null:
		roof.set_meta(&"glass", true)
	_dome(Vector3(74, Y + 10.0, -88), 11.0)
	skin("Lamp", &"surgical_lamp", Vector3(0, 0.6, 0))
	var lamp_s: SpotLight3D = spot_light(
		Vector3(74, Y + 8.2, -88), Vector3(74, Y, -88), Color(0.92, 0.97, 1.0), 4.0, 14.0, 38.0, true
	)
	lamp_s.shadow_enabled = true
	lamp_s.add_to_group(&"shadow_light")
	lamp_s.set_meta(&"shadow_priority", 70)
	spot_light(Vector3(68, Y + 16.0, -83), Vector3(73, Y, -87), Color(0.6, 0.7, 1.0), 1.4, 24.0, 12.0)
	fx(AtmosFx.Kind.SNOW_DRIFT, Vector3(70, Y + 9.5, -84), Vector3(0.5, 0.2, 0.5), Vector3.DOWN)
	decal(&"frost", Vector3(70, Y + 0.05, -84), Vector2(2.5, 2.5))
	# The electroconvulsive apparatus: vesperite cells, cables, green arcs (Relay #2 sits on it).
	for i: int in 4:
		var a: float = TAU * i / 4.0 + PI / 4.0
		var p: Vector3 = Vector3(74, Y, -88) + Vector3(cos(a), 0, sin(a)) * 2.2
		prop(&"gas_tank", p, a)
		deco("Cell_%d" % i, p + Vector3(0, 1.6, 0), Vector3(0.25, 0.4, 0.25), &"vesperite")
		fx(AtmosFx.Kind.ENERGY, p + Vector3(0, 1.7, 0), Vector3(0.2, 0.2, 0.2))
	fixture_light(&"", Vector3(74, Y + 2.2, -88), Color(0.4, 1.0, 0.55), 0.9, 6.0, PoweredLight.Pattern.BUZZ, false)
	decal(&"scorch", Vector3(74, Y + 0.05, -88), Vector2(5, 5))
	decal(&"blood", Vector3(72.0, Y + 0.05, -86.2), Vector2(1.5, 1.5), Vector3.UP, 0.8)
	# Tiered seating on the gallery ring, facing the table.
	for x: float in [69.0, 74.0, 79.0]:
		prop(&"bench", Vector3(x, GAL, -79.4), PI)
		prop(&"bench", Vector3(x, GAL, -96.6), 0.0)
	for z: float in [-85.0, -91.0]:
		prop(&"bench", Vector3(65.4, GAL, z), PI / 2.0)
		prop(&"bench", Vector3(82.6, GAL, z), -PI / 2.0)
	# Vignette 4: Varga's seat — a notebook and fogged glasses.
	var v: Node3D = vignette(
		"V04_VargaSeat", Vector3(65.5, GAL, -96.5), "Varga's gallery seat: a notebook and fogged glasses"
	)
	prop(&"chair", Vector3(0, 0, 0), PI / 4.0, v)
	prop(&"notebook", Vector3(0.0, 0.48, 0.05), 0.3, v)
	prop(&"glasses", Vector3(0.12, 0.49, -0.12), 1.0, v)
	decal(&"frost", Vector3(65.5, GAL + 0.6, -96.5), Vector2(0.6, 0.6), Vector3.UP, 0.0, Color(1, 1, 1, 0.7))
	# Scrub room: cabinets, gurney, linen; the laundry chute grate.
	prop(&"cabinet", Vector3(89.6, Y, -79.6), -PI / 2.0)
	prop(&"gurney", Vector3(86.5, Y, -83.2), PI / 2.0)
	deco("ScrubSink", Vector3(84.6, Y + 0.85, -79.2), Vector3(1.2, 0.2, 0.5), &"enamel")
	signage("BLANCHISSERIE · WÄSCHE", Vector3(89.75, Y + 2.3, -81), -PI / 2.0, 22, Color(0.9, 0.9, 0.85))
	fixture_light(
		&"fluoro", Vector3(87, Y + 3.0, -81), Color(0.82, 0.95, 1.0), 0.5, 6.0, PoweredLight.Pattern.FLICKER, true
	)
	for p: Vector3 in [Vector3(64.25, GAL + 2.2, -84), Vector3(83.75, GAL + 2.2, -92)]:
		fixture_light(
			&"sconce",
			p,
			Color(0.9, 0.95, 1.0),
			0.5,
			6.0,
			PoweredLight.Pattern.NONE,
			true,
			0,
			PI / 2.0 if p.x < 70 else -PI / 2.0
		)
	signage("AMPHITHÉÂTRE · OPERATIONSSAAL", Vector3(75, Y + 3.0, -78.25), PI, 26, Color(0.85, 0.85, 0.8))
	reverb(&"Reverb_Tile", Vector3(64, 3.5, -98), Vector3(84, 14.0, -78))
	reverb(&"Reverb_Room", Vector3(84, 3.5, -84), Vector3(90, 8.0, -78), 0.5)
	ambience(Vector3(74, Y + 2, -88), &"lab_hum", 4.0)


func _dome(c: Vector3, r: float) -> void:
	var b: MeshBatch = MeshBatch.new()
	var glass: Material = VesperProps.m(&"glass_clear")
	var iron: Material = VesperProps.m(&"metal")
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = r
	sm.is_hemisphere = true
	sm.radial_segments = 24
	sm.rings = 6
	var dome: MeshInstance3D = MeshInstance3D.new()
	dome.name = "GlassDome"
	dome.mesh = sm
	dome.material_override = glass
	dome.position = c
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	art.add_child(dome)
	for i: int in 12:
		var a: float = TAU * i / 12.0
		for k: int in 6:
			var t0: float = PI / 2.0 * float(k) / 6.0
			var t1: float = PI / 2.0 * float(k + 1) / 6.0
			var p0: Vector3 = c + Vector3(cos(a) * cos(t0), sin(t0), sin(a) * cos(t0)) * r
			var p1: Vector3 = c + Vector3(cos(a) * cos(t1), sin(t1), sin(a) * cos(t1)) * r
			var mid: Vector3 = (p0 + p1) * 0.5
			var bs: Basis = _basis_along(p1 - p0)
			b.add(MeshBatch.Shape.BOX, Vector3(0.12, 0.12, p0.distance_to(p1) + 0.05), Transform3D(bs, mid), iron)
	for k: int in [1, 3]:
		var t: float = PI / 2.0 * float(k) / 6.0
		for i: int in 24:
			var a0: float = TAU * i / 24.0
			var a1: float = TAU * (i + 1) / 24.0
			var p0: Vector3 = c + Vector3(cos(a0) * cos(t), sin(t), sin(a0) * cos(t)) * r
			var p1: Vector3 = c + Vector3(cos(a1) * cos(t), sin(t), sin(a1) * cos(t)) * r
			b.add(
				MeshBatch.Shape.BOX,
				Vector3(0.1, 0.1, p0.distance_to(p1) + 0.04),
				Transform3D(_basis_along(p1 - p0), (p0 + p1) * 0.5),
				iron
			)
	for side: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var sz: Vector3 = Vector3(0.6, 0.5, 2 * r) if absf(side.x) > 0.5 else Vector3(2 * r, 0.5, 0.6)
		b.box(sz, c + side * (r - 0.3) + Vector3(0, 0.1, 0), VesperProps.m(&"stone"))
	art.add_child(b.instance("DomeRibs", 160.0))
