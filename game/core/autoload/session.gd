# Session — the co-op session layer above Net (ARCHITECTURE §5.2 "Session"): the lobby / roster
# (LobbyState: slots, unique character selection, ready-up, host settings, chat, start countdown),
# the join policy (lobby full, late join off, duplicate identity) and "return to lobby" after a
# match. The roster lives for the whole session, so every peer can look up any player's character
# (`character_of`) in the lobby and in the match.
#   host  -> all  : `_lobby` [LobbyState.to_array()]        on every change
#   peer  -> host : `_lobby_req` [action, value]             character | ready | chat | settings (host)
#   host  -> all  : `_return_lobby` []                       after game over
# Authority: HOST owns the LobbyState and decides every change; clients send requests and mirror.
extends Node

signal lobby_changed
signal chat_received(peer_id: int, who: String, text: String)
signal countdown_finished  # host: the lobby countdown reached 0 -> Game launches the match
signal return_to_lobby_requested

const COUNTDOWN_SECONDS: float = 3.0

var lobby: LobbyState = LobbyState.new()
# Host: retained-player lookup provided by the running match (uid -> bool); see MatchSession.
var retained_lookup: Callable = Callable()
var in_match: bool = false  # host: a match is running (join policy: late join)
var starting_round_allowed: bool = true  # dev builds: host may pick the first round (testing)

var _countdown_fired: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Net.register_message(&"_lobby", _on_msg_lobby)
	Net.register_message(&"_lobby_req", _on_msg_req)
	Net.register_message(&"_return_lobby", _on_msg_return)
	Net.join_filter = _filter_join
	Net.session_started.connect(_on_session_started)
	Net.session_ended.connect(func(_r: String) -> void: _reset())
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	starting_round_allowed = OS.is_debug_build()
	CoopAudio.ensure_events()
	Debug.commands.register("lobby", _cmd_lobby, [], "Print the lobby / roster")
	Debug.commands.register("ready", _cmd_ready, [["on", TYPE_BOOL, true]], "Lobby: set ready")
	Debug.commands.register("character", _cmd_character, [["id", TYPE_STRING]], "Lobby: pick a character")
	Debug.commands.register("say", _cmd_say, [["text", TYPE_STRING]], "Lobby chat")
	Debug.commands.register("late_join", _cmd_late_join, [["on", TYPE_BOOL, true]], "Host: allow late join")
	Debug.commands.register(
		"start_round", _cmd_start_round, [["round", TYPE_INT, 1]], "Host (dev): first round of the next match"
	)
	Debug.commands.register("lobby_start", _cmd_lobby_start, [], "Host: start the countdown (everyone ready)")


func _reset() -> void:
	var chars: Array[StringName] = CharacterDefinition.ids_sorted()
	var keep_map: StringName = lobby.map_id
	lobby = LobbyState.new(chars)
	lobby.map_id = keep_map
	in_match = false
	_countdown_fired = false
	lobby_changed.emit()


# --- queries (any peer) -------------------------------------------------------------------------


func character_of(peer_id: int) -> StringName:
	return lobby.character_of(peer_id)


func character_def(peer_id: int) -> CharacterDefinition:
	var c: StringName = character_of(peer_id)
	return CharacterDefinition.get_def(c) if c != &"" else null


func countdown_left() -> float:
	if lobby.countdown_end < 0.0:
		return -1.0
	return maxf(lobby.countdown_end - Net.host_time(), 0.0)


# --- requests (any peer; the host applies them directly) ----------------------------------------


func request_character(char_id: StringName) -> void:
	_request("character", String(char_id))


func request_set_ready(value: bool) -> void:
	_request("ready", value)


func send_chat(text: String) -> void:
	_request("chat", text)


func _request(action: String, value: Variant) -> void:
	if not Net.is_active():
		return
	if Net.is_host():
		_host_apply(Net.local_id(), action, value)
	else:
		Net.send_reliable(1, &"_lobby_req", [action, value])


# --- host ---------------------------------------------------------------------------------------


func host_set_map(map_id: StringName) -> void:
	if Net.is_host() and Content.get_map(map_id) != null:
		lobby.map_id = map_id
		lobby.reset_ready()
		_broadcast()


func host_set_late_join(on: bool) -> void:
	if Net.is_host():
		lobby.late_join = on
		_broadcast()


func host_set_starting_round(r: int) -> void:
	if Net.is_host() and starting_round_allowed:
		lobby.starting_round = LobbyState.clamp_starting_round(r)
		_broadcast()


# Starts the countdown when everyone (host included) is ready. Returns false otherwise.
func host_start_countdown() -> bool:
	if not Net.is_host() or not lobby.all_ready() or in_match:
		return false
	lobby.countdown_end = Net.host_time() + COUNTDOWN_SECONDS
	_countdown_fired = false
	Audio.play_event(&"lobby_countdown")
	_broadcast()
	return true


func host_cancel_countdown() -> void:
	if Net.is_host() and lobby.countdown_end >= 0.0:
		lobby.countdown_end = -1.0
		_broadcast()


# After a game over: everyone goes back to the lobby (ready flags reset), the session stays up.
func host_return_to_lobby() -> void:
	if not Net.is_host():
		return
	in_match = false
	lobby.reset_ready()
	lobby.reserved.clear()
	_broadcast()
	Net.send_reliable(0, &"_return_lobby", [])
	return_to_lobby_requested.emit()


func host_match_started() -> void:
	in_match = true
	lobby.countdown_end = -1.0
	_broadcast()


