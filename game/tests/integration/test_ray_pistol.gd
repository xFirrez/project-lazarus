# AC-12.1 (integration): the Mk.I Ray Pistol on the gun range — a glowing plasma bolt with travel
# time at 55 m/s, a 1000 direct hit plus splash with falloff on the dummy, no bounce off walls; the
# Nova Mk.II bolt bounces once off a wall and explodes at its next contact.
extends GutTest

const Helper: GDScript = preload("res://tests/integration/player_test_helper.gd")
const W: GDScript = preload("res://tests/integration/weapon_test_helper.gd")


func _projectile(rig: W.Rig) -> Projectile:
	for p: Variant in rig.sync.projectiles.values():
		if is_instance_valid(p):
			return p as Projectile
	return null


func test_bolt_speed_direct_hit_and_splash() -> void:
	var rig: W.Rig = W.build(self, [&"ray_pistol"])
	await Helper.step(self, 30)
	var dummy: TargetDummy = rig.dummy("Dummy_20m")
	W.aim_at(rig, dummy.zone_position(WeaponDefinition.Hitzone.TORSO))
	var before: int = rig.sync.explosions
	assert_true(await W.fire_one(self, rig), "fired")
	await Helper.step(self, 2)
	var p: Projectile = _projectile(rig)
	assert_not_null(p, "bolt in flight (travel time, not hitscan)")
	if p != null:
		var d0: float = p.traveled
		var t0: float = p.age
		await Helper.step(self, 12)
		if is_instance_valid(p) and not p.is_done():
			var speed: float = (p.traveled - d0) / (p.age - t0)
			assert_almost_eq(speed, 55.0, 0.5, "55 m/s")
			assert_eq(p.def.projectile_kind, &"plasma")
	for i: int in 60:
		await Helper.step(self, 1)
		if rig.sync.explosions > before:
			break
	assert_eq(rig.sync.explosions, before + 1, "splash once")
	var hits: Array = dummy.damage_log.filter(func(e: Array) -> bool: return int(e[2]) == DamageInfo.Kind.EXPLOSIVE)
	assert_eq(hits.size(), 2, "direct + splash")
	if hits.size() == 2:
		assert_eq(float(hits[0][0]), 1000.0, "direct hit 1000")
		assert_between(float(hits[1][0]), 300.0, 1200.0, "splash between edge and centre")
		assert_gt(float(hits[1][0]), 900.0, "the target is at the blast centre")
	assert_eq(rig.controller().held().mag, 19)


func _wall_shot(weapon: StringName) -> Array:
	var rig: W.Rig = W.build(self, [weapon], "Mark_Walls")
	await Helper.step(self, 30)
	# The concrete wall at x 16..18.4: hit it at a slant so a bounce flies off sideways.
	W.aim_at(rig, Vector3(16.6, 0.7, -11.8))  # descending: after the bounce it meets the floor
	var before: int = rig.sync.explosions
	assert_true(await W.fire_one(self, rig))
	await Helper.step(self, 2)
	var p: Projectile = _projectile(rig)
	var bounces: int = 0
	for i: int in 120:
		await Helper.step(self, 1)
		if is_instance_valid(p):
			bounces = p.bounces
		if rig.sync.explosions > before:
			break
	return [bounces, rig.sync.explosions - before]


func test_mk1_explodes_on_the_wall() -> void:
	var r: Array = await _wall_shot(&"ray_pistol")
	assert_eq(int(r[0]), 0, "no bounce")
	assert_eq(int(r[1]), 1, "exploded")


func test_nova_bounces_once() -> void:
	var r: Array = await _wall_shot(&"ray_pistol_up")
	assert_eq(int(r[0]), 1, "Nova Mk.II bolt bounced once")
	assert_eq(int(r[1]), 1, "then exploded")
