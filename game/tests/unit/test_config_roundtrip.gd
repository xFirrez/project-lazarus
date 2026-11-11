extends GutTest

const ConfigScript: GDScript = preload("res://core/autoload/config.gd")
const PATH: String = "user://test_settings_roundtrip.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_defaults_present() -> void:
	var cfg: Node = autofree(ConfigScript.new())
	assert_eq(cfg.get_value(&"video", &"fov"), 90.0)
	assert_eq(cfg.get_value(&"audio", &"Music"), 0.8)
	assert_eq(cfg.get_value(&"nope", &"nothing", 7), 7)


func test_values_and_bindings_round_trip() -> void:
	var a: Node = autofree(ConfigScript.new())
	a.set_value(&"video", &"fov", 104.0)
	a.set_value(&"input", &"invert_y", true)
	a.set_value(&"gameplay", &"player_name", "Tester")
	a.set_value(&"custom", &"new_key", 42)
	a._bindings["jump"] = ["key:J", "joy:0"]
	assert_eq(a.save_settings(PATH), OK)

	var b: Node = autofree(ConfigScript.new())
	assert_eq(b.load_settings(PATH), OK)
	assert_eq(b.get_value(&"video", &"fov"), 104.0)
	assert_eq(b.get_value(&"input", &"invert_y"), true)
	assert_eq(b.get_value(&"gameplay", &"player_name"), "Tester")
	assert_eq(b.get_value(&"custom", &"new_key"), 42)
	assert_eq(b.get_bindings(&"jump"), PackedStringArray(["key:J", "joy:0"]))
	# Untouched defaults survive the round trip.
	assert_eq(b.get_value(&"audio", &"SFX"), 1.0)


func test_load_missing_file_keeps_defaults() -> void:
	var cfg: Node = autofree(ConfigScript.new())
	assert_ne(cfg.load_settings("user://does_not_exist.cfg"), OK)
	assert_eq(cfg.get_value(&"video", &"fov"), 90.0)
