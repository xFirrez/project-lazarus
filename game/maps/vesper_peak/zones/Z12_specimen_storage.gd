# Z12 Specimen Storage (VESPER_PEAK §3 Z12), y -28: a cramped 28 x 17 m cold store (x 63..91,
# z -46..-29) of shelving; the freight lift bottom station (shaft in the north-west corner,
# exit east), the laundry chute exit (linen pile, north-east), D12 airlock (south, Labs),
# 2 vents, a shaft drop and a window.
extends VesperZone

const Y: float = -28.0
const OBS_Z: float = -43.5  # observation window centre (z); the cavern wall opening lines up with it


func build() -> void:
	room(
		"Store",
		Vector3(63, Y, -46),
		Vector3(91, (Y) + (6.0), -29),
		{
			"S": [door_hole(80, 3.0, 3.0)],
			"N": [[75.0, 1.4, 0.0, 1.0], [85.0, 1.4, 0.0, 1.0]],
			"E": [win_hole(-36)],
			"W": [[OBS_Z, 3.0, 0.4, 2.2]],  # Step 13: the reactor observation glass (VESPER_PEAK §8.2)
		},
		[&"concrete", &"tile"],
		false,
		false
	)
	# Thick observation glass (solid; sightline tests treat `glass` bodies as see-through).
	var glass: StaticBody3D = box("ObservationGlass", Vector3(63.0, Y + 1.3, OBS_Z), Vector3(0.12, 1.8, 3.0), &"ice")
	glass.set_meta(&"glass", true)
	# Map quality pass: the glass looks 10 m through the rock to the cavern wall opening. A stone duct
	# (under the D11 ramp, which crosses above at x 56.8..60.2) frames the view instead of the void.
	# x 56.4..60.6 is under the D11 ramp, so the duct is lower there.
	for side: Array in [["N", OBS_Z + 2.2], ["S", OBS_Z - 2.6]]:
		var z0: float = float(side[1])
		box_mm("ObsDuct%sW" % side[0], Vector3(52.6, -36.5, z0), Vector3(56.4, -25.2, z0 + 0.4), &"stone")
		box_mm("ObsDuct%sM" % side[0], Vector3(56.4, -36.5, z0), Vector3(60.6, -28.0, z0 + 0.4), &"stone")
		box_mm("ObsDuct%sE" % side[0], Vector3(60.6, -36.5, z0), Vector3(63.0, -25.2, z0 + 0.4), &"stone")
	box_mm("ObsDuctFloor", Vector3(52.6, -36.9, OBS_Z - 2.6), Vector3(63.0, -36.5, OBS_Z + 2.6), &"stone")
	box_mm("ObsDuctRoofW", Vector3(52.6, -27.6, OBS_Z - 2.6), Vector3(56.4, -27.2, OBS_Z + 2.6), &"stone")
	box_mm("ObsDuctRoofMid", Vector3(56.4, -28.25, OBS_Z - 2.6), Vector3(60.6, -27.85, OBS_Z + 2.6), &"stone")
	box_mm("ObsDuctRoofE", Vector3(60.6, -25.6, OBS_Z - 2.6), Vector3(63.0, -25.2, OBS_Z + 2.6), &"stone")
	box_mm("ObsDuctPlugS", Vector3(52.6, -36.5, -48.6), Vector3(55.9, -25.2, OBS_Z - 2.6), &"stone")
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
	# Pit walls (map quality pass): the space under the store floor isn't open to the void.
	box_mm("ShaftPitW", Vector3(62.4, Y - 3.5, -34.6), Vector3(62.8, Y - 0.5, -28.4), &"concrete")
	box_mm("ShaftPitE", Vector3(68.2, Y - 3.5, -34.6), Vector3(68.6, Y - 0.5, -28.4), &"concrete")
	box_mm("ShaftPitS", Vector3(62.4, Y - 3.5, -34.6), Vector3(68.6, Y - 0.5, -34.2), &"concrete")
	box_mm("ShaftPitN", Vector3(62.4, Y - 3.5, -28.8), Vector3(68.6, Y - 0.5, -28.4), &"concrete")
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


# --- Step 13 art pass (13C): cold storage, specimen jars, the reactor glimpse ---------------------


