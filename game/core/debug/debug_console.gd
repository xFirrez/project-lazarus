# DebugConsole — drop-down console UI: log view, command line with Tab autocomplete and
# Up/Down history. Toggled with `~` (action toggle_console). Local only.
class_name DebugConsole
extends PanelContainer

const HISTORY_MAX: int = 64

var registry: CommandRegistry = null

var _log_view: RichTextLabel = null
var _line: LineEdit = null
var _history: PackedStringArray = []
var _history_index: int = -1


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(0, 320)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.05, 0.88)
	add_theme_stylebox_override(&"panel", style)
	var box: VBoxContainer = VBoxContainer.new()
	add_child(box)
	_log_view = RichTextLabel.new()
	_log_view.scroll_following = true
	_log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_view.add_theme_font_size_override(&"normal_font_size", 13)
	box.add_child(_log_view)
	_line = LineEdit.new()
	_line.placeholder_text = "command (Tab = complete, Up/Down = history, 'help')"
	_line.text_submitted.connect(_on_submitted)
	_line.gui_input.connect(_on_line_input)
	box.add_child(_line)
	for entry: Dictionary in Log.entries():
		_append(entry)
	Log.entry_added.connect(_append)


func toggle() -> void:
	visible = not visible
	if visible:
		_line.grab_focus()
		_line.clear()
	EventBus.console_toggled.emit(visible)


func _append(entry: Dictionary) -> void:
	if _log_view == null:
		return
	var colors: PackedStringArray = ["#8899aa", "#d8dde3", "#f2c14e", "#ff6b6b"]
	_log_view.append_text(
		"[color=%s]%s[/color]\n" % [colors[int(entry["level"])], Log.format_entry(entry).xml_escape()]
	)


func _on_submitted(text: String) -> void:
	var line: String = text.strip_edges()
	_line.clear()
	if line == "":
		return
	_history.append(line)
	if _history.size() > HISTORY_MAX:
		_history.remove_at(0)
	_history_index = -1
	Debug.run(line)


func _on_line_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed():
		return
	var key: InputEventKey = event
	match key.keycode:
		KEY_TAB:
			_autocomplete()
			_line.accept_event()
		KEY_UP:
			_step_history(1)
			_line.accept_event()
		KEY_DOWN:
			_step_history(-1)
			_line.accept_event()
		KEY_QUOTELEFT:
			toggle()
			_line.accept_event()


func _autocomplete() -> void:
	if registry == null:
		return
	var matches: PackedStringArray = registry.complete(_line.text.strip_edges())
	if matches.size() == 1:
		_line.text = matches[0] + " "
	elif matches.size() > 1:
		Log.info(&"console", "  ".join(matches))
		_line.text = _common_prefix(matches)
	_line.caret_column = _line.text.length()


func _step_history(direction: int) -> void:
	if _history.is_empty():
		return
	if _history_index == -1:
		_history_index = _history.size()
	_history_index = clampi(_history_index - direction, 0, _history.size())
	_line.text = _history[_history_index] if _history_index < _history.size() else ""
	_line.caret_column = _line.text.length()


static func _common_prefix(items: PackedStringArray) -> String:
	var prefix: String = items[0]
	for item: String in items:
		while not item.begins_with(prefix):
			prefix = prefix.substr(0, prefix.length() - 1)
	return prefix
