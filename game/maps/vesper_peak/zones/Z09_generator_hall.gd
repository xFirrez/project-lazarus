# Z09 Generator Hall (VESPER_PEAK §3 Z09), y -18: the D09 incline (from the Boiler House), a
# 28 x 23 m hall (x -34..-6, z -64..-41) with three generators and the raised control booth
# (+3 m, one stair) holding the MAIN POWER SWITCH. D10 (north-east, Morgue tunnels) and D14 (east,
# reactor service shaft) are on its boundary. 2 vents, 2 floor grates, a door burst.
extends VesperZone

const Y: float = -18.0


func build() -> void:
	corridor("D09Incline", Vector3(-27.5, -13.0, -28.2), Vector3(-27.5, Y, -41.0), 3.0, 3.0, &"concrete")
	room(
		"Hall",
		Vector3(-34, Y, -64),
		Vector3(-6, (Y) + (7.0), -41),
		{
			"N": [door_hole(-27.5, 3.0, 3.0), door_hole(-14, 3.0, 3.0)],
			"E": [door_hole(-42.5, 2.6, 2.8)],
			"W": [[-48.0, 1.4, 0.0, 1.0]],
			"S": [[-20.0, 1.4, 0.0, 1.0], [-8.0, 1.6, 0.0, 2.6]]
		},
		[&"concrete", &"stone"]
	)
	for i: int in 3:
		box("Generator%d" % (i + 1), Vector3(-26 + i * 7.0, Y + 2.3, -52), Vector3(3.6, 4.6, 7.0), &"olive")
	box_mm("Booth", Vector3(-33.8, Y, -63.8), Vector3(-26.0, Y + 3.0, -57.0), &"concrete")
	box_mm("BoothWallN", Vector3(-33.8, Y + 3.0, -57.2), Vector3(-29.0, Y + 4.1, -57.0), &"metal")
	box_mm("BoothWallE", Vector3(-26.2, Y + 3.0, -63.8), Vector3(-26.0, Y + 4.1, -59.2), &"metal")
	stairs("BoothStair", Vector3(-27.5, Y, -54.0), Vector3(-27.5, Y + 3.0, -57.0), 2.6, &"metal")
	# The control booth's only entrance is the north stair (x -29..-26).
	vent("VentW", Vector3(-34, Y, -48), Vector3.LEFT)
	vent("VentS", Vector3(-20, Y, -64), Vector3.FORWARD)
	climb("Grate1", Vector3(-17.0, Y - 3.2, -46.5), Vector3(-17.0, Y, -45.0), 3)
	climb("Grate2", Vector3(-9.0, Y - 3.2, -58.0), Vector3(-9.0, Y, -56.5), 3)
	for g: Vector3 in [Vector3(-17.0, Y + 0.01, -45.8), Vector3(-9.0, Y + 0.01, -57.2)]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(1.6, 0.02, 1.6)
		mi.mesh = bm
		mi.position = g
		mi.material_override = _mat(&"metal")
		geometry.add_child(mi)
	closet("Burst", Vector3(-8, Y, -64), Vector3.FORWARD)
	var sw: PowerSwitch = PowerSwitch.new()
	sw.name = "PWR_MainSwitch"
	sw.position = Vector3(-31.5, Y + 4.2, -63.4)
	sw.use_radius = 2.2
	gameplay.add_child(sw)
	box("LeverBank", Vector3(-31.5, Y + 3.7, -63.6), Vector3(2.4, 1.4, 0.3), &"brass")
	var d10: NavDoor = nav_door("D10_BlastCurtain", Vector3(-14, Y + 1.4, -41), Vector3(3.0, 2.8, 0.4))
	buy_door(&"D10", "tunnel blast curtain", 1000, [&"Z09", &"Z10"], [d10], Vector3(-14, Y + 1.4, -40.2))
	var d14: NavDoor = nav_door("D14_CatwalkHatch", Vector3(-6, Y + 1.4, -42.5), Vector3(0.4, 2.8, 2.6))
	buy_door(&"D14", "reactor catwalk hatch", 2000, [&"Z13", &"Z09"], [d14], Vector3(-6.8, Y + 1.4, -42.5))
	area("Incline", Vector3(-29, -19, -41), Vector3(-26, -10, -28))
	area("Hall", Vector3(-34, -22, -64), Vector3(-6, -11, -41))
	nav_areas.clear()
	nav_areas.append(AABB(Vector3(-37.6, -22.0, -67.6), Vector3(31.6, 8.4, 26.6)))
	nav_areas.append(AABB(Vector3(-29.6, -19.0, -41.0), Vector3(4.2, 7.0, 9.0)))  # incline z -41..-32
	mark(&"perk", "Perk_TwinFire", Vector3(-10, Y, -43), "Twin-Fire Root Beer", true)
	mark(&"lore", "L09", Vector3(-29, Y + 3.0, -60), "engineering report")
	mark(&"reel", "R04", Vector3(-33, Y + 3.0, -60), "audio reel R04")
	mark(&"ee", "EE_TallyMarks", Vector3(-33.6, Y + 4.0, -61), "chalk tally (booth wall)")
	for i: int in 3:
		lamp(Vector3(-26 + i * 7.0, Y + 6.0, -46), Color(1.0, 0.85, 0.6), 1.4, 14.0, true, 0.05)
	lamp(Vector3(-30, Y + 5.5, -60), Color(1.0, 0.1, 0.05), 0.6, 8.0, false)  # emergency red
	ambience(Vector3(-20, Y + 3, -52), &"generator_hall")
	occluder("Occ_Rock", Vector3(-20, Y + 9.5, -52.5), Vector3(28, 4, 23))
