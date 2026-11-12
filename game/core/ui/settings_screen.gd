# SettingsScreen — settings v1 from the main menu: player name, mouse sensitivity, field of view,
# master volume, quality preset, UPnP when hosting, teammate name tags. Values live in Config
# (user://settings.cfg); the full options menu (bindings, accessibility) is Step 15.
# Authority: local presentation.
class_name SettingsScreen
extends Control

signal back_pressed

const QUALITY: PackedStringArray = ["low", "medium", "high", "ultra"]


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
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override(&"separation", 10)
	center.add_child(box)
	var title: Label = Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override(&"font_size", 30)
	box.add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 16)
	box.add_child(grid)
	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = String(Config.get_value(&"gameplay", &"player_name", "Survivor"))
	name_edit.max_length = LobbyState.NAME_MAX_CHARS
	name_edit.text_changed.connect(
		func(t: String) -> void:
			Config.set_value(&"gameplay", &"player_name", LobbyState.sanitize_name(t))
			Net.local_name = LobbyState.sanitize_name(t)
	)
	_row(grid, "Player name", name_edit)
	_row(grid, "Mouse sensitivity", _slider(&"input", &"mouse_sensitivity", 0.1, 4.0, 0.05))
	_row(grid, "Field of view", _slider(&"video", &"fov", 70.0, 110.0, 1.0))
	_row(grid, "Master volume", _slider(&"audio", &"Master", 0.0, 1.0, 0.05))
	var quality: OptionButton = OptionButton.new()
	for q: String in QUALITY:
		quality.add_item(q)
	quality.select(maxi(QUALITY.find(String(Config.get_value(&"video", &"quality_preset", "high"))), 0))
	quality.item_selected.connect(func(i: int) -> void: Config.set_value(&"video", &"quality_preset", QUALITY[i]))
	_row(grid, "Graphics quality", quality)
	_row(grid, "Try UPnP when hosting", _check(&"gameplay", &"upnp"))
	_row(grid, "Teammate name tags", _check(&"gameplay", &"name_tags"))
	var back: Button = Button.new()
	back.text = "Save and back"
	back.custom_minimum_size = Vector2(0, 40)
	back.pressed.connect(
		func() -> void:
			Config.save_settings()
			Audio.play_event(&"ui_click")
			back_pressed.emit()
	)
	box.add_child(back)


func _row(grid: GridContainer, label: String, control: Control) -> void:
	var l: Label = Label.new()
	l.text = label
	grid.add_child(l)
	control.custom_minimum_size = Vector2(240, 0)
	grid.add_child(control)


func _slider(section: StringName, key: StringName, lo: float, hi: float, step: float) -> HSlider:
	var s: HSlider = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Config.get_value(section, key, lo))
	s.value_changed.connect(func(v: float) -> void: Config.set_value(section, key, v))
	return s


func _check(section: StringName, key: StringName) -> CheckBox:
	var c: CheckBox = CheckBox.new()
	c.button_pressed = bool(Config.get_value(section, key, true))
	c.toggled.connect(func(on: bool) -> void: Config.set_value(section, key, on))
	return c
