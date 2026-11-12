# Net — session lifecycle (host/join/solo/leave), transport selection, peer list, NetSim,
# clock sync and the two game channels:
#   * reliable message channel: send_reliable(target, type, payload) -> registered handlers
#   * unreliable byte-stream channel: send_unreliable(target, stream, bytes) for snapshots
# All game traffic goes through these two calls so NetSim can shape it.
# Authority: the host (peer 1) owns the peer list; clients mirror it.
extends Node

signal peer_joined(peer_id: int, info: Dictionary)
signal peer_left(peer_id: int)
signal session_started(is_host: bool)
signal session_ended(reason: String)
signal connection_failed(reason: String)

enum State { IDLE, CONNECTING, ACTIVE }

const DEFAULT_PORT: int = 24565
const MAX_CLIENTS: int = 3
const CONNECT_TIMEOUT: float = 5.0
const PING_INTERVAL: float = 0.5
const HOST_SILENCE_TIMEOUT: float = 4.0
const SNAPSHOT_CHANNEL: int = 1

# Reserved unreliable stream ids (game systems use >= 16).
const STREAM_PING: int = 1
const STREAM_PONG: int = 2

var state: State = State.IDLE
var transport: NetTransport = null
var sim: NetSim = NetSim.new()
var clock: ClockSync = ClockSync.new()
var local_uid: String = ""
var local_name: String = "Survivor"
var peers: Dictionary = {}  # peer_id -> {uid, name}
# Host: Callable(uid: String, name: String) -> String; a non-empty reason refuses the join
# (Session: lobby full, late join off, duplicate identity). The joiner gets `_rejected` [reason].
var join_filter: Callable = Callable()
var transport_status: String = ""  # e.g. UPnP result, shown in the lobby
var refused_joins: int = 0  # host: joins refused by join_filter
var upnp: UpnpMapper = null

var bytes_out_per_sec: float = 0.0
var bytes_in_per_sec: float = 0.0
var loss_estimate: float = 0.0

var _handlers: Dictionary = {}  # StringName -> Callable(sender: int, payload: Array)
var _stream_handlers: Dictionary = {}  # int -> Callable(sender: int, bytes: PackedByteArray)
var _connect_started: float = 0.0
var _ping_timer: float = 0.0
var _last_host_contact: float = 0.0
var _ping_seq: int = 0
var _pings_sent: int = 0
var _pongs_received: int = 0
var _bytes_out_acc: int = 0
var _bytes_in_acc: int = 0
var _stats_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var profile: String = CommandLine.get_value("profile", "")
	local_uid = PlayerIdentity.load_or_create(PlayerIdentity.path_for_profile(profile))
	local_name = String(Config.get_value(&"gameplay", &"player_name", "Survivor"))
	if profile != "":
		local_name = "%s-%s" % [local_name, profile]
	var spec: String = CommandLine.get_value("netsim", "")
	if spec != "":
		var v: PackedFloat64Array = NetSim.parse_spec(spec)
		set_netsim(v[0], v[1], v[2])
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_packet.connect(_on_peer_packet)
	register_message(&"_hello", _on_msg_hello)
	register_message(&"_welcome", _on_msg_welcome)
	register_message(&"_peer_joined", _on_msg_peer_joined)
	register_message(&"_peer_left", _on_msg_peer_left)
	register_message(&"_rejected", _on_msg_rejected)
	register_stream(STREAM_PING, _on_stream_ping)
	register_stream(STREAM_PONG, _on_stream_pong)
	Log.info(&"net", "player_uid %s (%s)" % [local_uid, local_name])


# --- Session lifecycle -------------------------------------------------------------------


func start_solo() -> Error:
	return _start_host(OfflineTransport.new(), 0)


func host_session(port: int = DEFAULT_PORT, try_upnp: bool = false) -> Error:
	var err: Error = _start_host(EnetTransport.new(), port)
	if err == OK and try_upnp:
		upnp = UpnpMapper.new()
		upnp.start(port)
	return err


# Steam (GodotSteam, D-045): the host creates a friends-only lobby; see SteamTransport.
func host_steam() -> Error:
	if not SteamTransport.is_available():
		return ERR_UNAVAILABLE
	return _start_host(SteamTransport.new(), 0)


