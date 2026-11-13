# AC-12.2 / AC-12.6 / Galvanics on live zombies (nav torture rig, host authority without a session):
# the Lazarus Conduit chains through a dummy cluster (count, jump range, falloff, stun 1.5 s with the
# ELECTROCUTED flag), Requiem reaches 11 targets with flat damage and kill arcs, the pulse stuns
# everything within 8 m for 3 s without damage, a chain through 10 zombies with 32 alive keeps arcs
# and lights within the WonderFx caps, the Ray Pistol's plasma kills disintegrate, and a Galvanic
# telegraphs (>= 0.6 s) then leaps 3-6 m at its target for 40.
extends GutTest

const ZH: GDScript = preload("res://tests/integration/zombie_test_helper.gd")
const EYE: Vector3 = Vector3(-1.2, 1.6, 4.0)


func _sync(rig: ZH.Rig) -> WeaponSync:
	var ws: WeaponSync = WeaponSync.new()
	ws.targets = rig.targets
	rig.root.add_child(ws)
	return ws


func _cluster(rig: ZH.Rig, n: int, hp: float, spacing: float = 2.5) -> Array[ZombieActor]:
	var out: Array[ZombieActor] = []
	for i: int in n:
		var col: float = -1.2 if i % 2 == 0 else -2.6
		var p: Vector3 = Vector3(col, 0, 1.0 - spacing * float(i / 2) - (0.0 if i % 2 == 0 else spacing * 0.5))
		out.append(rig.spawn(ZombieArchetype.Tier.WALK, p, ZombieSpawner.Kind.WINDOW, hp))
	return out


func _aim(z: ZombieActor) -> Vector3:
	return (z.zone_position(WeaponDefinition.Hitzone.TORSO) - EYE).normalized()


func test_conduit_chain_falloff_and_stun() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	var ws: WeaponSync = _sync(rig)
	var zs: Array[ZombieActor] = _cluster(rig, 9, 50000.0)
	await ZH.step(self, 20)
	var def: WeaponDefinition = WeaponCatalog.get_def(&"lazarus_conduit")
	var n: int = ws.host_chain(1, def, EYE, _aim(zs[0]))
	assert_eq(n, 6, "first + 5 jumps")
	assert_eq(ws.last_chain.size(), 6)
	var prev: Vector3 = Vector3.INF
	for j: int in ws.last_chain.size():
		var e: Array = ws.last_chain[j]
		var z: ZombieActor = e[0]
		assert_almost_eq(float(e[1]), 1200.0 * pow(0.75, j), 0.01, "jump %d damage" % j)
		assert_almost_eq(z.max_health - z.health, float(e[1]), 0.01, "applied")
		assert_true(bool(e[2]), "stunned")
		assert_eq(z.sim.state, ZombieSim.State.STAGGER)
		assert_true(z.flags & ZombieActor.Flag.ELECTROCUTED != 0, "electrocuted flag")
		var p: Vector3 = z.zone_position(WeaponDefinition.Hitzone.TORSO)
		if prev != Vector3.INF:
			assert_lte(prev.distance_to(p), def.chain_jump_range + 0.01, "jump within 6 m")
		prev = p
	var first: ZombieActor = ws.last_chain[0][0]
	await ZH.step(self, 84)  # 1.4 s
	assert_eq(first.sim.state, ZombieSim.State.STAGGER, "still stunned at 1.4 s")
	await ZH.step(self, 12)  # 1.6 s
	assert_ne(first.sim.state, ZombieSim.State.STAGGER, "free after 1.5 s")
	assert_true(first.flags & ZombieActor.Flag.ELECTROCUTED == 0, "flag cleared")


