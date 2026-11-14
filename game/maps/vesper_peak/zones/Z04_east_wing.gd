# Z04 East Wing (VESPER_PEAK §3 Z04), 2F at y -2: a 54 m wing (x 70..82, z -62..-8) along the
# Courtyard's east side. A 4 m main corridor (x 73..77) with patient rooms 3 / 7 / 9 / 12 on the
# east (x 77..82; the others are sealed), the nurse station alcove and the sunroom balcony on the
# west (one-way 4 m drop onto the Courtyard snowbank), a linen-closet door burst, 3 windows, 2
# ceiling vents. D05 (south) leads up to the Operating Theater.
extends VesperZone

const Y: float = -2.0
const H: float = 4.0
const ROOMS: Dictionary = {"R3": -18.0, "R7": -30.0, "R9": -40.0, "R12": -54.0}


func build() -> void:
	corridor("D03Link", Vector3(68.0, Y, -11), Vector3(70.2, Y, -11), 2.8, 3.0, &"plaster")
	room(
		"Wing",
		Vector3(70, Y, -62),
		Vector3(82, (Y) + (H), -8),
		{
			"W": [door_hole(-11, 2.8, 3.0), door_hole(-40, 3.0, 3.0)],
			"S": [door_hole(75, 3.0, 3.0)],
			"E": [win_hole(-18), win_hole(-40), win_hole(-54)],
		},
		[&"wood", &"plaster"]
	)
	# West strip x 70..73: sealed except the connector, nurse station and balcony passage.
	wall_x(
		"InnerW",
		73,
		-62,
		-8,
		Y,
		H,
		[
			door_hole(-11, 2.8, 3.0),
			[-30.0, 8.0, 0.0, 3.2],
			door_hole(-40, 3.0, 3.0),
			[-14.6, 1.6, 0.0, 2.6],
			[-22.0, 1.4, 0.0, 1.0],
			[-48.0, 1.4, 0.0, 1.0]
		],
		&"plaster"
	)
	for z: float in [-12.6, -9.4, -26.0, -34.0, -38.3, -41.7]:
		wall_z("Strip_%d" % int(absf(z) * 10), z, 70, 73, Y, H, [], &"plaster")
	# East rooms x 77..82 with doorways; partitions at the room boundaries.
	var doors: Array = []
	for r: String in ROOMS:
		doors.append(door_hole(float(ROOMS[r]), 1.4, 2.4))
	wall_x("InnerE", 77, -62, -8, Y, H, doors, &"plaster")
	for r: String in ROOMS:
		var zc: float = float(ROOMS[r])
		wall_z("%s_N" % r, zc + 2.0, 77, 82, Y, H, [], &"plaster")
		wall_z("%s_S" % r, zc - 2.0, 77, 82, Y, H, [], &"plaster")
		box("%s_Bed" % r, Vector3(80.5, Y + 0.3, zc + 1.0), Vector3(2.0, 0.6, 1.0), &"metal")
	window("W_R3", Vector3(82, Y, -18), Vector3.RIGHT)
	window("W_R9", Vector3(82, Y, -40), Vector3.RIGHT)
	window("W_R12", Vector3(82, Y, -54), Vector3.RIGHT)
	# The two "ceiling" vents are high-wall ducts into the sealed west strip (headroom; D-055).
	vent("Vent1", Vector3(73, Y, -22), Vector3.LEFT)
	vent("Vent2", Vector3(73, Y, -48), Vector3.LEFT)
	closet("Linen", Vector3(73, Y, -14.6), Vector3.LEFT)
	box("NurseDesk", Vector3(71.2, Y + 0.55, -27.5), Vector3(1.0, 1.1, 2.5), &"wood")
	box("Wheelchair", Vector3(76, Y + 0.45, -35), Vector3(0.7, 0.9, 0.9), &"metal")
	# Sunroom balcony (x 66..70) over the Courtyard: open west edge (4 m drop to the snowbank).
	# Solid foundations under the wing (the ground floor isn't playable) and the snowbank strip under
	# the balcony, so the balcony drop lands in the Courtyard and nothing falls into the void.
	box_mm("Foundation", Vector3(70.0, -9.0, -62.2), Vector3(82.2, Y - 0.5, -7.8), &"stone")
	box_mm("FoundationS", Vector3(66.2, -9.0, -62.2), Vector3(70.0, Y - 0.5, -46.0), &"stone")
	box_mm("FoundationN", Vector3(66.2, -9.0, -28.0), Vector3(70.0, Y - 0.5, -7.8), &"stone")
	box_mm("FoundationShed", Vector3(68.2, -9.0, -35.0), Vector3(70.0, Y - 0.5, -28.0), &"stone")
	box_mm("BalconySnow", Vector3(66.0, -9.0, -46.0), Vector3(70.0, -6.6, -34.0), &"snow")
	box_mm("Balcony", Vector3(66, Y - 0.5, -42), Vector3(70, Y, -38), &"wood")
	box("BalconyRailN", Vector3(68, Y + 0.5, -37.9), Vector3(4, 1.0, 0.15), &"wood")
	box("BalconyRailS", Vector3(68, Y + 0.5, -42.1), Vector3(4, 1.0, 0.15), &"wood")
	var d5: NavDoor = nav_door("D05_SurgicalDoors", Vector3(75, Y + 1.4, -62), Vector3(3.0, 2.8, 0.4))
	buy_door(&"D05", "surgical ward doors", 1250, [&"Z05", &"Z04"], [d5], Vector3(75, Y + 1.4, -61.2))
	area("Wing", Vector3(68.2, -2.5, -62), Vector3(82, 2.0, -8))
	area("Balcony", Vector3(66, -2.5, -42), Vector3(68.2, 2.0, -38))
	nav_areas.clear()
	nav_areas.append(AABB(Vector3(68.2, -3.0, -62.0), Vector3(17.8, 6.5, 54.0)))
	nav_areas.append(AABB(Vector3(66.0, -3.0, -43.0), Vector3(2.2, 6.5, 6.0)))
	mark(&"perk", "Perk_PackMule", Vector3(71.2, Y, -32), "Pack Mule Cream Soda", true)
	mark(&"box", "Box_Z04", Vector3(71.2, Y, -28.5), "Relic Box (nurse station)")
	wall_buy(&"model37", Vector3(73.2, Y + 1.5, -50), PI * 0.5).name = "WallBuy_Model37"  # VESPER_PEAK §5.1
	mark(&"trap", "T1_ElectroTherapy", Vector3(75, Y, -45), "Electro-Therapy Corridor (15 m)", true)
	mark(&"trap", "T1_Console", Vector3(76.8, Y + 1.2, -36), "T1 console (1000)", true)
	mark(&"part", "Part_Lens_B", Vector3(80.5, Y, -41), "Conduit Lens (option B)")
	mark(&"secret", "S1_Mirror_R7", Vector3(81.8, Y + 1.4, -30), "room 7 mirror (S1 switch)")
	mark(&"music_box", "MB2_Room12", Vector3(80.5, Y, -53), "music box #2 (under the bed)")
	mark(&"lore", "L04", Vector3(71.2, Y + 1.1, -26.8), "nurse's log")
	mark(&"ee", "EE_Room3_Notation", Vector3(81.8, Y + 1.5, -18.5), "Choir notation (room 3)")
	for z: float in [-14.0, -26.0, -38.0, -50.0, -59.0]:
		lamp(Vector3(75, Y + 3.4, z), Color(0.8, 0.95, 1.0), 1.0, 9.0)
	ambience(Vector3(75, Y + 2, -35), &"interior_hum")
	occluder("Occ_Floor", Vector3(76, Y - 1.5, -35), Vector3(12, 2, 54))


