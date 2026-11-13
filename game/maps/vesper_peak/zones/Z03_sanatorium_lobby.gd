# Z03 Sanatorium Lobby (VESPER_PEAK §3 Z03): the covered walkway from D01 (flat, then a 25° ramp
# down 8 m) and the Belle Époque lobby 30 x 22 m (x 38..68, z -14..8, floor y -8) with a north
# mezzanine (+4 m) reached by two side stairs, the grand staircase up to a landing (+6 m) where D03
# leads into the East Wing, terrace doors D04 (south, to the Courtyard), service door D08 (west,
# basement stairwell to the Morgue). 3 ground windows, 1 mezzanine window, a door-burst office.
extends VesperZone

const Y: float = -8.0
const MEZZ: float = -4.0
# S1 Director's Office (Step 14): x 33..37.8, z 2.6..8.2 at the mezzanine level, entered through the
# rotating bookcase in the lobby's west wall (a NavDoor, opened by the room-7 mirror secret).
const S1_LO: Vector3 = Vector3(33.0, -4.0, 2.6)
const S1_HI: Vector3 = Vector3(37.8, -0.8, 8.2)
const S1_DOOR_Z: float = 5.8


func build() -> void:
	# Walkway (D01 -> lobby west door).
	corridor("Walk", Vector3(13.2, 0, -3), Vector3(21, 0, -3), 3.2, 3.3, &"concrete")
	corridor("WalkRamp", Vector3(21, 0, -3), Vector3(38, Y, -3), 3.2, 3.3, &"concrete")
	room(
		"Lobby",
		Vector3(38, Y, -14),
		Vector3(68, (Y) + (9.0), 8),
		{
			"W": [door_hole(-3, 3.2, 3.4), door_hole(-11, 2.4, 2.8), win_hole(-7), [S1_DOOR_Z, 1.6, 4.0, 6.4]],
			"N": [win_hole(46), win_hole(54), [52.0 - 0.0, 1.4, 4.9, 6.1]],
			"E": [[-11.0, 2.4, 6.0, 8.8]],
			"S": [door_hole(52, 3.0, 3.0), [62.0, 1.6, 0.0, 2.6]],
		},
		[&"marble", &"plaster"]
	)
	# Fix: the mezzanine window shares x 52 with nothing at ground level (ground windows 46 / 54).
	box("Mezzanine", Vector3(50, MEZZ - 0.2, 6.1), Vector3(24, 0.4, 4.2), &"wood")
	# Rail along the mezzanine edge with gaps where the two side stairs (running along it) arrive.
	for r: Array in [[42.75, 9.5], [52.25, 4.5], [59.75, 4.5]]:
		box("MezzRail_%d" % int(r[0]), Vector3(float(r[0]), MEZZ + 0.5, 4.1), Vector3(float(r[1]), 1.0, 0.15), &"wood")
	stairs("MezzStairW", Vector3(41.0, Y, 3.0), Vector3(49.0, MEZZ, 3.0), 2.0)
	stairs("MezzStairE", Vector3(63.0, Y, 3.0), Vector3(55.0, MEZZ, 3.0), 2.0)
	# Grand staircase (east) -> landing -> D03 (Z04).
	stairs("Grand", Vector3(65.4, Y, 6.5), Vector3(65.4, -2.0, -8.0), 4.8, &"marble")
	box_mm("Landing", Vector3(63, -2.5, -14), Vector3(68, -2.0, -8), &"marble")
	box("LandingRail", Vector3(63.1, -1.5, -11), Vector3(0.15, 1.0, 6), &"wood")
	box("Chandelier", Vector3(66.6, -1.4, -9.3), Vector3(1.6, 1.2, 1.6), &"brass")
	box("ReceptionDesk", Vector3(53, Y + 0.55, -6), Vector3(5, 1.1, 1.2), &"wood")
	box("Clock", Vector3(39, Y + 1.3, 6.8), Vector3(0.8, 2.6, 0.6), &"wood")
	window("W1", Vector3(46, Y, 8), Vector3.BACK)
	window("W2", Vector3(54, Y, 8), Vector3.BACK)
	window("W3", Vector3(38, Y, -7), Vector3.LEFT)
	window("WM", Vector3(52, MEZZ, 8), Vector3.BACK, 2)
	closet("Office", Vector3(62, Y, -14), Vector3.FORWARD)
	# Terrace (D04) is the Courtyard's; the lobby scene owns the doors on its boundary.
	corridor("Terrace", Vector3(52, Y, -14.2), Vector3(52, Y, -20), 3.0, 3.2, &"marble")
	var d3: NavDoor = nav_door("D03_Chandelier", Vector3(68, -0.6, -11), Vector3(0.4, 2.8, 2.4))
	buy_door(&"D03", "fallen chandelier", 1000, [&"Z04", &"Z03"], [d3], Vector3(67.2, -0.6, -11))
	var d4: NavDoor = nav_door("D04_Terrace", Vector3(52, Y + 1.5, -14), Vector3(3.0, 3.0, 0.4))
	buy_door(&"D04", "iced terrace doors", 1250, [&"Z06", &"Z03"], [d4], Vector3(52, Y + 1.5, -13.2))
	var d8: NavDoor = nav_door("D08_ServiceDoor", Vector3(38, Y + 1.4, -11), Vector3(0.4, 2.8, 2.4))
	buy_door(&"D08", "basement service door", 1250, [&"Z10", &"Z03"], [d8], Vector3(38.8, Y + 1.4, -11))
	_office_shell()
	area("Walkway", Vector3(13.2, -8.5, -4.6), Vector3(38, 4.0, -1.4))
	area("Lobby", Vector3(38, -8.5, -14), Vector3(68, 1.0, 8))
	area("DirectorsOffice", Vector3(S1_LO.x, MEZZ - 0.5, S1_LO.z), Vector3(37.8, MEZZ + 3.0, S1_HI.z))
	nav_areas.clear()
	nav_areas.append(AABB(Vector3(13.2, -9.5, -5.0), Vector3(24.8, 13.0, 17.0)))  # walkway + W_U2 bay + S1 office
	nav_areas.append(AABB(Vector3(38, -9.5, -20.0), Vector3(30.2, 9.0, 32.0)))  # lobby + terrace + office
	mark(&"perk", "Perk_Quickdraw", Vector3(40, Y, 1.5), "Quickdraw Fizz", true)
	wall_buy(&"mp40", Vector3(44, Y + 1.5, -13.8), 0.0).name = "WallBuy_MP40"  # VESPER_PEAK §5.1
	mark(&"box", "Box_Z03", Vector3(49.5, Y, -6), "Relic Box START location")
	mark(&"ee", "EE_Guestbook", Vector3(54.5, Y + 1.1, -6), "guestbook (S1 clue)")
	mark(&"secret", "S1_Bookcase", Vector3(39, MEZZ, 7.6), "Director's Office entrance (S1)")
	mark(&"lore", "L02", Vector3(51, Y + 1.1, -6), "1908 brochure")
	mark(&"reel", "R02", Vector3(40.5, MEZZ, 7.0), "audio reel R02 (mezzanine desk)")
	# S1 Director's Office (behind the mezzanine bookcase; the room itself is built in Step 13).
	mark(&"lore", "L13", Vector3(36.0, MEZZ, 6.0), "Haemmer's Requiem Test order (S1)")
	mark(&"ee", "S1_FreeTonicCrate", Vector3(35.0, MEZZ, 4.5), "free tonic crate (S1)")
	mark(&"lore", "L03", Vector3(56, MEZZ, 7.4), "Group Vesper memo")
	lamp(Vector3(53, -1.0, -3), Color(1.0, 0.75, 0.45), 2.5, 22.0, true, 0.25)
	lamp(Vector3(45, -1.5, 6), Color(1.0, 0.75, 0.45), 1.2, 10.0)
	lamp(Vector3(25, 2.0, -3), Color(0.9, 0.85, 0.7), 0.8, 9.0)
	ambience(Vector3(53, -5, -3), &"interior_wind")
	occluder("Occ_Floor", Vector3(53, Y - 1.5, -3), Vector3(30, 2, 22))


