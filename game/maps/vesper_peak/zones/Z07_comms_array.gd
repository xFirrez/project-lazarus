# Z07 Communications Array (VESPER_PEAK §3 Z07), ridge plaza at y +17: 40 x 38 m (x -20..20,
# z -138..-100) with the radar tower (lower platform +8 m, Relay R1), the two-storey radio
# building (observation deck on its roof), the gondola upper station (north edge; station 1), the
# mountain road from the D06 checkpoint (Courtyard) and the Sky Bridge from D15 (Operating
# Theater). 4 risers, 2 cliff climbs (south edge), a generator-shed door burst, a radio window.
# Parapets are low (1.1 m) with an invisible 3 m player clip over the drops.
extends VesperZone

const Y: float = 17.0


func build() -> void:
	box_mm("Plaza", Vector3(-20.2, Y - 1.0, -138.2), Vector3(20.2, Y, -99.8), &"cobble")
	_parapets()
	_radio_building()
	_tower()
	_gondola_station()
	_road()
	corridor("SkyBridge", Vector3(64.0, 7.0, -88.0), Vector3(20.0, Y, -112.0), 3.2, 3.3, &"wood")
	var sb: ZoneVolume = ZoneVolume.new()
	sb.name = "Zone_Z07_SkyBridge"
	sb.zone = zone_id
	var dir: Vector3 = Vector3(20.0, Y, -112.0) - Vector3(64.0, 7.0, -88.0)
	sb.transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.z)), Vector3(42.0, 13.5, -100.0))
	sb.size = Vector3(3.4, 16.0, Vector2(dir.x, dir.z).length())
	gameplay.add_child(sb)
	for i: int in 4:
		spawner(
			"Spawn_Z07_R%d" % (i + 1),
			[Vector3(-12, Y, -108), Vector3(0, Y, -120), Vector3(12, Y, -130), Vector3(-2, Y, -133)][i],
			ZombieSpawner.Kind.RISER,
			2
		)
	climb("ClimbS1", Vector3(-8, Y - 3.0, -141.6), Vector3(-8, Y, -136.8))
	climb("ClimbS2", Vector3(10, Y - 3.0, -141.6), Vector3(10, Y, -136.8))
	closet("GenShed", Vector3(-14, Y, -138), Vector3.FORWARD)
	area("Plaza", Vector3(-20, 16.5, -138), Vector3(20, 32.0, -100))
	area("GondolaStation", Vector3(-7, 16.5, -100), Vector3(-2, 22.0, -95))
	area("Road", Vector3(-30, -8.5, -140), Vector3(-20, 18.0, -86))
	area("RoadLow", Vector3(-30, -8.5, -86), Vector3(-4, -4.0, -78))
	nav_areas.clear()
	nav_areas.append(AABB(Vector3(-20.2, 13.0, -143.2), Vector3(40.4, 14.0, 48.4)))  # plaza (+deck, tower)
	nav_areas.append(AABB(Vector3(-31.0, -9.0, -86.2), Vector3(27.2, 3.0, 4.6)))  # road, low legs
	nav_areas.append(AABB(Vector3(-31.0, -9.0, -141.0), Vector3(10.8, 27.5, 54.8)))  # road ramp + landing
	nav_areas.append(AABB(Vector3(20.2, 6.0, -114.0), Vector3(43.8, 13.0, 28.0)))  # Sky Bridge
	mark(&"perk", "Perk_MarathonMalt", Vector3(-18, Y, -104), "Marathon Malt", true)
	wall_buy(&"kar98k", Vector3(7.8, Y + 1.5, -106), -PI * 0.5).name = "WallBuy_Kar98k"  # VESPER_PEAK §5.1
	wall_buy(&"ice_axe", Vector3(-19.8, Y + 1.5, -118), PI * 0.5).name = "WallBuy_IceAxe"  # VESPER_PEAK §5.1
	mark(&"box", "Box_Z07", Vector3(-6, Y, -118), "Relic Box (antenna base)")
	mark(&"relay", "R1_Relay", Vector3(-12, Y + 8.0, -126), "Resonance Relay #1", true)
	mark(&"ee", "EE_RadioConsole", Vector3(14, Y, -107.5), "radio console (EE stage 1)", true)
	mark(&"music_box", "MB3_ObsLocker", Vector3(18.5, Y + 4.5, -101.5), "music box #3 (deck locker)")
	mark(&"part", "Part_Coil_A", Vector3(10, Y, -126), "Conduit Coil (option A)")
	mark(&"lore", "L07", Vector3(11, Y + 1.0, -108.5), "radio transcript")
	mark(&"reel", "R01", Vector3(17, Y + 1.0, -108.5), "audio reel R01")
	mark(&"raven", "Raven_4_Antenna", Vector3(-12, Y + 20.0, -126), "frozen raven (antenna)")
	mark(&"raven", "Raven_5_GondolaStation", Vector3(-4.5, Y + 4.6, -99), "frozen raven (gondola station)")
	mark(&"ee", "EE_FrozenOperator", Vector3(12.5, Y, -102), "frozen radio operator")
	for p: Vector3 in [Vector3(-10, Y + 6, -112), Vector3(10, Y + 6, -124), Vector3(14, Y + 3.5, -105)]:
		lamp(p, Color(0.8, 0.9, 1.0), 1.4, 16.0)
	lamp(Vector3(-12, Y + 34.0, -126), Color(1.0, 0.1, 0.05), 2.0, 12.0, false)  # aircraft light
	ambience(Vector3(0, Y + 3, -120), &"exterior_storm")


