# MainMenu — the final main menu (DEVELOPMENT_PLAN Step 15 scope 2): the stencilled title over the
# animated 3D backdrop (the map's menu scene, run by Game), and the dossier tab list Solo /
# Multiplayer / Journal / Settings / Credits / Quit. Multiplayer opens a sub-panel: Host co-op,
# Join <ip[:port]>, Steam lobby (only when GodotSteam is available) and Back. A red-stamped status
# line reports session errors ("Host disconnected", "Join refused: lobby is full").
# Authority: local presentation.
class_name MainMenu
extends UiScreen

signal solo_requested
signal host_requested
signal join_requested(address: String)
signal steam_requested
signal settings_requested
signal journal_requested
signal credits_requested
signal quit_requested

var _status: Label = null
var _address: LineEdit = null
var _main: VBoxContainer = null
var _multi: VBoxContainer = null


func _init() -> void:
	content_width = 460.0
	backdrop_alpha = 0.35
	has_back = false
	align_left = true


func _build(c: VBoxContainer) -> void:
	var title: Label = UiTheme.title_label("PROJECT LAZARUS", 58)
	title.name = "Title"
	c.add_child(title)
	var sub: Label = UiTheme.type_label("VESPER PEAK  ·  CLASSIFIED  ·  GROUP VESPER  ·  1962", 18, UiTheme.TEXT_LIGHT)
	c.add_child(sub)
	c.add_child(_rule())
	_status = UiTheme.type_label("", 18, Color(1.0, 0.45, 0.38))
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(_status)
	_main = VBoxContainer.new()
	_main.name = "Main"
	_main.add_theme_constant_override(&"separation", 8)
	c.add_child(_main)
	_main.add_child(_named(UiTheme.button("Solo", func() -> void: solo_requested.emit()), "Solo"))
	_main.add_child(_named(UiTheme.button("Multiplayer", _show_multi), "Multiplayer"))
	_main.add_child(_named(UiTheme.button("Journal", func() -> void: journal_requested.emit()), "Journal"))
	_main.add_child(_named(UiTheme.button("Settings", func() -> void: settings_requested.emit()), "Settings"))
	_main.add_child(_named(UiTheme.button("Credits", func() -> void: credits_requested.emit()), "Credits"))
	_main.add_child(_named(UiTheme.button("Quit", func() -> void: quit_requested.emit()), "Quit"))
	_multi = VBoxContainer.new()
	_multi.name = "Multiplayer"
	_multi.visible = false
	_multi.add_theme_constant_override(&"separation", 8)
	c.add_child(_multi)
	_multi.add_child(UiTheme.type_label("MULTIPLAYER — up to 4 survivors", 20, UiTheme.TEXT_LIGHT))
	_multi.add_child(_named(UiTheme.button("Host co-op", func() -> void: host_requested.emit()), "Host"))
	var join_row: HBoxContainer = HBoxContainer.new()
	_multi.add_child(join_row)
	_address = LineEdit.new()
	_address.name = "Address"
	_address.text = String(Config.get_value(&"gameplay", &"last_join_address", "127.0.0.1"))
	_address.placeholder_text = "host address (ip[:port])"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.text_submitted.connect(func(t: String) -> void: join_requested.emit(t.strip_edges()))
	join_row.add_child(_address)
	var join: Button = UiTheme.button("Join", func() -> void: join_requested.emit(_address.text.strip_edges()))
	join.name = "Join"
	join.custom_minimum_size = Vector2(100, 44)
	join_row.add_child(join)
	if SteamTransport.is_available():
		_multi.add_child(
			_named(UiTheme.button("Steam lobby (invite friends)", func() -> void: steam_requested.emit()), "Steam")
		)
	_multi.add_child(_named(UiTheme.button("Back", _show_main), "MultiBack"))
	var hint: Label = UiTheme.type_label(
		(
			"Online without Steam: the host forwards UDP %d or everyone joins one VPN (docs/NETWORKING.md)"
			% Net.DEFAULT_PORT
		),
		14
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_multi.add_child(hint)
	var ver: Label = UiTheme.type_label(BuildInfo.describe(), 13, UiTheme.TEXT_LIGHT)
	ver.name = "Version"
	ver.modulate.a = 0.6
	c.add_child(ver)
	if CrashLog.last_crash_path != "":
		_status.text = (
			"The last session ended unexpectedly. A crash log was saved to %s"
			% ProjectSettings.globalize_path(CrashLog.last_crash_path)
		)
		CrashLog.last_crash_path = ""  # shown once


func _named(b: Button, n: String) -> Button:
	b.name = n
	return b


func _rule() -> Control:
	var r: ColorRect = ColorRect.new()
	r.color = UiTheme.RED_INK
	r.custom_minimum_size = Vector2(0, 3)
	return r


func _show_multi() -> void:
	_main.visible = false
	_multi.visible = true
	has_back = true
	UiTheme.intro(_multi)
	UiTheme.focus_first(_multi)


func _show_main() -> void:
	_multi.visible = false
	_main.visible = true
	has_back = false
	UiTheme.intro(_main)
	UiTheme.focus_first(_main)


func back() -> void:
	if _multi != null and _multi.visible:
		Audio.play_event(&"ui_back")
		_show_main()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _multi != null and _multi.visible:
		get_viewport().set_input_as_handled()
		back()


func set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func status_text() -> String:
	return _status.text if _status != null else ""
