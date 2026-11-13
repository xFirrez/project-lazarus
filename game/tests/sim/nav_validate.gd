# nav_validate (DEVELOPMENT_PLAN Step 8 scope 7, AC-8.2): `tools/run_sim.sh nav_validate [--map=]`.
# With every door / grate / bridge open:
#   * tiles: navigation tile AABBs don't overlap;
#   * islands: every nav polygon can path to the player spawn (zombies anywhere reach players);
#     unreachable polygons are reported as islands, "harmful" when a player can stand there;
#   * coverage: every player-reachable standable cell (MapAnalysis flood fill) has navigation
#     within zombie reach (≤ 1.6 m horizontally, ≤ 1.4 m vertically), and a 1/64 subsample of
#     those cells also paths to the spawn — no player-standable area zombies can't get to;
#   * spawners: every spawner paths to sample points of its own and adjacent zones.
# Writes a JSON summary (+ failing positions) to --autotest-out.
extends "res://tests/net/autotest_base.gd"

const MapAnalysis = preload("res://tests/sim/map_analysis.gd")
const COVER_H: float = 1.6
const COVER_V: float = 1.4

var _stage: int = 0
var _t0: float = 0.0


func _ready() -> void:
	timeout = 240.0


func _physics_process(_delta: float) -> void:
	var m: Match = Match.current
	if m == null or sync() == null or sync().local_avatar() == null:
		return
	var tiles: NavTiles = NavTiles.find(m.map_root)
	match _stage:
		0:
			if tiles != null and not tiles.is_baking() and m.zombies.crowd.is_ready():
				sync().local_avatar().health.invulnerable = true
				m.rounds.enabled = false
				note("doors/bridges opened: %d" % MapAnalysis.open_everything(m))
				_t0 = elapsed()
				_stage = 1
		1:
			if elapsed() - _t0 > 1.0 and tiles != null and not tiles.is_baking() and MapAnalysis.nav_settled(m):
				_stage = 2
				_t0 = elapsed()
		2:
			if elapsed() - _t0 > 0.5:
				set_physics_process(false)
				_validate(m, tiles)