func _parapets() -> void:
	# [from, to] along the plaza edges with gaps for the road landing, Sky Bridge and station.
	var rails: Array = [
		[Vector3(-20, Y, -100), Vector3(-7.2, Y, -100)],
		[Vector3(-1.8, Y, -100), Vector3(8, Y, -100)],
		[Vector3(20, Y, -100), Vector3(20, Y, -110.4)],
		[Vector3(20, Y, -113.6), Vector3(20, Y, -138)],
		[Vector3(-20, Y, -138), Vector3(-15.0, Y, -138)],
		[Vector3(-13.0, Y, -138), Vector3(20, Y, -138)],
		[Vector3(-20, Y, -100), Vector3(-20, Y, -135.6)],
	]
	for i: int in rails.size():
		var a: Vector3 = rails[i][0]
		var b: Vector3 = rails[i][1]
		var c: Vector3 = (a + b) * 0.5
		var along_x: bool = absf(b.x - a.x) > absf(b.z - a.z)
		var len: float = a.distance_to(b)
		box(
			"Parapet_%d" % i,
			c + Vector3(0, 0.55, 0),
			Vector3(len, 1.1, 0.3) if along_x else Vector3(0.3, 1.1, len),
			&"stone"
		)
		clip(
			"ParapetClip_%d" % i, c + Vector3(0, 2.0, 0), Vector3(len, 3.0, 0.3) if along_x else Vector3(0.3, 3.0, len)
		)


func _radio_building() -> void:
	room(
		"Radio",
		Vector3(8, Y, -110),
		Vector3(20, (Y) + (4.0), -100),
		{"S": [door_hole(14, 2.0, 2.6)], "N": [win_hole(16)]},
		[&"wood", &"olive"]
	)
	window("W_Radio", Vector3(16, Y, -100), Vector3.BACK)
	box("RadioDesk", Vector3(9.2, Y + 0.5, -105), Vector3(1.0, 1.0, 4.0), &"wood")
	# Observation deck on the roof (+4.5) via an outside stair from the plaza.
	stairs("DeckStair", Vector3(6.8, Y, -113.5), Vector3(6.8, Y + 4.5, -104.6), 2.0, &"metal")
	box_mm("DeckLanding", Vector3(5.8, Y + 4.0, -104.6), Vector3(8, Y + 4.5, -102), &"metal")
	for r: Array in [
		[Vector3(14, Y + 5.0, -110.1), Vector3(12.4, 1.0, 0.15)],
		[Vector3(20.1, Y + 5.0, -105), Vector3(0.15, 1.0, 10.2)],
		[Vector3(14, Y + 5.0, -99.9), Vector3(12.4, 1.0, 0.15)]
	]:
		box("DeckRail_%d" % int(r[0].z), r[0], r[1], &"metal")
		clip("DeckClip_%d" % int(r[0].z), r[0] + Vector3(0, 1.0, 0), Vector3(r[1].x, 3.0, r[1].z))
	box("DeckLockers", Vector3(18.8, Y + 5.4, -102), Vector3(1.6, 1.8, 0.6), &"olive")


