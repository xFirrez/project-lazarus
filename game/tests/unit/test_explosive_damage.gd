# AC-9.3 (unit): splash falloff and self-damage of the projectile weapons match GAME_DESIGN §4.3 /
# §3.2 — centre damage at 0 m, linear to the edge value at the radius, nothing beyond; the owner
# takes at most 60.
extends GutTest


func test_splash_falloff() -> void:
	for wid: StringName in [&"law", &"china_lake", &"crossbow", &"tripmines", &"decoy"]:
		var d: WeaponDefinition = WeaponCatalog.get_def(wid)
		var r: float = d.splash_radius
		assert_eq(
			DamageModel.splash_damage(d.splash_damage_centre, d.splash_damage_edge, r, 0.0), d.splash_damage_centre
		)
		var mid: float = DamageModel.splash_damage(d.splash_damage_centre, d.splash_damage_edge, r, r * 0.5)
		assert_almost_eq(mid, (d.splash_damage_centre + d.splash_damage_edge) * 0.5, 0.01, "%s half radius" % wid)
		assert_eq(DamageModel.splash_damage(d.splash_damage_centre, d.splash_damage_edge, r, r + 0.01), 0.0)


func test_self_damage() -> void:
	var law: WeaponDefinition = WeaponCatalog.get_def(&"law")
	assert_eq(DamageModel.self_damage(law, 0.0), 60.0)
	assert_almost_eq(DamageModel.self_damage(law, 2.0), 30.0, 0.01)
	assert_eq(DamageModel.self_damage(law, 4.5), 0.0)
	var frag: WeaponDefinition = WeaponCatalog.get_def(&"frag")
	assert_eq(DamageModel.self_damage(frag, 0.0), 60.0)


func test_launch_is_deterministic() -> void:
	var cl: WeaponDefinition = WeaponCatalog.get_def(&"china_lake")
	var v1: Vector3 = ProjectileBehavior.launch_velocity(cl, Vector3(0, 0, -1))
	var v2: Vector3 = ProjectileBehavior.launch_velocity(cl, Vector3(0, 0, -2))
	assert_eq(v1, v2)
	assert_true(v1.y > 0.0, "grenade launcher lobs")
