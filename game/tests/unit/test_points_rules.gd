# Points economy rules (GAME_DESIGN §6.1, §3.3): per-hit / per-kill points by zone and damage kind,
# repair cap per round, down / bleedout penalties rounded down to 10.
extends GutTest


func test_hit_and_kill_points() -> void:
	var b: int = DamageInfo.Kind.BULLET
	assert_eq(PointsRules.for_damage(b, WeaponDefinition.Hitzone.TORSO, false), 10, "non-lethal hit")
	assert_eq(PointsRules.for_damage(b, WeaponDefinition.Hitzone.HEAD, false), 10, "non-lethal head hit")
	assert_eq(PointsRules.for_damage(b, WeaponDefinition.Hitzone.TORSO, true), 60)
	assert_eq(PointsRules.for_damage(b, WeaponDefinition.Hitzone.LIMB, true), 60)
	assert_eq(PointsRules.for_damage(b, WeaponDefinition.Hitzone.NECK, true), 70)
	assert_eq(PointsRules.for_damage(b, WeaponDefinition.Hitzone.HEAD, true), 100)
	assert_eq(PointsRules.for_damage(DamageInfo.Kind.MELEE, WeaponDefinition.Hitzone.HEAD, true), 130)
	assert_eq(PointsRules.for_damage(DamageInfo.Kind.MELEE, WeaponDefinition.Hitzone.TORSO, false), 10)
	assert_eq(PointsRules.for_damage(DamageInfo.Kind.EXPLOSIVE, WeaponDefinition.Hitzone.TORSO, true), 50)
	assert_eq(PointsRules.for_damage(DamageInfo.Kind.EXPLOSIVE, WeaponDefinition.Hitzone.TORSO, false), 0)
	assert_eq(PointsRules.for_damage(DamageInfo.Kind.DEBUG, WeaponDefinition.Hitzone.HEAD, true), 0)


func test_repair_cap() -> void:
	var earned: int = 0
	for i: int in 60:
		earned += PointsRules.repair_points(earned)
	assert_eq(earned, 500, "max 500 per player per round")
	assert_eq(PointsRules.repair_points(0), 10)
	assert_eq(PointsRules.repair_points(495), 5)
	assert_eq(PointsRules.repair_points(500), 0)


func test_penalties() -> void:
	assert_eq(PointsRules.penalty(1000, PointsRules.DOWN_PENALTY), 50)
	assert_eq(PointsRules.penalty(1234, PointsRules.DOWN_PENALTY), 60, "61.7 -> 60")
	assert_eq(PointsRules.penalty(190, PointsRules.DOWN_PENALTY), 0, "9.5 -> 0")
	assert_eq(PointsRules.penalty(1900, PointsRules.BLEEDOUT_PENALTY), 190)
	assert_eq(PointsRules.penalty(0, PointsRules.BLEEDOUT_PENALTY), 0)
