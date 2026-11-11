# PlayerSync — spawns one avatar per session peer and replicates avatar transforms.
#   owner  -> host : STREAM_PLAYER_STATE (30 Hz, unreliable) [host_time, pos, yaw]
#   host   -> all  : STREAM_PLAYER_SNAPSHOT (20 Hz, unreliable) [n, (id, stamp, pos, yaw)*n]
# Each entry carries the host-clock time at which that position was valid, so relayed client
# positions are not mis-stamped by the relay delay.
# Remote avatars render through an InterpolationBuffer (~100 ms behind arrival).
# Authority: owner-authoritative movement; the host relays (validation arrives in Step 2).
# Identical on solo and co-op: with no remote peers the sends are simply no-ops.
class_name PlayerSync
extends Node3D

signal avatar_spawned(peer_id: int, avatar: TempCapsule)
signal avatar_removed(peer_id: int)

const STREAM_PLAYER_STATE: int = 16
const STREAM_PLAYER_SNAPSHOT: int = 17
const STATE_RATE: float = 30.0
const SNAPSHOT_RATE: float = 20.0

var avatars: Dictionary = {}  # peer_id -> TempCapsule
var spawn_points: Array[Vector3] = []

var _state_timer: float = 0.0
var _snapshot_timer: float = 0.0
var _latest: Dictionary = {}  # host only: peer_id -> [stamp: float, pos: Vector3, yaw: float]


func _ready() -> void:
	name = "PlayerSync"
	# Run after the avatars have moved this frame so sent states are stamped correctly.
	process_physics_priority = 100
	Net.register_stream(STREAM_PLAYER_STATE, _on_player_state)
	Net.register_stream(STREAM_PLAYER_SNAPSHOT, _on_player_snapshot)
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	for id: int in Net.peer_ids():
		_spawn(id, Net.peers[id])


func _exit_tree() -> void:
	Net.unregister_stream(STREAM_PLAYER_STATE)
	Net.unregister_stream(STREAM_PLAYER_SNAPSHOT)


func local_avatar() -> TempCapsule:
	return avatars.get(Net.local_id(), null)


func _physics_process(delta: float) -> void:
	var me: TempCapsule = local_avatar()
	if me != null:
		if Net.is_host():
			_latest[me.peer_id] = [Net.host_time(), me.global_position, me.yaw]
		_state_timer -= delta
		if _state_timer <= 0.0:
			_state_timer += 1.0 / STATE_RATE
			if not Net.is_host():
				var buf: StreamPeerBuffer = StreamPeerBuffer.new()
				buf.put_double(Net.host_time())
				_put_vec(buf, me.global_position)
				buf.put_float(me.yaw)
				Net.send_unreliable(1, STREAM_PLAYER_STATE, buf.data_array)
	if Net.is_host():
		_snapshot_timer -= delta
		if _snapshot_timer <= 0.0:
			_snapshot_timer += 1.0 / SNAPSHOT_RATE
			_send_snapshot()


func _send_snapshot() -> void:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.put_u8(_latest.size())
	for id: int in _latest:
		var entry: Array = _latest[id]
		buf.put_u32(id)
		buf.put_double(entry[0])
		_put_vec(buf, entry[1])
		buf.put_float(entry[2])
	Net.send_unreliable(0, STREAM_PLAYER_SNAPSHOT, buf.data_array)


func _on_player_state(sender: int, bytes: PackedByteArray) -> void:
	if not Net.is_host() or not avatars.has(sender):
		return
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.data_array = bytes
	var stamp: float = buf.get_double()
	var pos: Vector3 = _get_vec(buf)
	var yaw: float = buf.get_float()
	_latest[sender] = [stamp, pos, yaw]
	(avatars[sender] as TempCapsule).buffer.push(stamp, pos, yaw, Net.now())


func _on_player_snapshot(_sender: int, bytes: PackedByteArray) -> void:
	if Net.is_host():
		return
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.data_array = bytes
	var count: int = buf.get_u8()
	var local_now: float = Net.now()
	for i: int in count:
		var id: int = buf.get_u32()
		var stamp: float = buf.get_double()
		var pos: Vector3 = _get_vec(buf)
		var yaw: float = buf.get_float()
		if id != Net.local_id() and avatars.has(id):
			(avatars[id] as TempCapsule).buffer.push(stamp, pos, yaw, local_now)


func _on_peer_joined(peer_id: int, info: Dictionary) -> void:
	if not avatars.has(peer_id):
		_spawn(peer_id, info)


func _on_peer_left(peer_id: int) -> void:
	_latest.erase(peer_id)
	if avatars.has(peer_id):
		var avatar: TempCapsule = avatars[peer_id]
		avatars.erase(peer_id)
		avatar.queue_free()
		Audio.play_event(&"net_peer_left")
		Log.info(&"players", "Removed avatar for peer %d" % peer_id)
		avatar_removed.emit(peer_id)


func _spawn(peer_id: int, info: Dictionary) -> void:
	var avatar: TempCapsule = TempCapsule.new()
	avatar.peer_id = peer_id
	avatar.is_local = peer_id == Net.local_id()
	avatar.display_name = String(info.get("name", "Peer %d" % peer_id))
	avatar.slot = avatars.size()
	var spawn: Vector3 = Vector3(0, 1, 0)
	if not spawn_points.is_empty():
		spawn = spawn_points[(Net.peer_ids().find(peer_id) + spawn_points.size()) % spawn_points.size()]
	avatar.position = spawn
	avatars[peer_id] = avatar
	add_child(avatar)
	Audio.play_event(&"net_peer_joined")
	Log.info(&"players", "Spawned avatar for peer %d (%s)" % [peer_id, "local" if avatar.is_local else "remote"])
	avatar_spawned.emit(peer_id, avatar)


static func _put_vec(buf: StreamPeerBuffer, v: Vector3) -> void:
	buf.put_float(v.x)
	buf.put_float(v.y)
	buf.put_float(v.z)


static func _get_vec(buf: StreamPeerBuffer) -> Vector3:
	var x: float = buf.get_float()
	var y: float = buf.get_float()
	var z: float = buf.get_float()
	return Vector3(x, y, z)
