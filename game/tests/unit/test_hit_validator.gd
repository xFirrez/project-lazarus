# AC-3.4 (logic): the host rejects hit claims beyond weapon range, faster than the RPM allows,
# on dead or unknown targets, for unowned weapons, with an empty mirrored magazine, duplicated
# sequence numbers, impossible penetration indices and ammo-increasing reload reports.
extends GutTest

var v: HitValidator = null
var mp40: WeaponDefinition = null
var knife: WeaponDefinition = null
var target: HitTarget = null


func before_each() -> void:
	v = HitValidator.new()
	mp40 = WeaponCatalog.get_def(&"mp40")
	knife = WeaponCatalog.get_def(&"knife")
	v.give(2, mp40)
	v.give(2, knife)
	target = HitTarget.new()
	target.max_health = 100.0
	add_child_autofree(target)
	target.position = Vector3(0, 0, -10)


func test_legit_full_auto_sequence_is_accepted() -> void:
	var t: float = 100.0
	var dt: float = 1.0 / 60.0
	var rt: WeaponRuntime = WeaponRuntime.new(mp40)
	rt.make_ready()
	var seq: int = 0
	var frame_t: float = t
	for i: int in 300:
		var shots: int = rt.update(dt, true, false, false)
		for s: int in shots:
			seq += 1
			# Arrival jitter: claims arrive 0-30 ms late.
			assert_eq(v.check_shot(2, mp40, seq, frame_t, frame_t + randf() * 0.03), HitValidator.Result.OK)
		frame_t += dt
		if rt.mag == 0:
			break
	assert_eq(v.rejection_count(), 0, "no false positives: %s" % v.last_rejection)
	assert_eq(int(v.ammo(2, &"mp40")[0]), 0, "mirrored magazine follows the shots")


func test_rate_hack_rejected() -> void:
	assert_eq(v.check_shot(2, mp40, 1, 10.0, 10.0), HitValidator.Result.OK)
	assert_eq(v.check_shot(2, mp40, 2, 10.02, 10.02), HitValidator.Result.RATE, "20 ms gap at 550 RPM")
	# Spacing stamps correctly but sending them all at once exhausts the arrival credit.
	var rejected: int = 0
	for i: int in 20:
		if v.check_shot(2, mp40, 3 + i, 10.2 + i * 0.11, 10.2) != HitValidator.Result.OK:
			rejected += 1
	assert_true(rejected >= 10, "bunched arrivals rejected (%d)" % rejected)


func test_future_stamp_rejected() -> void:
	assert_eq(v.check_shot(2, mp40, 1, 20.0, 10.0), HitValidator.Result.RATE)


func test_duplicate_and_unowned() -> void:
	assert_eq(v.check_shot(2, mp40, 5, 1.0, 1.0), HitValidator.Result.OK)
	assert_eq(v.check_shot(2, mp40, 5, 2.0, 2.0), HitValidator.Result.DUPLICATE)
	assert_eq(v.check_shot(2, WeaponCatalog.get_def(&"kar98k"), 6, 3.0, 3.0), HitValidator.Result.NOT_OWNED)
	assert_eq(v.check_shot(3, mp40, 1, 3.0, 3.0), HitValidator.Result.NOT_OWNED, "other peer")


func test_empty_mirrored_mag_rejected() -> void:
	v.give(2, mp40, 1, 0)
	assert_eq(v.check_shot(2, mp40, 1, 1.0, 1.0), HitValidator.Result.OK)
	assert_eq(v.check_shot(2, mp40, 2, 2.0, 2.0), HitValidator.Result.NO_AMMO)


func test_range_checks() -> void:
	var eye: Vector3 = Vector3(0, 1.6, 0)
	var zone: int = WeaponDefinition.Hitzone.TORSO
	assert_eq(v.check_hit(mp40, eye, target, zone, 10.0, 0, 0), HitValidator.Result.OK)
	assert_eq(v.check_hit(mp40, eye, target, zone, 500.0, 0, 0), HitValidator.Result.RANGE, "claimed distance")
	target.position = Vector3(0, 0, -150)
	assert_eq(v.check_hit(mp40, eye, target, zone, 10.0, 0, 0), HitValidator.Result.RANGE, "actual distance")
	target.position = Vector3(0, 0, -5)
	assert_eq(v.check_hit(knife, eye, target, zone, 5.0, 0, 0), HitValidator.Result.RANGE, "knife at 5 m")
	target.position = Vector3(0, 0, -2)
	assert_eq(v.check_hit(knife, eye, target, zone, 2.0, 0, 0), HitValidator.Result.OK, "knife lunge range")


func test_dead_unknown_and_bad_penetration() -> void:
	var eye: Vector3 = Vector3(0, 1.6, 0)
	var zone: int = WeaponDefinition.Hitzone.TORSO
	assert_eq(v.check_hit(mp40, eye, null, zone, 5.0, 0, 0), HitValidator.Result.UNKNOWN_TARGET)
	assert_eq(v.check_hit(mp40, eye, target, zone, 5.0, 1, 0), HitValidator.Result.BAD_DATA, "MP40 penetrates 1")
	assert_eq(v.check_hit(mp40, eye, target, 9, 5.0, 0, 0), HitValidator.Result.BAD_DATA, "zone")
	target.host_apply(DamageInfo.make(500.0, zone, DamageInfo.Kind.BULLET, &"mp40", 2))
	assert_false(target.alive)
	assert_eq(v.check_hit(mp40, eye, target, zone, 5.0, 0, 0), HitValidator.Result.DEAD_TARGET)


func test_reload_conservation() -> void:
	v.give(2, mp40, 10, 50)
	assert_true(v.check_reload(2, &"mp40", 32, 28), "10+50 -> 32+28")
	assert_false(v.check_reload(2, &"mp40", 32, 100), "ammo may not grow")
	assert_false(v.check_reload(2, &"kar98k", 5, 0), "unowned")


func test_infinite_ammo_flag() -> void:
	v.give(2, mp40, 0, 0)
	v.state_for(2).infinite_ammo = true
	assert_eq(v.check_shot(2, mp40, 1, 1.0, 1.0), HitValidator.Result.OK)
