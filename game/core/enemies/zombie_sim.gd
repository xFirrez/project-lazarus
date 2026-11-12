# ZombieSim — the host-side brain of one zombie (ARCHITECTURE §7.2). Hierarchical states:
# SPAWNING (rise / window entry) -> PURSUE (path following, surround slot on final approach) ->
# ATTACK (telegraphed wind-up) / TEAR (barricade, one plank at a time) / TRAVERSE (window climb,
# drop-down, vent crawl along a TraversalLink) / STAGGER / WAIT (window busy) / IDLE (no target).
# Crawler conversion is a flag (explosive damage below the hips). The CrowdDirector owns the
# schedule: `move()` every physics frame, `think()` at a staggered LOD rate, paths on a budget.
# Authority: HOST only; writes the actor's replicated state.
class_name ZombieSim
extends RefCounted

enum State { SPAWNING, PURSUE, ATTACK, TEAR, TRAVERSE, STAGGER, WAIT, IDLE, DEAD }

const STATE_NAMES: PackedStringArray = [
	"spawning", "pursue", "attack", "tear", "traverse", "stagger", "wait", "idle", "dead"
]
const CORNER_REACHED: float = 0.35
const REPATH_MOVE: float = 3.0  # target moved this far from the last path goal -> re-path
const DIRECT_RANGE: float = 5.0  # final approach steers straight at the surround slot
const STUCK_WINDOW: float = 4.0
const STUCK_MIN_PROGRESS: float = 0.75
const FAR_DISTANCE: float = 60.0
const FAR_TIME: float = 8.0
const NO_PATH_TIME: float = 8.0
const TARGET_EVAL_INTERVAL: float = 0.5  # 2 Hz
const TARGET_HYSTERESIS: float = 3.0  # m shorter path needed to switch targets
const RISE_TIME: float = 1.2
const WINDOW_QUEUE_RANGE: float = 1.8  # wait this far from a busy window instead of pushing in
const STUCK_NEAR_TARGET: float = 8.0  # crowding around a target is not "stuck"
const LIFT_GIVE_UP: float = 20.0  # waiting this long for / on a lift -> re-queue

var actor: ZombieActor = null
var director: CrowdDirector = null
var archetype: ZombieArchetype = null
var state: State = State.SPAWNING
var state_time: float = 0.0
var pos: Vector3 = Vector3.ZERO
var yaw: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var move_speed: float = 1.0
var think_interval: float = 0.1
var think_timer: float = 0.0
var lod: int = 0

var target: Node3D = null
var target_path_length: float = INF
var target_eval_timer: float = 0.0
var slot_offset: Vector3 = Vector3.ZERO
var has_slot: bool = false

var path: PackedVector3Array = []
var path_owners: PackedInt64Array = []
var path_types: PackedInt32Array = []
var path_index: int = 0
var path_goal: Vector3 = Vector3.INF
var path_age: float = 0.0
var path_requested: bool = false
var path_direct: bool = false  # last path was ~straight: final approach may steer directly
var repath_interval: float = 0.75
var no_path_time: float = 0.0

var traverse_link: TraversalLink = null
var traverse_from: Vector3 = Vector3.ZERO
var traverse_to: Vector3 = Vector3.ZERO
var traverse_duration: float = 1.0
var barricade: Barricade = null
var tear_timer: float = 0.0
var window_swipe_timer: float = -1.0  # wind-up of a swipe through the window bars (< 0 = none)
var attack_cooldown: float = 0.0
var attack_hit_done: bool = false
var attack_target: Node3D = null
var stagger_time: float = 0.0

