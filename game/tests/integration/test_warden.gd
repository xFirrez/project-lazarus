# AC-12.5: the Warden in its test arena (maps/_test/warden_arena): health = 25 x base hp(r) x players,
# three armor plates (75 % less body damage while any holds, plate break), the core exposed after
# the third (hits from behind x2), slam / charge / summon each telegraphed >= 0.6 s and dealing
# their damage, phases at 66 % / 33 % health (faster), coolant: frozen <= 3 s, brittle plates, no
# shatter. Plus the kill-time measurement: two bots with upgraded weapons (Forge AK-47 + M14) kite
# the round-20 Warden of a 2-player game and must kill it in 3-6 minutes (simulated time).
extends GutTest

const ARENA: PackedScene = preload("res://maps/_test/warden_arena.tscn")
const BENIGN: PackedStringArray = ["Jolt Physics job system exceeded the maximum number of jobs"]


class Rig:
	extends RefCounted
	var root: Node3D = null
	var zombies: ZombieSync = null
	var targets: TargetRegistry = null
	var crowd: CrowdDirector = null
	var status: StatusEffects = null
	var hits: Array = []

	func marker(n: String) -> Vector3:
		return (root.find_child(n, true, false) as Node3D).global_position

	func add_target(n: String, pos: Vector3) -> Node3D:
		var t: Node3D = Node3D.new()
		t.name = n
		root.add_child(t)
		t.global_position = pos
		crowd.extra_targets.append(t)
		return t


func _build() -> Rig:
	var rig: Rig = Rig.new()
	rig.root = ARENA.instantiate() as Node3D
	add_child_autofree(rig.root)
	rig.targets = TargetRegistry.new()
	rig.root.add_child(rig.targets)
	rig.zombies = ZombieSync.new()
	rig.zombies.targets = rig.targets
	rig.root.add_child(rig.zombies)
	rig.zombies.scan_spawners(rig.root)
	rig.zombies.auto_respawn = false
	rig.crowd = rig.zombies.crowd
	rig.status = StatusEffects.new()
	rig.status.targets = rig.targets
	rig.root.add_child(rig.status)
	var hits: Array = rig.hits
	rig.crowd.damage_hook = func(t: Node3D, amount: float, from: Vector3) -> void: hits.append([t, amount, from])
	for i: int in 240:
		await get_tree().physics_frame
		if rig.crowd.is_ready():
			break
	return rig


