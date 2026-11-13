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
	wall_buy(&"grease_gun", Vector3(-45.8, Y + 1.5, -23), PI * 0.5).name = "WallBuy_GreaseGun"  # VESPER_PEAK §5.1
	mark(&"box", "Box_Z08", Vector3(-26, Y, -15), "Relic Box (boiler house)")
	mark(&"part", "Part_Stock_A", Vector3(-40, Y + 3.5, -11.2), "Conduit Stock (option A)")
	mark(&"hazard", "H1_FuelDrums_Z08", Vector3(-42, Y, -26), "fuel drums")
	mark(&"lore", "L08", Vector3(-27, Y + 1.0, -26.4), "foreman's letter")
	lamp(Vector3(-34, Y + 1.5, -17), Color(1.0, 0.45, 0.15), 2.0, 14.0, false)  # furnace glow
	lamp(Vector3(-28, Y + 6.0, -20), Color(1.0, 0.8, 0.5), 1.0, 12.0)
	ambience(Vector3(-34, Y + 3, -19), &"boiler_room")
	occluder("Occ_Rock", Vector3(-34, Y + 9.5, -19), Vector3(24, 4, 18))


# --- Step 13 art pass (13C): furnaces, catwalks, coal chute, foreman's office --------------------


func dress() -> void:
	trim = "industrial"
	var furnace: Color = Color(1.0, 0.42, 0.12)
	for b: String in ["Boiler1", "Boiler2"]:
		var body: Node3D = geometry.get_node(b) as Node3D
		skin(b, &"boiler", Vector3(0, 0, 0), 0.0)
		# Furnace mouths glowing (who stokes them?), embers and steam bursts.
		var mouth: Vector3 = body.position + Vector3(0, -2.2, 2.6)
		fixture_light(
			&"",
			mouth + Vector3(0, 0, 0.4),
			furnace,
			1.6,
			9.0,
			PoweredLight.Pattern.FLICKER,
			false,
			45 if b == "Boiler1" else 0
		)
		fx(AtmosFx.Kind.EMBERS, mouth + Vector3(0, 0.2, 0.3), Vector3(0.4, 0.1, 0.1))
		fx(AtmosFx.Kind.STEAM, body.position + Vector3(1.4, 2.4, 0.0), Vector3(0.1, 0.1, 0.1), Vector3(0.3, 1, 0))
		decal(&"scorch", mouth + Vector3(0, -1.3, 1.2), Vector2(2.4, 2.4))
	# Coal under the chute, shovels, drums.
	prop(&"coal_pile", Vector3(-34, Y, -26.2), 0.0)
	prop(&"shovel", Vector3(-31.6, Y, -26.9), 0.3, null, Vector3(0.25, 0, 0))
	prop(&"shovel", Vector3(-36.4, Y, -27.0), -0.4, null, Vector3(0.2, 0, 0))
	decal(&"scorch", Vector3(-34, Y + 0.05, -24), Vector2(5, 4), Vector3.UP, 0.0, Color(1, 1, 1, 0.8))
	for x: float in [-45.6, -22.4]:
		prop(&"valve", Vector3(x, Y + 1.6, -15.0), PI / 2.0 if x < -30 else -PI / 2.0)
	prop(&"toolrack", Vector3(-45.75, Y, -17.0), PI / 2.0)
	# Foreman's office (vignette: a cold dinner and a letter never sent).
	skin("ForemanDesk", &"desk", Vector3.ZERO, PI)
	prop(&"chair", Vector3(-27, Y, -25.4), PI)
	prop(&"filing_cabinet", Vector3(-23.2, Y, -27.4), 0.0)
	var v: Node3D = vignette(
		"X_ForemansOffice", Vector3(-27, Y + 1.0, -26.4), "the foreman's desk: a cold dinner, a letter he never sent"
	)
	prop(&"notebook", Vector3(0.4, 0.06, 0), 0.2, v)
	deco("V08_Plate", v.position + Vector3(-0.4, 0.07, 0.1), Vector3(0.28, 0.02, 0.28), &"enamel")
	deco("V08_Mug", v.position + Vector3(-0.8, 0.13, -0.15), Vector3(0.09, 0.14, 0.09), &"enamel")
	signage("VORARBEITER · FOREMAN", Vector3(-27, Y + 2.6, -27.75), 0.0, 22, Color(0.92, 0.9, 0.82))
	signage("KESSELHAUS 2 — RAUCHEN VERBOTEN", Vector3(-34, Y + 5.6, -10.25), PI, 28, Color(0.95, 0.8, 0.2))
	# Catwalk caged bulbs; sodium spill.
	for x: float in [-42.0, -34.0, -26.0]:
		fixture_light(
			&"caged_bulb", Vector3(x, Y + 6.6, -11.4), Color(1.0, 0.72, 0.4), 0.7, 8.0, PoweredLight.Pattern.NONE, true
		)
	fx(AtmosFx.Kind.DUST, Vector3(-34, Y + 3.5, -19), Vector3(11, 3, 8))
	fog(Vector3(-34, Y + 5.0, -19), Vector3(24, 3, 18), Color(0.45, 0.35, 0.3), 0.3)
	for p: Vector3 in [Vector3(-40, Y + 0.05, -14), Vector3(-26, Y + 0.05, -20), Vector3(-44, Y + 0.05, -26)]:
		decal(&"grime", p, Vector2(5, 5), Vector3.UP, p.x)
	decal(&"water_stain", Vector3(-30, Y + 6.95, -14), Vector2(3, 3), Vector3.DOWN)
	reverb(&"Reverb_Industrial", Vector3(-46, -14, -28), Vector3(-22, -6, -10))
	reverb(&"Reverb_Tunnel", Vector3(-22, -14, -25.6), Vector3(-10, -4, -22.4))
