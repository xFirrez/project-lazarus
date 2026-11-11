# AC-3.1: damage falloff, hitzone multipliers and penetration loss for all 4 weapons match their
# definitions; fire-rate timing (±1 ms averaged over 100 shots) in test_weapon_fire_rate.gd.
extends GutTest

const IDS: Array[StringName] = [&"m1911", &"mp40", &"model37", &"kar98k"]
const Z: Dictionary = {
	"head": WeaponDefinition.Hitzone.HEAD,
	"neck": WeaponDefinition.Hitzone.NECK,
	"torso": WeaponDefinition.Hitzone.TORSO,
	"limb": WeaponDefinition.Hitzone.LIMB,
}


func test_falloff_curve_per_weapon() -> void:
	for wid: StringName in IDS:
		var d: WeaponDefinition = WeaponCatalog.get_def(wid)
		assert_eq(DamageModel.falloff(d, 0.0), 1.0, "%s full damage at 0 m" % wid)
		assert_eq(DamageModel.falloff(d, d.range_min), 1.0, "%s full damage at range_min" % wid)
		var mid: float = (d.range_min + d.range_max) * 0.5
		assert_almost_eq(DamageModel.falloff(d, mid), lerpf(1.0, d.min_damage_fraction, 0.5), 0.0001, "%s mid" % wid)
		assert_eq(DamageModel.falloff(d, d.range_max), d.min_damage_fraction, "%s min at range_max" % wid)
		assert_eq(DamageModel.falloff(d, d.range_max * 3.0), d.min_damage_fraction, "%s clamps beyond" % wid)


func test_hitzone_multipliers_per_weapon() -> void:
	for wid: StringName in IDS:
		var d: WeaponDefinition = WeaponCatalog.get_def(wid)
		var close: float = d.range_min * 0.5
		assert_eq(DamageModel.bullet_damage(d, close, Z["head"], 0), d.damage * d.head_multiplier, "%s head" % wid)
		assert_eq(DamageModel.bullet_damage(d, close, Z["neck"], 0), d.damage * d.neck_multiplier, "%s neck" % wid)
		assert_eq(DamageModel.bullet_damage(d, close, Z["torso"], 0), d.damage, "%s torso" % wid)
		assert_eq(DamageModel.bullet_damage(d, close, Z["limb"], 0), d.damage * 0.75, "%s limb" % wid)


func test_design_examples() -> void:
	var m1911: WeaponDefinition = WeaponCatalog.get_def(&"m1911")
	assert_eq(DamageModel.bullet_damage(m1911, 5.0, Z["head"], 0), 120.0, "M1911 headshot ×3")
	var kar: WeaponDefinition = WeaponCatalog.get_def(&"kar98k")
	assert_eq(DamageModel.bullet_damage(kar, 20.0, Z["head"], 0), 2000.0, "Kar98k headshot ×5")
	var mp40: WeaponDefinition = WeaponCatalog.get_def(&"mp40")
	assert_almost_eq(DamageModel.bullet_damage(mp40, 40.0, Z["torso"], 0), 24.0, 0.001, "MP40 at 40 m = 60%")


func test_penetration_loss() -> void:
	for wid: StringName in IDS:
		var d: WeaponDefinition = WeaponCatalog.get_def(wid)
		for i: int in 5:
			var dmg: float = DamageModel.bullet_damage(d, 1.0, Z["torso"], i)
			if i < d.penetration:
				assert_almost_eq(dmg, d.damage * pow(0.75, i), 0.0001, "%s target %d loses 25%% each" % [wid, i])
			else:
				assert_eq(dmg, 0.0, "%s cannot reach target %d (penetration %d)" % [wid, i, d.penetration])


func test_splash_and_melee() -> void:
	var frag: WeaponDefinition = WeaponCatalog.get_def(&"frag")
	assert_eq(DamageModel.splash_damage(frag.splash_damage_centre, frag.splash_damage_edge, 5.0, 0.0), 1200.0)
	assert_eq(DamageModel.splash_damage(frag.splash_damage_centre, frag.splash_damage_edge, 5.0, 5.0), 250.0)
	assert_eq(DamageModel.splash_damage(frag.splash_damage_centre, frag.splash_damage_edge, 5.0, 5.1), 0.0)
	var knife: WeaponDefinition = WeaponCatalog.get_def(&"knife")
	assert_eq(DamageModel.melee_damage(knife), 150.0, "knife: headshots don't multiply")


func test_spread_direction_is_inside_cone_and_deterministic() -> void:
	var fwd: Vector3 = Vector3(0.3, -0.1, -1.0).normalized()
	for s: int in 200:
		var a: Vector3 = Ballistics.spread_direction(fwd, 3.0, Ballistics.make_rng(s))
		var b: Vector3 = Ballistics.spread_direction(fwd, 3.0, Ballistics.make_rng(s))
		assert_eq(a, b)
		assert_true(rad_to_deg(a.angle_to(fwd)) <= 3.0001, "inside the cone")
	assert_eq(Ballistics.spread_direction(fwd, 0.0, Ballistics.make_rng(1)), fwd)
