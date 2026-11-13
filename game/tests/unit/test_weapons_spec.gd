# AC-9.1: every conventional weapon of GAME_DESIGN §4.3 (+ equipment) exists with stats matching
# the parsed spec table tests/data/weapons_spec.json.
extends GutTest

const SPEC_PATH: String = "res://tests/data/weapons_spec.json"
const FIRE_MODES: Dictionary = {"semi": 0, "pump": 0, "bolt": 0, "single": 0, "auto": 1, "burst": 2}

var _spec: Dictionary = {}


func before_all() -> void:
	_spec = JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))


func _class_index(name: String) -> int:
	return WeaponDefinition.WeaponClass.keys().find(name)


func test_roster_complete() -> void:
	assert_eq((_spec["weapons"] as Dictionary).size(), 23, "23 conventional weapons (GAME_DESIGN §4.3)")
	for wid: String in _spec["weapons"]:
		assert_not_null(WeaponCatalog.get_def(StringName(wid)), "%s defined" % wid)
	for wid: String in _spec["equipment"]:
		assert_not_null(WeaponCatalog.get_def(StringName(wid)), "%s defined" % wid)


func test_weapon_stats_match_spec() -> void:
	var heads: Dictionary = _spec["head_multiplier"]
	var pens: Dictionary = _spec["penetration"]
	for wid: String in _spec["weapons"]:
		var s: Dictionary = _spec["weapons"][wid]
		var d: WeaponDefinition = WeaponCatalog.get_def(StringName(wid))
		if d == null:
			continue
		var cls: String = String(s["class"])
		assert_eq(d.weapon_class, _class_index(cls), "%s class" % wid)
		assert_eq(d.damage, float(s["damage"]), "%s damage" % wid)
		if s.has("rpm"):
			assert_eq(d.rpm, float(s["rpm"]), "%s rpm" % wid)
		assert_eq(d.fire_mode, int(FIRE_MODES[s["fire"]]), "%s fire mode" % wid)
		if s.has("burst"):
			assert_eq(d.burst_count, int(s["burst"]), "%s burst" % wid)
		assert_eq(d.mag_size, int(s["mag"]), "%s mag" % wid)
		assert_eq(d.reserve_max, int(s["reserve"]), "%s reserve" % wid)
		assert_eq(d.pellets, int(s.get("pellets", 1)), "%s pellets" % wid)
		if String(s["source"]) == "wall":
			assert_eq(d.cost, int(s["cost"]), "%s wall price" % wid)
		if cls != "EXPLOSIVE":
			assert_eq(d.head_multiplier, float(heads.get(cls, heads["default"])), "%s head multiplier" % wid)
			assert_true(d.penetration >= int(pens[cls]), "%s penetration >= class default" % wid)
			assert_eq(d.limb_multiplier, 0.75, "%s limb multiplier" % wid)
			assert_true(d.range_max > d.range_min, "%s falloff" % wid)
		if s.has("splash"):
			assert_eq(d.behavior, &"projectile", "%s is a projectile weapon" % wid)
			assert_eq(d.splash_damage_centre, float(s["splash"][0]), "%s splash damage" % wid)
			assert_eq(d.splash_radius, float(s["splash"][1]), "%s splash radius" % wid)
			assert_eq(String(d.projectile_kind), String(s["projectile"]), "%s projectile kind" % wid)
			assert_eq(d.self_damage_max, 60.0, "%s self damage (GAME_DESIGN §3.2)" % wid)
			if s.has("fuse"):
				assert_eq(d.fuse_time, float(s["fuse"]), "%s fuse" % wid)
		assert_true(d.recoil_pattern != null and d.recoil_pattern.point_count > 0, "%s recoil pattern" % wid)


func test_equipment_matches_spec() -> void:
	for wid: String in _spec["equipment"]:
		var s: Dictionary = _spec["equipment"][wid]
		var d: WeaponDefinition = WeaponCatalog.get_def(StringName(wid))
		if d == null:
			continue
		assert_eq(d.weapon_class, _class_index(String(s["class"])), "%s class" % wid)
		assert_true(d.is_equipment(), "%s is equipment" % wid)
		if s.has("damage"):
			assert_eq(d.damage, float(s["damage"]), "%s damage" % wid)
		if s.has("melee_time"):
			assert_eq(d.melee_time, float(s["melee_time"]), "%s melee time" % wid)
		if s.has("splash"):
			assert_eq(d.splash_damage_centre, float(s["splash"][0]), "%s splash" % wid)
			assert_eq(d.splash_radius, float(s["splash"][1]), "%s radius" % wid)
		for key: String in ["carry_start", "carry_max", "place_limit", "attract_time", "attract_radius"]:
			if s.has(key):
				assert_eq(float(d.get(key)), float(s[key]), "%s %s" % [wid, key])
		if s.has("cost"):
			assert_eq(d.cost, int(s["cost"]), "%s price" % wid)


func test_every_weapon_sounds_distinct() -> void:
	var seen: Dictionary = {}
	for wid: String in _spec["weapons"]:
		var d: WeaponDefinition = WeaponCatalog.get_def(StringName(wid))
		if d == null:
			continue
		var key: String = "%.0f/%.0f/%.2f" % [d.sound_body_hz, d.sound_mech_hz, d.sound_tail_s]
		assert_false(seen.has(key), "%s has a distinct fire sound signature (shares with %s)" % [wid, seen.get(key)])
		seen[key] = wid


func test_box_pool_items_exist() -> void:
	var pool: RelicBoxPool = load(RelicBoxSystem.DEFAULT_POOL) as RelicBoxPool
	assert_eq(pool.item_ids.size(), pool.weights.size())
	for id: StringName in pool.item_ids:
		if pool.wonder_ids.has(id):
			continue  # wonder weapons arrive in Step 12
		assert_not_null(WeaponCatalog.get_def(id), "box item %s defined" % id)
