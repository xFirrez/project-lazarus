# CrowdDirector — schedules every host zombie brain (ARCHITECTURE §7.2, §12): per physics frame it
# serves at most `path_budget` path queries (FIFO), runs `think()` for the zombies whose staggered
# LOD timer expired (0.1 s near, 0.25 s mid, 0.5 s far from every player), computes separation
# with a spatial hash and assigns surround slots around each target so groups fan out, then moves
# every zombie along its path (navmesh-constrained). It accounts its own time per frame
# (avg / p99 / max, exposed to the debug overlay and benchmarks) and asks ZombieSync to re-queue
# zombies that are stuck, unreachable or far from every player.
# Authority: HOST only (clients have no brains).
class_name CrowdDirector
extends Node

signal requeue_requested(sim: ZombieSim, reason: String)

const PATH_TIME_CAP_USEC: int = 400
const LOD_NEAR: float = 20.0
const LOD_FAR: float = 40.0
const THINK_RATES: PackedFloat32Array = [0.1, 0.25, 0.5]
const SEPARATION_RADIUS: float = 0.8
const SEPARATION_STRENGTH: float = 2.2
const SLOT_RADIUS: float = 1.05
const SLOT_RING2: float = 1.9
const SLOT_COUNT: int = 8
const SLOT_COUNT2: int = 12
const SLOT_ASSIGN_RANGE: float = 6.0
const TIMING_WINDOW: int = 600

var sims: Array[ZombieSim] = []
var path_budget: int = 6
var frozen: bool = false
var debug_draw: bool = false
# Targets: PlayerSync avatars by default; tests may add any Node3D (stationary markers, bots).
var players: PlayerSync = null
var extra_targets: Array[Node3D] = []
var damage_hook: Callable = Callable()  # func(target: Node3D, amount: float, from: Vector3)

# Statistics.
var frame_usec: PackedInt32Array = []
var queries_total: int = 0
var spawn_queries: int = 0  # unbudgeted spawner ranking (re-queue respawns only)
var queries_this_frame: int = 0
var max_queries_in_frame: int = 0
var path_queue_peak: int = 0
var requeues: int = 0
var crawlers_created: int = 0
var damage_dealt: float = 0.0

var _map: RID = RID()
var _tiles: NavTiles = null  # tiled maps: snap() searches only the nearby tiles
var _tiles_checked: bool = false
var _queue: Array[ZombieSim] = []
var _params: NavigationPathQueryParameters3D = NavigationPathQueryParameters3D.new()
var _result: NavigationPathQueryResult3D = NavigationPathQueryResult3D.new()
var _links: Dictionary = {}  # owner instance id -> TraversalLink (or null for non-links)
var _grid: Dictionary = {}
var _timing_index: int = 0
var _debug: ZombieDebugDraw = null
var _slot_timer: float = 0.0
var _nav_ready: bool = false


func _ready() -> void:
	name = "Crowd"
	process_physics_priority = 50
	_params.metadata_flags = (
		NavigationPathQueryParameters3D.PATH_METADATA_INCLUDE_TYPES
		| NavigationPathQueryParameters3D.PATH_METADATA_INCLUDE_OWNERS
	)
	_params.navigation_layers = 0xFFFFFFFF
	frame_usec.resize(TIMING_WINDOW)


func navigation_map() -> RID:
	if not _map.is_valid() and is_inside_tree():
		_map = get_viewport().get_world_3d().navigation_map
	return _map


# The map has synced at least one region with polygons (baked navmeshes reach the server a sync
# after the region joins the map).
func is_ready() -> bool:
	if _nav_ready:
		return true
	if not navigation_map().is_valid() or NavigationServer3D.map_get_iteration_id(_map) == 0:
		return false
	for r: RID in NavigationServer3D.map_get_regions(_map):
		if NavigationServer3D.region_get_enabled(r) and NavigationServer3D.region_get_iteration_id(r) > 0:
			_nav_ready = NavigationServer3D.map_get_closest_point_owner(_map, Vector3.ZERO).is_valid()
	return _nav_ready


