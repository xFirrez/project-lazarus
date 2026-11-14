# Visual survey (map quality pass): samples standable points in every Vesper Peak zone's navigation
# areas and, from player eye height, (1) casts a sphere of rays against the static colliders and
# reports the directions that escape to the void ("leaks": spots where you can see out of the map)
# and (2) renders four eye-level frames per sample to --autotest-shots as survey_<zone>_<n>_<dir>.png.
# Exterior zones (Z06, Z07) are allowed to see the sky upwards; horizontal escapes are flagged
# everywhere except where the terrain backdrop is intended (Z06 / Z07 / Z01 dock).
# Run: tools/visual_tests.sh <out_dir> vesper_survey   (`--shots=Z04,Z10` limits the zones)
extends "res://tests/net/autotest_base.gd"

const OPEN_ZONES: Array[StringName] = [&"Z06", &"Z07"]

var _spacing: float = 7.0
var _max_samples: int = 8
var _rays: int = 400
var _out: String = ""
var _only: PackedStringArray = PackedStringArray()
var _render: bool = true
var _nav_map: RID
var _start: Vector3 = Vector3.ZERO
var _exits: Dictionary = {}  # Vector3i (2 m cells) -> count


func _ready() -> void:
	timeout = 900.0
	_out = CommandLine.get_value("autotest-shots", "user://screenshots")
	var only: String = CommandLine.get_value("shots", "")
	if only != "":
		_only = only.split(",")
	_render = CommandLine.get_value("survey-render", "1") == "1"
	if not _render:  # leak-only: denser
		_spacing = 4.0
		_max_samples = 40
		_rays = 1600
	DirAccess.make_dir_recursive_absolute(_out)
	EventBus.match_started.connect(func(_m: StringName) -> void: _run.call_deferred())


func _frames(n: int) -> void:
	for i: int in n:
		await RenderingServer.frame_post_draw


func _run() -> void:
	await _frames(10)
	var m: Match = Match.current
	var me: PlayerCharacter = sync().local_avatar()
	me.health.invulnerable = true
	me.notarget = true
	m.rounds.enabled = false
	m.zombies.host_kill_all()
	Power.host_set(Power.MAIN, true)
	SurvivalCommands._cmd_open_all([])
	_start = me.global_position
	await get_tree().create_timer(9.5).timeout
	for n: Node in get_tree().get_nodes_in_group(&"hide_for_shots"):
		n.set(&"visible", false)
	if is_instance_valid(Debug.overlay):
		Debug.overlay.visible = false
	me.visible = false
	var map: Node = m.map_root
	var art: VesperArt = map.get(&"art") as VesperArt
	var cam: Camera3D = Camera3D.new()
	cam.far = 900.0
	cam.fov = 80.0
	get_tree().root.add_child(cam)
	cam.current = true
	Graphics.apply_camera(cam)
	var space: PhysicsDirectSpaceState3D = (map as Node3D).get_world_3d().direct_space_state
	_nav_map = (map as Node3D).get_world_3d().navigation_map
	for i: int in 30:
		await get_tree().physics_frame  # door re-bakes
	var cams: String = CommandLine.get_value("survey-cams", "")
	if cams != "":
		# "name:x,y,z>x,y,z;name2:..." renders just these views
		for spec: String in cams.split(";"):
			var nm: String = spec.get_slice(":", 0)
			var ab: PackedStringArray = spec.get_slice(":", 1).split(">")
			var a: PackedFloat64Array = ab[0].split_floats(",")
			var b: PackedFloat64Array = ab[1].split_floats(",")
			var zid: String = nm.get_slice("_", 0)
			if art != null and zid.begins_with("Z"):
				art.atmosphere.forced_zone = StringName(zid)
				art.atmosphere.snap_to(StringName(zid))
			cam.global_position = Vector3(a[0], a[1], a[2])
			cam.look_at(Vector3(b[0], b[1], b[2]), Vector3.UP)
			if art != null:
				art.shadows.refresh()
			await _frames(6)
			get_viewport().get_texture().get_image().save_png(_out.path_join("cam_%s.png" % nm))
		finish(true)
		return
	var report: PackedStringArray = PackedStringArray()
	var total_leaks: int = 0
	for z: VesperZone in map.get(&"zones"):
		if not _only.is_empty() and not _only.has(String(z.zone_id)):
			continue
		var samples: Array[Vector3] = _samples(space, z)
		var zl: int = 0
		for i: int in samples.size():
			var eye: Vector3 = samples[i] + Vector3(0, 1.65, 0)
			var leaks: Array[Vector3] = _leaks(space, eye, OPEN_ZONES.has(z.zone_id))
			for d3: Vector3 in leaks:
				_exit_of(z, eye, d3)
			if not leaks.is_empty():
				zl += leaks.size()
				report.append(
					(
						"%s s%d %s: %d leak rays, e.g. %s"
						% [
							z.zone_id,
							i,
							str(eye.snapped(Vector3.ONE * 0.1)),
							leaks.size(),
							str(leaks[0].snapped(Vector3.ONE * 0.01))
						]
					)
				)
			if not _render:
				continue
			if art != null:
				art.atmosphere.forced_zone = z.zone_id
				art.atmosphere.snap_to(z.zone_id)
			for d: int in 4:
				var yaw: float = d * PI * 0.5
				cam.global_position = eye
				cam.global_rotation = Vector3(-0.08, yaw, 0)
				if art != null:
					art.shadows.refresh()
				await _frames(4)
				var img: Image = get_viewport().get_texture().get_image()
				img.save_png(_out.path_join("survey_%s_%02d_%d.png" % [z.zone_id, i, d]))
		note("%s: %d samples, %d leak rays" % [z.zone_id, samples.size(), zl])
		var keys: Array = _exits.keys()
		keys.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return int(_exits[a]) > int(_exits[b]))
		for k: Vector3i in keys.slice(0, 25):
			report.append("  %s exit ~(%d, %d, %d) x%d" % [z.zone_id, k.x, k.y, k.z, _exits[k]])
		_exits.clear()
		total_leaks += zl
	for r: String in report:
		note(r)
	var f: FileAccess = FileAccess.open(_out.path_join("survey_report.txt"), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	check("survey_ran", true, total_leaks)
	finish(true)


# Standable points on a grid over the zone's nav areas (downward rays), farthest-point thinned.
func _samples(space: PhysicsDirectSpaceState3D, z: VesperZone) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for a: AABB in z.nav_areas:
		var x: float = a.position.x + _spacing * 0.5
		while x < a.end.x:
			var zz: float = a.position.z + _spacing * 0.5
			while zz < a.end.z:
				# every floor in the column; the lowest, plus any covered floor (roof tops skipped)
				var top: float = a.end.y + 0.5
				var column: Array[Vector3] = []
				var covered: Array[bool] = []
				for _k: int in 6:
					var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
						Vector3(x, top, zz), Vector3(x, a.position.y - 1.0, zz), 1
					)
					var hit: Dictionary = space.intersect_ray(q)
					if hit.is_empty():
						break
					var p: Vector3 = hit["position"]
					top = p.y - 0.6
					if (hit["normal"] as Vector3).y <= 0.8:
						continue
					var up: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
						p + Vector3(0, 0.05, 0), p + Vector3(0, 1.9, 0), 1
					)
					if not space.intersect_ray(up).is_empty():
						continue  # inside a prop / under a low ceiling
					var sky: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
						p + Vector3(0, 0.05, 0), p + Vector3(0, 300, 0), 1
					)
					column.append(p)
					covered.append(not space.intersect_ray(sky).is_empty())
				for k: int in column.size():
					if not (covered[k] or k == column.size() - 1):
						continue
					# player-reachable only: on the baked navmesh (pads by the agent radius)
					var np: Vector3 = NavigationServer3D.map_get_closest_point(_nav_map, column[k])
					var inside: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
					inside.position = column[k] + Vector3(0, 1.0, 0)
					inside.collision_mask = 1
					if not space.intersect_point(inside, 1).is_empty():
						continue  # sampled inside a wall / solid
					if _near_spawner(column[k]):
						continue  # zombie-only pads / closets / vent bays
					if np.distance_to(column[k]) < 0.6 and _in_zone(z, column[k]) and _reachable(np):
						pts.append(column[k])
				zz += _spacing
			x += _spacing
	if pts.size() <= _max_samples:
		return pts
	var out: Array[Vector3] = [pts[0]]
	while out.size() < _max_samples:
		var best: Vector3 = pts[0]
		var bd: float = -1.0
		for p: Vector3 in pts:
			var d: float = INF
			for o: Vector3 in out:
				d = minf(d, p.distance_to(o))
			if d > bd:
				bd = d
				best = p
		out.append(best)
	return out


