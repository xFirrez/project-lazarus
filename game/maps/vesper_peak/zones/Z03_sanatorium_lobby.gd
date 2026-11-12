# Z03 Sanatorium Lobby (VESPER_PEAK §3 Z03): the covered walkway from D01 (flat, then a 25° ramp
# down 8 m) and the Belle Époque lobby 30 x 22 m (x 38..68, z -14..8, floor y -8) with a north
# mezzanine (+4 m) reached by two side stairs, the grand staircase up to a landing (+6 m) where D03
# leads into the East Wing, terrace doors D04 (south, to the Courtyard), service door D08 (west,
# basement stairwell to the Morgue). 3 ground windows, 1 mezzanine window, a door-burst office.
extends VesperZone

const Y: float = -8.0
const MEZZ: float = -4.0


func build() -> void:
	# Walkway (D01 -> lobby west door).
	corridor("Walk", Vector3(13.2, 0, -3), Vector3(21, 0, -3), 3.2, 3.3, &"concrete")
	corridor("WalkRamp", Vector3(21, 0, -3), Vector3(38, Y, -3), 3.2, 3.3, &"concrete")
	room(
		"Lobby",
		Vector3(38, Y, -14),
		Vector3(68, (Y) + (9.0), 8),
		{
			"W": [door_hole(-3, 3.2, 3.4), door_hole(-11, 2.4, 2.8), win_hole(-7)],
			"N": [win_hole(46), win_hole(54), [52.0 - 0.0, 1.4, 4.9, 6.1]],
			"E": [[-11.0, 2.4, 6.0, 8.8]],
			"S": [door_hole(52, 3.0, 3.0), [62.0, 1.6, 0.0, 2.6]],
		},
		[&"marble", &"plaster"]
	)
	# Fix: the mezzanine window shares x 52 with nothing at ground level (ground windows 46 / 54).
	box("Mezzanine", Vector3(50, MEZZ - 0.2, 6.1), Vector3(24, 0.4, 4.2), &"wood")
	# Rail along the mezzanine edge with gaps where the two side stairs (running along it) arrive.
	for r: Array in [[42.75, 9.5], [52.25, 4.5], [59.75, 4.5]]:
		box("MezzRail_%d" % int(r[0]), Vector3(float(r[0]), MEZZ + 0.5, 4.1), Vector3(float(r[1]), 1.0, 0.15), &"wood")
	stairs("MezzStairW", Vector3(41.0, Y, 3.0), Vector3(49.0, MEZZ, 3.0), 2.0)
	stairs("MezzStairE", Vector3(63.0, Y, 3.0), Vector3(55.0, MEZZ, 3.0), 2.0)
	# Grand staircase (east) -> landing -> D03 (Z04).
	stairs("Grand", Vector3(65.4, Y, 6.5), Vector3(65.4, -2.0, -8.0), 4.8, &"marble")
	box_mm("Landing", Vector3(63, -2.5, -14), Vector3(68, -2.0, -8), &"marble")
	box("LandingRail", Vector3(63.1, -1.5, -11), Vector3(0.15, 1.0, 6), &"wood")
	box("Chandelier", Vector3(66.6, -1.4, -9.3), Vector3(1.6, 1.2, 1.6), &"brass")
	box("ReceptionDesk", Vector3(53, Y + 0.55, -6), Vector3(5, 1.1, 1.2), &"wood")
	box("Clock", Vector3(39, Y + 1.3, 6.8), Vector3(0.8, 2.6, 0.6), &"wood")
	window("W1", Vector3(46, Y, 8), Vector3.BACK)
	window("W2", Vector3(54, Y, 8), Vector3.BACK)
	window("W3", Vector3(38, Y, -7), Vector3.LEFT)
	window("WM", Vector3(52, MEZZ, 8), Vector3.BACK, 2)
	closet("Office", Vector3(62, Y, -14), Vector3.FORWARD)
	# Terrace (D04) is the Courtyard's; the lobby scene owns the doors on its boundary.
	corridor("Terrace", Vector3(52, Y, -14.2), Vector3(52, Y, -20), 3.0, 3.2, &"marble")
	var d3: NavDoor = nav_door("D03_Chandelier", Vector3(68, -0.6, -11), Vector3(0.4, 2.8, 2.4))
	buy_door(&"D03", "fallen chandelier", 1000, [&"Z04", &"Z03"], [d3], Vector3(67.2, -0.6, -11))
	var d4: NavDoor = nav_door("D04_Terrace", Vector3(52, Y + 1.5, -14), Vector3(3.0, 3.0, 0.4))
	buy_door(&"D04", "iced terrace doors", 1250, [&"Z06", &"Z03"], [d4], Vector3(52, Y + 1.5, -13.2))
	var d8: NavDoor = nav_door("D08_ServiceDoor", Vector3(38, Y + 1.4, -11), Vector3(0.4, 2.8, 2.4))
	buy_door(&"D08", "basement service door", 1250, [&"Z10", &"Z03"], [d8], Vector3(38.8, Y + 1.4, -11))
	area("Walkway", Vector3(13.2, -8.5, -4.6), Vector3(38, 4.0, -1.4))
	area("Lobby", Vector3(38, -8.5, -14), Vector3(68, 1.0, 8))
	nav_areas.clear()
	nav_areas.append(AABB(Vector3(13.2, -9.5, -5.0), Vector3(24.8, 13.0, 17.0)))  # walkway + W_U2 bay
	nav_areas.append(AABB(Vector3(38, -9.5, -20.0), Vector3(30.2, 9.0, 32.0)))  # lobby + terrace + office
	mark(&"perk", "Perk_Quickdraw", Vector3(40, Y, 1.5), "Quickdraw Fizz", true)
	mark(&"wallbuy", "WB_MP40", Vector3(44, Y + 1.5, -13.8), "MP40 wall-buy (1000)")
	mark(&"box", "Box_Z03", Vector3(49.5, Y, -6), "Relic Box START location")
	mark(&"ee", "EE_Guestbook", Vector3(54.5, Y + 1.1, -6), "guestbook (S1 clue)")
	mark(&"secret", "S1_Bookcase", Vector3(39, MEZZ, 7.6), "Director's Office entrance (S1)")
	mark(&"lore", "L02", Vector3(51, Y + 1.1, -6), "1908 brochure")
	mark(&"reel", "R02", Vector3(40.5, MEZZ, 7.0), "audio reel R02 (mezzanine desk)")
	# S1 Director's Office (behind the mezzanine bookcase; the room itself is built in Step 13).
	mark(&"lore", "L13", Vector3(36.0, MEZZ, 6.0), "Haemmer's Requiem Test order (S1)")
	mark(&"ee", "S1_FreeTonicCrate", Vector3(35.0, MEZZ, 4.5), "free tonic crate (S1)")
	mark(&"lore", "L03", Vector3(56, MEZZ, 7.4), "Group Vesper memo")
	lamp(Vector3(53, -1.0, -3), Color(1.0, 0.75, 0.45), 2.5, 22.0, true, 0.25)
	lamp(Vector3(45, -1.5, 6), Color(1.0, 0.75, 0.45), 1.2, 10.0)
	lamp(Vector3(25, 2.0, -3), Color(0.9, 0.85, 0.7), 0.8, 9.0)
	ambience(Vector3(53, -5, -3), &"interior_wind")
	occluder("Occ_Floor", Vector3(53, Y - 1.5, -3), Vector3(30, 2, 22))
