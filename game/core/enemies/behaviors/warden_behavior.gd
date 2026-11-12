# WardenBehavior — the Warden boss (GAME_DESIGN §5.4, DEVELOPMENT_PLAN Step 12B scope 5): a 3 m
# armored brute. Armor: `plate_count` plates each soak raw damage up to `plate_health_fraction` of
# max health; while any plate holds, the body takes `plate_reduction` less. With every plate broken
# the vesperite core on its back is exposed: hits from behind (within `core_arc_deg` of its back)
# deal `core_multiplier`. Attacks, each telegraphed (TELEGRAPH flag, >= 0.6 s, AC-12.5):
#   SLAM    target within `slam_range`: shockwave, players within `slam_radius` (falloff);
#   CHARGE  phase >= 2, target 7–20 m away: a straight run, hits players in its path, then a long
#           recovery (the damage window);
#   SUMMON  pulse that raises `summon_count` zombies around it.
# Phases at the health thresholds speed it up and shorten cooldowns. Coolant (Coolant Purge trap /
# StatusEffects freeze) holds it for at most 3 s and makes the plates brittle; it never shatters and
# shrugs off staggers (stuns last `stun_immunity`).
# Replicated: plates / phase / core through `_warden` [net_id, plates_left, phase] (SpecialEnemies),
# attacks through the actor flags + action, effects through WonderFx.
# Authority: HOST only.
class_name WardenBehavior
extends ZombieBehavior

signal plate_broken(index: int)
signal phase_changed(phase: int)
signal attack_started(kind: StringName, telegraph: float)

enum Attack { NONE, SLAM, CHARGE, SUMMON }

const ATTACK_NAMES: Array[StringName] = [&"none", &"slam", &"charge", &"summon"]

var tuning: WardenTuning = null
var plates: PackedFloat32Array = []  # remaining raw soak per plate
var phase: int = 0
var attack: Attack = Attack.NONE
var attack_stage: int = 0  # 0 telegraph, 1 active, 2 recover
var attack_time: float = 0.0
var cooldowns: Dictionary = {Attack.SLAM: 2.0, Attack.CHARGE: 4.0, Attack.SUMMON: 8.0}
var frozen_brittle: float = 0.0
var round_number: int = 1
var stats: Dictionary = {"slam": 0, "charge": 0, "summon": 0, "slam_hits": 0, "charge_hits": 0, "plates": 0}
var telegraphs: Array[float] = []  # measured telegraph lengths (tests: every one >= 0.6 s)
var summoned: Array[ZombieActor] = []

var _charge_dir: Vector3 = Vector3.ZERO
var _charge_hit: Dictionary = {}
var _charge_start: Vector3 = Vector3.ZERO


func setup() -> void:
	tuning = arch().boss_tuning if arch().boss_tuning != null else WardenTuning.new()
	plates.resize(tuning.plate_count)
	for i: int in plates.size():
		plates[i] = tuning.plate_health_fraction * actor().max_health
	round_number = int(actor().get_meta(&"round", 1))
	sim.move_speed = tuning.phase_speed[0]
	_publish()


# --- armor --------------------------------------------------------------------------------------


func plates_left() -> int:
	var n: int = 0
	for p: float in plates:
		if p > 0.0:
			n += 1
	return n


func core_exposed() -> bool:
	return plates_left() == 0


func filter_damage(info: DamageInfo) -> float:
	if info.kind == DamageInfo.Kind.DEBUG:
		return info.amount
	var amount: float = info.amount
	if not core_exposed():
		var soak: float = amount * (tuning.frozen_plate_multiplier if frozen_brittle > 0.0 else 1.0)
		for i: int in plates.size():
			if plates[i] > 0.0:
				plates[i] -= soak
				if plates[i] <= 0.0:
					plates[i] = 0.0
					_on_plate_broken(i)
				break
		return amount * (1.0 - tuning.plate_reduction)
	if _from_behind(info):
		amount *= tuning.core_multiplier
	return amount


func _from_behind(info: DamageInfo) -> bool:
	var src: Vector3 = info.position
	if src == Vector3.ZERO or info.kind != DamageInfo.Kind.EXPLOSIVE:
		var pl: PlayerSync = sim.director.players
		if pl != null and pl.avatars.has(info.source_peer):
			src = (pl.avatars[info.source_peer] as Node3D).global_position
		elif info.position != Vector3.ZERO:
			src = info.position
		else:
			return false
	var to_src: Vector3 = src - sim.pos
	to_src.y = 0.0
	if to_src.length_squared() < 0.01:
		return false
	var facing: Vector3 = Vector3(sin(sim.yaw), 0.0, cos(sim.yaw))  # models face +Z
	var ang: float = rad_to_deg(acos(clampf((-facing).dot(to_src.normalized()), -1.0, 1.0)))
	return ang <= tuning.core_arc_deg


