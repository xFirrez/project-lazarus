# OfflineTransport — solo play. The local peer is the host (id 1) with no clients, so solo
# runs exactly the same host code path as co-op (ARCHITECTURE §4 rule 2).
class_name OfflineTransport
extends NetTransport


func transport_name() -> String:
	return "offline"


func create_host(_port: int, _max_clients: int) -> MultiplayerPeer:
	return OfflineMultiplayerPeer.new()