# S1 (Step 14): collision for the office shell drawn in dress() (floor, walls, ceiling) and the
# bookcase door in the lobby's west wall. Collision-only bodies: the visuals stay the Step 13 deco.
func _office_shell() -> void:
	var lo: Vector3 = S1_LO
	var hi: Vector3 = S1_HI
	var mid: Vector3 = (lo + hi) * 0.5
	_solid("S1_FloorSolid", Vector3(mid.x + 0.1, MEZZ - 0.1, mid.z), Vector3(hi.x - lo.x + 0.2, 0.2, hi.z - lo.z))
	_solid("S1_CeilingSolid", Vector3(mid.x, MEZZ + 3.2, mid.z), Vector3(hi.x - lo.x, 0.2, hi.z - lo.z))
	_solid("S1_WallWSolid", Vector3(lo.x, MEZZ + 1.6, mid.z), Vector3(0.2, 3.2, hi.z - lo.z))
	_solid("S1_WallNSolid", Vector3(mid.x, MEZZ + 1.6, hi.z), Vector3(hi.x - lo.x + 0.4, 3.2, 0.2))
	_solid("S1_WallSSolid", Vector3(mid.x, MEZZ + 1.6, lo.z), Vector3(hi.x - lo.x + 0.4, 3.2, 0.2))
	nav_door("S1_BookcaseDoor", Vector3(38.0, MEZZ + 1.2, S1_DOOR_Z), Vector3(0.45, 2.4, 1.6))


