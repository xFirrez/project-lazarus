# MapCommands — console commands for map testing (Step 8): debug minimap, power, the extendable
# bridge (every NavDoor with `solid_when_open`), traversal machines, zone teleports, markers and
# navigation tiles.
# Authority: shared-state changes are host only; read-only commands read local mirrors.
class_name MapCommands
extends RefCounted

static var minimap: MinimapOverlay = null


static func register(reg: CommandRegistry) -> void:
	reg.register("minimap", _cmd_minimap, [["on", TYPE_BOOL, true]], "Top-down zone / player / zombie debug map")
	reg.register("power", _cmd_power, [["on", TYPE_BOOL, true]], "Host: main power on (off for tests)")
	reg.register(
		"bridge", _cmd_bridge, [["extend", TYPE_BOOL, true]], "Host: extend / retract inverted NavDoors (bridge)"
	)
	reg.register(
		"machine", _cmd_machine, [["id", TYPE_STRING, ""]], "Host: start a traversal machine ride (list if no id)"
	)
	reg.register("zone_tp", _cmd_zone_tp, [["zone", TYPE_STRING]], "Teleport to the centre of a zone volume")
	reg.register("markers", _cmd_markers, [["kind", TYPE_STRING, ""]], "List map markers (optionally of one kind)")
	reg.register("nav_tiles", _cmd_nav_tiles, [], "Navigation tiles: count, polygons, bake timings")


static func _m() -> Match:
	return Match.current


static func _cmd_minimap(args: Array) -> String:
	if minimap == null or not is_instance_valid(minimap):
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree == null or DisplayServer.get_name() == "headless":
			return "no display"
		var layer: CanvasLayer = CanvasLayer.new()
		layer.layer = 90
		layer.add_to_group(&"hide_for_shots")
		tree.root.add_child(layer)
		minimap = MinimapOverlay.new()
		layer.add_child(minimap)
	minimap.visible = bool(args[0])
	return "minimap %s" % ("on" if minimap.visible else "off")


static func _cmd_power(args: Array) -> String:
	if _m() == null or not MatchSession.is_authority():
		return "host only"
	if bool(args[0]):
		Power.host_set(Power.MAIN, true)
	else:
		_m().session.host_set_flag(Power.key(Power.MAIN), false)
	return "power %s" % ("on" if Power.is_on() else "off")


static func _cmd_bridge(args: Array) -> String:
	if _m() == null or not WorldSync.is_authority():
		return "host only"
	var n: int = 0
	for d: Node in _m().map_root.find_children("*", "NavDoor", true, false):
		if (d as NavDoor).solid_when_open:
			(d as NavDoor).host_set_open(bool(args[0]))
			n += 1
	return "%d bridge(s) %s" % [n, "extended" if bool(args[0]) else "retracted"]


static func _cmd_machine(args: Array) -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var out: PackedStringArray = []
	for n: Node in tree.get_nodes_in_group(TraversalMachine.GROUP):
		var tm: TraversalMachine = n as TraversalMachine
		if String(args[0]) == "":
			var t: float = Net.host_time()
			out.append("%s docked %d ready %s rides %d" % [tm.machine_id, tm.docked_at(t), tm.ready_at(t), tm.rides])
		elif String(tm.machine_id) == String(args[0]):
			var why: String = tm.host_request()
			return "%s: %s" % [tm.machine_id, why if why != "" else "departing"]
	return "\n".join(out) if not out.is_empty() else "no machine %s" % args[0]


static func _cmd_zone_tp(args: Array) -> String:
	var m: Match = _m()
	if m == null or m.zones == null:
		return "no match"
	for v: ZoneVolume in m.zones.volumes:
		if String(v.zone) == String(args[0]).to_upper():
			var c: Vector3 = v.global_position - Vector3(0, v.size.y * 0.5 - 0.1, 0)
			var tp: Vector3 = m.zombies.crowd.snap(c, c) if m.zombies.crowd.is_ready() else c
			m.players.request_teleport(tp + Vector3(0, 0.05, 0))
			return "teleport to %s %v" % [v.zone, tp]
	return "no zone %s" % args[0]


static func _cmd_markers(args: Array) -> String:
	var m: Match = _m()
	if m == null:
		return "no match"
	var out: PackedStringArray = []
	for n: Node in m.map_root.find_children("*", "MapMarker", true, false):
		var mk: MapMarker = n as MapMarker
		if String(args[0]) == "" or String(mk.kind) == String(args[0]):
			out.append("%s %s %s %v" % [mk.kind, mk.marker_id, mk.zone, mk.global_position.round()])
	return "%d markers\n%s" % [out.size(), "\n".join(out)]


static func _cmd_nav_tiles(_args: Array) -> String:
	var m: Match = _m()
	var tiles: NavTiles = NavTiles.find(m.map_root) if m != null else null
	if tiles == null:
		return "no nav tiles"
	return (
		"%d tiles, %d polygons, %d bakes, parse %.1f ms, bake total %.0f ms, baking %s"
		% [
			tiles.regions.size(),
			tiles.polygon_count(),
			tiles.bake_count,
			tiles.parse_usec / 1000.0,
			tiles.bake_usec / 1000.0,
			tiles.is_baking()
		]
	)