var stuck_timer: float = 0.0
var lift_phase: int = 0  # LIFT traversal: 0 boarding, 1 aboard, 2 stepping off
var lift_wait: float = 0.0
var lift_offset: Vector3 = Vector3.ZERO
var stuck_ref: Vector3 = Vector3.ZERO
var far_timer: float = 0.0
var reached_target: bool = false  # statistics: got into attack range at least once
var requeue_reason: String = ""
var separation: Vector3 = Vector3.ZERO
var traversals: Dictionary = {}  # TraversalLink.Action -> count (statistics / tests)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_actor: ZombieActor, p_director: CrowdDirector, seed_value: int) -> void:
	actor = p_actor
	director = p_director
	archetype = p_actor.archetype
	_rng.seed = seed_value
	pos = p_actor.global_position
	yaw = p_actor.rotation.y
	move_speed = (
		archetype.speed_for(p_actor.tier) * (1.0 + _rng.randf_range(-archetype.speed_jitter, archetype.speed_jitter))
	)
	repath_interval = _rng.randf_range(0.5, 1.0)
	think_timer = _rng.randf_range(0.0, 0.1)
	stuck_ref = pos
	if p_actor.spawn_kind == ZombieSpawner.Kind.RISER:
		_enter(State.SPAWNING)
		actor.start_action(ZombieActor.Action.RISE)
	else:
		_enter(State.PURSUE)


func state_name() -> String:
	return STATE_NAMES[state]


func current_speed_cap() -> float:
	return archetype.crawler_speed if actor.is_crawler() else move_speed


# --- think (staggered, LOD rate) --------------------------------------------------------------


func think(dt: float) -> void:
	if state == State.DEAD:
		return
	target_eval_timer -= dt
	if target_eval_timer <= 0.0 and state in [State.PURSUE, State.IDLE, State.WAIT, State.SPAWNING]:
		target_eval_timer = TARGET_EVAL_INTERVAL * (1.0 + lod)
		_select_target()
	if state == State.IDLE and target != null:
		_enter(State.PURSUE)
	if state == State.PURSUE:
		_think_pursue(dt)
	elif state == State.WAIT:
		_think_wait()
	_check_stuck(dt)


func _think_pursue(dt: float) -> void:
	if target == null:
		_enter(State.IDLE)
		return
	path_age += dt
	var tp: Vector3 = target.global_position
	var need: bool = path.is_empty() or path_index >= path.size()
	need = need or path_age >= repath_interval * (1.0 + lod)
	need = need or (path_goal != Vector3.INF and tp.distance_to(path_goal) > REPATH_MOVE)
	if need and not path_requested:
		director.request_path(self)
	# Attack when in reach of the target (not while crossing a link). Attractors are never attacked.
	if attack_cooldown <= 0.0 and _in_reach(target) and not director.is_attractor(target):
		_begin_attack(target)


func _think_wait() -> void:
	# Waiting outside a window another zombie is working.
	if barricade == null or barricade.occupant == 0 or barricade.occupant == actor.net_id:
		_enter(State.PURSUE)
		path_age = INF


func _in_reach(t: Node3D) -> bool:
	var d: Vector3 = t.global_position - pos
	if absf(d.y) > 1.4:
		return false
	d.y = 0.0
	var reach: float = archetype.reach_for(actor.tier)
	if actor.is_crawler():
		reach *= 0.85
	return d.length() <= reach and not director.is_downed(t)


func _select_target() -> void:
	var lure: int = _select_attractor()
	if lure != 0:
		return  # 1 = chasing an attractor, -1 = path budget spent (retry next think)
	var cands: Array[Node3D] = director.live_targets()
	if cands.is_empty():
		target = null
		return
	if cands.size() == 1:
		if target != cands[0]:
			target = cands[0]
			path_age = INF
		return
	# Path distance (not straight line); queries come out of the director's budget.
	var best: Node3D = null
	var best_len: float = INF
	var cur_len: float = INF
	for c: Node3D in cands:
		var l: float = director.path_length(self, pos, c.global_position)
		if l < 0.0:
			return  # budget exhausted this frame: retry next think
		if c == target:
			cur_len = l
		if l < best_len:
			best_len = l
			best = c
	if best == null:
		# No path to anyone (navmesh not synced yet / everyone unreachable): nearest straight line.
		var bd: float = INF
		for c: Node3D in cands:
			if pos.distance_squared_to(c.global_position) < bd:
				bd = pos.distance_squared_to(c.global_position)
				best = c
		target_eval_timer = 0.0
	if target == null or not cands.has(target) or best_len < cur_len - TARGET_HYSTERESIS:
		if best != target:
			target = best
			path_age = INF
			has_slot = false
	target_path_length = cur_len if best == target and cur_len < INF else best_len