func _host_apply(peer_id: int, action: String, value: Variant) -> void:
	var changed: bool = false
	match action:
		"character":
			if not in_match:
				changed = lobby.request_character(peer_id, StringName(String(value)))
				if not changed and peer_id == Net.local_id():
					Audio.play_event(&"ui_error")
		"ready":
			if not in_match:
				changed = lobby.set_ready(peer_id, bool(value))
		"chat":
			if lobby.add_chat(peer_id, String(value)):
				var last: Array = lobby.chat[-1]
				chat_received.emit(int(last[0]), String(last[1]), String(last[2]))
				Audio.play_event(&"lobby_chat")
				changed = true
	if changed:
		_broadcast()


func _broadcast() -> void:
	if not Net.is_host():
		return
	Net.send_reliable(0, &"_lobby", [lobby.to_array()])
	update_steam_metadata()
	lobby_changed.emit()


# Steam lobby browser / invite info (map, players, round); no-op on other transports.
func update_steam_metadata() -> void:
	if Net.is_host() and Net.transport is SteamTransport:
		var r: int = Match.current.rounds.current_round if Match.current != null and Match.current.rounds != null else 0
		(Net.transport as SteamTransport).update_metadata(lobby.map_id, lobby.slots.size(), r)


func _filter_join(uid: String, _player_name: String) -> String:
	for s: Dictionary in lobby.slots:
		if String(s["uid"]) == uid and int(s["peer"]) != Net.local_id():
			# The same player is back before their old connection timed out (crash + relaunch):
			# drop the stale peer now so its state is retained and restored to the new one.
			Log.info(&"session", "uid %s rejoined; dropping stale peer %d" % [uid.substr(0, 8), int(s["peer"])])
			Net.host_drop_peer(int(s["peer"]))
			break
	if uid == Net.local_uid:
		return "Same identity as the host"
	var retained: bool = retained_lookup.is_valid() and bool(retained_lookup.call(uid))
	if in_match and not lobby.late_join and not retained:
		return "Match in progress (late join is off)"
	if lobby.is_full():
		return "Lobby is full"
	return ""


func _process(_delta: float) -> void:
	if not Net.is_host() or lobby.countdown_end < 0.0 or _countdown_fired:
		return
	if not lobby.all_ready():
		host_cancel_countdown()
		return
	if Net.host_time() >= lobby.countdown_end:
		_countdown_fired = true
		countdown_finished.emit()


# --- net ----------------------------------------------------------------------------------------


func _on_session_started(is_host: bool) -> void:
	_reset()
	if is_host:
		lobby.add_peer(Net.local_id(), Net.local_uid, Net.local_name)
		_broadcast()


func _on_peer_joined(peer_id: int, info: Dictionary) -> void:
	if not Net.is_host() or peer_id == Net.local_id():
		return
	lobby.add_peer(peer_id, String(info.get("uid", "")), String(info.get("name", "")))
	Log.info(&"session", "Peer %d -> slot %d as %s" % [peer_id, lobby.index_of(peer_id), lobby.character_of(peer_id)])
	_broadcast()


func _on_peer_left(peer_id: int) -> void:
	if not Net.is_host():
		return
	var s: Dictionary = lobby.slot(peer_id)
	if s.is_empty():
		return
	if in_match:
		lobby.reserve(String(s["uid"]), StringName(s["character"]))  # reconnect keeps the character
	lobby.remove_peer(peer_id)
	lobby.countdown_end = -1.0
	_broadcast()


func _on_msg_lobby(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	var before: int = lobby.chat.size()
	lobby.from_array(p[0] as Array)
	for i: int in range(mini(before, lobby.chat.size()), lobby.chat.size()):
		var c: Array = lobby.chat[i]
		chat_received.emit(int(c[0]), String(c[1]), String(c[2]))
		Audio.play_event(&"lobby_chat")
	if lobby.countdown_end >= 0.0 and not _countdown_fired:
		_countdown_fired = true  # client: play the countdown sting once
		Audio.play_event(&"lobby_countdown")
	elif lobby.countdown_end < 0.0:
		_countdown_fired = false
	lobby_changed.emit()


func _on_msg_req(sender: int, p: Array) -> void:
	if Net.is_host() and p.size() >= 2:
		_host_apply(sender, String(p[0]), p[1])


func _on_msg_return(sender: int, _p: Array) -> void:
	if sender == 1 and not Net.is_host():
		in_match = false
		return_to_lobby_requested.emit()


# --- console ------------------------------------------------------------------------------------


func _cmd_lobby(_args: Array) -> String:
	var lines: PackedStringArray = []
	lines.append(
		(
			"map=%s late_join=%s start_round=%d countdown=%.1f in_match=%s"
			% [lobby.map_id, lobby.late_join, lobby.starting_round, countdown_left(), in_match]
		)
	)
	for s: Dictionary in lobby.slots:
		lines.append("  peer %d %s [%s] ready=%s" % [s["peer"], s["name"], s["character"], s["ready"]])
	return "\n".join(lines)


func _cmd_ready(args: Array) -> String:
	request_set_ready(bool(args[0]))
	return "ready %s" % args[0]


func _cmd_character(args: Array) -> String:
	request_character(StringName(String(args[0])))
	return "requested %s" % args[0]


func _cmd_say(args: Array) -> String:
	send_chat(String(args[0]))
	return "sent"


func _cmd_late_join(args: Array) -> String:
	host_set_late_join(bool(args[0]))
	return "late join %s" % lobby.late_join


func _cmd_start_round(args: Array) -> String:
	host_set_starting_round(int(args[0]))
	return "starting round %d" % lobby.starting_round


func _cmd_lobby_start(_args: Array) -> String:
	return "countdown started" if host_start_countdown() else "not everyone is ready"
