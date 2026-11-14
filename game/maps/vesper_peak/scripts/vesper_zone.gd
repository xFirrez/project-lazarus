# VesperZone — base script of every Vesper Peak zone scene (VESPER_PEAK §9): builds the zone's
# greybox at load under `Geometry/` (static colliders, kit materials), `Gameplay/` (zone volumes,
# spawners, barricades, links, doors, interactables, markers — the sacred layer), `Lighting/` and
# `Audio/`, and reports its navigation tile boxes (`nav_areas`) to the map root, which bakes one
# tile per area (NavTiles). Coordinates are map-global; datum y 0 = the Arrival Station floor
# (+28 m real elevation). Axes: +X east, +Z north.
# Subclasses override `build()` (greybox + gameplay, Step 8) and `dress()` (Step 13 art pass:
# everything under `Art/` — props, fixtures, decals, signage, FX, reverb zones and vignettes —
# is visual only and never moves or adds gameplay nodes; D-076). `trim` picks the automatic
# architectural trim pass run over the zone's wall boxes after dressing.
# Authority: static map data; doors / barricades / machines replicate through core systems.
class_name VesperZone
extends VesperZoneArt

const WALL_T: float = 0.4
const SLAB_T: float = 0.5
const CORRIDOR_LAP: float = 0.25

var nav_areas: Array[AABB] = []
var rooms: Array = []  # [lo, hi, prefix] of every roofed room() (auto lighting)
var occluders: int = 0
var _corridor_ends: Array = []  # [point, basis] of every corridor() end (joint fillers)


func _ready() -> void:
	for n: String in ["Geometry", "Gameplay", "Lighting", "Audio", "Art"]:
		var c: Node3D = Node3D.new()
		c.name = n
		add_child(c)
	geometry = $Geometry
	gameplay = $Gameplay
	lighting = $Lighting
	audio = $Audio
	art = $Art
	build()
	dress()
	_auto_furnish()
	_auto_light()
	if trim != "":
		_auto_trim()
	batch_static()
	set_process(not _spinners.is_empty())


func build() -> void:
	pass


func dress() -> void:
	pass


# --- geometry -----------------------------------------------------------------------------------


func box(node_name: String, center: Vector3, size: Vector3, style: StringName = &"concrete") -> StaticBody3D:
	return slab(node_name, Transform3D(Basis.IDENTITY, center), size, style)


func box_mm(node_name: String, lo: Vector3, hi: Vector3, style: StringName = &"concrete") -> StaticBody3D:
	return box(node_name, (lo + hi) * 0.5, (hi - lo).abs(), style)


func slab(node_name: String, xf: Transform3D, size: Vector3, style: StringName = &"concrete") -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.transform = xf
	body.collision_layer = 1
	body.collision_mask = 0
	var st: Array = STYLES.get(style, STYLES[&"concrete"])
	body.physics_material_override = SurfaceTags.make_material(st[1])
	body.set_meta(&"surface", st[1])
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = _mat(style)
	if size.length() < 4.0:
		mesh.visibility_range_end = 70.0  # small props: distance-cull (perf baseline)
	body.add_child(mesh)
	var col: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	col.shape = bs
	body.add_child(col)
	geometry.add_child(body)
	return body


# Player-only invisible blocker (railings over pits, window clips): not navigation, not bullets.
func clip(node_name: String, center: Vector3, size: Vector3, yaw: float = 0.0) -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	b.name = node_name
	b.collision_layer = MotorComponent.PLAYER_CLIP_LAYER
	b.collision_mask = 0
	b.position = center
	b.rotation.y = yaw
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	gameplay.add_child(b)
	return b


# Sloped (or flat) floor whose TOP surface runs from `a` to `b` (centre line).
func ramp(node_name: String, a: Vector3, b: Vector3, width: float, style: StringName = &"concrete") -> StaticBody3D:
	var bs: Basis = _basis_along(b - a)
	var c: Vector3 = (a + b) * 0.5 - bs.y * (SLAB_T * 0.5)
	return slab(node_name, Transform3D(bs, c), Vector3(width, SLAB_T, a.distance_to(b) + 0.05), style)


