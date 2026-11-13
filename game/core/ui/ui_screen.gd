# UiScreen — base of every full-screen menu (DEVELOPMENT_PLAN Step 15): themed root, the backdrop
# (translucent over the 3D menu scene when one runs), a centred content column with a stencil
# title, an intro transition, initial keyboard / gamepad focus and a uniform "back" path
# (ui_cancel / Escape / pad B, or the `back()` call) so no screen is a dead end (AC-15.1).
# Subclasses override `_build(content)` and, for screens with a parent, connect `back_pressed`.
# Authority: local presentation.
class_name UiScreen
extends Control

signal back_pressed

var screen_title: String = ""
var content_width: float = 560.0
var backdrop_alpha: float = 0.72  # < 1 lets the 3D menu backdrop show through
var has_back: bool = true
var align_left: bool = false  # main menu: the column sits left so the 3D backdrop stays visible

var content: VBoxContainer = null
var backdrop: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.apply(self)
	backdrop = UiTheme.backdrop(backdrop_alpha)
	add_child(backdrop)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	content = VBoxContainer.new()
	content.name = "Content"
	content.custom_minimum_size = Vector2(content_width, 0)
	content.add_theme_constant_override(&"separation", 10)
	if align_left:
		margin.add_theme_constant_override(&"margin_left", 90)
		content.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		margin.add_child(content)
	else:
		var center: CenterContainer = CenterContainer.new()
		margin.add_child(center)
		center.add_child(content)
	if screen_title != "":
		var t: Label = UiTheme.title_label(screen_title, 44)
		t.name = "Title"
		content.add_child(t)
	_build(content)
	UiTheme.intro(content)
	UiTheme.focus_first(content)


func _build(_c: VBoxContainer) -> void:
	pass


func back() -> void:
	if not has_back:
		return
	Audio.play_event(&"ui_back")
	back_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and has_back:
		get_viewport().set_input_as_handled()
		back()


# Re-grabs focus when the pad / keyboard is used and nothing has focus (e.g. after a mouse click on
# empty space).
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var nav: bool = (
		event.is_action_pressed(&"ui_down")
		or event.is_action_pressed(&"ui_up")
		or event.is_action_pressed(&"ui_left")
		or event.is_action_pressed(&"ui_right")
	)
	if nav and get_viewport().gui_get_focus_owner() == null:
		UiTheme.focus_first(content)
		get_viewport().set_input_as_handled()
