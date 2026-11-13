# Z13 Lazarus Reactor Chamber (VESPER_PEAK §3 Z13): the service shaft down from D14 (three 26.6°
# flights, -18 -> -48, with the west observation balcony at -38), the cavern (centre x 28,
# z -50, wall r 25.4, -58..-18), the Lower Ring training walkway (r 19..25 at y -48, ≈ 138 m),
# 6 pit-rift climbs + 2 spoke vents, the floating core with its containment rings, and the Forge
# platform (-34) the Reactor Bridge reaches from the Labs gantry. Railings over the pit carry a
# player clip so nobody falls in.
extends VesperZone

const C: Vector3 = Vector3(28.0, -48.0, -50.0)
const RING_IN: float = 19.0
const RING_OUT: float = 25.0
const WALL_R: float = 25.4
const SEGMENTS: int = 48
# Openings in the cavern wall (degrees, atan2(dz, dx)): lower band (ring level) / upper band.
const LOWER_GAPS: Array = [-142.2, 90.0, -90.0, 0.0]
# Upper-wall openings: the D14 shaft door, the Reactor Bridge gantry and (Step 13) the window the
# Z12 observation glass looks through (segment centred 11.25°).
const UPPER_GAPS: Array = [163.3, -24.4, 11.25]
const UPPER_OPEN: Array = [[-38.0, -34.4], [-28.0, -24.4], [-35.5, -28.6]]  # [bottom, top] of each upper gap


func build() -> void:
	_shaft()
	_ring()
	_cavern()
	_core_and_forge()
	area("Shaft", Vector3(-6, -49, -67), Vector3(0, -15, -37))
	area("Chamber", Vector3(0, -52, -78), Vector3(56, -17, -22))
	nav_areas.clear()
	nav_areas.append(AABB(Vector3(-6.0, -49.5, -67.2), Vector3(6.0, 33.0, 30.4)))  # shaft
	nav_areas.append(AABB(Vector3(0.0, -52.5, -78.0), Vector3(56.0, 26.5, 56.0)))  # chamber + gantry
	mark(&"forge", "FRG_LazarusForge", Vector3(33.5, -34.0, -60.0), "Lazarus Forge (5000)", true)
	mark(&"trap", "T3_CoolantPurge", _on_ring(0.0, 22.0), "Coolant Purge (ring quadrant)", true)
	# Step 11: the console sits just outside the 90° freeze sector (-45..45) so its user isn't frozen.
	mark(&"trap", "T3_Console", _on_ring(52.0, 24.6), "T3 console (1000)", true)
	mark(&"ee", "EE_CoreSocket", _on_ring(-90.0, 20.0), "core socket (stage 5 / finale)")
	for i: int in 4:
		var a: float = deg_to_rad(45.0 + 90.0 * i)
		mark(
			&"ee",
			"EE_Node_%d" % (i + 1),
			Vector3(C.x + cos(a) * 6.5, -44.0, C.z + sin(a) * 6.5),
			"vesperite node %d" % (i + 1)
		)
	for i: int in 3:
		mark(&"ee", "EE_Pylon_%d" % (i + 1), _on_ring(60.0 + 120.0 * i, 23.5), "stabilizer pylon %d" % (i + 1))
	mark(&"reel", "R08", Vector3(4.0, -38.0, -42.5), "audio reel R08 (balcony)")
	mark(&"ee", "EE_HaemmerCap", Vector3(31.5, -34.0, -56.6), "Haemmer's cap on the Forge rail")
	mark(&"ee", "EE_WardenRise", C + Vector3(0, -6.0, 0), "Warden rises from the pit (finale)")
	ambience(C + Vector3(0, 8, 0), &"reactor_drone")


func _on_ring(deg: float, r: float) -> Vector3:
	var a: float = deg_to_rad(deg)
	return Vector3(C.x + cos(a) * r, C.y, C.z + sin(a) * r)


