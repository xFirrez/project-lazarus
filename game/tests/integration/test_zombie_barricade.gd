# AC-5.3: a zombie approaches the window, tears planks one at a time (1.0 s each; 0.8 s at run /
# sprint), climbs through and pursues. A second zombie waits for the window instead of pushing.
extends GutTest

const ZH: GDScript = preload("res://tests/integration/zombie_test_helper.gd")


func _tear_times(tier: int) -> Dictionary:
	var rig: ZH.Rig = await ZH.build(self)
	rig.add_target("Inside", Vector3(-8, 0, 8))
	var b: Barricade = rig.marker("W1_Barricade") as Barricade
	var changes: Array[float] = []
	var frame: Array[int] = [0]
	b.planks_changed.connect(func(_p: int, _d: int) -> void: changes.append(frame[0] / 60.0))
	var z: ZombieActor = rig.spawn_at(tier, "Spawn_W1")
	var z2: ZombieActor = rig.spawn(tier, Vector3(-7, 0, 22))
	var climbed_at: float = -1.0
	var max_wait: int = 0
	var inside_at: float = -1.0
	for f: int in 60 * 25:
		frame[0] = f
		await ZH.step(self, 1)
		if z2.sim.state == ZombieSim.State.WAIT:
			max_wait += 1
		if climbed_at < 0.0 and z.sim.state == ZombieSim.State.TRAVERSE:
			climbed_at = f / 60.0
		if inside_at < 0.0 and z.global_position.z < 14.0:
			inside_at = f / 60.0
		if z.sim.reached_target and z2.sim.reached_target:
			break
	return {
		"changes": changes,
		"climbed": climbed_at,
		"inside": inside_at,
		"z_reached": z.sim.reached_target,
		"z2_reached": z2.sim.reached_target,
		"z2_waited": max_wait,
		"planks": b.planks,
		"tears": b.tears,
	}


func _gaps(times: Array[float]) -> Array[float]:
	var out: Array[float] = []
	for i: int in range(1, times.size()):
		out.append(times[i] - times[i - 1])
	return out


func test_walker_tears_one_plank_per_second_then_climbs() -> void:
	var r: Dictionary = await _tear_times(ZombieArchetype.Tier.WALK)
	gut.p(r)
	var changes: Array[float] = r["changes"]
	assert_eq(changes.size(), 6, "6 planks torn one at a time")
	assert_eq(r["planks"], 0)
	assert_eq(r["tears"], 6, "no plank torn twice")
	for g: float in _gaps(changes):
		assert_almost_eq(g, 1.0, 0.05, "1.0 s per plank")
	assert_gt(float(r["climbed"]), changes[-1] - 0.05, "climbs after the last plank")
	assert_gt(float(r["inside"]), 0.0, "came through the window")
	assert_true(r["z_reached"], "pursued and reached the target inside")
	assert_gt(int(r["z2_waited"]), 30, "second zombie waited for the window")
	assert_true(r["z2_reached"], "second zombie followed through the open window")


func test_runner_tears_faster() -> void:
	var r: Dictionary = await _tear_times(ZombieArchetype.Tier.RUN)
	var changes: Array[float] = r["changes"]
	assert_eq(changes.size(), 6)
	for g: float in _gaps(changes):
		assert_almost_eq(g, 0.8, 0.05, "0.8 s per plank at run tier")
