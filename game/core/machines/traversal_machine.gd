# TraversalMachine — a host-driven moving platform between two stations (gondola cabin, freight
# lift; DEVELOPMENT_PLAN Step 8 scope 5, D-052). Motion is a pure function of the replicated ride
# state [from_station, depart_time] and the shared host clock, so every peer moves its copy
# identically (deterministic) and an owner-authoritative rider is carried by the CharacterBody3D
# platform support on its own client. The host validator subtracts the platform's displacement
# (`displacement`) so riders aren't corrected for speed.
#   * Ride state lives in the MatchSession flag `machine.<id>` (late join + state hash).
#   * `cabin_gates` (shapes on this body) are solid while moving; `station_gates[s]` (static clip
#     bodies at the stations) are solid unless the machine is docked at station s (shaft safety).
#   * Zombies: the body sits on the player-clip layer, so navigation never covers it (they can't
#     board). Machines with `allow_zombies` enable their TraversalLink (Action.LIFT) at the docked
#     station; ZombieSim rides along (`position_at`).
# Authority: HOST starts rides (`host_request`); every peer simulates the motion.
class_name TraversalMachine
extends AnimatableBody3D

signal departed(from_station: int)
signal arrived(station: int)

const GROUP: StringName = &"traversal_machine"

@export var machine_id: StringName = &""
@export var display_name: String = "machine"
# Global positions of this body's origin along the route: station 0 first, station 1 last.
@export var waypoints: PackedVector3Array = PackedVector3Array()
@export var ride_time: float = 6.0
@export var boarding_delay: float = 1.5
@export var cooldown: float = 20.0
@export var ride_cost: int = 0
@export var requires_power: bool = true
@export var allow_zombies: bool = false
@export var start_station: int = 0
# Rider volume in this body's frame (centre at origin + half height): who counts as aboard.
@export var rider_size: Vector3 = Vector3(3, 2.4, 3)

var from_station: int = 1
var depart_time: float = -1.0e9
var cabin_gates: Array[CollisionShape3D] = []
var station_gates: Array[CollisionObject3D] = [null, null]
var links: Array[TraversalLink] = []
var rides: int = 0

var _was_docked: int = -2
var _lengths: PackedFloat32Array = PackedFloat32Array()
var _total: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	sync_to_physics = true
	collision_layer = MotorComponent.PLAYER_CLIP_LAYER
	collision_mask = 0
	from_station = 1 - start_station
	_measure()
	if not waypoints.is_empty():
		global_position = position_at(_now())
	_update_state(true)


# Called by Match.setup once the MatchSession exists (map _ready runs before it).
func _on_match_setup(m: Match) -> void:
	if m.session != null and not m.session.flag_changed.is_connected(_on_flag):
		m.session.flag_changed.connect(_on_flag)
		var v: Variant = m.session.flags.get(flag_key(), null)
		if v != null:
			_on_flag(flag_key(), v)


func flag_key() -> String:
	return "machine.%s" % machine_id


static func _now() -> float:
	return Net.host_time()


func _measure() -> void:
	_lengths = PackedFloat32Array([0.0])
	_total = 0.0
	for i: int in range(1, waypoints.size()):
		_total += waypoints[i - 1].distance_to(waypoints[i])
		_lengths.append(_total)


# --- deterministic motion ---------------------------------------------------------------------


func position_at(t: float) -> Vector3:
	if waypoints.is_empty():
		return global_position
	var u: float = clampf((t - depart_time) / maxf(ride_time, 0.01), 0.0, 1.0)
	var e: float = smoothstep(0.0, 1.0, u)
	if from_station == 1:
		e = 1.0 - e
	return _along(e * _total)


func _along(d: float) -> Vector3:
	for i: int in range(1, waypoints.size()):
		if d <= _lengths[i] or i == waypoints.size() - 1:
			var seg: float = maxf(_lengths[i] - _lengths[i - 1], 0.0001)
			return waypoints[i - 1].lerp(waypoints[i], clampf((d - _lengths[i - 1]) / seg, 0.0, 1.0))
	return waypoints[0]


func displacement(t0: float, t1: float) -> Vector3:
	return position_at(t1) - position_at(t0)


# Station the machine is docked at, or -1 while it moves (boarding counts as docked).
func docked_at(t: float) -> int:
	if t < depart_time:
		return from_station
	if t >= depart_time + ride_time:
		return 1 - from_station
	return -1


func ready_at(t: float) -> bool:
	return docked_at(t) >= 0 and t >= depart_time + ride_time + cooldown


func cooldown_left(t: float) -> float:
	return maxf(depart_time + ride_time + cooldown - t, 0.0)


func contains(p: Vector3, t: float) -> bool:
	var l: Vector3 = p - position_at(t)
	l = global_basis.inverse() * l
	var h: Vector3 = rider_size * 0.5
	return absf(l.x) <= h.x and l.y >= -0.4 and l.y <= rider_size.y and absf(l.z) <= h.z


func station_position(s: int) -> Vector3:
	return waypoints[0] if s == 0 else waypoints[waypoints.size() - 1]


# --- host -------------------------------------------------------------------------------------


# Starts a ride from wherever the machine is docked (a call from the far station brings it over).
func host_request() -> String:
	if not MatchSession.is_authority():
		return "host only"
	var now: float = _now()
	if requires_power and not Power.is_on():
		return "Requires power"
	if docked_at(now) < 0 or now < depart_time:
		return "%s is moving" % display_name.capitalize()
	if not ready_at(now):
		return "%s cooling down (%.0f s)" % [display_name.capitalize(), cooldown_left(now)]
	var s: int = docked_at(now)
	var m: Match = Match.current
	var state: Array = [s, now + boarding_delay]
	if m != null and m.session != null:
		m.session.host_set_flag(flag_key(), state)
	else:
		_on_flag(flag_key(), state)
	return ""


func _on_flag(key: String, value: Variant) -> void:
	if key != flag_key() or not value is Array:
		return
	var a: Array = value
	from_station = int(a[0])
	depart_time = float(a[1])
	rides += 1


# --- per frame ----------------------------------------------------------------------------------


func _physics_process(_delta: float) -> void:
	if waypoints.is_empty():
		return
	var now: float = _now()
	global_position = position_at(now)
	_update_state(false)


func _update_state(force: bool) -> void:
	var d: int = docked_at(_now())
	if d == _was_docked and not force:
		return
	var prev: int = _was_docked
	_was_docked = d
	var moving: bool = d < 0
	for g: CollisionShape3D in cabin_gates:
		g.set_deferred(&"disabled", not moving)
	for s: int in 2:
		var gate: CollisionObject3D = station_gates[s]
		if gate != null:
			gate.collision_layer = 0 if d == s else MotorComponent.PLAYER_CLIP_LAYER
	for l: TraversalLink in links:
		l.enabled = allow_zombies and d == l.station
	if force:
		return
	if moving:
		Audio.play_event_3d(&"machine_depart", global_position)
		departed.emit(prev)
	else:
		Audio.play_event_3d(&"machine_arrive", global_position)
		arrived.emit(d)


# Re-applies gates / links after the map wired station gates or links in later.
func refresh() -> void:
	_update_state(true)


func register_link(l: TraversalLink) -> void:
	l.machine = self
	links.append(l)
	l.enabled = allow_zombies and docked_at(_now()) == l.station
