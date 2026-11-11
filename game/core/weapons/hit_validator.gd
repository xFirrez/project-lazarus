# HitValidator — host-side sanity checks for shot and hit claims (ARCHITECTURE §5.1,
# "favor the shooter"): the weapon is owned, the host's mirrored magazine has a round, the shot
# respects the weapon's fire rate (sender-clock spacing plus an arrival-time credit bucket so
# reordering/jitter never false-positives but a rate hack can't bank shots), the target exists
# and is alive, the hit is within weapon range of the shooter's host-known position, the claimed
# penetration index is possible, and a rough line of sight exists (thin props pass).
# Damage is always recomputed from the WeaponDefinition by the caller — claims carry no amounts.
# Authority: HOST only.
class_name HitValidator
extends RefCounted

enum Result { OK, NOT_OWNED, NO_AMMO, RATE, RANGE, DEAD_TARGET, UNKNOWN_TARGET, DUPLICATE, LOS, BAD_DATA }

const RATE_TOLERANCE: float = 0.85  # claimed shots may be up to 15% closer than 60/RPM (timer jitter)
const MIN_GAP_SLACK: float = 0.035  # ... or two 60 Hz frames, whichever is larger
const FUTURE_SLACK: float = 0.35  # s a claimed shot time may lead the host clock
const RANGE_SLACK: float = 2.5  # m beyond max_range (target motion, eye height)
const CREDIT_SECONDS: float = 0.6  # arrival-time burst allowance (reliable resend bunching)
const MIN_CREDIT: float = 3.0


class ShooterState:
	extends RefCounted
	var owned: Dictionary = {}  # weapon id -> [mag, reserve]
	var last_shot: Dictionary = {}  # weapon id -> sender host-clock time
	var credit: Dictionary = {}  # weapon id -> shots available
	var credit_time: Dictionary = {}  # weapon id -> host time of last credit update
	var last_seq: int = -1
	var infinite_ammo: bool = false


var states: Dictionary = {}  # peer id -> ShooterState
var accepted_shots: int = 0
var accepted_hits: int = 0
var rejections: Dictionary = {}  # Result name -> count
var last_rejection: String = ""


func state_for(peer_id: int) -> ShooterState:
	if not states.has(peer_id):
		states[peer_id] = ShooterState.new()
	return states[peer_id]


func remove_peer(peer_id: int) -> void:
	states.erase(peer_id)


func give(peer_id: int, def: WeaponDefinition, mag: int = -1, reserve: int = -1) -> void:
	var s: ShooterState = state_for(peer_id)
	s.owned[def.id] = [def.mag_size if mag < 0 else mag, def.reserve_max if reserve < 0 else reserve]


func take(peer_id: int, weapon_id: StringName) -> void:
	state_for(peer_id).owned.erase(weapon_id)


func owns(peer_id: int, weapon_id: StringName) -> bool:
	return state_for(peer_id).owned.has(weapon_id)


func ammo(peer_id: int, weapon_id: StringName) -> Array:
	return state_for(peer_id).owned.get(weapon_id, [0, 0])


# Shot claim: ownership, mirrored ammo, duplicate sequence, fire rate. Consumes a round if OK.
func check_shot(peer_id: int, def: WeaponDefinition, seq: int, shot_time: float, now: float) -> Result:
	var s: ShooterState = state_for(peer_id)
	if not s.owned.has(def.id):
		return _reject(Result.NOT_OWNED, "%s not owned" % def.id)
	if seq <= s.last_seq:
		return _reject(Result.DUPLICATE, "seq %d <= %d" % [seq, s.last_seq])
	var interval: float = def.melee_time if def.is_melee() else def.fire_interval()
	if shot_time > now + FUTURE_SLACK:
		return _reject(Result.RATE, "shot time %.3f ahead of host %.3f" % [shot_time, now])
	if s.last_shot.has(def.id):
		var gap: float = shot_time - float(s.last_shot[def.id])
		if gap < min_shot_gap(interval):
			return _reject(Result.RATE, "%s gap %.1f ms < %.1f ms" % [def.id, gap * 1000.0, interval * 1000.0])
	var cap: float = maxf(MIN_CREDIT, CREDIT_SECONDS / interval)
	var credit: float = cap
	if s.credit.has(def.id):
		credit = minf(cap, float(s.credit[def.id]) + (now - float(s.credit_time[def.id])) / interval)
	if credit < 0.999:
		return _reject(Result.RATE, "%s arrival rate exceeds %.0f RPM" % [def.id, 60.0 / interval])
	var a: Array = s.owned[def.id]
	if not def.is_melee() and int(a[0]) <= 0 and not s.infinite_ammo:
		return _reject(Result.NO_AMMO, "%s mirrored magazine empty" % def.id)
	if not def.is_melee() and not s.infinite_ammo:
		a[0] = int(a[0]) - 1
	s.credit[def.id] = credit - 1.0
	s.credit_time[def.id] = now
	s.last_shot[def.id] = shot_time
	s.last_seq = seq
	accepted_shots += 1
	return Result.OK