# Enclosed passage from a to b (floor top centre line): floor, side walls, roof (all pitched).
func corridor(
	prefix: String,
	a: Vector3,
	b: Vector3,
	width: float,
	height: float = 3.2,
	style: StringName = &"concrete",
	walls: bool = true,
	roof: bool = true
) -> void:
	ramp("%s_Floor" % prefix, a, b, width, style)
	var bs: Basis = _basis_along(b - a)
	# Walls and roof run CORRIDOR_LAP past both ends so a pitched passage meets the next wall (or a
	# lintel) without a wedge-shaped slit to the outside (map quality pass).
	var length: float = a.distance_to(b) + 0.05 + CORRIDOR_LAP * 2.0
	var mid: Vector3 = (a + b) * 0.5
	if walls:
		for side: float in [-1.0, 1.0]:
			var c: Vector3 = mid + bs.x * side * (width * 0.5 + WALL_T * 0.5) + bs.y * (height * 0.5 - SLAB_T)
			slab(
				"%s_Wall%s" % [prefix, "L" if side < 0 else "R"],
				Transform3D(bs, c),
				Vector3(WALL_T, height + SLAB_T * 2.0, length),
				style
			)
	if roof:
		slab(
			"%s_Roof" % prefix,
			Transform3D(bs, mid + bs.y * (height + SLAB_T * 0.5)),
			Vector3(width + WALL_T * 2.0, SLAB_T, length),
			style
		)
	# Where two passages meet at an angle (flat walkway -> ramp), the slabs open a wedge at the
	# outer side of the bend: close it with a short joint section on the averaged slope.
	for e: Vector3 in [a, b]:
		for prev: Array in _corridor_ends:
			var pe: Vector3 = prev[0]
			var pb: Basis = prev[1]
			if pe.distance_to(e) > 0.05 or pb.z.dot(bs.z) > 0.999 or absf(pb.z.dot(bs.z)) < 0.5:
				continue
			var other: Basis = pb if pb.z.dot(bs.z) > 0.0 else pb.rotated(pb.y, PI)
			var jb: Basis = Basis(bs.get_rotation_quaternion().slerp(other.get_rotation_quaternion(), 0.5))
			var jn: String = "%s_Joint%d" % [prefix, _corridor_ends.size()]
			if roof:
				slab(
					"%s_Roof" % jn,
					Transform3D(jb, e + jb.y * (height + SLAB_T * 0.5)),
					Vector3(width + WALL_T * 2.0, SLAB_T, 1.6),
					style
				)
			if walls:
				for side: float in [-1.0, 1.0]:
					slab(
						"%s_Wall%d" % [jn, int(side)],
						Transform3D(jb, e + jb.x * side * (width * 0.5 + WALL_T * 0.5) + jb.y * (height * 0.5)),
						Vector3(WALL_T, height + SLAB_T, 1.6),
						style
					)
	_corridor_ends.append([a, bs])
	_corridor_ends.append([b, bs])


# Steps (navigation and players both handle 0.25 m risers) from a (bottom) to b (top), width w.
func stairs(prefix: String, a: Vector3, b: Vector3, width: float, style: StringName = &"wood") -> void:
	var rise: float = b.y - a.y
	var n: int = maxi(int(ceil(absf(rise) / 0.25)), 1)
	var flat: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
	var bs: Basis = Basis.looking_at(flat.normalized(), Vector3.UP)
	for i: int in n:
		var top: float = a.y + rise * float(i + 1) / float(n)
		var f0: float = float(i) / float(n)
		var f1: float = float(i + 1) / float(n)
		var c: Vector3 = a + flat * ((f0 + f1) * 0.5)
		var h: float = top - (a.y - 0.3)
		c.y = top - h * 0.5
		slab("%s_%02d" % [prefix, i], Transform3D(bs, c), Vector3(width, h, flat.length() / float(n) + 0.02), style)


# Wall along Z (constant x) or along X (constant z), base y0, with openings
# [[centre, width, bottom (relative to y0), top (relative)], ...].
func wall_x(
	prefix: String,
	x: float,
	z0: float,
	z1: float,
	y0: float,
	h: float,
	openings: Array = [],
	style: StringName = &"concrete"
) -> void:
	_wall(prefix, true, x, Vector4(z0, z1, y0, h), openings, style)


func wall_z(
	prefix: String,
	z: float,
	x0: float,
	x1: float,
	y0: float,
	h: float,
	openings: Array = [],
	style: StringName = &"concrete"
) -> void:
	_wall(prefix, false, z, Vector4(x0, x1, y0, h), openings, style)