# Service shaft x -6..0, z -67..-37: lanes A (x -6..-3) and B (x -3..0), landings N (z -44..-41)
# and S (z -67..-64).
func _shaft() -> void:
	box_mm("TopLanding", Vector3(-6.0, -18.5, -44.0), Vector3(0.0, -18.0, -41.0), &"metal")
	ramp("Flight1", Vector3(-4.5, -18.0, -44.0), Vector3(-4.5, -28.0, -64.0), 2.8, &"metal")
	box_mm("LandingS1", Vector3(-6.0, -28.5, -67.0), Vector3(0.0, -28.0, -64.0), &"metal")
	ramp("Flight2", Vector3(-1.5, -28.0, -64.0), Vector3(-1.5, -38.0, -44.0), 2.8, &"metal")
	box_mm("LandingN2", Vector3(-6.0, -38.5, -44.0), Vector3(0.0, -38.0, -41.0), &"metal")
	ramp("Flight3", Vector3(-4.5, -38.0, -44.0), Vector3(-4.5, -48.0, -64.0), 2.8, &"metal")
	box_mm("LandingS2", Vector3(-6.0, -48.5, -67.0), Vector3(0.0, -48.0, -64.0), &"metal")
	box_mm("ShaftW", Vector3(-6.4, -49.0, -67.2), Vector3(-6.0, -18.5, -36.8), &"stone")
	box_mm("ShaftN", Vector3(-6.4, -49.0, -41.2), Vector3(0.4, -15.0, -40.8), &"stone")
	box_mm("ShaftS", Vector3(-6.4, -49.0, -67.4), Vector3(0.4, -15.0, -67.0), &"stone")
	box_mm("ShaftDivider", Vector3(-3.1, -49.0, -64.0), Vector3(-2.9, -15.5, -44.0), &"metal")
	# East wall with the balcony (landing N2) and ring corridor (landing S2) openings.
	wall_x("ShaftE", 0.2, -67.0, -41.0, -49.0, 34.0, [[-42.5, 2.6, 11.0, 13.8], [-65.5, 2.6, 1.0, 3.8]], &"stone")
	box_mm("ShaftRoof", Vector3(-6.4, -15.5, -67.2), Vector3(0.4, -15.0, -40.8), &"stone")
	clip("ShaftClipTopB", Vector3(-1.5, -16.5, -44.0), Vector3(2.8, 3.0, 0.3))
	clip("ShaftClipBottomB", Vector3(-1.5, -46.5, -64.0), Vector3(2.8, 3.0, 0.3))
	# West observation balcony off landing N2, overlooking the core.
	box_mm("ObsBalcony", Vector3(0.0, -38.5, -45.0), Vector3(7.0, -38.0, -40.0), &"metal")
	for r: Array in [
		[Vector3(3.5, -37.5, -45.1), Vector3(7.0, 1.0, 0.15)],
		[Vector3(3.5, -37.5, -39.9), Vector3(7.0, 1.0, 0.15)],
		[Vector3(7.1, -37.5, -42.5), Vector3(0.15, 1.0, 5.2)]
	]:
		box("ObsRail_%d_%d" % [int(r[0].x), int(absf(r[0].z))], r[0], r[1], &"metal")
		clip(
			"ObsClip_%d_%d" % [int(r[0].x), int(absf(r[0].z))], r[0] + Vector3(0, 1.0, 0), Vector3(r[1].x, 3.0, r[1].z)
		)
	box("ObsDesk", Vector3(5.5, -37.5, -42.5), Vector3(1.0, 1.0, 2.4), &"brass")
	# Corridor from landing S2 to the ring (west-south-west spoke).
	room(
		"SpokeWSW",
		Vector3(0.0, -48.0, -67.0),
		Vector3(8.8, (-48.0) + (3.2), -64.0),
		{"W": false, "E": false},
		[&"metal", &"stone"]
	)


