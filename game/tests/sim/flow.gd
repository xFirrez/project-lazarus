# flow (DEVELOPMENT_PLAN Step 8 scope 8, AC-8.3): `tools/run_sim.sh flow`. Opens every door in
# progression order (and extends the bridge), then
#   * estimates sprint times along the navmesh (path length / sprint speed): the shortest route
#     Arrival Station -> Reactor Lower Ring (target <= 75 s), zone-to-zone legs, and the time from
#     every zone (and every perk marker) to the nearest OTHER perk marker (target <= 35 s);
#   * drives the local player as a sprinting bot along navmesh paths through a loop that visits
#     every zone (Z01 Z03 Z04 Z05 Z07 Z06 Z08 Z09 Z13 Forge Z11 Z12 Z10 Z03 Z01), checking each
#     leg is completed (nobody stuck) and recording the real leg times.
# Zombies are off (rounds disabled); the player is invulnerable.
extends "res://tests/net/autotest_base.gd"

const MapAnalysis = preload("res://tests/sim/map_analysis.gd")
const DOOR_ORDER: Array[StringName] = [
	&"D01", &"D02", &"D04", &"D03", &"D05", &"D15", &"D06", &"D07", &"D09", &"D08", &"D10", &"D11", &"D12", &"D14"
]
const LOOP: Array = [
	["Z01", Vector3(0, 0, -3)],
	["Z03", Vector3(53, -8, -2)],
	["Z04", Vector3(75, -2, -35)],
	["Z05", Vector3(70, 4, -90)],
	["Z07", Vector3(0, 17, -118)],
	["Z06", Vector3(20, -8, -40)],
	["Z08", Vector3(-34, -13, -25)],
	["Z09", Vector3(-20, -18, -46)],
	["Z13", Vector3(6, -48, -50)],
	["Forge", Vector3(34, -34, -58)],
	["Z11", Vector3(70, -28, -55)],
	["Z12", Vector3(68, -28, -44)],
	["Z10", Vector3(13, -16, -15)],
	["Z03", Vector3(48, -8, -3)],
	["Z01", Vector3(-2, 0, -3)],
]
const LEG_SLACK: float = 2.0  # a leg may take this × its sprint estimate + 12 s

var _stage: int = 0
var _t0: float = 0.0
var _ma: MapAnalysis = null
var _sprint: float = 6.6
var _leg: int = 1
var _leg_start: float = 0.0
var _leg_est: float = 0.0
var _goal: Vector3 = Vector3.ZERO
var _path: PackedVector3Array = PackedVector3Array()
var _path_i: int = 0
var _repath: float = 0.0
var _legs: Array = []
var _stuck: Array = []
var _last_pos: Vector3 = Vector3.ZERO
var _still: float = 0.0
var _nudge: float = 0.0
var _nudge_dir: Vector3 = Vector3.ZERO


func _ready() -> void:
	timeout = 900.0


func _physics_process(delta: float) -> void:
	var m: Match = Match.current
	if m == null or sync() == null or sync().local_avatar() == null:
		return
	var me: PlayerCharacter = sync().local_avatar()
	var tiles: NavTiles = NavTiles.find(m.map_root)
	match _stage:
		0:
			if tiles != null and not tiles.is_baking() and m.zombies.crowd.is_ready():
				me.health.invulnerable = true
				m.rounds.enabled = false
				m.zombies.host_kill_all()
				_open_in_order(m)
				_t0 = elapsed()
				_stage = 1
		1:
			# Wait until the re-baked tiles reached the navigation map (a cross-map path resolves).
			if elapsed() - _t0 > 1.0 and not tiles.is_baking() and MapAnalysis.nav_settled(m):
				_ma = MapAnalysis.new(m)
				if (
					not _ma.reaches(sync().spawn_point_for(Net.local_id()), Vector3(6, -48, -50))
					and elapsed() - _t0 < 10.0
				):
					return
				_sprint = me.motor.tuning.sprint_speed
				_estimates(m)
				me.bot_driver = BotInputDriver.direction_driver(_wish.bind(me), true)
				_start_leg(me)
				_stage = 2
		2:
			_drive(me, delta)


func _open_in_order(m: Match) -> void:
	var order: PackedStringArray = []
	for id: StringName in DOOR_ORDER:
		for it: Node in m.map_root.find_children("%s_Buy" % id, "PurchasableDoor", true, false):
			(it as PurchasableDoor).host_open(0)
			order.append(String(id))
	MapAnalysis.open_everything(m)  # grate, bridge
	check("doors_opened_in_order", order.size() == DOOR_ORDER.size(), order)
	check("all_zones_unlocked", m.zones.unlocked.size() == m.definition.zones.size(), m.zones.unlocked.keys())


func _secs(a: Vector3, b: Vector3) -> float:
	var p: PackedVector3Array = _ma.path(a, b)
	if p.is_empty() or p[p.size() - 1].distance_to(NavigationServer3D.map_get_closest_point(_ma.map_rid, b)) > 1.5:
		return INF
	return _ma.path_length(p) / _sprint