# dims = (start, end) along the wall, base y, height.
func _wall(prefix: String, along_z: bool, fixed: float, dims: Vector4, openings: Array, style: StringName) -> void:
	var a0: float = dims.x
	var a1: float = dims.y
	var y0: float = dims.z
	var h: float = dims.w
	var cuts: Array = openings.duplicate()
	cuts.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var cursor: float = a0
	var n: int = 0
	for o: Array in cuts:
		var lo: float = float(o[0]) - float(o[1]) * 0.5
		var hi: float = float(o[0]) + float(o[1]) * 0.5
		if lo > cursor:
			_wall_box("%s_%d" % [prefix, n], along_z, fixed, cursor, lo, y0, y0 + h, style)
			n += 1
		if float(o[2]) > 0.0:
			_wall_box("%s_%d" % [prefix, n], along_z, fixed, lo, hi, y0, y0 + float(o[2]), style)
			n += 1
		var lintel: StaticBody3D = _wall_box(
			"%s_%d" % [prefix, n], along_z, fixed, lo, hi, y0 + float(o[3]), y0 + h, style
		)
		if lintel != null:
			lintel.set_meta(&"wall_part", &"lintel")
		n += 1
		cursor = maxf(cursor, hi)
	if cursor < a1:
		_wall_box("%s_%d" % [prefix, n], along_z, fixed, cursor, a1, y0, y0 + h, style)


func _wall_box(
	node_name: String, along_z: bool, fixed: float, a0: float, a1: float, y0: float, y1: float, style: StringName
) -> StaticBody3D:
	if a1 - a0 < 0.01 or y1 - y0 < 0.01:
		return null
	var mid: float = (a0 + a1) * 0.5
	var c: Vector3 = Vector3(fixed, (y0 + y1) * 0.5, mid) if along_z else Vector3(mid, (y0 + y1) * 0.5, fixed)
	var s: Vector3 = Vector3(WALL_T, y1 - y0, a1 - a0) if along_z else Vector3(a1 - a0, y1 - y0, WALL_T)
	return box(node_name, c, s, style)


# A rectangular room from lo (x0, floor y, z0) to hi (x1, floor y + wall height, z1). `open`
# maps "N" (z1), "S" (z0), "E" (x1), "W" (x0) to opening lists (see _wall); a side mapped to false
# gets no wall. `styles` = [floor style, wall style].
func room(
	prefix: String,
	lo: Vector3,
	hi: Vector3,
	open: Dictionary = {},
	styles: Array = [],
	with_floor: bool = true,
	with_roof: bool = true
) -> void:
	var fs: StringName = StringName(styles[0]) if styles.size() > 0 else &"concrete"
	var ws: StringName = StringName(styles[1]) if styles.size() > 1 else &"concrete"
	var t: float = WALL_T * 0.5
	var y: float = lo.y
	var h: float = hi.y - lo.y
	if with_floor:
		box_mm("%s_Floor" % prefix, Vector3(lo.x - t, y - SLAB_T, lo.z - t), Vector3(hi.x + t, y, hi.z + t), fs)
	if with_roof:
		rooms.append([lo, hi, prefix])
		box_mm("%s_Roof" % prefix, Vector3(lo.x - t, hi.y, lo.z - t), Vector3(hi.x + t, hi.y + SLAB_T, hi.z + t), ws)
	for side: String in ["N", "S", "E", "W"]:
		var o: Variant = open.get(side, [])
		if o is bool and not o:
			continue
		var ops: Array = o if o is Array else []
		match side:
			"N":
				wall_z("%s_N" % prefix, hi.z, lo.x - t, hi.x + t, y, h, ops, ws)
			"S":
				wall_z("%s_S" % prefix, lo.z, lo.x - t, hi.x + t, y, h, ops, ws)
			"E":
				wall_x("%s_E" % prefix, hi.x, lo.z, hi.z, y, h, ops, ws)
			"W":
				wall_x("%s_W" % prefix, lo.x, lo.z, hi.z, y, h, ops, ws)


# --- gameplay -----------------------------------------------------------------------------------


# Zone volume + navigation tile (min / max corners). Areas of different zones never overlap.
func area(suffix: String, lo: Vector3, hi: Vector3) -> ZoneVolume:
	var v: ZoneVolume = ZoneVolume.new()
	v.name = "Zone_%s_%s" % [zone_id, suffix]
	v.zone = zone_id
	v.position = (lo + hi) * 0.5
	v.size = (hi - lo).abs()
	gameplay.add_child(v)
	nav_areas.append(AABB(lo, hi - lo))
	return v


