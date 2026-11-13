# AC-3.3: a scripted bot fires each weapon at gun-range dummies; the recorded (host-applied)
# damage equals the expected value per hitzone; penetration damages exactly n dummies; thin wood
# passes bullets with the prop loss; knife lunge and frag splash damage the killable dummy.
extends GutTest

const Helper: GDScript = preload("res://tests/integration/player_test_helper.gd")
const W: GDScript = preload("res://tests/integration/weapon_test_helper.gd")
const ZONES: Array[int] = [
	WeaponDefinition.Hitzone.HEAD,
	WeaponDefinition.Hitzone.NECK,
	WeaponDefinition.Hitzone.TORSO,
	WeaponDefinition.Hitzone.LIMB
]


func test_hitscan_damage_per_hitzone() -> void:
	for wid: StringName in [&"m1911", &"mp40", &"kar98k"] as Array[StringName]:
		var rig: W.Rig = W.build(self, [wid])
		await Helper.step(self, 30)
		var dummy: TargetDummy = rig.dummy("Dummy_10m")
		var def: WeaponDefinition = WeaponCatalog.get_def(wid)
		for zone: int in ZONES:
			W.aim_at(rig, dummy.zone_position(zone))
			var n: int = dummy.damage_log.size()
			assert_true(await W.fire_one(self, rig), "%s fired" % wid)
			await Helper.step(self, 1)
			assert_eq(dummy.damage_log.size(), n + 1, "%s one hit on zone %d" % [wid, zone])
			if dummy.damage_log.size() == n + 1:
				var entry: Array = dummy.damage_log[n]
				var dist: float = rig.player.weapons.eye_position().distance_to(dummy.zone_position(zone))
				assert_eq(int(entry[1]), zone, "%s zone" % wid)
				assert_almost_eq(
					float(entry[0]),
					DamageModel.bullet_damage(def, dist, zone, 0),
					0.01,
					"%s zone %d damage" % [wid, zone]
				)
			# Wait out bolt / pump cycles before the next shot.
			await Helper.step(self, roundi(def.fire_interval() * 60.0) + 2)
		rig.root.queue_free()
		await Helper.step(self, 2)


func test_falloff_at_40m() -> void:
	var rig: W.Rig = W.build(self, [&"mp40"], "Mark_LaneA_40m")
	await Helper.step(self, 30)
	var dummy: TargetDummy = rig.dummy("Dummy_40m")
	W.aim_at(rig, dummy.zone_position(WeaponDefinition.Hitzone.TORSO))
	assert_true(await W.fire_one(self, rig))
	await Helper.step(self, 1)
	assert_eq(dummy.damage_log.size(), 1)
	assert_almost_eq(float(dummy.damage_log[0][0]), 40.0 * 0.6, 0.01, "MP40 at 40 m: 60% damage")


func test_shotgun_pellets_per_hitzone() -> void:
	var rig: W.Rig = W.build(self, [&"model37"], "Mark_LaneA_05m")
	await Helper.step(self, 30)
	var dummy: TargetDummy = rig.dummy("Dummy_05m")
	var def: WeaponDefinition = WeaponCatalog.get_def(&"model37")
	W.aim_at(rig, dummy.zone_position(WeaponDefinition.Hitzone.TORSO))
	assert_true(await W.fire_one(self, rig))
	await Helper.step(self, 1)
	assert_between(dummy.damage_log.size(), 4, 8, "most of the 8 pellets hit at 5 m")
	for entry: Array in dummy.damage_log:
		assert_almost_eq(
			float(entry[0]), def.damage * def.zone_multiplier(int(entry[1])), 0.01, "pellet zone %d" % entry[1]
		)