func _tower() -> void:
	for lx: float in [-16.0, -8.0]:
		for lz: float in [-130.0, -122.0]:
			box("TowerLeg_%d_%d" % [int(lx), int(lz)], Vector3(lx, Y + 17.5, lz), Vector3(0.6, 35.0, 0.6), &"metal")
	box_mm("TowerPlatform", Vector3(-16.3, Y + 7.6, -130.3), Vector3(-7.7, Y + 8.0, -121.7), &"metal")
	stairs("TowerStair", Vector3(-6.2, Y, -112.5), Vector3(-6.2, Y + 8.0, -122.0), 2.0, &"metal")
	box_mm("TowerLanding", Vector3(-7.7, Y + 7.6, -124.0), Vector3(-5.2, Y + 8.0, -121.7), &"metal")
	for r: Array in [
		[Vector3(-12, Y + 8.5, -130.4), Vector3(8.6, 1.0, 0.15)],
		[Vector3(-16.4, Y + 8.5, -126), Vector3(0.15, 1.0, 8.6)],
		[Vector3(-7.6, Y + 8.5, -127.2), Vector3(0.15, 1.0, 6.2)],
		[Vector3(-12.9, Y + 8.5, -121.6), Vector3(6.8, 1.0, 0.15)]
	]:
		box("TowerRail_%d_%d" % [int(r[0].x), int(r[0].z)], r[0], r[1], &"metal")
		clip("TowerClip_%d_%d" % [int(r[0].x), int(r[0].z)], r[0] + Vector3(0, 1.0, 0), Vector3(r[1].x, 3.0, r[1].z))
	box("Dish", Vector3(-12, Y + 36.0, -126), Vector3(6.0, 0.6, 6.0), &"metal")


# Upper station (station 1): platform x -7..-2, z -100..-95; the cabin docks at z -95..-92.
func _gondola_station() -> void:
	box_mm("StationPlatform", Vector3(-7.0, Y - 1.0, -100.0), Vector3(-2.0, Y, -95.0), &"concrete")
	box_mm("StationRoof", Vector3(-7.4, Y + 4.0, -100.0), Vector3(-1.6, Y + 4.4, -92.0), &"olive")
	for sx: float in [-7.2, -1.8]:
		box_mm(
			"StationWall_%d" % int(absf(sx) * 10), Vector3(sx - 0.2, Y, -100), Vector3(sx + 0.2, Y + 4.0, -95), &"olive"
		)
	var gate1: StaticBody3D = clip("Gondola_Gate1", Vector3(-4.5, Y + 1.5, -95.0), Vector3(3.0, 3.0, 0.3))
	clip("Gondola_EdgeW", Vector3(-6.5, Y + 1.5, -95.0), Vector3(1.2, 3.0, 0.3))
	clip("Gondola_EdgeE", Vector3(-2.5, Y + 1.5, -95.0), Vector3(1.2, 3.0, 0.3))
	box("StationRailW", Vector3(-6.5, Y + 0.5, -95.0), Vector3(1.2, 1.0, 0.15), &"metal")
	box("StationRailE", Vector3(-2.5, Y + 0.5, -95.0), Vector3(1.2, 1.0, 0.15), &"metal")
	var z01: Node = get_parent().get_node_or_null("Z01_ArrivalStation")
	var cab: TraversalMachine = z01.find_child("GND_Gondola", true, false) as TraversalMachine if z01 != null else null
	var c1: MachineConsole = MachineConsole.new()
	c1.name = "GND_Console_Z07"
	c1.station = 1
	c1.position = Vector3(-2.6, Y + 1.2, -96.5)
	gameplay.add_child(c1)
	if cab != null:
		cab.station_gates[1] = gate1
		cab.refresh()
		c1.machine_path = c1.get_path_to(cab)
		c1.machine = cab


