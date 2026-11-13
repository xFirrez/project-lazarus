# ZoneManager — the map's zone graph (ARCHITECTURE §8): which zones are unlocked (doors bought),
# which contain players (ZoneVolumes) and which are *active* for spawning: zones with a player in
# them plus their unlocked adjacent zones (VESPER_PEAK §4).
#   host -> all : `_zone_unlock` [zone]            host -> peer: `_zones_full` [[zone...]] on join
# Authority: HOST unlocks; clients mirror the unlocked set (HUD / debug only).
class_name ZoneManager
extends Node

signal zone_unlocked(zone: StringName)

var definition: MapDefinition = null
var volumes: Array[ZoneVolume] = []
var unlocked: Dictionary = {}  # zone id -> true
var players: PlayerSync = null


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


func _ready() -> void:
	name = "Zones"
	Net.register_message(&"_zone_unlock", _on_msg_unlock)
	Net.register_message(&"_zones_full", _on_msg_full)
	Net.peer_joined.connect(_on_peer_joined)


func _exit_tree() -> void:
	Net.unregister_message(&"_zone_unlock")
	Net.unregister_message(&"_zones_full")


func setup(def: MapDefinition, root: Node) -> void:
	definition = def
	for z: ZoneDef in def.zones:
		if z.start_unlocked or z.id == def.starting_zone:
			unlocked[z.id] = true
	for n: Node in root.find_children("*", "ZoneVolume", true, false):
		volumes.append(n as ZoneVolume)


func is_unlocked(zone: StringName) -> bool:
	return unlocked.has(zone)


func zone_at(p: Vector3) -> StringName:
	for v: ZoneVolume in volumes:
		if v.contains(p):
			return v.zone
	return &""


func adjacent(zone: StringName) -> Array[StringName]:
	var z: ZoneDef = definition.zone_def(zone) if definition != null else null
	return z.adjacent if z != null else ([] as Array[StringName])


# Zones that currently contain a (non-spectating) player.
func occupied_zones() -> Array[StringName]:
	var out: Array[StringName] = []
	if players == null:
		return out
	for id: int in players.avatars:
		var p: PlayerCharacter = players.avatars[id]
		if p.spectating:
			continue
		var z: StringName = zone_at(p.global_position)
		if z != &"" and not out.has(z):
			out.append(z)
	return out


# Occupied zones plus their unlocked neighbours (spawner activation, VESPER_PEAK §4).
func active_zones() -> Array[StringName]:
	var out: Array[StringName] = occupied_zones()
	for z: StringName in out.duplicate():
		for a: StringName in adjacent(z):
			if is_unlocked(a) and not out.has(a):
				out.append(a)
	if out.is_empty() and definition != null and definition.starting_zone != &"":
		out.append(definition.starting_zone)  # nobody inside a volume (e.g. mid-teleport)
	return out


func host_unlock(zone: StringName) -> void:
	if not is_authority() or zone == &"" or unlocked.has(zone):
		return
	unlocked[zone] = true
	Log.info(&"zones", "Zone %s unlocked" % zone)
	Net.send_reliable(0, &"_zone_unlock", [String(zone)])
	zone_unlocked.emit(zone)


func _on_msg_unlock(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	var z: StringName = StringName(p[0])
	if not unlocked.has(z):
		unlocked[z] = true
		zone_unlocked.emit(z)


func _on_msg_full(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	for z: Variant in p[0]:
		unlocked[StringName(z)] = true


func _on_peer_joined(peer_id: int, _info: Dictionary) -> void:
	if not Net.is_host() or peer_id == Net.local_id():
		return
	var list: Array = []
	for z: StringName in unlocked:
		list.append(String(z))
	Net.send_reliable(peer_id, &"_zones_full", [list])
