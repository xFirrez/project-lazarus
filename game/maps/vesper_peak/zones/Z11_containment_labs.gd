# Z11 Containment Labs (VESPER_PEAK §3 Z11), y -28: the ramp down from D11, a 36 x 24 m lab
# (x 56..92, z -72..-48) around the central containment chamber (Relay R3) with five more
# chambers (two shattered = bursts), the workbench, the Soul Containment Pod, the D12 airlock
# (north, Specimen Storage) and the reactor-side gantry (west) where the Reactor Bridge extends
# to the Forge platform once the relays are done (Step 11; `bridge` console command for now).
extends VesperZone

const Y: float = -28.0


func build() -> void:
	corridor("D11Ramp", Vector3(58.5, -16.0, -21.2), Vector3(58.5, Y, -47.8), 3.0, 3.5, &"tile")
	room(
		"Labs",
		Vector3(56, Y, -72),
		Vector3(92, (Y) + (5.0), -48),
		{
			"N": [[58.5, 3.0, 0.0, 3.4], door_hole(80, 3.0, 3.0)],
			"W": [door_hole(-60, 3.0, 3.0), [-68.0, 1.4, 0.0, 1.0]],
			"E": [[-64.0, 1.4, 0.0, 1.0], [-52.0, 1.6, 0.0, 2.6]],
			"S": [[64.0, 1.6, 0.0, 2.6], [84.0, 1.6, 0.0, 2.6]]
		},
		[&"tile", &"tile"]
	)
	# Central chamber (relay) with two doorways; four intact chambers as glass blocks.
	room(
		"Chamber",
		Vector3(71, Y, -63),
		Vector3(77, (Y) + (3.2), -57),
		{"N": [door_hole(74, 1.6, 2.4)], "S": [door_hole(74, 1.6, 2.4)]},
		[&"tile", &"tile"],
		false
	)
	for c: Vector3 in [Vector3(64, Y, -54), Vector3(84, Y, -54), Vector3(64, Y, -66), Vector3(84, Y, -66)]:
		box("ChamberGlass_%d_%d" % [int(c.x), int(absf(c.z))], c + Vector3(0, 1.6, 0), Vector3(3.6, 3.2, 3.6), &"ice")
	box("ObservationDesk", Vector3(88, Y + 0.5, -70.4), Vector3(4, 1.0, 1.0), &"metal")
	corridor("Airlock", Vector3(80, Y, -47.8), Vector3(80, Y, -46.0), 3.0, 3.0, &"metal")
	box_mm("Gantry", Vector3(50, Y - 0.5, -62), Vector3(56, Y, -58), &"metal")
	for r: Array in [
		[Vector3(53, Y + 0.5, -62.1), Vector3(6, 1, 0.15)], [Vector3(53, Y + 0.5, -57.9), Vector3(6, 1, 0.15)]
	]:
		box("GantryRail_%d" % int(absf(r[0].z)), r[0], r[1], &"metal")
		clip("GantryClip_%d" % int(absf(r[0].z)), r[0] + Vector3(0, 1.0, 0), Vector3(r[1].x, 3.0, r[1].z))
	# Reactor Bridge: an inverted NavDoor (solid when "open" = extended), gantry tip -> Forge platform.
	var a: Vector3 = Vector3(50.0, Y, -60.0)
	var b: Vector3 = Vector3(37.8, -34.0, -60.0)
	var bs: Basis = _basis_along(b - a)
	var br: NavDoor = NavDoor.new()
	br.name = "BRG_ReactorBridge"
	br.solid_when_open = true
	br.size = Vector3(3.0, 0.4, a.distance_to(b) + 0.3)
	br.transform = Transform3D(bs, (a + b) * 0.5 - bs.y * 0.2)
	geometry.add_child(br)
	closet("ChamberBroken1", Vector3(64, Y, -72), Vector3.FORWARD)
	closet("ChamberBroken2", Vector3(84, Y, -72), Vector3.FORWARD)
	closet("AirlockBurst", Vector3(92, Y, -52), Vector3.RIGHT)
	vent("VentE", Vector3(92, Y, -64), Vector3.RIGHT)
	vent("VentW", Vector3(56, Y, -68), Vector3.LEFT)
	var d12: NavDoor = nav_door("D12_Airlock", Vector3(80, Y + 1.4, -47.0), Vector3(3.0, 2.8, 0.4))
	buy_door(&"D12", "decontamination airlock", 1250, [&"Z12", &"Z11"], [d12], Vector3(80, Y + 1.4, -48.6))
	area("Ramp", Vector3(57, -29, -48), Vector3(60, -13, -21.2))
	area("Labs", Vector3(56, -29, -72), Vector3(92, -22, -48))
	area("Airlock", Vector3(78.5, -29, -48), Vector3(81.5, -24, -46))
	nav_areas.clear()
	nav_areas.append(AABB(Vector3(56.0, -29.5, -75.4), Vector3(39.4, 4.5, 29.4)))  # labs + airlock (z -46)
	nav_areas.append(AABB(Vector3(56.8, -29.5, -46.0), Vector3(3.4, 15.3, 24.8)))  # D11 ramp
	mark(&"relay", "R3_Relay", Vector3(74, Y, -60), "Resonance Relay #3", true)
	mark(&"workbench", "WB_LabWorkbench", Vector3(88, Y, -60), "Lab Workbench (Conduit)", true)
	mark(&"ee", "EE_SoulPod", Vector3(66, Y, -60), "Soul Containment Pod (stage 3)")
	mark(&"box", "Box_Z11", Vector3(88, Y, -66), "Relic Box (labs)")
	mark(&"hazard", "H3_Breaker", Vector3(91.6, Y + 1.3, -58), "lab breaker (puddles)", true)
	mark(&"hazard", "H3_Puddles", Vector3(80, Y, -60), "electrified puddles")
	mark(&"lore", "L11", Vector3(88, Y + 1.0, -70.4), "Varga: not a fuel")
	mark(&"reel", "R06", Vector3(86.5, Y + 1.0, -70.4), "audio reel R06")
	mark(&"ee", "EE_Chamber6_Claws", Vector3(84, Y, -64), "chamber 6 vignette")
	for p: Vector3 in [Vector3(64, Y + 4.5, -60), Vector3(84, Y + 4.5, -60), Vector3(74, Y + 4.5, -52)]:
		lamp(p, Color(0.85, 1.0, 1.0), 1.2, 12.0, true, 0.1)
	lamp(Vector3(74, Y + 1.5, -60), Color(0.4, 1.0, 0.5), 1.0, 6.0, false)  # vesperite leak
	ambience(Vector3(74, Y + 2, -60), &"lab_hum")