func spawner(node_name: String, pos: Vector3, kind: ZombieSpawner.Kind, min_round: int = 1) -> ZombieSpawner:
	var s: ZombieSpawner = ZombieSpawner.new()
	s.name = node_name
	s.position = pos
	s.kind = kind
	s.zone = zone_id
	s.min_round = min_round
	gameplay.add_child(s)
	return s


func link(
	node_name: String, action: TraversalLink.Action, from: Vector3, to: Vector3, b: Barricade = null
) -> TraversalLink:
	var l: TraversalLink = TraversalLink.create(action, from, to, b)
	l.name = node_name
	gameplay.add_child(l)
	return l


static func yaw_of(out: Vector3) -> float:
	return atan2(out.x, out.z)


# Barricaded window `id` in a wall at `c` (window centre at sill+0.6 => pass the FLOOR point under
# the window), `out` = unit vector to the outside. Builds the zombie-only bay outside (floor,
# walls, roof), the barricade, its window link, the player clip and the WINDOW spawner.
func window(id: String, c: Vector3, out: Vector3, min_round: int = 1, bay_depth: float = 3.2) -> Barricade:
	var yaw: float = yaw_of(out)
	var tag: String = "%s_%s" % [zone_id, id]
	var b: Barricade = Barricade.new()
	b.name = "%s_Barricade" % tag
	b.position = c + Vector3(0, 1.5, 0)
	b.rotation.y = yaw
	gameplay.add_child(b)
	link("%s_Link" % tag, TraversalLink.Action.WINDOW, c + out * 0.8, c - out * 1.0, b)
	clip("%s_PlayerClip" % tag, c + Vector3(0, 1.5, 0), Vector3(1.6, 1.4, 0.3), yaw)
	id = tag
	# Bay: 3.2 m along the wall, bay_depth outward.
	var along: Vector3 = Vector3(out.z, 0, -out.x)
	var far: Vector3 = c + out * (bay_depth + WALL_T * 0.5)
	var mid: Vector3 = c + out * (bay_depth * 0.5 + WALL_T * 0.5)
	var sz_along: float = 3.6
	if absf(out.x) > 0.5:
		box("%s_BayFloor" % id, mid + Vector3(0, -SLAB_T * 0.5, 0), Vector3(bay_depth, SLAB_T, sz_along))
		box("%s_BayBack" % id, far + Vector3(0, 1.5, 0), Vector3(WALL_T, 3.0, sz_along))
		for s: float in [-1.0, 1.0]:
			box(
				"%s_BaySide%d" % [id, int(s)],
				mid + along * s * (sz_along * 0.5) + Vector3(0, 1.5, 0),
				Vector3(bay_depth, 3.0, WALL_T)
			)
		box("%s_BayRoof" % id, mid + Vector3(0, 3.2, 0), Vector3(bay_depth, 0.4, sz_along))
	else:
		box("%s_BayFloor" % id, mid + Vector3(0, -SLAB_T * 0.5, 0), Vector3(sz_along, SLAB_T, bay_depth))
		box("%s_BayBack" % id, far + Vector3(0, 1.5, 0), Vector3(sz_along, 3.0, WALL_T))
		for s: float in [-1.0, 1.0]:
			box(
				"%s_BaySide%d" % [id, int(s)],
				mid + along * s * (sz_along * 0.5) + Vector3(0, 1.5, 0),
				Vector3(WALL_T, 3.0, bay_depth)
			)
		box("%s_BayRoof" % id, mid + Vector3(0, 3.2, 0), Vector3(sz_along, 0.4, bay_depth))
	# Spawner tucked beside the window, out of the line of sight through it.
	spawner("Spawn_%s" % tag, c + out * (bay_depth * 0.6) + along * 1.1, ZombieSpawner.Kind.WINDOW, min_round)
	return b


# Opening helper for walls: a window hole [centre, 1.4 wide, sill 0.9, top 2.1].
static func win_hole(at: float) -> Array:
	return [at, 1.4, 0.9, 2.1]


static func door_hole(at: float, w: float = 2.4, h: float = 2.8) -> Array:
	return [at, w, 0.0, h]