# Drummer Decoy pull (AC-9.6): the closest attractor within its radius by PATH distance wins over
# every player. Returns 1 when chasing one, -1 when the path budget ran out, 0 otherwise.
func _select_attractor() -> int:
	var best: Node3D = null
	var best_len: float = INF
	for a: Node3D in director.live_attractors():
		var radius: float = float(a.get_meta(&"attract_radius", 0.0))
		if pos.distance_to(a.global_position) > radius:
			continue  # straight line is a lower bound of the path distance
		var l: float = director.path_length(self, pos, a.global_position)
		if l < 0.0:
			return -1
		if l <= radius and l < best_len:
			best_len = l
			best = a
	if best == null:
		return 0
	if target != best:
		target = best
		path_age = INF
		has_slot = false
	target_path_length = best_len
	return 1


# --- move (every physics frame) ---------------------------------------------------------------


func move(dt: float) -> void:
	state_time += dt
	attack_cooldown -= dt
	match state:
		State.SPAWNING:
			if state_time >= RISE_TIME:
				actor.start_action(ZombieActor.Action.NONE)
				_enter(State.PURSUE if target != null else State.IDLE)
			_set_speed(0.0, dt)
		State.PURSUE:
			_move_pursue(dt)
		State.ATTACK:
			_move_attack(dt)
		State.TEAR:
			_move_tear(dt)
		State.TRAVERSE:
			_move_traverse(dt)
		State.STAGGER:
			_set_speed(0.0, dt)
			if state_time >= stagger_time:
				actor.set_flag(ZombieActor.Flag.STUNNED, false)
				actor.start_action(ZombieActor.Action.NONE)
				_enter(State.PURSUE)
		State.WAIT, State.IDLE:
			_set_speed(0.0, dt)
			_apply_separation(dt)
	_write_actor()


func _move_pursue(dt: float) -> void:
	if target == null:
		_set_speed(0.0, dt)
		return
	var goal: Vector3 = Vector3.INF
	var tp: Vector3 = target.global_position
	var flat_d: float = Vector2(tp.x - pos.x, tp.z - pos.z).length()
	# Final approach: straight at the surround slot when the path says it's a direct line.
	if path_direct and flat_d < DIRECT_RANGE and absf(tp.y - pos.y) < 0.8:
		goal = tp + (slot_offset if has_slot else Vector3.ZERO)
		if _in_reach(target) and (not has_slot or Vector2(goal.x - pos.x, goal.z - pos.z).length() < 0.25):
			goal = Vector3.INF
	elif path_index < path.size():
		goal = path[path_index]
		var to_c: Vector3 = goal - pos
		var flat: float = Vector2(to_c.x, to_c.z).length()
		if flat < WINDOW_QUEUE_RANGE and _window_busy_at(path_index):
			_enter(State.WAIT)
			actor.start_action(ZombieActor.Action.WAIT)
			_set_speed(0.0, dt)
			return
		if flat < CORNER_REACHED and absf(to_c.y) < 1.2:
			if _link_starts_at(path_index):
				_begin_link(path_index)
				return
			path_index += 1
			if path_index >= path.size():
				goal = Vector3.INF
			else:
				goal = path[path_index]
	if goal == Vector3.INF:
		_set_speed(0.0, dt)
		_face(tp - pos, dt)
		_apply_separation(dt)
		return
	var dir: Vector3 = goal - pos
	dir.y = 0.0
	var dist: float = dir.length()
	var cap: float = current_speed_cap()
	var want: Vector3 = (dir / maxf(dist, 0.001)) * minf(cap, dist / maxf(dt, 0.001))
	velocity = velocity.lerp(want, clampf(dt * 8.0, 0.0, 1.0))
	var step: Vector3 = (velocity + separation) * dt
	pos = director.snap(pos + step, pos)
	_face(velocity, dt)
	actor.speed = velocity.length()


func _set_speed(_v: float, dt: float) -> void:
	velocity = velocity.lerp(Vector3.ZERO, clampf(dt * 10.0, 0.0, 1.0))
	actor.speed = velocity.length()


func _apply_separation(dt: float) -> void:
	if separation.length_squared() > 0.0001:
		pos = director.snap(pos + separation * dt, pos)


