# PlayerSync — spawns one PlayerCharacter per session peer, replicates movement and health.
#   owner -> host : STREAM_PLAYER_STATE (30 Hz, unreliable) [host_time, pos, yaw, pitch, flags, seq]
#   host  -> all  : STREAM_PLAYER_SNAPSHOT (20 Hz, unreliable) [n, (id, stamp, pos, yaw, pitch, flags)*n]
#   host  -> owner: `_player_correct` (reliable) [seq, pos]  movement validation failed / teleport
#   host  -> all  : `_player_health` (reliable) [id, hp, damage, src, type]  on damage/heal/downed
#   owner -> host : `_player_fall` (reliable) [height]   fall-damage claim (host clamps + applies)
#   any   -> host : `_player_tp` (reliable) [pos]        debug teleport request
# Entries carry the host-clock time at which that position was valid (D-011).
# Authority: owner-authoritative movement validated by the host (MovementValidator); health is
# host-authoritative. Solo and co-op run the same code: with no remote peers sends are no-ops.
class_name PlayerSync
extends Node3D

signal avatar_spawned(peer_id: int, avatar: PlayerCharacter)
signal avatar_removed(peer_id: int)
signal corrected(peer_id: int, reason: String)

const STREAM_PLAYER_STATE: int = 16
const STREAM_PLAYER_SNAPSHOT: int = 17
const STATE_RATE: float = 30.0
const SNAPSHOT_RATE: float = 20.0
const PLAYER_SCENE: PackedScene = preload("res://core/player/player_character.tscn")
const DOWNED_PLACEHOLDER_REVIVE_S: float = 3.0

var avatars: Dictionary = {}  # peer_id -> PlayerCharacter
var spawn_points: Array[Vector3] = []
var spawn_yaw: float = 0.0
var validators: Dictionary = {}  # host only: peer_id -> MovementValidator
var corrections_received: int = 0  # owner side

var _state_timer: float = 0.0
var _snapshot_timer: float = 0.0
var _latest: Dictionary = {}  # host only: peer_id -> [stamp, pos, yaw, pitch, flags]
var _correction_seq: int = 0  # owner side: sequence of the last applied correction


func _ready() -> void:
	name = "PlayerSync"
	# Run after the avatars have moved this frame so sent states are stamped correctly.
	process_physics_priority = 100
	Net.register_stream(STREAM_PLAYER_STATE, _on_player_state)
	Net.register_stream(STREAM_PLAYER_SNAPSHOT, _on_player_snapshot)
	Net.register_message(&"_player_correct", _on_msg_correct)
	Net.register_message(&"_player_health", _on_msg_health)
	Net.register_message(&"_player_fall", _on_msg_fall)
	Net.register_message(&"_player_tp", _on_msg_tp)
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	for id: int in Net.peer_ids():
		_spawn(id, Net.peers[id])


func _exit_tree() -> void:
	Net.unregister_stream(STREAM_PLAYER_STATE)
	Net.unregister_stream(STREAM_PLAYER_SNAPSHOT)
	for msg: StringName in [&"_player_correct", &"_player_health", &"_player_fall", &"_player_tp"]:
		Net.unregister_message(msg)


func local_avatar() -> PlayerCharacter:
	return avatars.get(Net.local_id(), null)


func spawn_point_for(peer_id: int) -> Vector3:
	if spawn_points.is_empty():
		return Vector3(0, 1, 0)
	return spawn_points[(Net.peer_ids().find(peer_id) + spawn_points.size()) % spawn_points.size()]


# --- host API ---------------------------------------------------------------------------------


# Host: authoritative damage to any player. Broadcasts the result to every peer.
func damage_player(peer_id: int, amount: float, source: Vector3, type: int) -> float:
	if not Net.is_host() or not avatars.has(peer_id):
		return 0.0
	var p: PlayerCharacter = avatars[peer_id]
	var applied: float = p.health.apply_damage(amount, source, type)
	if applied > 0.0:
		_broadcast_health(p, applied, source, type)
	return applied