func _on_plate_broken(i: int) -> void:
	stats["plates"] = int(stats["plates"]) + 1
	plate_broken.emit(i)
	Audio.play_event_3d(&"warden_plate", sim.pos)
	WonderFx.play(
		actor(), WonderFx.Kind.SPARKS, PackedVector3Array([sim.pos + Vector3.UP * 2.0]), 1.0, WonderFx.Variant.METAL
	)
	_publish()


func on_damaged(_info: DamageInfo, survives: bool) -> void:
	if not survives:
		return
	var frac: float = actor().health / maxf(actor().max_health, 1.0)
	var want: int = 0
	for t: float in tuning.phase_thresholds:
		if frac <= t:
			want += 1
	if want > phase:
		phase = want
		sim.move_speed = tuning.phase_speed[mini(phase, tuning.phase_speed.size() - 1)]
		phase_changed.emit(phase)
		Audio.play_event_3d(&"warden_roar", sim.pos)
		_publish()


func can_stagger() -> bool:
	return false


func stun_time(seconds: float) -> float:
	return seconds * tuning.stun_immunity


func on_frozen(seconds: float) -> void:
	frozen_brittle = seconds
	_end_attack()


# --- attacks ------------------------------------------------------------------------------------


func think(dt: float) -> bool:
	for k: Variant in cooldowns.keys():
		cooldowns[k] = float(cooldowns[k]) - dt
	if frozen_brittle > 0.0:
		frozen_brittle -= dt
	if attack != Attack.NONE:
		return true
	if sim.state != ZombieSim.State.PURSUE or sim.target == null or sim.director.is_attractor(sim.target):
		return false
	var tp: Vector3 = sim.target.global_position
	var d: float = flat_distance_to(tp)
	if d <= tuning.slam_range and float(cooldowns[Attack.SLAM]) <= 0.0:
		_begin(Attack.SLAM, tuning.slam_telegraph)
		return true
	if phase >= 1 and d >= tuning.charge_min and d <= tuning.charge_max and float(cooldowns[Attack.CHARGE]) <= 0.0:
		_begin(Attack.CHARGE, tuning.charge_telegraph)
		return true
	if d >= tuning.summon_min_distance and float(cooldowns[Attack.SUMMON]) <= 0.0:
		_begin(Attack.SUMMON, tuning.summon_telegraph)
		return true
	return false


# Debug / tests: force an attack now (ignores range and cooldown).
func force_attack(kind: StringName) -> void:
	_end_attack()
	match kind:
		&"slam":
			_begin(Attack.SLAM, tuning.slam_telegraph)
		&"charge":
			_begin(Attack.CHARGE, tuning.charge_telegraph)
		&"summon":
			_begin(Attack.SUMMON, tuning.summon_telegraph)


func _begin(a: Attack, telegraph: float) -> void:
	attack = a
	attack_stage = 0
	attack_time = 0.0
	sim.velocity = Vector3.ZERO
	actor().set_flag(ZombieActor.Flag.TELEGRAPH, true)
	actor().start_action(ZombieActor.Action.ATTACK if a == Attack.SLAM else ZombieActor.Action.WAIT)
	attack_started.emit(ATTACK_NAMES[a], telegraph)
	Audio.play_event_3d(&"warden_telegraph", sim.pos)


func move(dt: float) -> bool:
	if attack == Attack.NONE:
		return false
	attack_time += dt
	actor().speed = 0.0
	match attack:
		Attack.SLAM:
			_move_slam(dt)
		Attack.CHARGE:
			_move_charge(dt)
		Attack.SUMMON:
			_move_summon(dt)
	return true


func _face_target(dt: float) -> void:
	if sim.target != null and is_instance_valid(sim.target):
		sim._face(sim.target.global_position - sim.pos, dt)


func _telegraph_done(seconds: float) -> bool:
	if attack_stage != 0 or attack_time < seconds:
		return false
	telegraphs.append(attack_time)
	actor().set_flag(ZombieActor.Flag.TELEGRAPH, false)
	attack_stage = 1
	attack_time = 0.0
	return true


func _move_slam(dt: float) -> void:
	if attack_stage == 0:
		_face_target(dt)
		if _telegraph_done(tuning.slam_telegraph):
			stats["slam"] = int(stats["slam"]) + 1
			for t: Node3D in players_near(sim.pos, tuning.slam_radius):
				var d: float = t.global_position.distance_to(sim.pos)
				var dmg: float = lerpf(
					tuning.slam_damage, tuning.slam_damage_edge, clampf(d / tuning.slam_radius, 0.0, 1.0)
				)
				sim.director.damage_target(t, dmg, sim.pos)
				stats["slam_hits"] = int(stats["slam_hits"]) + 1
			WonderFx.play(
				actor(), WonderFx.Kind.RING, PackedVector3Array([sim.pos]), tuning.slam_radius, WonderFx.Variant.METAL
			)
			Audio.play_event_3d(&"warden_slam", sim.pos)
			attack_stage = 2
	elif attack_time >= tuning.slam_recover:
		_finish(Attack.SLAM, tuning.slam_cooldown)


