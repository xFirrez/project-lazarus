# HitTarget — anything weapons can damage (dummies now, zombies in Step 5). Owns its Hurtboxes,
# health and alive state. The HOST applies damage (`host_apply`) after HitValidator accepted a
# claim and TargetRegistry broadcasts the result; other peers mirror it (`apply_remote`).
# `max_health <= 0` means indestructible (records damage, never dies) — used by range dummies.
# Authority: host-authoritative health; registration ids are shared (TargetRegistry).
class_name HitTarget
extends Node3D

signal damaged(amount: float, zone: int, kind: int, source_peer: int)
signal died(source_peer: int)
signal revived

@export var max_health: float = 0.0
@export var respawn_time: float = 3.0

var target_id: int = -1
var health: float = 0.0
var alive: bool = true
var hurtboxes: Array[Hurtbox] = []
# Host-side record of applied damage, for tests and the gun range ([amount, zone, kind]).
var damage_log: Array[Array] = []
var total_damage: float = 0.0


func _ready() -> void:
	add_to_group(&"hit_target")
	health = max_health


func is_indestructible() -> bool:
	return max_health <= 0.0


func add_hurtbox(zone: int, shape: Shape3D, local_pos: Vector3, parent: Node3D = null) -> Hurtbox:
	var hb: Hurtbox = Hurtbox.create(self, zone, shape, local_pos)
	(parent if parent != null else self).add_child(hb)
	hurtboxes.append(hb)
	return hb


func hurtbox_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for hb: Hurtbox in hurtboxes:
		rids.append(hb.get_rid())
	return rids


# World position of the hurtbox for a zone (LOS checks); falls back to the target origin.
func zone_position(zone: int) -> Vector3:
	for hb: Hurtbox in hurtboxes:
		if hb.zone == zone:
			return hb.global_position
	return global_position + Vector3.UP


# Health as the local peer believes it (host: authoritative; clients: last replicated value).
func predicted_lethal(amount: float) -> bool:
	return alive and not is_indestructible() and amount >= health


# HOST: applies damage, returns the amount applied (clamped to remaining health unless indestructible).
func host_apply(info: DamageInfo) -> float:
	if not alive or info.amount <= 0.0:
		return 0.0
	var applied: float = info.amount if is_indestructible() else minf(info.amount, health)
	damage_log.append([info.amount, info.zone, info.kind])
	total_damage += info.amount
	if not is_indestructible():
		health -= applied
	_on_damaged(info.amount, info.zone, info.kind, info.source_peer)
	if not is_indestructible() and health <= 0.0:
		health = 0.0
		_set_alive(false, info.source_peer)
	return applied


# Mirrors the host's result on clients.
func apply_remote(new_health: float, amount: float, zone: int, kind: int, source_peer: int, is_alive: bool) -> void:
	health = new_health
	if amount > 0.0:
		total_damage += amount
		_on_damaged(amount, zone, kind, source_peer)
	if is_alive != alive:
		_set_alive(is_alive, source_peer)


func host_revive() -> void:
	health = max_health
	_set_alive(true, 0)


func _on_damaged(amount: float, zone: int, kind: int, source_peer: int) -> void:
	damaged.emit(amount, zone, kind, source_peer)


func _set_alive(on: bool, source_peer: int) -> void:
	alive = on
	if on:
		health = max_health
		revived.emit()
	else:
		died.emit(source_peer)