func _solid(node_name: String, center: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	body.physics_material_override = SurfaceTags.make_material(&"wood")
	body.set_meta(&"surface", &"wood")
	var col: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	col.shape = bs
	body.add_child(col)
	geometry.add_child(body)


# --- Step 13 art pass (13B): Belle Époque lobby, mezzanine, S1 office shell ----------------------


func dress() -> void:
	trim = "sanatorium"
	var warm: Color = Color(1.0, 0.72, 0.42)
	skin("ReceptionDesk", &"desk", Vector3(-1.2, 0, 0), PI)
	prop(&"desk", Vector3(54.2, Y, -6), PI)
	prop(&"reception_switchboard", Vector3(56.5, Y, -7.6), 0.0)
	fx(AtmosFx.Kind.SPARKS, Vector3(56.5, Y + 1.7, -7.3), Vector3(0.3, 0.1, 0.1), Vector3.FORWARD).set_meta(
		&"note", "switchboard"
	)
	fixture_light(
		&"", Vector3(56.5, Y + 1.8, -7.0), Color(1.0, 0.8, 0.5), 0.5, 4.0, PoweredLight.Pattern.FLICKER, false
	)
	skin("Clock", &"clock", Vector3.ZERO, PI)
	skin("Chandelier", &"chandelier_fallen", Vector3(0, 0, 0), 0.4)
	# Chequered floor accents + frost cracks; rugs.
	for i: int in 6:
		decal(
			&"frost",
			Vector3(40.0 + i * 5.0, Y + 0.05, 7.0 - (i % 2) * 2.0),
			Vector2(3.0, 3.0),
			Vector3.UP,
			i * 1.1,
			Color(1, 1, 1, 0.6)
		)
	deco("Rug", Vector3(53, Y + 0.01, -1.5), Vector3(7.0, 0.02, 4.0), &"red_paint")
	decal(&"grime", Vector3(53, Y + 0.05, -1.5), Vector2(6, 4))
	decal(&"water_stain", Vector3(44, Y + 0.05, -9), Vector2(3, 3), Vector3.UP, 0.4)
	decal(&"blood", Vector3(46, Y + 0.05, 6.6), Vector2(1.6, 1.6), Vector3.UP, 2.4)
	decal(&"handprints", Vector3(54, Y + 1.4, 7.75), Vector2(1.2, 1.2), Vector3.FORWARD)
	# Lounge furniture along the walls (clear of the hub paths).
	prop(&"armchair", Vector3(40.2, Y, -12.4), PI / 4.0)
	prop(&"armchair", Vector3(66.8, Y, -1.0), -PI / 2.0)
	prop(&"bench", Vector3(46, Y, -13.5), 0.0)
	prop(&"book_pile", Vector3(40.4, Y, -12.0), 0.3)
	# Vignette 2: the founder's portrait slashed; the Group Vesper banner over the original crest.
	var v: Node3D = vignette(
		"V02_Portrait",
		Vector3(53, Y + 5.6, 7.78),
		"the founder's portrait slashed; Group Vesper banner over the crest",
		PI
	)
	prop(&"portrait_slashed", Vector3(-6.0, -0.6, 0), 0.0, v)
	prop(&"crest", Vector3(0, 0.4, 0), 0.0, v)
	prop(&"banner", Vector3(0, 2.1, -0.06), 0.0, v)
	prop(&"portrait", Vector3(6.0, -0.6, 0), 0.0, v)
	signage("SANATORIUM VESPERHÖHE · MDCCCXCVIII", Vector3(53, Y + 8.4, 7.75), PI, 46, Color(0.85, 0.72, 0.45))
	signage("REQUISITIONED — GROUP VESPER — 1951", Vector3(44, Y + 2.2, -13.75), 0.0, 22, Color(0.92, 0.92, 0.85))
	signage("ACCUEIL · EMPFANG", Vector3(53, Y + 2.4, -6.62), 0.0, 24, Color(0.95, 0.85, 0.6))
	# Mezzanine: the reel desk, bookcases (S1 entrance at the west end).
	prop(&"bookcase", Vector3(39.3, MEZZ, 7.4), PI)
	prop(&"bookcase", Vector3(41.2, MEZZ, 7.75), PI)
	prop(&"desk", Vector3(42.5, MEZZ, 6.6), PI)
	prop(&"chair", Vector3(42.5, MEZZ, 5.8), PI)
	_director_office()
	# Lights: warm sconces (power), the chandelier hall lamp (shadowed), moon shafts from the windows.
	for p: Vector3 in [
		Vector3(38.25, Y + 2.6, 3),
		Vector3(67.75, Y + 2.6, -4),
		Vector3(38.25, Y + 2.6, -4),
		Vector3(46, Y + 2.6, -13.75),
		Vector3(60, Y + 2.6, -13.75)
	]:
		var yaw: float = PI / 2.0 if p.x < 39 else (-PI / 2.0 if p.x > 67 else 0.0)
		fixture_light(&"sconce", p, warm, 0.8, 7.0, PoweredLight.Pattern.NONE, true, 0, yaw)
	fixture_light(&"pendant", Vector3(53, Y + 7.6, -3), warm, 1.8, 18.0, PoweredLight.Pattern.NONE, true, 55)
	for wx: float in [46.0, 54.0]:
		spot_light(Vector3(wx, Y + 5.5, 10.5), Vector3(wx - 1.0, Y, 2.0), Color(0.6, 0.7, 1.0), 1.4, 20.0, 16.0)
	fx(AtmosFx.Kind.DUST, Vector3(53, Y + 4.0, -2), Vector3(12, 3.5, 8))
	fx(AtmosFx.Kind.DUST, Vector3(25, -3.0, -3), Vector3(8, 1.5, 1.2))
	# Walkway: frost and drifting snow through the broken roof lights.
	decal(&"frost", Vector3(17, 0.05, -3), Vector2(3, 3))
	fx(AtmosFx.Kind.SNOW_DRIFT, Vector3(18, 2.8, -3), Vector3(1.0, 0.2, 1.0), Vector3.DOWN)
	reverb(&"Reverb_Hall", Vector3(38, -8.5, -14), Vector3(68, 1.0, 8))
	reverb(&"Reverb_Room", Vector3(13.2, -8.5, -4.6), Vector3(38, 4.0, -1.4), 0.5)
	ambience(Vector3(48, -6, -8), &"room_tone")


# S1 Director's Office behind the mezzanine bookcase (VESPER_PEAK §3 S1): the room shell and its
# dressing (map table, Haemmer's pistol case, files). Visual only — Step 14 opens the bookcase and
# adds the walkable floor, collision and navigation.
func _director_office() -> void:
	var lo: Vector3 = Vector3(33.0, MEZZ, 2.6)
	var hi: Vector3 = Vector3(37.8, MEZZ + 3.2, 8.2)
	deco(
		"S1_Floor",
		Vector3((lo.x + hi.x) * 0.5, MEZZ - 0.1, (lo.z + hi.z) * 0.5),
		Vector3(hi.x - lo.x, 0.2, hi.z - lo.z),
		&"wood"
	)
	deco(
		"S1_Ceiling",
		Vector3((lo.x + hi.x) * 0.5, hi.y, (lo.z + hi.z) * 0.5),
		Vector3(hi.x - lo.x, 0.2, hi.z - lo.z),
		&"plaster"
	)
	deco("S1_WallW", Vector3(lo.x, MEZZ + 1.6, (lo.z + hi.z) * 0.5), Vector3(0.2, 3.2, hi.z - lo.z), &"plaster")
	deco("S1_WallN", Vector3((lo.x + hi.x) * 0.5, MEZZ + 1.6, hi.z), Vector3(hi.x - lo.x, 3.2, 0.2), &"plaster")
	deco("S1_WallS", Vector3((lo.x + hi.x) * 0.5, MEZZ + 1.6, lo.z), Vector3(hi.x - lo.x, 3.2, 0.2), &"plaster")
	var v: Node3D = vignette(
		"S1_DirectorsOffice",
		Vector3(35.4, MEZZ, 5.4),
		"Director's Office: survey map table, Haemmer's service pistol case, files"
	)
	deco("S1_MapTable", Vector3(35.4, MEZZ + 0.8, 5.6), Vector3(1.8, 0.06, 1.2), &"wood")
	deco("S1_Map", Vector3(35.4, MEZZ + 0.84, 5.6), Vector3(1.6, 0.01, 1.0), &"paper")
	prop(&"filing_cabinet", Vector3(33.5, MEZZ, 7.6), PI / 2.0, v)
	prop(&"filing_cabinet", Vector3(33.5, MEZZ, 3.4), PI / 2.0, v)
	deco("S1_PistolCase", Vector3(34.0, MEZZ + 1.2, 5.6), Vector3(0.1, 0.5, 0.8), &"glass_clear")
	prop(&"book_pile", Vector3(36.6, MEZZ + 0.84, 5.2), 0.5)
	fixture_light(
		&"", Vector3(35.4, MEZZ + 2.6, 5.4), Color(1.0, 0.7, 0.4), 0.5, 4.5, PoweredLight.Pattern.FLICKER, false
	)
