# AC-2.4: damage -> regen timing (3.0 s delay, then 100 HP/s), downed at 0 HP, god mode.
extends GutTest

const DT: float = 1.0 / 60.0

var health: HealthComponent = null
var tuning: PlayerTuning = null


func before_each() -> void:
	tuning = PlayerTuning.new()
	health = HealthComponent.new()
	health.setup(tuning)
	autofree(health)


func _run(seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		health.tick(DT)


func test_no_regen_before_delay() -> void:
	health.apply_damage(50.0, Vector3.ZERO)
	_run(2.95)
	assert_eq(health.health, 50.0, "no regen during the 3.0 s delay")


func test_regen_rate_after_delay() -> void:
	health.apply_damage(60.0, Vector3.ZERO)
	_run(3.0)
	assert_almost_eq(health.health, 40.0, 2.0, "regen just starting at 3.0 s")
	_run(0.3)
	assert_almost_eq(health.health, 70.0, 2.0, "100 HP/s: +30 in 0.3 s")
	_run(0.5)
	assert_eq(health.health, 100.0, "capped at max")


func test_full_regen_time_from_one_hp() -> void:
	health.apply_damage(99.0, Vector3.ZERO)
	var t: float = 0.0
	while health.health < health.max_health and t < 10.0:
		health.tick(DT)
		t += DT
	assert_almost_eq(t, tuning.regen_delay + 99.0 / tuning.regen_rate, 0.05, "full after %.2f s" % t)


func test_new_damage_resets_delay() -> void:
	health.apply_damage(30.0, Vector3.ZERO)
	_run(2.5)
	health.apply_damage(10.0, Vector3.ZERO)
	_run(2.5)
	assert_eq(health.health, 60.0, "delay restarted by the second hit")


func test_two_swipes_down_without_regen() -> void:
	watch_signals(health)
	health.apply_damage(50.0, Vector3.ZERO, HealthComponent.DamageType.ZOMBIE)
	_run(1.0)
	health.apply_damage(50.0, Vector3.ZERO, HealthComponent.DamageType.ZOMBIE)
	assert_true(health.is_downed)
	assert_signal_emitted(health, "downed")
	_run(5.0)
	assert_eq(health.health, 0.0, "no regen while downed")
	health.restore_full()
	assert_eq(health.health, 100.0)
	assert_false(health.is_downed)


func test_damage_signal_carries_source_and_type() -> void:
	watch_signals(health)
	health.apply_damage(20.0, Vector3(1, 2, 3), HealthComponent.DamageType.EXPLOSIVE)
	assert_signal_emitted_with_parameters(
		health, "damaged", [20.0, Vector3(1, 2, 3), HealthComponent.DamageType.EXPLOSIVE]
	)


func test_invulnerable_and_overkill() -> void:
	health.invulnerable = true
	assert_eq(health.apply_damage(50.0, Vector3.ZERO), 0.0)
	health.invulnerable = false
	assert_eq(health.apply_damage(500.0, Vector3.ZERO), 100.0, "applied damage capped at remaining HP")


func test_low_health_threshold() -> void:
	health.apply_damage(49.0, Vector3.ZERO)
	assert_false(health.is_low())
	health.apply_damage(2.0, Vector3.ZERO)
	assert_true(health.is_low(), "below 50% triggers heartbeat/muffle")


func test_remote_mirror() -> void:
	watch_signals(health)
	health.apply_remote(70.0, 30.0, Vector3.ONE, HealthComponent.DamageType.ZOMBIE)
	assert_eq(health.health, 70.0)
	assert_signal_emitted(health, "damaged")
	_run(3.2)
	assert_gt(health.health, 70.0, "clients predict the same regen")
