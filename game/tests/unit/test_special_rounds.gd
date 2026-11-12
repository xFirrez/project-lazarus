# AC-12.4 (rules): Galvanic special rounds — first on round 5-7, then every 4-6 rounds (checked over
# 50 rounds for 200 seeds); 6 x p on the first, +2 x p each after, capped at 24 x p; 400 HP first,
# x1.35 per special round, soft-capped at 0.6 x the base zombie's health; Vesper Peak's rules put
# Galvanics on exactly the scheduled rounds and mix them into normal rounds from 20.
extends GutTest

var curve: RoundCurve = null


func before_all() -> void:
	curve = load("res://content/rounds/default_round_curve.tres") as RoundCurve


func test_schedule_over_50_rounds() -> void:
	for s: int in 200:
		var sched: PackedInt32Array = curve.special_schedule(s, 50)
		assert_true(sched.size() >= 8, "seed %d: enough special rounds by 50 (%d)" % [s, sched.size()])
		assert_between(sched[0], 5, 7, "seed %d first" % s)
		for i: int in range(1, sched.size()):
			assert_between(sched[i] - sched[i - 1], 4, 6, "seed %d gap %d" % [s, i])
		assert_true(sched[sched.size() - 1] <= 50)
	assert_eq(curve.special_schedule(42, 50), curve.special_schedule(42, 50), "seeded: reproducible")


func test_counts() -> void:
	for p: int in [1, 2, 3, 4]:
		assert_eq(curve.special_count(0, p), 6 * p, "first, %dp" % p)
		assert_eq(curve.special_count(1, p), 8 * p)
		assert_eq(curve.special_count(3, p), 12 * p)
		assert_eq(curve.special_count(20, p), 24 * p, "capped at 24 x p")
	assert_eq(curve.special_alive_cap, 12)


func test_health_scaling() -> void:
	var base: ZombieArchetype = load("res://content/enemies/zombie/zombie.tres") as ZombieArchetype
	assert_eq(curve.special_health(0, base.health_for_round(6)), 400.0, "400 on the first")
	assert_eq(curve.special_health(1, base.health_for_round(11)), 540.0, "x1.35")
	assert_eq(curve.special_health(2, base.health_for_round(16)), roundf(400.0 * 1.35 * 1.35))
	var soft: float = curve.special_health(12, base.health_for_round(30))
	assert_eq(soft, roundf(base.health_for_round(30) * 0.6), "soft cap 0.6 x base hp")
	assert_eq(curve.special_health(0, 100.0), 400.0, "never below the first value")
	assert_eq(curve.special_intermission, 12.0)
	assert_eq(curve.special_warning, 8.0)
	assert_eq(curve.rift_telegraph, 1.5)


func test_galvanic_archetype() -> void:
	var g: ZombieArchetype = load("res://content/enemies/galvanic/galvanic.tres") as ZombieArchetype
	assert_eq(g.id, &"galvanic")
	assert_eq(g.speed_for(ZombieArchetype.Tier.SPRINT), 6.0, "sprint 6.0 m/s")
	assert_eq([g.leap_min, g.leap_max], [3.0, 6.0])
	assert_true(g.leap_telegraph >= 0.6, "0.6 s telegraph")
	assert_eq(g.leap_damage, 40.0)
	assert_eq([g.burst_radius, g.burst_damage], [3.0, 30.0])
	assert_true(g.trap_resistant and g.special)


func test_vesper_rules_follow_the_schedule() -> void:
	var def: MapDefinition = load("res://maps/vesper_peak/map_definition.tres") as MapDefinition
	var rules: MapRules = def.rules_script.new() as MapRules
	var m: Match = Match.new()
	m.definition = def
	m.session = MatchSession.new()
	m.session.flags["special_seed"] = 777
	rules.match_node = m
	var sched: PackedInt32Array = curve.special_schedule(777)
	for r: int in range(1, 51):
		var want: StringName = &"galvanic" if sched.has(r) else &""
		assert_eq(rules.get_special_round_enemy(r), want, "round %d" % r)
	assert_eq(rules.get_mixed_enemy(19), &"")
	assert_eq(rules.get_mixed_enemy(20), &"galvanic")
	assert_false(rules.warden_late_rounds_enabled(), "late-round Warden gated off until Step 14")
	m.session.free()
	m.free()