# Where a leak ray leaves the zone's nav areas (+1.5 m): the hole is about there.
func _exit_of(z: VesperZone, eye: Vector3, dir: Vector3) -> void:
	var t: float = 0.0
	var last: Vector3 = eye
	while t < 120.0:
		var p: Vector3 = eye + dir * t
		var inside: bool = false
		for a: AABB in z.nav_areas:
			if a.grow(1.5).has_point(p):
				inside = true
				break
		if not inside:
			break
		last = p
		t += 0.25
	var k: Vector3i = Vector3i(roundi(last.x / 2.0) * 2, roundi(last.y / 2.0) * 2, roundi(last.z / 2.0) * 2)
	_exits[k] = int(_exits.get(k, 0)) + 1


# Player-reachable: a navigation path from the spawn ends on the point (roof tops are islands).
func _reachable(p: Vector3) -> bool:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(_nav_map, _start, p, true)
	return path.size() > 0 and path[path.size() - 1].distance_to(p) < 0.8


func _near_spawner(p: Vector3) -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"zombie_spawner"):
		if (n as Node3D).global_position.distance_to(p) < 2.6:
			return true
	return false


func _in_zone(z: VesperZone, p: Vector3) -> bool:
	for v: Node in get_tree().get_nodes_in_group(&"zone_volume"):
		var zv: ZoneVolume = v as ZoneVolume
		if zv.zone == z.zone_id and zv.contains(p + Vector3(0, 0.3, 0)):
			return true
	return false


# Ray directions (Fibonacci sphere) from `eye` that hit nothing within 600 m.
func _leaks(space: PhysicsDirectSpaceState3D, eye: Vector3, open_sky: bool) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n: int = _rays
	for i: int in n:
		var y: float = 1.0 - (float(i) + 0.5) / n * 2.0
		if open_sky and y > -0.05:
			continue
		var r: float = sqrt(maxf(0.0, 1.0 - y * y))
		var th: float = PI * (3.0 - sqrt(5.0)) * i
		var dir: Vector3 = Vector3(cos(th) * r, y, sin(th) * r)
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, eye + dir * 600.0, 1)
		if space.intersect_ray(q).is_empty():
			out.append(dir)
	return out