func test_requiem_reach_flat_damage_and_kill_arcs() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	var ws: WeaponSync = _sync(rig)
	var zs: Array[ZombieActor] = _cluster(rig, 13, 90000.0)
	await ZH.step(self, 20)
	var up: WeaponDefinition = WeaponCatalog.upgrade_of(&"lazarus_conduit")
	assert_eq(ws.host_chain(1, up, EYE, _aim(zs[0])), 11, "first + 10 jumps")
	for j: int in 5:
		assert_eq(float(ws.last_chain[j][1]), up.damage, "no falloff jump %d" % j)
	assert_almost_eq(float(ws.last_chain[5][1]), up.damage * 0.75, 0.01)
	var stunned: ZombieActor = ws.last_chain[0][0]
	await ZH.step(self, 60 * 2 + 20)
	assert_eq(stunned.sim.state, ZombieSim.State.STAGGER, "Requiem stun 2.5 s (2.3 s in)")
	await ZH.step(self, 20)
	assert_ne(stunned.sim.state, ZombieSim.State.STAGGER)
	# Kill arcs: a weak lead zombie dies and arcs to 2 more beyond the main chain's reach.
	var rig2: ZH.Rig = await ZH.build(self)
	var ws2: WeaponSync = _sync(rig2)
	var lead: ZombieActor = rig2.spawn(
		ZombieArchetype.Tier.WALK, Vector3(-1.2, 0, 1.0), ZombieSpawner.Kind.WINDOW, 100.0
	)
	var extra: Array[ZombieActor] = []
	for p: Vector3 in [Vector3(-3.0, 0, 1.0), Vector3(-1.2, 0, -1.5)]:
		extra.append(rig2.spawn(ZombieArchetype.Tier.WALK, p, ZombieSpawner.Kind.WINDOW, 90000.0))
	await ZH.step(self, 20)
	var solo: WeaponDefinition = up.duplicate() as WeaponDefinition
	solo.chain_jumps = 0  # only the lead: the extra arcs come from its death
	assert_eq(ws2.host_chain(1, solo, EYE, _aim(lead)), 3, "lead + 2 kill arcs")
	assert_false(lead.alive, "lead killed")
	for z: ZombieActor in extra:
		assert_almost_eq(z.max_health - z.health, up.damage * up.chain_kill_arc_factor, 0.01, "kill arc damage")


func test_pulse_stuns_within_8m_without_damage() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	var ws: WeaponSync = _sync(rig)
	var near: Array[ZombieActor] = []
	for z: float in [1.0, -1.0, -2.5]:
		near.append(rig.spawn(ZombieArchetype.Tier.WALK, Vector3(-1.2, 0, z), ZombieSpawner.Kind.WINDOW, 5000.0))
	var far: ZombieActor = rig.spawn(
		ZombieArchetype.Tier.WALK, Vector3(-1.2, 0, -9.0), ZombieSpawner.Kind.WINDOW, 5000.0
	)
	await ZH.step(self, 20)
	var pulse: WeaponDefinition = WeaponCatalog.get_def(&"lazarus_conduit_pulse")
	var n: int = ws.host_pulse(1, pulse, EYE + Vector3(0, 0, 0.5))
	assert_eq(n, 3, "everything within 8 m")
	for z: ZombieActor in near:
		assert_eq(z.health, z.max_health, "no damage")
		assert_eq(z.sim.state, ZombieSim.State.STAGGER)
	assert_ne(far.sim.state, ZombieSim.State.STAGGER, "13 m away: untouched")
	await ZH.step(self, 60 * 3 - 12)
	assert_eq(near[0].sim.state, ZombieSim.State.STAGGER, "3 s stun")
	await ZH.step(self, 20)
	assert_ne(near[0].sim.state, ZombieSim.State.STAGGER)