func _estimates(m: Match) -> void:
	var spawn: Vector3 = sync().spawn_point_for(Net.local_id())
	var ring: Vector3 = Vector3(6, -48, -50)
	var t_ring: float = _secs(spawn, ring)
	result["z01_to_z13_sprint_s"] = snappedf(t_ring, 0.1)
	check("z01_to_z13_le_75s", t_ring <= 75.0, t_ring)
	var perks: Array[MapMarker] = []
	for n: Node in m.map_root.find_children("*", "MapMarker", true, false):
		if (n as MapMarker).kind == &"perk":
			perks.append(n as MapMarker)
	var worst_perk: Array = [0.0, ""]
	var perk_rows: Dictionary = {}
	for a: MapMarker in perks:
		var best: float = INF
		for b: MapMarker in perks:
			if a != b:
				best = minf(best, _secs(a.global_position, b.global_position))
		perk_rows[String(a.marker_id)] = snappedf(best, 0.1)
		if best > float(worst_perk[0]):
			worst_perk = [best, String(a.marker_id)]
	result["perk_to_nearest_perk_s"] = perk_rows
	check("perk_to_perk_le_35s", float(worst_perk[0]) <= 35.0, worst_perk)
	var zone_rows: Dictionary = {}
	var worst_zone: Array = [0.0, ""]
	for row: Array in LOOP:
		var best2: float = INF
		for p: MapMarker in perks:
			best2 = minf(best2, _secs(row[1], p.global_position))
		zone_rows[String(row[0])] = snappedf(best2, 0.1)
		if best2 > float(worst_zone[0]):
			worst_zone = [best2, String(row[0])]
	result["zone_to_nearest_perk_s"] = zone_rows
	check("zone_to_perk_le_35s", float(worst_zone[0]) <= 35.0, worst_zone)


# --- bot loop -----------------------------------------------------------------------------------


func _start_leg(me: PlayerCharacter) -> void:
	_goal = NavigationServer3D.map_get_closest_point(_ma.map_rid, LOOP[_leg][1])
	_leg_est = _secs(me.global_position, _goal)
	_leg_start = elapsed()
	_repath = 0.0


func _wish(me: PlayerCharacter) -> Vector3:
	if _nudge > 0.0:
		return _nudge_dir
	if _path_i >= _path.size():
		return Vector3.ZERO
	var d: Vector3 = _path[_path_i] - me.global_position
	d.y = 0.0
	if d.length() < 0.05:
		return Vector3.ZERO
	me.set_view(atan2(-d.x, -d.z), 0.0)  # face the way we run (sprint is forward-only)
	return d.normalized()


func _drive(me: PlayerCharacter, delta: float) -> void:
	# Unstick: the capsule (r 0.35) is wider than the nav agent (r 0.3), so path corners can pin
	# it against a wall corner; sidestep briefly, like a player would.
	_nudge -= delta
	_still = _still + delta if me.global_position.distance_to(_last_pos) < 0.02 else 0.0
	_last_pos = me.global_position
	if _still > 0.6 and _nudge <= 0.0 and _path_i < _path.size():
		var d: Vector3 = _path[_path_i] - me.global_position
		d.y = 0.0
		_nudge_dir = d.normalized().rotated(Vector3.UP, PI * 0.5 * (1.0 if randf() < 0.5 else -1.0))
		_nudge = 0.35
		_still = 0.0
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.5
		_path = _ma.path(me.global_position, _goal)
		_path_i = 1 if _path.size() > 1 else 0
	while _path_i < _path.size():
		var d: Vector3 = _path[_path_i] - me.global_position
		if Vector2(d.x, d.z).length() < 0.6 and absf(d.y) < 2.0:
			_path_i += 1
		else:
			break
	var flat: Vector3 = _goal - me.global_position
	var took: float = elapsed() - _leg_start
	if Vector2(flat.x, flat.z).length() < 1.2 and absf(flat.y) < 1.5:
		_legs.append(
			[String(LOOP[_leg - 1][0]) + "->" + String(LOOP[_leg][0]), snappedf(took, 0.1), snappedf(_leg_est, 0.1)]
		)
		_next_leg(me)
	elif took > _leg_est * LEG_SLACK + 12.0:
		var nxt: Vector3 = _path[_path_i] if _path_i < _path.size() else Vector3.INF
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			me.global_position + Vector3.UP * 0.5, nxt + Vector3.UP * 0.5, MotorComponent.WORLD_MASK, [me.get_rid()]
		)
		var hit: Dictionary = me.get_world_3d().direct_space_state.intersect_ray(q) if nxt != Vector3.INF else {}
		note(
			(
				"stuck: ray to next corner hits %s at %s"
				% [(hit["collider"] as Node).get_path() if not hit.is_empty() else "nothing", hit.get("position", "")]
			)
		)
		_stuck.append(
			[
				String(LOOP[_leg][0]),
				me.global_position.snapped(Vector3.ONE * 0.1),
				snappedf(took, 0.1),
				nxt.snapped(Vector3.ONE * 0.1),
				_path.size()
			]
		)
		me.motor.teleport(_goal + Vector3.UP * 0.1)
		_next_leg(me)


func _next_leg(me: PlayerCharacter) -> void:
	_leg += 1
	if _leg >= LOOP.size():
		set_physics_process(false)
		me.bot_driver = Callable()
		result["legs"] = _legs
		var total: float = 0.0
		for l: Array in _legs:
			total += float(l[1])
		result["loop_total_s"] = snappedf(total, 0.1)
		check("bot_loop_no_stuck_legs", _stuck.is_empty(), _stuck)
		check("bot_loop_all_legs", _legs.size() + _stuck.size() == LOOP.size() - 1, _legs.size())
		finish(true)
		return
	_start_leg(me)
