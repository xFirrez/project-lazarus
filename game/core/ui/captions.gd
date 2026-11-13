# Captions — subtitles for the announcer ("Voice of the Mountain") and the survivors' quips
# (DEVELOPMENT_PLAN Step 15 scope 6): up to three lines above the quest-VO subtitle, speaker name in
# their colour, typewriter face on a dark band, fading out. Hidden when the Subtitles setting is off
# (lines are still recorded for tests). Story VO keeps its own line (VoDirector).
# Authority: local presentation.
class_name Captions
extends Control

const MAX_LINES: int = 3
const FADE: float = 0.4

var lines: Array = []  # [speaker, text, color, seconds_left]
var shown: int = 0  # every caption ever pushed (tests)
var last_text: String = ""


func _ready() -> void:
	name = "Captions"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func enabled() -> bool:
	return bool(Config.get_value(&"gameplay", &"subtitles", true))


func push(speaker: String, text: String, color: Color, seconds: float) -> void:
	lines.append([speaker, text, color, seconds])
	while lines.size() > MAX_LINES:
		lines.pop_front()
	shown += 1
	last_text = "%s: %s" % [speaker, text]


func _process(delta: float) -> void:
	UiTheme.fit_hud(self)
	for l: Variant in lines:
		(l as Array)[3] = float((l as Array)[3]) - delta
	lines = lines.filter(func(l: Array) -> bool: return float(l[3]) > 0.0)
	queue_redraw()


func _draw() -> void:
	if lines.is_empty() or not enabled():
		return
	var font: Font = UiTheme.font(&"type")
	var fs: int = 21
	var y: float = size.y - 230.0 - (lines.size() - 1) * 34.0
	for l: Variant in lines:
		var a: Array = l
		var alpha: float = clampf(float(a[3]) / FADE, 0.0, 1.0)
		var who: String = "%s: " % String(a[0])
		var body: String = String(a[1])
		var w1: float = font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w2: float = font.get_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x: float = size.x * 0.5 - (w1 + w2) * 0.5
		draw_rect(Rect2(x - 12, y - fs, w1 + w2 + 24, fs + 12), Color(0, 0, 0, 0.55 * alpha))
		var c: Color = a[2]
		c.a = alpha
		draw_string(font, Vector2(x, y), who, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
		draw_string(font, Vector2(x + w1, y), body, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, alpha))
		y += 34.0
