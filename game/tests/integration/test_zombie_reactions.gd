# AC-5.4: headshots produce a head react and lethal headshots can pop the head (gib); explosive
# leg damage creates crawlers; deaths produce a ragdoll (or animation) within the pool limit of 6
# simulating ragdolls, and corpses fade out. Also: heavy hits stagger.
extends GutTest

const ZH: GDScript = preload("res://tests/integration/zombie_test_helper.gd")


func _hit(
	rig: ZH.Rig, z: ZombieActor, amount: float, zone: int, kind: DamageInfo.Kind, at: Vector3 = Vector3.ZERO
) -> void:
	var info: DamageInfo = DamageInfo.make(amount, zone, kind, &"m1911", 1)
	info.position = at
	rig.targets.host_damage(z, info)


func test_head_and_body_reacts_and_stagger() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	rig.add_target("T", Vector3(-8, 0, -11))
	var z: ZombieActor = rig.spawn(ZombieArchetype.Tier.WALK, Vector3(-8, 0, 0), ZombieSpawner.Kind.WINDOW, 1000.0)
	await ZH.step(self, 20)
	_hit(rig, z, 20.0, WeaponDefinition.Hitzone.HEAD, DamageInfo.Kind.BULLET)
	assert_eq(z.visual.last_react, &"hit_react_head", "headshot -> head react")
	await ZH.step(self, 30)
	_hit(rig, z, 20.0, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.BULLET)
	assert_eq(z.visual.last_react, &"hit_react_stomach", "torso -> stomach react")
	_hit(rig, z, 20.0, WeaponDefinition.Hitzone.LIMB, DamageInfo.Kind.BULLET)
	assert_true(z.visual.last_react in [&"hit_react_left", &"hit_react_right"], "limb -> side react")
	assert_eq(z.sim.state, ZombieSim.State.PURSUE, "small hits don't stagger")
	_hit(rig, z, 400.0, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.BULLET)
	assert_eq(z.sim.state, ZombieSim.State.STAGGER, "hit >= 35% of max health staggers")
	assert_eq(z.action, ZombieActor.Action.STAGGER)
	await ZH.step(self, 60)
	assert_eq(z.sim.state, ZombieSim.State.PURSUE, "recovers after the stagger")
	assert_true(z.visual.tree.active, "animation tree running")


func test_lethal_headshot_can_pop_the_head() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	var arch: ZombieArchetype = rig.zombies.archetype(&"zombie")
	var old: float = arch.head_gib_chance
	arch.head_gib_chance = 1.0
	var z: ZombieActor = rig.spawn(ZombieArchetype.Tier.WALK, Vector3(-8, 0, 0))
	await ZH.step(self, 10)
	_hit(rig, z, 500.0, WeaponDefinition.Hitzone.HEAD, DamageInfo.Kind.BULLET)
	arch.head_gib_chance = old
	assert_false(z.alive, "dead")
	assert_true(z.visual.dead, "visual death")
	assert_true(z.visual.gib_mask & ZombieSync.Gib.HEAD != 0, "head gibbed")
	var head: int = z.visual.model.skeleton.find_bone(&"Head")
	assert_true(z.visual.gibber.hidden_bones.has(head), "head bone collapsed")
	assert_gt(rig.zombies.fx.gibs_spawned, 0, "gib chunks spawned")
	assert_eq(rig.zombies.alive_count(), 0, "removed from the alive registry")
	assert_null(rig.targets.get_target(z.target_id), "no longer a hit target")


func test_explosive_leg_damage_creates_crawler() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	rig.add_target("T", Vector3(-8, 0, -11))
	var z: ZombieActor = rig.spawn(ZombieArchetype.Tier.RUN, Vector3(-8, 0, 0), ZombieSpawner.Kind.WINDOW, 1000.0)
	await ZH.step(self, 20)
	_hit(
		rig,
		z,
		300.0,
		WeaponDefinition.Hitzone.TORSO,
		DamageInfo.Kind.EXPLOSIVE,
		z.global_position + Vector3(0.5, 0.1, 0)
	)
	assert_true(z.is_crawler(), "explosion at the legs -> crawler")
	assert_true(z.alive, "keeps its health")
	assert_eq(rig.crowd.crawlers_created, 1)
	await ZH.step(self, 120)
	assert_almost_eq(z.speed, z.archetype.crawler_speed, 0.25, "crawls at 1.0 m/s")
	assert_true(z.visual.gib_mask & ZombieSync.Gib.LEG_L != 0, "legs gibbed")
	assert_eq(String(z.visual.tree.get(&"parameters/mode/current_state")), "crawl", "crawl locomotion")
	var z2: ZombieActor = rig.spawn(ZombieArchetype.Tier.RUN, Vector3(-6, 0, 0), ZombieSpawner.Kind.WINDOW, 1000.0)
	await ZH.step(self, 5)
	_hit(
		rig,
		z2,
		300.0,
		WeaponDefinition.Hitzone.TORSO,
		DamageInfo.Kind.EXPLOSIVE,
		z2.global_position + Vector3(0, 1.6, 0)
	)
	assert_false(z2.is_crawler(), "explosion above the hips doesn't take the legs")
	_hit(rig, z2, 300.0, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.BULLET)
	assert_false(z2.is_crawler(), "bullets never create crawlers")


func test_ragdoll_pool_limit_and_corpse_fade() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	var zs: Array[ZombieActor] = []
	for i: int in 10:
		zs.append(rig.spawn(ZombieArchetype.Tier.WALK, Vector3(-12 + i * 1.2, 0, 8)))
	await ZH.step(self, 20)
	var peak: int = 0
	for z: ZombieActor in zs:
		_hit(rig, z, 2000.0, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.BULLET)
		peak = maxi(peak, rig.zombies.fx.ragdolls.size())
		await ZH.step(self, 3)
	assert_eq(peak, ZombieFx.RAGDOLL_LIMIT, "never more than 6 simulating ragdolls")
	assert_eq(rig.zombies.fx.ragdolls_frozen, 4, "the 4 oldest were frozen")
	for z: ZombieActor in zs:
		assert_true(z.visual.death_style in ["ragdoll", "animation"], "death presented (%s)" % z.visual.death_style)
	await ZH.step(self, 90)
	var last: ZombieActor = zs[-1]
	var hips: Vector3 = last.visual.ragdoll_root_position()
	assert_true(hips.is_finite() and hips.y < 0.9 and hips.y > -0.5, "ragdoll settled on the floor (%s)" % hips)
	await ZH.step(self, 60 * 8)
	var left: int = 0
	for z: ZombieActor in zs:
		if is_instance_valid(z):
			left += 1
	assert_eq(left, 0, "corpses faded and freed")
	assert_eq(rig.zombies.fx.ragdolls.size(), 0)
