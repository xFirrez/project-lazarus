# AC-2.1 (solo part), AC-2.6 and traversal checks on maps/_test/movement_course.tscn:
# the bot walks every waypoint (stairs, ramps, mantles, 0.8 m gap, door, slide tunnel, elevator,
# 5 m drops); a 1.5 m ledge cannot be mantled; no standing up under a 1.5 m ceiling; the slide
# ends in a crouch under the tunnel ceiling; moving platforms carry the player.
extends GutTest

const H: GDScript = preload("res://tests/integration/player_test_helper.gd")

var course: Node3D = null
var player: PlayerCharacter = null


func before_each() -> void:
	course = H.COURSE_SCENE.instantiate() as Node3D
	add_child_autofree(course)


func _spawn(pos: Vector3, yaw: float = 0.0) -> void:
	player = H.spawn_player(course, pos, yaw)
	await H.step(self, 5)


# Every spawn point: approach angles differ, which once exposed a stair-step edge case.
func test_bot_completes_course(p: Array = use_parameters([[0], [1], [2], [3]])) -> void:
	var spawn: Node3D = H.find_marker(course, "PlayerSpawn%d" % int(p[0]))
	await _spawn(spawn.global_position)
	var bot: BotInputDriver = BotInputDriver.from_markers(get_tree().get_nodes_in_group(&"course_waypoint"))
	assert_gt(bot.waypoints.size(), 15, "course has waypoints")
	player.bot_driver = bot.as_callable()
	var frames: int = 0
	var mantles: Array[int] = [0]
	var slides: Array[int] = [0]
	player.motor.mantle_started.connect(func(_h: float) -> void: mantles[0] += 1)
	player.motor.slide_started.connect(func() -> void: slides[0] += 1)
	while not bot.finished and not bot.failed and frames < 60 * 150:
		await H.step(self, 1)
		frames += 1
	assert_false(bot.failed, bot.fail_reason)
	assert_true(
		bot.finished,
		"finished all %d waypoints in %.1f s (reached %d)" % [bot.waypoints.size(), frames / 60.0, bot.index]
	)
	assert_eq(mantles[0], 2, "mantled the 1.0 m and 1.2 m ledges")
	assert_eq(slides[0], 1, "slid into the tunnel")
	assert_eq(player.health.health, player.health.max_health, "5 m drops deal no damage")
	gut.p("course time %.1f s; waypoint times: %s" % [frames / 60.0, str(bot.reached_times)])


func test_cannot_mantle_1_5m_ledge() -> void:
	var approach: Node3D = H.find_marker(course, "Ledge_1_5m_Approach")
	await _spawn(approach.global_position + Vector3(0, 0.05, 0))
	player.bot_driver = func(_p: PlayerCharacter, _d: float) -> PlayerInputFrame:
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.move = Vector2(0, -1)
		f.jump_pressed = true
		f.jump_held = true
		return f
	var max_y: float = 0.0
	for i: int in 180:
		await H.step(self, 1)
		max_y = maxf(max_y, player.global_position.y)
	assert_lt(player.global_position.y, 0.5, "still on the ground in front of the 1.5 m ledge")
	assert_lt(max_y, 1.45, "never got on top (max feet y %.2f)" % max_y)


func test_mantle_1_2m_ledge() -> void:
	await _spawn(Vector3(0, 0.05, -57.5))
	player.bot_driver = H.const_driver(Vector2(0, -1))  # just walk into it: auto-mantle
	var mantled: Array[float] = [-1.0]
	player.motor.mantle_started.connect(func(h: float) -> void: mantled[0] = h)
	var on_top: bool = false
	for i: int in 120:
		await H.step(self, 1)
		if player.motor.grounded and absf(player.global_position.y - 1.2) < 0.05:
			on_top = true
			break
	assert_almost_eq(mantled[0], 1.2, 0.03, "mantle height")
	assert_true(on_top, "stood on the 1.2 m ledge")


func test_cannot_stand_under_1_5m_ceiling() -> void:
	await _spawn(Vector3(-10, 0.05, -26.5))  # facing -Z, toward the low ceiling
	var crouch: Array[bool] = [true]
	var move: Array[Vector2] = [Vector2(0, -1)]
	player.bot_driver = func(_p: PlayerCharacter, _d: float) -> PlayerInputFrame:
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.crouch = crouch[0]
		f.move = move[0]
		return f
	for i: int in 70:  # crouch-walk ~2.7 m under the slab
		await H.step(self, 1)
	move[0] = Vector2.ZERO
	crouch[0] = false
	await H.step(self, 30)
	assert_lt(player.global_position.z, -28.2, "under the slab (z %.2f)" % player.global_position.z)
	assert_eq(player.motor.stance, MotorComponent.Stance.CROUCH, "stays crouched under a 1.5 m ceiling")
	assert_false(player.motor.can_stand())
	# Walk back out: stands up automatically once clear.
	await _turn_and_walk_out()
	assert_eq(player.motor.stance, MotorComponent.Stance.STAND, "stands once clear")


func _turn_and_walk_out() -> void:
	player.bot_driver = H.const_driver(Vector2(0, 1))  # walk backwards (+Z) out from under it
	for i: int in 90:
		await H.step(self, 1)


func test_slide_ends_in_crouch_under_tunnel() -> void:
	await _spawn(Vector3(0, 0.05, -71.5))
	var state: Dictionary = {"pressed": false}
	player.bot_driver = func(p: PlayerCharacter, _d: float) -> PlayerInputFrame:
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.move = Vector2(0, -1)
		f.sprint = true
		if not bool(state["pressed"]) and p.global_position.z < -76.4:
			f.crouch_pressed = true
			state["pressed"] = true
		return f
	var slid: Array[bool] = [false]
	var ended_stance: Array[int] = [-1]
	var ended_z: Array[float] = [0.0]
	player.motor.slide_started.connect(func() -> void: slid[0] = true)
	player.motor.slide_ended.connect(
		func() -> void:
			ended_stance[0] = int(player.motor.stance)
			ended_z[0] = player.global_position.z
	)
	for i: int in 150:
		await H.step(self, 1)
		if ended_stance[0] >= 0 and i % 10 == 0 and player.global_position.z < -83.5:
			break
	assert_true(slid[0], "slide started")
	assert_eq(ended_stance[0], int(MotorComponent.Stance.CROUCH), "slide ended in a crouch (z %.2f)" % ended_z[0])
	assert_between(ended_z[0], -83.0, -77.0, "slide ended inside the tunnel")
	for i: int in 120:
		if player.global_position.z < -84.5:
			break
		await H.step(self, 1)
	await H.step(self, 5)
	assert_eq(player.motor.stance, MotorComponent.Stance.STAND, "stood up after leaving the tunnel")


func test_shuttle_carries_player() -> void:
	var shuttle: Node3D = course.find_child("Shuttle", true, false) as Node3D
	await _spawn(shuttle.global_position + Vector3(0, 0.3, 0))
	player.bot_driver = H.const_driver(Vector2.ZERO)
	await H.step(self, 10)
	var p0: Vector3 = player.global_position
	var s0: Vector3 = shuttle.global_position
	await H.step(self, 90)
	var moved_platform: float = shuttle.global_position.x - s0.x
	var moved_player: float = player.global_position.x - p0.x
	assert_gt(absf(moved_platform), 0.5, "shuttle moved")
	assert_almost_eq(moved_player, moved_platform, 0.15, "player carried by the shuttle")
	assert_true(player.motor.grounded, "still standing on it")
