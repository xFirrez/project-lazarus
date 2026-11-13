# MapSelectScreen — lists the playable MapDefinitions (Content registry; test maps too in debug
# builds behind a toggle) and emits the chosen id. Only Vesper Peak ships in 1.0.
# Authority: local presentation.
class_name MapSelectScreen
extends Control

signal map_chosen(map_id: StringName)
signal back_pressed

var selected: StringName = &""
var confirm_text: String = "Start"

var _list: ItemList = null
var _ids: Array[StringName] = []
var _show_test: CheckBox = null


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
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override(&"separation", 10)
	center.add_child(box)
	var title: Label = Label.new()
	title.text = "SELECT MAP"
	title.add_theme_font_size_override(&"font_size", 30)
	box.add_child(title)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(420, 220)
	_list.item_activated.connect(func(_i: int) -> void: _confirm())
	box.add_child(_list)
	if OS.is_debug_build():
		_show_test = CheckBox.new()
		_show_test.text = "Show test maps (dev)"
		_show_test.toggled.connect(func(_on: bool) -> void: _fill())
		box.add_child(_show_test)
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	var back: Button = Button.new()
	back.text = "Back"
	back.pressed.connect(func() -> void: back_pressed.emit())
	row.add_child(back)
	var go: Button = Button.new()
	go.name = "Confirm"
	go.text = confirm_text
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(_confirm)
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
	_list.clear()
	for id: StringName in _ids:
		var d: MapDefinition = Content.get_map(id)
		_list.add_item("%s%s%s" % [d.display_name, "  (test)" if d.is_test_map else "", badge_text(id)])
	var idx: int = maxi(_ids.find(selected), 0)
	if not _ids.is_empty():
		_list.select(idx)


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


func _confirm() -> void:
	var sel: PackedInt32Array = _list.get_selected_items()
	if sel.is_empty() or _ids.is_empty():
		return
	Audio.play_event(&"ui_click")
	map_chosen.emit(_ids[sel[0]])
