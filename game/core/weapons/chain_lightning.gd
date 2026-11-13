# ChainLightning — target selection and damage of the Lazarus Conduit's arc (GAME_DESIGN §7.2,
# DEVELOPMENT_PLAN Step 12A): pure functions over target positions so the rules are unit-tested
# with a dummy cluster (AC-12.2) and the host applies them to live zombies (WeaponSync).
#   first : the target within `max_range` whose aim point is inside `cone_deg` of the aim
#           direction, smallest angle first (aim assist), visible (`visible` callable);
#   chain : greedy — each jump goes to the nearest not-yet-struck target within `jump_range` of
#           the previous one (and visible from it), up to `jumps` jumps;
#   damage: jump j (0 = first target) deals base x falloff^max(0, j - full_jumps).
# Authority: HOST (pure logic; no state).
class_name ChainLightning
extends RefCounted


# Index of the first target, or -1. `visible(from, to) -> bool` (null = everything visible).
static func pick_first(
	eye: Vector3,
	forward: Vector3,
	points: Array[Vector3],
	max_range: float,
	cone_deg: float,
	visible: Callable = Callable()
) -> int:
	var best: int = -1
	var best_angle: float = INF
	var fw: Vector3 = forward.normalized()
	for i: int in points.size():
		var to: Vector3 = points[i] - eye
		var d: float = to.length()
		if d > max_range or d < 0.01:
			continue
		var ang: float = rad_to_deg(acos(clampf(fw.dot(to / d), -1.0, 1.0)))
		# Up close the cone is widened to the target's body (a 4° cone at 2 m is only 14 cm).
		var allowed: float = maxf(cone_deg, rad_to_deg(atan(0.35 / d)))
		if ang > allowed:
			continue
		if visible.is_valid() and not bool(visible.call(eye, points[i])):
			continue
		if ang < best_angle - 0.01 or (absf(ang - best_angle) <= 0.01 and d < eye.distance_to(points[best])):
			best_angle = ang
			best = i
	return best


# Order of targets struck: [first, jump 1, jump 2 ...] (indices into `points`).
static func chain(
	first: int, points: Array[Vector3], jumps: int, jump_range: float, visible: Callable = Callable(), skip: Array = []
) -> PackedInt32Array:
	var order: PackedInt32Array = PackedInt32Array()
	if first < 0 or first >= points.size():
		return order
	order.append(first)
	var used: Dictionary = {first: true}
	for i: int in skip:
		used[i] = true
	var cur: int = first
	for j: int in jumps:
		var best: int = -1
		var best_d: float = INF
		for i: int in points.size():
			if used.has(i):
				continue
			var d: float = points[cur].distance_to(points[i])
			if d > jump_range or d >= best_d:
				continue
			if visible.is_valid() and not bool(visible.call(points[cur], points[i])):
				continue
			best_d = d
			best = i
		if best < 0:
			break
		order.append(best)
		used[best] = true
		cur = best
	return order


# Up to `n` targets nearest to `from` within `jump_range` (visible, not in `skip`): the Requiem's
# kill arcs fan out from the zombie that died.
static func nearest(
	from: int, points: Array[Vector3], n: int, jump_range: float, visible: Callable = Callable(), skip: Array = []
) -> PackedInt32Array:
	var cands: Array = []
	for i: int in points.size():
		if i == from or skip.has(i):
			continue
		var d: float = points[from].distance_to(points[i])
		if d > jump_range:
			continue
		if visible.is_valid() and not bool(visible.call(points[from], points[i])):
			continue
		cands.append([d, i])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: PackedInt32Array = PackedInt32Array()
	for c: Array in cands.slice(0, n):
		out.append(int(c[1]))
	return out


static func damage_at(base: float, jump: int, falloff: float, full_jumps: int) -> float:
	return base * pow(falloff, maxi(0, jump - full_jumps))


static func damage_for(def: WeaponDefinition, jump: int) -> float:
	return damage_at(def.damage, jump, def.chain_falloff, def.chain_full_jumps)
