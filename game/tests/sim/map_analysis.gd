# MapAnalysis — shared helpers for the map validation sims (nav_validate, flow; DEVELOPMENT_PLAN
# Step 8 scope 7–8): opens every door / grate / bridge, samples PLAYER-STANDABLE cells from
# collision (downward rays on a 0.5 m grid, headroom >= crouch height) and flood-fills the ones a
# player can actually reach from the spawn (steps <= 0.35 m, mantles <= 1.2 m, any drop; a move is
# blocked if a ray at knee / chest height hits world or player-clip geometry). Traversal machines
# and chutes count as portals between their stations. Path helpers wrap the navigation map.
# Authority: test tooling (host / solo).
extends RefCounted

const CELL: float = 0.5
const MAX_FLOORS: int = 10
const STEP: float = 0.35
const MANTLE: float = 1.2
const HEADROOM: float = 1.1  # crouch height
const WORLD_MASK: int = 1 | MotorComponent.PLAYER_CLIP_LAYER

static var _last_iter: int = -1
static var _stable: int = 0

var m: Match = null
var space: PhysicsDirectSpaceState3D = null
var map_rid: RID = RID()
var bounds: AABB = AABB()
var nx: int = 0
var nz: int = 0
var floors: Dictionary = {}  # Vector2i column -> PackedFloat32Array of standable floor heights
var reach: Dictionary = {}  # Vector3i (ix, iz, floor index) -> parent cell (player-reachable)
var excluded_rids: Array[RID] = []
var portals: Array = []  # [from: Vector3, to: Vector3, label]
var rays: int = 0
var machines: Array[TraversalMachine] = []
var chutes: Array[Chute] = []
var _q: PhysicsRayQueryParameters3D = null


func _init(p_match: Match) -> void:
	m = p_match
	map_rid = m.zombies.crowd.navigation_map()
	space = m.map_root.get_world_3d().direct_space_state
	_q = PhysicsRayQueryParameters3D.new()
	_q.collision_mask = WORLD_MASK
	_q.hit_back_faces = false


# The navigation map applies region changes asynchronously (several frames after a re-bake):
# true once its iteration id has been unchanged for `frames` physics frames.


static func nav_settled(mt: Match, frames: int = 60) -> bool:
	var it: int = NavigationServer3D.map_get_iteration_id(mt.zombies.crowd.navigation_map())
	if it != _last_iter:
		_last_iter = it
		_stable = 0
		return false
	_stable += 1
	return _stable >= frames


static func open_everything(mt: Match) -> int:
	var n: int = 0
	for it: Node in mt.map_root.find_children("*", "PurchasableDoor", true, false):
		if not (it as PurchasableDoor).is_open():
			(it as PurchasableDoor).host_open(0)
			n += 1
	for d: Node in mt.map_root.find_children("*", "NavDoor", true, false):
		if not (d as NavDoor).is_open:
			(d as NavDoor).host_set_open(true)
			n += 1
	return n


# --- standable cells ----------------------------------------------------------------------------


func sample(p_bounds: AABB) -> void:
	bounds = p_bounds
	for n: Node in m.map_root.find_children("*", "TraversalMachine", true, false):
		machines.append(n as TraversalMachine)
	for n: Node in m.map_root.find_children("*", "Chute", true, false):
		chutes.append(n as Chute)
	for n: Node in machines:
		excluded_rids.append((n as CollisionObject3D).get_rid())
		var tm: TraversalMachine = n as TraversalMachine
		portals.append([tm.station_position(0), tm.station_position(1), String(tm.machine_id)])
		portals.append([tm.station_position(1), tm.station_position(0), String(tm.machine_id)])
	for n: Node in m.map_root.find_children("*", "Chute", true, false):
		var ch: Chute = n as Chute
		portals.append([ch.global_position, ch.exit_point, String(ch.name)])
	_q.exclude = excluded_rids
	nx = int(ceil(bounds.size.x / CELL))
	nz = int(ceil(bounds.size.z / CELL))
	var top: float = bounds.end.y
	var bottom: float = bounds.position.y
	for ix: int in nx:
		for iz: int in nz:
			var x: float = bounds.position.x + (ix + 0.5) * CELL
			var z: float = bounds.position.z + (iz + 0.5) * CELL
			var ys: PackedFloat32Array = PackedFloat32Array()
			var from_y: float = top
			for _i: int in MAX_FLOORS:
				var hit: Dictionary = _ray(Vector3(x, from_y, z), Vector3(x, bottom, z))
				if hit.is_empty():
					break
				var p: Vector3 = hit["position"]
				var nrm: Vector3 = hit["normal"]
				if nrm.y > 0.69 and _wide(p) and _ray(p + Vector3(0, 0.05, 0), p + Vector3(0, HEADROOM, 0)).is_empty():
					ys.append(p.y)
				from_y = p.y - 0.06
				if from_y <= bottom:
					break
			if not ys.is_empty():
				floors[Vector2i(ix, iz)] = ys


