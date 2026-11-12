# NetTransport — creates the MultiplayerPeer for a session. The rest of the game is
# transport-agnostic: it only talks to the SceneMultiplayer API through Net.
class_name NetTransport
extends RefCounted


func transport_name() -> String:
	return "base"


func create_host(_port: int, _max_clients: int) -> MultiplayerPeer:
	return null


func create_client(_address: String, _port: int) -> MultiplayerPeer:
	return null


func supports_clients() -> bool:
	return false


# Called when the session closes (Steam: leave the lobby).
func shutdown() -> void:
	pass