func _face(dir: Vector3, dt: float) -> void:
	if Vector2(dir.x, dir.z).length_squared() < 0.0001:
		return
	# Models face +Z.
	var want: float = atan2(dir.x, dir.z)
	yaw = rotate_toward(yaw, want, archetype.turn_rate * dt)


# --- path -------------------------------------------------------------------------------------


func set_path(p: PackedVector3Array, owners: PackedInt64Array, types: PackedInt32Array, goal: Vector3) -> void:
	path_requested = false
	path = p
	path_owners = owners
	path_types = types
	path_goal = goal
	path_age = 0.0
	path_index = 1 if p.size() > 1 else 0
	if p.is_empty():
		return
	var length: float = 0.0
	for i: int in range(1, p.size()):
		length += p[i - 1].distance_to(p[i])
	var straight: float = pos.distance_to(p[p.size() - 1])
	path_direct = length <= straight * 1.15 + 0.5 and _no_links(p.size())
	if target != null and target_path_length == INF:
		target_path_length = length
	var end: Vector3 = p[p.size() - 1]
	if target != null and Vector2(end.x - goal.x, end.z - goal.z).length() > 2.5:
		no_path_time += path_age + repath_interval
	else:
		no_path_time = 0.0


func _no_links(n: int) -> bool:
	for i: int in n:
		if director.link_for_owner(path_owners[i]) != null:
			return false
	return true


# The next corner starts a window link whose barricade another zombie is working.
func _window_busy_at(i: int) -> bool:
	if not _link_starts_at(i):
		return false
	var l: TraversalLink = director.link_for_owner(path_owners[i])
	if l.action != TraversalLink.Action.WINDOW or l.barricade == null:
		return false
	barricade = l.barricade
	return l.barricade.occupant != 0 and l.barricade.occupant != actor.net_id


func _link_starts_at(i: int) -> bool:
	if i + 1 >= path.size():
		return false
	# Path metadata marks the link's entry point with the link as owner; the next point is its exit.
	return director.link_for_owner(path_owners[i]) != null


func _begin_link(i: int) -> void:
	traverse_link = director.link_for_owner(path_owners[i])
	traverse_from = path[i]
	traverse_to = path[i + 1]
	path_index = i + 2
	traversals[traverse_link.action] = int(traversals.get(traverse_link.action, 0)) + 1
	if traverse_link.action == TraversalLink.Action.WINDOW and traverse_link.barricade != null:
		barricade = traverse_link.barricade
		if barricade.occupant != 0 and barricade.occupant != actor.net_id:
			_enter(State.WAIT)
			actor.start_action(ZombieActor.Action.WAIT)
			return
		barricade.occupant = actor.net_id
		if not barricade.is_open():
			_enter(State.TEAR)
			tear_timer = archetype.tear_time_for(actor.tier)
			actor.start_action(ZombieActor.Action.TEAR)
			return
	_start_traverse()


func _start_traverse() -> void:
	var a: int = ZombieActor.Action.CLIMB
	traverse_duration = archetype.climb_time
	match traverse_link.action:
		TraversalLink.Action.DROP:
			a = ZombieActor.Action.DROP
			traverse_duration = traverse_link.traverse_time(archetype.crawler_speed)
		TraversalLink.Action.VENT:
			a = ZombieActor.Action.VENT
			traverse_duration = traverse_link.traverse_time(archetype.crawler_speed)
		TraversalLink.Action.JUMP:
			a = ZombieActor.Action.DROP
			traverse_duration = traverse_link.traverse_time(archetype.crawler_speed)
		TraversalLink.Action.LIFT:
			a = ZombieActor.Action.NONE
			traverse_duration = 1.0e9
			lift_phase = 0
			lift_wait = 0.0
	_enter(State.TRAVERSE)
	actor.start_action(a)
	actor.set_flag(ZombieActor.Flag.TRAVERSING, true)


