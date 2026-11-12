# Z10 Morgue & South Tunnels — Maintenance South (VESPER_PEAK §3 Z10), y -16: the service
# stairwell down from D08 (Lobby), the 18 x 12 m morgue (x 4..22, z -22..-10) with its drawer
# wall, the west tunnel + south tunnel to D10 (Generator Hall) and the east tunnel (Steam Purge
# trap section) to the lab blast door D11. 2 drawer bursts, 3 tunnel vents, a floor grate.
extends VesperZone

const Y: float = -16.0


func build() -> void:
	corridor("D08Stair", Vector3(37.8, -8.0, -11), Vector3(22.0, Y, -11), 2.8, 3.0, &"concrete")
	room(
		"Morgue",
		Vector3(4, Y, -22),
		Vector3(22, (Y) + (4.5), -10),
		{
			"E": [door_hole(-11, 2.8, 3.0), door_hole(-19.5, 3.0, 3.0)],
			"W": [door_hole(-16, 3.0, 3.0)],
			"N": [[8.0, 1.6, 0.0, 2.6], [14.0, 1.6, 0.0, 2.6]]
		},
		[&"tile", &"tile"]
	)
	for i: int in 3:
		box("AutopsyTable%d" % i, Vector3(9 + i * 4.5, Y + 0.5, -17), Vector3(2.0, 1.0, 1.0), &"metal")
	box_mm("DrawerWall", Vector3(17.0, Y, -10.4), Vector3(21.6, Y + 2.6, -10.2), &"metal")
	# West tunnel (x -15.5..4) and south tunnel (x -15.5..-12.5) to the D10 ramp.
	room(
		"TunnelW",
		Vector3(-15.5, Y, -17.5),
		Vector3(4, (Y) + (3.5), -14.5),
		{"E": false, "S": [door_hole(-14, 3.0, 3.0)], "N": [[-6.0, 1.4, 0.0, 1.0]]},
		[&"concrete", &"concrete"]
	)
	room(
		"TunnelS",
		Vector3(-15.5, Y, -34),
		Vector3(-12.5, (Y) + (3.5), -17.5),
		{"N": false, "S": false, "W": [[-28.0, 1.4, 0.0, 1.0]]},
		[&"concrete", &"concrete"]
	)
	corridor("D10Ramp", Vector3(-14, Y, -34), Vector3(-14, -18.0, -41.0), 3.0, 3.5, &"concrete")
	# East tunnel (x 22..60) to D11; the ramp down to the labs is Z11's.
	room(
		"TunnelE",
		Vector3(22, Y, -21),
		Vector3(60, (Y) + (3.5), -18),
		{"W": false, "S": [door_hole(58.5, 3.0, 3.0)], "N": [[40.0, 1.4, 0.0, 1.0]]},
		[&"concrete", &"concrete"]
	)
	box_mm("FloodedSection", Vector3(30, Y, -21), Vector3(44, Y + 0.05, -18), &"tile")
	closet("Drawer1", Vector3(8, Y, -10), Vector3.BACK)
	closet("Drawer2", Vector3(14, Y, -10), Vector3.BACK)
	vent("VentW", Vector3(-6, Y, -14.5), Vector3.BACK)
	vent("VentS", Vector3(-15.5, Y, -28), Vector3.LEFT)
	vent("VentE", Vector3(40, Y, -18), Vector3.BACK)
	climb("Grate", Vector3(19.0, Y - 3.2, -20.0), Vector3(19.0, Y, -18.6), 3)
	var d11: NavDoor = nav_door("D11_LabBlastDoor", Vector3(50, Y + 1.4, -19.5), Vector3(0.4, 2.8, 3.0))
	buy_door(&"D11", "lab security blast door", 1500, [&"Z11", &"Z10"], [d11], Vector3(49.2, Y + 1.4, -19.5))
	area("Stair", Vector3(22, -17, -12.4), Vector3(38, -7, -9.6))
	area("Morgue", Vector3(4, -20, -22), Vector3(22, -11, -10))
	area("TunnelW", Vector3(-15.5, -17, -17.5), Vector3(4, -12, -14.5))
	area("TunnelS", Vector3(-15.5, -19, -41), Vector3(-12.5, -12, -17.5))
	area("TunnelE", Vector3(22, -20, -21), Vector3(60, -12, -18))
	nav_areas.clear()
	nav_areas.append(AABB(Vector3(4.0, -20.0, -22.0), Vector3(18.0, 6.0, 15.5)))  # morgue + drawers
	nav_areas.append(AABB(Vector3(-12.2, -17.5, -17.8), Vector3(16.2, 3.3, 6.8)))  # west tunnel
	nav_areas.append(AABB(Vector3(-19.0, -17.5, -34.0), Vector3(6.8, 3.3, 23.0)))  # south tunnel
	nav_areas.append(AABB(Vector3(-19.0, -19.5, -41.0), Vector3(6.8, 5.3, 7.0)))  # D10 ramp
	nav_areas.append(AABB(Vector3(22.0, -20.0, -21.2), Vector3(38.2, 5.8, 7.2)))  # east tunnel (+grate)
	nav_areas.append(AABB(Vector3(22.0, -17.0, -13.0), Vector3(16.0, 10.0, 4.0)))  # D08 stairwell
	wall_buy(&"revolver", Vector3(4.2, Y + 1.5, -20), PI * 0.5).name = "WallBuy_Revolver"  # VESPER_PEAK §5.1
	mark(&"trap", "T2_SteamPurge", Vector3(38, Y, -19.5), "Steam Purge (20 m tunnel)", true)
	mark(&"trap", "T2_Console", Vector3(27, Y + 1.2, -18.2), "T2 console (1000)", true)
	mark(&"ee", "EE_MorgueDrawers", Vector3(19.3, Y + 1.3, -10.6), "drawer wall (stage 2b)")
	mark(&"ee", "EE_ChainedDrawer", Vector3(21.0, Y + 0.6, -10.6), "the chained drawer")
	for i: int in 4:
		mark(
			&"ee",
			"EE_Symbol_%d" % (i + 1),
			[
				Vector3(4.2, Y + 2.0, -12),
				Vector3(-10, Y + 2.0, -14.7),
				Vector3(-15.3, Y + 2.0, -24),
				Vector3(46, Y + 2.0, -18.2)
			][i],
			"luminous symbol %d" % (i + 1)
		)
	mark(&"lore", "L10", Vector3(9, Y + 1.0, -17), "morgue intake ledger")
	mark(&"reel", "R05", Vector3(13.5, Y + 1.0, -17), "audio reel R05")
	lamp(Vector3(13, Y + 4.0, -16), Color(0.6, 1.0, 0.6), 1.0, 12.0, true, 0.3)
	for x: float in [-8.0, 30.0, 44.0]:
		lamp(Vector3(x, Y + 3.0, -16.0 if x < 0 else -19.5), Color(0.6, 1.0, 0.6), 0.6, 8.0, true, 0.3)
	lamp(Vector3(-14, Y + 3.0, -28), Color(0.6, 1.0, 0.6), 0.6, 8.0, true, 0.3)
	ambience(Vector3(13, Y + 2, -16), &"tunnel_drip")
