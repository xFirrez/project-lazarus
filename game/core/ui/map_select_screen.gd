# MapSelectScreen — map select with map cards (DEVELOPMENT_PLAN Step 15 scope 2): one card per
# playable MapDefinition (Content registry; test maps too in debug builds behind a toggle) with the
# preview art (`card_image_path`, or a drawn placeholder plate), the blurb, the local best round per
# player count and the Easter-egg badges (Journal). Designed for more maps: cards sit in a
# horizontal strip, left / right moves between them, accept starts. Only Vesper Peak ships in 1.0.
# Authority: local presentation.
class_name MapSelectScreen
extends UiScreen

signal map_chosen(map_id: StringName)

var selected: StringName = &""
var confirm_text: String = "Start"

var _ids: Array[StringName] = []
var _show_test: CheckBox = null
var _strip: HBoxContainer = null


static func map_ids(include_test: bool) -> Array[StringName]:
	var defs: Array[MapDefinition] = []
	for res: Resource in Content.get_all(&"MapDefinition"):
		var d: MapDefinition = res as MapDefinition
		if include_test or not d.is_test_map:
			defs.append(d)
	defs.sort_custom(
		func(a: MapDefinition, b: MapDefinition) -> bool:
			if a.is_test_map != b.is_test_map:
				return not a.is_test_map
			return String(a.id) < String(b.id)
	)
	var out: Array[StringName] = []
	for d: MapDefinition in defs:
		out.append(d.id)
	return out


# Easter-egg badges earned on this map (Journal), e.g. "  ★ Requiem (1p, 4p)".
static func badge_text(map_id: StringName) -> String:
	var parts: PackedStringArray = []
	var b: Dictionary = Journal.badges(map_id)
	for k: Variant in b.keys():
		var counts: PackedStringArray = []
		for c: Variant in b[k]:
			counts.append("%dp" % int(c))
		parts.append("★ %s (%s)" % [String(k).capitalize(), ", ".join(counts)])
	return "  " + "  ".join(parts) if not parts.is_empty() else ""


# "Best: 1p R12 · 4p R20" (or "No record yet").
static func best_text(map_id: StringName) -> String:
	var parts: PackedStringArray = []
	for n: int in range(1, 5):
		var r: int = Journal.best_round(map_id, n)
		if r > 0:
			parts.append("%dp R%d" % [n, r])
	return "Best: " + "  ·  ".join(parts) if not parts.is_empty() else "No record yet"


func _init() -> void:
	screen_title = "SELECT MAP"
	content_width = 900.0


func _build(c: VBoxContainer) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900, 470)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	c.add_child(scroll)
	_strip = HBoxContainer.new()
	_strip.name = "Cards"
	_strip.add_theme_constant_override(&"separation", 24)
	scroll.add_child(_strip)
	if OS.is_debug_build():
		_show_test = CheckBox.new()
		_show_test.name = "ShowTest"
		_show_test.text = "Show test maps (dev)"
		_show_test.toggled.connect(func(_on: bool) -> void: _fill())
		c.add_child(_show_test)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	c.add_child(row)
	var back_b: Button = UiTheme.button("Back", back)
	back_b.name = "BackButton"
	back_b.custom_minimum_size = Vector2(180, 44)
	row.add_child(back_b)
	var go: Button = UiTheme.button(confirm_text, _confirm)
	go.name = "Confirm"
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(go)
	_fill()


func _fill() -> void:
	var include_test: bool = _show_test != null and _show_test.button_pressed
	if selected != &"":
		var sel: MapDefinition = Content.get_map(selected)
		if sel != null and sel.is_test_map and _show_test != null and not _show_test.button_pressed:
			_show_test.set_pressed_no_signal(true)
			include_test = true
	_ids = map_ids(include_test)
	for ch: Node in _strip.get_children():
		_strip.remove_child(ch)
		ch.queue_free()
	if selected == &"" or not _ids.has(selected):
		selected = _ids[0] if not _ids.is_empty() else &""
	for id: StringName in _ids:
		_strip.add_child(_card(Content.get_map(id)))
	_refresh_selection()


func _card(d: MapDefinition) -> Button:
	var b: Button = Button.new()
	b.name = "Card_%s" % d.id
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(420, 450)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override(&"normal", UiTheme.paper_box())
	b.add_theme_stylebox_override(&"hover", UiTheme.paper_box(Color(0.95, 0.9, 0.78)))
	b.add_theme_stylebox_override(&"pressed", UiTheme.paper_box(Color(0.97, 0.88, 0.8)))
	b.add_theme_stylebox_override(&"hover_pressed", UiTheme.paper_box(Color(0.97, 0.88, 0.8)))
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 22)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 8)
	b.add_child(col)
	var plate: Control = _plate(d)
	col.add_child(plate)
	var name_l: Label = UiTheme.title_label(d.display_name.to_upper(), 30, UiTheme.INK)
	name_l.add_theme_constant_override(&"outline_size", 0)
	col.add_child(name_l)
	var blurb: Label = UiTheme.type_label(d.card_blurb if d.card_blurb != "" else "—", 15, UiTheme.INK)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(370, 0)
	col.add_child(blurb)
	col.add_child(UiTheme.type_label(best_text(d.id), 16, UiTheme.RED_INK))
	var badges: String = badge_text(d.id).strip_edges()
	col.add_child(UiTheme.type_label(badges if badges != "" else "Easter egg: not completed", 16, UiTheme.RED_INK))
	if d.is_test_map:
		col.add_child(UiTheme.type_label("(test map)", 14, UiTheme.INK))
	for n: Node in col.find_children("*", "Control", true, false):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(
		func() -> void:
			selected = d.id
			Audio.play_event(&"ui_click")
			_refresh_selection()
	)
	b.focus_entered.connect(
		func() -> void:
			selected = d.id
			_refresh_selection()
	)
	b.gui_input.connect(
		func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).double_click:
				_confirm()
	)
	return b


# Preview art: the map's card image if it has one, else a stamped "PHOTOGRAPH WITHHELD" plate.
func _plate(d: MapDefinition) -> Control:
	if d.card_image_path != "" and ResourceLoader.exists(d.card_image_path):
		var tr: TextureRect = TextureRect.new()
		tr.texture = load(d.card_image_path) as Texture2D
		tr.custom_minimum_size = Vector2(376, 200)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		return tr
	var p: ColorRect = ColorRect.new()
	p.color = Color(0.1, 0.11, 0.13)
	p.custom_minimum_size = Vector2(376, 200)
	var l: Label = UiTheme.title_label("PHOTOGRAPH\nWITHHELD", 26, Color(0.75, 0.12, 0.08, 0.8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.rotation_degrees = -6.0
	p.add_child(l)
	return p


func _refresh_selection() -> void:
	for ch: Node in _strip.get_children():
		var b: Button = ch as Button
		b.set_pressed_no_signal(b.name == "Card_%s" % selected)


func _confirm() -> void:
	if selected == &"" or not _ids.has(selected):
		return
	Audio.play_event(&"ui_accept")
	map_chosen.emit(selected)
