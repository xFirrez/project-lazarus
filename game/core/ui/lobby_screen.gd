# LobbyScreen — the co-op lobby (DEVELOPMENT_PLAN Step 7 scope 2): 4 slots (name, character in
# its colour, ready), character cards (unique per lobby; taken ones are disabled), ready toggle,
# minimal text chat, host settings (map, late join, starting round in dev builds), Start (host,
# everyone ready) with the countdown, connection info (address / UPnP / Steam invite) and Leave.
# Rebuilt from Session.lobby on every `lobby_changed`.
# Authority: local presentation; every action is a Session request decided by the host.
class_name LobbyScreen
extends Control

signal leave_pressed

var _slots_box: VBoxContainer = null
var _chars_box: HBoxContainer = null
var _ready_button: Button = null
var _start_button: Button = null
var _countdown: Label = null
var _chat_log: RichTextLabel = null
var _chat_edit: LineEdit = null
var _status: Label = null
var _map_option: OptionButton = null
var _late_join: CheckBox = null
var _start_round: SpinBox = null
var _map_ids: Array[StringName] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 14)
	margin.add_child(root)
	var title: Label = Label.new()
	title.text = "LOBBY"
	title.add_theme_font_size_override(&"font_size", 34)
	root.add_child(title)
	_status = Label.new()
	_status.add_theme_color_override(&"font_color", Color(0.7, 0.75, 0.8))
	root.add_child(_status)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override(&"separation", 30)
	root.add_child(columns)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override(&"separation", 10)
	columns.add_child(left)
	_slots_box = VBoxContainer.new()
	_slots_box.name = "Slots"
	left.add_child(_slots_box)
	var pick: Label = Label.new()
	pick.text = "Choose your survivor"
	left.add_child(pick)
	_chars_box = HBoxContainer.new()
	_chars_box.name = "Characters"
	_chars_box.add_theme_constant_override(&"separation", 8)
	left.add_child(_chars_box)
	_build_host_settings(left)
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	columns.add_child(right)
	var chat_title: Label = Label.new()
	chat_title.text = "Chat"
	right.add_child(chat_title)
	_chat_log = RichTextLabel.new()
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.scroll_following = true
	right.add_child(_chat_log)
	_chat_edit = LineEdit.new()
	_chat_edit.placeholder_text = "Say something (Enter)"
	_chat_edit.max_length = LobbyState.CHAT_MAX_CHARS
	_chat_edit.text_submitted.connect(_on_chat_submitted)
	right.add_child(_chat_edit)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", 12)
	root.add_child(bottom)
	var leave: Button = _button("Leave", func() -> void: leave_pressed.emit())
	bottom.add_child(leave)
	if Net.transport is SteamTransport:
		bottom.add_child(_button("Invite friends (Steam)", (Net.transport as SteamTransport).open_invite_overlay))
	_countdown = Label.new()
	_countdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.add_theme_font_size_override(&"font_size", 26)
	_countdown.add_theme_color_override(&"font_color", Color(0.9, 0.2, 0.15))
	bottom.add_child(_countdown)
	_ready_button = _button(
		"Ready", func() -> void: Session.request_set_ready(not Session.lobby.is_ready(Net.local_id()))
	)
	_ready_button.name = "ReadyButton"
	bottom.add_child(_ready_button)
	_start_button = _button("Start", func() -> void: Session.host_start_countdown())
	_start_button.name = "StartButton"
	_start_button.visible = Net.is_host()
	bottom.add_child(_start_button)
	Session.lobby_changed.connect(_refresh)
	_refresh()


func _build_host_settings(parent: VBoxContainer) -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 14)
	parent.add_child(grid)
	var ml: Label = Label.new()
	ml.text = "Map"
	grid.add_child(ml)
	_map_option = OptionButton.new()
	_map_ids = MapSelectScreen.map_ids(OS.is_debug_build())
	for id: StringName in _map_ids:
		_map_option.add_item(Content.get_map(id).display_name)
	_map_option.item_selected.connect(func(i: int) -> void: Session.host_set_map(_map_ids[i]))
	grid.add_child(_map_option)
	var ll: Label = Label.new()
	ll.text = "Late join"
	grid.add_child(ll)
	_late_join = CheckBox.new()
	_late_join.text = "Friends may join a match in progress"
	_late_join.toggled.connect(func(on: bool) -> void: Session.host_set_late_join(on))
	grid.add_child(_late_join)
	if Session.starting_round_allowed:
		var rl: Label = Label.new()
		rl.text = "Starting round (dev)"
		grid.add_child(rl)
		_start_round = SpinBox.new()
		_start_round.min_value = 1
		_start_round.max_value = 100
		_start_round.value_changed.connect(func(v: float) -> void: Session.host_set_starting_round(int(v)))
		grid.add_child(_start_round)