# The mountain road from the D06 gate: south 6 m, west 22 m, then a 25° ramp south to the plaza's
# south-west landing (+25 m over 50 m). Guard rails + player clips over the drops.
func _road() -> void:
	ramp("RoadA", Vector3(-6, -8.0, -78.2), Vector3(-6, -8.0, -86.0), 4.0, &"cobble")
	ramp("RoadB", Vector3(-4.0, -8.0, -84.0), Vector3(-30.0, -8.0, -84.0), 4.0, &"cobble")
	ramp("RoadC", Vector3(-28.0, -8.0, -86.0), Vector3(-28.0, Y, -136.0), 4.0, &"cobble")
	box_mm("RoadLanding", Vector3(-30.0, Y - 1.0, -140.0), Vector3(-20.0, Y, -136.0), &"cobble")
	var guards: Array = [
		[Vector3(-8.2, -8.0, -78.2), Vector3(-8.2, -8.0, -82.0)],
		[Vector3(-3.8, -8.0, -78.2), Vector3(-3.8, -8.0, -86.2)],
		[Vector3(-3.8, -8.0, -86.2), Vector3(-26.0, -8.0, -86.2)],
		[Vector3(-8.2, -8.0, -81.8), Vector3(-30.2, -8.0, -81.8)],
		[Vector3(-30.2, -8.0, -81.8), Vector3(-30.2, -8.0, -86.0)],
		[Vector3(-30.2, Y, -136.0), Vector3(-30.2, Y, -140.2)],
		[Vector3(-30.2, Y, -140.2), Vector3(-20.0, Y, -140.2)],
		[Vector3(-26.0, Y, -135.8), Vector3(-20.0, Y, -135.8)],
		[Vector3(-20.0, Y, -140.2), Vector3(-20.0, Y, -138.0)],
	]
	for i: int in guards.size():
		var a: Vector3 = guards[i][0]
		var b: Vector3 = guards[i][1]
		var along_x: bool = absf(b.x - a.x) > absf(b.z - a.z)
		var len: float = a.distance_to(b)
		var c: Vector3 = (a + b) * 0.5
		box(
			"Guard_%d" % i,
			c + Vector3(0, 0.55, 0),
			Vector3(len, 1.1, 0.3) if along_x else Vector3(0.3, 1.1, len),
			&"stone"
		)
		clip("GuardClip_%d" % i, c + Vector3(0, 2.0, 0), Vector3(len, 3.0, 0.3) if along_x else Vector3(0.3, 3.0, len))
	# Sloped rails along both sides of the ramp.
	for side: float in [-1.0, 1.0]:
		var a2: Vector3 = Vector3(-28.0 + side * 2.15, -8.0, -86.0)
		var b2: Vector3 = Vector3(-28.0 + side * 2.15, Y, -136.0)
		var bs: Basis = _basis_along(b2 - a2)
		var mid: Vector3 = (a2 + b2) * 0.5
		slab(
			"RampRail%d" % int(side),
			Transform3D(bs, mid + bs.y * 0.55),
			Vector3(0.3, 1.1, a2.distance_to(b2)),
			&"stone"
		)
		var cl: StaticBody3D = clip("RampClip%d" % int(side), Vector3.ZERO, Vector3(0.3, 3.0, a2.distance_to(b2)))
		cl.transform = Transform3D(bs, mid + bs.y * 2.0)
	box_mm("CheckpointHut", Vector3(-3.6, -8.0, -81.8), Vector3(-1.0, -5.2, -78.4), &"olive")


# --- Step 13 art pass (13A): the ridge plaza, the radar tower, the radio building, gondola station