# Joins with an already-created client peer (Steam: after the lobby join resolved the owner).
func join_with_transport(p_transport: NetTransport, address: String, port: int) -> Error:
	leave_session("")
	var peer: MultiplayerPeer = p_transport.create_client(address, port)
	if peer == null:
		return ERR_CANT_CONNECT
	transport = p_transport
	multiplayer.multiplayer_peer = peer
	state = State.CONNECTING
	_connect_started = now()
	Log.info(&"net", "Joining via %s (%s) ..." % [p_transport.transport_name(), address])
	return OK


func join_session(address: String, port: int = DEFAULT_PORT) -> Error:
	leave_session("")
	transport = EnetTransport.new()
	var peer: MultiplayerPeer = transport.create_client(address, port)
	if peer == null:
		transport = null
		return ERR_CANT_CONNECT
	multiplayer.multiplayer_peer = peer
	state = State.CONNECTING
	_connect_started = now()
	Log.info(&"net", "Joining %s:%d ..." % [address, port])
	return OK


func leave_session(reason: String) -> void:
	if state == State.IDLE:
		return
	var was_active: bool = state == State.ACTIVE
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	state = State.IDLE
	if transport != null:
		transport.shutdown()
	transport = null
	if upnp != null:
		upnp.stop()
		upnp = null
	transport_status = ""
	peers.clear()
	clock.reset()
	sim.clear()
	Log.info(&"net", "Session closed%s" % ((": " + reason) if reason != "" else ""))
	if was_active:
		session_ended.emit(reason)


func is_active() -> bool:
	return state == State.ACTIVE


func is_host() -> bool:
	return state == State.ACTIVE and multiplayer.is_server()


func local_id() -> int:
	return multiplayer.get_unique_id()


func peer_ids() -> Array[int]:
	var ids: Array[int] = []
	for id: int in peers:
		ids.append(id)
	ids.sort()
	return ids


func now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0


# Host clock estimate; on the host this is the local clock.
func host_time() -> float:
	if is_host() or state != State.ACTIVE:
		return now()
	return clock.host_time(now())


func rtt_ms() -> float:
	return clock.rtt * 1000.0


func set_netsim(latency_ms: float, jitter_ms: float, loss: float) -> void:
	sim.configure(latency_ms, jitter_ms, loss)
	Log.info(&"net", "NetSim: %s" % sim.describe())


# --- Messaging ----------------------------------------------------------------------------


func register_message(type: StringName, handler: Callable) -> void:
	_handlers[type] = handler


func unregister_message(type: StringName) -> void:
	_handlers.erase(type)


func register_stream(stream_id: int, handler: Callable) -> void:
	_stream_handlers[stream_id] = handler


func unregister_stream(stream_id: int) -> void:
	_stream_handlers.erase(stream_id)


# target: a peer id, or 0 for every other peer. Sending to yourself dispatches locally.
func send_reliable(target: int, type: StringName, payload: Array = []) -> void:
	if state == State.IDLE:
		return
	if target == local_id():
		_dispatch_message(local_id(), type, payload)
		return
	if not _has_remote_peers():
		return
	var item: Dictionary = {"reliable": true, "target": target, "type": type, "payload": payload}
	if sim.enabled:
		sim.push(item, now(), true)
	else:
		_send_now(item)


func send_unreliable(target: int, stream_id: int, bytes: PackedByteArray) -> void:
	if state == State.IDLE or not _has_remote_peers():
		return
	var packet: PackedByteArray = PackedByteArray([stream_id])
	packet.append_array(bytes)
	var item: Dictionary = {"reliable": false, "target": target, "bytes": packet}
	if sim.enabled:
		sim.push(item, now(), false)
	else:
		_send_now(item)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_message(type: StringName, payload: Array) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	_bytes_in_acc += var_to_bytes(payload).size() + String(type).length() + 8
	if state == State.CONNECTING and type != &"_welcome" and type != &"_rejected":
		return
	_last_host_contact = now()
	_dispatch_message(sender, type, payload)


func _dispatch_message(sender: int, type: StringName, payload: Array) -> void:
	if not _handlers.has(type):
		Log.warn(&"net", "No handler for message '%s' from %d" % [type, sender])
		return
	(_handlers[type] as Callable).call(sender, payload)


