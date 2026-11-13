# AC-12.2: the Lazarus Conduit's chain rules on a dummy cluster — first target inside the 4° aim
# cone within 25 m, up to 5 jumps of <= 6 m (nearest first, never back), 75 % per jump, line of
# sight respected; Requiem: 10 jumps of 8 m, no falloff for the first 4.
extends GutTest

const EYE: Vector3 = Vector3(0, 1.6, 0)


func _line(n: int, spacing: float, start_z: float = -5.0) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i: int in n:
		out.append(Vector3(0, 1.2, start_z - spacing * i))
	return out


func test_first_target_inside_cone() -> void:
	var pts: Array[Vector3] = [Vector3(3, 1.6, -10), Vector3(0.3, 1.6, -12), Vector3(0, 1.6, -30)]
	var i: int = ChainLightning.pick_first(EYE, Vector3.FORWARD, pts, 25.0, 4.0)
	assert_eq(i, 1, "the one at 1.4° (the 17° one and the 30 m one are out)")
	assert_eq(ChainLightning.pick_first(EYE, Vector3.FORWARD, [Vector3(3, 1.6, -10)] as Array[Vector3], 25.0, 4.0), -1)
	var blocked: Callable = func(_a: Vector3, _b: Vector3) -> bool: return false
	assert_eq(ChainLightning.pick_first(EYE, Vector3.FORWARD, pts, 25.0, 4.0, blocked), -1, "needs sight")


func test_chains_to_five_more_within_six_metres() -> void:
	var pts: Array[Vector3] = _line(9, 4.0)
	var order: PackedInt32Array = ChainLightning.chain(0, pts, 5, 6.0)
	assert_eq(order.size(), 6, "first + 5 jumps")
	assert_eq(Array(order), [0, 1, 2, 3, 4, 5], "nearest each time, no revisits")
	var sparse: Array[Vector3] = _line(5, 6.5)
	assert_eq(ChainLightning.chain(0, sparse, 5, 6.0).size(), 1, "6.5 m gaps: no jump")


func test_nearest_jump_and_no_backtrack() -> void:
	var pts: Array[Vector3] = [Vector3(0, 0, 0), Vector3(5, 0, 0), Vector3(2, 0, 0), Vector3(-1, 0, 0)]
	var order: PackedInt32Array = ChainLightning.chain(0, pts, 5, 6.0)
	assert_eq(Array(order), [0, 3, 2, 1], "nearest unvisited from the current link")


func test_falloff() -> void:
	var expect: Array[float] = [1200.0, 900.0, 675.0, 506.25, 379.6875, 284.765625]
	for j: int in expect.size():
		assert_almost_eq(ChainLightning.damage_at(1200.0, j, 0.75, 0), expect[j], 0.001, "jump %d" % j)
	var d: WeaponDefinition = WeaponCatalog.get_def(&"lazarus_conduit")
	assert_almost_eq(ChainLightning.damage_for(d, 2), 675.0, 0.001)


func test_requiem_chain_and_flat_damage() -> void:
	var u: WeaponDefinition = WeaponCatalog.upgrade_of(&"lazarus_conduit")
	var pts: Array[Vector3] = _line(14, 7.5)
	var order: PackedInt32Array = ChainLightning.chain(0, pts, u.chain_jumps, u.chain_jump_range)
	assert_eq(order.size(), 11, "first + 10 jumps of 7.5 m")
	for j: int in 5:
		assert_eq(ChainLightning.damage_for(u, j), u.damage, "no falloff through jump %d" % j)
	assert_almost_eq(ChainLightning.damage_for(u, 5), u.damage * 0.75, 0.001)
	assert_almost_eq(ChainLightning.damage_for(u, 6), u.damage * 0.5625, 0.001)


func test_skip_and_sight_between_links() -> void:
	var pts: Array[Vector3] = _line(4, 3.0)
	var order: PackedInt32Array = ChainLightning.chain(1, pts, 5, 6.0, Callable(), [0])
	assert_eq(Array(order), [1, 2, 3], "skipped targets are never struck")
	var wall_after_2: Callable = func(a: Vector3, b: Vector3) -> bool: return minf(a.z, b.z) > pts[2].z - 0.1
	assert_eq(ChainLightning.chain(0, pts, 5, 6.0, wall_after_2).size(), 3, "no arc through a wall")
