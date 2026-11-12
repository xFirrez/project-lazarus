# RoundCurve matches GAME_DESIGN §5.1-5.2 (AC-6.1): zombie count for rounds 1-50 x 1-4 players
# (table-driven against an independent implementation of the formula + the GDD's worked numbers),
# zombie health by round (archetype), spawn interval, alive caps, tier mix by round.
extends GutTest

const CURVE: String = "res://content/rounds/default_round_curve.tres"


func _curve() -> RoundCurve:
	return load(CURVE) as RoundCurve


# Independent reference: N(r, p) = round(base_p * f(r)), capped (GAME_DESIGN §5.2).
static func _expected_count(r: int, p: int) -> int:
	var base_p: float = 24.0 + 6.0 * (p - 1)
	var early: Array[float] = [0.25, 0.33, 0.54, 0.75, 1.0]
	var f: float = early[r - 1] if r <= 5 else (r / 5.0) * (1.0 + 0.05 * maxi(0, r - 10))
	return mini(roundi(base_p * f), 300 + 75 * (p - 1))


static func _expected_interval(r: int, p: int) -> float:
	return maxf(2.0 * pow(0.95, r - 1), 0.35 if p == 1 else 0.3)


func test_counts_rounds_1_to_50_players_1_to_4() -> void:
	var c: RoundCurve = _curve()
	for p: int in range(1, 5):
		for r: int in range(1, 51):
			assert_eq(c.zombie_count(r, p), _expected_count(r, p), "N(%d, %d)" % [r, p])


func test_gdd_worked_numbers() -> void:
	var c: RoundCurve = _curve()
	var solo: Array[int] = []
	for r: int in range(1, 6):
		solo.append(c.zombie_count(r, 1))
	assert_eq(solo, [6, 8, 13, 18, 24] as Array[int], "solo rounds 1-5")
	assert_eq(c.zombie_count(10, 1), 48)
	assert_eq(c.zombie_count(20, 1), 144)
	assert_eq(c.zombie_count(30, 1), 288)
	# The GDD lists r15 = 75, but its own formula gives 24 * 3 * 1.25 = 90 (tuning log, Step 6).
	assert_eq(c.zombie_count(15, 1), 90)
	assert_eq(c.zombie_count(50, 1), 300, "solo cap")
	assert_eq(c.zombie_count(50, 4), 525, "4-player cap")
	assert_eq(c.zombie_count(1, 4), roundi(42 * 0.25))


func test_health_rounds_1_to_50() -> void:
	var a: ZombieArchetype = Content.get_def(&"ZombieArchetype", &"zombie") as ZombieArchetype
	var hp: float = 150.0
	for r: int in range(1, 51):
		if r >= 2 and r <= 9:
			hp += 100.0
		elif r >= 10:
			hp *= 1.1
		assert_almost_eq(a.health_for_round(r), roundf(hp), maxf(roundf(hp) * 1e-6, 1.0), "hp(%d)" % r)


func test_spawn_interval_and_caps() -> void:
	var c: RoundCurve = _curve()
	for p: int in range(1, 5):
		for r: int in range(1, 51):
			assert_almost_eq(c.spawn_interval(r, p), _expected_interval(r, p), 1e-5, "interval(%d, %d)" % [r, p])
	assert_eq([c.alive_cap(1), c.alive_cap(2), c.alive_cap(3), c.alive_cap(4)], [24, 28, 32, 32])
	assert_eq(c.intermission, 10.0)
	assert_eq(c.intro_delay, 5.0)


func test_tier_mix_follows_gdd_table() -> void:
	var c: RoundCurve = _curve()
	for r: int in range(1, 51):
		var w: PackedFloat32Array = c.tier_weights(r)
		var total: float = 0.0
		for x: float in w:
			total += x
		assert_almost_eq(total, 1.0, 1e-4, "weights sum to 1 at round %d" % r)
	assert_eq(c.tier_weights(1)[0], 1.0, "round 1 all shamble")
	assert_eq(c.tier_weights(3)[2], 0.0, "no jog before round 4")
	assert_almost_eq(c.tier_weights(4)[2], 0.25, 1e-4, "jog 25 % from round 4")
	assert_eq(c.tier_weights(6)[3], 0.0, "no run before round 7")
	assert_almost_eq(c.tier_weights(7)[3], 0.2, 1e-4, "run 20 % from round 7")
	assert_true(c.tier_weights(8)[2] > 0.5, "jog majority by 8")
	assert_eq(c.tier_weights(12)[4], 0.0, "no sprint before 13")
	assert_almost_eq(c.tier_weights(13)[4], 0.1, 1e-4, "sprint 10 % at 13")
	assert_almost_eq(c.tier_weights(20)[4], 0.5, 1e-4, "sprint 50 % by 20")
	assert_almost_eq(c.tier_weights(30)[4], 0.75, 1e-4, "sprint 75 % by 30")
	assert_eq(c.tier_weights(7)[0], 0.0, "shamble mixed only through round 6")
	assert_eq(c.pick_tier(1, 0.99), ZombieArchetype.Tier.SHAMBLE)
	assert_eq(c.pick_tier(30, 0.99), ZombieArchetype.Tier.SPRINT)
