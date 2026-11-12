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
