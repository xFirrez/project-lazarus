# GalvanicBehavior — the Galvanic special enemy's brain (GAME_DESIGN §5.3, DEVELOPMENT_PLAN Step
# 12B): a 6 m/s sprinter that leaps at its target from 3–6 m. The leap is telegraphed for
# `leap_telegraph` (>= 0.6 s; the TELEGRAPH flag makes every peer crackle and flash the electrodes),
# then the Galvanic arcs through the air for `leap_time` and hits whoever is within
# `leap_hit_radius` of the landing point (`leap_damage`). The death burst and the plank disable
# are SpecialRoundDirector's (zombie_died). Everything else is the ordinary zombie brain.
# Authority: HOST only.
class_name GalvanicBehavior
extends ZombieBehavior

enum Phase { NONE, TELEGRAPH, AIR }

var phase: Phase = Phase.NONE
var phase_time: float = 0.0
var cooldown: float = 1.0
var leaps: int = 0  # statistics / tests
var leap_hits: int = 0
var telegraph_seconds: float = 0.0  # last telegraph's measured length (tests)

var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _victim: Node3D = null


func think(dt: float) -> bool:
	cooldown -= dt
	if phase != Phase.NONE:
		return true
	if cooldown > 0.0 or sim.state != ZombieSim.State.PURSUE or sim.target == null or actor().is_crawler():
		return false
	if sim.director.is_attractor(sim.target) or sim.director.is_downed(sim.target):
		return false
	var tp: Vector3 = sim.target.global_position
	var d: float = flat_distance_to(tp)
	if d < arch().leap_min or d > arch().leap_max or absf(tp.y - sim.pos.y) > 1.0:
		return false
	_begin_telegraph()
	return true


func _begin_telegraph() -> void:
	phase = Phase.TELEGRAPH
	phase_time = 0.0
	_victim = sim.target
	actor().set_flag(ZombieActor.Flag.TELEGRAPH, true)
	actor().start_action(ZombieActor.Action.WAIT)
	Audio.play_event_3d(&"galvanic_crackle", sim.pos)


func move(dt: float) -> bool:
	if phase == Phase.NONE:
		return false
	phase_time += dt
	if sim.frozen:
		return true
	if phase == Phase.TELEGRAPH:
		sim.velocity = Vector3.ZERO
		actor().speed = 0.0
		if _victim != null and is_instance_valid(_victim):
			sim._face(_victim.global_position - sim.pos, dt)
		if phase_time >= arch().leap_telegraph:
			telegraph_seconds = phase_time
			_launch()
		return true
	# Airborne: straight line to the landing point with a parabolic hop.
	var t: float = clampf(phase_time / maxf(arch().leap_time, 0.05), 0.0, 1.0)
	var p: Vector3 = _from.lerp(_to, t)
	p.y += sin(t * PI) * 1.1
	sim.pos = p
	actor().speed = _from.distance_to(_to) / maxf(arch().leap_time, 0.05)
	if t >= 1.0:
		_land()
	return true


func _launch() -> void:
	phase = Phase.AIR
	phase_time = 0.0
	leaps += 1
	actor().set_flag(ZombieActor.Flag.TELEGRAPH, false)
	actor().start_action(ZombieActor.Action.DROP)
	_from = sim.pos
	var aim: Vector3 = _victim.global_position if _victim != null and is_instance_valid(_victim) else sim.pos
	var dir: Vector3 = aim - _from
	dir.y = 0.0
	var d: float = dir.length()
	# Land just short of the target (0.6 m), never farther than the leap range.
	var land: Vector3 = _from + dir / maxf(d, 0.001) * clampf(d - 0.6, 0.0, arch().leap_max)
	land.y = aim.y
	_to = sim.director.snap(land, _from)
	Audio.play_event_3d(&"galvanic_leap", sim.pos)


func _land() -> void:
	phase = Phase.NONE
	cooldown = arch().leap_cooldown
	sim.pos = _to
	actor().start_action(ZombieActor.Action.NONE)
	for t: Node3D in players_near(_to, arch().leap_hit_radius):
		sim.director.damage_target(t, arch().leap_damage, _to + Vector3.UP * 1.0)
		leap_hits += 1
	sim.attack_cooldown = arch().attack_cooldown * 0.5
	sim._enter(ZombieSim.State.PURSUE)
	sim.path_age = INF


func on_stunned() -> void:
	if phase != Phase.NONE:
		phase = Phase.NONE
		cooldown = arch().leap_cooldown
		actor().set_flag(ZombieActor.Flag.TELEGRAPH, false)
		if phase_time > 0.0:
			sim.pos = sim.director.snap(sim.pos, _from)
