# WeaponHud — local weapon HUD (Step 3 scope 6): crosshair whose gap visualizes the current spread
# cone (bloom), hit markers (hit / headshot / kill variants), ammo counter, weapon name, lethal
# count and reload / no-ammo hints. Final HUD art comes in Step 15 (GAME_DESIGN §15).
# Authority: local presentation, driven by the local WeaponController.
class_name WeaponHud
extends Control

enum Marker { NONE, HIT, HEAD, KILL }

const MARKER_TIME: float = 0.28
const MARKER_COLORS: Array[Color] = [Color.WHITE, Color(1, 1, 1, 0.95), Color(1.0, 0.85, 0.2), Color(1.0, 0.2, 0.15)]

var controller: WeaponController = null
var marker: Marker = Marker.NONE
var marker_age: float = 10.0
var markers_shown: int = 0
var crosshair_gap: float = 0.0


func _ready() -> void:
	name = "WeaponHud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_marker(kind: Marker) -> void:
	# A kill marker is not downgraded by a later pellet of the same shot.
	if marker_age < 0.05 and int(kind) < int(marker):
		return
	marker = kind
	marker_age = 0.0
	markers_shown += 1


# Pixel gap for a spread cone (half-angle, degrees) at the current horizontal FOV.
static func spread_to_pixels(spread_deg: float, hfov_deg: float, width: float) -> float:
	return tan(deg_to_rad(spread_deg)) / tan(deg_to_rad(hfov_deg) * 0.5) * width * 0.5


func _process(delta: float) -> void:
	marker_age += delta
	queue_redraw()


func _draw() -> void:
	if controller == null:
		return
	var rt: WeaponRuntime = controller.held()
	var c: Vector2 = size * 0.5
	if rt != null:
		var hfov: float = controller.player.camera.fov
		crosshair_gap = spread_to_pixels(controller.current_spread(), hfov, size.x) + 3.0
		var alpha: float = (1.0 - rt.ads) * (0.0 if rt.state == WeaponRuntime.State.SPRINT else 0.85)
		if alpha > 0.02:
			var col: Color = Color(1, 1, 1, alpha)
			var g: float = crosshair_gap
			var l: float = 9.0
			draw_line(c + Vector2(-g - l, 0), c + Vector2(-g, 0), col, 2.0)
			draw_line(c + Vector2(g, 0), c + Vector2(g + l, 0), col, 2.0)
			draw_line(c + Vector2(0, -g - l), c + Vector2(0, -g), col, 2.0)
			draw_line(c + Vector2(0, g), c + Vector2(0, g + l), col, 2.0)
	if marker != Marker.NONE and marker_age < MARKER_TIME:
		var mc: Color = MARKER_COLORS[marker]
		mc.a = 1.0 - marker_age / MARKER_TIME
		var r0: float = 6.0
		var r1: float = 14.0 if marker == Marker.KILL else 11.0
		for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var n: Vector2 = d.normalized()
			draw_line(c + n * r0, c + n * r1, mc, 3.0 if marker == Marker.KILL else 2.0)
	_draw_ammo(rt)


func _draw_ammo(rt: WeaponRuntime) -> void:
	var font: Font = ThemeDB.fallback_font
	var right: float = size.x - 40.0
	var bottom: float = size.y - 40.0
	if rt != null:
		var ammo: String = "%d / %d" % [rt.mag, rt.reserve]
		var w: float = font.get_string_size(ammo, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		draw_string(font, Vector2(right - w, bottom), ammo, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, 0.92))
		var nm: String = rt.def.display_name
		var w2: float = font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(
			font, Vector2(right - w2, bottom - 46.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.85, 0.8, 0.7)
		)
		var hint: String = ""
		if rt.mag == 0 and rt.reserve == 0:
			hint = "NO AMMO"
		elif rt.mag <= maxi(rt.def.mag_size / 4, 1) and rt.reserve > 0 and rt.state != WeaponRuntime.State.RELOADING:
			hint = "RELOAD"
		if hint != "":
			var w3: float = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
			draw_string(
				font, size * 0.5 + Vector2(-w3 * 0.5, 70), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.8, 0.3)
			)
	var inv: WeaponInventory = controller.inventory
	var lethal: String = "FRAG x%d" % inv.lethal_count
	if controller.cooking():
		lethal += "  (cooking %.1f)" % controller.cook_time_left()
	var w4: float = font.get_string_size(lethal, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(
		font, Vector2(right - w4, bottom - 80.0), lethal, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8, 0.85, 0.8)
	)
