# AC-9.6: the Drummer Decoy pulls every zombie within 25 m (path distance) away from the players
# for 8 s, then explodes (2000, r = 4 m); zombies farther than 25 m by path keep chasing players.
# Plus tripmines: a zombie walking into one sets it off (placed limit 4 per player), and the Ice
# Axe replaces the knife.
extends GutTest

const ZH: GDScript = preload("res://tests/integration/zombie_test_helper.gd")


func _sync(rig: ZH.Rig) -> WeaponSync:
	var ws: WeaponSync = WeaponSync.new()
	ws.targets = rig.targets
	rig.root.add_child(ws)
	var crowd: CrowdDirector = rig.crowd
	ws.attraction = func(n: Node3D, d: WeaponDefinition) -> void: crowd.add_attractor(n, d.attract_radius)
	return ws


func test_decoy_pulls_zombies_within_25m_for_8s() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	var ws: WeaponSync = _sync(rig)
	var player: Node3D = rig.add_target("Player", Vector3(-1.2, 0, 2.0))
	var decoy_at: Vector3 = Vector3(-1.2, 0.2, -12.0)
	var near: Array[ZombieActor] = []
	for x: float in [-2.5, -1.2, 0.0 - 0.6]:
		near.append(rig.spawn(ZombieArchetype.Tier.WALK, Vector3(x, 0, -3.0), ZombieSpawner.Kind.WINDOW, 5000.0))
	var far_pos: Vector3 = rig.marker("Target_F3").global_position
	var far_len: float = rig.crowd.path_length_now(far_pos, decoy_at)
	var far: ZombieActor = rig.spawn(ZombieArchetype.Tier.WALK, far_pos, ZombieSpawner.Kind.WINDOW, 5000.0)
	await ZH.step(self, 60)
	for z: ZombieActor in near:
		assert_eq(z.sim.target, player, "chasing the player before the decoy")
	assert_true(ws.host_give(1, &"decoy"), "decoy given")
	var def: WeaponDefinition = WeaponCatalog.get_def(&"decoy")
	ws._host_throw(1, def, 1001, decoy_at, Vector3.ZERO, def.fuse_time)
	var decoy: Node3D = ws.grenades.values()[0] if not ws.grenades.is_empty() else null
	assert_not_null(decoy, "decoy spawned")
	assert_eq(int(ws.loadouts[1]["tac_n"]), def.carry_max - 1, "one decoy used")
	rig.hits.clear()
	var pulled_frames: int = 0
	var frames: int = roundi(def.attract_time * 60.0) - 30
	for f: int in frames:
		await ZH.step(self, 1)
		if f > 90:
			var all_on_decoy: bool = true
			for z: ZombieActor in near:
				all_on_decoy = all_on_decoy and z.sim.target == decoy
			if all_on_decoy:
				pulled_frames += 1
	assert_true(pulled_frames >= frames - 120, "every zombie within 25 m targets the decoy (%d frames)" % pulled_frames)
	for z: ZombieActor in near:
		assert_lt(
			z.global_position.distance_to(decoy_at), z.global_position.distance_to(player.global_position), "moved away"
		)
	var on_player: int = 0
	for h: Array in rig.hits:
		if h[0] == player:
			on_player += 1
	assert_eq(on_player, 0, "nobody attacked the player while the decoy played")
	gut.p("far zombie path to decoy: %.1f m" % far_len)
	if far_len > def.attract_radius + 1.0:
		assert_ne(far.sim.target, decoy, "zombie > 25 m by path is not pulled")
	var before: int = ws.explosions
	await ZH.step(self, 120)
	assert_eq(ws.explosions, before + 1, "decoy exploded after 8 s")
	for z: ZombieActor in near:
		if z.global_position.distance_to(decoy_at) < 2.5:
			assert_true(z.health < 5000.0 - 1000.0, "caught in the 2000 blast")
	await ZH.step(self, 30)
	for z: ZombieActor in near:
		if z.alive:
			assert_ne(z.sim.target, decoy, "back to the players after the decoy")


func test_tripmine_triggers_on_zombie_and_limit() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	var ws: WeaponSync = _sync(rig)
	rig.add_target("Player", Vector3(-1.2, 0, 2.0))
	assert_true(ws.host_give(1, &"tripmines"))
	assert_eq(int(ws.loadouts[1]["place_n"]), 2, "2 tripmines")
	ws.host_add_lethal(1, 2)
	ws._host_place_mine(1, 1, Vector3(-1.2, 0.0, -2.0), PI)  # facing -Z, toward the zombies
	ws._host_place_mine(1, 2, Vector3(-3.0, 0.0, 0.0), PI)
	ws._host_place_mine(1, 3, Vector3(-3.0, 0.0, 1.0), PI)
	assert_eq(ws.mines.size(), 2, "only the carried count can be placed")
	var def: WeaponDefinition = WeaponCatalog.get_def(&"tripmines")
	ws.loadouts[1]["place_n"] = 10
	for i: int in 6:
		ws._host_place_mine(1, 10 + i, Vector3(-3.5 + 0.5 * i, 0.0, 1.5), PI)
	assert_eq(ws.mines.size(), def.place_limit, "limit 4 placed per player")
	var z: ZombieActor = rig.spawn(ZombieArchetype.Tier.RUN, Vector3(-1.2, 0, -10.0))
	var before: int = ws.explosions
	for i: int in 60 * 8:
		await ZH.step(self, 1)
		if ws.explosions > before:
			break
	assert_eq(ws.explosions, before + 1, "the zombie set a mine off")
	await ZH.step(self, 2)
	assert_false(z.alive, "2000 splash kills a round-1 zombie")


func test_ice_axe_replaces_knife() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	var ws: WeaponSync = _sync(rig)
	assert_true(ws.host_give(1, &"ice_axe"))
	assert_true(ws.host_owns(1, &"ice_axe"))
	assert_eq(StringName(ws.loadouts[1]["melee"]), &"ice_axe")
	assert_true(ws.validator.state_for(1).owned.has(&"ice_axe"), "host validates Ice Axe swings")
	assert_false(ws.host_give(1, &"knife"), "the knife can't be bought back")