func dress() -> void:
	trim = "military"
	_tower_art()
	# Antenna masts with guy wires.
	for m: Vector3 in [Vector3(-2, Y, -110), Vector3(14, Y, -132)]:
		var b: MeshBatch = MeshBatch.new()
		b.cyl(0.12, 14.0, m + Vector3(0, 7.0, 0), VesperProps.m(&"metal"))
		b.box(Vector3(2.4, 0.08, 0.08), m + Vector3(0, 13.0, 0), VesperProps.m(&"metal"))
		for k: int in 3:
			var a: float = TAU * k / 3.0 + 0.4
			var top: Vector3 = m + Vector3(0, 12.0, 0)
			var foot: Vector3 = m + Vector3(cos(a) * 5.0, 0.05, sin(a) * 5.0)
			b.add(
				MeshBatch.Shape.BOX,
				Vector3(0.025, 0.025, top.distance_to(foot)),
				Transform3D(_basis_along(top - foot), (top + foot) * 0.5),
				VesperProps.m(&"black")
			)
		art.add_child(b.instance("AntennaMast", 140.0))
		prop(&"beacon", m + Vector3(0, 14.0, 0))
		fixture_light(&"", m + Vector3(0, 14.2, 0), Color(1.0, 0.1, 0.05), 1.0, 6.0, PoweredLight.Pattern.BLINK, false)
	# Searchlight mounts (the lights themselves are map-level, VesperArt).
	for x: float in [-16.0, 12.0]:
		deco("SearchlightMount", Vector3(x, Y + 2.7, -101), Vector3(0.5, 5.4, 0.5), &"olive")
		deco("SearchlightDeck", Vector3(x, Y + 5.3, -101), Vector3(1.6, 0.15, 1.6), &"metal")
	# Radio room: consoles, the frozen operator (vignette 6), lockers.
	skin("RadioDesk", &"radio_console", Vector3(0, 0, 0), PI / 2.0)
	prop(&"radio_console", Vector3(18.8, Y, -106.5), -PI / 2.0)
	prop(&"filing_cabinet", Vector3(19.4, Y, -109.2), -PI / 2.0)
	var v: Node3D = vignette(
		"V06_FrozenOperator",
		Vector3(12.5, Y, -102),
		"a radio operator still seated, frozen solid, headphones on",
		PI * 0.85
	)
	prop(&"frozen_operator", Vector3.ZERO, 0.0, v)
	deco("OperatorDesk", Vector3(12.5, Y + 0.78, -101.0), Vector3(1.6, 0.06, 0.7), &"wood")
	var set_top: MeshInstance3D = prop(&"radio_console", Vector3(12.5, Y + 0.8, -100.6), PI, v)
	set_top.scale = Vector3(0.45, 0.45, 0.45)
	decal(&"frost", Vector3(12.5, Y + 0.05, -102), Vector2(2.4, 2.4))
	skin("DeckLockers", &"cabinet", Vector3(-0.4, 0, 0), PI)
	prop(&"cabinet", Vector3(19.2, Y + 4.5, -102), PI)
	fixture_light(
		&"caged_bulb",
		Vector3(14, Y + 3.8, -105),
		Color(1.0, 0.78, 0.5),
		0.8,
		7.0,
		PoweredLight.Pattern.FLICKER,
		true,
		25
	)
	signage("FUNKSTATION · RADIO ROOM", Vector3(14, Y + 2.9, -110.25), PI, 24, Color(0.92, 0.9, 0.82))
	signage("GROUP VESPER — KOMMANDOSTATION VESPERHÖHE", Vector3(0, Y + 3.6, -99.75), PI, 34, Color(0.92, 0.9, 0.82))
	# The climbing club plaque (Ice Axe wall-buy).
	deco("ClubPlaque", Vector3(-19.75, Y + 2.6, -118), Vector3(0.06, 0.8, 1.6), &"wood")
	signage("ALPENVEREIN VESPERHÖHE · 1911", Vector3(-19.7, Y + 2.9, -118), PI / 2.0, 20, Color(0.95, 0.85, 0.55))
	# Gondola upper station.
	signage("GONDEL > BERGSTATION", Vector3(-4.5, Y + 3.5, -99.8), PI, 22, Color(0.92, 0.9, 0.82))
	fixture_light(
		&"caged_bulb", Vector3(-4.5, Y + 3.9, -97.5), Color(1.0, 0.78, 0.5), 0.6, 6.0, PoweredLight.Pattern.SWING, true
	)
	# Generator shed.
	signage("AGGREGAT · GENERATOR", Vector3(-14, Y + 3.0, -137.75), 0.0, 22, Color(0.95, 0.8, 0.2))
	decal(&"hazard_stripes", Vector3(-14, Y + 0.05, -137.0), Vector2(2.4, 0.6))
	prop(&"drum_rack", Vector3(-17.5, Y, -136.5), 0.0)
	prop(&"crate_stack", Vector3(16.5, Y, -135.5), 0.3)
	_sky_bridge()
	# Sky Bridge: swinging caged bulbs.
	for t: float in [0.2, 0.5, 0.8]:
		var p: Vector3 = Vector3(64.0, 7.0, -88.0).lerp(Vector3(20.0, Y, -112.0), t)
		fixture_light(
			&"caged_bulb", p + Vector3(0, 3.0, 0), Color(1.0, 0.75, 0.45), 0.6, 7.0, PoweredLight.Pattern.SWING, true
		)
	# Storm FX, frost, acoustics.
	fx(AtmosFx.Kind.SNOW_DRIFT, Vector3(0, Y + 1.2, -119), Vector3(19, 0.8, 18), Vector3(1, 0, 0.2))
	fx(AtmosFx.Kind.HAZE, Vector3(0, Y + 2.0, -119), Vector3(18, 1.2, 18))
	for p: Vector3 in [Vector3(-12, Y + 0.05, -108), Vector3(6, Y + 0.05, -128), Vector3(-6, Y + 0.05, -118)]:
		decal(&"frost", p, Vector2(4, 4), Vector3.UP, p.x)
	decal(&"blood", Vector3(2, Y + 0.05, -114), Vector2(1.6, 1.6), Vector3.UP, 0.3)
	reverb(&"Reverb_Exterior", Vector3(-20, 16.5, -138), Vector3(20, 32.0, -100))
	reverb(&"Reverb_Room", Vector3(8, 16.5, -110), Vector3(20, 21.0, -100), 0.6)
	ambience(Vector3(12, Y + 1.5, -104), &"radio_static")