# Hit claim for an accepted shot. `space` (optional) enables the rough line-of-sight test.
func check_hit(
	def: WeaponDefinition,
	shooter_eye: Vector3,
	target: HitTarget,
	zone: int,
	claimed_distance: float,
	target_index: int,
	props: int,
	space: PhysicsDirectSpaceState3D = null
) -> Result:
	if target == null:
		return _reject(Result.UNKNOWN_TARGET, "unknown target")
	if not target.alive:
		return _reject(Result.DEAD_TARGET, "target %d is dead" % target.target_id)
	if zone < 0 or zone > WeaponDefinition.Hitzone.LIMB or props < 0 or props > Ballistics.MAX_PROPS:
		return _reject(Result.BAD_DATA, "bad zone/props")
	if target_index < 0 or target_index >= maxi(def.penetration, 1):
		return _reject(Result.BAD_DATA, "penetration index %d >= %d" % [target_index, def.penetration])
	var limit: float = max_hit_range(def)
	var actual: float = shooter_eye.distance_to(target.zone_position(zone))
	if claimed_distance > limit or actual > limit:
		return _reject(
			Result.RANGE, "%s hit at %.1f m (claimed %.1f) > %.1f m" % [def.id, actual, claimed_distance, limit]
		)
	if space != null and not has_line_of_sight(space, shooter_eye, target.zone_position(zone)):
		return _reject(Result.LOS, "no line of sight to target %d" % target.target_id)
	accepted_hits += 1
	return Result.OK


# Reload report from the owner: magazine + reserve may never grow (ammo conservation).
func check_reload(peer_id: int, weapon_id: StringName, mag: int, reserve: int) -> bool:
	var s: ShooterState = state_for(peer_id)
	if not s.owned.has(weapon_id):
		return false
	var a: Array = s.owned[weapon_id]
	if s.infinite_ammo:
		a[0] = mag
		a[1] = reserve
		return true
	if mag < 0 or reserve < 0 or mag + reserve > int(a[0]) + int(a[1]):
		_reject(Result.BAD_DATA, "reload %d+%d exceeds mirrored %d+%d" % [mag, reserve, a[0], a[1]])
		return false
	a[0] = mag
	a[1] = reserve
	return true


# Smallest accepted spacing of two claimed shots: owners fire on 60 Hz ticks with the sub-frame
# remainder carried, so single gaps can be one frame shorter than 60 / RPM.
static func min_shot_gap(interval: float) -> float:
	return interval - maxf(interval * (1.0 - RATE_TOLERANCE), MIN_GAP_SLACK)


static func max_hit_range(def: WeaponDefinition) -> float:
	if def.is_melee():
		return def.melee_reach + def.melee_lunge + 1.0
	return def.max_range + RANGE_SLACK


static func has_line_of_sight(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var excl: Array[RID] = []
	for i: int in Ballistics.MAX_PROPS + 1:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, Ballistics.WORLD_MASK)
		q.exclude = excl
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			return true
		if not Ballistics.is_thin_prop(hit["collider"]):
			return false
		excl.append(hit["rid"])
	return false


func rejection_count() -> int:
	var n: int = 0
	for k: String in rejections:
		n += int(rejections[k])
	return n


func _reject(r: Result, reason: String) -> Result:
	var key: String = Result.keys()[r]
	rejections[key] = int(rejections.get(key, 0)) + 1
	last_rejection = "%s: %s" % [key, reason]
	return r
