extends GutTest


func test_maps_discovered() -> void:
	var sandbox: MapDefinition = Content.get_map(&"sandbox")
	assert_not_null(sandbox)
	assert_true(sandbox.is_test_map)
	assert_true(ResourceLoader.exists(sandbox.scene_path))


func test_audio_buses() -> void:
	var names: PackedStringArray = Audio.bus_names()
	for bus: String in ["Master", "Music", "SFX", "Weapons", "Zombies", "UI", "VO", "Ambience"]:
		assert_has(names, bus)