func _send_now(item: Dictionary) -> void:
	if multiplayer.multiplayer_peer == null or state == State.IDLE:
		return
	var target: int = int(item["target"])
	if target > 0 and target != local_id() and not multiplayer.get_peers().has(target):
		return  # the peer left while this (NetSim-delayed) packet was queued
	if bool(item["reliable"]):
		var type: StringName = item["type"]
		var payload: Array = item["payload"]
		_bytes_out_acc += var_to_bytes(payload).size() + String(type).length() + 8
		if target == 0:
			_rpc_message.rpc(type, payload)
		else:
			_rpc_message.rpc_id(target, type, payload)
	else:
		var bytes: PackedByteArray = item["bytes"]
		_bytes_out_acc += bytes.size() + 8
		(multiplayer as SceneMultiplayer).send_bytes(
			bytes, target, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, SNAPSHOT_CHANNEL
		)


func _has_remote_peers() -> bool:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return false
	if state == State.CONNECTING:
		return true
	return multiplayer.get_peers().size() > 0


func _on_peer_packet(sender: int, packet: PackedByteArray) -> void:
	if packet.is_empty():
		return
	_bytes_in_acc += packet.size() + 8
	var stream_id: int = packet[0]
	if not _stream_handlers.has(stream_id):
		return
	if sender == 1:
		_last_host_contact = now()
	(_stream_handlers[stream_id] as Callable).call(sender, packet.slice(1))


# --- Frame update -------------------------------------------------------------------------


func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	if sim.enabled or sim.pending() > 0:
		for item: Variant in sim.pop_ready(now()):
			_send_now(item as Dictionary)
	if state == State.CONNECTING and now() - _connect_started > CONNECT_TIMEOUT:
		_fail_connection("Connection timed out")
		return
	if upnp != null:
		transport_status = upnp.status_text()
	if state == State.ACTIVE and not is_host():
		_ping_timer -= delta
		if _ping_timer <= 0.0:
			_ping_timer = PING_INTERVAL
			_send_ping()
		if now() - _last_host_contact > HOST_SILENCE_TIMEOUT:
			Log.warn(&"net", "No traffic from host for %.1f s" % HOST_SILENCE_TIMEOUT)
			leave_session("Host disconnected")
			return
	_stats_timer += delta
	if _stats_timer >= 1.0:
		bytes_out_per_sec = _bytes_out_acc / _stats_timer
		bytes_in_per_sec = _bytes_in_acc / _stats_timer
		_bytes_out_acc = 0
		_bytes_in_acc = 0
		_stats_timer = 0.0
		if _pings_sent >= 4:
			loss_estimate = clampf(1.0 - float(_pongs_received) / _pings_sent, 0.0, 1.0)
			_pings_sent = 0
			_pongs_received = 0


# --- Internals ----------------------------------------------------------------------------


func _start_host(p_transport: NetTransport, port: int) -> Error:
	leave_session("")
	var peer: MultiplayerPeer = p_transport.create_host(port, MAX_CLIENTS)
	if peer == null:
		return ERR_CANT_CREATE
	transport = p_transport
	multiplayer.multiplayer_peer = peer
	state = State.ACTIVE
	peers.clear()
	peers[local_id()] = _local_info()
	Log.info(
		&"net",
		(
			"Hosting (%s%s), peer id %d"
			% [transport.transport_name(), (" port %d" % port) if transport.supports_clients() else "", local_id()]
		)
	)
	session_started.emit(true)
	peer_joined.emit(local_id(), peers[local_id()])
	return OK


func _local_info() -> Dictionary:
	return {"uid": local_uid, "name": local_name}


func _fail_connection(reason: String) -> void:
	Log.warn(&"net", reason)
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	state = State.IDLE
	if transport != null:
		transport.shutdown()
	transport = null
	sim.clear()
	connection_failed.emit(reason)


func _send_ping() -> void:
	_ping_seq += 1
	_pings_sent += 1
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.put_double(now())
	send_unreliable(1, STREAM_PING, buf.data_array)


func _on_stream_ping(sender: int, bytes: PackedByteArray) -> void:
	if not is_host():
		return
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.data_array = bytes
	var client_time: float = buf.get_double()
	var out: StreamPeerBuffer = StreamPeerBuffer.new()
	out.put_double(client_time)
	out.put_double(now())
	send_unreliable(sender, STREAM_PONG, out.data_array)


