# CommandRegistry — debug console commands with typed arguments, autocomplete and help.
# Pure logic (no UI) so it can be unit-tested and driven from `--exec=` on headless peers.
# A command handler receives typed args as an Array and returns a String result.
class_name CommandRegistry
extends RefCounted

var _commands: Dictionary = {}  # name -> {handler, args: Array[[name, Variant.Type]], help}


# args: Array of [arg_name: String, type: int (TYPE_INT/FLOAT/STRING/BOOL), optional default]
func register(name: String, handler: Callable, args: Array = [], help: String = "") -> void:
	_commands[name] = {"handler": handler, "args": args, "help": help}


func has(name: String) -> bool:
	return _commands.has(name)


func names() -> PackedStringArray:
	var out: PackedStringArray = []
	for name: String in _commands:
		out.append(name)
	out.sort()
	return out


func usage(name: String) -> String:
	if not _commands.has(name):
		return ""
	var parts: PackedStringArray = [name]
	for arg: Array in _commands[name]["args"]:
		var label: String = "%s:%s" % [arg[0], type_string(int(arg[1]))]
		parts.append(("[%s]" if arg.size() > 2 else "<%s>") % label)
	return " ".join(parts)


func help_text() -> String:
	var lines: PackedStringArray = []
	for name: String in names():
		lines.append("%s — %s" % [usage(name), _commands[name]["help"]])
	return "\n".join(lines)


func complete(prefix: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for name: String in names():
		if name.begins_with(prefix):
			out.append(name)
	return out


static func tokenize(line: String) -> PackedStringArray:
	var tokens: PackedStringArray = []
	var current: String = ""
	var quoted: bool = false
	for ch: String in line:
		if ch == '"':
			quoted = not quoted
		elif ch == " " and not quoted:
			if current != "":
				tokens.append(current)
				current = ""
		else:
			current += ch
	if current != "":
		tokens.append(current)
	return tokens


func execute(line: String) -> String:
	var tokens: PackedStringArray = tokenize(line.strip_edges())
	if tokens.is_empty():
		return ""
	var name: String = tokens[0]
	if not _commands.has(name):
		var suggestions: PackedStringArray = complete(name.substr(0, 2))
		return (
			"Unknown command '%s'.%s"
			% [name, (" Did you mean: " + ", ".join(suggestions)) if not suggestions.is_empty() else ""]
		)
	var spec: Array = _commands[name]["args"]
	var values: Array = []
	for i: int in spec.size():
		var arg: Array = spec[i]
		if i + 1 >= tokens.size():
			if arg.size() > 2:
				values.append(arg[2])
				continue
			return "Usage: %s" % usage(name)
		var parsed: Variant = _parse_arg(tokens[i + 1], int(arg[1]))
		if parsed == null:
			return (
				"Bad value '%s' for %s (expected %s). Usage: %s"
				% [tokens[i + 1], arg[0], type_string(int(arg[1])), usage(name)]
			)
		values.append(parsed)
	var handler: Callable = _commands[name]["handler"]
	var result: Variant = handler.call(values)
	return "" if result == null else str(result)


static func _parse_arg(token: String, type: int) -> Variant:
	match type:
		TYPE_INT:
			return token.to_int() if token.is_valid_int() else null
		TYPE_FLOAT:
			return token.to_float() if token.is_valid_float() else null
		TYPE_BOOL:
			var t: String = token.to_lower()
			if t in ["1", "true", "on", "yes"]:
				return true
			if t in ["0", "false", "off", "no"]:
				return false
			return null
		_:
			return token
