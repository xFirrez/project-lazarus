# AC-5.1: in the nav torture map, 32 zombies spawned at random spawners reach a stationary target
# on each floor within the expected time; none stay permanently stuck (stuck re-queue fires for
# any that are). Also checks the path budget is respected.
extends GutTest

const ZH: GDScript = preload("res://tests/integration/zombie_test_helper.gd")
const REACH: float = 4.5  # surround rings + queue around one target
const LIMIT_S: float = 75.0


func _run_floor(target_marker: String) -> Dictionary:
	var rig: ZH.Rig = await ZH.build(self)
	rig.zombies.auto_respawn = true  # re-queued zombies come back at a spawner near the target
	assert_true(rig.crowd.is_ready(), "navigation map ready")
	var goal: Vector3 = rig.marker(target_marker).global_position
	rig.add_target("Goal", goal)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(target_marker)
	var spawners: Array[ZombieSpawner] = rig.zombies.spawners
	var actors: Array[ZombieActor] = []
	for i: int in 32:
		var sp: ZombieSpawner = spawners[rng.randi_range(0, spawners.size() - 1)]
		actors.append(rig.zombies.host_spawn_at_spawner(rig.zombies.archetype(&"zombie"), ZombieArchetype.Tier.JOG, sp))
	var reached: Dictionary = {}
	var frames: int = int(LIMIT_S * 60.0)
	for f: int in frames:
		await ZH.step(self, 1)
		for a: ZombieActor in rig.zombies.actors.values():
			if reached.has(a.net_id):
				continue
			var p: Vector3 = a.global_position
			if (ZH.flat_dist(p, goal) <= REACH and absf(p.y - goal.y) < 1.0) or a.sim.reached_target:
				reached[a.net_id] = f / 60.0
		if reached.size() >= rig.zombies.alive_count() and f > 120:
			break
	var times: Array = reached.values()
	times.sort()
	var stuck: Array[String] = []
	for a: ZombieActor in rig.zombies.actors.values():
		if not reached.has(a.net_id):
			stuck.append("#%d %s at %s" % [a.net_id, a.sim.state_name(), a.global_position.snapped(Vector3.ONE * 0.1)])
	return {
		"reached": reached.size(),
		"alive": rig.zombies.alive_count(),
		"max_time": times[-1] if not times.is_empty() else -1.0,
		"median": times[times.size() / 2] if not times.is_empty() else -1.0,
		"stuck": stuck,
		"requeues": rig.crowd.requeues,
		"max_queries": rig.crowd.max_queries_in_frame,
		"timing": rig.crowd.timing_stats(),
		"traversals": _traversal_counts(rig),
	}


func _traversal_counts(rig: ZH.Rig) -> Dictionary:
	var out: Dictionary = {}
	for a: ZombieActor in rig.zombies.actors.values():
		for k: int in a.sim.traversals:
			out[TraversalLink.Action.keys()[k]] = (
				int(out.get(TraversalLink.Action.keys()[k], 0)) + int(a.sim.traversals[k])
			)
	return out


func _check(r: Dictionary, floor_name: String) -> void:
	gut.p("%s: %s" % [floor_name, r])
	assert_eq(r["alive"], 32, "%s: 32 alive (re-queued zombies respawn elsewhere, none lost)" % floor_name)
	assert_eq(r["reached"], 32, "%s: all 32 reached the target (stuck: %s)" % [floor_name, r["stuck"]])
	assert_lt(float(r["max_time"]), LIMIT_S, "%s: last arrival within %.0f s" % [floor_name, LIMIT_S])
	assert_true(int(r["max_queries"]) <= 6, "%s: path budget respected (%d/frame)" % [floor_name, r["max_queries"]])


func test_32_zombies_reach_target_floor_1() -> void:
	_check(await _run_floor("Target_F1"), "F1")


func test_32_zombies_reach_target_floor_2() -> void:
	_check(await _run_floor("Target_F2"), "F2")


func test_32_zombies_reach_target_floor_3() -> void:
	_check(await _run_floor("Target_F3"), "F3")
