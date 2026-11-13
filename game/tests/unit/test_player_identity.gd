extends GutTest

const PATH: String = "user://test_identity.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_generated_uuid_is_v4() -> void:
	for i: int in 50:
		assert_true(PlayerIdentity.is_valid_uuid(PlayerIdentity.generate_uuid()))


func test_uuids_unique() -> void:
	var seen: Dictionary = {}
	for i: int in 200:
		seen[PlayerIdentity.generate_uuid()] = true
	assert_eq(seen.size(), 200)


func test_uid_persists_across_loads() -> void:
	var first: String = PlayerIdentity.load_or_create(PATH)
	assert_true(PlayerIdentity.is_valid_uuid(first))
	assert_true(FileAccess.file_exists(PATH))
	assert_eq(PlayerIdentity.load_or_create(PATH), first)
	assert_eq(PlayerIdentity.load_or_create(PATH), first)


func test_invalid_stored_uid_is_replaced() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("identity", "player_uid", "not-a-uuid")
	cfg.save(PATH)
	var uid: String = PlayerIdentity.load_or_create(PATH)
	assert_true(PlayerIdentity.is_valid_uuid(uid))
	assert_eq(PlayerIdentity.load_or_create(PATH), uid)


func test_profiles_have_distinct_paths() -> void:
	assert_ne(PlayerIdentity.path_for_profile(""), PlayerIdentity.path_for_profile("p2"))
