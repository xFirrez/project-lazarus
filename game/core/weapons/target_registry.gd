# TargetRegistry — ids and health replication for every HitTarget in the match.
# Map-placed targets are registered in tree order after the map is built, so every peer derives
# the same ids without messages; dynamic targets (zombies, Step 5) use host-assigned ids.
#   host -> all : `_target_health` (reliable) [id, health, amount, zone, kind, peer, alive]
#   host -> peer: `_targets_full`  (reliable) [[id, health, alive]...]  on join (late join)
# Authority: host applies damage and respawns; clients mirror.
class_name TargetRegistry
extends Node

signal target_damaged(target: HitTarget, amount: float, zone: int, kind: int, source_peer: int)
signal target_killed(target: HitTarget, source_peer: int)

var targets: Dictionary = {}  # id -> HitTarget
var _next_id: int = 1


func _ready() -> void:
	name = "Targets"
	Net.register_message(&"_target_health", _on_msg_health)
	Net.register_message(&"_targets_full", _on_msg_full)
	Net.peer_joined.connect(_on_peer_joined)


func _exit_tree() -> void:
	Net.unregister_message(&"_target_health")
	Net.unregister_message(&"_targets_full")


func scan(root: Node) -> void:
	for node: Node in root.find_children("*", "", true, false):
		if node is HitTarget:
			register(node as HitTarget)


func register(t: HitTarget, forced_id: int = -1) -> int:
	t.target_id = forced_id if forced_id > 0 else _next_id
	_next_id = maxi(_next_id, t.target_id + 1)
	targets[t.target_id] = t
	if not t.has_meta(&"_target_registry"):
		t.set_meta(&"_target_registry", true)
		t.tree_exiting.connect(unregister.bind(t))
	return t.target_id


# Removes a target (dead zombies leave as corpses; their id may be reused by a new spawn).
func unregister(t: HitTarget) -> void:
	if targets.get(t.target_id, null) == t:
		targets.erase(t.target_id)


func get_target(id: int) -> HitTarget:
	var t: HitTarget = targets.get(id, null)
	return t if t != null and is_instance_valid(t) else null


# HOST: applies validated damage and broadcasts the result. Returns damage applied.
func host_damage(t: HitTarget, info: DamageInfo) -> float:
	if not Net.is_host() and Net.is_active():
		return 0.0
	var was_alive: bool = t.alive
	var applied: float = t.host_apply(info)
	if info.amount <= 0.0 or not was_alive:
		return applied
	Net.send_reliable(
		0, &"_target_health", [t.target_id, t.health, info.amount, info.zone, info.kind, info.source_peer, t.alive]
	)
	target_damaged.emit(t, info.amount, info.zone, info.kind, info.source_peer)
	if not t.alive:
		target_killed.emit(t, info.source_peer)
		if t.respawn_time > 0.0:
			_respawn_later(t)
	return applied


func host_reset_all() -> void:
	for id: int in targets:
		var t: HitTarget = get_target(id)
		if t == null:
			continue
		t.host_revive()
		t.damage_log.clear()
		t.total_damage = 0.0
		Net.send_reliable(0, &"_target_health", [id, t.health, 0.0, 0, 0, 0, true])


func _respawn_later(t: HitTarget) -> void:
	await get_tree().create_timer(t.respawn_time).timeout
	if is_instance_valid(t) and not t.alive:
		t.host_revive()
		Net.send_reliable(0, &"_target_health", [t.target_id, t.health, 0.0, 0, 0, 0, true])


func _on_msg_health(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	var t: HitTarget = get_target(int(p[0]))
	if t != null:
		t.apply_remote(float(p[1]), float(p[2]), int(p[3]), int(p[4]), int(p[5]), bool(p[6]))
		if float(p[2]) > 0.0:
			target_damaged.emit(t, float(p[2]), int(p[3]), int(p[4]), int(p[5]))


func _on_msg_full(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	for entry: Variant in p[0]:
		var e: Array = entry
		var t: HitTarget = get_target(int(e[0]))
		if t != null:
			t.apply_remote(float(e[1]), 0.0, 0, 0, 0, bool(e[2]))


func _on_peer_joined(peer_id: int, _info: Dictionary) -> void:
	if not Net.is_host() or peer_id == Net.local_id():
		return
	var list: Array = []
	for id: int in targets:
		var t: HitTarget = get_target(id)
		if t != null:
			list.append([id, t.health, t.alive])
	Net.send_reliable(peer_id, &"_targets_full", [list])