func _move_charge(dt: float) -> void:
	match attack_stage:
		0:
			_face_target(dt)
			if _telegraph_done(tuning.charge_telegraph):
				stats["charge"] = int(stats["charge"]) + 1
				var to: Vector3 = (sim.target.global_position if sim.target != null else sim.pos) - sim.pos
				to.y = 0.0
				_charge_dir = to.normalized() if to.length() > 0.1 else Vector3(sin(sim.yaw), 0, cos(sim.yaw))
				_charge_hit.clear()
				_charge_start = sim.pos
				Audio.play_event_3d(&"warden_charge", sim.pos)
		1:
			var before: Vector3 = sim.pos
			sim.pos = sim.director.snap(sim.pos + _charge_dir * tuning.charge_speed * dt, sim.pos)
			actor().speed = tuning.charge_speed
			sim._face(_charge_dir, dt)
			for t: Node3D in players_near(sim.pos, tuning.charge_hit_radius):
				if not _charge_hit.has(t):
					_charge_hit[t] = true
					sim.director.damage_target(t, tuning.charge_damage, sim.pos)
					stats["charge_hits"] = int(stats["charge_hits"]) + 1
			var blocked: bool = sim.pos.distance_to(before) < tuning.charge_speed * dt * 0.3
			if attack_time >= tuning.charge_time or blocked:
				attack_stage = 2
				attack_time = 0.0
				actor().start_action(ZombieActor.Action.STAGGER)
		2:
			if attack_time >= tuning.charge_recover:
				_finish(Attack.CHARGE, tuning.charge_cooldown)


func _move_summon(dt: float) -> void:
	if attack_stage == 0:
		_face_target(dt)
		if _telegraph_done(tuning.summon_telegraph):
			stats["summon"] = int(stats["summon"]) + 1
			_summon()
			attack_stage = 2
	elif attack_time >= 0.6:
		_finish(Attack.SUMMON, tuning.summon_cooldown)


func _summon() -> void:
	WonderFx.play(actor(), WonderFx.Kind.RING, PackedVector3Array([sim.pos]), 8.0, WonderFx.Variant.GREEN)
	Audio.play_event_3d(&"warden_summon", sim.pos)
	var zs: ZombieSync = ZombieSync.instance(actor())
	if zs == null:
		return
	var base: ZombieArchetype = zs.archetype(&"zombie")
	for i: int in tuning.summon_count:
		var a: float = TAU * float(i) / float(tuning.summon_count) + sim.yaw
		var p: Vector3 = sim.director.snap(sim.pos + Vector3(cos(a), 0.0, sin(a)) * 3.0, sim.pos)
		var z: ZombieActor = zs.host_spawn(
			base, ZombieArchetype.Tier.RUN, p, a, ZombieSpawner.Kind.RISER, -1, base.health_for_round(round_number)
		)
		if z != null:
			summoned.append(z)


func _finish(a: Attack, cooldown: float) -> void:
	cooldowns[a] = cooldown * tuning.phase_cooldown_scale[mini(phase, tuning.phase_cooldown_scale.size() - 1)]
	_end_attack()


func _end_attack() -> void:
	attack = Attack.NONE
	attack_stage = 0
	attack_time = 0.0
	if sim != null:
		actor().set_flag(ZombieActor.Flag.TELEGRAPH, false)
		actor().start_action(ZombieActor.Action.NONE)
		sim._enter(ZombieSim.State.PURSUE)
		sim.path_age = INF


func _publish() -> void:
	var a: ZombieActor = actor()
	a.set_meta(&"warden_plates", plates_left())
	a.set_meta(&"warden_phase", phase)
	if Net.is_active() and Net.is_host():
		Net.send_reliable(0, &"_warden", [a.net_id, plates_left(), phase])


# --- spawning -----------------------------------------------------------------------------------


# Max health for round r with p players (GAME_DESIGN §5.4: 25 x base zombie health, co-op x p).
static func health_for(warden: ZombieArchetype, base: ZombieArchetype, r: int, p: int) -> float:
	var factor: float = warden.boss_tuning.health_factor if warden.boss_tuning != null else 25.0
	return roundf(factor * base.health_for_round(r) * maxi(p, 1))


# HOST: spawns a Warden for round r (debug `spawn_warden`, the late-round rule, Step 14's finale).
static func host_spawn(zs: ZombieSync, pos: Vector3, yaw: float, r: int, p: int) -> ZombieActor:
	var w: ZombieArchetype = zs.archetype(&"warden")
	if w == null or w.id != &"warden":
		return null
	var hp: float = health_for(w, zs.archetype(&"zombie"), r, p)
	zs.pending_meta = {&"round": r}
	var a: ZombieActor = zs.host_spawn(w, ZombieArchetype.Tier.WALK, pos, yaw, ZombieSpawner.Kind.WINDOW, 0, hp)
	zs.pending_meta = {}
	return a
