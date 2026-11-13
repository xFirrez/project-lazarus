# UiBackdrop — full-screen menu backdrop: night wash (transparent enough to show a 3D menu scene
# behind it), a red-ink edge vignette, scanning film grain and a slow flicker. Drawn, no textures.
# Authority: local presentation.
class_name UiBackdrop
extends Control

var alpha: float = 1.0

var _t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var c: Color = UiTheme.NIGHT
	c.a = alpha
	draw_rect(r, c)
	# Edge vignette: stacked translucent frames, darker and redder towards the border.
	var steps: int = 10
	for i: int in steps:
		var k: float = float(i) / steps
		var inset: float = k * minf(size.x, size.y) * 0.18
		var col: Color = Color(0.18, 0.02, 0.02, 0.05 * (1.0 - k))
		draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0), col, false, 18.0)
	# Grain: a few hundred faint specks re-seeded ~12 times a second (film, not TV noise).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(_t * 12.0)
	for i: int in 220:
		var p: Vector2 = Vector2(rng.randf() * size.x, rng.randf() * size.y)
		draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 1, 1, rng.randf() * 0.05))
	# A scratch now and then.
	if rng.randf() < 0.3:
		var x: float = rng.randf() * size.x
		draw_line(Vector2(x, 0), Vector2(x + rng.randf_range(-8, 8), size.y), Color(1, 1, 1, 0.035), 1.0)
	var flick: float = 0.02 * (sin(_t * 7.3) * sin(_t * 1.7))
	if flick > 0.0:
		draw_rect(r, Color(0, 0, 0, flick))