func add(sim: ZombieSim) -> void:
	sims.append(sim)


func remove(sim: ZombieSim) -> void:
	sims.erase(sim)
	_queue.erase(sim)


# --- target helpers ---------------------------------------------------------------------------


func live_targets() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if players != null:
		for id: int in players.avatars:
			var p: PlayerCharacter = players.avatars[id]
			if not p.health.is_downed and not p.notarget:
				out.append(p)
	for t: Node3D in extra_targets:
		if is_instance_valid(t) and t.is_inside_tree() and not is_downed(t):
			out.append(t)
	return out


func is_downed(t: Node3D) -> bool:
	if t is PlayerCharacter:
		return (t as PlayerCharacter).health.is_downed
	return bool(t.get_meta(&"downed", false))


func damage_target(t: Node3D, amount: float, from: Vector3) -> void:
	damage_dealt += amount
	if damage_hook.is_valid():
		damage_hook.call(t, amount, from)
		return
	if t is PlayerCharacter:
		var p: PlayerCharacter = t as PlayerCharacter
		if players != null and players.avatars.get(p.peer_id, null) == p:
			players.damage_player(p.peer_id, amount, from, HealthComponent.DamageType.ZOMBIE)
		else:
			p.health.apply_damage(amount, from, HealthComponent.DamageType.ZOMBIE)


# --- navigation -------------------------------------------------------------------------------


func request_path(sim: ZombieSim) -> void:
	if not sim.path_requested:
		sim.path_requested = true
		_queue.append(sim)
		path_queue_peak = maxi(path_queue_peak, _queue.size())


# Synchronous path length for target selection; -1 when this frame's budget is spent.
func path_length(_sim: ZombieSim, from: Vector3, to: Vector3) -> float:
	if queries_this_frame >= path_budget:
		return -1.0
	_query(from, to)
	var p: PackedVector3Array = _result.path
	if p.is_empty():
		return INF
	var end: Vector3 = p[p.size() - 1]
	var length: float = _result.path_length
	if Vector2(end.x - to.x, end.z - to.z).length() > 2.5 or absf(end.y - to.y) > 2.0:
		length += 1000.0  # unreachable: still pursuable (closest point) but ranked last
	return length


# Unbudgeted path length (rare callers: spawner ranking).
func path_length_now(from: Vector3, to: Vector3) -> float:
	spawn_queries += 1
	_query(from, to, false)
	return _result.path_length if not _result.path.is_empty() else INF


func _query(from: Vector3, to: Vector3, budgeted: bool = true) -> void:
	if budgeted:
		queries_this_frame += 1
		queries_total += 1
	_params.map = navigation_map()
	_params.start_position = from
	_params.target_position = to
	NavigationServer3D.query_path(_params, _result)


func link_for_owner(owner_id: int) -> TraversalLink:
	if owner_id == 0:
		return null
	if not _links.has(owner_id):
		var o: Object = instance_from_id(owner_id)
		_links[owner_id] = o as TraversalLink if o is TraversalLink else null
	return _links[owner_id]


# Projects a moved position back onto the navmesh (zombies are navmesh-constrained).
# On tiled maps (NavTiles) only the tiles around p are searched: the map-wide closest-point query
# scales with every polygon of the map and dominated the AI budget on Vesper Peak (Step 8).
func snap(p: Vector3, _from: Vector3) -> Vector3:
	var m: RID = navigation_map()
	if not m.is_valid():
		return p
	if _tiles == null and not _tiles_checked:
		_tiles_checked = true
		_tiles = NavTiles.find(self)
	if _tiles != null:
		var probe: Vector3 = p + Vector3.UP * 0.25
		var best: Vector3 = Vector3.INF
		var best_d: float = INF
		for i: int in _tiles.boxes.size():
			if not _tiles.boxes[i].grow(1.0).has_point(probe):
				continue
			var c: Vector3 = NavigationServer3D.region_get_closest_point(_tiles.regions[i].get_rid(), probe)
			var d: float = c.distance_squared_to(probe)
			if d < best_d:
				best_d = d
				best = c
		if best != Vector3.INF and best_d < 4.0:
			return best
	var q: Vector3 = NavigationServer3D.map_get_closest_point(m, p + Vector3.UP * 0.25)
	if q == Vector3.ZERO and p.length_squared() > 1.0:
		return p
	return q


