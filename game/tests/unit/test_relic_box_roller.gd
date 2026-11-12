# AC-9.4: Relic Box statistics — 100,000 rolls match the configured weights within ±1 % (ineligible
# entries excluded), the doll never appears in the first 4 spins at a location or during a Fire
# Sale, the doll chance ramps 15 % -> 75 %, relocation always picks a different location, and the
# wonder bad-luck bonus applies.
extends GutTest

var pool: RelicBoxPool = null


func before_all() -> void:
	pool = load(RelicBoxSystem.DEFAULT_POOL) as RelicBoxPool


func _elig(owned: Array, flags: Dictionary = {}, bad_luck: float = 0.0) -> Array:
	return RelicBoxRoller.eligible(
		pool,
		func(id: StringName) -> bool: return owned.has(id),
		func(flag: String) -> bool: return bool(flags.get(flag, false)),
		func(id: StringName) -> bool: return WeaponCatalog.get_def(id) != null,
		bad_luck
	)


func test_weights_over_100k_rolls() -> void:
	var owned: Array = [&"m14", &"mp40"]
	var elig: Array = _elig(owned)
	var ids: Array[StringName] = elig[0]
	var w: PackedFloat32Array = elig[1]
	assert_false(ids.has(&"m14"), "owned weapons are ineligible")
	assert_false(ids.has(&"ray_pistol"), "undefined wonder weapons are ineligible")
	assert_false(ids.has(&"lazarus_conduit"), "the Conduit needs its first build")
	var total: float = 0.0
	for x: float in w:
		total += x
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var counts: Dictionary = {}
	var n: int = 100000
	for i: int in n:
		var r: StringName = RelicBoxRoller.roll(rng, pool, elig, 0, false)
		counts[r] = int(counts.get(r, 0)) + 1
	assert_false(counts.has(RelicBoxRoller.DOLL), "no doll on a first spin")
	var worst: float = 0.0
	for i: int in ids.size():
		var expected: float = w[i] / total
		var got: float = float(counts.get(ids[i], 0)) / n
		worst = maxf(worst, absf(got - expected))
		assert_almost_eq(got, expected, 0.01, "%s frequency" % ids[i])
	gut.p("worst deviation %.4f over %d items" % [worst, ids.size()])
	for id: StringName in counts:
		assert_true(ids.has(id), "rolled only eligible items (%s)" % id)


func test_condition_unlocks_conduit_entry() -> void:
	var elig: Array = _elig([], {"conduit_built": true})
	# The Conduit definition arrives in Step 12; until then it stays ineligible even with its flag.
	assert_eq((elig[0] as Array).has(&"lazarus_conduit"), WeaponCatalog.get_def(&"lazarus_conduit") != null)


func test_doll_chance_ramp() -> void:
	for spins_done: int in 4:
		assert_eq(RelicBoxRoller.doll_chance(pool, spins_done, false), 0.0, "spin %d is safe" % (spins_done + 1))
	assert_almost_eq(RelicBoxRoller.doll_chance(pool, 4, false), 0.15, 0.0001)
	assert_almost_eq(RelicBoxRoller.doll_chance(pool, 5, false), 0.30, 0.0001)
	assert_almost_eq(RelicBoxRoller.doll_chance(pool, 8, false), 0.75, 0.0001)
	assert_almost_eq(RelicBoxRoller.doll_chance(pool, 30, false), 0.75, 0.0001, "capped at 75 %")
	assert_eq(RelicBoxRoller.doll_chance(pool, 10, true), 0.0, "never during a Fire Sale")


func test_doll_never_in_first_four_or_fire_sale() -> void:
	var elig: Array = _elig([])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for trial: int in 5000:
		for spins_done: int in 4:
			assert_ne(RelicBoxRoller.roll(rng, pool, elig, spins_done, false), RelicBoxRoller.DOLL)
		assert_ne(RelicBoxRoller.roll(rng, pool, elig, 20, true), RelicBoxRoller.DOLL)
	# After the 4th use the doll does show up (5th spin: ~15 %).
	var dolls: int = 0
	for i: int in 20000:
		if RelicBoxRoller.roll(rng, pool, elig, 4, false) == RelicBoxRoller.DOLL:
			dolls += 1
	assert_almost_eq(float(dolls) / 20000.0, 0.15, 0.01)


func test_relocation_always_different() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var seen: Dictionary = {}
	for i: int in 20000:
		var cur: int = i % 7
		var nxt: int = RelicBoxRoller.next_location(rng, 7, cur)
		assert_ne(nxt, cur)
		assert_true(nxt >= 0 and nxt < 7)
		seen[nxt] = true
	assert_eq(seen.size(), 7, "every location reachable")


func test_bad_luck_bonus_raises_wonder_weight() -> void:
	# Simulate a defined wonder entry by checking the weight arithmetic on the pool directly.
	var fake: RelicBoxPool = pool.duplicate() as RelicBoxPool
	fake.item_ids = [&"mp40", &"m16"]
	fake.weights = PackedFloat32Array([8.0, 1.5])
	fake.wonder_ids = [&"m16"]
	var elig: Array = RelicBoxRoller.eligible(
		fake,
		func(_id: StringName) -> bool: return false,
		func(_f: String) -> bool: return true,
		func(_id: StringName) -> bool: return true,
		0.5
	)
	assert_eq((elig[1] as PackedFloat32Array)[1], 2.0, "wonder weight 1.5 + bad luck 0.5")
	assert_eq((elig[1] as PackedFloat32Array)[0], 8.0)
