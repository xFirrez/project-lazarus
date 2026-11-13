# SettingsScreen — the full options menu (GAME_DESIGN §18, DEVELOPMENT_PLAN Step 15 scope 4) as a
# manila-tabbed dossier: VIDEO (preset + individual overrides, window, FOV, viewmodel FOV, bob /
# shake), AUDIO (every bus), CONTROLS (mouse, ADS multiplier, invert, toggles, full keyboard /
# mouse rebinding), GAMEPAD (sensitivity + pad rebinding) and GAMEPLAY / ACCESSIBILITY (name,
# HUD scale, colorblind palette, subtitles, name tags, UPnP). Changes apply live; APPLY saves
# (user://settings.cfg), REVERT restores the values from when the screen opened (or the last
# apply), BACK saves and leaves. Used from the main menu and the pause menu.
# Authority: local presentation.
class_name SettingsScreen
extends UiScreen

const QUALITY: PackedStringArray = ["low", "medium", "high", "ultra"]
const TRISTATE: PackedStringArray = ["preset", "on", "off"]
const FPS_CAPS: Array[int] = [0, 30, 60, 90, 120, 144, 165, 240]
# Actions shown in the rebinding lists (debug toggles stay fixed).
const REBIND_ACTIONS: PackedStringArray = [
	"move_forward",
	"move_back",
	"move_left",
	"move_right",
	"jump",
	"sprint",
	"crouch",
	"fire",
	"aim",
	"reload",
	"interact",
	"melee",
	"lethal",
	"tactical",
	"placeable",
	"alt_fire",
	"carry_drop",
	"weapon_next",
	"weapon_prev",
	"weapon_slot_1",
	"weapon_slot_2",
	"weapon_slot_3",
	"scoreboard",
	"ping",
	"pause",
]
const PAD_ONLY_ACTIONS: PackedStringArray = ["look_up", "look_down", "look_left", "look_right"]

var in_match: bool = false
var tabs: TabContainer = null
var capture_action: String = ""  # waiting for an input to bind ("" = not capturing)
var capture_pad: bool = false

var _snapshot: Dictionary = {}
var _capture_button: Button = null
var _bind_buttons: Dictionary = {}  # "<action>|kb" / "<action>|pad" -> Button
var _dirty_label: Label = null


func _init() -> void:
	screen_title = "SETTINGS"
	content_width = 980.0


func _build(c: VBoxContainer) -> void:
	_snapshot = Config.snapshot()
	tabs = TabContainer.new()
	tabs.name = "Tabs"
	tabs.custom_minimum_size = Vector2(980, 500)
	c.add_child(tabs)
	_video_tab()
	_audio_tab()
	_controls_tab()
	_gamepad_tab()
	_gameplay_tab()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	c.add_child(row)
	var apply_b: Button = UiTheme.button("Apply", apply_changes)
	apply_b.name = "ApplyButton"
	row.add_child(apply_b)
	var revert_b: Button = UiTheme.button("Revert", revert_changes)
	revert_b.name = "RevertButton"
	row.add_child(revert_b)
	var reset_b: Button = UiTheme.button("Default bindings", _reset_bindings)
	reset_b.name = "ResetBindingsButton"
	row.add_child(reset_b)
	var back_b: Button = UiTheme.button("Back", back)
	back_b.name = "BackButton"
	row.add_child(back_b)
	_dirty_label = UiTheme.type_label("", 16, UiTheme.TEXT_DIM)
	row.add_child(_dirty_label)
	for b: Button in [apply_b, revert_b, reset_b, back_b]:
		b.custom_minimum_size = Vector2(170, 44)


func apply_changes() -> void:
	Config.save_settings()
	_snapshot = Config.snapshot()
	if _dirty_label != null:
		_dirty_label.text = "saved"


func revert_changes() -> void:
	Config.restore(_snapshot)
	_rebuild_tabs()
	if _dirty_label != null:
		_dirty_label.text = "reverted"


func back() -> void:
	if capture_action != "":
		cancel_capture()
		return
	Config.save_settings()
	super.back()


