# SteamTransport — Steam lobbies + P2P via the GodotSteam GDExtension (D-045). The addon is not
# vendored: docs/NETWORKING.md §3 has the install steps (GodotSteam GDExtension build matching the
# pinned Godot, into game/addons/godotsteam/; needs a running Steam client). Everything is called dynamically through
# the `Steam` singleton / `SteamMultiplayerPeer` class so the project compiles and runs without
# it; `is_available()` gates the menu's Steam button. Direct IP (EnetTransport) + UPnP + a VPN
# guide is the always-available path.
# Flow: host -> create SteamMultiplayerPeer host + a friends-only lobby (metadata: map, players,
# round, version) -> invite via the overlay. Joiner (invite / friend list) -> joinLobby -> lobby
# owner's Steam id -> SteamMultiplayerPeer client.
# Authority: transport only; game authority is unchanged (host-authoritative).
class_name SteamTransport
extends NetTransport

signal lobby_ready(lobby_id: int)
signal lobby_join_resolved(owner_steam_id: int, lobby_id: int)
signal lobby_failed(reason: String)

const DEV_APP_ID: int = 480  # Spacewar, Valve's public test app (development only)
const LOBBY_TYPE_FRIENDS_ONLY: int = 1
const VIRTUAL_PORT: int = 0
const META_KEYS: PackedStringArray = ["game", "map", "players", "round", "version"]
const GAME_TAG: String = "project_lazarus"

const INIT_META: StringName = &"steam_api_initialized"  # Engine meta, not a static var (D-045)

var lobby_id: int = 0
var max_members: int = 4


static func is_available() -> bool:
	return Engine.has_singleton("Steam") and ClassDB.class_exists("SteamMultiplayerPeer")


static func steam() -> Object:
	return Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null


# Initialises the Steam API once (App ID 480 in development). Returns false without Steam.
static func ensure_init(app_id: int = DEV_APP_ID) -> bool:
	if Engine.has_meta(INIT_META):
		return true
	var s: Object = steam()
	if s == null:
		return false
	var res: Variant = s.call("steamInitEx", app_id, true)
	var ok: bool = res is Dictionary and int((res as Dictionary).get("status", 1)) == 0
	if ok:
		Engine.set_meta(INIT_META, true)
	if not ok:
		Log.warn(&"net", "Steam init failed: %s" % str(res))
	return ok


# Lobby metadata (pure; unit-tested): what friends see in the lobby browser / invite.
static func lobby_metadata(map_id: StringName, players: int, round_number: int, version: String) -> Dictionary:
	return {
		"game": GAME_TAG,
		"map": String(map_id),
		"players": str(clampi(players, 0, 4)),
		"round": str(maxi(round_number, 0)),
		"version": version,
	}


# Validates lobby metadata read back from Steam; empty when it is not one of our lobbies.
static func parse_lobby_metadata(meta: Dictionary) -> Dictionary:
	if String(meta.get("game", "")) != GAME_TAG:
		return {}
	return {
		"map": StringName(String(meta.get("map", ""))),
		"players": String(meta.get("players", "0")).to_int(),
		"round": String(meta.get("round", "0")).to_int(),
		"version": String(meta.get("version", "")),
	}


func transport_name() -> String:
	return "steam"


func supports_clients() -> bool:
	return true


func create_host(_port: int, max_clients: int) -> MultiplayerPeer:
	if not is_available() or not ensure_init():
		Log.warn(&"net", "Steam transport unavailable (GodotSteam not installed or Steam not running)")
		return null
	max_members = max_clients + 1
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
	var err: Variant = peer.call("create_host", VIRTUAL_PORT)
	if int(err) != OK:
		Log.error(&"net", "SteamMultiplayerPeer.create_host failed: %s" % str(err))
		return null
	var s: Object = steam()
	if not s.is_connected("lobby_created", _on_lobby_created):
		s.connect("lobby_created", _on_lobby_created)
	s.call("createLobby", LOBBY_TYPE_FRIENDS_ONLY, max_members)
	return peer


# address = the lobby owner's Steam id (decimal string), resolved by `join_lobby`.
func create_client(address: String, _port: int) -> MultiplayerPeer:
	if not is_available() or not ensure_init() or not address.is_valid_int():
		return null
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
	var err: Variant = peer.call("create_client", address.to_int(), VIRTUAL_PORT)
	if int(err) != OK:
		Log.error(&"net", "SteamMultiplayerPeer.create_client failed: %s" % str(err))
		return null
	return peer


# Joiner: join a lobby (from an invite / the friend list); emits lobby_join_resolved(owner, id).
func join_lobby(p_lobby_id: int) -> void:
	var s: Object = steam()
	if s == null:
		lobby_failed.emit("Steam unavailable")
		return
	if not s.is_connected("lobby_joined", _on_lobby_joined):
		s.connect("lobby_joined", _on_lobby_joined)
	s.call("joinLobby", p_lobby_id)


func open_invite_overlay() -> void:
	var s: Object = steam()
	if s != null and lobby_id != 0:
		s.call("activateGameOverlayInviteDialog", lobby_id)


func update_metadata(map_id: StringName, players: int, round_number: int) -> void:
	var s: Object = steam()
	if s == null or lobby_id == 0:
		return
	var meta: Dictionary = lobby_metadata(
		map_id, players, round_number, ProjectSettings.get_setting("application/config/version", "dev")
	)
	for k: String in meta:
		s.call("setLobbyData", lobby_id, k, String(meta[k]))


func shutdown() -> void:
	var s: Object = steam()
	if s != null and lobby_id != 0:
		s.call("leaveLobby", lobby_id)
	lobby_id = 0


func _on_lobby_created(result: int, p_lobby_id: int) -> void:
	if result != 1:
		lobby_failed.emit("lobby creation failed (%d)" % result)
		return
	lobby_id = p_lobby_id
	steam().call("setLobbyJoinable", lobby_id, true)
	update_metadata(&"", 1, 0)
	lobby_ready.emit(lobby_id)


func _on_lobby_joined(p_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:
		lobby_failed.emit("could not join the lobby (%d)" % response)
		return
	lobby_id = p_lobby_id
	var owner: int = int(steam().call("getLobbyOwner", p_lobby_id))
	lobby_join_resolved.emit(owner, p_lobby_id)