func heal_player(peer_id: int) -> void:
	if not Net.is_host() or not avatars.has(peer_id):
		return
	var p: PlayerCharacter = avatars[peer_id]
	p.health.restore_full()
	_broadcast_health(p, 0.0, Vector3.INF, HealthComponent.DamageType.GENERIC)


# Moves a player through the host (validator-authorized); usable from any peer.
func request_teleport(pos: Vector3) -> void:
	if Net.is_host():
		_host_teleport(Net.local_id(), pos)
	else:
		Net.send_reliable(1, &"_player_tp", [pos.x, pos.y, pos.z])


func _host_teleport(peer_id: int, pos: Vector3) -> void:
	if not avatars.has(peer_id):
		return
	if peer_id == Net.local_id():
		(avatars[peer_id] as PlayerCharacter).motor.teleport(pos)
		return
	var v: MovementValidator = validators[peer_id]
	var seq: int = v.authorize(pos, Net.host_time())
	_latest[peer_id] = [Net.host_time(), pos, (avatars[peer_id] as PlayerCharacter).get_yaw(), 0.0, 4]
	Net.send_reliable(peer_id, &"_player_correct", [seq, pos.x, pos.y, pos.z])


# --- tick -------------------------------------------------------------------------------------


func _physics_process(delta: float) -> void:
	var me: PlayerCharacter = local_avatar()
	if me != null:
		if Net.is_host():
			if me.global_position.y < PlayerCharacter.KILL_Y:
				me.motor.teleport(spawn_point_for(me.peer_id))
			_latest[me.peer_id] = [Net.host_time(), me.global_position, me.get_yaw(), me.get_pitch(), me.state_flags()]
		_state_timer -= delta
		if _state_timer <= 0.0:
			_state_timer += 1.0 / STATE_RATE
			if not Net.is_host():
				var buf: StreamPeerBuffer = StreamPeerBuffer.new()
				buf.put_double(Net.host_time())
				_put_vec(buf, me.global_position)
				buf.put_float(me.get_yaw())
				buf.put_float(me.get_pitch())
				buf.put_u8(me.state_flags())
				buf.put_u16(_correction_seq)
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
		buf.put_float(entry[3])
		buf.put_u8(entry[4])
	Net.send_unreliable(0, STREAM_PLAYER_SNAPSHOT, buf.data_array)


func _on_player_state(sender: int, bytes: PackedByteArray) -> void:
	if not Net.is_host() or not avatars.has(sender):
		return
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.data_array = bytes
	var stamp: float = buf.get_double()
	var pos: Vector3 = _get_vec(buf)
	var yaw: float = buf.get_float()
	var pitch: float = buf.get_float()
	var flags: int = buf.get_u8()
	var seq: int = buf.get_u16()
	var avatar: PlayerCharacter = avatars[sender]
	var v: MovementValidator = validators[sender]
	if pos.y < PlayerCharacter.KILL_Y and seq == v.expected_seq:
		_host_teleport(sender, spawn_point_for(sender))
		return
	match v.validate(stamp, pos, seq):
		MovementValidator.Result.STALE:
			return
		MovementValidator.Result.CORRECT:
			Log.warn(&"players", "Correcting peer %d: %s" % [sender, v.last_reason])
			Net.send_reliable(sender, &"_player_correct", [v.expected_seq, v.position.x, v.position.y, v.position.z])
			corrected.emit(sender, v.last_reason)
			return
	_latest[sender] = [stamp, pos, yaw, pitch, flags]
	avatar.remote_flags = flags
	avatar.remote_pitch = pitch
	avatar.buffer.push(stamp, pos, yaw, Net.now())


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
		var pitch: float = buf.get_float()
		var flags: int = buf.get_u8()
		if id != Net.local_id() and avatars.has(id):
			var avatar: PlayerCharacter = avatars[id]
			avatar.remote_flags = flags
			avatar.remote_pitch = pitch
			avatar.buffer.push(stamp, pos, yaw, local_now)


# --- messages ---------------------------------------------------------------------------------