# --- Step 13 art pass (13B): the patient corridor, nurse station, rooms 3 / 7 / 9 / 12, balcony ---


func dress() -> void:
	trim = "military"
	furnish = "ward"
	var cold: Color = Color(0.82, 0.95, 1.0)
	skin("NurseDesk", &"desk", Vector3.ZERO, PI / 2.0)
	skin("Wheelchair", &"wheelchair", Vector3.ZERO, 0.6)
	for r: String in ROOMS:
		var zc: float = float(ROOMS[r])
		skin("%s_Bed" % r, &"bed", Vector3(0, 0, 0), PI / 2.0)
		prop(&"chair", Vector3(78.0, Y, zc - 1.4), 0.5)
		decal(&"grime", Vector3(80, Y + 0.05, zc), Vector2(3, 3), Vector3.UP, zc)
		decal(&"tally", Vector3(81.75, Y + 1.5, zc - 1.0), Vector2(1.0, 1.0), Vector3.LEFT, 0.0, Color(1, 1, 1, 0.55))
		signage("%s" % r.trim_prefix("R"), Vector3(76.95, Y + 2.7, zc), -PI / 2.0, 40, Color(0.2, 0.18, 0.16))
	# Nurse station clutter, cabinets, gurneys along the corridor.
	prop(&"cabinet", Vector3(70.5, Y, -24.6), PI / 2.0)
	prop(&"filing_cabinet", Vector3(70.4, Y, -30.0), PI / 2.0)
	prop(&"book_pile", Vector3(71.2, Y + 1.1, -28.2), 0.3)
	prop(&"gurney", Vector3(76.3, Y, -20.0), 0.08)
	prop(&"wheelchair", Vector3(76.1, Y, -56.0), 2.6)
	prop(&"gas_tank", Vector3(73.5, Y, -58.5), 0.0)
	prop(&"gas_tank", Vector3(73.8, Y, -58.9), 0.0, null, Vector3(0, 0, 0.15))
	signage("STATION DE SOINS · NURSE STATION", Vector3(73.0 - 0.21, Y + 2.8, -28), PI / 2.0, 22, Color(0.9, 0.9, 0.84))
	signage("ELEKTROTHERAPIE  —  NICHT BETRETEN", Vector3(76.95, Y + 3.0, -45), -PI / 2.0, 22, Color(0.95, 0.8, 0.2))
	decal(&"hazard_stripes", Vector3(75, Y + 0.05, -37.6), Vector2(3.6, 0.6), Vector3.UP)
	decal(&"hazard_stripes", Vector3(75, Y + 0.05, -52.4), Vector2(3.6, 0.6), Vector3.UP)
	decal(&"blood", Vector3(75.2, Y + 0.05, -44), Vector2(1.6, 1.6), Vector3.UP, 1.0)
	decal(&"claws", Vector3(73.25, Y + 1.2, -42.5), Vector2(1.0, 1.2), Vector3.RIGHT)
	# Vignette 3: room 3 walls covered in the Choir's melody, drawn in charcoal.
	var v: Node3D = vignette(
		"V03_Room3Notation", Vector3(79.5, Y, -18), "room 3: the Choir's melody in charcoal on every wall"
	)
	for i: int in 3:
		decal(
			&"notation",
			Vector3(81.75, Y + 0.9 + i * 0.95, -18.6 + (i % 2) * 1.1),
			Vector2(1.6, 1.0),
			Vector3.LEFT,
			0.0,
			Color(1, 1, 1, 0.9)
		)
		decal(&"notation", Vector3(78.0 + i * 1.3, Y + 1.0 + (i % 2) * 1.2, -16.25), Vector2(1.4, 1.0), Vector3.FORWARD)
		decal(&"notation", Vector3(78.0 + i * 1.3, Y + 1.4 - (i % 2) * 0.6, -19.75), Vector2(1.4, 1.0), Vector3.BACK)
	prop(&"book_pile", Vector3(1.2, 0, 0.8), 0.6, v)
	deco("V03_Charcoal", v.position + Vector3(0.6, 0.02, 1.2), Vector3(0.1, 0.03, 0.02), &"black")
	# Room 7: the mirror that does not reflect zombies (S1 switch marker is at the wall).
	prop(&"mirror", Vector3(81.95, Y - 0.2, -30), -PI / 2.0)
	# Room 12: music box under the bed; Room 9: the Lens part.
	prop(&"trunk", Vector3(80.8, Y, -38.8), 0.2)
	# Fluorescent tubes (military, flickering) over the corridor — two shadowed.
	var zs: Array[float] = [-14.0, -26.0, -38.0, -50.0, -59.0]
	for i: int in zs.size():
		var pat: PoweredLight.Pattern = PoweredLight.Pattern.FLICKER if i % 2 == 0 else PoweredLight.Pattern.BUZZ
		fixture_light(&"fluoro", Vector3(75, Y + 3.7, zs[i] + 1.5), cold, 0.6, 7.0, pat, true, 30 if i == 2 else 0)
	for r: String in ROOMS:
		fixture_light(
			&"caged_bulb",
			Vector3(79.5, Y + 3.8, float(ROOMS[r])),
			Color(1.0, 0.8, 0.55),
			1.1,
			7.5,
			PoweredLight.Pattern.NONE,
			true
		)
	# Sunroom balcony: frost, snow drifting in.
	decal(&"frost", Vector3(68, Y + 0.05, -40), Vector2(3.5, 3.5))
	fx(AtmosFx.Kind.SNOW_DRIFT, Vector3(68, Y + 2.0, -40), Vector3(1.5, 0.6, 1.5), Vector3.LEFT)
	fx(AtmosFx.Kind.DUST, Vector3(75, Y + 2.0, -35), Vector3(1.5, 1.4, 25))
	reverb(&"Reverb_Room", Vector3(68.2, -2.5, -62), Vector3(82, 2.0, -8))
	ambience(Vector3(75, Y + 3.2, -45), &"lab_hum")
