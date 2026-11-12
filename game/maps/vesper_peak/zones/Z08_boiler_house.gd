# Z08 Boiler House — Maintenance North (VESPER_PEAK §3 Z08), y -13: the stair corridor down from
# D07 (Courtyard), a 24 x 18 m boiler room (x -46..-22, z -28..-10) with two boilers and a north
# catwalk loop (+3.5 m, stairs at both ends), the foreman's window, a coal-chute drop and 2 vents.
# D09 (south) opens the inclined tunnel down to the Generator Hall.
extends VesperZone

const Y: float = -13.0


func build() -> void:
	corridor("D07Stair", Vector3(-10.2, -8.0, -24), Vector3(-22.0, Y, -24), 2.8, 3.0, &"concrete")
	room(
		"Boiler",
		Vector3(-46, Y, -28),
		Vector3(-22, (Y) + (7.0), -10),
		{
			"E": [door_hole(-24, 2.8, 3.0)],
			"S": [door_hole(-27.5, 3.0, 3.0), [-40.0, 1.4, 0.0, 1.0]],
			"W": [[-24.0, 1.4, 0.0, 1.0]],
			"N": [win_hole(-36)]
		},
		[&"concrete", &"stone"]
	)
	box("Boiler1", Vector3(-38, Y + 3.45, -19.5), Vector3(5, 6.9, 5), &"metal")
	box("Boiler2", Vector3(-30, Y + 3.45, -19.5), Vector3(5, 6.9, 5), &"metal")
	box_mm("Catwalk", Vector3(-45.8, Y + 3.1, -12.6), Vector3(-22.2, Y + 3.5, -10.2), &"metal")
	box("CatwalkRail", Vector3(-34, Y + 4.0, -12.65), Vector3(16.0, 1.0, 0.1), &"metal")
	stairs("CatStairW", Vector3(-44.5, Y, -19.0), Vector3(-44.5, Y + 3.5, -12.6), 2.6, &"metal")
	stairs("CatStairE", Vector3(-23.5, Y, -19.0), Vector3(-23.5, Y + 3.5, -12.6), 2.6, &"metal")
	box("ForemanDesk", Vector3(-27, Y + 0.5, -26.4), Vector3(2.4, 1.0, 1.0), &"wood")
	window("W_Foreman", Vector3(-36, Y, -10), Vector3.BACK)
	vent("VentW", Vector3(-46, Y, -24), Vector3.LEFT)
	vent("VentS", Vector3(-40, Y, -28), Vector3.FORWARD)
	drop("CoalChute", Vector3(-34, Y + 4.2, -26.0), Vector3(-34, Y, -23.5), ZombieSpawner.Kind.VENT, 2)
	var d9: NavDoor = nav_door("D09_Bulkhead", Vector3(-27.5, Y + 1.4, -28), Vector3(3.0, 2.8, 0.4))
	buy_door(&"D09", "maintenance bulkhead", 1000, [&"Z09", &"Z08"], [d9], Vector3(-27.5, Y + 1.4, -27.2))
	area("Stair", Vector3(-22, -14, -25.6), Vector3(-10, -4, -22.4))
	area("Boiler", Vector3(-46, -14, -28), Vector3(-22, -6, -10))
	nav_areas.clear()
	nav_areas.append(AABB(Vector3(-50.0, -14.5, -32.0), Vector3(28.0, 8.0, 26.0)))
	nav_areas.append(AABB(Vector3(-22.0, -14.0, -26.0), Vector3(8.4, 9.0, 4.0)))  # D07 stair (x -22..-13.6)
	mark(&"wallbuy", "WB_GreaseGun", Vector3(-45.8, Y + 1.5, -23), "M3 Grease Gun wall-buy (1000)")
	mark(&"box", "Box_Z08", Vector3(-26, Y, -15), "Relic Box (boiler house)")
	mark(&"part", "Part_Stock_A", Vector3(-40, Y + 3.5, -11.2), "Conduit Stock (option A)")
	mark(&"hazard", "H1_FuelDrums_Z08", Vector3(-42, Y, -26), "fuel drums")
	mark(&"lore", "L08", Vector3(-27, Y + 1.0, -26.4), "foreman's letter")
	lamp(Vector3(-34, Y + 1.5, -17), Color(1.0, 0.45, 0.15), 2.0, 14.0, false)  # furnace glow
	lamp(Vector3(-28, Y + 6.0, -20), Color(1.0, 0.8, 0.5), 1.0, 12.0)
	ambience(Vector3(-34, Y + 3, -19), &"boiler_room")
	occluder("Occ_Rock", Vector3(-34, Y + 9.5, -19), Vector3(24, 4, 18))
