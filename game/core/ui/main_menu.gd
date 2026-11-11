# MainMenu — placeholder main menu: Solo, Host, Join <address>, Quit, plus a status line
# (e.g. "Host disconnected"). Final UI arrives in Step 15.
class_name MainMenu
extends Control

signal solo_requested
signal host_requested
signal join_requested(address: String)
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
	_status.add_theme_color_override(&"font_color", Color(1.0, 0.55, 0.45))
	box.add_child(_status)
	box.add_child(_button("Solo", func() -> void: solo_requested.emit()))
	box.add_child(_button("Host co-op", func() -> void: host_requested.emit()))
	_address = LineEdit.new()
	_address.text = String(Config.get_value(&"gameplay", &"last_join_address", "127.0.0.1"))
	_address.placeholder_text = "host address (ip[:port])"
	box.add_child(_address)
	box.add_child(_button("Join", func() -> void: join_requested.emit(_address.text.strip_edges())))
	box.add_child(_button("Quit", func() -> void: quit_requested.emit()))


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