func _move_tear(dt: float) -> void:
	_set_speed(0.0, dt)
	_face(traverse_to - traverse_from, dt)
	if barricade == null or barricade.is_open():
		_start_traverse()
		return
	if window_swipe_timer >= 0.0:
		window_swipe_timer -= dt
		if window_swipe_timer < 0.0:
			var v: Node3D = _window_victim()
			if v != null:
				director.damage_target(v, archetype.attack_damage, pos)
			tear_timer = archetype.attack_cooldown
		return
	tear_timer -= dt
	if tear_timer <= 0.0 and barricade.planks < barricade.max_planks and _window_victim() != null:
		# A player stands at a partly broken window: swipe through the bars (telegraphed).
		window_swipe_timer = archetype.attack_windup
		actor.start_action(ZombieActor.Action.ATTACK)
		Audio.play_event_3d(&"zombie_attack", pos)
		return
	if tear_timer <= 0.0:
		barricade.host_tear()
		Audio.play_event_3d(&"zombie_tear", pos)
		if barricade.is_open():
			_start_traverse()
		else:
			tear_timer = archetype.tear_time_for(actor.tier)
			actor.start_action(ZombieActor.Action.TEAR)


func _window_victim() -> Node3D:
	for t: Node3D in director.live_targets():
		var d: Vector3 = t.global_position - pos
		if absf(d.y) < 1.5 and Vector2(d.x, d.z).length() <= archetype.window_swipe_range:
			return t
	return null


func _move_traverse(dt: float) -> void:
	if traverse_link != null and traverse_link.action == TraversalLink.Action.LIFT:
		_move_lift(dt)
		return
	var t: float = clampf(state_time / maxf(traverse_duration, 0.05), 0.0, 1.0)
	var p: Vector3 = traverse_from.lerp(traverse_to, t)
	if traverse_link != null and traverse_link.action == TraversalLink.Action.DROP:
		# Short hop out, then fall: ease the height so the drop reads as gravity.
		p.y = lerpf(traverse_from.y, traverse_to.y, t * t)
	pos = p
	_face(traverse_to - traverse_from, dt)
	actor.speed = (
		traverse_from.distance_to(traverse_to) / traverse_duration
		if traverse_link.action == TraversalLink.Action.VENT
		else 0.0
	)
	if t >= 1.0:
		_end_traverse()


# Rides a TraversalMachine (freight lift): walk aboard while it is docked at the link's station,
# ride (position follows the machine), step off at the other station. Gives up (re-queue) when
# the lift doesn't come or doesn't leave.
func _move_lift(dt: float) -> void:
	var m: TraversalMachine = traverse_link.machine
	if m == null:
		_end_traverse()
		return
	var now: float = Net.host_time()
	var docked: int = m.docked_at(now)
	match lift_phase:
		0:
			if docked != traverse_link.station:
				lift_wait += dt
				_set_speed(0.0, dt)
			else:
				var board: Vector3 = (
					m.position_at(now)
					+ Vector3(sin(float(actor.net_id) * 1.7) * 0.8, 0.0, cos(float(actor.net_id) * 1.3) * 0.8)
				)
				if _step_toward(board, dt):
					lift_offset = pos - m.position_at(now)
					lift_phase = 1
					lift_wait = 0.0
		1:
			pos = m.position_at(now) + lift_offset
			actor.speed = 0.0
			if docked == 1 - traverse_link.station:
				lift_phase = 2
			elif docked == traverse_link.station:
				lift_wait += dt
		2:
			if _step_toward(traverse_to, dt):
				_end_traverse()
				return
	if lift_wait > LIFT_GIVE_UP:
		requeue_reason = "lift wait"


# Walks straight at `goal` (no navmesh: lift floors aren't on it). True when there.
func _step_toward(goal: Vector3, dt: float) -> bool:
	var d: Vector3 = goal - pos
	var flat: float = Vector2(d.x, d.z).length()
	if flat < 0.2:
		return true
	var step: float = minf(current_speed_cap() * dt, flat)
	pos += Vector3(d.x, 0.0, d.z) / flat * step
	pos.y = lerpf(pos.y, goal.y, clampf(dt * 10.0, 0.0, 1.0))
	_face(d, dt)
	actor.speed = step / maxf(dt, 0.001)
	return false


