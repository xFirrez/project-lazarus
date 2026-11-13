# JournalScreen — the main menu's Journal (DEVELOPMENT_PLAN Step 14 scope 2, AC-14.5): every map's
# collectible documents, audio reels and story entries (LoreLibrary.journal_ids) with locked ones
# shown as "???"; selecting an unlocked entry shows its text or reel transcript (a reel can be
# replayed with subtitles), plus the map's Easter-egg badges. Unlocks persist locally (Journal).
# Authority: local presentation.
class_name JournalScreen
extends Control

signal back_pressed

var _list: ItemList = null
var _title: Label = null
var _body: Label = null
var _badges: Label = null
var _ids: Array[StringName] = []
var _libs: Array[LoreLibrary] = []
var _vo: VoDirector = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.apply(self)
	add_child(UiTheme.backdrop(0.8))
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 40)
	add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	margin.add_child(col)
	col.add_child(UiTheme.title_label("JOURNAL", 44))
	_badges = UiTheme.type_label("", 18, Color(1.0, 0.8, 0.4))
	col.add_child(_badges)
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 20)
	col.add_child(row)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(360, 0)
	_list.item_selected.connect(_show)
	row.add_child(_list)
	var paper: PanelContainer = PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(paper)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.add_child(right)
	_title = UiTheme.type_label("", 24, UiTheme.RED_INK)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	_body = UiTheme.type_label("", 17, UiTheme.INK)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(560, 0)
	scroll.add_child(_body)
	var back: Button = UiTheme.button("Back", func() -> void: back_pressed.emit())
	back.name = "BackButton"
	back.custom_minimum_size = Vector2(180, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(back)
	_list.focus_mode = Control.FOCUS_ALL
	_vo = VoDirector.new()
	add_child(_vo)
	_fill()
	UiTheme.intro(col)
	UiTheme.focus_first(col)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		Audio.play_event(&"ui_back")
		back_pressed.emit()


func _fill() -> void:
	_list.clear()
	_ids.clear()
	_libs.clear()
	var badge_lines: PackedStringArray = []
	for res: Resource in Content.get_all(&"MapDefinition"):
		var def: MapDefinition = res as MapDefinition
		if def.is_test_map:
			continue
		var lib: LoreLibrary = LoreLibrary.for_map(def)
		var have: int = 0
		var ids: Array[StringName] = lib.journal_ids()
		for id: StringName in ids:
			var unlocked: bool = Journal.is_unlocked(id)
			have += int(unlocked)
			var e: Dictionary = lib.entry(id)
			var tag: String = {"doc": "Document", "reel": "Reel", "story": "Story"}.get(String(e.get("kind", "")), "")
			_list.add_item("%s  %s" % [id, String(e.get("title", "")) if unlocked else "???  (%s)" % tag])
			_ids.append(id)
			_libs.append(lib)
		var b: String = MapSelectScreen.badge_text(def.id).strip_edges()
		badge_lines.append("%s: %d / %d found%s" % [def.display_name, have, ids.size(), "   " + b if b != "" else ""])
	_badges.text = "\n".join(badge_lines)


func entry_count() -> int:
	return _ids.size()


func _show(i: int) -> void:
	var id: StringName = _ids[i]
	var lib: LoreLibrary = _libs[i]
	_vo.stop()
	if not Journal.is_unlocked(id):
		_title.text = "???"
		_body.text = "Not found yet. Explore %s." % String(lib.entry(id).get("zone", "the map"))
		return
	var e: Dictionary = lib.entry(id)
	_title.text = "%s — %s" % [id, e.get("title", "")]
	if lib.kind_of(id) == "reel":
		_body.text = lib.transcript(id)
		_vo.lore = lib
		_vo.play_local(id)
	else:
		_body.text = String(e.get("body", ""))