func _on_stream_pong(_sender: int, bytes: PackedByteArray) -> void:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.data_array = bytes
	var client_time: float = buf.get_double()
	var host_t: float = buf.get_double()
	_pongs_received += 1
	clock.add_sample(client_time, host_t, now())


func _on_peer_connected(id: int) -> void:
	Log.debug(&"net", "Transport peer connected: %d" % id)


func _on_peer_disconnected(id: int) -> void:
	if not is_host() or not peers.has(id):
		return
	peers.erase(id)
	Log.info(&"net", "Peer %d left" % id)
	send_reliable(0, &"_peer_left", [id])
	peer_left.emit(id)


func _on_connected_to_server() -> void:
	Log.info(&"net", "Transport connected; sending hello")
	_last_host_contact = now()
	send_reliable(1, &"_hello", [local_uid, local_name])


func _on_connection_failed() -> void:
	_fail_connection("Could not connect to host")


func _on_server_disconnected() -> void:
	leave_session("Host disconnected")


func _on_msg_hello(sender: int, payload: Array) -> void:
	if not is_host() or payload.size() < 2:
		return
	var info: Dictionary = {"uid": String(payload[0]), "name": String(payload[1])}
	var reason: String = String(join_filter.call(info["uid"], info["name"])) if join_filter.is_valid() else ""
	if reason != "":
		Log.info(&"net", "Refused peer %d (%s): %s" % [sender, info["name"], reason])
		refused_joins += 1
		send_reliable(sender, &"_rejected", [reason])
		_kick_later(sender)
		return
	var existing: Array = []
	for id: int in peers:
		existing.append([id, peers[id]])
	peers[sender] = info
	send_reliable(sender, &"_welcome", [existing, now()])
	for id: int in peers:
		if id != sender and id != local_id():
			send_reliable(id, &"_peer_joined", [sender, info])
	Log.info(&"net", "Peer %d joined (%s, uid %s)" % [sender, info["name"], info["uid"]])
	peer_joined.emit(sender, info)


func _on_msg_welcome(_sender: int, payload: Array) -> void:
	if state != State.CONNECTING:
		return
	state = State.ACTIVE
	peers.clear()
	peers[local_id()] = _local_info()
	_last_host_contact = now()
	_ping_timer = 0.0
	Log.info(&"net", "Joined session as peer %d" % local_id())
	session_started.emit(false)
	for entry: Variant in payload[0]:
		var pair: Array = entry
		var id: int = int(pair[0])
		peers[id] = pair[1]
		peer_joined.emit(id, pair[1])
	peer_joined.emit(local_id(), peers[local_id()])


# Host: disconnects a peer now and processes its departure immediately (stale connection of a
# player who is rejoining under the same uid).
func host_drop_peer(peer_id: int) -> void:
	if not is_host():
		return
	if multiplayer.get_peers().has(peer_id):
		multiplayer.multiplayer_peer.disconnect_peer(peer_id, true)
	if multiplayer.get_peers().has(peer_id):
		# A forced ENet disconnect doesn't notify SceneMultiplayer; without this it keeps the
		# dead peer in its list and every broadcast errors with "Invalid target peer".
		multiplayer.multiplayer_peer.peer_disconnected.emit(peer_id)
	_on_peer_disconnected(peer_id)


# Host: drops a refused / kicked peer after its `_rejected` message had time to leave.
func _kick_later(peer_id: int) -> void:
	await get_tree().create_timer(0.5 + sim.latency_ms / 1000.0).timeout
	if is_host() and multiplayer.get_peers().has(peer_id):
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


func _on_msg_rejected(sender: int, payload: Array) -> void:
	if sender != 1 or is_host():
		return
	_fail_connection("Join refused: %s" % String(payload[0]))


func _on_msg_peer_joined(_sender: int, payload: Array) -> void:
	var id: int = int(payload[0])
	peers[id] = payload[1]
	peer_joined.emit(id, payload[1])


func _on_msg_peer_left(_sender: int, payload: Array) -> void:
	var id: int = int(payload[0])
	if peers.erase(id):
		peer_left.emit(id)
