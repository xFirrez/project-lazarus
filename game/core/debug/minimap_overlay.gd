# MinimapOverlay — top-down debug map (DEVELOPMENT_PLAN Step 8 scope 11): zone volumes (filled =
# unlocked, bright outline = active for spawning, labelled by id), player dots in their character
# colour, zombie dots (red), traversal machines (cyan) and the elevation band under the local
# player. Console: `minimap [on]`. Fits the whole map in a corner panel.
# Authority: local, read-only.
class_name MinimapOverlay
extends Control

const PANEL: Vector2 = Vector2(360, 300)

var _bounds: Rect2 = Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(-PANEL.x - 12, 12)
	size = PANEL


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _to_panel(p: Vector3) -> Vector2:
	var s: float = minf((PANEL.x - 16) / _bounds.size.x, (PANEL.y - 28) / _bounds.size.y)
	# North (-z on screen up) : x right, z down.
	return Vector2(8, 20) + (Vector2(p.x, p.z) - _bounds.position) * s


func _draw() -> void:
	var m: Match = Match.current
	if m == null or m.zones == null:
		return
	draw_rect(Rect2(Vector2.ZERO, PANEL), Color(0, 0, 0, 0.55))
	_bounds = Rect2()
	var first: bool = true
	for v: ZoneVolume in m.zones.volumes:
		var r: Rect2 = Rect2(
			Vector2(v.global_position.x - v.size.x * 0.5, v.global_position.z - v.size.z * 0.5),
			Vector2(v.size.x, v.size.z)
		)
		_bounds = r if first else _bounds.merge(r)
		first = false
	if first:
		return
	var active: Array[StringName] = m.zones.active_zones()
	var font: Font = ThemeDB.fallback_font
	for v: ZoneVolume in m.zones.volumes:
		var a: Vector2 = _to_panel(v.global_position - v.size * 0.5)
		var b: Vector2 = _to_panel(v.global_position + v.size * 0.5)
		var rect: Rect2 = Rect2(a, b - a).abs()
		var unlocked: bool = m.zones.is_unlocked(v.zone)
		draw_rect(rect, Color(0.3, 0.45, 0.6, 0.35) if unlocked else Color(0.25, 0.25, 0.25, 0.25))
		draw_rect(rect, Color(1, 0.9, 0.3) if active.has(v.zone) else Color(0.5, 0.5, 0.55), false, 1.0)
		if rect.size.x > 18:
			draw_string(font, rect.position + Vector2(2, 10), String(v.zone), HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
	if m.zombies != null:
		for id: int in m.zombies.actors:
			var z: ZombieActor = m.zombies.actors[id]
			if is_instance_valid(z):
				draw_circle(_to_panel(z.global_position), 1.6, Color(1, 0.2, 0.15))
	for n: Node in get_tree().get_nodes_in_group(TraversalMachine.GROUP):
		draw_circle(_to_panel((n as Node3D).global_position), 3.0, Color(0.2, 1, 1))
	var me_y: float = 0.0
	if m.players != null:
		for id: int in m.players.avatars:
			var p: PlayerCharacter = m.players.avatars[id]
			draw_circle(_to_panel(p.global_position), 3.5, p.player_color())
			if id == Net.local_id():
				me_y = p.global_position.y
	var here: StringName = &""
	if m.players != null and m.players.avatars.has(Net.local_id()):
		here = m.zones.zone_at((m.players.avatars[Net.local_id()] as Node3D).global_position)
	draw_string(
		font,
		Vector2(8, 14),
		"zone %s  y %.1f  unlocked %d  active %s" % [here, me_y, m.zones.unlocked.size(), ",".join(active)],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10
	)