# Sealed vent crawlspace behind a wall: spawner inside, VENT link through a low opening at
# `mouth` (floor point in the wall), `out` towards the crawlspace.
func vent(id: String, mouth: Vector3, out: Vector3, min_round: int = 3) -> void:
	var sp_name: String = "Spawn_%s_%s" % [zone_id, id]
	id = "%s_%s" % [zone_id, id]
	var along: Vector3 = Vector3(out.z, 0, -out.x)
	var mid: Vector3 = mouth + out * 1.7
	var big: Vector3 = Vector3(3.0, 2.0, 4.4) if absf(out.x) > 0.5 else Vector3(4.4, 2.0, 3.0)
	box("%s_Floor" % id, mid + Vector3(0, -0.25, 0), Vector3(big.x, 0.5, big.z))
	box("%s_Top" % id, mid + Vector3(0, 2.2, 0), Vector3(big.x, 0.4, big.z))
	box(
		"%s_Back" % id,
		mouth + out * 3.3 + Vector3(0, 1.0, 0),
		Vector3(big.z if absf(out.x) < 0.5 else 0.4, 2.0, 0.4 if absf(out.x) < 0.5 else big.z)
	)
	for s: float in [-1.0, 1.0]:
		box(
			"%s_Side%d" % [id, int(s)],
			mid + along * s * 2.0 + Vector3(0, 1.0, 0),
			Vector3(0.4 if absf(out.x) < 0.5 else 3.0, 2.0, 3.0 if absf(out.x) < 0.5 else 0.4)
		)
	link("%s_Link" % id, TraversalLink.Action.VENT, mouth + out * 1.2, mouth - out * 1.0)
	clip("%s_PlayerClip" % id, mouth + Vector3(0, 0.6, 0), Vector3(1.4, 1.2, 0.3), yaw_of(out))
	spawner(sp_name, mouth + out * 2.4 + along * 0.8, ZombieSpawner.Kind.VENT, min_round)


# Ceiling / skylight drop: a ledge above the floor point `land`, spawner on it, DROP link down.
func drop(
	id: String, ledge: Vector3, land: Vector3, kind: ZombieSpawner.Kind = ZombieSpawner.Kind.VENT, min_round: int = 3
) -> void:
	var sp_name: String = "Spawn_%s_%s" % [zone_id, id]
	id = "%s_%s" % [zone_id, id]
	box("%s_Ledge" % id, ledge + Vector3(0, -0.25, 0), Vector3(3.0, 0.5, 3.0))
	for i: int in 4:
		var o: Vector3 = [Vector3(1.7, 0, 0), Vector3(-1.7, 0, 0), Vector3(0, 0, 1.7), Vector3(0, 0, -1.7)][i]
		var sz: Vector3 = Vector3(0.4, 1.2, 3.8) if absf(o.x) > 0.1 else Vector3(3.8, 1.2, 0.4)
		if (land - ledge).normalized().dot(o.normalized()) < 0.5:
			box("%s_Rim%d" % [id, i], ledge + o + Vector3(0, 0.6, 0), sz)
	link(
		"%s_Link" % id,
		TraversalLink.Action.DROP,
		ledge + (Vector3(land.x, ledge.y, land.z) - ledge).limit_length(1.0),
		land
	)
	spawner(sp_name, ledge - (Vector3(land.x, ledge.y, land.z) - ledge).limit_length(0.6), kind, min_round)


# Climb point: zombies start at `bottom` (outside, below an edge) and vault up to `top`.
func climb(id: String, bottom: Vector3, top: Vector3, min_round: int = 2) -> void:
	var sp_name: String = "Spawn_%s_%s" % [zone_id, id]
	id = "%s_%s" % [zone_id, id]
	box("%s_Pad" % id, bottom + Vector3(0, -0.25, 0), Vector3(3.0, 0.5, 3.0))
	link("%s_Link" % id, TraversalLink.Action.JUMP, bottom, top)
	spawner(
		sp_name,
		bottom + (bottom - Vector3(top.x, bottom.y, top.z)).limit_length(0.5),
		ZombieSpawner.Kind.CLIMB,
		min_round
	)


