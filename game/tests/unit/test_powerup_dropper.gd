# AC-10.3: the power-up drop algorithm (GAME_DESIGN §11, PowerUpDropper) simulated over 30 rounds
# with the real RoundCurve zombie counts (solo and 4 players, 100 matches each): 2–4 drops per round
# on average in the early rounds (1–10), never more than 4 in a round, trap / Nuke kills never
# drop, and the bag rules (each type once before repeats; Fire Sale only after the box moved;
# Carpenter only with ≥ 5 planks missing; no Nuke on rounds 1–3).
extends GutTest

var rules: PowerUpRules = null
var curve: RoundCurve = null


func before_all() -> void:
	rules = load(PowerUpSystem.RULES_PATH) as PowerUpRules
	curve = load("res://content/rounds/default_round_curve.tres") as RoundCurve
	if curve == null:
		curve = RoundCurve.new()


# Points one kill earns: 10 per hit (more hits as zombie health grows) + the kill reward mix.
static func _kill_points(rng: RandomNumberGenerator, r: int) -> int:
	var hits: int = rng.randi_range(1, 3) + r / 6
	var kill: Array = [60, 60, 100, 130, 70]
	return hits * PointsRules.HIT + int(kill[rng.randi() % kill.size()])


func _simulate(players: int, matches: int) -> Array:
	var per_round: PackedFloat32Array = PackedFloat32Array()
	per_round.resize(31)
	var worst: int = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234 + players
	for m: int in matches:
		var d: PowerUpDropper = PowerUpDropper.new(rules, m)
		for r: int in range(1, 31):
			d.new_round(r)
			for k: int in curve.zombie_count(r, players):
				d.add_points(_kill_points(rng, r), DamageInfo.Kind.BULLET)
				if d.wants_drop(DamageInfo.Kind.BULLET):
					d.next_type({"box_moved": true, "planks_missing": 6, "round": r})
					d.commit_drop()
			per_round[r] += d.drops_round
			worst = maxi(worst, d.drops_round)
	for r: int in range(1, 31):
		per_round[r] /= matches
	return [per_round, worst]


func test_thirty_round_drop_rates() -> void:
	for players: int in [1, 4]:
		var res: Array = _simulate(players, 100)
		var pr: PackedFloat32Array = res[0]
		var early: float = 0.0
		for r: int in range(1, 11):
			early += pr[r]
		early /= 10.0
		var late: float = 0.0
		for r: int in range(11, 31):
			late += pr[r]
		late /= 20.0
		gut.p("%dp: early avg %.2f / round, rounds 11-30 avg %.2f, worst round %d" % [players, early, late, res[1]])
		assert_between(early, 2.0, 4.0, "%dp early rounds average 2-4 drops" % players)
		assert_lte(int(res[1]), rules.max_per_round, "%dp never more than 4 in a round" % players)


func test_trap_and_nuke_kills_never_drop() -> void:
	var d: PowerUpDropper = PowerUpDropper.new(rules, 1)
	d.new_round(5)
	for i: int in 500:
		d.add_points(200, DamageInfo.Kind.TRAP)
		d.add_points(200, DamageInfo.Kind.NUKE)
		assert_false(d.wants_drop(DamageInfo.Kind.TRAP))
	assert_eq(d.counter, 0.0, "trap / Nuke kills add nothing")
	d.add_points(int(d.threshold()), DamageInfo.Kind.BULLET)
	assert_true(d.wants_drop(DamageInfo.Kind.BULLET))
	assert_false(d.wants_drop(DamageInfo.Kind.TRAP), "a trap kill never spawns the pending drop")


func test_threshold_growth_stops_after_round_20() -> void:
	var d: PowerUpDropper = PowerUpDropper.new(rules, 2)
	d.new_round(1)
	assert_eq(d.threshold(), rules.threshold_start)
	d.commit_drop()
	assert_almost_eq(d.threshold(), rules.threshold_start * rules.threshold_growth, 0.01)
	d.new_round(21)
	var t: float = d.threshold()
	d.commit_drop()
	assert_almost_eq(d.threshold(), t, 0.01, "no growth after round 20")


func test_bag_each_once_before_repeats() -> void:
	var d: PowerUpDropper = PowerUpDropper.new(rules, 3)
	var ctx: Dictionary = {"box_moved": true, "planks_missing": 10, "round": 10}
	for bag: int in 20:
		var seen: Array = []
		for i: int in rules.bag.size():
			seen.append(d.next_type(ctx))
		seen.sort()
		var want: Array = rules.bag.duplicate()
		want.sort()
		assert_eq(seen, want, "bag %d holds each type once" % bag)


func test_bag_conditions() -> void:
	var d: PowerUpDropper = PowerUpDropper.new(rules, 4)
	var ctx: Dictionary = {"box_moved": false, "planks_missing": 2, "round": 2}
	for i: int in 300:
		var t: StringName = d.next_type(ctx)
		assert_ne(t, &"fire_sale", "no Fire Sale before the box moved")
		assert_ne(t, &"carpenter", "no Carpenter with < 5 planks missing")
		assert_ne(t, &"nuke", "no Nuke on rounds 1-3")
		assert_ne(t, &"free_upgrade", "Free Upgrade never comes from the bag")
	var d2: PowerUpDropper = PowerUpDropper.new(rules, 5)
	var ok: Dictionary = {"box_moved": true, "planks_missing": 5, "round": 4}
	var types: Dictionary = {}
	for i: int in 60:
		types[d2.next_type(ok)] = true
	for t2: StringName in rules.bag:
		assert_true(types.has(t2), "%s drops once allowed" % t2)


func test_max_four_per_round() -> void:
	var d: PowerUpDropper = PowerUpDropper.new(rules, 6)
	d.new_round(3)
	var n: int = 0
	for i: int in 1000:
		d.add_points(5000, DamageInfo.Kind.BULLET)
		if d.wants_drop(DamageInfo.Kind.BULLET):
			d.commit_drop()
			n += 1
	assert_eq(n, 4)
	d.new_round(4)
	d.add_points(1, DamageInfo.Kind.BULLET)
	assert_true(d.wants_drop(DamageInfo.Kind.BULLET), "the next round may drop again")
