# MainMenu — main menu v1 (DEVELOPMENT_PLAN Step 7): Solo, Host co-op, Join <ip[:port]>, Steam
# (only when GodotSteam is available), Settings, Quit, plus a status line (e.g. "Host
# disconnected", "Join refused: lobby is full"). Final art in Step 15.
# Authority: local presentation.
class_name MainMenu
extends Control

signal solo_requested
signal host_requested
signal join_requested(address: String)
signal steam_requested
signal settings_requested
signal quit_requested

var _status: Label = null
var _address: LineEdit = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override(&"separation", 10)
	center.add_child(box)
	var title: Label = Label.new()
	title.text = "PROJECT LAZARUS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 40)
	box.add_child(title)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override(&"font_color", Color(1.0, 0.55, 0.45))
	box.add_child(_status)
	box.add_child(_button("Solo", func() -> void: solo_requested.emit()))
	box.add_child(_button("Host co-op", func() -> void: host_requested.emit()))
	var join_row: HBoxContainer = HBoxContainer.new()
	box.add_child(join_row)
	_address = LineEdit.new()
	_address.text = String(Config.get_value(&"gameplay", &"last_join_address", "127.0.0.1"))
	_address.placeholder_text = "host address (ip[:port])"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.text_submitted.connect(func(t: String) -> void: join_requested.emit(t.strip_edges()))
	join_row.add_child(_address)
	var join: Button = _button("Join", func() -> void: join_requested.emit(_address.text.strip_edges()))
	join.custom_minimum_size = Vector2(90, 40)
	join_row.add_child(join)
	if SteamTransport.is_available():
		box.add_child(_button("Steam lobby (invite friends)", func() -> void: steam_requested.emit()))
	box.add_child(_button("Settings", func() -> void: settings_requested.emit()))
	box.add_child(_button("Quit", func() -> void: quit_requested.emit()))
	var hint: Label = Label.new()
	hint.text = (
		"Online without Steam: the host forwards UDP %d or everyone joins one VPN (docs/NETWORKING.md)"
		% (Net.DEFAULT_PORT)
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override(&"font_size", 13)
	hint.add_theme_color_override(&"font_color", Color(0.6, 0.62, 0.66))
	box.add_child(hint)


func set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func status_text() -> String:
	return _status.text if _status != null else ""


func _button(text: String, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(func() -> void: Audio.play_event(&"ui_click"))
	b.pressed.connect(on_press)
	return b
