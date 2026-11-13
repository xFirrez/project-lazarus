# MessageScreen — placeholder full-screen message used for Lobby / Loading / Game Over.
class_name MessageScreen
extends Control

signal action_pressed

var title: String = ""
var action_text: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	center.add_child(box)
	var label: Label = Label.new()
	label.text = title
	label.add_theme_font_size_override(&"font_size", 28)
	box.add_child(label)
	if action_text != "":
		var b: Button = Button.new()
		b.text = action_text
		b.pressed.connect(func() -> void: action_pressed.emit())
		box.add_child(b)