# --- tick -------------------------------------------------------------------------------------


func _physics_process(delta: float) -> void:
	if sims.is_empty() or not is_ready():
		return
	var t0: int = Time.get_ticks_usec()
	queries_this_frame = 0
	if not frozen:
		_serve_paths()
		_update_lod_and_think(delta)
		_slot_timer -= delta
		if _slot_timer <= 0.0:
			_slot_timer = 0.2
			_assign_slots()
		_compute_separation()
		for sim: ZombieSim in sims:
			sim.move(delta)
		_collect_requeues()
	max_queries_in_frame = maxi(max_queries_in_frame, queries_this_frame)
	frame_usec[_timing_index % TIMING_WINDOW] = Time.get_ticks_usec() - t0
	_timing_index += 1
	if debug_draw:
		_draw_debug()


func _serve_paths() -> void:
	# Count budget AND a time cap: on large maps (Vesper Peak) single queries cost more, so a
	# frame stops serving once PATH_TIME_CAP_USEC is spent (always at least one query).
	var t0: int = Time.get_ticks_usec()
	while not _queue.is_empty() and queries_this_frame < path_budget:
		if queries_this_frame > 0 and Time.get_ticks_usec() - t0 > PATH_TIME_CAP_USEC:
			break
		var sim: ZombieSim = _queue.pop_front()
		if sim.state == ZombieSim.State.DEAD or sim.target == null:
			sim.path_requested = false
			continue
		var goal: Vector3 = sim.target.global_position
		_query(sim.pos, goal)
		sim.set_path(_result.path, _result.path_owner_ids, _result.path_types, goal)


func _update_lod_and_think(delta: float) -> void:
	var targets: Array[Node3D] = live_targets()
	for sim: ZombieSim in sims:
		var nearest: float = INF
		for t: Node3D in targets:
			nearest = minf(nearest, sim.pos.distance_squared_to(t.global_position))
		nearest = sqrt(nearest)
		sim.lod = 0 if nearest < LOD_NEAR else (1 if nearest < LOD_FAR else 2)
		sim.think_interval = THINK_RATES[sim.lod]
		sim.think_timer -= delta
		if sim.think_timer <= 0.0:
			sim.think_timer += sim.think_interval
			sim.think(sim.think_interval)


# Surround offsets: per target, zombies on their final approach claim the free ring slot closest
# to their bearing (inner ring 8, outer ring 12), so groups fan out instead of conga-lining.
func _assign_slots() -> void:
	var by_target: Dictionary = {}
	for sim: ZombieSim in sims:
		sim.has_slot = false
		if sim.target == null or sim.state == ZombieSim.State.DEAD:
			continue
		var d: float = sim.pos.distance_to(sim.target.global_position)
		if d < SLOT_ASSIGN_RANGE:
			if not by_target.has(sim.target):
				by_target[sim.target] = []
			(by_target[sim.target] as Array).append([d, sim])
	for t: Node3D in by_target:
		var list: Array = by_target[t]
		list.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var taken: Dictionary = {}
		var tp: Vector3 = t.global_position
		for e: Array in list:
			var sim: ZombieSim = e[1]
			var bearing: float = atan2(sim.pos.x - tp.x, sim.pos.z - tp.z)
			var best: int = -1
			var best_err: float = INF
			for s: int in SLOT_COUNT + SLOT_COUNT2:
				if taken.has(s):
					continue
				var inner: bool = s < SLOT_COUNT
				var ang: float = TAU * (s if inner else s - SLOT_COUNT) / (SLOT_COUNT if inner else SLOT_COUNT2)
				var err: float = absf(angle_difference(bearing, ang)) + (0.0 if inner else 1.2)
				if err < best_err:
					best_err = err
					best = s
			if best < 0:
				break
			taken[best] = true
			var inner2: bool = best < SLOT_COUNT
			var a: float = TAU * (best if inner2 else best - SLOT_COUNT) / (SLOT_COUNT if inner2 else SLOT_COUNT2)
			var r: float = SLOT_RADIUS if inner2 else SLOT_RING2
			sim.slot_offset = Vector3(sin(a), 0.0, cos(a)) * r
			sim.has_slot = true


