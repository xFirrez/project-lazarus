# Step 16 balance guards (AC-16.4 numerics, scope 1 balance targets) over the shipped data via
# BalanceModel: weapon tier ordering, GAME_DESIGN §6.3 milestones solo (±2 rounds), co-op shared
# doors, and round-curve numerics far past round 60 (no overflow / NaN, caps hold).
extends GutTest

const Model: GDScript = preload("res://tests/balance/balance_model.gd")

var m: RefCounted = null


func before_all() -> void:
	m = Model.new()


func _within(ms: Dictionary, key: String, lo: int, hi: int) -> bool:
	return ms.has(key) and int(ms[key]) >= lo and int(ms[key]) <= hi


func test_weapon_tiers_are_ordered() -> void:
	var med: Dictionary = m.tier_medians()
	assert_gte(float(med["wall"]), 8.0, "wall-buys viable to mid rounds: %s" % med)
	assert_gt(float(med["box"]), float(med["wall"]), "box worth the gamble")
	assert_gte(float(med["box_up"]), float(med["box"]) + 5.0, "upgrades meaningful")
	assert_gte(float(med["wall_up"]), float(med["wall"]) + 5.0, "wall upgrades meaningful")
	assert_gt(float(med["wonder"]), float(med["box"]), "wonder weapons top tier")
	assert_gt(float(med["wonder_up"]), float(med["box_up"]), "upgraded wonder weapons top tier")


func test_every_upgrade_beats_its_base() -> void:
	var t: Dictionary = m.tier_table()
	for id: StringName in t:
		var row: Dictionary = t[id]
		if int(row["viable_up"]) > 0:
			assert_gte(int(row["viable_up"]), int(row["viable"]), "%s upgrade not weaker" % id)


func test_solo_economy_within_two_rounds_of_targets() -> void:
	var ms: Dictionary = m.simulate(1, 30)["milestones"]
	assert_true(_within(ms, "earned_4000", 3, 7), "4000 points by r5 ±2: %s" % ms)
	assert_true(_within(ms, "first_perk", 4, 10), "first perk r6-8 ±2: %s" % ms)
	assert_true(_within(ms, "power", 5, 12), "power r7-10 ±2: %s" % ms)
	assert_true(_within(ms, "forge_unlocked", 8, 16), "Forge r10-14 ±2: %s" % ms)
	assert_true(_within(ms, "first_upgrade", 10, 17), "first upgrade r12-15 ±2: %s" % ms)


func test_coop_shared_doors_reach_power_no_later() -> void:
	var solo: int = int(m.simulate(1, 30)["milestones"].get("power", 99))
	for p: int in [2, 3, 4]:
		var coop: int = int(m.simulate(p, 30)["milestones"].get("power", 99))
		assert_lte(coop, solo, "%d players reach power by r%d (solo r%d)" % [p, coop, solo])


func test_round_curve_numerics_to_round_200() -> void:
	var c: RoundCurve = m.curve
	var prev_hp: float = 0.0
	for r: int in range(1, 201):
		var h: float = m.hp(r)
		assert_true(is_finite(h) and h > prev_hp, "hp(%d) finite, increasing" % r)
		prev_hp = h
		for p: int in [1, 4]:
			var n: int = c.zombie_count(r, p)
			assert_true(n > 0 and n <= 300 + 75 * (p - 1), "count(%d, %d) capped" % [r, p])
			assert_gte(c.spawn_interval(r, p), 0.3 - 0.001)
		var w: PackedFloat32Array = c.tier_weights(r)
		var s: float = 0.0
		for x: float in w:
			s += x
		assert_almost_eq(s, 1.0, 0.001, "tier weights r%d" % r)
	# Late growth softens from round 55 (×1.05) and the Warden's 4p HP stays a sane 64-bit int.
	assert_almost_eq(m.hp(56) / m.hp(55), 1.05, 0.001)
	assert_lt(m.warden_health(200, 4), 9.0e15, "Warden HP fits comfortably in int64 / float")
	assert_true(is_finite(c.special_health(60, m.hp(200))))


func test_special_rounds_frequency() -> void:
	for seed_value: int in [1, 42, 777, 12345]:
		var sched: PackedInt32Array = m.special_rounds(seed_value, 50)
		assert_between(sched[0], 5, 7, "first special r5-7")
		for i: int in range(1, sched.size()):
			assert_between(sched[i] - sched[i - 1], 4, 6, "gap 4-6")
		assert_between(sched.size(), 8, 10, "8-10 special rounds to r50")
