# FacilityMap — the pause menu's stylized hand-drawn facility map (GAME_DESIGN §15): every zone the
# local player has visited, inked on paper (unvisited zones stay blank), the current zone circled in
# red, teammates as coloured pins. Built from the map's ZoneVolumes (top-down, north up), so it
# works for any map without map-specific art.
# Authority: local presentation.
class_name FacilityMap
extends Control

var match_node: Match = null
var visited: Dictionary = {}  # zone id -> true

var _bounds: Rect2 = Rect2()


func _ready() -> void:
	custom_minimum_size = Vector2(520, 380)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


func _to_panel(p: Vector2) -> Vector2:
	var pad: Vector2 = Vector2(24, 40)
	var avail: Vector2 = size - pad * 2.0
	var s: float = minf(avail.x / maxf(_bounds.size.x, 1.0), avail.y / maxf(_bounds.size.y, 1.0))
	var off: Vector2 = pad + (avail - _bounds.size * s) * 0.5
	return off + (p - _bounds.position) * s


func _draw() -> void:
	draw_style_box(UiTheme.paper_box(), Rect2(Vector2.ZERO, size))
	var font: Font = UiTheme.font(&"type")
	draw_string(font, Vector2(20, 28), "FACILITY MAP — VISITED SECTORS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiTheme.INK)
	if match_node == null or match_node.zones == null or match_node.zones.volumes.is_empty():
		return
	var first: bool = true
	for v: ZoneVolume in match_node.zones.volumes:
		var r: Rect2 = _rect_of(v)
		_bounds = r if first else _bounds.merge(r)
		first = false
	var here: StringName = &""
	var me: PlayerCharacter = match_node.players.local_avatar() if match_node.players != null else null
	if me != null:
		here = match_node.zones.zone_at(me.global_position)
	var labelled: Dictionary = {}
	for v: ZoneVolume in match_node.zones.volumes:
		var a: Vector2 = _to_panel(_rect_of(v).position)
		var b: Vector2 = _to_panel(_rect_of(v).end)
		var rect: Rect2 = Rect2(a, b - a).abs()
		if not visited.has(v.zone):
			draw_rect(rect, Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, 0.08), false, 1.0)
			continue
		draw_rect(rect, Color(0.55, 0.47, 0.32, 0.35))
		# Hand-drawn feel: a slightly offset double outline.
		draw_rect(rect, UiTheme.INK, false, 2.0)
		draw_rect(Rect2(rect.position + Vector2(1.5, -1.0), rect.size), Color(UiTheme.INK, 0.4), false, 1.0)
		if not labelled.has(v.zone):
			labelled[v.zone] = true
			var zd: ZoneDef = match_node.definition.zone_def(v.zone) if match_node.definition != null else null
			var label: String = zd.display_name if zd != null else String(v.zone)
			draw_string(
				font, rect.position + Vector2(4, 16), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 6, 12, UiTheme.INK
			)
		if v.zone == here:
			draw_arc(rect.get_center(), maxf(rect.size.x, rect.size.y) * 0.6, 0.0, TAU, 40, UiTheme.RED_INK, 3.0)
	if match_node.players != null:
		for id: int in match_node.players.avatars:
			var p: PlayerCharacter = match_node.players.avatars[id]
			if is_instance_valid(p):
				var pp: Vector2 = _to_panel(Vector2(p.global_position.x, p.global_position.z))
				draw_circle(pp, 6.0, UiTheme.INK)
				draw_circle(pp, 4.5, p.player_color())


static func _rect_of(v: ZoneVolume) -> Rect2:
	var c: Vector3 = v.global_position
	return Rect2(Vector2(c.x - v.size.x * 0.5, c.z - v.size.z * 0.5), Vector2(v.size.x, v.size.z))
