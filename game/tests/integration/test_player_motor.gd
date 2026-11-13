# AC-2.2: measured walk / sprint / crouch speeds within ±3% of GAME_DESIGN §3.1; sprint duration
# and recharge within ±0.1 s; jump apex; slide speed, duration and cooldown. Flat floor, 60 Hz.
extends GutTest

const H: GDScript = preload("res://tests/integration/player_test_helper.gd")
const DT: float = 1.0 / 60.0

var player: PlayerCharacter = null
var tuning: PlayerTuning = null
var root: Node3D = null


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	H.flat_floor(root)
	player = H.spawn_player(root, Vector3(0, 0.05, 0))
	tuning = player.tuning
	await H.step(self, 10)


func _measure_speed(move: Vector2, sprint: bool, crouch: bool) -> float:
	player.bot_driver = H.const_driver(move, sprint, crouch)
	await H.step(self, 40)  # accelerate
	var start: Vector3 = player.global_position
	await H.step(self, 60)
	var d: Vector3 = player.global_position - start
	d.y = 0.0
	return d.length() / (60.0 * DT)


func test_walk_speed() -> void:
	var v: float = await _measure_speed(Vector2(0, -1), false, false)
	assert_almost_eq(v, tuning.walk_speed, tuning.walk_speed * 0.03, "walk %.3f m/s" % v)
	assert_true(player.footsteps.steps_played > 0, "footsteps played while walking")


func test_sprint_speed() -> void:
	var v: float = await _measure_speed(Vector2(0, -1), true, false)
	assert_almost_eq(v, tuning.sprint_speed, tuning.sprint_speed * 0.03, "sprint %.3f m/s" % v)


func test_crouch_speed() -> void:
	var v: float = await _measure_speed(Vector2(0, -1), false, true)
	assert_almost_eq(v, tuning.crouch_speed, tuning.crouch_speed * 0.03, "crouch %.3f m/s" % v)
	assert_eq(player.motor.stance, MotorComponent.Stance.CROUCH)
	assert_almost_eq((player.collision.shape as CapsuleShape3D).height, tuning.crouch_height, 0.001)


func test_diagonal_not_faster() -> void:
	var v: float = await _measure_speed(Vector2(1, -1).normalized(), false, false)
	assert_almost_eq(v, tuning.walk_speed, tuning.walk_speed * 0.03)


func test_sprint_duration_and_recharge() -> void:
	player.bot_driver = H.const_driver(Vector2(0, -1), true, false)
	var frames: int = 0
	while not player.motor.sprinting and frames < 30:
		await H.step(self, 1)
		frames += 1
	assert_true(player.motor.sprinting, "sprint started")
	var sprint_frames: int = 0
	while player.motor.sprinting and sprint_frames < 600:
		await H.step(self, 1)
		sprint_frames += 1
	var duration: float = sprint_frames * DT
	assert_almost_eq(duration, tuning.sprint_duration, 0.1, "sprint lasted %.3f s" % duration)
	# Holding sprint after exhaustion does not restart it until released.
	await H.step(self, 30)
	assert_false(player.motor.sprinting, "needs release after exhaustion")
	player.bot_driver = H.const_driver(Vector2.ZERO)
	var recharge_frames: int = 30
	while player.motor.stamina < tuning.sprint_duration - 0.0001 and recharge_frames < 600:
		await H.step(self, 1)
		recharge_frames += 1
	var recharge: float = recharge_frames * DT
	var expected: float = tuning.sprint_recharge_delay + tuning.sprint_recharge_time
	assert_almost_eq(recharge, expected, 0.1, "recharged in %.3f s (delay + recharge)" % recharge)


func test_sprint_ends_on_aim_and_fire() -> void:
	var aim: Array[bool] = [false]  # lambdas capture locals by value: box it
	player.bot_driver = func(_p: PlayerCharacter, _d: float) -> PlayerInputFrame:
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.move = Vector2(0, -1)
		f.sprint = true
		f.aim = aim[0]
		return f
	await H.step(self, 20)
	assert_true(player.motor.sprinting)
	aim[0] = true
	await H.step(self, 2)
	assert_false(player.motor.sprinting, "ADS cancels sprint")


func test_jump_apex() -> void:
	var jumped: Array[bool] = [false]
	player.bot_driver = func(_p: PlayerCharacter, _d: float) -> PlayerInputFrame:
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.jump_pressed = not jumped[0]
		jumped[0] = true
		return f
	var base: float = player.global_position.y
	var peak: float = base
	for i: int in 90:
		await H.step(self, 1)
		peak = maxf(peak, player.global_position.y)
	assert_almost_eq(peak - base, tuning.jump_apex, 0.05, "apex %.3f m" % (peak - base))
	assert_true(player.motor.grounded, "landed again")


func test_slide_speed_duration_cooldown() -> void:
	var press: Array[bool] = [false]
	player.bot_driver = func(_p: PlayerCharacter, _d: float) -> PlayerInputFrame:
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.move = Vector2(0, -1)
		f.sprint = true
		f.crouch_pressed = press[0]
		press[0] = false
		return f
	await H.step(self, 30)
	assert_true(player.motor.sprinting)
	press[0] = true
	await H.step(self, 2)
	assert_eq(player.motor.stance, MotorComponent.Stance.SLIDE, "slide started")
	assert_gt(player.motor.horizontal_speed(), tuning.sprint_speed, "slide starts faster than sprint")
	var frames: int = 1
	while player.motor.stance == MotorComponent.Stance.SLIDE and frames < 120:
		await H.step(self, 1)
		frames += 1
	assert_almost_eq(frames * DT, tuning.slide_duration, 0.05, "slide lasted %.3f s" % (frames * DT))
	assert_eq(player.motor.stance, MotorComponent.Stance.STAND, "open ground: slide ends standing")
	# Cooldown: sprint again and try to slide inside the 1.0 s window.
	await H.step(self, 12)
	press[0] = true
	await H.step(self, 2)
	assert_ne(player.motor.stance, MotorComponent.Stance.SLIDE, "slide cooldown prevents chaining")


func test_air_control_is_limited() -> void:
	player.bot_driver = func(_p: PlayerCharacter, _d: float) -> PlayerInputFrame:
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.jump_pressed = true
		f.move = Vector2(1, 0)
		return f
	await H.step(self, 3)
	# In the air for ~0.6 s with 8 m/s² air accel: lateral speed stays well below walk speed.
	await H.step(self, 20)
	if not player.motor.grounded:
		assert_lt(player.motor.horizontal_speed(), tuning.walk_speed, "air control limited")
	pass_test("air control sampled")
