# AC-12.1 / AC-12.2 (data): the Mk.I Ray Pistol and the Lazarus Conduit match GAME_DESIGN §7 — fire
# rate, magazine, projectile speed, direct / splash damage and radius, self-damage, chain jumps /
# range / falloff / stun, the pulse — their Forge upgrades "Nova Mk.II" (bounce once) and "Lazarus
# Requiem" follow the wonder_upgrades table, and both are rare Relic Box entries (§10.3).
extends GutTest

const SPEC_PATH: String = "res://tests/data/upgrades_spec.json"


func test_ray_pistol_spec() -> void:
	var d: WeaponDefinition = WeaponCatalog.get_def(&"ray_pistol")
	assert_not_null(d)
	assert_true(d.is_wonder(), "wonder class")
	assert_eq(d.behavior, &"projectile")
	assert_eq(d.projectile_kind, &"plasma")
	assert_eq(d.projectile_speed, 55.0, "55 m/s visible travel")
	assert_eq(d.projectile_gravity, 0.0)
	assert_eq(d.rpm, 180.0)
	assert_eq(d.fire_mode, WeaponDefinition.FireMode.SEMI)
	assert_eq([d.mag_size, d.reserve_max], [20, 160])
	assert_eq(d.damage, 1000.0, "direct hit")
	assert_eq([d.splash_damage_centre, d.splash_damage_edge, d.splash_radius], [1200.0, 300.0, 3.0])
	assert_eq(d.self_damage_max, 25.0)
	assert_eq(DamageModel.self_damage(d, 0.0), 25.0, "self-splash 25 at the centre")
	assert_almost_eq(DamageModel.self_damage(d, 1.5), 12.5, 0.01, "falls off")
	assert_eq(DamageModel.self_damage(d, 3.1), 0.0, "none outside the radius")
	assert_almost_eq(DamageModel.splash_damage(1200.0, 300.0, 3.0, 1.5), 750.0, 0.01)
	assert_eq(d.projectile_bounces, 0, "Mk.I does not bounce")
	assert_eq(d.death_fx, &"disintegrate")


func test_nova_upgrade() -> void:
	var u: WeaponDefinition = WeaponCatalog.upgrade_of(&"ray_pistol")
	assert_not_null(u)
	assert_eq(u.display_name, "Nova Mk.II")
	assert_eq([u.mag_size, u.reserve_max], [40, 200])
	assert_eq(u.damage, 1500.0)
	assert_eq(u.splash_damage_centre, 1800.0)
	assert_eq(u.splash_radius, 3.5)
	assert_eq(u.projectile_bounces, 1, "bolts bounce once")
	assert_true(u.projectile_color.r > 0.9 and u.projectile_color.g < 0.6, "red-orange plasma")
	assert_eq(u.camo, &"vesperite")
	assert_true(WeaponCatalog.can_upgrade(&"ray_pistol"))


func test_conduit_spec() -> void:
	var d: WeaponDefinition = WeaponCatalog.get_def(&"lazarus_conduit")
	assert_not_null(d)
	assert_true(d.is_wonder())
	assert_eq(d.behavior, &"chain")
	assert_eq(d.damage, 1200.0, "first target")
	assert_eq(d.max_range, 25.0)
	assert_eq(d.chain_cone_deg, 4.0)
	assert_eq(d.chain_jumps, 5, "up to 5 more")
	assert_eq(d.chain_jump_range, 6.0)
	assert_eq(d.chain_falloff, 0.75)
	assert_eq(d.stun_time, 1.5)
	assert_eq(d.rpm, 120.0)
	assert_eq([d.mag_size, d.reserve_max], [24, 96])
	var p: WeaponDefinition = WeaponCatalog.get_def(d.pulse_id)
	assert_not_null(p, "pulse definition")
	assert_eq(p.behavior, &"pulse")
	assert_eq(p.splash_radius, 8.0, "pulse stuns within 8 m")
	assert_eq(p.stun_time, 3.0)
	assert_eq(p.damage, 0.0, "no damage")
	assert_eq(d.pulse_hold_time, 1.0)
	assert_eq(d.pulse_ammo, 3)
	assert_eq(p.attachment_of, &"lazarus_conduit")
	assert_false(WeaponCatalog.can_upgrade(p.id), "the pulse is not a Forge item")


func test_requiem_upgrade() -> void:
	var u: WeaponDefinition = WeaponCatalog.upgrade_of(&"lazarus_conduit")
	assert_not_null(u)
	assert_eq(u.display_name, "Lazarus Requiem")
	assert_eq(u.chain_jumps, 10)
	assert_eq(u.chain_jump_range, 8.0)
	assert_eq(u.chain_full_jumps, 4, "no falloff for the first 4 jumps")
	assert_eq(u.stun_time, 2.5)
	assert_eq([u.mag_size, u.reserve_max], [36, 180])
	assert_eq(u.chain_kill_arcs, 2, "kills arc to 2 more")
	assert_eq(u.pulse_id, &"lazarus_conduit_pulse", "keeps the pulse")


func test_upgrade_table_matches() -> void:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))
	for wid: String in spec["wonder_upgrades"]:
		if wid == "doc":
			continue
		var u: Dictionary = spec["wonder_upgrades"][wid]
		var up: WeaponDefinition = WeaponCatalog.upgrade_of(StringName(wid))
		assert_not_null(up, wid)
		assert_eq(up.display_name, String(u["name"]))
		assert_eq(up.base_id, StringName(wid))
		assert_eq(up.mag_size, int(u["mag"]))


func test_box_rarity() -> void:
	var pool: RelicBoxPool = load(RelicBoxSystem.DEFAULT_POOL) as RelicBoxPool
	var ray: float = pool.weight_of(&"ray_pistol")
	var con: float = pool.weight_of(&"lazarus_conduit")
	assert_eq(ray, 1.5)
	assert_eq(con, 1.0)
	for id: StringName in pool.item_ids:
		if not pool.wonder_ids.has(id):
			assert_gt(pool.weight_of(id), ray, "%s is more common than the Ray Pistol" % id)
	assert_eq(pool.conditions.get(&"lazarus_conduit", ""), "conduit_built", "Conduit gated by its first build")