func test_penetration_counts() -> void:
	var expected: Dictionary = {&"kar98k": 4, &"mp40": 1, &"m1911": 1}
	for wid: StringName in expected:
		var rig: W.Rig = W.build(self, [wid], "Mark_Pen")
		await Helper.step(self, 30)
		W.aim_at(rig, rig.dummy("Pen_1").zone_position(WeaponDefinition.Hitzone.TORSO))
		assert_true(await W.fire_one(self, rig))
		await Helper.step(self, 1)
		var def: WeaponDefinition = WeaponCatalog.get_def(wid)
		var hit: int = 0
		for i: int in 4:
			var d: TargetDummy = rig.dummy("Pen_%d" % (i + 1))
			if d.damage_log.size() > 0:
				hit += 1
				assert_almost_eq(float(d.damage_log[0][0]), def.damage * pow(0.75, i), 0.01, "%s Pen_%d" % [wid, i + 1])
		assert_eq(hit, int(expected[wid]), "%s penetrates exactly %d dummies" % [wid, expected[wid]])
		rig.root.queue_free()
		await Helper.step(self, 2)


func test_thin_wood_wall_passes_with_loss() -> void:
	var rig: W.Rig = W.build(self, [&"m1911"], "Mark_Walls")
	rig.player.motor.teleport(Vector3(19, 0.05, -8))
	await Helper.step(self, 30)
	var dummy: TargetDummy = rig.dummy("Dummy_BehindWood")
	W.aim_at(rig, dummy.zone_position(WeaponDefinition.Hitzone.TORSO))
	assert_true(await W.fire_one(self, rig))
	await Helper.step(self, 1)
	assert_eq(dummy.damage_log.size(), 1, "bullet passed the wood wall")
	if dummy.damage_log.size() == 1:
		assert_almost_eq(float(dummy.damage_log[0][0]), 40.0 * Ballistics.PROP_PENETRATION_FACTOR, 0.01)


func test_knife_lunge_kills_150hp_dummy() -> void:
	var rig: W.Rig = W.build(self, [&"m1911"], "Mark_Kill")
	var dummy: TargetDummy = rig.dummy("Dummy_Kill")
	rig.player.motor.teleport(dummy.global_position + Vector3(0, 0.05, 2.3))
	await Helper.step(self, 30)
	W.aim_at(rig, dummy.zone_position(WeaponDefinition.Hitzone.TORSO))
	var start: Vector3 = rig.player.global_position
	rig.input["melee"] = true
	await Helper.step(self, 20)
	assert_false(dummy.alive, "one knife hit kills 150 HP")
	assert_eq(float(dummy.damage_log[0][0]) if not dummy.damage_log.is_empty() else 0.0, 150.0)
	assert_true(rig.player.global_position.distance_to(start) > 0.5, "lunged toward the target")
	await Helper.step(self, roundi(dummy.respawn_time * 60.0) + 10)
	assert_true(dummy.alive, "respawned")


func test_frag_splash_kills_dummy() -> void:
	var rig: W.Rig = W.build(self, [&"m1911"], "Mark_Kill")
	var dummy: TargetDummy = rig.dummy("Dummy_Kill")
	rig.player.motor.teleport(dummy.global_position + Vector3(0, 0.05, 4.0))
	await Helper.step(self, 30)
	W.aim_at(rig, dummy.global_position + Vector3(0, 0.6, 0))
	var frags: int = rig.controller().inventory.lethal_count
	rig.input["lethal"] = true
	await Helper.step(self, 180)  # cook 3 s: ~0.5 s of fuse left
	rig.input["lethal"] = false
	await Helper.step(self, 2)
	assert_eq(rig.controller().inventory.lethal_count, frags - 1)
	await Helper.step(self, 60)
	assert_false(dummy.alive, "frag splash killed the dummy")
	var explosive: bool = false
	for e: Array in dummy.damage_log:
		explosive = explosive or int(e[2]) == DamageInfo.Kind.EXPLOSIVE
	assert_true(explosive, "explosive damage recorded")


func test_cooked_frag_explodes_in_hand() -> void:
	var rig: W.Rig = W.build(self, [&"m1911"], "Mark_Kill")
	await Helper.step(self, 10)
	rig.input["lethal"] = true
	await Helper.step(self, roundi(3.6 * 60.0))
	assert_false(rig.controller().cooking(), "fuse ran out while cooking")
	assert_eq(rig.controller().inventory.lethal_count, 1)
	rig.input["lethal"] = false
	await Helper.step(self, 5)
