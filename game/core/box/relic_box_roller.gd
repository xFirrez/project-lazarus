# RelicBoxRoller — pure Relic Box roll logic (GAME_DESIGN §10.2-10.4), shared by the host system
# and the statistics tests (AC-9.4):
#   * eligibility: not already owned, condition flag set, definition exists;
#   * weights: pool weights, wonder entries + `bad_luck` (per-player bonus);
#   * doll chance: 0 for the first `doll_free_uses` spins at a location and during a Fire Sale,
#     then doll_base, +doll_step per further spin, capped at doll_max;
#   * relocation: a uniformly random location other than the current one.
# Authority: pure functions (the host rolls; clients only display the broadcast result).
class_name RelicBoxRoller
extends RefCounted

const DOLL: StringName = &"doll"


# Eligible [ids, weights] for a spinner. `owns` / `condition` / `exists` are Callables taking an
# id (owns, exists) or a flag key (condition) and returning bool.
static func eligible(
	pool: RelicBoxPool, owns: Callable, condition: Callable, exists: Callable, bad_luck: float
) -> Array:
	var ids: Array[StringName] = []
	var w: PackedFloat32Array = []
	for i: int in pool.item_ids.size():
		var id: StringName = pool.item_ids[i]
		if not bool(exists.call(id)) or bool(owns.call(id)):
			continue
		if pool.conditions.has(id) and not bool(condition.call(String(pool.conditions[id]))):
			continue
		var weight: float = pool.weights[i] if i < pool.weights.size() else 0.0
		if pool.wonder_ids.has(id):
			weight += bad_luck
		if weight <= 0.0:
			continue
		ids.append(id)
		w.append(weight)
	return [ids, w]


static func pick(rng: RandomNumberGenerator, ids: Array[StringName], weights: PackedFloat32Array) -> StringName:
	if ids.is_empty():
		return &""
	var total: float = 0.0
	for x: float in weights:
		total += x
	var r: float = rng.randf() * total
	for i: int in ids.size():
		r -= weights[i]
		if r < 0.0:
			return ids[i]
	return ids[ids.size() - 1]


# Doll chance of the spin that follows `spins_done` spins at the current location.
static func doll_chance(pool: RelicBoxPool, spins_done: int, fire_sale: bool) -> float:
	var n: int = spins_done + 1
	if fire_sale or n <= pool.doll_free_uses:
		return 0.0
	return minf(pool.doll_base + pool.doll_step * float(n - pool.doll_free_uses - 1), pool.doll_max)


# One full roll: the doll (when the box can move) or a weighted item.
static func roll(
	rng: RandomNumberGenerator, pool: RelicBoxPool, elig: Array, spins_done: int, fire_sale: bool, can_move: bool = true
) -> StringName:
	if can_move and rng.randf() < doll_chance(pool, spins_done, fire_sale):
		return DOLL
	return pick(rng, elig[0], elig[1])


static func next_location(rng: RandomNumberGenerator, count: int, current: int) -> int:
	if count <= 1:
		return current
	var i: int = rng.randi_range(0, count - 2)
	return i + 1 if i >= current else i