# The 35 m lattice radar tower (the map's landmark): cross-braced legs, a rotating dish and blinking
# red aircraft lights at the top (VESPER_PEAK §3 Z07 / §8.2).
func _tower_art() -> void:
	var b: MeshBatch = MeshBatch.new()
	var steel: Material = VesperProps.m(&"metal")
	var legs: Array[Vector3] = [
		Vector3(-16, 0, -130), Vector3(-8, 0, -130), Vector3(-8, 0, -122), Vector3(-16, 0, -122)
	]
	for f: int in 4:
		var a: Vector3 = legs[f]
		var c: Vector3 = legs[(f + 1) % 4]
		var y0: float = Y + 1.0
		while y0 < Y + 33.0:
			var y1: float = y0 + 4.0
			for pair: Array in [
				[a + Vector3(0, y0, 0), c + Vector3(0, y1, 0)], [c + Vector3(0, y0, 0), a + Vector3(0, y1, 0)]
			]:
				var p0: Vector3 = pair[0]
				var p1: Vector3 = pair[1]
				b.add(
					MeshBatch.Shape.BOX,
					Vector3(0.12, 0.12, p0.distance_to(p1)),
					Transform3D(_basis_along(p1 - p0), (p0 + p1) * 0.5),
					steel
				)
			b.box(Vector3(absf(c.x - a.x) + 0.2, 0.15, absf(c.z - a.z) + 0.2), (a + c) * 0.5 + Vector3(0, y1, 0), steel)
			y0 = y1
	art.add_child(b.instance("TowerLattice", 400.0))
	hide_greybox("Dish")
	var dish_pivot: Node3D = Node3D.new()
	dish_pivot.name = "RadarDish"
	dish_pivot.position = Vector3(-12, Y + 35.6, -126)
	art.add_child(dish_pivot)
	var d: MeshBatch = MeshBatch.new()
	d.cyl(0.4, 1.2, Vector3(0, 0.6, 0), steel)
	d.box(Vector3(7.0, 2.6, 0.25), Vector3(0, 2.0, 0.4), steel, Vector3(-0.25, 0, 0))
	for i: int in 6:
		d.box(Vector3(0.1, 2.6, 0.6), Vector3(-3.0 + i * 1.2, 2.0, 0.6), steel, Vector3(-0.25, 0, 0))
	d.box(Vector3(0.15, 0.15, 1.6), Vector3(0, 2.0, 1.4), steel)
	var dmi: MeshInstance3D = d.instance("Dish", 400.0)
	dish_pivot.add_child(dmi)
	spin(dish_pivot, Vector3.UP, 0.6)
	for l: Vector3 in legs:
		var top: Vector3 = l + Vector3(0, Y + 35.1, 0)
		prop(&"beacon", top)
		fixture_light(
			&"", top + Vector3(0, 0.3, 0), Color(1.0, 0.08, 0.04), 1.5, 10.0, PoweredLight.Pattern.BLINK, false
		)


