# PowerUpDropper — the drop algorithm of GAME_DESIGN §11 as pure logic (host; unit-tested and
# simulated over 30 rounds, AC-10.3): every kill adds the points it earned to a counter; when the
# counter reaches the threshold a drop spawns at the kill (if the spot is valid) and the counter
# resets. The threshold starts at 600 and grows ×1.06 per drop (tuned in Step 10), the growth stopping after round
# 20; at most 4 drops per round; trap / Nuke kills never count. Types come from a shuffled bag
# (each once before repeats) with conditions: Fire Sale only after the box moved, Carpenter only
# with ≥ 5 planks missing, no Nuke before round 4.
# Authority: HOST (PowerUpSystem).
class_name PowerUpDropper
extends RefCounted

var rules: PowerUpRules = null
var counter: float = 0.0
var growth_steps: int = 0
var drops_total: int = 0
var drops_round: int = 0
var round_number: int = 0
var rate: float = 1.0  # debug `drop_rate`
var bag: Array[StringName] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_rules: PowerUpRules, seed_value: int = -1) -> void:
	rules = p_rules
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


static func counts(kind: int) -> bool:
	return kind != DamageInfo.Kind.TRAP and kind != DamageInfo.Kind.NUKE and kind != DamageInfo.Kind.DEBUG


func threshold() -> float:
	return rules.threshold_start * pow(rules.threshold_growth, growth_steps)


func new_round(r: int) -> void:
	round_number = r
	drops_round = 0


func add_points(points: int, kind: int) -> void:
	if counts(kind) and points > 0:
		counter += points * rate


# After add_points for a kill: should this kill drop (the caller then validates the spot)?
func wants_drop(kind: int) -> bool:
	return counts(kind) and drops_round < rules.max_per_round and counter >= threshold()


func commit_drop() -> void:
	counter = 0.0
	drops_round += 1
	drops_total += 1
	if round_number <= rules.growth_stop_round:
		growth_steps += 1


# ctx: {box_moved: bool, planks_missing: int, round: int}
func eligible(type: StringName, ctx: Dictionary) -> bool:
	match type:
		&"fire_sale":
			return bool(ctx.get("box_moved", false))
		&"carpenter":
			return int(ctx.get("planks_missing", 0)) >= rules.carpenter_min_missing
		&"nuke":
			return int(ctx.get("round", round_number)) >= rules.nuke_min_round
	return true


func next_type(ctx: Dictionary) -> StringName:
	if bag.is_empty():
		_refill()
	for i: int in bag.size():
		if eligible(bag[i], ctx):
			var t: StringName = bag[i]
			bag.remove_at(i)
			return t
	# Nothing left in this bag is allowed now: open the next bag (repeats are unavoidable).
	var start: int = bag.size()
	_refill()
	for i: int in range(start, bag.size()):
		if eligible(bag[i], ctx):
			var t2: StringName = bag[i]
			bag.remove_at(i)
			return t2
	return &"max_ammo"


func _refill() -> void:
	var fresh: Array[StringName] = rules.bag.duplicate()
	for i: int in range(fresh.size() - 1, 0, -1):  # Fisher-Yates with our rng (seedable)
		var j: int = rng.randi_range(0, i)
		var tmp: StringName = fresh[i]
		fresh[i] = fresh[j]
		fresh[j] = tmp
	bag.append_array(fresh)
