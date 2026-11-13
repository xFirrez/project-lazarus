# LobbyState — pure data model of the co-op lobby / session roster (ARCHITECTURE §5.2 "Session"):
# up to 4 slots (peer id, player_uid, name, character, ready), host settings (map, late join,
# starting round), a short chat log and the start countdown. Characters are unique per lobby.
# Serialised as plain Arrays/Dictionaries for the reliable `_lobby` message and unit-testable
# without a scene tree. The host owns the authoritative copy (Session); clients hold a mirror.
# Authority: HOST mutates; clients only replace their copy from `from_array`.
class_name LobbyState
extends RefCounted

const MAX_SLOTS: int = 4
const CHAT_MAX: int = 30
const CHAT_MAX_CHARS: int = 160
const NAME_MAX_CHARS: int = 24

var slots: Array[Dictionary] = []  # {peer, uid, name, character, ready}; join order
var map_id: StringName = &""
var late_join: bool = true
var starting_round: int = 1  # dev/testing: first round of the match
var chat: Array = []  # [[peer, name, text]...]
var countdown_end: float = -1.0  # host clock time the match starts (< 0: no countdown)
var characters: Array[StringName] = []  # selectable ids, lobby order
# Characters held for disconnected players (uid -> character) so a reconnect gets theirs back.
var reserved: Dictionary = {}


func _init(p_characters: Array[StringName] = []) -> void:
	characters = p_characters.duplicate()


func has_peer(peer_id: int) -> bool:
	return index_of(peer_id) >= 0


func index_of(peer_id: int) -> int:
	for i: int in slots.size():
		if int(slots[i]["peer"]) == peer_id:
			return i
	return -1


func slot(peer_id: int) -> Dictionary:
	var i: int = index_of(peer_id)
	return slots[i] if i >= 0 else {}


func is_full() -> bool:
	return slots.size() >= MAX_SLOTS


func character_of(peer_id: int) -> StringName:
	return StringName(slot(peer_id).get("character", &""))


func peer_with_character(char_id: StringName) -> int:
	for s: Dictionary in slots:
		if StringName(s["character"]) == char_id:
			return int(s["peer"])
	return 0


# Free for `uid`: not used by a connected peer and not reserved for another (disconnected) uid.
func is_character_free(char_id: StringName, uid: String = "") -> bool:
	if peer_with_character(char_id) != 0:
		return false
	for r: String in reserved:
		if r != uid and StringName(reserved[r]) == char_id:
			return false
	return true


func free_characters(uid: String = "") -> Array[StringName]:
	var out: Array[StringName] = []
	for c: StringName in characters:
		if is_character_free(c, uid):
			out.append(c)
	return out


func reserve(uid: String, char_id: StringName) -> void:
	if uid != "" and char_id != &"":
		reserved[uid] = char_id


func release(uid: String) -> void:
	reserved.erase(uid)


# Adds (or refreshes) a peer. `preferred` (e.g. the character a reconnecting player had) is used
# when free, otherwise the first free character in lobby order. Returns false if the lobby is full.
func add_peer(peer_id: int, uid: String, player_name: String, preferred: StringName = &"") -> bool:
	if has_peer(peer_id):
		return true
	if is_full():
		return false
	var c: StringName = &""
	if preferred == &"":
		preferred = StringName(reserved.get(uid, &""))
	if preferred != &"" and characters.has(preferred) and is_character_free(preferred, uid):
		c = preferred
	else:
		var free: Array[StringName] = free_characters(uid)
		c = free[0] if not free.is_empty() else &""
	reserved.erase(uid)
	slots.append({"peer": peer_id, "uid": uid, "name": sanitize_name(player_name), "character": c, "ready": false})
	return true


func remove_peer(peer_id: int) -> void:
	var i: int = index_of(peer_id)
	if i >= 0:
		slots.remove_at(i)


# Character selection: unique per lobby. Returns false if taken by someone else or unknown.
func request_character(peer_id: int, char_id: StringName) -> bool:
	var i: int = index_of(peer_id)
	if i < 0 or not characters.has(char_id):
		return false
	if StringName(slots[i]["character"]) != char_id and not is_character_free(char_id, String(slots[i]["uid"])):
		return false
	slots[i]["character"] = char_id
	slots[i]["ready"] = false  # changing character un-readies (avoids a start mid-change)
	return true


func set_ready(peer_id: int, value: bool) -> bool:
	var i: int = index_of(peer_id)
	if i < 0:
		return false
	slots[i]["ready"] = value
	if not value:
		countdown_end = -1.0
	return true


func is_ready(peer_id: int) -> bool:
	return bool(slot(peer_id).get("ready", false))


func all_ready() -> bool:
	if slots.is_empty():
		return false
	for s: Dictionary in slots:
		if not bool(s["ready"]) or StringName(s["character"]) == &"":
			return false
	return true


func reset_ready() -> void:
	for s: Dictionary in slots:
		s["ready"] = false
	countdown_end = -1.0


func add_chat(peer_id: int, text: String) -> bool:
	var clean: String = sanitize_chat(text)
	if clean == "":
		return false
	var who: String = String(slot(peer_id).get("name", "Peer %d" % peer_id))
	chat.append([peer_id, who, clean])
	while chat.size() > CHAT_MAX:
		chat.pop_front()
	return true


static func sanitize_chat(text: String) -> String:
	var t: String = text.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	return t.substr(0, CHAT_MAX_CHARS)


static func sanitize_name(text: String) -> String:
	var t: String = text.strip_edges().replace("\n", " ").substr(0, NAME_MAX_CHARS)
	return t if t != "" else "Survivor"


static func clamp_starting_round(r: int) -> int:
	return clampi(r, 1, 100)


func to_array() -> Array:
	var list: Array = []
	for s: Dictionary in slots:
		list.append([int(s["peer"]), String(s["uid"]), String(s["name"]), String(s["character"]), bool(s["ready"])])
	return [list, String(map_id), late_join, starting_round, chat.duplicate(true), countdown_end]


func from_array(a: Array) -> void:
	slots.clear()
	for e: Variant in a[0]:
		var r: Array = e
		slots.append(
			{
				"peer": int(r[0]),
				"uid": String(r[1]),
				"name": String(r[2]),
				"character": StringName(r[3]),
				"ready": bool(r[4])
			}
		)
	map_id = StringName(a[1])
	late_join = bool(a[2])
	starting_round = int(a[3])
	chat = (a[4] as Array).duplicate(true)
	countdown_end = float(a[5])
