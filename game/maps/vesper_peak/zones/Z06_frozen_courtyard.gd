# Z06 Frozen Courtyard (VESPER_PEAK §3 Z06), exterior at y -8: 76 x 58 m (x -10..66, z -78..-20)
# between the station, the sanatorium and the mountain. The D02 cargo ramp (from Z01), the D04
# terrace (from Z03), the frozen fountain (training loop ≈ 70 m), the motor pool + Ironhide garage
# (west), the greenhouse shed with a window (south), the freight lift shed (east; LFT to Z12), the
# snowbank under the East Wing balcony, 6 risers and 2 wall climbs. Doors on its boundary: D06
# (south gate to the Comms Array road) and D07 (west, Boiler House). Low outer walls (2.6 m) let
# zombies vault in but stop players.
extends VesperZone

const Y: float = -8.0
const LIFT_C: Vector3 = Vector3(65.5, -8.0, -31.5)


func build() -> void:
	corridor("CargoRamp", Vector3(6, 0, -8.4), Vector3(6, Y, -25.6), 2.8, 3.2, &"concrete")
	# Seal the wedge under the ramp's last 5.6 m (inside the courtyard).
	box_mm("CargoRampSideW", Vector3(4.0, Y, -25.6), Vector3(4.6, -5.2, -20.2), &"concrete")
	box_mm("CargoRampSideE", Vector3(7.4, Y, -25.6), Vector3(8.0, -5.2, -20.2), &"concrete")
	# Ground, with the freight lift shaft (x 63..68, z -34..-29) cut out.
	box_mm("Ground", Vector3(-10.2, Y - 1.0, -78.2), Vector3(63.0, Y, -19.8), &"snow")
	box_mm("GroundLiftS", Vector3(63.0, Y - 1.0, -78.2), Vector3(66.2, Y, -34.2), &"snow")
	box_mm("GroundLiftN", Vector3(63.0, Y - 1.0, -28.8), Vector3(66.2, Y, -19.8), &"snow")
	# Boundary: north = sanatorium / station foundations (tall), others low (vaultable by zombies).
	wall_z("WallN", -20, -10.2, 66.2, Y, 7.0, [[6.0, 2.8, 2.55, 6.2], door_hole(52, 3.0, 3.2)], &"facade")
	wall_x("WallW", -10, -78, -20, Y, 2.6, [door_hole(-24, 2.4, 2.6)], &"stone")
	wall_z("WallS", -78, -10.2, 66.2, Y, 2.6, [door_hole(-6, 3.0, 2.8), win_hole(44)], &"stone")
	wall_x("WallE", 66, -78, -20, Y, 5.0, [[-31.5, 4.6, 0.0, 3.0], [-40.0, 12.0, 0.0, 5.0]], &"stone")
	# Fountain (centre), motor pool, garage, greenhouse shed, sandbags, snowbank.
	box("FountainBase", Vector3(28, Y + 1.0, -49), Vector3(7, 2.0, 7), &"ice")
	box("FountainMid", Vector3(28, Y + 2.7, -49), Vector3(3.5, 1.4, 3.5), &"ice")
	box("FountainTop", Vector3(28, Y + 4.2, -49), Vector3(1.2, 1.6, 1.2), &"ice")
	for v: Array in [
		["Truck1", Vector3(2, Y + 1.4, -42), Vector3(2.6, 2.8, 6.0)],
		["Truck2", Vector3(6, Y + 1.4, -54), Vector3(2.6, 2.8, 6.0)],
		["HalfTrack", Vector3(-1, Y + 1.3, -64), Vector3(2.4, 2.6, 5.0)],
		["Jeep", Vector3(12, Y + 1.0, -66), Vector3(2.0, 2.0, 3.4)],
		["SandbagsA", Vector3(18, Y + 0.45, -30), Vector3(6.0, 0.9, 0.8)],
		["SandbagsB", Vector3(40, Y + 0.45, -60), Vector3(0.8, 0.9, 6.0)],
	]:
		box(
			String(v[0]),
			v[1],
			v[2],
			(
				&"olive"
				if String(v[0]).begins_with("T") or String(v[0]).begins_with("H") or String(v[0]).begins_with("J")
				else &"sandbag"
			)
		)
	room(
		"Garage",
		Vector3(-9.6, Y, -36),
		Vector3(-3.0, (Y) + (3.6), -29),
		{"E": false},
		[&"concrete", &"concrete"],
		false
	)
	room(
		"GreenShed",
		Vector3(40, Y, -78),
		Vector3(48, (Y) + (3.0), -72),
		{"N": false, "S": false},
		[&"concrete", &"plaster"],
		false
	)
	window("W_Greenhouse", Vector3(44, Y, -78), Vector3.FORWARD)
	box_mm("Greenhouse", Vector3(30, Y, -74), Vector3(38, Y + 2.0, -66), &"plaster")
	box_mm("Snowbank", Vector3(58, Y, -46), Vector3(66, -6.6, -34), &"snow")
	ramp("SnowbankRamp", Vector3(62, -6.6, -46), Vector3(62, Y, -50), 8.0, &"snow")
	box_mm("Waterfall", Vector3(-10, Y, -74), Vector3(-9.0, Y + 6.0, -66), &"ice")
	# Spawners: risers (round 2+), wall climbs.
	var risers: Array = [
		Vector3(8, Y, -58),
		Vector3(18, Y, -36),
		Vector3(40, Y, -30),
		Vector3(50, Y, -56),
		Vector3(16, Y, -72),
		Vector3(24, Y, -71)
	]
	for i: int in risers.size():
		spawner("Spawn_Z06_R%d" % (i + 1), risers[i], ZombieSpawner.Kind.RISER, 2)
	climb("ClimbW", Vector3(-12.2, Y, -58), Vector3(-8.6, Y, -58))
	climb("ClimbS", Vector3(22, Y, -80.2), Vector3(22, Y, -76.6))
	_lift()
	var d6: NavDoor = nav_door("D06_CheckpointGate", Vector3(-6, Y + 1.4, -78), Vector3(3.0, 2.8, 0.4))
	buy_door(&"D06", "checkpoint gate", 1250, [&"Z07", &"Z06"], [d6], Vector3(-6, Y + 1.4, -77.2))
	var d7: NavDoor = nav_door("D07_BoilerDoor", Vector3(-10, Y + 1.3, -24), Vector3(0.4, 2.6, 2.4))
	buy_door(&"D07", "frozen boiler house door", 1000, [&"Z08", &"Z06"], [d7], Vector3(-9.2, Y + 1.3, -24))
	area("Courtyard", Vector3(-10, -8.5, -78), Vector3(66, 0.0, -20))
	area("CargoRamp", Vector3(4.6, -8.5, -20), Vector3(7.4, 3.0, -8.2))
	area("LiftShed", Vector3(66, -8.5, -34), Vector3(68, -3.0, -29))
	nav_areas.clear()
	nav_areas.append(AABB(Vector3(-13.6, -9.5, -81.6), Vector3(83.6, 3.2, 61.6)))  # courtyard + climb pads
	nav_areas.append(AABB(Vector3(4.0, -9.5, -20.0), Vector3(4.0, 8.0, 6.8)))  # cargo ramp (z -20..-13.2)
	mark(&"perk", "Perk_Ironhide", Vector3(-8.4, Y, -32.5), "Ironhide Stout (garage)", true)
	wall_buy(&"m16", Vector3(-9.75, Y + 1.5, -44), PI * 0.5).name = "WallBuy_M16"  # VESPER_PEAK §5.1
	wall_buy(&"tripmines", Vector3(35, Y + 1.5, -20.2), PI).name = "WallBuy_Tripmines"  # VESPER_PEAK §5.1
	mark(&"box", "Box_Z06", Vector3(-4, Y, -46), "Relic Box (motor pool)")
	mark(&"hazard", "H1_FuelDrums_Z06", Vector3(-6.5, Y, -56), "fuel drums")
	mark(&"hazard", "H2_Icicles_Terrace", Vector3(52, -1.5, -20.6), "icicles above D04")
	mark(&"hazard", "H2_Icicles_Arch", Vector3(6, -1.5, -20.6), "icicles above the ramp arch")
	mark(&"part", "Part_Stock_B", Vector3(34, Y, -72), "Conduit Stock (option B)")
	mark(&"lore", "L06", Vector3(0, Y + 1.0, -38.6), "motor pool requisition")
	mark(&"ee", "EE_FountainShard", Vector3(28, Y + 5.0, -49), "frozen heart shard (stage 2a)")
	mark(&"secret", "S2_Waterfall", Vector3(-8.8, Y, -70), "Ice Grotto behind the waterfall (S2)")
	# S2 Ice Grotto (behind the waterfall; the cave is built in Step 13).
	mark(&"lore", "L14", Vector3(-13.0, Y, -70), "Tomas Brandt's diary (S2)")
	mark(&"music_box", "MB4_Grotto", Vector3(-14.0, Y, -68), "hidden music box variant (S2)")
	mark(&"raven", "Raven_2_Fountain", Vector3(28, Y + 5.2, -48.2), "frozen raven (fountain)")
	mark(&"raven", "Raven_3_Greenhouse", Vector3(34, Y + 1.4, -70), "frozen raven (greenhouse)")
	mark(&"ee", "EE_Coffins", Vector3(-6, Y, -66), "200 coffins vignette")
	for p: Vector3 in [Vector3(4, -3, -46), Vector3(28, -2, -30), Vector3(52, -3, -66), Vector3(28, -3, -70)]:
		lamp(p, Color(0.75, 0.85, 1.0), 1.2, 18.0)
	lamp(Vector3(2, Y + 3.2, -42), Color(1.0, 0.15, 0.1), 0.8, 7.0, false)  # truck beacon
	ambience(Vector3(28, -4, -49), &"exterior_storm")


