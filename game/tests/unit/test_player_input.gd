# Gamepad look shaping (deadzone + curve), damage-direction math and surface tags.
extends GutTest


func test_stick_deadzone() -> void:
	assert_eq(PlayerInputSource.shape_stick(Vector2(0.1, 0.0), 0.15, 2.0), Vector2.ZERO)
	assert_eq(PlayerInputSource.shape_stick(Vector2(0.0, -0.14), 0.15, 2.0), Vector2.ZERO)


func test_stick_curve() -> void:
	var full: Vector2 = PlayerInputSource.shape_stick(Vector2(1.0, 0.0), 0.15, 2.0)
	assert_almost_eq(full.x, 1.0, 0.0001, "full deflection = full speed")
	var half: Vector2 = PlayerInputSource.shape_stick(Vector2(0.575, 0.0), 0.15, 2.0)
	assert_almost_eq(half.x, 0.25, 0.001, "quadratic curve: half of the live range -> 25%")
	var diag: Vector2 = PlayerInputSource.shape_stick(Vector2(1.0, 1.0), 0.15, 2.0)
	assert_almost_eq(diag.length(), 1.0, 0.0001, "radial, clamped to 1")


func test_damage_relative_angle() -> void:
	var p: Vector3 = Vector3.ZERO
	assert_almost_eq(DamageHud.relative_angle(p, 0.0, Vector3(0, 0, -5)), 0.0, 0.001, "ahead")
	assert_almost_eq(DamageHud.relative_angle(p, 0.0, Vector3(-5, 0, 0)), PI / 2.0, 0.001, "left")
	assert_almost_eq(DamageHud.relative_angle(p, 0.0, Vector3(5, 0, 0)), -PI / 2.0, 0.001, "right")
	assert_almost_eq(absf(DamageHud.relative_angle(p, 0.0, Vector3(0, 0, 5))), PI, 0.001, "behind")
	# Turning left by 90° puts a source that was on the left straight ahead.
	assert_almost_eq(DamageHud.relative_angle(p, PI / 2.0, Vector3(-5, 0, 0)), 0.0, 0.001)


func test_surface_tags() -> void:
	var body: StaticBody3D = autofree(StaticBody3D.new())
	assert_eq(SurfaceTags.of(body), SurfaceTags.DEFAULT)
	body.physics_material_override = SurfaceTags.make_material(&"metal")
	assert_eq(SurfaceTags.of(body), &"metal")
	body.set_meta(&"surface", &"wood")
	assert_eq(SurfaceTags.of(body), &"wood", "metadata overrides the material")
	assert_eq(SurfaceTags.of(null), SurfaceTags.DEFAULT)


func test_footstep_events_registered() -> void:
	FootstepLibrary.ensure_registered()
	for surface: StringName in SurfaceTags.KNOWN:
		for kind: String in FootstepLibrary.KINDS:
			assert_true(Audio.has_event(FootstepLibrary.event_name(surface, kind)), "%s %s" % [surface, kind])
	assert_eq(FootstepLibrary.event_name(&"lava", "walk"), &"footstep_concrete_walk", "unknown -> default")


func test_input_frame_duplicate() -> void:
	var f: PlayerInputFrame = PlayerInputFrame.new()
	f.move = Vector2(0.5, -1)
	f.sprint = true
	f.crouch_pressed = true
	var g: PlayerInputFrame = f.duplicate_frame()
	assert_eq(g.move, f.move)
	assert_true(g.sprint and g.crouch_pressed)