# The Sky Bridge reads as an open iron footbridge: the greybox walls / roof stay as invisible
# collision (marked `glass` for sightline checks) and the art adds deck planks, posts and rails.
func _sky_bridge() -> void:
	var a: Vector3 = Vector3(64.0, 7.0, -88.0)
	var e: Vector3 = Vector3(20.0, Y, -112.0)
	for n: String in ["SkyBridge_WallL", "SkyBridge_WallR", "SkyBridge_Roof"]:
		hide_greybox(n)
		var body: Node = geometry.get_node_or_null(n)
		if body != null:
			body.set_meta(&"glass", true)
	var bs: Basis = _basis_along(e - a)
	var b: MeshBatch = MeshBatch.new()
	var iron: Material = VesperProps.m(&"metal")
	var n_posts: int = 16
	for i: int in n_posts + 1:
		var p: Vector3 = a.lerp(e, float(i) / n_posts)
		for side: float in [-1.0, 1.0]:
			b.add(
				MeshBatch.Shape.BOX,
				Vector3(0.1, 1.2, 0.1),
				Transform3D(Basis.IDENTITY, p + bs.x * side * 1.65 + Vector3(0, 0.6, 0)),
				iron
			)
	for side: float in [-1.0, 1.0]:
		for h: float in [1.15, 0.6]:
			var p0: Vector3 = a + bs.x * side * 1.65 + Vector3(0, h, 0)
			var p1: Vector3 = e + bs.x * side * 1.65 + Vector3(0, h, 0)
			b.add(MeshBatch.Shape.BOX, Vector3(0.06, 0.06, p0.distance_to(p1)), Transform3D(bs, (p0 + p1) * 0.5), iron)
	# Lattice trusses under the deck.
	for i: int in n_posts:
		var p2: Vector3 = a.lerp(e, (float(i) + 0.5) / n_posts)
		b.add(MeshBatch.Shape.BOX, Vector3(3.4, 0.12, 0.12), Transform3D(bs, p2 + Vector3(0, -0.9, 0)), iron)
		b.add(
			MeshBatch.Shape.BOX,
			Vector3(0.12, 1.6, 0.12),
			Transform3D(bs * Basis(Vector3.RIGHT, 0.7), p2 + bs.x * 1.6 + Vector3(0, -0.6, 0)),
			iron
		)
		b.add(
			MeshBatch.Shape.BOX,
			Vector3(0.12, 1.6, 0.12),
			Transform3D(bs * Basis(Vector3.RIGHT, 0.7), p2 - bs.x * 1.6 + Vector3(0, -0.6, 0)),
			iron
		)
	art.add_child(b.instance("SkyBridgeRails", 160.0))
