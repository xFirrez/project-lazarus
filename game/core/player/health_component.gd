# HealthComponent — HP, damage intake, regeneration (GAME_DESIGN §3.2) and the downed hook.
# Authority: the HOST applies damage and decides downed; every peer runs the same deterministic
# regen tick so HUDs agree between the host's reliable health events (PlayerSync).
class_name HealthComponent
extends Node

signal damaged(amount: float, source_position: Vector3, type: int)
signal health_changed(health: float, max_health: float)
signal downed

enum DamageType { GENERIC, ZOMBIE, EXPLOSIVE, FALL }

var tuning: PlayerTuning = null
var max_health: float = 100.0
var health: float = 100.0
var invulnerable: bool = false  # debug `god`
var is_downed: bool = false
var time_since_damage: float = 1000.0


func setup(p_tuning: PlayerTuning) -> void:
	tuning = p_tuning
	max_health = tuning.max_health
	health = max_health


func fraction() -> float:
	return health / maxf(max_health, 1.0)


func is_low() -> bool:
	return fraction() < tuning.low_health_fraction


# Host-side damage entry point. Returns the damage actually applied.
func apply_damage(amount: float, source_position: Vector3, type: int = DamageType.GENERIC) -> float:
	if amount <= 0.0 or is_downed or invulnerable:
		return 0.0
	var applied: float = minf(amount, health)
	health -= applied
	time_since_damage = 0.0
	damaged.emit(applied, source_position, type)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		health = 0.0
		is_downed = true
		downed.emit()
	return applied


# Mirrors an authoritative health event from the host (clients), including the feedback signal.
func apply_remote(new_health: float, damage: float, source_position: Vector3, type: int) -> void:
	health = clampf(new_health, 0.0, max_health)
	if damage > 0.0:
		time_since_damage = 0.0
		damaged.emit(damage, source_position, type)
	is_downed = health <= 0.0
	health_changed.emit(health, max_health)


# Revive (host): back up with a fraction of max health.
func revive(fraction: float) -> void:
	is_downed = false
	health = max_health * clampf(fraction, 0.01, 1.0)
	time_since_damage = 0.0
	health_changed.emit(health, max_health)


func restore_full() -> void:
	is_downed = false
	health = max_health
	time_since_damage = 1000.0
	health_changed.emit(health, max_health)


func tick(delta: float) -> void:
	time_since_damage += delta
	if is_downed or health >= max_health:
		return
	if time_since_damage >= tuning.regen_delay:
		health = minf(health + tuning.regen_rate * delta, max_health)
		health_changed.emit(health, max_health)
