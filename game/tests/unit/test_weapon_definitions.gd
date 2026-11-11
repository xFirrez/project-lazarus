# Weapon data matches GAME_DESIGN §4 (roster table, damage model) — rule: numbers live in data.
extends GutTest

# id -> [damage, rpm, mag, reserve, head multiplier, penetration, pellets]
const SPEC: Dictionary = {
	&"m1911": [40.0, 400.0, 8, 32, 3.0, 1, 1],
	&"mp40": [40.0, 550.0, 32, 192, 4.0, 1, 1],
	&"model37": [130.0, 70.0, 6, 54, 1.5, 1, 8],
	&"kar98k": [400.0, 50.0, 5, 50, 5.0, 4, 1],
}


func test_roster_matches_design_table() -> void:
	for wid: StringName in SPEC:
		var d: WeaponDefinition = WeaponCatalog.get_def(wid)
		assert_not_null(d, "%s registered" % wid)
		if d == null:
			continue
		var s: Array = SPEC[wid]
		assert_eq(d.damage, s[0], "%s damage" % wid)
		assert_eq(d.rpm, s[1], "%s rpm" % wid)
		assert_eq(d.mag_size, s[2], "%s mag" % wid)
		assert_eq(d.reserve_max, s[3], "%s reserve" % wid)
		assert_eq(d.head_multiplier, s[4], "%s head multiplier" % wid)
		assert_eq(d.penetration, s[5], "%s penetration" % wid)
		assert_eq(d.pellets, s[6], "%s pellets" % wid)
		assert_eq(d.neck_multiplier >= 1.25, true, "%s neck multiplier" % wid)
		assert_eq(d.limb_multiplier, 0.75, "%s limb multiplier" % wid)
		assert_eq(d.penetration_loss, 0.25, "%s penetration loss" % wid)
		assert_true(d.range_max > d.range_min, "%s falloff range" % wid)
		assert_true(d.recoil_pattern != null and d.recoil_pattern.point_count > 0, "%s recoil pattern" % wid)


func test_knife_and_frag() -> void:
	var knife: WeaponDefinition = WeaponCatalog.get_def(&"knife")
	assert_eq(knife.damage, 150.0)
	assert_eq(knife.melee_time, 0.45)
	assert_eq(knife.melee_lunge, 1.5)
	assert_true(knife.is_melee())
	var frag: WeaponDefinition = WeaponCatalog.get_def(&"frag")
	assert_eq(frag.splash_radius, 5.0)
	assert_eq(frag.splash_damage_centre, 1200.0)
	assert_eq(frag.splash_damage_edge, 250.0)
	assert_eq(frag.fuse_time, 3.5)
	assert_eq(frag.carry_start, 2)
	assert_eq(frag.carry_max, 4)
	assert_eq(frag.self_damage_max, 60.0)


func test_every_weapon_sounds_distinct() -> void:
	var seen: Dictionary = {}
	for wid: StringName in SPEC:
		var d: WeaponDefinition = WeaponCatalog.get_def(wid)
		var key: String = "%.0f/%.0f/%.2f" % [d.sound_body_hz, d.sound_mech_hz, d.sound_tail_s]
		assert_false(seen.has(key), "%s has a distinct fire sound signature" % wid)
		seen[key] = true


func test_network_index_round_trips() -> void:
	for wid: StringName in WeaponCatalog.all_ids():
		assert_eq(WeaponCatalog.def_at(WeaponCatalog.index_of(wid)).id, wid)