func dress() -> void:
	trim = "lab"
	for i: int in 4:
		hide_greybox("Shelf%d" % i)
		for k: int in 4:
			for side: float in [-1.0, 1.0]:
				var shelf: MeshInstance3D = prop(
					&"jar_shelf", Vector3(72 + i * 4.5 + side * 0.18, Y, -42.0 + k * 2.0), side * PI / 2.0
				)
				shelf.scale = Vector3(1.25, 1.2, 0.9)
	# Vignette: the two-headed goat and the thing with too many teeth.
	var v: Node3D = vignette(
		"X_Specimens", Vector3(84.5, Y, -44.6), "the two-headed goat in its jar; something with too many teeth"
	)
	prop(&"goat_jar", Vector3.ZERO, 0.3, v)
	prop(&"jar", Vector3(1.0, 0, 0.2), 0.0, v)
	prop(&"jar", Vector3(1.3, 0, -0.2), 1.0, v)
	prop(&"chair", Vector3(-0.9, 0, 0.6), 1.8, v, Vector3(0, 0, PI / 2.0))
	signage("PRÄPARATE · SPECIMENS — KÜHLRAUM -18°C", Vector3(77, Y + 4.4, -29.25), PI, 28, Color(0.85, 0.92, 0.95))
	# The observation glass (thick, see-through) and the rock channel beyond it to the cavern.
	var glass: Node = geometry.get_node_or_null("ObservationGlass")
	if glass != null:
		(glass.get_child(0) as MeshInstance3D).material_override = VesperProps.m(&"glass_clear")
	deco("ObsFrameTop", Vector3(63.0, Y + 2.25, OBS_Z), Vector3(0.3, 0.12, 3.2), &"brass")
	deco("ObsFrameSill", Vector3(63.2, Y + 0.4, OBS_Z), Vector3(0.6, 0.1, 3.2), &"brass")
	signage("BEOBACHTUNGSFENSTER · REAKTOR", Vector3(63.25, Y + 2.6, OBS_Z), PI / 2.0, 20, Color(0.6, 1.0, 0.7))
	deco("ObsChannelFloor", Vector3(58.0, -36.5, -45.0), Vector3(11.0, 0.5, 8.0), &"stone")
	deco("ObsChannelN", Vector3(58.0, -32.8, -40.8), Vector3(11.0, 7.0, 0.5), &"stone")
	deco("ObsChannelS", Vector3(58.0, -33.0, -49.2), Vector3(11.0, 6.4, 0.5), &"stone")
	fixture_light(&"", Vector3(55.0, -31.5, -45.0), Color(0.35, 1.0, 0.45), 1.0, 9.0, PoweredLight.Pattern.PULSE, false)
	# Freezing: frost on everything, breath-fog haze, refrigeration units.
	for p: Vector3 in [
		Vector3(68, Y + 0.05, -32), Vector3(78, Y + 0.05, -35), Vector3(88, Y + 0.05, -38), Vector3(70, Y + 0.05, -44)
	]:
		decal(&"frost", p, Vector2(4, 4), Vector3.UP, p.x * 0.3)
	for z: float in [-31.0, -41.0]:
		decal(&"frost", Vector3(90.75, Y + 2.0, z), Vector2(3, 3), Vector3.LEFT)
	fx(AtmosFx.Kind.HAZE, Vector3(77, Y + 0.8, -38), Vector3(12, 0.6, 7))
	fog(Vector3(77, Y + 0.5, -38), Vector3(28, 1.0, 17), Color(0.75, 0.85, 0.9), 0.5)
	for x: float in [70.0, 86.0]:
		deco("FridgeUnit", Vector3(x, Y + 5.4, -29.6), Vector3(2.4, 1.0, 0.8), &"enamel")
		fx(AtmosFx.Kind.STEAM, Vector3(x, Y + 4.8, -30.0), Vector3(0.6, 0.05, 0.1), Vector3.DOWN)
	# Laundry chute exit: linen pile.
	skin("LinenPile", &"coal_pile", Vector3(0, 0, 0), 0.0)
	var linen: MeshInstance3D = prop(&"coal_pile", Vector3(88, Y, -31.3), 0.4)
	linen.material_override = VesperProps.m(&"cloth_white")
	linen.scale = Vector3(1.0, 0.5, 0.9)
	signage("LASTENAUFZUG", Vector3(65.5, Y + 3.0, -34.0), 0.0, 22, Color(0.95, 0.8, 0.2))
	for p: Vector3 in [Vector3(70, Y + 5.6, -36), Vector3(84, Y + 5.6, -40)]:
		prop(&"fluoro", p)
	fixture_light(
		&"fluoro", Vector3(77, Y + 5.6, -44), Color(0.8, 0.95, 1.0), 0.5, 8.0, PoweredLight.Pattern.BUZZ, true
	)
	reverb(&"Reverb_Room", Vector3(63, -29, -46), Vector3(91, -22, -29))