func _rebuild_tabs() -> void:
	var current: int = tabs.current_tab
	for ch: Node in tabs.get_children():
		tabs.remove_child(ch)
		ch.queue_free()
	_bind_buttons.clear()
	_video_tab()
	_audio_tab()
	_controls_tab()
	_gamepad_tab()
	_gameplay_tab()
	tabs.current_tab = clampi(current, 0, tabs.get_tab_count() - 1)


# --- tabs ----------------------------------------------------------------------------------------


func _page(title: String) -> GridContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = title.capitalize().replace(" ", "")
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count() - 1, title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", 24)
	grid.add_theme_constant_override(&"v_separation", 8)
	scroll.add_child(grid)
	return grid


func _video_tab() -> void:
	var g: GridContainer = _page("VIDEO")
	var q: OptionButton = OptionButton.new()
	for id: String in QUALITY:
		q.add_item(id.capitalize())
	q.select(maxi(QUALITY.find(String(Config.get_value(&"video", &"quality_preset", "high"))), 0))
	q.item_selected.connect(func(i: int) -> void: _set_value(&"video", &"quality_preset", QUALITY[i]))
	_row(g, "Quality preset", q)
	_row(g, "Resolution scale (0 = preset)", _slider(&"video", &"render_scale", 0.0, 2.0, 0.05))
	_row(g, "Shadow-casting lights (-1 = preset)", _slider(&"video", &"max_shadow_lights", -1.0, 16.0, 1.0))
	_row(g, "SSAO", _option(&"video", &"ssao", TRISTATE))
	_row(g, "Glow", _option(&"video", &"glow", TRISTATE))
	_row(g, "Volumetric fog", _option(&"video", &"volumetric_fog", TRISTATE))
	_row(g, "Particle density (-1 = preset)", _slider(&"video", &"particle_density", -1.0, 1.0, 0.05))
	_row(g, "View distance m (0 = preset)", _slider(&"video", &"view_distance", 0.0, 400.0, 10.0))
	_row(g, "Fullscreen", _check(&"video", &"fullscreen", false))
	_row(g, "V-sync", _check(&"video", &"vsync", true))
	var fps: OptionButton = OptionButton.new()
	for cap: int in FPS_CAPS:
		fps.add_item("Unlimited" if cap == 0 else str(cap))
	fps.select(maxi(FPS_CAPS.find(int(Config.get_value(&"video", &"fps_cap", 0))), 0))
	fps.item_selected.connect(func(i: int) -> void: _set_value(&"video", &"fps_cap", FPS_CAPS[i]))
	_row(g, "FPS cap", fps)
	_row(g, "Field of view", _slider(&"video", &"fov", 70.0, 110.0, 1.0))
	_row(g, "Camera bob", _slider(&"video", &"camera_bob_scale", 0.0, 1.0, 0.05))
	_row(g, "Screen shake", _slider(&"video", &"screen_shake_scale", 0.0, 1.0, 0.05))


func _audio_tab() -> void:
	var g: GridContainer = _page("AUDIO")
	for bus: String in ["Master", "Music", "SFX", "Weapons", "Zombies", "VO", "Ambience", "UI"]:
		_row(g, "%s volume" % bus, _slider(&"audio", StringName(bus), 0.0, 1.0, 0.05))
	_row(g, "Subtitles (voice-over, quips, announcer)", _check(&"gameplay", &"subtitles", true))


func _controls_tab() -> void:
	var g: GridContainer = _page("CONTROLS")
	_row(g, "Mouse sensitivity", _slider(&"input", &"mouse_sensitivity", 0.1, 4.0, 0.05))
	_row(g, "ADS sensitivity multiplier", _slider(&"input", &"ads_sensitivity_multiplier", 0.2, 1.5, 0.05))
	_row(g, "Invert look Y", _check(&"input", &"invert_y", false))
	_row(g, "Toggle aim (ADS)", _check(&"input", &"toggle_ads", false))
	_row(g, "Toggle crouch", _check(&"input", &"toggle_crouch", true))
	_row(g, "Toggle sprint", _check(&"input", &"toggle_sprint", false))
	var hdr: Label = UiTheme.type_label(
		"KEYBOARD / MOUSE — select, then press a key (Delete clears)", 18, UiTheme.MANILA
	)
	g.add_child(hdr)
	g.add_child(Control.new())
	for action: String in REBIND_ACTIONS:
		_row(g, action_label(action), _bind_button(action, false))