func test_chain_fx_within_caps_with_32_alive() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	var ws: WeaponSync = _sync(rig)
	var chain: Array[ZombieActor] = _cluster(rig, 10, 2000.0, 2.0)
	for i: int in 22:
		var p: Vector3 = rig.marker("Target_F2").global_position + Vector3(float(i % 6) - 3.0, 0, float(i / 6) - 2.0)
		rig.spawn(ZombieArchetype.Tier.WALK, p, ZombieSpawner.Kind.WINDOW, 2000.0)
	await ZH.step(self, 20)
	assert_eq(rig.zombies.alive_count(), 32, "32 alive")
	var up: WeaponDefinition = WeaponCatalog.upgrade_of(&"lazarus_conduit")
	var worst_frame_us: int = 0
	for shot: int in 4:
		var alive_lead: ZombieActor = null
		for z: ZombieActor in chain:
			if z.alive:
				alive_lead = z
				break
		if alive_lead == null:
			break
		var t0: int = Time.get_ticks_usec()
		ws.host_chain(1, up, EYE, _aim(alive_lead))
		worst_frame_us = maxi(worst_frame_us, Time.get_ticks_usec() - t0)
		await ZH.step(self, 3)
	var fx: WonderFx = WonderFx.of(ws)
	var c: Dictionary = fx.counts()
	gut.p(
		(
			"wonder fx after 4 Requiem chains: %s, peak lights %d, peak arcs %d, worst chain %d us"
			% [c, fx.peak_lights, fx.peak_arcs, worst_frame_us]
		)
	)
	assert_true(int(fx.shown.get(WonderFx.Kind.ARC, 0)) >= 4, "arcs shown")
	assert_lte(int(c["arcs"]), WonderFx.ARC_CAP)
	assert_lte(int(c["bursts"]), WonderFx.BURST_CAP)
	assert_lte(int(c["sparks"]), WonderFx.SPARK_CAP)
	assert_lte(fx.peak_lights, WonderFx.MAX_LIGHTS, "light cap")
	assert_lt(worst_frame_us, 25000, "host chain resolution well under a 25 ms frame")


func test_ray_pistol_kill_disintegrates() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	var ws: WeaponSync = _sync(rig)
	var z: ZombieActor = rig.spawn(ZombieArchetype.Tier.WALK, Vector3(-1.2, 0, -2.0), ZombieSpawner.Kind.WINDOW, 900.0)
	await ZH.step(self, 20)
	var def: WeaponDefinition = WeaponCatalog.get_def(&"ray_pistol")
	ws._host_launch(1, def, 7, EYE, _aim(z))
	await ZH.step(self, 30)
	assert_false(z.alive, "1000 direct hit kills a 900 HP zombie")
	assert_eq(z.visual.death_fx, ZombieVisual.DeathFx.DISINTEGRATE, "green disintegration")
	assert_eq(ws.explosions, 1, "plasma splash")


func test_galvanic_telegraphs_then_leaps() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	var target: Node3D = rig.add_target("Player", Vector3(-1.2, 0, 3.0))
	var g: ZombieActor = rig.zombies.host_spawn(
		rig.zombies.archetype(&"galvanic"),
		ZombieArchetype.Tier.SPRINT,
		Vector3(-1.2, 0, -12.0),
		0.0,
		ZombieSpawner.Kind.SPECIAL,
		-1,
		400.0
	)
	assert_true(g.behavior is GalvanicBehavior, "Galvanic brain")
	var gb: GalvanicBehavior = g.behavior as GalvanicBehavior
	var saw_telegraph: bool = false
	var max_speed: float = 0.0
	for f: int in 60 * 6:
		await ZH.step(self, 1)
		saw_telegraph = saw_telegraph or g.flags & ZombieActor.Flag.TELEGRAPH != 0
		if gb.phase == GalvanicBehavior.Phase.NONE and gb.leaps == 0:
			max_speed = maxf(max_speed, g.speed)
		if gb.leaps > 0 and gb.phase == GalvanicBehavior.Phase.NONE:
			break
	assert_true(saw_telegraph, "TELEGRAPH flag while winding up")
	assert_gte(gb.leaps, 1, "leapt")
	assert_gte(gb.telegraph_seconds, 0.6, "telegraph >= 0.6 s")
	assert_gt(max_speed, 5.0, "sprints (~6 m/s)")
	var leap_hits: Array = rig.hits.filter(func(h: Array) -> bool: return is_equal_approx(float(h[1]), 40.0))
	assert_gte(leap_hits.size(), 1, "leap hit for 40")
	assert_lt(ZH.flat_dist(g.global_position, target.global_position), 2.5, "landed at the target")