func _validate(m: Match, tiles: NavTiles) -> void:
	var t_start: int = Time.get_ticks_msec()
	result["tiles"] = tiles.regions.size()
	result["polygons"] = tiles.polygon_count()
	# 1. Tile overlap.
	var overlaps: Array = []
	for i: int in tiles.boxes.size():
		for j: int in range(i + 1, tiles.boxes.size()):
			var x: AABB = tiles.boxes[i].intersection(tiles.boxes[j])
			if x.has_volume() and x.get_volume() > 0.01:
				overlaps.append("%s x %s" % [tiles.regions[i].name, tiles.regions[j].name])
	check("tiles_disjoint", overlaps.is_empty(), overlaps)
	var spawn: Vector3 = sync().spawn_point_for(Net.local_id())
	var ma: MapAnalysis = MapAnalysis.new(m)
	var spawn_nav: Vector3 = NavigationServer3D.map_get_closest_point(ma.map_rid, spawn)
	# 2. Islands (polygon centres -> spawn).
	var bounds: AABB = tiles.boxes[0]
	for b: AABB in tiles.boxes:
		bounds = bounds.merge(b)
	ma.sample(bounds.grow(0.5))
	result["standable_columns"] = ma.floors.size()
	var reached: int = ma.flood(spawn)
	result["player_reachable_cells"] = reached
	var islands: Array = []
	var harmful: Array = []
	var poly_total: int = 0
	for r: NavigationRegion3D in tiles.regions:
		var nm: NavigationMesh = r.navigation_mesh
		if nm == null:
			continue
		var verts: PackedVector3Array = nm.get_vertices()
		# Up to 24 polygons per tile, spread over its polygon list (connectivity is per area).
		var count: int = nm.get_polygon_count()
		var stride: int = maxi(1, count / 24)
		for pi: int in range(0, count, stride):
			var idx: PackedInt32Array = nm.get_polygon(pi)
			var c: Vector3 = Vector3.ZERO
			for k: int in idx:
				c += verts[k]
			c /= float(idx.size())
			poly_total += 1
			if not ma.reaches(c, spawn_nav, 1.0):
				var tag: String = "%s %v" % [r.name, c.snapped(Vector3.ONE * 0.1)]
				islands.append(tag)
				var cell: Vector3i = ma.nearest_cell(c, 1.0)
				if (
					cell.x >= 0
					and ma.reach.has(cell)
					and not ma.covered(ma.cell_pos(cell), spawn_nav, COVER_H, COVER_V)
				):
					harmful.append(tag)
					if harmful.size() <= 4:
						note("route to %s: %s" % [tag, str(ma.explain(cell))])
	result["islands"] = islands.size()
	note("island polygons (unreachable decor, first 25): %s" % str(islands.slice(0, 25)))
	check("no_player_reachable_islands", harmful.is_empty(), harmful.slice(0, 30))
	if CommandLine.get_value("quick", "0") == "1":
		finish(true)
		return
	# 3. Coverage.
	var uncovered: Array = []
	var unreachable: Array = []
	var checked: int = 0
	for c: Vector3i in ma.reach:
		var p: Vector3 = ma.cell_pos(c)
		if ma.in_machine(p) or ma.in_chute(p):
			continue
		checked += 1
		var q: Vector3 = NavigationServer3D.map_get_closest_point(ma.map_rid, p)
		if Vector2(q.x - p.x, q.z - p.z).length() > COVER_H or absf(q.y - p.y) > COVER_V:
			if not ma.covered(p, spawn_nav, COVER_H, COVER_V):
				uncovered.append("%s %v" % [m.zones.zone_at(p + Vector3.UP * 0.5), p.snapped(Vector3.ONE * 0.1)])
				if uncovered.size() <= 3:
					note("route to uncovered %v: %s" % [p.snapped(Vector3.ONE * 0.1), str(ma.explain(c))])
			continue
		if c.x % 8 == 0 and c.y % 8 == 0 and not ma.reaches(q, spawn_nav, 1.0):
			unreachable.append("%s %v" % [m.zones.zone_at(p + Vector3.UP * 0.5), p.snapped(Vector3.ONE * 0.1)])
	result["cells_checked"] = checked
	result["uncovered"] = uncovered.size()
	check("standable_covered", uncovered.is_empty(), uncovered.slice(0, 120))
	check("standable_nav_reaches_spawn", unreachable.is_empty(), unreachable.slice(0, 40))
	# 4. Spawners -> own + adjacent zones.
	var samples: Dictionary = {}  # zone -> Array[Vector3]
	for c: Vector3i in ma.reach:
		var p2: Vector3 = ma.cell_pos(c)
		var z: StringName = m.zones.zone_at(p2 + Vector3.UP * 0.5)
		if z == &"" or ma.in_machine(p2):
			continue
		if not samples.has(z):
			samples[z] = []
		(samples[z] as Array).append(p2)
	var zone_samples: Dictionary = {}
	for z: StringName in samples:
		var arr: Array = samples[z]
		var pick: Array = []
		for i: int in 3:
			pick.append(arr[int((float(i) + 0.5) / 3.0 * arr.size())])
		zone_samples[z] = pick
	result["zones_with_standable"] = zone_samples.keys().size()
	var bad: Array = []
	var checked_sp: int = 0
	for sp: ZombieSpawner in m.zombies.spawners:
		checked_sp += 1
		var zones: Array[StringName] = [sp.zone]
		zones.append_array(m.zones.adjacent(sp.zone))
		for z2: StringName in zones:
			for p3: Vector3 in zone_samples.get(z2, []):
				if not ma.reaches(sp.global_position, p3, 1.6):
					bad.append("%s -> %s %v" % [sp.name, z2, (p3 as Vector3).snapped(Vector3.ONE * 0.1)])
	result["spawners"] = checked_sp
	check("spawners_reach_activation_zones", bad.is_empty(), bad.slice(0, 40))
	check("all_zones_sampled", zone_samples.keys().size() == m.definition.zones.size(), zone_samples.keys())
	result["rays"] = ma.rays
	result["validate_ms"] = Time.get_ticks_msec() - t_start
	finish(true)