func _process(_delta: float) -> void:
	var left: float = Session.countdown_left()
	_countdown.text = "Starting in %d" % ceili(left) if left >= 0.0 else ""
	var lines: PackedStringArray = []
	if Net.is_host():
		lines.append(
			"Hosting on port %d" % Net.DEFAULT_PORT if not (Net.transport is SteamTransport) else "Steam lobby"
		)
	else:
		lines.append("Connected — ping %d ms" % roundi(Net.rtt_ms()))
	if Net.transport_status != "":
		lines.append(Net.transport_status)
	_status.text = "   ·   ".join(lines)


func _refresh() -> void:
	if not is_inside_tree():
		return
	var lobby: LobbyState = Session.lobby
	for c: Node in _slots_box.get_children():
		c.queue_free()
	for i: int in LobbyState.MAX_SLOTS:
		var row: Label = Label.new()
		row.add_theme_font_size_override(&"font_size", 22)
		if i < lobby.slots.size():
			var s: Dictionary = lobby.slots[i]
			var cdef: CharacterDefinition = CharacterDefinition.get_def(StringName(s["character"]))
			var who: String = String(s["name"]) + ("  (you)" if int(s["peer"]) == Net.local_id() else "")
			if int(s["peer"]) == 1:
				who += "  [host]"
			row.text = (
				"%d. %s — %s   %s"
				% [i + 1, who, cdef.full_name if cdef != null else "?", "READY" if bool(s["ready"]) else "not ready"]
			)
			row.add_theme_color_override(&"font_color", cdef.color if cdef != null else Color.WHITE)
		else:
			row.text = "%d. (open)" % (i + 1)
			row.add_theme_color_override(&"font_color", Color(0.45, 0.45, 0.5))
		_slots_box.add_child(row)
	for c: Node in _chars_box.get_children():
		c.queue_free()
	var mine: StringName = lobby.character_of(Net.local_id())
	for cdef: CharacterDefinition in CharacterDefinition.all_sorted():
		var b: Button = Button.new()
		b.name = "Char_%s" % cdef.id
		b.text = "%s\n%s" % [cdef.display_name, cdef.nationality]
		b.tooltip_text = "%s — %s" % [cdef.full_name, cdef.bio]
		b.custom_minimum_size = Vector2(130, 64)
		b.toggle_mode = true
		b.button_pressed = cdef.id == mine
		b.disabled = cdef.id != mine and not lobby.is_character_free(cdef.id)
		b.add_theme_color_override(&"font_color", cdef.color)
		b.add_theme_color_override(&"font_pressed_color", cdef.color)
		var cid: StringName = cdef.id
		b.pressed.connect(func() -> void: Session.request_character(cid))
		_chars_box.add_child(b)
	_ready_button.text = "Not ready" if lobby.is_ready(Net.local_id()) else "Ready"
	_start_button.disabled = not lobby.all_ready() or lobby.countdown_end >= 0.0
	var is_host: bool = Net.is_host()
	_map_option.disabled = not is_host
	_late_join.disabled = not is_host
	_map_option.select(maxi(_map_ids.find(lobby.map_id), 0))
	_late_join.set_pressed_no_signal(lobby.late_join)
	if _start_round != null:
		_start_round.editable = is_host
		_start_round.set_value_no_signal(lobby.starting_round)
	_chat_log.clear()
	for e: Variant in lobby.chat:
		var c: Array = e
		var cdef2: CharacterDefinition = CharacterDefinition.get_def(lobby.character_of(int(c[0])))
		var col: Color = cdef2.color if cdef2 != null else Color.WHITE
		_chat_log.push_color(col)
		_chat_log.add_text("%s: " % String(c[1]))
		_chat_log.pop()
		_chat_log.add_text(String(c[2]) + "\n")


func _on_chat_submitted(text: String) -> void:
	if text.strip_edges() != "":
		Session.send_chat(text)
	_chat_edit.clear()


func _button(text: String, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 40)
	b.pressed.connect(func() -> void: Audio.play_event(&"ui_click"))
	b.pressed.connect(on_press)
	return b
