# AC-5.2: path-distance targeting (players either side of a wall), stairs instead of walls,
# drop-down links when shorter, pursuit of a bot moving a scripted route across floors; plus the
# NavDoor re-bake connecting both halves of F1.
extends GutTest

const ZH: GDScript = preload("res://tests/integration/zombie_test_helper.gd")


func test_targets_nearer_player_by_path_not_straight_line() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	# Divider wall at x = 0 (door D1 closed): A is 2 m away through the wall, B is 9 m away in the open.
	var a: Node3D = rig.add_target("PlayerA", Vector3(1.2, 0, -12))
	var b: Node3D = rig.add_target("PlayerB", Vector3(-1.2, 0, -3))
	var z: ZombieActor = rig.spawn(ZombieArchetype.Tier.WALK, Vector3(-1.2, 0, -12))
	await ZH.step(self, 30)
	assert_eq(z.sim.target, b, "picks B (shorter path) over A (closer in a straight line)")
	assert_lt(z.global_position.distance_to(a.global_position), z.global_position.distance_to(b.global_position))
	assert_gt(z.sim.target_path_length, 5.0)
	# Opening the door re-bakes the navmesh: the path to A becomes short and the zombie retargets.
	var door: NavDoor = rig.marker("D1_Door") as NavDoor
	b.global_position = Vector3(-1.2, 0, 2.0)  # B farther away now (14 m)
	door.host_set_open(true)
	# The re-bake is threaded: under --fixed-fps it can outlast a fixed frame window, so wait for it.
	var region: NavigationRegion3D = door.get_parent() as NavigationRegion3D
	for i: int in 900:
		await ZH.step(self, 1)
		if region == null or not region.is_baking():
			break
	for i: int in 180:
		await ZH.step(self, 1)
		if z.sim.target == a:
			break
	assert_true(door.is_open, "door open")
	assert_eq(z.sim.target, a, "after the door opens A is nearer by path")


func test_uses_stairs_not_walls_to_reach_upper_floor() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	var goal: Node3D = rig.add_target("Upstairs", Vector3(8, 4, -13))
	var z: ZombieActor = rig.spawn(ZombieArchetype.Tier.RUN, Vector3(8, 0, 2))
	var off_stairs_climb: int = 0
	var reached: bool = false
	for f: int in 60 * 25:
		await ZH.step(self, 1)
		var p: Vector3 = z.global_position
		if p.y > 0.5 and p.y < 3.5:
			var on_stairs: bool = p.x > 10.6 and p.x < 15.4 and p.z < -1.6 and p.z > -10.4
			if not on_stairs:
				off_stairs_climb += 1
		if z.sim.reached_target:
			reached = true
			break
	assert_true(reached, "reached the F2 target")
	assert_eq(off_stairs_climb, 0, "only gained height on the stairs footprint")
	assert_almost_eq(z.global_position.y, 4.0, 0.5, "on F2")


func test_takes_drop_link_when_shorter() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	rig.add_target("Atrium", rig.marker("Target_Atrium").global_position)
	var z: ZombieActor = rig.spawn(ZombieArchetype.Tier.JOG, Vector3(-10, 4, 1.5))
	var t0: int = 0
	for f: int in 60 * 20:
		await ZH.step(self, 1)
		if z.sim.reached_target:
			t0 = f
			break
	assert_true(z.sim.reached_target, "reached the atrium target")
	assert_eq(int(z.sim.traversals.get(TraversalLink.Action.DROP, 0)), 1, "dropped from the balcony")
	assert_lt(t0 / 60.0, 8.0, "drop route is the short one (%.1f s)" % (t0 / 60.0))


func test_pursues_bot_on_scripted_route_across_floors() -> void:
	var rig: ZH.Rig = await ZH.build(self)
	var route: Array[Vector3] = []
	for i: int in 8:
		route.append(rig.marker("Route_%d" % i).global_position)
	var bot: Node3D = rig.add_target("Bot", route[0])
	var z: ZombieActor = rig.spawn(ZombieArchetype.Tier.RUN, Vector3(-10, 0, 10))
	var seg: int = 0
	var u: float = 0.0
	var floors_shared: Dictionary = {}
	var attacks: int = 0
	var was_attacking: bool = false
	for f: int in 60 * 60:
		await ZH.step(self, 1)
		if seg < route.size() - 1:
			var a: Vector3 = route[seg]
			var b: Vector3 = route[seg + 1]
			u += 2.6 / 60.0 / maxf(a.distance_to(b), 0.01)
			if u >= 1.0:
				u = 0.0
				seg += 1
			bot.global_position = a.lerp(b, minf(u, 1.0))
		var attacking: bool = z.sim.state == ZombieSim.State.ATTACK
		if attacking and not was_attacking:
			attacks += 1
			floors_shared[roundi(bot.global_position.y / 4.0)] = true
		was_attacking = attacking
	gut.p(
		(
			"attacks %d on floors %s, requeues %d, hits %d"
			% [attacks, floors_shared.keys(), rig.crowd.requeues, rig.hits.size()]
		)
	)
	assert_eq(rig.crowd.requeues, 0, "never stuck or lost")
	assert_gt(attacks, 2, "caught up and attacked the moving bot")
	assert_true(floors_shared.size() >= 2, "attacked on more than one floor (followed it upstairs)")
	assert_gt(rig.hits.size(), 0, "swipes landed")
