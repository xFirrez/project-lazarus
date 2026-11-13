# AC-9.3: projectile weapons on the gun range — the LAW rocket's direct hit + splash, the China
# Lake grenade bouncing before it goes off, the crossbow bolt sticking to a target (direct hit,
# then the fused explosion) and to walls. Splash values follow the falloff formula.
extends GutTest

const Helper: GDScript = preload("res://tests/integration/player_test_helper.gd")
const W: GDScript = preload("res://tests/integration/weapon_test_helper.gd")


func _kinds(dummy: TargetDummy, kind: int) -> Array:
	var out: Array = []
	for e: Array in dummy.damage_log:
		if int(e[2]) == kind:
			out.append(e)
	return out


func _projectile(rig: W.Rig) -> Projectile:
	for p: Variant in rig.sync.projectiles.values():
		if is_instance_valid(p):
			return p as Projectile
	return null


func test_law_direct_hit_and_splash() -> void:
	var rig: W.Rig = W.build(self, [&"law"])
	await Helper.step(self, 30)
	var dummy: TargetDummy = rig.dummy("Dummy_10m")
	var def: WeaponDefinition = WeaponCatalog.get_def(&"law")
	W.aim_at(rig, dummy.zone_position(WeaponDefinition.Hitzone.TORSO))
	var before: int = rig.sync.explosions
	assert_true(await W.fire_one(self, rig), "LAW fired")
	await Helper.step(self, 40)
	assert_eq(rig.sync.explosions, before + 1, "rocket exploded once")
	var hits: Array = _kinds(dummy, DamageInfo.Kind.EXPLOSIVE)
	assert_eq(hits.size(), 2, "direct hit + splash")
	if hits.size() == 2:
		assert_eq(float(hits[0][0]), def.damage, "direct hit 1500")
		assert_true(float(hits[1][0]) > def.splash_damage_centre * 0.7, "splash near the centre")
		assert_true(float(hits[1][0]) <= def.splash_damage_centre, "splash <= centre damage")
	assert_eq(rig.controller().held().mag, 0, "single shot")


func test_china_lake_bounces_then_explodes() -> void:
	var rig: W.Rig = W.build(self, [&"china_lake"])
	await Helper.step(self, 30)
	var dummy: TargetDummy = rig.dummy("Dummy_20m")
	# Aim at the floor 6 m ahead: the grenade skips along toward the 20 m dummy.
	W.aim_at(rig, rig.player.global_position + Vector3(0, 0, -6))
	var before: int = rig.sync.explosions
	assert_true(await W.fire_one(self, rig))
	await Helper.step(self, 2)
	var p: Projectile = _projectile(rig)
	assert_not_null(p, "grenade in flight")
	var bounces: int = 0
	for i: int in 60 * 4:
		await Helper.step(self, 1)
		if is_instance_valid(p):
			bounces = p.bounces
		if rig.sync.explosions > before:
			break
	assert_true(bounces >= 1, "bounced off the floor (%d)" % bounces)
	assert_eq(rig.sync.explosions, before + 1, "exploded (zombie contact or fuse)")
	assert_true(dummy != null)


func test_crossbow_sticks_to_target_then_explodes() -> void:
	var rig: W.Rig = W.build(self, [&"crossbow"])
	await Helper.step(self, 30)
	var dummy: TargetDummy = rig.dummy("Dummy_10m")
	var def: WeaponDefinition = WeaponCatalog.get_def(&"crossbow")
	W.aim_at(rig, dummy.zone_position(WeaponDefinition.Hitzone.TORSO))
	var before: int = rig.sync.explosions
	assert_true(await W.fire_one(self, rig))
	await Helper.step(self, 20)
	var p: Projectile = _projectile(rig)
	assert_not_null(p, "bolt still there (fused)")
	if p != null:
		assert_true(p.stuck, "bolt stuck")
		assert_eq(p.stuck_target, dummy, "stuck to the dummy")
	var direct: Array = _kinds(dummy, DamageInfo.Kind.EXPLOSIVE)
	assert_eq(direct.size(), 1, "direct hit at impact")
	if not direct.is_empty():
		assert_eq(float(direct[0][0]), def.damage, "750 on impact")
	assert_eq(rig.sync.explosions, before, "not yet exploded")
	await Helper.step(self, roundi(def.fuse_time * 60.0) + 5)
	assert_eq(rig.sync.explosions, before + 1, "exploded after the 1.5 s fuse")
	assert_eq(_kinds(dummy, DamageInfo.Kind.EXPLOSIVE).size(), 2, "splash after the fuse")


func test_crossbow_sticks_to_walls() -> void:
	var rig: W.Rig = W.build(self, [&"crossbow"])
	await Helper.step(self, 30)
	W.aim_at(rig, rig.player.global_position + Vector3(0, 0.0, -3.0))  # into the floor
	assert_true(await W.fire_one(self, rig))
	await Helper.step(self, 15)
	var p: Projectile = _projectile(rig)
	assert_not_null(p)
	if p != null:
		assert_true(p.stuck, "stuck in the floor")
		assert_null(p.stuck_target, "not on a target")
		var at: Vector3 = p.global_position
		await Helper.step(self, 30)
		if is_instance_valid(p):
			assert_true(p.global_position.distance_to(at) < 0.01, "stays put")