func _compute_separation() -> void:
	_grid.clear()
	for i: int in sims.size():
		var s: ZombieSim = sims[i]
		var key: Vector3i = Vector3i(floori(s.pos.x), floori(s.pos.y * 0.5), floori(s.pos.z))
		if not _grid.has(key):
			_grid[key] = [i]
		else:
			(_grid[key] as Array).append(i)
	var r2: float = SEPARATION_RADIUS * SEPARATION_RADIUS
	for i: int in sims.size():
		var s: ZombieSim = sims[i]
		var push: Vector3 = Vector3.ZERO
		if s.state in [ZombieSim.State.TRAVERSE, ZombieSim.State.TEAR, ZombieSim.State.DEAD]:
			s.separation = push
			continue
		var c: Vector3i = Vector3i(floori(s.pos.x), floori(s.pos.y * 0.5), floori(s.pos.z))
		for dx: int in range(-1, 2):
			for dz: int in range(-1, 2):
				var cell: Variant = _grid.get(c + Vector3i(dx, 0, dz))
				if cell == null:
					continue
				for j: int in cell:
					if j == i:
						continue
					var o: ZombieSim = sims[j]
					if o.state == ZombieSim.State.TRAVERSE or o.state == ZombieSim.State.DEAD:
						continue
					var d: Vector3 = s.pos - o.pos
					d.y = 0.0
					var l2: float = d.length_squared()
					if l2 < r2:
						if l2 < 0.0001:
							d = Vector3(sin(i * 1.7), 0, cos(i * 1.7)) * 0.01
							l2 = 0.0001
						var l: float = sqrt(l2)
						push += d / l * (SEPARATION_RADIUS - l) / SEPARATION_RADIUS
		s.separation = push * SEPARATION_STRENGTH


func _collect_requeues() -> void:
	for sim: ZombieSim in sims.duplicate():
		if sim.requeue_reason != "":
			var reason: String = sim.requeue_reason
			sim.requeue_reason = ""
			requeues += 1
			Log.info(&"ai", "Re-queue zombie %d: %s" % [sim.actor.net_id, reason])
			requeue_requested.emit(sim, reason)


# --- statistics / debug -----------------------------------------------------------------------


func timing_stats() -> Dictionary:
	var n: int = mini(_timing_index, TIMING_WINDOW)
	if n == 0:
		return {"avg_ms": 0.0, "p99_ms": 0.0, "max_ms": 0.0, "frames": 0}
	var arr: Array[int] = []
	var total: int = 0
	for i: int in n:
		arr.append(frame_usec[i])
		total += frame_usec[i]
	arr.sort()
	return {
		"avg_ms": total / 1000.0 / n,
		"p99_ms": arr[mini(n - 1, int(n * 0.99))] / 1000.0,
		"max_ms": arr[n - 1] / 1000.0,
		"frames": n,
	}


func reset_timing() -> void:
	_timing_index = 0
	max_queries_in_frame = 0


func overlay_text() -> String:
	var st: Dictionary = timing_stats()
	return (
		"AI %d zombies  %.2f ms avg  %.2f p99  %.2f max  paths %d/frame (peak %d)  queue %d"
		% [
			sims.size(),
			st["avg_ms"],
			st["p99_ms"],
			st["max_ms"],
			queries_this_frame,
			max_queries_in_frame,
			_queue.size()
		]
	)


func _draw_debug() -> void:
	if _debug == null:
		_debug = ZombieDebugDraw.new()
		add_child(_debug)
	_debug.redraw(sims)


func set_debug_draw(on: bool) -> void:
	debug_draw = on
	if not on and _debug != null:
		_debug.queue_free()
		_debug = null