func _ring() -> void:
	var step: float = TAU / SEGMENTS
	var r_mid: float = (RING_IN + RING_OUT) * 0.5
	for i: int in SEGMENTS:
		var a: float = step * (i + 0.5)
		var dir: Vector3 = Vector3(cos(a), 0, sin(a))
		var bs: Basis = Basis(Vector3.UP, atan2(dir.x, dir.z))
		var seg_len: float = 2.0 * RING_OUT * tan(step * 0.5) + 0.1
		slab(
			"Ring_%02d" % i,
			Transform3D(bs, C + dir * r_mid + Vector3(0, -0.25, 0)),
			Vector3(seg_len, 0.5, RING_OUT - RING_IN),
			&"metal"
		)
		var in_len: float = 2.0 * RING_IN * tan(step * 0.5) + 0.05
		slab(
			"Rail_%02d" % i,
			Transform3D(bs, C + dir * (RING_IN + 0.1) + Vector3(0, 0.5, 0)),
			Vector3(in_len, 1.0, 0.15),
			&"brass"
		)
		var cl: StaticBody3D = clip(
			"RailClip_%02d" % i, C + dir * (RING_IN + 0.1) + Vector3(0, 2.0, 0), Vector3(in_len, 3.0, 0.2)
		)
		cl.rotation.y = atan2(dir.x, dir.z)
	# Pit rifts: ledges below the railing, zombies climb onto the ring.
	for i: int in 6:
		var d: float = 30.0 + 60.0 * i
		climb("Rift%d" % (i + 1), _on_ring(d, 16.5) + Vector3(0, -3.0, 0), _on_ring(d, 20.6), 2)
	# Spoke vents (north / south) through the cavern wall.
	for v: Array in [["VentN", 90.0], ["VentS", -90.0]]:
		var a2: float = deg_to_rad(float(v[1]))
		var out: Vector3 = Vector3(cos(a2), 0, sin(a2)).round()
		vent(String(v[0]), _on_ring(float(v[1]), WALL_R), out)
		clip(
			"%s_WideClip" % v[0],
			_on_ring(float(v[1]), WALL_R) + Vector3(0, 0.9, 0),
			Vector3(3.2, 1.8, 0.3),
			VesperZone.yaw_of(out)
		)
	# East alcove (coolant trap console).
	var e: Vector3 = _on_ring(0.0, WALL_R)
	box_mm("AlcoveE_Floor", e + Vector3(-0.2, -0.5, -2.0), e + Vector3(3.0, 0.0, 2.0), &"metal")
	box_mm("AlcoveE_Back", e + Vector3(3.0, 0.0, -2.2), e + Vector3(3.4, 3.2, 2.2), &"stone")
	for s: float in [-1.0, 1.0]:
		box_mm(
			"AlcoveE_Side%d" % int(s),
			e + Vector3(-0.2, 0.0, s * 2.0 - 0.2),
			e + Vector3(3.0, 3.2, s * 2.0 + 0.2),
			&"stone"
		)
	box_mm("AlcoveE_Top", e + Vector3(-0.2, 3.2, -2.2), e + Vector3(3.4, 3.6, 2.2), &"stone")


func _gap_at(a_deg: float, gaps: Array, half_width_deg: float) -> bool:
	return _gap_index(a_deg, gaps, half_width_deg) >= 0


func _gap_index(a_deg: float, gaps: Array, half_width_deg: float) -> int:
	for i: int in gaps.size():
		var d: float = absf(wrapf(a_deg - float(gaps[i]), -180.0, 180.0))
		if d < half_width_deg:
			return i
	return -1