func _gamepad_tab() -> void:
	var g: GridContainer = _page("GAMEPAD")
	_row(g, "Look sensitivity", _slider(&"input", &"gamepad_sensitivity", 0.2, 3.0, 0.05))
	var hdr: Label = UiTheme.type_label(
		"GAMEPAD — select, then press a button / move a stick or trigger", 18, UiTheme.MANILA
	)
	g.add_child(hdr)
	g.add_child(Control.new())
	for action: String in PAD_ONLY_ACTIONS + REBIND_ACTIONS:
		_row(g, action_label(action), _bind_button(action, true))


func _gameplay_tab() -> void:
	var g: GridContainer = _page("GAMEPLAY")
	var name_edit: LineEdit = LineEdit.new()
	name_edit.name = "PlayerName"
	name_edit.text = String(Config.get_value(&"gameplay", &"player_name", "Survivor"))
	name_edit.max_length = LobbyState.NAME_MAX_CHARS
	name_edit.editable = not in_match
	name_edit.text_changed.connect(
		func(t: String) -> void:
			_set_value(&"gameplay", &"player_name", LobbyState.sanitize_name(t))
			Net.local_name = LobbyState.sanitize_name(t)
	)
	_row(g, "Player name", name_edit)
	_row(g, "HUD scale", _slider(&"gameplay", &"hud_scale", UiTheme.HUD_SCALE_MIN, UiTheme.HUD_SCALE_MAX, 0.05))
	_row(g, "Colorblind palette", _option(&"gameplay", &"colorblind_mode", UiTheme.COLORBLIND_MODES))
	_row(g, "Subtitles", _check(&"gameplay", &"subtitles", true))
	_row(g, "Teammate name tags", _check(&"gameplay", &"name_tags", true))
	_row(g, "Try UPnP when hosting", _check(&"gameplay", &"upnp", true))


# --- rows ----------------------------------------------------------------------------------------


static func action_label(action: String) -> String:
	return action.replace("_", " ").capitalize()


func _row(grid: GridContainer, label: String, control: Control) -> void:
	var l: Label = Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(420, 0)
	grid.add_child(l)
	control.custom_minimum_size = Vector2(maxf(control.custom_minimum_size.x, 320), 36)
	grid.add_child(control)


func _set_value(section: StringName, key: StringName, value: Variant) -> void:
	Config.set_value(section, key, value)
	if _dirty_label != null:
		_dirty_label.text = "unsaved changes"


func _slider(section: StringName, key: StringName, lo: float, hi: float, step: float) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var s: HSlider = HSlider.new()
	s.name = "Slider"
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.focus_mode = Control.FOCUS_ALL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value = float(Config.get_value(section, key, lo))
	var readout: Label = UiTheme.type_label("", 16, UiTheme.TEXT_LIGHT)
	readout.custom_minimum_size = Vector2(56, 0)
	readout.text = _fmt(s.value, step)
	s.value_changed.connect(
		func(v: float) -> void:
			readout.text = _fmt(v, step)
			_set_value(section, key, int(v) if step >= 1.0 else v)
	)
	row.add_child(s)
	row.add_child(readout)
	return row


static func _fmt(v: float, step: float) -> String:
	return str(int(v)) if step >= 1.0 else "%.2f" % v


func _check(section: StringName, key: StringName, fallback: bool) -> CheckBox:
	var c: CheckBox = CheckBox.new()
	c.text = ""
	c.button_pressed = bool(Config.get_value(section, key, fallback))
	c.toggled.connect(func(on: bool) -> void: _set_value(section, key, on))
	return c


func _option(section: StringName, key: StringName, values: PackedStringArray) -> OptionButton:
	var o: OptionButton = OptionButton.new()
	for v: String in values:
		o.add_item(v.capitalize())
	o.select(maxi(values.find(String(Config.get_value(section, key, values[0]))), 0))
	o.item_selected.connect(func(i: int) -> void: _set_value(section, key, values[i]))
	return o


