# GameOverScreen — game over v1 (GAME_DESIGN §15): "YOU SURVIVED N ROUNDS" and a per-player table
# (kills, headshots, downs, revives, points earned, doors). Rows come from the host's PointsLedger
# summary in the `_game_over` event, so every peer shows the same numbers.
# Authority: local presentation.
class_name GameOverScreen
extends Control

signal menu_pressed

const COLUMNS: Array[String] = ["kills", "headshots", "downs", "revives", "points_earned", "doors"]
const HEADERS: Array[String] = ["Player", "Kills", "Headshots", "Downs", "Revives", "Points", "Doors"]

var round_reached: int = 1
var rows: Array = []
var local_peer: int = 1


static func title_for(r: int) -> String:
	return "YOU SURVIVED %d ROUND%s" % [r, "" if r == 1 else "S"]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.02, 0.02, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 18)
	center.add_child(box)
	var title: Label = Label.new()
	title.text = title_for(round_reached)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 44)
	title.add_theme_color_override(&"font_color", Color(0.85, 0.12, 0.1))
	box.add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = HEADERS.size()
	grid.add_theme_constant_override(&"h_separation", 28)
	box.add_child(grid)
	for h: String in HEADERS:
		grid.add_child(_cell(h, Color(0.7, 0.7, 0.7), 18))
	for r: Variant in rows:
		var row: Dictionary = r
		var col: Color = Color(1, 0.9, 0.5) if int(row.get("peer", 0)) == local_peer else Color.WHITE
		grid.add_child(_cell(String(row.get("name", "?")), col, 20))
		for k: String in COLUMNS:
			grid.add_child(_cell(str(int(row.get(k, 0))), col, 20))
	var b: Button = Button.new()
	b.text = "Main menu"
	b.pressed.connect(func() -> void: menu_pressed.emit())
	box.add_child(b)


func _cell(text: String, color: Color, font_size: int) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	return l