func _cavern() -> void:
	var step: float = TAU / SEGMENTS
	var seg_len: float = 2.0 * WALL_R * tan(step * 0.5) + 0.2
	var half: float = rad_to_deg(step) * 0.5 + 0.5
	for i: int in SEGMENTS:
		var a: float = step * (i + 0.5)
		var a_deg: float = rad_to_deg(wrapf(a, -PI, PI))
		var dir: Vector3 = Vector3(cos(a), 0, sin(a))
		var yaw: float = atan2(dir.x, dir.z)
		var bs: Basis = Basis(Vector3.UP, yaw)
		var p: Vector3 = C + dir * (WALL_R + 0.3)
		if not _gap_at(a_deg, LOWER_GAPS, half):
			slab("WallLow_%02d" % i, Transform3D(bs, Vector3(p.x, -46.0, p.z)), Vector3(seg_len, 12.0, 0.6), &"stone")
		else:
			slab(
				"WallLowLintel_%02d" % i,
				Transform3D(bs, Vector3(p.x, -42.8, p.z)),
				Vector3(seg_len, 5.6, 0.6),
				&"stone"
			)
		var g: int = _gap_index(a_deg, UPPER_GAPS, half)
		if g < 0:
			slab("WallHigh_%02d" % i, Transform3D(bs, Vector3(p.x, -29.0, p.z)), Vector3(seg_len, 22.0, 0.6), &"stone")
		else:
			var lo: float = float(UPPER_OPEN[g][0])
			var hi: float = float(UPPER_OPEN[g][1])
			slab(
				"WallHighLow_%02d" % i,
				Transform3D(bs, Vector3(p.x, (-40.0 + lo) * 0.5, p.z)),
				Vector3(seg_len, lo + 40.0, 0.6),
				&"stone"
			)
			slab(
				"WallHighTop_%02d" % i,
				Transform3D(bs, Vector3(p.x, (hi - 18.0) * 0.5, p.z)),
				Vector3(seg_len, -18.0 - hi, 0.6),
				&"stone"
			)
	box_mm("CavernRoof", Vector3(0.5, -18.5, -77.5), Vector3(55.5, -18.0, -22.5), &"stone")
	_seal_openings()
	occluder("Occ_Roof", Vector3(28, -15.5, -50), Vector3(54, 4, 54))


