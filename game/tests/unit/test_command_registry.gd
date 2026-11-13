extends GutTest

var reg: CommandRegistry
var calls: Array = []


func before_each() -> void:
	reg = CommandRegistry.new()
	calls.clear()
	reg.register("echo", func(a: Array) -> String: return String(a[0]), [["text", TYPE_STRING]], "echo")
	reg.register(
		"netsim",
		func(a: Array) -> String:
			calls.append(a)
			return "ok",
		[["ms", TYPE_FLOAT], ["jitter", TYPE_FLOAT, 0.0], ["loss", TYPE_FLOAT, 0.0]],
		"sim"
	)
	reg.register("net_status", func(_a: Array) -> String: return "status", [], "status")


func test_typed_args_and_defaults() -> void:
	assert_eq(reg.execute("netsim 100 20 0.02"), "ok")
	assert_eq(calls[0], [100.0, 20.0, 0.02])
	reg.execute("netsim 50")
	assert_eq(calls[1], [50.0, 0.0, 0.0])


func test_bad_and_missing_args() -> void:
	assert_string_contains(reg.execute("netsim abc"), "Bad value")
	assert_string_contains(reg.execute("netsim"), "Usage")
	assert_eq(calls.size(), 0)


func test_quoted_tokens() -> void:
	assert_eq(reg.execute('echo "hello world"'), "hello world")


func test_unknown_command_suggests() -> void:
	assert_string_contains(reg.execute("net_stat"), "Did you mean")


func test_autocomplete() -> void:
	assert_eq(reg.complete("net"), PackedStringArray(["net_status", "netsim"]))
	assert_eq(reg.complete("ec"), PackedStringArray(["echo"]))
	assert_eq(reg.complete("zz").size(), 0)


func test_help_lists_everything() -> void:
	var help: String = reg.help_text()
	for name: String in ["echo", "netsim", "net_status"]:
		assert_string_contains(help, name)
	assert_string_contains(reg.usage("netsim"), "[jitter:float]")


func test_builtin_console_commands_registered() -> void:
	for name: String in ["help", "net_status", "netsim", "quit", "overlay", "host", "join", "solo"]:
		assert_true(Debug.commands.has(name), name)