func _step(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame
	for err: Variant in gut.error_tracker.get_current_test_errors():
		for b: String in BENIGN:
			if ("%s %s" % [err.code, err.rationale]).contains(b):
				err.handled = true


func _warden(rig: Rig, r: int = 20, p: int = 2, at: String = "Mark_Warden") -> ZombieActor:
	return WardenBehavior.host_spawn(rig.zombies, rig.marker(at), 0.0, r, p)


func _hit(rig: Rig, w: ZombieActor, amount: float, from: Vector3) -> float:
	var info: DamageInfo = DamageInfo.make(amount, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.BULLET, &"m14_up", 9)
	info.position = from
	var before: float = w.health
	rig.targets.host_damage(w, info)
	return before - w.health


func test_health_plates_and_core() -> void:
	var rig: Rig = await _build()
	var w: ZombieActor = _warden(rig)
	assert_not_null(w)
	var base: ZombieArchetype = rig.zombies.archetype(&"zombie")
	assert_eq(w.max_health, 25.0 * base.health_for_round(20) * 2.0, "25 x hp(20) x 2 players")
	var wb: WardenBehavior = w.behavior as WardenBehavior
	assert_eq(wb.plates_left(), 3)
	await _step(5)
	var front: Vector3 = w.global_position + Vector3(sin(wb.sim.yaw), 1.5, cos(wb.sim.yaw)) * 8.0
	assert_almost_eq(_hit(rig, w, 100.0, front), 25.0, 0.01, "75 % reduction while plated")
	var plate_hp: float = wb.tuning.plate_health_fraction * w.max_health
	var broken: Array = []
	wb.plate_broken.connect(func(i: int) -> void: broken.append(i))
	var raw: float = 100.0
	while wb.plates_left() > 0 and raw < plate_hp * 4.0:
		_hit(rig, w, 500.0, front)
		raw += 500.0
	assert_eq(broken.size(), 3, "three plates broke")
	assert_almost_eq(raw, plate_hp * 3.0, 1500.0, "each plate soaks %.0f raw" % plate_hp)
	assert_true(wb.core_exposed(), "core exposed")
	assert_eq(int(w.get_meta(&"warden_plates")), 0, "replicated plate count")
	assert_almost_eq(_hit(rig, w, 100.0, front), 100.0, 0.01, "full damage from the front")
	var back: Vector3 = w.global_position - Vector3(sin(wb.sim.yaw), -1.5, cos(wb.sim.yaw)) * 8.0
	assert_almost_eq(_hit(rig, w, 100.0, back), 200.0, 0.01, "core from behind x2")
	assert_true(w.alive)


func test_attacks_telegraphed_and_damaging() -> void:
	var rig: Rig = await _build()
	var w: ZombieActor = _warden(rig, 10, 1)
	var wb: WardenBehavior = w.behavior as WardenBehavior
	var t: Node3D = rig.add_target("Player", w.global_position + Vector3(0, 0, 2.5))
	var started: Array = []
	wb.attack_started.connect(func(k: StringName, tele: float) -> void: started.append([k, tele]))
	for f: int in 180:
		await _step(1)
		if int(wb.stats["slam"]) > 0:
			break
	assert_eq(int(wb.stats["slam"]), 1, "slammed the player in reach")
	assert_gte(wb.stats["slam_hits"], 1, "slam hit")
	var slam_hit: Array = rig.hits.filter(func(h: Array) -> bool: return h[0] == t)
	assert_true(not slam_hit.is_empty() and float(slam_hit[0][1]) >= wb.tuning.slam_damage_edge, "slam damage")
	# Charge at a target 12 m away.
	await _step(70)
	t.global_position = w.global_position + Vector3(0, 0, 12.0)
	rig.hits.clear()
	wb.force_attack(&"charge")
	for f: int in 300:
		await _step(1)
		if int(wb.stats["charge"]) > 0 and wb.attack == WardenBehavior.Attack.NONE:
			break
	assert_eq(int(wb.stats["charge"]), 1, "charged")
	assert_gte(int(wb.stats["charge_hits"]), 1, "the charge ran the player over")
	# Summon.
	await _step(10)
	var before: int = rig.zombies.alive_count()
	wb.force_attack(&"summon")
	await _step(90)
	assert_eq(rig.zombies.alive_count() - before, wb.tuning.summon_count, "4 zombies summoned")
	assert_gte(wb.telegraphs.size(), 3)
	for s: float in wb.telegraphs:
		assert_gte(s, 0.6, "telegraph %.2f s >= 0.6" % s)
	for e: Array in started:
		assert_gte(float(e[1]), 0.6, "%s telegraph configured >= 0.6 s" % e[0])


func test_phases_and_coolant() -> void:
	var rig: Rig = await _build()
	var w: ZombieActor = _warden(rig, 10, 1)
	var wb: WardenBehavior = w.behavior as WardenBehavior
	await _step(5)
	var speed0: float = wb.sim.move_speed
	wb.plates.fill(0.0)
	var dbg: DamageInfo = DamageInfo.make(w.max_health * 0.36, 2, DamageInfo.Kind.BULLET, &"", 0)
	rig.targets.host_damage(w, dbg)
	assert_eq(wb.phase, 1, "phase 2 below 66 %")
	assert_gt(wb.sim.move_speed, speed0, "faster")
	rig.targets.host_damage(w, DamageInfo.make(w.max_health * 0.35, 2, DamageInfo.Kind.BULLET, &"", 0))
	assert_eq(wb.phase, 2, "phase 3 below 33 %")
	assert_eq(int(w.get_meta(&"warden_phase")), 2)
	# Coolant on a plated Warden: frozen <= 3 s, brittle plates (x2 soak), never shatters.
	var rig2: Rig = await _build()
	var w2: ZombieActor = _warden(rig2, 10, 1)
	var wb2: WardenBehavior = w2.behavior as WardenBehavior
	await _step(5)
	rig2.status.host_freeze(w2, 25.0, 1)
	assert_true(rig2.status.is_frozen(w2))
	var plate0: float = wb2.plates[0]
	var from: Vector3 = w2.global_position + Vector3(0, 1.5, 8)
	_hit(rig2, w2, 100.0, from)
	assert_almost_eq(plate0 - wb2.plates[0], 200.0, 0.01, "brittle: plate takes x2")
	assert_true(w2.alive, "shot while frozen: no shatter")
	await _step(60 * 3 + 10)
	assert_false(rig2.status.is_frozen(w2), "thawed after 3 s")
	assert_true(w2.alive)


func test_two_player_kill_time_round_20() -> void:
	var rig: Rig = await _build()
	var w: ZombieActor = _warden(rig, 20, 2, "Mark_Coolant")
	var wb: WardenBehavior = w.behavior as WardenBehavior
	var bots: Array[Node3D] = [rig.add_target("BotA", Vector3(0, 0, 12)), rig.add_target("BotB", Vector3(0, 0, -12))]
	var guns: Array[WeaponDefinition] = [WeaponCatalog.get_def(&"ak47_up"), WeaponCatalog.get_def(&"m14_up")]
	var mags: Array[int] = [guns[0].mag_size, guns[1].mag_size]
	var cool: Array[float] = [0.0, 0.0]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2012
	const HIT_RATE: float = 0.55  # moving 3 m target while kiting
	const KITE_SPEED: float = 4.0
	const RADIUS: float = 13.0
	var t: float = 0.0
	var dt: float = 1.0 / 60.0
	var shots: int = 0
	var summon_kills: int = 0
	var angle: float = 0.0
	while w.alive and t < 600.0:
		await _step(1)
		t += dt
		angle += KITE_SPEED / RADIUS * dt
		bots[0].global_position = Vector3(cos(angle) * RADIUS, 0, sin(angle) * RADIUS)
		bots[1].global_position = Vector3(cos(angle + PI * 0.8) * RADIUS, 0, sin(angle + PI * 0.8) * RADIUS)
		var dodging: bool = w.flags & ZombieActor.Flag.TELEGRAPH != 0
		for i: int in 2:
			cool[i] -= dt
			if cool[i] > 0.0 or dodging:
				continue
			if mags[i] <= 0:
				mags[i] = guns[i].mag_size
				cool[i] = guns[i].reload_empty_time
				continue
			mags[i] -= 1
			cool[i] = guns[i].fire_interval()
			shots += 1
			# Summoned zombies get shot first (they would otherwise swarm the bot).
			var adds: Array = wb.summoned.filter(
				func(z: Variant) -> bool: return is_instance_valid(z) and (z as ZombieActor).alive
			)
			if not adds.is_empty():
				var z: ZombieActor = adds[0]
				if rng.randf() < HIT_RATE:
					rig.targets.host_damage(
						z, DamageInfo.make(guns[i].damage, 2, DamageInfo.Kind.BULLET, guns[i].id, 9)
					)
					if not z.alive:
						summon_kills += 1
				continue
			if rng.randf() < HIT_RATE:
				var info: DamageInfo = DamageInfo.make(
					DamageModel.bullet_damage(guns[i], 13.0, WeaponDefinition.Hitzone.TORSO, 0),
					WeaponDefinition.Hitzone.TORSO,
					DamageInfo.Kind.BULLET,
					guns[i].id,
					9
				)
				info.position = bots[i].global_position + Vector3.UP * 1.5
				rig.targets.host_damage(w, info)
	var taken: float = 0.0
	for h: Array in rig.hits:
		taken += float(h[1])
	gut.p(
		(
			"Warden r20 2p: %.0f HP in %.1f s (%.2f min), shots %d, plates %s, attacks %s, adds killed %d, bot dmg %.0f"
			% [w.max_health, t, t / 60.0, shots, str(wb.stats["plates"]), str(wb.stats), summon_kills, taken]
		)
	)
	assert_false(w.alive, "killed")
	assert_between(t, 180.0, 360.0, "3-6 minutes")