# Map quality pass: each wall opening is two 7.5° segments (~6.9 m) wide while the vents (4.4 m),
# the east alcove (4.4 m) and the WSW spoke corridor (3 m) behind them are narrower, which left
# slits through to the void beside them. Rock pockets close the openings around what's behind.
func _seal_openings() -> void:
	for deg: float in [90.0, -90.0, 0.0]:
		var a: float = deg_to_rad(deg)
		var out: Vector3 = Vector3(cos(a), 0, sin(a))
		var tan_dir: Vector3 = Vector3(-out.z, 0, out.x)
		var bs: Basis = Basis(Vector3.UP, atan2(out.x, out.z))
		var base: Vector3 = C + out * WALL_R
		# back face (behind the vent / alcove), side cheeks and a lid under the lintel
		slab(
			"SealBack_%d" % int(deg),
			Transform3D(bs, base + out * 4.0 + Vector3(0, 3.5, 0)),
			Vector3(8.4, 8.0, 0.6),
			&"stone"
		)
		for sd: float in [-1.0, 1.0]:
			slab(
				"SealSide_%d_%d" % [int(deg), int(sd)],
				Transform3D(bs, base + out * 2.15 + tan_dir * sd * 4.0 + Vector3(0, 3.5, 0)),
				Vector3(0.6, 8.0, 3.9),
				&"stone"
			)
		slab(
			"SealLid_%d" % int(deg),
			Transform3D(bs, base + out * 2.15 + Vector3(0, 4.3, 0)),
			Vector3(8.4, 0.5, 3.9),
			&"stone"
		)
	# Below the ring at the openings (the wall segments there start at the ring floor).
	var step: float = TAU / SEGMENTS
	var seg_len: float = 2.0 * WALL_R * tan(step * 0.5) + 0.2
	var half: float = rad_to_deg(step) * 0.5 + 0.5
	for i: int in SEGMENTS:
		var a2: float = step * (i + 0.5)
		if not _gap_at(rad_to_deg(wrapf(a2, -PI, PI)), LOWER_GAPS, half):
			continue
		var d2: Vector3 = Vector3(cos(a2), 0, sin(a2))
		slab(
			"WallLowFoot_%02d" % i,
			Transform3D(Basis(Vector3.UP, atan2(d2.x, d2.z)), C + d2 * (WALL_R + 0.3) + Vector3(0, -4.0, 0)),
			Vector3(seg_len, 7.0, 0.6),
			&"stone"
		)
	# The pit: a rock shaft under the ring's inner edge down to the vesperite pool, so looking over
	# the railing shows the shaft wall instead of the space under the ring. Its top stays 1.1 m under
	# the ring so the rift climbs (pad r 16.5 -> ring r 20.6) pass over it.
	var pit_len: float = 2.0 * (RING_IN + 0.4) * tan(step * 0.5) + 0.12
	for i: int in SEGMENTS:
		var a3: float = step * (i + 0.5)
		var d3: Vector3 = Vector3(cos(a3), 0, sin(a3))
		slab(
			"PitWall_%02d" % i,
			Transform3D(Basis(Vector3.UP, atan2(d3.x, d3.z)), C + d3 * (RING_IN + 0.4) + Vector3(0, -6.15, 0)),
			Vector3(pit_len, 9.1, 0.6),
			&"stone"
		)
	box("PitFloor", C + Vector3(0, -10.6, 0), Vector3(40.0, 0.6, 40.0), &"stone")
	# WSW spoke: rock either side of the corridor where it pierces the wall.
	box_mm("SealSpokeN", Vector3(3.5, -48.5, -63.8), Vector3(10.5, -43.0, -61.0), &"stone")
	box_mm("SealSpokeS", Vector3(3.5, -48.5, -70.0), Vector3(10.5, -43.0, -67.2), &"stone")
	box_mm("SealSpokeTop", Vector3(3.5, -44.8, -70.0), Vector3(10.5, -43.0, -61.0), &"stone")
	# Shaft balcony opening: the shaft's north wall stops at z -40.8; the opening runs to ~-39.4.
	box_mm("SealShaftN", Vector3(0.0, -39.0, -40.8), Vector3(4.2, -33.6, -38.2), &"stone")


