# EnetTransport — direct IP / LAN / VPN co-op over ENet.
class_name EnetTransport
extends NetTransport

const CHANNELS: int = 4
const TIMEOUT_LIMIT: int = 32
const TIMEOUT_MIN_MS: int = 1000
const TIMEOUT_MAX_MS: int = 3000


func transport_name() -> String:
	return "enet"


func supports_clients() -> bool:
	return true


func create_host(port: int, max_clients: int) -> MultiplayerPeer:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, max_clients, CHANNELS)
	if err != OK:
		Log.error(&"net", "ENet create_server(%d) failed: %s" % [port, error_string(err)])
		return null
	peer.peer_connected.connect(_on_server_peer_connected.bind(peer))
	return peer


func create_client(address: String, port: int) -> MultiplayerPeer:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port, CHANNELS)
	if err != OK:
		Log.error(&"net", "ENet create_client(%s:%d) failed: %s" % [address, port, error_string(err)])
		return null
	# Detect a dead host in ~3 s instead of ENet's default 30 s.
	var server: ENetPacketPeer = peer.get_peer(1)
	if server != null:
		server.set_timeout(TIMEOUT_LIMIT, TIMEOUT_MIN_MS, TIMEOUT_MAX_MS)
	return peer


func _on_server_peer_connected(id: int, peer: ENetMultiplayerPeer) -> void:
	var client: ENetPacketPeer = peer.get_peer(id)
	if client != null:
		client.set_timeout(TIMEOUT_LIMIT, TIMEOUT_MIN_MS, TIMEOUT_MAX_MS)
