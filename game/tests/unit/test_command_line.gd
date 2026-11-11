extends GutTest


func test_parse_flags_and_values() -> void:
	var parsed: Dictionary = CommandLine.parse(
		PackedStringArray(["--host", "--join=127.0.0.1:9000", "--netsim=100,20,0.02", "x", "--"])
	)
	assert_eq(parsed["host"], "")
	assert_eq(parsed["join"], "127.0.0.1:9000")
	assert_eq(parsed["netsim"], "100,20,0.02")
	assert_false(parsed.has("x"))


func test_override() -> void:
	CommandLine.override_args = PackedStringArray(["--profile=p3"])
	CommandLine.use_override = true
	assert_eq(CommandLine.get_value("profile"), "p3")
	assert_true(CommandLine.has_flag("profile"))
	CommandLine.use_override = false