func _core_and_forge() -> void:
	var core: MeshInstance3D = MeshInstance3D.new()
	core.name = "ReactorCore"
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 3.0
	sm.height = 6.0
	core.mesh = sm
	core.material_override = _mat(&"vesperite")
	core.position = C + Vector3(0, 4.0, 0)
	geometry.add_child(core)
	var state: ReactorState = ReactorState.new()
	state.name = "ReactorState"
	state.core = core
	state.bridge_position = Vector3(44.0, -31.0, -60.0)
	for i: int in 3:
		var ring: MeshInstance3D = MeshInstance3D.new()
		ring.name = "ContainmentRing%d" % (i + 1)
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = 5.0 + i * 1.2
		tm.outer_radius = 5.5 + i * 1.2
		ring.mesh = tm
		ring.material_override = _mat(&"brass")
		ring.position = core.position
		ring.rotation = Vector3(PI * 0.5 * (i % 2), PI / 3.0 * i, 0.3 * i)
		geometry.add_child(ring)
		state.rings.append(ring)
	var glow: OmniLight3D = lamp(core.position, Color(0.4, 1.0, 0.55), 6.0, 45.0, true, 0.25)
	glow.shadow_enabled = false
	geometry.add_child(state)  # adds its own stage light (the glow above follows the power cascade)
	var pit: MeshInstance3D = MeshInstance3D.new()
	pit.name = "PitGlow"
	var pm: CylinderMesh = CylinderMesh.new()
	pm.top_radius = RING_IN
	pm.bottom_radius = RING_IN
	pm.height = 0.2
	pit.mesh = pm
	pit.material_override = _mat(&"vesperite")
	pit.position = C + Vector3(0, -10.0, 0)
	geometry.add_child(pit)
	# Forge platform (x 30..38, z -64..-56, y -34); its only way in is the Reactor Bridge (Z11).
	box_mm("ForgePlatform", Vector3(30.0, -34.5, -64.0), Vector3(38.0, -34.0, -56.0), &"brass")
	for r: Array in [
		[Vector3(34, -33.5, -64.1), Vector3(8, 1, 0.15)],
		[Vector3(34, -33.5, -55.9), Vector3(8, 1, 0.15)],
		[Vector3(29.9, -33.5, -60), Vector3(0.15, 1, 8.2)],
		[Vector3(38.1, -33.5, -63.0), Vector3(0.15, 1, 2.0)],
		[Vector3(38.1, -33.5, -57.0), Vector3(0.15, 1, 2.0)]
	]:
		box("ForgeRail_%d_%d" % [int(r[0].x), int(absf(r[0].z))], r[0], r[1], &"brass")
		clip(
			"ForgeClip_%d_%d" % [int(r[0].x), int(absf(r[0].z))],
			r[0] + Vector3(0, 1.0, 0),
			Vector3(r[1].x, 3.0, r[1].z)
		)
	# Collision + nav carve of the Lazarus Forge; the machine itself is drawn by LazarusForge (Step 11).
	var anvil: StaticBody3D = box("ForgeAnvil", Vector3(33.0, -33.4, -60.0), Vector3(2.0, 1.2, 1.4), &"metal")
	(anvil.get_child(0) as MeshInstance3D).visible = false
	for p: Vector3 in [
		_on_ring(45.0, 24.0) + Vector3(0, 6, 0),
		_on_ring(135.0, 24.0) + Vector3(0, 6, 0),
		_on_ring(-45.0, 24.0) + Vector3(0, 6, 0),
		_on_ring(-135.0, 24.0) + Vector3(0, 6, 0)
	]:
		lamp(p, Color(1.0, 0.8, 0.55), 1.4, 18.0)


# --- Step 13 art pass (13D): the reactor core, cable bundles, arcs, heartbeat, the Forge platform -


