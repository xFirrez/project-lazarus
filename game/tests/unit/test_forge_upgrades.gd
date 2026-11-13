# AC-11.2 / AC-11.3: every conventional weapon has a Lazarus Forge upgrade (GAME_DESIGN §9.3,
# tests/data/upgrades_spec.json) with damage ×2 (splash ×2), the table's magazine / reserve, the
# upgraded name and camo, and its listed behavior change (checklist per weapon).
extends GutTest

const SPEC_PATH: String = "res://tests/data/upgrades_spec.json"
const WEAPONS_SPEC: String = "res://tests/data/weapons_spec.json"

var _spec: Dictionary = {}
var _weapons: Dictionary = {}


func before_all() -> void:
	_spec = JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))
	_weapons = JSON.parse_string(FileAccess.get_file_as_string(WEAPONS_SPEC))


func test_every_conventional_weapon_upgrades() -> void:
	for wid: String in _weapons["weapons"]:
		assert_true(WeaponCatalog.can_upgrade(StringName(wid)), "%s has a Forge upgrade" % wid)
		assert_true((_spec["upgrades"] as Dictionary).has(wid), "%s is in the §9.3 table" % wid)
	for wid: String in _spec["not_upgradable"]:
		assert_false(WeaponCatalog.can_upgrade(StringName(wid)), "%s is not upgradable" % wid)


func test_damage_magazine_and_identity() -> void:
	for wid: String in _spec["upgrades"]:
		var u: Dictionary = _spec["upgrades"][wid]
		var base: WeaponDefinition = WeaponCatalog.get_def(StringName(wid))
		var up: WeaponDefinition = WeaponCatalog.upgrade_of(StringName(wid))
		assert_not_null(up, "%s upgrade defined" % wid)
		if up == null:
			continue
		assert_eq(String(up.id), wid + "_up", "%s id" % wid)
		assert_eq(up.base_id, StringName(wid), "%s base id" % wid)
		assert_eq(WeaponCatalog.base_of(up.id), StringName(wid))
		assert_true(up.is_upgraded() and not base.is_upgraded(), "%s flagged upgraded" % wid)
		assert_eq(up.display_name, String(u["name"]), "%s name" % wid)
		assert_eq(up.camo, &"vesperite", "%s camo" % wid)
		assert_eq(up.damage, base.damage * 2.0, "%s damage x2" % wid)
		if base.splash_damage_centre > 0.0 and not (u["set"] as Dictionary).has("splash_damage_centre"):
			assert_eq(up.splash_damage_centre, base.splash_damage_centre * 2.0, "%s splash x2" % wid)
		assert_eq(up.mag_size, int(u["mag"]), "%s magazine" % wid)
		assert_eq(up.reserve_max, int(u["reserve"]), "%s reserve" % wid)
		assert_true(up.reserve_max >= base.reserve_max * 2 - 1, "%s reserve >= x2" % wid)
		var ratio: float = float(up.mag_size) / float(base.mag_size)
		if wid != "coachgun":  # two barrels stay two barrels
			assert_true(
				ratio >= 1.5 - 0.001 or up.mag_size >= base.mag_size + 1, "%s mag x1.5-2+ (%.2f)" % [wid, ratio]
			)
		assert_false(WeaponCatalog.can_upgrade(up.id), "%s cannot be upgraded twice" % wid)


func test_behavior_checklist() -> void:
	for wid: String in _spec["upgrades"]:
		var base: WeaponDefinition = WeaponCatalog.get_def(StringName(wid))
		var up: WeaponDefinition = WeaponCatalog.upgrade_of(StringName(wid))
		if up == null:
			continue
		for c: String in _spec["upgrades"][wid]["checks"]:
			assert_true(_check(c, base, up), "%s: %s" % [wid, c])