# Freight lift shed + shaft (LFT): platform x 63..68, z -34..-29; station 0 = Courtyard (top,
# opening west), station 1 = Specimen Storage (bottom, y -28, opening east). Zombies may ride.
func _lift() -> void:
	room("LiftShed", Vector3(62, Y, -35), Vector3(68, (Y) + (3.6), -28), {"W": false}, [&"concrete", &"metal"], false)
	box_mm("ShaftN", Vector3(63, -28.5, -29.2), Vector3(68, Y - 0.2, -28.8), &"metal")
	box_mm("ShaftS", Vector3(63, -28.5, -34.2), Vector3(68, Y - 0.2, -33.8), &"metal")
	box_mm("ShaftW", Vector3(62.8, -28.5, -34), Vector3(63.2, Y - 0.6, -29), &"metal")
	box_mm("ShaftE", Vector3(67.8, -24.6, -34), Vector3(68.2, Y, -29), &"metal")
	var gate0: StaticBody3D = clip("LFT_Gate0", Vector3(63.0, Y + 1.5, -31.5), Vector3(0.3, 3.0, 4.6))
	var gate1: StaticBody3D = clip("LFT_Gate1", Vector3(68.0, -26.5, -31.5), Vector3(0.3, 3.0, 4.6))
	var lift: TraversalMachine = TraversalMachine.new()
	lift.name = "LFT_FreightLift"
	lift.machine_id = &"freight_lift"
	lift.display_name = "freight lift"
	lift.ride_time = 6.0
	lift.cooldown = 20.0
	lift.boarding_delay = 2.0
	lift.ride_cost = 0
	lift.requires_power = true
	lift.allow_zombies = true
	lift.rider_size = Vector3(4.4, 2.4, 4.6)
	lift.waypoints = PackedVector3Array([LIFT_C, Vector3(LIFT_C.x, -28.0, LIFT_C.z)])
	lift.position = LIFT_C
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(4.6, 0.3, 4.6)
	cs.shape = bs
	cs.position = Vector3(0, -0.15, 0)
	lift.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = bs.size
	mi.mesh = bm
	mi.position = cs.position
	mi.material_override = _mat(&"metal")
	lift.add_child(mi)
	lift.station_gates[0] = gate0
	lift.station_gates[1] = gate1
	gameplay.add_child(lift)
	for s: int in 2:
		var top: Vector3 = Vector3(61.9, Y, LIFT_C.z)
		var bottom: Vector3 = Vector3(69.1, -28.0, LIFT_C.z)
		var l: TraversalLink = link(
			"LFT_Link%d" % s, TraversalLink.Action.LIFT, top if s == 0 else bottom, bottom if s == 0 else top
		)
		l.station = s
		l.cost = 4.0
		l.enter_cost = 4.0
		lift.register_link(l)
	for s: int in 2:
		var c: MachineConsole = MachineConsole.new()
		c.name = "LFT_Console%d" % s
		c.station = s
		c.position = Vector3(62.3, Y + 1.2, -34.4) if s == 0 else Vector3(69.0, -26.8, -34.2)
		gameplay.add_child(c)
		c.machine_path = c.get_path_to(lift)
		c.machine = lift
	lift.refresh()