# --- rebinding -----------------------------------------------------------------------------------


static func is_pad_binding(b: String) -> bool:
	return b.begins_with("joy:") or b.begins_with("axis:")


static func binding_label(b: String) -> String:
	if b == "":
		return "—"
	var parts: PackedStringArray = b.split(":")
	match parts[0]:
		"key":
			return parts[1]
		"mouse":
			return ["", "Mouse L", "Mouse R", "Mouse M", "Wheel Up", "Wheel Down"][clampi(int(parts[1]), 0, 5)]
		"joy":
			return "Pad %s" % parts[1]
		"axis":
			return "Axis %s%s" % [parts[1], "+" if parts[2] == "1" else "−"]
	return b


func current_binding(action: String, pad: bool) -> String:
	for b: String in Config.get_bindings(StringName(action)):
		if is_pad_binding(b) == pad:
			return b
	return ""


func _bind_button(action: String, pad: bool) -> Button:
	var b: Button = Button.new()
	b.name = "Bind_%s_%s" % [action, "pad" if pad else "kb"]
	b.text = binding_label(current_binding(action, pad))
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void: begin_capture(action, pad, b))
	_bind_buttons["%s|%s" % [action, "pad" if pad else "kb"]] = b
	return b


func begin_capture(action: String, pad: bool, button: Button = null) -> void:
	capture_action = action
	capture_pad = pad
	_capture_button = button
	if button != null:
		button.text = "press %s ..." % ("a button" if pad else "a key")
	Audio.play_event(&"ui_click")


func cancel_capture() -> void:
	if _capture_button != null and is_instance_valid(_capture_button):
		_capture_button.text = binding_label(current_binding(capture_action, capture_pad))
	capture_action = ""
	_capture_button = null


# Replaces the action's first binding of the captured kind (keyboard/mouse or pad); the other kind
# is kept. An input already bound to another action of the same kind is moved (swap-free: the
# other action loses it) so two actions never share one key silently.
func bind_captured(binding: String) -> void:
	if capture_action == "":
		return
	var action: String = capture_action
	var list: PackedStringArray = Config.get_bindings(StringName(action))
	var out: PackedStringArray = []
	var replaced: bool = false
	for b: String in list:
		if is_pad_binding(b) == capture_pad and not replaced:
			replaced = true
			if binding != "":
				out.append(binding)
		else:
			out.append(b)
	if not replaced and binding != "":
		out.append(binding)
	if binding != "":
		for other: String in REBIND_ACTIONS + PAD_ONLY_ACTIONS:
			if other == action:
				continue
			var ob: PackedStringArray = Config.get_bindings(StringName(other))
			if ob.has(binding):
				ob.remove_at(ob.find(binding))
				Config.set_bindings(StringName(other), ob)
				var key: String = "%s|%s" % [other, "pad" if capture_pad else "kb"]
				if _bind_buttons.has(key):
					(_bind_buttons[key] as Button).text = binding_label(current_binding(other, capture_pad))
	Config.set_bindings(StringName(action), out)
	if _capture_button != null and is_instance_valid(_capture_button):
		_capture_button.text = binding_label(current_binding(action, capture_pad))
	capture_action = ""
	_capture_button = null
	if _dirty_label != null:
		_dirty_label.text = "unsaved changes"


func _reset_bindings() -> void:
	Config.reset_bindings()
	_rebuild_tabs()


func _input(event: InputEvent) -> void:
	if capture_action == "":
		super._input(event)
		return
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < 0.6:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey:
		var k: InputEventKey = event
		var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		if code == KEY_ESCAPE:
			cancel_capture()
			return
		if code == KEY_DELETE or code == KEY_BACKSPACE:
			bind_captured("")
			return
	var b: String = InputDefaults.event_to_binding(event)
	if b == "" or is_pad_binding(b) != capture_pad:
		return  # wrong kind of input for this column: keep waiting
	bind_captured(b)
