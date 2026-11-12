# Co-op rules (Step 7): late-join points (GAME_DESIGN §13), the four characters (§14), Steam lobby
# metadata, name-tag distance fade and the Steam transport's graceful absence in the container.
extends GutTest


func test_late_join_points() -> void:
	assert_eq(PointsRules.late_join_points(0), 500)
	assert_eq(PointsRules.late_join_points(1), 750)
	assert_eq(PointsRules.late_join_points(10), 3000)
	assert_eq(PointsRules.late_join_points(18), 5000)
	assert_eq(PointsRules.late_join_points(40), 5000, "capped at 5000")


func test_four_characters_with_design_colours() -> void:
	var list: Array[CharacterDefinition] = CharacterDefinition.all_sorted()
	assert_eq(list.size(), 4)
	var ids: Array[StringName] = CharacterDefinition.ids_sorted()
	assert_eq(ids, [&"calloway", &"orlov", &"brandt", &"ashcombe"] as Array[StringName])
	# §13: white, blue, yellow, green.
	var c: Array[Color] = []
	for d: CharacterDefinition in list:
		c.append(d.color)
		assert_ne(d.full_name, "")
		assert_ne(d.bio, "")
	assert_gt(minf(c[0].r, minf(c[0].g, c[0].b)), 0.8, "Calloway white")
	assert_gt(c[1].b, c[1].r + 0.3, "Orlov blue")
	assert_gt(minf(c[2].r, c[2].g), c[2].b + 0.4, "Brandt yellow")
	assert_gt(c[3].g, maxf(c[3].r, c[3].b) + 0.3, "Ashcombe green")
	for i: int in list.size():
		for j: int in range(i + 1, list.size()):
			assert_ne(list[i].sleeve_color, list[j].sleeve_color, "distinct first-person sleeves")
	assert_eq(CharacterDefinition.for_slot(5).id, &"orlov", "slot fallback wraps")


func test_steam_metadata_round_trip() -> void:
	var meta: Dictionary = SteamTransport.lobby_metadata(&"vesper_peak", 3, 12, "0.7")
	assert_eq(meta["game"], SteamTransport.GAME_TAG)
	for k: String in SteamTransport.META_KEYS:
		assert_true(meta.has(k), k)
		assert_typeof(meta[k], TYPE_STRING)
	var back: Dictionary = SteamTransport.parse_lobby_metadata(meta)
	assert_eq(back["map"], &"vesper_peak")
	assert_eq(back["players"], 3)
	assert_eq(back["round"], 12)
	assert_eq(SteamTransport.lobby_metadata(&"x", 9, -2, "v")["players"], "4", "clamped")
	assert_true(SteamTransport.parse_lobby_metadata({"game": "other"}).is_empty(), "foreign lobby ignored")


func test_steam_unavailable_is_graceful() -> void:
	if SteamTransport.is_available():
		pass_test("GodotSteam installed: live test is a human task")
		return
	var t: SteamTransport = SteamTransport.new()
	assert_null(t.create_host(0, 3), "no Steam -> no peer, no crash")
	assert_null(t.create_client("123", 0))
	assert_false(SteamTransport.ensure_init())


func test_name_tag_fade() -> void:
	assert_eq(PlayerCharacter.tag_alpha(0.0), 1.0)
	assert_eq(PlayerCharacter.tag_alpha(PlayerCharacter.TAG_FULL_DISTANCE), 1.0)
	var mid: float = (PlayerCharacter.TAG_FULL_DISTANCE + PlayerCharacter.TAG_HIDE_DISTANCE) * 0.5
	assert_almost_eq(PlayerCharacter.tag_alpha(mid), 0.5, 0.01)
	assert_eq(PlayerCharacter.tag_alpha(PlayerCharacter.TAG_HIDE_DISTANCE + 5.0), 0.0)


func test_ping_kinds() -> void:
	assert_eq(PingSystem.kind_from_name(&"zombie"), PingSystem.Kind.ZOMBIE)
	assert_eq(PingSystem.kind_from_name(&"machine"), PingSystem.Kind.MACHINE)
	assert_eq(PingSystem.kind_from_name(&"bogus"), PingSystem.Kind.LOCATION)
	CoopAudio.ensure_events()
	for k: StringName in PingSystem.KIND_NAMES:
		assert_true(Audio.has_event(StringName("ping_%s" % k)), "cue for %s" % k)