func dress() -> void:
	trim = "cavern"
	var core_pos: Vector3 = C + Vector3(0, 4.0, 0)
	var state: ReactorState = geometry.get_node_or_null("ReactorState") as ReactorState
	# The core and its rings animate (ReactorState): keep them out of the static batch.
	for n: String in ["ReactorCore", "ContainmentRing1", "ContainmentRing2", "ContainmentRing3"]:
		var mi: Node = geometry.get_node_or_null(n)
		if mi != null:
			mi.set_meta(&"no_batch", true)
	# Heartbeat sync: the core's pulse follows the reactor drone's playback (AmbienceLibrary
	# REACTOR_BPM), so light and sound thump together.
	if state != null:
		for e: Node in audio.get_children():
			if e is AmbienceEmitter and (e as AmbienceEmitter).event == &"amb_reactor":
				state.heartbeat = e as AmbienceEmitter
	# Cable bundles "thick as tree trunks" from the containment rings to the cavern wall.
	var b: MeshBatch = MeshBatch.new()
	var rubber: Material = VesperProps.m(&"rubber")
	var brass: Material = VesperProps.m(&"brass")
	for i: int in 6:
		var a: float = deg_to_rad(15.0 + 60.0 * i)
		var dir: Vector3 = Vector3(cos(a), 0, sin(a))
		var p0: Vector3 = core_pos + dir * 7.5 + Vector3(0, -0.5 + (i % 2) * 1.2, 0)
		var p1: Vector3 = C + dir * (WALL_R - 0.2) + Vector3(0, 9.0 + (i % 3) * 2.0, 0)
		var mid: Vector3 = (p0 + p1) * 0.5 + Vector3(0, -2.5, 0)  # sag
		for seg: Array in [[p0, mid], [mid, p1]]:
			var q0: Vector3 = seg[0]
			var q1: Vector3 = seg[1]
			b.add(
				MeshBatch.Shape.CYLINDER,
				Vector3(0.9, q0.distance_to(q1) + 0.3, 0.9),
				Transform3D(_basis_along(q1 - q0) * Basis(Vector3.RIGHT, PI / 2.0), (q0 + q1) * 0.5),
				rubber
			)
		b.cyl(0.6, 0.4, mid, brass)
		# The wall end: a brass collar and a vertical run down to the ring.
		b.cyl(0.7, 0.6, p1, brass)
		b.cyl(0.35, p1.y - (C.y + 0.5), Vector3(p1.x, (p1.y + C.y + 0.5) * 0.5, p1.z) + dir * 0.4, rubber)
	art.add_child(b.instance("CableBundles", 200.0))
	# Pit: the drop is lit from below; arcs crackle between the rings (energy wisps + pulsing light).
	fixture_light(&"", C + Vector3(0, -8.0, 0), Color(0.3, 1.0, 0.5), 2.0, 22.0, PoweredLight.Pattern.PULSE, true)
	for i: int in 4:
		var a2: float = TAU * i / 4.0 + 0.4
		var p: Vector3 = core_pos + Vector3(cos(a2) * 6.0, sin(a2 * 2.0) * 1.5, sin(a2) * 6.0)
		fx(AtmosFx.Kind.ENERGY, p, Vector3(0.6, 0.6, 0.6))
	fx(AtmosFx.Kind.DUST, C + Vector3(0, 6.0, 0), Vector3(20, 8, 20))
	fx(AtmosFx.Kind.HAZE, C + Vector3(0, -1.0, 0), Vector3(14, 2.0, 14))
	fog(C + Vector3(0, -6.0, 0), Vector3(36, 10, 36), Color(0.35, 0.8, 0.45), 0.12, Color(0.0, 0.03, 0.01))
	# Lower Ring: rim lights on the wall (brass cages), grime, frost by the coolant sector.
	for i: int in 8:
		var a3: float = TAU * i / 8.0 + 0.2
		var wp: Vector3 = C + Vector3(cos(a3), 0, sin(a3)) * (WALL_R - 0.25) + Vector3(0, 3.2, 0)
		prop(&"caged_bulb", wp)
		decal(&"grime", C + Vector3(cos(a3), 0, sin(a3)) * 22.0 + Vector3(0, 0.05, 0), Vector2(4, 4), Vector3.UP, a3)
	for k: int in 3:
		var a4: float = deg_to_rad(-30.0 + 30.0 * k)
		decal(&"frost", C + Vector3(cos(a4), 0, sin(a4)) * 22.0 + Vector3(0, 0.05, 0), Vector2(5, 5), Vector3.UP, a4)
	decal(
		&"hazard_stripes", _on_ring(45.0, 22.0) + Vector3(0, 0.05, 0), Vector2(0.6, 6.0), Vector3.UP, deg_to_rad(-45.0)
	)
	decal(
		&"hazard_stripes", _on_ring(-45.0, 22.0) + Vector3(0, 0.05, 0), Vector2(0.6, 6.0), Vector3.UP, deg_to_rad(45.0)
	)
	signage("LAZARUS-REAKTOR · KERN 1", Vector3(28.0, -40.0, -24.95), PI, 60, Color(0.6, 1.0, 0.7))
	# Observation balcony desk + chair; spoke vents.
	skin("ObsDesk", &"console", Vector3.ZERO, -PI / 2.0)
	prop(&"chair", Vector3(4.6, -38.0, -42.5), PI / 2.0)
	# Vignette 10: Haemmer's officer cap on the Forge platform rail.
	var v: Node3D = vignette(
		"V10_HaemmerCap", Vector3(31.5, -33.0, -56.6), "Haemmer's officer cap on the Forge platform rail"
	)
	prop(&"cap", Vector3(0, 0.0, 0), 0.6, v)
	fixture_light(&"", Vector3(31.5, -31.5, -56.6), Color(1.0, 0.85, 0.6), 0.4, 3.0, PoweredLight.Pattern.NONE, false)
	_dress_cavern()
	reverb(&"Reverb_Cavern", Vector3(0, -52, -78), Vector3(56, -17, -22))
	reverb(&"Reverb_Tunnel", Vector3(-6, -49, -67), Vector3(0, -15, -37))


