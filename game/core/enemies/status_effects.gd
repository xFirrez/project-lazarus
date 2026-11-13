# StatusEffects — timed zombie conditions (DEVELOPMENT_PLAN Step 11): SLOW (Glacier Breaker hits),
# BURN (Grease Fire damage over time) and FREEZE (Coolant Purge trap: the zombie stops dead and
# shatters when anything touches or shoots it, or when the freeze runs out). The HOST keeps the
# timers, scales the brain's speed (ZombieSim.speed_scale / frozen) and applies burn ticks through
# the TargetRegistry; the replicated ZombieActor flags (BURNING / FROZEN) drive every peer's visuals.
# Authority: HOST only (clients see the flags through ZombieSync snapshots).
class_name StatusEffects
extends Node

signal shattered(actor: ZombieActor, source_peer: int)

const BURN_TICK: float = 0.5
const SHATTER_TOUCH: float = 1.0  # a player this close to a frozen zombie shatters it
const BOSS_FREEZE_MAX: float = 3.0  # bosses (the Warden) thaw after at most this, never shatter

var targets: TargetRegistry = null
var players: PlayerSync = null
var effects: Dictionary = {}  # ZombieActor -> Effect
var burn_damage_total: float = 0.0
var shatters: int = 0


class Effect:
	var slow_factor: float = 0.0
	var slow_left: float = 0.0
	var burn_dps: float = 0.0
	var burn_left: float = 0.0
	var burn_peer: int = 0
	var burn_weapon: StringName = &""
	var burn_tick: float = 0.0
	var freeze_left: float = 0.0
	var freeze_peer: int = 0
	var freeze_kind: int = DamageInfo.Kind.TRAP


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


func _ready() -> void:
	name = "StatusEffects"
	process_physics_priority = 95


func _of(a: ZombieActor) -> Effect:
	if not effects.has(a):
		effects[a] = Effect.new()
	return effects[a]


func host_slow(a: ZombieActor, factor: float, seconds: float) -> void:
	if not _ok(a) or factor <= 0.0:
		return
	var e: Effect = _of(a)
	e.slow_factor = maxf(e.slow_factor, clampf(factor, 0.0, 0.95))
	e.slow_left = maxf(e.slow_left, seconds)
	_apply(a, e)


func host_burn(a: ZombieActor, dps: float, seconds: float, peer_id: int, weapon_id: StringName) -> void:
	if not _ok(a) or dps <= 0.0:
		return
	var e: Effect = _of(a)
	e.burn_dps = maxf(e.burn_dps, dps)
	e.burn_left = maxf(e.burn_left, seconds)
	e.burn_peer = peer_id
	e.burn_weapon = weapon_id
	a.set_flag(ZombieActor.Flag.BURNING, true)


# Frozen solid for `seconds` (then it shatters); `peer_id` gets the kill (trap activator).
func host_freeze(a: ZombieActor, seconds: float, peer_id: int) -> void:
	if not _ok(a):
		return
	var e: Effect = _of(a)
	if _boss(a):
		seconds = minf(seconds, BOSS_FREEZE_MAX)  # Warden: coolant chills the armor (brittle)
		if a.behavior != null:
			a.behavior.on_frozen(seconds)
	if e.freeze_left <= 0.0:
		e.freeze_left = seconds
		e.freeze_peer = peer_id
	a.set_flag(ZombieActor.Flag.FROZEN, true)
	_apply(a, e)


func is_frozen(a: ZombieActor) -> bool:
	return effects.has(a) and (effects[a] as Effect).freeze_left > 0.0


func is_slowed(a: ZombieActor) -> bool:
	return effects.has(a) and (effects[a] as Effect).slow_left > 0.0


func is_burning(a: ZombieActor) -> bool:
	return effects.has(a) and (effects[a] as Effect).burn_left > 0.0


# HOST: any damage to a frozen zombie shatters it (kills it, credited to whoever froze it).
func host_on_damaged(a: ZombieActor, kind: int) -> void:
	if a.alive and kind != DamageInfo.Kind.TRAP and is_frozen(a) and not _boss(a):
		_shatter(a)


static func _boss(a: ZombieActor) -> bool:
	return a.archetype != null and a.archetype.is_boss


func _ok(a: ZombieActor) -> bool:
	return is_authority() and a != null and is_instance_valid(a) and a.alive and a.sim != null


func _apply(a: ZombieActor, e: Effect) -> void:
	if a.sim == null:
		return
	a.sim.frozen = e.freeze_left > 0.0
	a.sim.speed_scale = 1.0 - (e.slow_factor if e.slow_left > 0.0 else 0.0)


func _physics_process(delta: float) -> void:
	if not is_authority() or effects.is_empty():
		return
	for a: Variant in effects.keys():
		var actor: ZombieActor = a as ZombieActor
		if actor == null or not is_instance_valid(actor) or not actor.alive:
			effects.erase(a)
			continue
		var e: Effect = effects[a]
		if e.slow_left > 0.0:
			e.slow_left -= delta
		if e.burn_left > 0.0:
			_tick_burn(actor, e, delta)
		if e.freeze_left > 0.0:
			e.freeze_left -= delta
			if _boss(actor) and e.freeze_left <= 0.0:
				e.freeze_left = 0.0
				actor.set_flag(ZombieActor.Flag.FROZEN, false)  # thaws: bosses never shatter
			elif not _boss(actor) and (e.freeze_left <= 0.0 or _player_touching(actor)):
				_shatter(actor)
				continue
		_apply(actor, e)
		if e.slow_left <= 0.0 and e.burn_left <= 0.0 and e.freeze_left <= 0.0:
			effects.erase(a)


func _tick_burn(a: ZombieActor, e: Effect, delta: float) -> void:
	e.burn_left -= delta
	e.burn_tick += delta
	if e.burn_tick >= BURN_TICK or e.burn_left <= 0.0:
		var dmg: float = e.burn_dps * e.burn_tick
		e.burn_tick = 0.0
		if targets != null and dmg > 0.0:
			var info: DamageInfo = DamageInfo.make(
				dmg, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.EXPLOSIVE, e.burn_weapon, e.burn_peer
			)
			burn_damage_total += dmg
			targets.host_damage(a, info)
	if e.burn_left <= 0.0 and is_instance_valid(a):
		a.set_flag(ZombieActor.Flag.BURNING, false)


func _player_touching(a: ZombieActor) -> bool:
	if players == null:
		return false
	for id: int in players.avatars:
		var p: PlayerCharacter = players.avatars[id]
		if not p.health.is_downed and p.global_position.distance_to(a.global_position) < SHATTER_TOUCH:
			return true
	return false


func _shatter(a: ZombieActor) -> void:
	var e: Effect = effects.get(a, null)
	var peer: int = e.freeze_peer if e != null else 0
	if e != null:
		e.freeze_left = 0.0
	a.set_flag(ZombieActor.Flag.FROZEN, false)
	if a.sim != null:
		a.sim.frozen = false
	shatters += 1
	shattered.emit(a, peer)
	if targets != null and a.alive:
		var info: DamageInfo = DamageInfo.make(
			maxf(a.health + 1.0, a.max_health * 3.0),
			WeaponDefinition.Hitzone.TORSO,
			DamageInfo.Kind.TRAP,
			&"shatter",
			peer
		)
		targets.host_damage(a, info)