func _end_traverse() -> void:
	pos = director.snap(traverse_to, traverse_to)
	actor.set_flag(ZombieActor.Flag.TRAVERSING, false)
	actor.start_action(ZombieActor.Action.NONE)
	if barricade != null and barricade.occupant == actor.net_id:
		barricade.occupant = 0
	barricade = null
	traverse_link = null
	stuck_ref = pos
	stuck_timer = 0.0
	_enter(State.PURSUE)


# --- attack / reactions -----------------------------------------------------------------------


func _begin_attack(t: Node3D) -> void:
	attack_target = t
	attack_hit_done = false
	attack_cooldown = archetype.attack_cooldown
	reached_target = true
	_enter(State.ATTACK)
	actor.start_action(ZombieActor.Action.ATTACK)


func _move_attack(dt: float) -> void:
	_set_speed(0.0, dt)
	if attack_target != null and is_instance_valid(attack_target):
		_face(attack_target.global_position - pos, dt)
	_apply_separation(dt)
	if not attack_hit_done and state_time >= archetype.attack_windup:
		attack_hit_done = true
		if attack_target != null and is_instance_valid(attack_target):
			var d: Vector3 = attack_target.global_position - pos
			var reach: float = archetype.reach_for(actor.tier) + 0.5
			if absf(d.y) < 1.5 and Vector2(d.x, d.z).length() <= reach and not director.is_downed(attack_target):
				var dmg: float = archetype.crawler_attack_damage if actor.is_crawler() else archetype.attack_damage
				director.damage_target(attack_target, dmg, pos + Vector3.UP * 1.2)
	if state_time >= archetype.attack_duration:
		actor.start_action(ZombieActor.Action.NONE)
		_enter(State.PURSUE)


func on_damaged(info: DamageInfo, survives: bool) -> void:
	if not survives:
		_enter(State.DEAD)
		_release_barricade()
		return
	if info.kind == DamageInfo.Kind.EXPLOSIVE and not actor.is_crawler():
		var low: bool = info.position == Vector3.ZERO or info.position.y < pos.y + 0.9
		if low and info.amount >= archetype.crawler_explosive_fraction * actor.max_health:
			actor.set_flag(ZombieActor.Flag.CRAWLER, true)
			director.crawlers_created += 1
	if state in [State.TRAVERSE, State.SPAWNING]:
		return
	if info.amount >= archetype.stagger_fraction * actor.max_health:
		stagger_time = archetype.stagger_time
		actor.set_flag(ZombieActor.Flag.STUNNED, true)
		_release_barricade()
		_enter(State.STAGGER)
		actor.start_action(ZombieActor.Action.STAGGER)


func _release_barricade() -> void:
	if barricade != null and barricade.occupant == actor.net_id:
		barricade.occupant = 0
	if state != State.TRAVERSE:
		barricade = null


# --- stuck / far handling (ARCHITECTURE §7.2) -------------------------------------------------


func _check_stuck(dt: float) -> void:
	if state in [State.PURSUE]:
		stuck_timer += dt
		if stuck_timer >= STUCK_WINDOW:
			var moved: float = pos.distance_to(stuck_ref)
			var near_target: bool = target != null and pos.distance_to(target.global_position) < STUCK_NEAR_TARGET
			if moved < STUCK_MIN_PROGRESS and not near_target:
				requeue_reason = "stuck (moved %.2f m in %.0f s)" % [moved, STUCK_WINDOW]
				return
			stuck_timer = 0.0
			stuck_ref = pos
	else:
		stuck_timer = 0.0
		stuck_ref = pos
	if target_path_length > FAR_DISTANCE and target_path_length < INF:
		far_timer += dt
		if far_timer >= FAR_TIME:
			requeue_reason = "far (%.0f m path)" % target_path_length
	else:
		far_timer = 0.0
	if no_path_time >= NO_PATH_TIME:
		requeue_reason = "no path to target"


func _enter(s: State) -> void:
	state = s
	state_time = 0.0


func _write_actor() -> void:
	actor.global_position = pos
	actor.rotation.y = yaw
	actor.set_flag(ZombieActor.Flag.AGGRO, target != null and state != State.IDLE)
	if target != null and is_instance_valid(target):
		actor.look_target = target.global_position + Vector3.UP * 1.5
	else:
		actor.look_target = Vector3.INF
