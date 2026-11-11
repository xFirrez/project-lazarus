# ZombieArchetype data matches GAME_DESIGN §5.1: health curve, tier speeds, attack numbers,
# barricade tear times; tier name parsing; voice priority (max 10 voiced, nearest wins).
extends GutTest


func _arch() -> ZombieArchetype:
	return Content.get_def(&"ZombieArchetype", &"zombie") as ZombieArchetype


func test_registered_with_three_variants() -> void:
	var a: ZombieArchetype = _arch()
	assert_not_null(a, "zombie archetype in the Content registry")
	assert_eq(a.variants.size(), 3, "orderly + pallid + frostbitten")


func test_health_curve() -> void:
	var a: ZombieArchetype = _arch()
	assert_eq(a.health_for_round(1), 150.0)
	assert_eq(a.health_for_round(2), 250.0)
	assert_eq(a.health_for_round(9), 950.0)
	assert_eq(a.health_for_round(10), roundf(950.0 * 1.1))
	assert_eq(a.health_for_round(11), roundf(950.0 * 1.1 * 1.1))
	var r54: float = 950.0 * pow(1.1, 45)
	assert_almost_eq(a.health_for_round(55), roundf(r54 * 1.05), r54 * 1e-6)


func test_speeds_attack_and_tear() -> void:
	var a: ZombieArchetype = _arch()
	assert_eq(
		Array(a.tier_speeds),
		[1.1, 1.7, 3.0, 4.3, 5.4].map(func(v: float) -> float: return float(PackedFloat32Array([v])[0]))
	)
	assert_eq(a.attack_damage, 50.0)
	assert_eq(a.attack_windup, 0.45)
	assert_eq(a.attack_range, 1.4)
	assert_eq(a.reach_for(ZombieArchetype.Tier.SPRINT), 2.0, "sprinter lunge")
	assert_eq(a.attack_cooldown, 1.1)
	assert_eq(a.crawler_speed, 1.0)
	assert_eq(a.tear_time_for(ZombieArchetype.Tier.WALK), 1.0)
	assert_eq(a.tear_time_for(ZombieArchetype.Tier.SPRINT), 0.8)


func test_tier_names() -> void:
	assert_eq(ZombieArchetype.tier_from_name("sprint"), ZombieArchetype.Tier.SPRINT)
	assert_eq(ZombieArchetype.tier_from_name("Jog"), ZombieArchetype.Tier.JOG)
	assert_eq(ZombieArchetype.tier_from_name("2"), ZombieArchetype.Tier.JOG)
	assert_eq(ZombieArchetype.tier_from_name("nope"), -1)


func test_voice_priority_max_10_nearest_wins() -> void:
	ZombieAudio.reset_voices()
	for i: int in 10:
		assert_true(ZombieAudio.request_voice(100 + i, 10.0 + i, 5.0), "voice %d" % i)
	assert_eq(ZombieAudio.active_voices(), 10)
	assert_false(ZombieAudio.request_voice(200, 50.0, 5.0), "far zombie denied when 10 are voiced")
	assert_true(ZombieAudio.request_voice(201, 2.0, 5.0), "near zombie steals the farthest voice")
	assert_eq(ZombieAudio.active_voices(), 10, "still capped at 10")
	ZombieAudio.reset_voices()
