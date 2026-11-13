# Visual check (Step 5): renders zombies on the nav torture map for review and composition
# regression: (1) a posed line-up with AI frozen — walk cycle, attack wind-up, crawler, head look
# toward the camera, head gib, ragdoll death; (2) a surround shot: 14 zombies pursuing the
# stationary player (they should fan out in rings, not conga-line); (3) a window being torn.
# Frames go to --autotest-shots (docs/screenshots). Run by tools/visual_tests.sh.
extends "res://tests/net/autotest_base.gd"

var _out: String = ""


func _ready() -> void:
	timeout = 90.0
	_out = CommandLine.get_value("autotest-shots", "user://screenshots")
	DirAccess.make_dir_recursive_absolute(_out)
	EventBus.match_started.connect(func(_m: StringName) -> void: _run.call_deferred())


func _frames(n: int) -> void:
	for i: int in n:
		await RenderingServer.frame_post_draw


func _shot(file: String) -> Image:
	await _frames(2)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(file))
	return img


static func _variance(img: Image) -> float:
	var sum: float = 0.0
	var sq: float = 0.0
	var n: int = 0
	for y: int in range(0, img.get_height(), 8):
		for x: int in range(0, img.get_width(), 8):
			var l: float = img.get_pixel(x, y).get_luminance()
			sum += l
			sq += l * l
			n += 1
	var m: float = sum / n
	return sq / n - m * m


func _hide_hud() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"hide_for_shots"):
		n.set(&"visible", false)
	if is_instance_valid(Debug.overlay):
		Debug.overlay.visible = false


func _run() -> void:
	await _frames(10)
	var zs: ZombieSync = Match.current.zombies
	while not zs.crowd.is_ready():
		await get_tree().physics_frame
	var me: PlayerCharacter = sync().local_avatar()
	me.health.invulnerable = true
	_hide_hud()
	var arch: ZombieArchetype = zs.archetype(&"zombie")
	var cam: Camera3D = Camera3D.new()
	Match.current.map_root.add_child(cam)
	cam.fov = 60.0
	cam.look_at_from_position(Vector3(0, 1.6, 13.5), Vector3(0, 1.0, 8.5))
	cam.current = true
	# (1) posed line-up, AI frozen.
	zs.crowd.frozen = true
	var lineup: Array[ZombieActor] = []
	for i: int in 6:
		var a: ZombieActor = zs.host_spawn(
			arch,
			ZombieArchetype.Tier.WALK,
			Vector3(-3.75 + i * 1.5, 0, 8.5),
			PI * 0.0,
			ZombieSpawner.Kind.WINDOW,
			i % 3,
			500.0
		)
		a.rotation.y = 0.0  # face +Z, toward the camera
		a.sim.yaw = 0.0
		lineup.append(a)
	lineup[0].speed = 1.4
	lineup[1].start_action(ZombieActor.Action.ATTACK)
	lineup[2].set_flag(ZombieActor.Flag.CRAWLER, true)
	lineup[2].speed = 0.8
	lineup[3].look_target = cam.global_position + Vector3(2.5, 0, 0)
	await _frames(20)
	var head: DamageInfo = DamageInfo.make(9999.0, WeaponDefinition.Hitzone.HEAD, DamageInfo.Kind.BULLET, &"m1911", 1)
	arch.head_gib_chance = 1.0
	Match.current.targets.host_damage(lineup[4], head)
	arch.head_gib_chance = 0.5
	Match.current.targets.host_damage(
		lineup[5], DamageInfo.make(9999.0, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.BULLET, &"m1911", 1)
	)
	lineup[1].start_action(ZombieActor.Action.ATTACK)
	await _frames(18)  # ~0.3 s: mid wind-up
	var img1: Image = await _shot("zombies_lineup.png")
	check("lineup_rendered", _variance(img1) > 0.002, _variance(img1))
	check("ragdoll_started", lineup[5].visual.death_style == "ragdoll", lineup[5].visual.death_style)
	check("head_gibbed", lineup[4].visual.gib_mask & ZombieSync.Gib.HEAD != 0, lineup[4].visual.gib_mask)
	await _frames(60)
	await _shot("zombies_lineup_after.png")
	zs.host_kill_all()
	await _frames(30)
	# (2) surround: the player stands still in the atrium, 14 runners close in.
	zs.crowd.frozen = false
	me.bot_driver = func(_p: PlayerCharacter, _d: float) -> PlayerInputFrame: return PlayerInputFrame.new()
	me.motor.teleport(Vector3(0, 0.1, 6))
	for i: int in 14:
		var ang: float = TAU * i / 14.0
		zs.host_spawn(
			arch,
			ZombieArchetype.Tier.RUN,
			Vector3(0, 0, 6) + Vector3(sin(ang), 0, cos(ang)) * 9.0,
			0.0,
			ZombieSpawner.Kind.WINDOW
		)
	cam.look_at_from_position(Vector3(0, 9, 13), Vector3(0, 0, 6))
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4500:
		await get_tree().physics_frame
	var ring: int = 0
	for a: ZombieActor in zs.actors.values():
		if Vector2(a.global_position.x, a.global_position.z - 6.0).length() < 2.4:
			ring += 1
	await _shot("zombies_surround.png")
	check("surrounds_player", ring >= 8, ring)
	zs.host_kill_all()
	await _frames(20)
	# (3) window tear from inside.
	for i: int in 2:
		zs.host_spawn_at_spawner(
			arch, ZombieArchetype.Tier.WALK, Match.current.map_root.find_child("Spawn_W1", true, false) as ZombieSpawner
		)
	cam.look_at_from_position(Vector3(-6.5, 1.7, 12.5), Vector3(-8, 1.2, 16.5))
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5500:
		await get_tree().physics_frame
	var b: Barricade = Match.current.map_root.find_child("W1_Barricade", true, false) as Barricade
	await _shot("zombies_window.png")
	check("window_being_torn", b.planks < 6, b.planks)
	finish(true)