func _on_msg_correct(sender: int, payload: Array) -> void:
	if sender != 1:
		return
	var me: PlayerCharacter = local_avatar()
	if me == null:
		return
	_correction_seq = int(payload[0])
	corrections_received += 1
	me.motor.teleport(Vector3(float(payload[1]), float(payload[2]), float(payload[3])))
	Log.info(&"players", "Position corrected by host (seq %d)" % _correction_seq)


func _on_msg_health(sender: int, payload: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	var id: int = int(payload[0])
	if not avatars.has(id):
		return
	var src: Vector3 = Vector3(float(payload[3]), float(payload[4]), float(payload[5]))
	if src.x > 1e8:
		src = Vector3.INF  # no direction (fall damage, heal)
	(avatars[id] as PlayerCharacter).health.apply_remote(float(payload[1]), float(payload[2]), src, int(payload[6]))


func _on_msg_fall(sender: int, payload: Array) -> void:
	if Net.is_host():
		_apply_fall(sender, float(payload[0]))


func _on_msg_tp(sender: int, payload: Array) -> void:
	if Net.is_host():
		_host_teleport(sender, Vector3(float(payload[0]), float(payload[1]), float(payload[2])))


func _apply_fall(peer_id: int, height: float) -> void:
	if not avatars.has(peer_id):
		return
	var p: PlayerCharacter = avatars[peer_id]
	var dmg: float = p.tuning.fall_damage(clampf(height, 0.0, 100.0))
	if dmg > 0.0:
		damage_player(peer_id, dmg, Vector3.INF, HealthComponent.DamageType.FALL)


func _broadcast_health(p: PlayerCharacter, damage: float, src: Vector3, type: int) -> void:
	var s: Vector3 = src if src != Vector3.INF else Vector3(1e9, 1e9, 1e9)
	Net.send_reliable(0, &"_player_health", [p.peer_id, p.health.health, damage, s.x, s.y, s.z, type])


func _on_fall_claim(height: float) -> void:
	if Net.is_host():
		_apply_fall(Net.local_id(), height)
	else:
		Net.send_reliable(1, &"_player_fall", [height])


func _on_downed(peer_id: int) -> void:
	Audio.play_event(&"player_downed")
	Log.info(
		&"players",
		(
			"Peer %d downed (placeholder: auto-restore in %.0f s; Step 6 adds last stand)"
			% [peer_id, DOWNED_PLACEHOLDER_REVIVE_S]
		)
	)
	if Net.is_host():
		await get_tree().create_timer(DOWNED_PLACEHOLDER_REVIVE_S).timeout
		heal_player(peer_id)


# --- spawn / despawn --------------------------------------------------------------------------


func _on_peer_joined(peer_id: int, info: Dictionary) -> void:
	if not avatars.has(peer_id):
		_spawn(peer_id, info)


func _on_peer_left(peer_id: int) -> void:
	_latest.erase(peer_id)
	validators.erase(peer_id)
	if avatars.has(peer_id):
		var avatar: PlayerCharacter = avatars[peer_id]
		avatars.erase(peer_id)
		avatar.queue_free()
		Audio.play_event(&"net_peer_left")
		Log.info(&"players", "Removed avatar for peer %d" % peer_id)
		avatar_removed.emit(peer_id)


func _spawn(peer_id: int, info: Dictionary) -> void:
	var avatar: PlayerCharacter = PLAYER_SCENE.instantiate() as PlayerCharacter
	avatar.peer_id = peer_id
	avatar.is_local = peer_id == Net.local_id()
	avatar.display_name = String(info.get("name", "Peer %d" % peer_id))
	avatar.slot = avatars.size()
	avatar.position = spawn_point_for(peer_id)
	avatar.rotation.y = spawn_yaw
	avatars[peer_id] = avatar
	add_child(avatar)
	if avatar.is_local:
		avatar.fall_damage_claimed.connect(_on_fall_claim)
	avatar.health.downed.connect(_on_downed.bind(peer_id))
	if Net.is_host() and not avatar.is_local:
		var v: MovementValidator = MovementValidator.new(avatar.tuning)
		v.kill_y = PlayerCharacter.KILL_Y
		validators[peer_id] = v
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
