# PauseMenu — in-match pause (GAME_DESIGN §15, DEVELOPMENT_PLAN Step 15 scope 5): Resume, Settings
# (the full options screen over the match), Leave match, Quit to desktop, and the hand-drawn
# facility map of visited zones. SOLO pauses the game (scene tree paused + the session clock
# frozen, so host-time timers resume exactly); CO-OP shows the same menu without pausing (gameplay
# input is blocked while it is open; teammates keep playing). Opened with the `pause` action
# (Escape / pad Start); Escape / pad B / Start closes it.
# Authority: local presentation (solo pause only when no remote peer is connected).
class_name PauseMenu
extends Control

signal leave_requested
signal quit_requested

const LAYER: int = 12

var match_node: Match = null
var is_open: bool = false
var paused_game: bool = false  # this open paused the tree (solo)
var visited: Dictionary = {}  # zone id -> true (local player)

var _panel: Control = null
var _map: FacilityMap = null
var _note: Label = null
var _settings: SettingsScreen = null
var _sample: float = 0.0


func _ready() -> void:
	name = "PauseMenu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UiTheme.apply(self)
	visible = false
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.03, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 36)
	center.add_child(row)
	_panel = row
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "Buttons"
	col.custom_minimum_size = Vector2(340, 0)
	col.add_theme_constant_override(&"separation", 10)
	row.add_child(col)
	col.add_child(UiTheme.title_label("PAUSED", 56))
	_note = UiTheme.type_label("", 16, UiTheme.TEXT_LIGHT)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_note)
	col.add_child(_named(UiTheme.button("Resume", close), "Resume"))
	col.add_child(_named(UiTheme.button("Settings", _open_settings), "Settings"))
	col.add_child(_named(UiTheme.button("Leave match", func() -> void: leave_requested.emit()), "Leave"))
	col.add_child(_named(UiTheme.button("Quit to desktop", func() -> void: quit_requested.emit()), "Quit"))
	_map = FacilityMap.new()
	_map.name = "FacilityMap"
	_map.match_node = match_node
	_map.visited = visited
	row.add_child(_map)


func _named(b: Button, n: String) -> Button:
	b.name = n
	return b


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	paused_game = Net.can_pause()
	if paused_game:
		get_tree().paused = true
		Net.set_clock_paused(true)
	PlayerInputSource.ui_blocked = true
	_note.text = (
		"Solo: the mountain waits for you."
		if paused_game
		else "Co-op: the game keeps running — your survivor stands still while this is open."
	)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.play_event(&"ui_pause")
	UiTheme.intro(_panel)
	UiTheme.focus_first(_panel)


func close() -> void:
	if not is_open:
		return
	if _settings != null:
		_close_settings()
	is_open = false
	visible = false
	if paused_game:
		Net.set_clock_paused(false)
		get_tree().paused = false
	paused_game = false
	PlayerInputSource.ui_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if DisplayServer.get_name() != "headless" else Input.mouse_mode
	Audio.play_event(&"ui_back")


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func _open_settings() -> void:
	_settings = SettingsScreen.new()
	_settings.in_match = true
	_settings.backdrop_alpha = 0.9
	_settings.back_pressed.connect(_close_settings)
	add_child(_settings)
	_panel.visible = false


func _close_settings() -> void:
	if _settings != null:
		_settings.queue_free()
		_settings = null
	_panel.visible = true
	UiTheme.focus_first(_panel)


func _exit_tree() -> void:
	# Never leave the tree paused / input blocked when the match ends with the menu open.
	if is_open:
		if paused_game:
			Net.set_clock_paused(false)
			get_tree().paused = false
		PlayerInputSource.ui_blocked = false


func _process(delta: float) -> void:
	_sample -= delta
	if _sample > 0.0 or match_node == null or match_node.players == null or match_node.zones == null:
		return
	_sample = 0.5
	var me: PlayerCharacter = match_node.players.local_avatar()
	if me != null:
		var z: StringName = match_node.zones.zone_at(me.global_position)
		if z != &"":
			visited[z] = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if not is_open and DocumentReader.current != null and is_instance_valid(DocumentReader.current):
			return  # Escape closes the open document first
		get_viewport().set_input_as_handled()
		if _settings != null:
			_close_settings()
		else:
			toggle()
	elif is_open and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if _settings != null:
			_close_settings()
		else:
			close()
