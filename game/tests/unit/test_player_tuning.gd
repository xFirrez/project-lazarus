# PlayerTuning defaults must match GAME_DESIGN §3.1 / §3.2 (rule: numbers live in data and the doc).
extends GutTest

const TUNING_PATH: String = "res://content/player/player_tuning.tres"


func test_design_values() -> void:
	var t: PlayerTuning = load(TUNING_PATH) as PlayerTuning
	assert_not_null(t)
	assert_eq(t.walk_speed, 4.6)
	assert_eq(t.sprint_speed, 6.6)
	assert_eq(t.crouch_speed, 2.4)
	assert_eq(t.ground_accel, 45.0)
	assert_eq(t.friction, 9.0)
	assert_eq(t.sprint_duration, 4.0)
	assert_eq(t.sprint_recharge_time, 3.0)
	assert_eq(t.sprint_recharge_delay, 0.8)
	assert_eq(t.stand_height, 1.8)
	assert_eq(t.crouch_height, 1.1)
	assert_eq(t.crouch_transition, 0.15)
	assert_eq(t.slide_duration, 0.7)
	assert_eq(t.slide_start_speed, 7.5)
	assert_eq(t.slide_cooldown, 1.0)
	assert_eq(t.jump_apex, 1.0)
	assert_eq(t.air_accel, 8.0)
	assert_eq(t.mantle_max_height, 1.2)
	assert_eq(t.step_height, 0.35)
	assert_eq(t.sprint_fov_kick, 5.0)
	assert_eq(t.max_health, 100.0)
	assert_eq(t.regen_delay, 3.0)
	assert_eq(t.regen_rate, 100.0)


func test_jump_velocity_reaches_apex() -> void:
	var t: PlayerTuning = PlayerTuning.new()
	var v: float = t.jump_velocity()
	assert_almost_eq(v * v / (2.0 * t.gravity), t.jump_apex, 0.0001)


func test_fall_damage_curve() -> void:
	var t: PlayerTuning = PlayerTuning.new()
	assert_eq(t.fall_damage(3.0), 0.0)
	assert_eq(t.fall_damage(5.0), 0.0, "none up to 5 m")
	assert_eq(t.fall_damage(7.5), 25.0)
	assert_eq(t.fall_damage(10.0), 50.0)
	assert_eq(t.fall_damage(40.0), 50.0, "capped: never lethal from full HP")


func test_validation_limits_above_legit_speeds() -> void:
	var t: PlayerTuning = PlayerTuning.new()
	assert_gt(t.validation_max_horizontal_speed, t.slide_start_speed + 2.5, "slide + moving platform headroom")
	assert_lt(t.validation_max_horizontal_speed, t.sprint_speed * 3.0 * 0.6, "3x speed hack is far over budget")


func test_tunable_names() -> void:
	var names: PackedStringArray = PlayerTuning.new().tunable_names()
	assert_true(names.has("walk_speed"))
	assert_true(names.has("bob_amplitude"))
	assert_false(names.has("id"))
