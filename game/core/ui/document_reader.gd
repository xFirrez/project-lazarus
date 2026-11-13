# DocumentReader — the in-match document reader (DEVELOPMENT_PLAN Step 14 scope 2): a paper panel with
# the title, typed body text and, when the quest has annotated the document (the frequency digits of
# stage 1), a red-ink note. It does not capture input: it closes on interact / pause, when the
# player walks more than CLOSE_DISTANCE away, or after AUTO_CLOSE seconds. One at a time.
# Authority: local presentation.
class_name DocumentReader
extends Control

const CLOSE_DISTANCE: float = 3.0
const AUTO_CLOSE: float = 60.0

static var current: DocumentReader = null

var entry: Dictionary = {}
var annotation: String = ""
var opened_at_position: Vector3 = Vector3.INF
var _age: float = 0.0


static func open(host: Node, e: Dictionary, note: String = "") -> DocumentReader:
	close_current()
	if e.is_empty() or host == null or not host.is_inside_tree():
		return null
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "DocumentReaderLayer"
	layer.layer = 9
	host.add_child(layer)
	var r: DocumentReader = DocumentReader.new()
	r.entry = e
	r.annotation = note
	var me: PlayerCharacter = (
		Match.current.players.local_avatar() if Match.current != null and Match.current.players != null else null
	)
	if me != null:
		r.opened_at_position = me.global_position
	layer.add_child(r)
	current = r
	Audio.play_event(&"page_turn")
	return r


static func close_current() -> void:
	if current != null and is_instance_valid(current):
		current.get_parent().queue_free()
	current = null


static func is_open() -> bool:
	return current != null and is_instance_valid(current)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.86, 0.81, 0.68)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(28)
	sb.shadow_size = 12
	sb.shadow_color = Color(0, 0, 0, 0.5)
	panel.add_theme_stylebox_override(&"panel", sb)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	panel.add_child(box)
	var title: Label = Label.new()
	title.name = "Title"
	title.text = String(entry.get("title", ""))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override(&"font_size", 22)
	title.add_theme_color_override(&"font_color", Color(0.15, 0.12, 0.1))
	box.add_child(title)
	var body: Label = Label.new()
	body.name = "Body"
	body.text = String(entry.get("body", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(540, 0)
	body.add_theme_font_size_override(&"font_size", 16)
	body.add_theme_color_override(&"font_color", Color(0.2, 0.17, 0.14))
	box.add_child(body)
	if annotation != "":
		var note: Label = Label.new()
		note.name = "Annotation"
		note.text = annotation
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		note.add_theme_font_size_override(&"font_size", 26)
		note.add_theme_color_override(&"font_color", Color(0.72, 0.08, 0.06))
		box.add_child(note)
	var hint: Label = Label.new()
	hint.text = "[F] close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override(&"font_size", 12)
	hint.add_theme_color_override(&"font_color", Color(0.4, 0.35, 0.3))
	box.add_child(hint)


func text() -> String:
	return "%s\n%s\n%s" % [entry.get("title", ""), entry.get("body", ""), annotation]


func _process(delta: float) -> void:
	_age += delta
	var me: PlayerCharacter = (
		Match.current.players.local_avatar() if Match.current != null and Match.current.players != null else null
	)
	var walked: bool = (
		me != null
		and opened_at_position.is_finite()
		and me.global_position.distance_to(opened_at_position) > CLOSE_DISTANCE
	)
	var pressed: bool = (
		_age > 0.3 and (Input.is_action_just_pressed(&"interact") or Input.is_action_just_pressed(&"pause"))
	)
	if walked or pressed or _age > AUTO_CLOSE:
		close_current()