# Door-burst closet: a small room behind a doorway that players can't enter (clip).
func closet(id: String, doorway: Vector3, out: Vector3, min_round: int = 2) -> void:
	var sp_name: String = "Spawn_%s_%s" % [zone_id, id]
	id = "%s_%s" % [zone_id, id]
	var along: Vector3 = Vector3(out.z, 0, -out.x)
	var mid: Vector3 = doorway + out * 1.6
	var dims: Vector3 = Vector3(3.0, 0, 3.2) if absf(out.x) > 0.5 else Vector3(3.2, 0, 3.0)
	box("%s_Floor" % id, mid + Vector3(0, -0.25, 0), Vector3(dims.x, 0.5, dims.z))
	box("%s_Top" % id, mid + Vector3(0, 2.9, 0), Vector3(dims.x, 0.4, dims.z))
	box(
		"%s_Back" % id,
		doorway + out * 3.1 + Vector3(0, 1.35, 0),
		Vector3(0.4 if absf(out.x) > 0.5 else 3.2, 2.7, 3.2 if absf(out.x) > 0.5 else 0.4)
	)
	for s: float in [-1.0, 1.0]:
		box(
			"%s_Side%d" % [id, int(s)],
			mid + along * s * 1.6 + Vector3(0, 1.35, 0),
			Vector3(3.0 if absf(out.x) > 0.5 else 0.4, 2.7, 0.4 if absf(out.x) > 0.5 else 3.0)
		)
	clip("%s_PlayerClip" % id, doorway + Vector3(0, 1.3, 0), Vector3(1.6, 2.6, 0.3), yaw_of(out))
	spawner(sp_name, mid + out * 0.4, ZombieSpawner.Kind.DOOR_BURST, min_round)


func nav_door(node_name: String, center: Vector3, size: Vector3) -> NavDoor:
	var d: NavDoor = NavDoor.new()
	d.name = node_name
	d.position = center
	d.size = size
	geometry.add_child(d)
	return d


func buy_door(
	door_id: StringName, label: String, price: int, unlocks: Array[StringName], doors: Array[NavDoor], at: Vector3
) -> PurchasableDoor:
	var b: PurchasableDoor = PurchasableDoor.new()
	b.name = "%s_Buy" % door_id
	b.position = at
	b.door_id = door_id
	b.prompt = "%s (%s)" % [label, door_id]
	b.cost = price
	b.unlocks = unlocks
	b.nav_doors = doors
	gameplay.add_child(b)
	return b


func wall_buy(weapon: StringName, pos: Vector3, yaw: float) -> WallBuy:
	var wb: WallBuy = WallBuy.new()
	wb.name = "WallBuy_%s" % String(weapon).capitalize().replace(" ", "")
	wb.weapon_id = weapon
	wb.position = pos
	wb.rotation.y = yaw
	gameplay.add_child(wb)
	return wb


func mark(kind: StringName, id: String, pos: Vector3, label: String = "", powered: bool = false) -> MapMarker:
	var m: MapMarker = MapMarker.new()
	m.name = id
	m.kind = kind
	m.marker_id = StringName(id)
	m.zone = zone_id
	m.label = label
	m.requires_power = powered
	m.position = pos
	gameplay.add_child(m)
	return m


# --- lighting / audio / occlusion ---------------------------------------------------------------


func lamp(
	pos: Vector3, color: Color, energy: float = 1.5, rng: float = 12.0, powered: bool = true, off_fraction: float = 0.15
) -> Light3D:
	var o: OmniLight3D = OmniLight3D.new()
	o.position = pos
	o.light_color = color
	o.light_energy = energy
	o.omni_range = rng
	o.distance_fade_enabled = true
	o.distance_fade_begin = 40.0
	o.distance_fade_length = 15.0
	if not powered:
		lighting.add_child(o)
		return o
	var pl: PoweredLight = PoweredLight.new()
	pl.name = "PoweredLamp_%d" % lighting.get_child_count()
	pl.delay = cascade * CASCADE_STEP + randf_range(0.0, 0.3)
	pl.off_fraction = off_fraction
	pl.add_child(o)
	o.position = Vector3.ZERO
	pl.position = pos
	lighting.add_child(pl)
	return o


# Occluder box (put it inside solid mass: floor slabs, thick rock) for occlusion culling.
func occluder(node_name: String, center: Vector3, size: Vector3) -> void:
	var oi: OccluderInstance3D = OccluderInstance3D.new()
	oi.name = node_name
	var bo: BoxOccluder3D = BoxOccluder3D.new()
	bo.size = size
	oi.occluder = bo
	oi.position = center
	geometry.add_child(oi)
	occluders += 1
