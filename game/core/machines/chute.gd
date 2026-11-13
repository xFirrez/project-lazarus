# Chute — a one-way shortcut (VESPER_PEAK §5 CHT, laundry chute Z05 → Z12): while its grate
# (NavDoor) is open, a player stepping into `size` (box in this node's frame) is moved by the
# host into a sealed slide tube (`tube_point`) for `travel_time` seconds, then out at
# `exit_point` (soft landing). Host-validated teleports (PlayerSync.host_teleport), so clients and
# bots behave the same. Zombies never use it (no navigation link).
# Authority: HOST detects riders and moves them.
class_name Chute
extends Node3D

@export var size: Vector3 = Vector3(1.6, 2.0, 1.6)
@export var grate_path: NodePath = ^""
@export var tube_point: Vector3 = Vector3.ZERO
@export var exit_point: Vector3 = Vector3.ZERO
@export var travel_time: float = 5.0

var grate: NavDoor = null
var riders: Dictionary = {}  # peer id -> host time of exit
var uses: int = 0


func _ready() -> void:
	add_to_group(&"chute")
	grate = get_node_or_null(grate_path) as NavDoor


func is_open() -> bool:
	return grate == null or grate.is_open


func contains(p: Vector3) -> bool:
	var l: Vector3 = to_local(p)
	var h: Vector3 = size * 0.5
	return absf(l.x) <= h.x and absf(l.y) <= h.y and absf(l.z) <= h.z


func _physics_process(_delta: float) -> void:
	var m: Match = Match.current
	if m == null or m.players == null or not MatchSession.is_authority():
		return
	var now: float = Net.host_time()
	for id: int in riders.keys():
		if now >= float(riders[id]):
			riders.erase(id)
			if m.players.avatars.has(id):
				m.players.host_teleport(id, exit_point + Vector3(0.6 * (id % 3) - 0.6, 0, 0))
	if not is_open():
		return
	for id: int in m.players.avatars:
		if riders.has(id):
			continue
		var p: PlayerCharacter = m.players.avatars[id]
		if p.spectating or p.health.is_downed or not contains(p.global_position):
			continue
		riders[id] = now + travel_time
		uses += 1
		m.players.host_teleport(id, tube_point + Vector3(1.2 * (riders.size() - 1), 0, 0))
		Audio.play_event_3d(&"chute_slide", global_position)
		Log.info(&"world", "Peer %d took %s" % [id, name])
