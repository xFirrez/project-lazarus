# SpawnDirector — feeds the RoundDirector's queue into the world (ARCHITECTURE §7.3,
# GAME_DESIGN §5.2): one zombie every spawn_interval(r, p) while the round's alive count is under
# the alive cap, from spawners in ACTIVE zones only (ZoneManager), past their `min_round`, and
# fair: never within 8 m of a player and never in a player's line of sight (risers excepted
# beyond 12 m). Spawns rotate across players in co-op (distance-band weighting around a
# round-robin player). Every spawn is re-checked and logged; `violations` must stay 0 (AC-6.3).
# Takes over re-queues from ZombieSync (`auto_respawn = false`): they return through the queue.
# Special enemies (Galvanics, Step 12) arrive through energy rifts instead of spawners: a rift opens
# near a player (8-25 m, fair distance, sight allowed — it is the telegraph), crackles for
# RoundCurve.rift_telegraph on every peer (WonderFx RIFT), then the enemy steps out. At most
# `special_alive_cap` special enemies (rifts included) at once.
# Authority: HOST only.
class_name SpawnDirector
extends Node

const MIN_DISTANCE: float = 8.0
const RISER_LOS_DISTANCE: float = 12.0
const EYE_HEIGHT: float = 1.6
const TARGET_HEIGHT: float = 1.2
const RETRY_DELAY: float = 0.25

var rounds: RoundDirector = null
var zombies: ZombieSync = null
var zones: ZoneManager = null
var players: PlayerSync = null
var curve: RoundCurve = null
var spawns: int = 0
var violations: int = 0
var stalls: int = 0  # no fair spawner available at a spawn tick
var min_distance_seen: float = INF
var log_spawns: bool = false  # Log every spawn (soak tests)

var rifts: Array = []  # host: pending [position, seconds left, yaw]
var rifts_opened: int = 0
var rift_min_distance_seen: float = INF
# Quest hooks (Step 14): spawn-interval divisor (escort ×1.5) and zones whose spawners are active
# even when not unlocked ("every vent in Z09 / Z10 / Z13").
var rate_scale: float = 1.0
var extra_zones: Array[StringName] = []

var _timer: float = 0.0
var _special_timer: float = 0.0
var _rr: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	name = "Spawns"
	_rng.randomize()
	if zombies != null and ZombieSync.is_authority():
		zombies.auto_respawn = false


func _physics_process(delta: float) -> void:
	if rounds == null or not RoundDirector.is_authority() or rounds.phase != RoundDirector.Phase.ACTIVE:
		_timer = 0.0
		_special_timer = 0.0
		rifts.clear()  # RoundDirector resets its pending count at the next round start / skip
		return
	_tick_rifts(delta)
	_tick_special(delta)
	_timer -= delta
	if rounds.event_hold:
		return
	if _timer > 0.0 or rounds.queue.is_empty():
		return
	if rounds.round_ids.size() >= curve.alive_cap(rounds.player_count()):
		return
	if not zombies.crowd.is_ready():
		return
	var sp: ZombieSpawner = pick_spawner()
	if sp == null:
		stalls += 1
		_timer = RETRY_DELAY
		return
	var tier: int = rounds.host_take_next()
	var a: ZombieActor = zombies.host_spawn(
		rounds.archetype, tier, sp.global_position, sp.global_rotation.y, sp.kind, -1, rounds.zombie_health()
	)
	if a == null:
		rounds.queue.push_front(tier)
		_timer = RETRY_DELAY
		return
	rounds.host_register_spawn(a)
	_record(sp)
	_timer = curve.spawn_interval(rounds.current_round, rounds.player_count()) / maxf(rate_scale, 0.1)


# --- special enemies through rifts -------------------------------------------------------------


func _tick_special(delta: float) -> void:
	_special_timer -= delta
	if _special_timer > 0.0 or rounds.special_left <= 0 or not zombies.crowd.is_ready():
		return
	var mixed: bool = not rounds.is_special_round()
	if mixed and rounds.queue.size() > rounds.total / 2:
		return  # mixed rounds: they join in the second half
	var cap: int = curve.special_alive_cap if not mixed else curve.mixed_max
	if rounds.special_ids.size() + rifts.size() >= cap:
		return
	if rounds.round_ids.size() + rifts.size() >= curve.alive_cap(rounds.player_count()):
		return
	var at: Vector3 = pick_rift_position()
	if at == Vector3.INF:
		_special_timer = RETRY_DELAY
		return
	var arch: ZombieArchetype = rounds.host_take_special()
	if arch == null:
		return
	var yaw: float = _rng.randf_range(-PI, PI)
	rifts.append([at, curve.rift_telegraph, yaw])
	rifts_opened += 1
	WonderFx.play(self, WonderFx.Kind.RIFT, PackedVector3Array([at]), 1.0, WonderFx.Variant.ELECTRIC)
	_special_timer = curve.special_spawn_interval


