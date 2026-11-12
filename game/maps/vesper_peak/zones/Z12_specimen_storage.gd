# Z12 Specimen Storage (VESPER_PEAK §3 Z12), y -28: a cramped 28 x 17 m cold store (x 63..91,
# z -46..-29) of shelving; the freight lift bottom station (shaft in the north-west corner,
# exit east), the laundry chute exit (linen pile, north-east), D12 airlock (south, Labs),
# 2 vents, a shaft drop and a window.
extends VesperZone

const Y: float = -28.0


func build() -> void:
	room(
		"Store",
		Vector3(63, Y, -46),
		Vector3(91, (Y) + (6.0), -29),
		{"S": [door_hole(80, 3.0, 3.0)], "N": [[75.0, 1.4, 0.0, 1.0], [85.0, 1.4, 0.0, 1.0]], "E": [win_hole(-36)]},
		[&"concrete", &"tile"],
		false,
		false
	)
	for i: int in 4:
		box("Shelf%d" % i, Vector3(72 + i * 4.5, Y + 1.25, -39), Vector3(0.8, 2.5, 8.0), &"metal")
	box_mm("LinenPile", Vector3(86, Y, -33), Vector3(90, Y + 0.3, -29.6), &"sandbag")
	window("W_Gallery", Vector3(91, Y, -36), Vector3.RIGHT)
	vent("VentN1", Vector3(75, Y, -29), Vector3.BACK)
	vent("VentN2", Vector3(85, Y, -29), Vector3.BACK)
	drop("ShaftDrop", Vector3(66, Y + 3.2, -40.0), Vector3(66, Y, -37.0), ZombieSpawner.Kind.VENT, 4)
	# Floor with the lift shaft footprint (x 63..68, z -34..-29) left open: the platform is the
	# floor there; below it is a pit nobody reaches (gates), so navigation never enters the shaft.
	box_mm("StoreFloorS", Vector3(62.8, Y - 0.5, -46.2), Vector3(91.2, Y, -34.2), &"concrete")
	box_mm("StoreFloorE", Vector3(68.2, Y - 0.5, -34.2), Vector3(91.2, Y, -28.8), &"concrete")
	box_mm("StoreRoofS", Vector3(62.8, Y + 6.0, -46.2), Vector3(91.2, Y + 6.5, -34.2), &"tile")
	box_mm("StoreRoofE", Vector3(68.2, Y + 6.0, -34.2), Vector3(91.2, Y + 6.5, -28.8), &"tile")
	box_mm("ShaftPit", Vector3(62.8, Y - 3.5, -34.2), Vector3(68.2, Y - 3.0, -28.8), &"concrete")
	area("Store", Vector3(63, -29, -46), Vector3(91, -22, -29))
	nav_areas.clear()
	nav_areas.append(AABB(Vector3(63.0, -29.5, -46.0), Vector3(31.6, 6.0, 20.8)))
	mark(&"perk", "Perk_Bullseye", Vector3(89.5, Y, -44), "Bullseye Bitters", true)
	mark(&"box", "Box_Z12", Vector3(70, Y, -44.5), "Relic Box (specimen storage)")
	mark(&"part", "Part_Coil_B", Vector3(88, Y, -40), "Conduit Coil (option B)")
	mark(&"lore", "L12", Vector3(76.5, Y + 1.0, -34.5), "specimen catalogue")
	mark(&"reel", "R07", Vector3(81, Y + 1.0, -34.5), "audio reel R07")
	mark(&"ee", "EE_ObservationGlass", Vector3(64, Y + 1.5, -44), "observation glass (reactor view; Step 13)")
	for p: Vector3 in [Vector3(70, Y + 5.5, -36), Vector3(84, Y + 5.5, -40)]:
		lamp(p, Color(0.8, 0.95, 1.0), 1.0, 12.0, true, 0.1)
	lamp(Vector3(65, Y + 3.0, -44), Color(0.35, 1.0, 0.45), 0.8, 8.0, false)  # reactor glow
	ambience(Vector3(77, Y + 2, -38), &"refrigeration")