# A floor a capsule can stand on: support within 0.2 m of the height at 3 of 4 points 0.3 m out
# (filters rail / parapet / wall tops).
func _wide(p: Vector3) -> bool:
	var n: int = 0
	for o: Vector3 in [Vector3(0.3, 0, 0), Vector3(-0.3, 0, 0), Vector3(0, 0, 0.3), Vector3(0, 0, -0.3)]:
		var h: Dictionary = _ray(p + o + Vector3(0, 0.25, 0), p + o - Vector3(0, 0.25, 0))
		if not h.is_empty():
			n += 1
	return n >= 3


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	rays += 1
	_q.from = a
	_q.to = b
	return space.intersect_ray(_q)


func cell_pos(c: Vector3i) -> Vector3:
	var ys: PackedFloat32Array = floors[Vector2i(c.x, c.y)]
	return Vector3(bounds.position.x + (c.x + 0.5) * CELL, ys[c.z], bounds.position.z + (c.y + 0.5) * CELL)


func nearest_cell(p: Vector3, max_d: float = 4.0) -> Vector3i:
	var best: Vector3i = Vector3i(-1, -1, -1)
	var best_d: float = max_d
	var cx: int = int(floor((p.x - bounds.position.x) / CELL))
	var cz: int = int(floor((p.z - bounds.position.z) / CELL))
	var r: int = int(ceil(max_d / CELL))
	for ix: int in range(cx - r, cx + r + 1):
		for iz: int in range(cz - r, cz + r + 1):
			var col: Vector2i = Vector2i(ix, iz)
			if not floors.has(col):
				continue
			var ys: PackedFloat32Array = floors[col]
			for k: int in ys.size():
				var c: Vector3i = Vector3i(ix, iz, k)
				if in_machine(cell_pos(c)):
					continue
				var d: float = cell_pos(c).distance_to(p)
				if d < best_d:
					best_d = d
					best = c
	return best


func in_machine(p: Vector3) -> bool:
	for tm: TraversalMachine in machines:
		for s: int in 2:
			var l: Vector3 = p - tm.station_position(s)
			var h: Vector3 = tm.rider_size * 0.5 + Vector3(0.3, 0, 0.3)
			if absf(l.x) <= h.x and l.y >= -0.6 and l.y <= tm.rider_size.y and absf(l.z) <= h.z:
				return true
	return false


# Inside a machine's footprint at a station, at any height (its shaft / bay): players get there
# only by riding (portals), never by walking or falling in.
func in_machine_column(p: Vector3) -> bool:
	for tm: TraversalMachine in machines:
		for s: int in 2:
			var l: Vector3 = p - tm.station_position(s)
			var h: Vector3 = tm.rider_size * 0.5 + Vector3(0.3, 0, 0.3)
			if absf(l.x) <= h.x and absf(l.z) <= h.z and l.y <= tm.rider_size.y:
				return true
	return false


func in_chute(p: Vector3) -> bool:
	for ch: Chute in chutes:
		if ch.contains(p):
			return true
	return false


