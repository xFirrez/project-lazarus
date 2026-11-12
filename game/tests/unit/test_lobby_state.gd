# LobbyState (Step 7 lobby): slots, unique characters, reservations for reconnects, ready-up,
# countdown reset, chat sanitising, serialisation round trip.
extends GutTest

const CHARS: Array[StringName] = [&"calloway", &"orlov", &"brandt", &"ashcombe"]


func _lobby() -> LobbyState:
	return LobbyState.new(CHARS)


func test_add_assigns_unique_characters_in_order() -> void:
	var l: LobbyState = _lobby()
	for i: int in 4:
		assert_true(l.add_peer(i + 1, "uid%d" % i, "P%d" % i))
	assert_eq(l.character_of(1), &"calloway")
	assert_eq(l.character_of(2), &"orlov")
	assert_eq(l.character_of(3), &"brandt")
	assert_eq(l.character_of(4), &"ashcombe")
	assert_true(l.is_full())
	assert_false(l.add_peer(5, "uid5", "late"), "5th player refused")


func test_character_request_is_unique() -> void:
	var l: LobbyState = _lobby()
	l.add_peer(1, "a", "A")
	l.add_peer(2, "b", "B")
	assert_false(l.request_character(2, &"calloway"), "taken by peer 1")
	assert_true(l.request_character(2, &"brandt"))
	assert_eq(l.character_of(2), &"brandt")
	assert_true(l.request_character(1, &"orlov"), "orlov is free again")
	assert_false(l.request_character(1, &"nobody"), "unknown id")
	assert_eq(l.free_characters(), [&"calloway", &"ashcombe"] as Array[StringName])


func test_ready_and_countdown() -> void:
	var l: LobbyState = _lobby()
	l.add_peer(1, "a", "A")
	l.add_peer(2, "b", "B")
	assert_false(l.all_ready())
	l.set_ready(1, true)
	assert_false(l.all_ready())
	l.set_ready(2, true)
	assert_true(l.all_ready())
	l.countdown_end = 10.0
	l.set_ready(2, false)
	assert_eq(l.countdown_end, -1.0, "un-ready cancels the countdown")
	l.set_ready(2, true)
	l.request_character(2, &"ashcombe")
	assert_false(l.is_ready(2), "changing character un-readies")


func test_reserved_character_survives_disconnect() -> void:
	var l: LobbyState = _lobby()
	l.add_peer(1, "host", "H")
	l.add_peer(2, "petya", "P")  # orlov
	l.reserve("petya", &"orlov")
	l.remove_peer(2)
	l.add_peer(3, "stranger", "S")
	assert_ne(l.character_of(3), &"orlov", "reserved for the disconnected uid")
	assert_false(l.request_character(3, &"orlov"))
	l.add_peer(4, "petya", "P")
	assert_eq(l.character_of(4), &"orlov", "reconnect gets the reserved character back")
	assert_false(l.reserved.has("petya"))


func test_chat_sanitised_and_capped() -> void:
	var l: LobbyState = _lobby()
	l.add_peer(1, "a", "Ruth")
	assert_false(l.add_chat(1, "   "), "empty refused")
	assert_true(l.add_chat(1, "hello\nworld"))
	assert_eq(l.chat[-1], [1, "Ruth", "hello world"])
	l.add_chat(1, "x".repeat(500))
	assert_eq(String(l.chat[-1][2]).length(), LobbyState.CHAT_MAX_CHARS)
	for i: int in 50:
		l.add_chat(1, "m%d" % i)
	assert_eq(l.chat.size(), LobbyState.CHAT_MAX)


func test_round_trip() -> void:
	var l: LobbyState = _lobby()
	l.add_peer(1, "a", "A")
	l.add_peer(7, "b", "B")
	l.set_ready(7, true)
	l.map_id = &"vesper_peak"
	l.late_join = false
	l.starting_round = 12
	l.add_chat(7, "ready?")
	l.countdown_end = 42.5
	var m: LobbyState = _lobby()
	m.from_array(l.to_array())
	assert_eq(m.slots.size(), 2)
	assert_eq(m.character_of(7), &"orlov")
	assert_true(m.is_ready(7))
	assert_eq(m.map_id, &"vesper_peak")
	assert_false(m.late_join)
	assert_eq(m.starting_round, 12)
	assert_eq(m.chat.size(), 1)
	assert_eq(m.countdown_end, 42.5)


func test_names_and_rounds_clamped() -> void:
	assert_eq(LobbyState.sanitize_name("  "), "Survivor")
	assert_eq(LobbyState.sanitize_name("a".repeat(40)).length(), LobbyState.NAME_MAX_CHARS)
	assert_eq(LobbyState.clamp_starting_round(0), 1)
	assert_eq(LobbyState.clamp_starting_round(500), 100)
