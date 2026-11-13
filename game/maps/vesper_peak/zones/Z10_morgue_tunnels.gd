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


# --- Step 13 art pass (13C): the morgue, records, utility tunnels, the flooded section, Steam Purge


func dress() -> void:
	trim = "lab"
	var green: Color = Color(0.55, 1.0, 0.6)
	for i: int in 3:
		skin("AutopsyTable%d" % i, &"autopsy_table", Vector3.ZERO, PI / 2.0)
	hide_greybox("DrawerWall")
	prop(&"drawer_wall", Vector3(19.3, Y, -10.45), PI)
	prop(&"gurney", Vector3(6.0, Y, -20.4), PI / 2.0)
	prop(&"cabinet", Vector3(4.5, Y, -14.0), PI / 2.0)
	prop(&"filing_cabinet", Vector3(21.5, Y, -21.4), -PI / 2.0)
	signage("LEICHENHALLE · MORGUE", Vector3(13, Y + 3.6, -21.75), 0.0, 30, Color(0.85, 0.88, 0.82))
	# Vignette 8: one drawer chained shut, a cross scratched on it.
	var v: Node3D = vignette(
		"V08_ChainedDrawer", Vector3(21.0, Y + 0.6, -10.55), "one drawer chained shut with a cross scratched on it"
	)
	prop(&"chain", Vector3(0, 0.05, -0.05), PI / 2.0, v)
	prop(&"chain", Vector3(0, -0.12, -0.05), PI / 2.0 + 0.2, v)
	decal(&"cross_scratch", v.position + Vector3(0, 0.05, -0.05), Vector2(0.55, 0.55), Vector3.FORWARD)
	# Emergency bulbs (green) in cages; one strobing in the trap tunnel.
	for p: Vector3 in [
		Vector3(13, Y + 4.2, -16),
		Vector3(-8, Y + 3.3, -16.0),
		Vector3(-14, Y + 3.3, -28),
		Vector3(30, Y + 3.3, -19.5),
		Vector3(44, Y + 3.3, -19.5)
	]:
		prop(&"caged_bulb", p)
	fixture_light(
		&"caged_bulb", Vector3(52, Y + 3.3, -19.5), Color(1.0, 0.15, 0.08), 0.6, 6.0, PoweredLight.Pattern.BLINK, false
	)
	fixture_light(
		&"fluoro", Vector3(10, Y + 4.3, -13), Color(0.8, 1.0, 0.85), 0.5, 7.0, PoweredLight.Pattern.FLICKER, true, 35
	)
	# Utility tunnels: pipes (auto trim), steam vents of the purge trap, drips, the flooded floor.
	for x: float in [30.0, 38.0, 46.0]:
		prop(&"valve", Vector3(x, Y + 2.2, -20.8), 0.0)
		var fx_1: GPUParticles3D = fx(
			AtmosFx.Kind.STEAM, Vector3(x, Y + 3.2, -20.6), Vector3(0.1, 0.05, 0.1), Vector3(0, -0.2, 1)
		)
		fx_1.amount = 8
	signage("DAMPFLEITUNG — LEBENSGEFAHR", Vector3(26, Y + 2.6, -20.75), 0.0, 22, Color(0.95, 0.8, 0.2))
	decal(&"hazard_stripes", Vector3(28.2, Y + 0.05, -19.5), Vector2(0.6, 3.0))
	decal(&"hazard_stripes", Vector3(47.8, Y + 0.05, -19.5), Vector2(0.6, 3.0))
	var water: MeshInstance3D = deco("FloodWater", Vector3(37, Y + 0.07, -19.5), Vector3(14, 0.02, 3), &"glass_clear")
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x: float in [32.0, 36.5, 41.0]:
		fx(AtmosFx.Kind.DRIPS, Vector3(x, Y + 3.3, -19.0), Vector3(0.6, 0.05, 0.8), Vector3.DOWN)
	fx(AtmosFx.Kind.DRIPS, Vector3(-14, Y + 3.3, -24), Vector3(0.6, 0.05, 2.0), Vector3.DOWN)
	fx(AtmosFx.Kind.HAZE, Vector3(13, Y + 1.2, -16), Vector3(8, 0.8, 5))
	fog(Vector3(36, Y + 0.6, -19.5), Vector3(16, 1.2, 3), Color(0.55, 0.7, 0.6), 0.45)
	# Painted luminous symbols (EE clue) glow faintly; damp and blood.
	for s: Vector3 in [
		Vector3(4.2, Y + 2.0, -12),
		Vector3(-10, Y + 2.0, -14.7),
		Vector3(-15.3, Y + 2.0, -24),
		Vector3(46, Y + 2.0, -18.2)
	]:
		fixture_light(&"", s + Vector3(0, 0, 0), Color(0.4, 1.0, 0.6), 0.25, 2.0, PoweredLight.Pattern.PULSE, false)
	for p: Vector3 in [
		Vector3(10, Y + 0.05, -15),
		Vector3(-6, Y + 0.05, -16),
		Vector3(-14, Y + 0.05, -30),
		Vector3(52, Y + 0.05, -19.5)
	]:
		decal(&"water_stain", p, Vector2(3, 3), Vector3.UP, p.x)
	decal(&"blood", Vector3(13.5, Y + 0.05, -15.6), Vector2(2.0, 2.0), Vector3.UP, 0.6)
	decal(&"handprints", Vector3(8.0, Y + 1.3, -10.25), Vector2(1.0, 1.0), Vector3.FORWARD)
	reverb(&"Reverb_Tile", Vector3(4, -20, -22), Vector3(22, -11, -10))
	reverb(&"Reverb_Tunnel", Vector3(-15.5, -17, -17.5), Vector3(4, -12, -14.5))
	reverb(&"Reverb_Tunnel", Vector3(-15.5, -19, -41), Vector3(-12.5, -12, -17.5))
	reverb(&"Reverb_Tunnel", Vector3(22, -20, -21), Vector3(60, -12, -18))
	ambience(Vector3(38, Y + 2, -19.5), &"tunnel_drip", -4.0)
	ambience(Vector3(-14, Y + 2, -26), &"tunnel_drip", -4.0)