# BFS over standable cells from `start` (world position).
func flood(start: Vector3) -> int:
	var seed: Vector3i = nearest_cell(start, 2.0)
	if seed.x < 0:
		return 0
	var queue: Array[Vector3i] = [seed]
	reach[seed] = seed
	var portal_done: Dictionary = {}
	var head: int = 0
	while head < queue.size():
		var c: Vector3i = queue[head]
		head += 1
		var p: Vector3 = cell_pos(c)
		for pi: int in portals.size():
			if portal_done.has(pi) or p.distance_to(portals[pi][0]) > 4.5:
				continue
			portal_done[pi] = true
			var dst: Vector3i = nearest_cell(portals[pi][1], 5.0)
			if dst.x >= 0 and not reach.has(dst):
				reach[dst] = c
				queue.append(dst)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var col: Vector2i = Vector2i(c.x + d.x, c.y + d.y)
			if not floors.has(col):
				continue
			var ys: PackedFloat32Array = floors[col]
			for k: int in ys.size():
				var n: Vector3i = Vector3i(col.x, col.y, k)
				if reach.has(n):
					continue
				var q: Vector3 = cell_pos(n)
				var dy: float = q.y - p.y
				if dy > MANTLE or in_machine_column(q):
					continue
				if not _passable(p, q):
					continue
				# Of several floors in the column, a player walking / dropping lands on the highest
				# one at or below their reach.
				if dy < -STEP and _has_floor_between(col, q.y, p.y):
					continue
				# A fall must be clear all the way down (no slab / roof in between).
				if dy < -STEP and not _ray(Vector3(q.x, p.y + 0.3, q.z), Vector3(q.x, q.y + 0.1, q.z)).is_empty():
					continue
				reach[n] = c
				queue.append(n)
	return reach.size()


# The flood's route to cell c, reduced to its notable moves (drops / mantles / portals).
func explain(c: Vector3i, limit: int = 12) -> Array:
	var out: Array = []
	var cur: Vector3i = c
	var guard: int = 0
	while reach.has(cur) and reach[cur] != cur and guard < 100000:
		var par: Vector3i = reach[cur]
		var a: Vector3 = cell_pos(par)
		var b: Vector3 = cell_pos(cur)
		if absf(b.y - a.y) > 0.4 or a.distance_to(b) > 1.0:
			out.append("%v -> %v" % [a.snapped(Vector3.ONE * 0.1), b.snapped(Vector3.ONE * 0.1)])
			if out.size() >= limit:
				break
		cur = par
		guard += 1
	return out


func _has_floor_between(col: Vector2i, lo: float, hi: float) -> bool:
	for y: float in floors[col]:
		if y > lo + 0.05 and y <= hi + STEP:
			return true
	return false


func _passable(p: Vector3, q: Vector3) -> bool:
	var base: float = maxf(p.y, q.y)
	for h: float in [0.45, 1.0]:
		if not _ray(Vector3(p.x, base + h, p.z), Vector3(q.x, base + h, q.z)).is_empty():
			return false
	return true


# --- navigation helpers -------------------------------------------------------------------------


func path(a: Vector3, b: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(map_rid, a, b, true)


func path_length(pth: PackedVector3Array) -> float:
	var l: float = 0.0
	for i: int in range(1, pth.size()):
		l += pth[i - 1].distance_to(pth[i])
	return l


# A player at p is within zombie reach of navigation that connects to `goal`.
func covered(p: Vector3, goal: Vector3, h_reach: float, v_reach: float) -> bool:
	for o: Vector3 in [Vector3.ZERO, Vector3(1.2, 0, 0), Vector3(-1.2, 0, 0), Vector3(0, 0, 1.2), Vector3(0, 0, -1.2)]:
		var q: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, p + o + Vector3(0, -1.0, 0))
		if Vector2(q.x - p.x, q.z - p.z).length() <= h_reach and absf(q.y - p.y) <= v_reach and reaches(q, goal, 1.0):
			return true
	return false


# True when the path from a ends near b (within tol horizontally, 1.6 m vertically).
func reaches(a: Vector3, b: Vector3, tol: float = 1.5) -> bool:
	var pth: PackedVector3Array = path(a, b)
	if pth.is_empty():
		return false
	var e: Vector3 = pth[pth.size() - 1]
	var tgt: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, b)
	return Vector2(e.x - tgt.x, e.z - tgt.z).length() <= tol and absf(e.y - tgt.y) <= 1.6 and tgt.distance_to(b) <= 2.5
