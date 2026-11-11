# AC-2.3: 10,000 frames of random input on the movement course (sprint, jump, crouch, slide,
# mantle attempts, turning) from ten start points; after every physics frame the player's capsule
# (shrunk by a small tolerance) must not overlap static geometry and must not fall through.
extends GutTest

const H: GDScript = preload("res://tests/integration/player_test_helper.gd")
const FRAMES: int = 10000
const SEGMENT: int = 1000
const TOLERANCE: float = 0.03
const STARTS: Array[Vector3] = [
	Vector3(0, 0.05, -1),
	Vector3(0, 0.05, -23.5),
	Vector3(0, 1.45, -34.0),
	Vector3(0, 0.05, -42.5),
	Vector3(0, 0.05, -52.5),
	Vector3(0, 0.05, -63.5),
	Vector3(0, 0.05, -72.0),
	Vector3(0, 0.05, -79.0),
	Vector3(0, 10.05, -96.0),
	Vector3(-10, 0.05, -27.0)
]


func test_no_tunneling_under_random_input() -> void:
	var course: Node3D = H.COURSE_SCENE.instantiate() as Node3D
	add_child_autofree(course)
	var player: PlayerCharacter = H.spawn_player(course, STARTS[0])
	player.health.invulnerable = true
	await H.step(self, 3)
	player.bot_driver = BotInputDriver.random_driver(20261111)
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var overlaps: int = 0
	var fell: int = 0
	var first_bad: String = ""
	var mantles: Array[int] = [0]
	var slides: Array[int] = [0]
	player.motor.mantle_started.connect(func(_h: float) -> void: mantles[0] += 1)
	player.motor.slide_started.connect(func() -> void: slides[0] += 1)
	for i: int in FRAMES:
		if i % SEGMENT == 0:
			player.motor.teleport(STARTS[(i / SEGMENT) % STARTS.size()])
			player.set_view(randf_range(-PI, PI), 0.0)
		await H.step(self, 1)
		var hit: String = _overlap(space, player)
		if hit != "":
			overlaps += 1
			if first_bad == "":
				first_bad = "frame %d: %s at %s stance %d" % [i, hit, str(player.global_position), player.motor.stance]
		if player.global_position.y < -1.0:
			fell += 1
			player.motor.teleport(STARTS[0])
	gut.p("random soak: mantles %d, slides %d" % [mantles[0], slides[0]])
	assert_eq(overlaps, 0, "frames intersecting static geometry (%s)" % first_bad)
	assert_eq(fell, 0, "fell through the world")
	assert_gt(slides[0], 0, "random input exercised slides")


func _overlap(space: PhysicsDirectSpaceState3D, player: PlayerCharacter) -> String:
	var src: CapsuleShape3D = player.collision.shape as CapsuleShape3D
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = src.radius - TOLERANCE
	cap.height = src.height - TOLERANCE * 2.0
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = player.collision.global_transform
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	for r: Dictionary in space.intersect_shape(q, 4):
		# Static geometry only: AnimatableBody3D platforms move before this check runs each frame,
		# so a rider legitimately reads up to one frame of platform motion as overlap.
		if r["collider"] is StaticBody3D and not r["collider"] is AnimatableBody3D:
			return String((r["collider"] as Node).name)
	return ""