func _check(c: String, base: WeaponDefinition, up: WeaponDefinition) -> bool:
	var ok: bool = false
	match c:
		"dual_wield":
			ok = up.dual_wield and not base.dual_wield
		"explosive_rounds":
			ok = (
				(up.behavior == &"projectile" and up.splash_radius > 0.0)
				or (up.impact_splash == &"hit" and up.impact_splash_radius > 0.0 and up.impact_splash_damage > 0.0)
			)
		"explosive_headshots":
			ok = up.impact_splash == &"headshot" and up.impact_splash_damage > 0.0
		"headshot_kill_burst":
			ok = up.impact_splash == &"headshot_kill" and up.impact_splash_radius > 0.0
		"penetration>=4":
			ok = up.penetration >= 4
		"penetration+2":
			ok = up.penetration == base.penetration + 2
		"full_auto":
			ok = up.fire_mode == WeaponDefinition.FireMode.AUTO and base.fire_mode != WeaponDefinition.FireMode.AUTO
		"burst3":
			ok = up.fire_mode == WeaponDefinition.FireMode.BURST and up.burst_count == 3
		"tracer_color":
			ok = up.tracer_color.a > 0.0
		"burn":
			ok = up.burn_dps > 0.0 and up.burn_time > 0.0
		"rpm_x1.15":
			ok = is_equal_approx(up.rpm, base.rpm * 1.15)
		"alt_fire":
			var alt: WeaponDefinition = WeaponCatalog.get_def(up.alt_fire_id)
			ok = (
				alt != null and alt.attachment_of == up.id and alt.behavior == &"projectile" and alt.splash_radius > 0.0
			)
		"slow":
			ok = is_equal_approx(up.slow_factor, 0.2) and is_equal_approx(up.slow_time, 1.0)
		"pellets_x1.5":
			ok = up.pellets == int(base.pellets * 1.5)
		"faster_pump":
			ok = up.rpm > base.rpm
		"reduced_recoil":
			ok = up.recoil_scale < 1.0 and up.recoil_kick(0).length() < base.recoil_kick(0).length()
		"thermal_scope":
			ok = up.thermal_scope
		"cluster":
			ok = up.cluster_count > 0 and up.cluster_radius > 0.0
		"impact_detonation":
			ok = up.projectile_kind == &"rocket" and base.projectile_kind == &"grenade"
		"attracts":
			ok = up.attract_radius > 0.0 and up.projectile_kind == &"bolt" and up.fuse_time >= up.attract_time
	return ok


func test_attachment_hidden_from_upgrades() -> void:
	var gl: WeaponDefinition = WeaponCatalog.get_def(&"m16_up_gl")
	assert_not_null(gl)
	assert_true(gl.is_upgraded(), "attachment counts as upgraded (camo, not on walls)")
	assert_false(WeaponCatalog.can_upgrade(&"m16_up_gl"))


func test_box_pool_has_no_upgrades() -> void:
	var pool: RelicBoxPool = load("res://content/box/relic_box_pool.tres") as RelicBoxPool
	for id: StringName in pool.item_ids:
		var d: WeaponDefinition = WeaponCatalog.get_def(id)
		assert_true(d == null or not d.is_upgraded(), "%s in the box pool is not an upgrade" % id)


func test_forge_rules_numbers() -> void:
	assert_eq(ForgeSystem.COST, int(_spec["cost"]), "Forge 5000 (GAME_DESIGN §6.2)")
	assert_eq(WallBuy.UPGRADED_AMMO_COST, int(_spec["upgraded_wall_ammo"]), "upgraded wall ammo 4500")
	assert_eq(ForgeSystem.FORGE_TIME, 5.0)
	assert_eq(ForgeSystem.OFFER_TIME, 15.0)
	assert_eq(PointsRules.for_damage(DamageInfo.Kind.TRAP, WeaponDefinition.Hitzone.HEAD, true), 50, "trap kill 50")
	assert_eq(
		PointsRules.for_damage(DamageInfo.Kind.TRAP, WeaponDefinition.Hitzone.TORSO, false), 0, "no trap hit points"
	)


func test_trap_areas() -> void:
	var t1: TrapDefinition = Content.get_def(&"TrapDefinition", &"t1") as TrapDefinition
	var t3: TrapDefinition = Content.get_def(&"TrapDefinition", &"t3") as TrapDefinition
	assert_not_null(t1)
	assert_not_null(t3)
	var area: Transform3D = Transform3D(Basis.IDENTITY, Vector3(75, -2, -45))
	assert_true(t1.contains(area, Vector3(75, -2, -38)))
	assert_false(t1.contains(area, Vector3(75, -2, -36)), "15 m corridor ends at 7.5 m")
	assert_false(t1.contains(area, Vector3(78, -2, -45)), "4 m wide")
	assert_true(t1.sample_points(area, 2.5).size() >= 6)
	for def: TrapDefinition in [t1, t3]:
		assert_eq(def.cost, 1000)
		assert_eq(def.active_time, 25.0)
		assert_eq(def.cooldown, 60.0)
		assert_true(def.requires_power)
	var ring_area: Transform3D = Transform3D(Basis.IDENTITY, Vector3(28 + 22, -48, -50))
	assert_true(t3.contains(ring_area, Vector3(28 + 22, -48, -50)))
	assert_true(t3.contains(ring_area, Vector3(28 + 22 * cos(0.6), -48, -50 + 22 * sin(0.6))), "inside the 90° arc")
	assert_false(t3.contains(ring_area, Vector3(28 + 22 * cos(1.0), -48, -50 + 22 * sin(1.0))), "outside the arc")
	assert_false(t3.contains(ring_area, Vector3(28 + 10, -48, -50)), "inside the pit")
	# Player damage rule (GAME_DESIGN §12): ~1 s for 100 HP, ~2 s with Ironhide (250).
	assert_almost_eq(100.0 / t1.player_dps, 1.0, 0.15)
	assert_almost_eq(250.0 / t1.player_dps, 2.0, 0.4)