# Map quality pass: the cavern read as a smooth green cylinder. Rock outcrops break up the wall
# above head height, stalactites hang from the roof, pipe risers and supply clutter line the ring
# between the gameplay spots, and vesperite crystals glow in the pit.
func _dress_cavern() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1313
	var holder: Node3D = _art_group("Cavern")
	var keep_clear: Array = [52.0, 60.0, 180.0, -60.0, -90.0, 0.0, 90.0, -142.2, 163.3, -24.4, 11.25]
	for i: int in SEGMENTS:
		var a_deg: float = 360.0 * (i + 0.5) / SEGMENTS
		var a: float = deg_to_rad(a_deg)
		var dir: Vector3 = Vector3(cos(a), 0, sin(a))
		var yaw: float = atan2(-dir.x, -dir.z)
		var w_deg: float = rad_to_deg(wrapf(a, -PI, PI))
		var near_gap: bool = _gap_at(w_deg, UPPER_GAPS, 11.0)
		if i % 2 == 0 and not near_gap:
			var rp: MeshInstance3D = prop(
				&"rock_pillar",
				C + dir * (WALL_R - 0.1) + Vector3(0, 3.8 + rng.randf_range(0.0, 9.0), 0),
				yaw + rng.randf_range(-0.3, 0.3),
				holder
			)
			rp.scale = Vector3.ONE * rng.randf_range(0.8, 1.5)
		var clear: bool = true
		for k: float in keep_clear:
			if absf(wrapf(w_deg - k, -180.0, 180.0)) < 9.0:
				clear = false
		if not clear:
			continue
		match i % 4:
			0:
				prop(&"wall_pipes", C + dir * (WALL_R - 0.05), yaw, holder)
			1:
				prop(&"crate", C + dir * (WALL_R - 0.5), yaw + rng.randf_range(-0.2, 0.2), holder)
			2:
				prop(&"barrel_cluster", C + dir * (WALL_R - 0.7), yaw, holder)
			3:
				prop(&"rubble", C + dir * (WALL_R - 0.8), yaw + rng.randf(), holder)
	# Stalactites from the roof (outside the core's column).
	for k: int in 26:
		var r: float = rng.randf_range(9.0, 24.0)
		var ang: float = rng.randf() * TAU
		var st: MeshInstance3D = prop(
			&"stalactites", C + Vector3(cos(ang) * r, 29.5, sin(ang) * r), rng.randf() * TAU, holder
		)
		st.scale = Vector3.ONE * rng.randf_range(1.0, 2.6)
	# Vesperite crystals on the pit floor and wall foot: emissive, they light the shaft from below.
	for k: int in 22:
		var r2: float = rng.randf_range(3.0, 18.0)
		var ang2: float = rng.randf() * TAU
		var h: float = rng.randf_range(0.8, 3.2)
		deco(
			"PitCrystal_%d" % k,
			C + Vector3(cos(ang2) * r2, -10.3 + h * 0.5, sin(ang2) * r2),
			Vector3(0.35, h, 0.35) * rng.randf_range(0.7, 1.4),
			&"vesperite",
			Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))
		)
	# Warm work lamps on the outer ring between the caged bulbs.
	for k: int in 4:
		var a3: float = deg_to_rad(112.0 + 90.0 * k)
		fixture_light(
			&"caged_bulb",
			C + Vector3(cos(a3), 0, sin(a3)) * (WALL_R - 0.3) + Vector3(0, 2.6, 0),
			Color(1.0, 0.72, 0.42),
			1.0,
			9.0,
			PoweredLight.Pattern.FLICKER,
			true
		)