func _tick_rifts(delta: float) -> void:
	for i: int in range(rifts.size() - 1, -1, -1):
		var r: Array = rifts[i]
		r[1] = float(r[1]) - delta
		if float(r[1]) > 0.0:
			continue
		rifts.remove_at(i)
		var a: ZombieActor = zombies.host_spawn(
			rounds.special_archetype,
			ZombieArchetype.Tier.SPRINT,
			r[0],
			float(r[2]),
			ZombieSpawner.Kind.SPECIAL,
			-1,
			rounds.special_health_value
		)
		if a == null:
			rounds.host_return_special()
			continue
		rounds.host_register_special(a)
		var nearest: float = INF
		for p: PlayerCharacter in watchers():
			nearest = minf(nearest, a.global_position.distance_to(p.global_position))
		rift_min_distance_seen = minf(rift_min_distance_seen, nearest)


# A navmesh point 8-25 m from a player (round-robin), near an active-zone spawner.
func pick_rift_position() -> Vector3:
	var ws: Array[PlayerCharacter] = watchers()
	var active: Array[StringName] = zones.active_zones() if zones != null else []
	var near: Array[Vector3] = []
	var fallback: Array[Vector3] = []
	_rr = (_rr + 1) % maxi(ws.size(), 1)
	var focus: PlayerCharacter = ws[_rr] if not ws.is_empty() else null
	for s: ZombieSpawner in zombies.spawners:
		if zones != null and s.zone != &"" and not active.has(s.zone) and not extra_zones.has(s.zone):
			continue
		var p: Vector3 = s.global_position + Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2))
		p = zombies.crowd.snap(p, s.global_position)
		var ok: bool = true
		for w: PlayerCharacter in ws:
			if p.distance_to(w.global_position) < MIN_DISTANCE:
				ok = false
		if not ok:
			continue
		fallback.append(p)
		if focus != null and p.distance_to(focus.global_position) <= 25.0:
			near.append(p)
	var pool: Array[Vector3] = near if not near.is_empty() else fallback
	if pool.is_empty():
		return Vector3.INF
	return pool[_rng.randi_range(0, pool.size() - 1)]


func watchers() -> Array[PlayerCharacter]:
	var out: Array[PlayerCharacter] = []
	if players != null:
		for id: int in players.avatars:
			var p: PlayerCharacter = players.avatars[id]
			if not p.spectating:
				out.append(p)
	return out


func candidates() -> Array[ZombieSpawner]:
	var out: Array[ZombieSpawner] = []
	var active: Array[StringName] = zones.active_zones() if zones != null else []
	for s: ZombieSpawner in zombies.spawners:
		if s.min_round > rounds.current_round:
			continue
		if zones != null and s.zone != &"" and not active.has(s.zone):
			continue
		if is_fair(s.global_position, s.kind):
			out.append(s)
	return out


func pick_spawner() -> ZombieSpawner:
	var list: Array[ZombieSpawner] = candidates()
	if list.is_empty():
		return null
	var ws: Array[PlayerCharacter] = watchers()
	var focus: PlayerCharacter = null
	if not ws.is_empty():
		_rr = (_rr + 1) % ws.size()
		focus = ws[_rr]
	var weights: PackedFloat32Array = PackedFloat32Array()
	var total_w: float = 0.0
	for s: ZombieSpawner in list:
		var w: float = 1.0
		if focus != null:
			var d: float = s.global_position.distance_to(focus.global_position)
			w = 4.0 if d <= 30.0 else (2.0 if d <= 50.0 else 1.0)
		weights.append(w)
		total_w += w
	var roll: float = _rng.randf() * total_w
	for i: int in list.size():
		roll -= weights[i]
		if roll <= 0.0:
			return list[i]
	return list[list.size() - 1]


# Fairness rule (GAME_DESIGN §5.2): >= 8 m from every player and out of their line of sight
# (risers may spawn in view beyond 12 m).
func is_fair(pos: Vector3, kind: int) -> bool:
	for p: PlayerCharacter in watchers():
		var d: float = pos.distance_to(p.global_position)
		if d < MIN_DISTANCE:
			return false
		if kind == ZombieSpawner.Kind.RISER and d > RISER_LOS_DISTANCE:
			continue
		if has_line_of_sight(p, pos):
			return false
	return true


func has_line_of_sight(p: PlayerCharacter, pos: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		p.global_position + Vector3.UP * EYE_HEIGHT, pos + Vector3.UP * TARGET_HEIGHT, 1
	)
	return space.intersect_ray(q).is_empty()


func _record(sp: ZombieSpawner) -> void:
	spawns += 1
	var nearest: float = INF
	var seen: bool = false
	for p: PlayerCharacter in watchers():
		var d: float = sp.global_position.distance_to(p.global_position)
		nearest = minf(nearest, d)
		if (
			has_line_of_sight(p, sp.global_position)
			and not (sp.kind == ZombieSpawner.Kind.RISER and d > RISER_LOS_DISTANCE)
		):
			seen = true
	min_distance_seen = minf(min_distance_seen, nearest)
	if nearest < MIN_DISTANCE or seen:
		violations += 1
		Log.warn(&"spawns", "Unfair spawn at %s (nearest %.1f m, seen %s)" % [sp.name, nearest, seen])
	elif log_spawns:
		Log.debug(&"spawns", "r%d %s nearest %.1f m" % [rounds.current_round, sp.name, nearest])
