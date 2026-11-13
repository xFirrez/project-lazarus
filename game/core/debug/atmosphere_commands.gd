# AtmosphereCommands — console commands for the Step 13 art & atmosphere layer (local presentation
# only): pin a zone's atmosphere profile, force a storm gust or an energy pulse, toggle the
# greybox marker posts, and report art statistics (vignettes, props, decals, FX, lights, shadow
# budget). Maps expose their art node in group `map_art` (method `energy_pulse`).
# Authority: local presentation.
class_name AtmosphereCommands
extends RefCounted


static func register(reg: CommandRegistry) -> void:
	reg.register(
		"atmos", _cmd_atmos, [["zone", TYPE_STRING, ""]], "Pin a zone's atmosphere profile (empty/off = follow camera)"
	)
	reg.register("gust", _cmd_gust, [], "Force a storm gust now (local)")
	reg.register("art_pulse", _cmd_pulse, [], "Play the reactor energy pulse (aurora flash, exposure dip)")
	reg.register("markers_visible", _cmd_markers, [["on", TYPE_BOOL, true]], "Show / hide greybox marker posts")
	reg.register("art_stats", _cmd_stats, [], "Art layer statistics: vignettes, props, decals, FX, lights, shadows")


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _find(cls: String) -> Node:
	var found: Array[Node] = _tree().root.find_children("*", cls, true, false)
	return found[0] if not found.is_empty() else null


static func _cmd_atmos(args: Array) -> String:
	var za: ZoneAtmosphere = _find("ZoneAtmosphere") as ZoneAtmosphere
	if za == null:
		return "No ZoneAtmosphere on this map"
	var z: String = String(args[0])
	if z == "" or z == "off":
		za.forced_zone = &""
		return "atmosphere follows the camera (now %s)" % za.current_zone
	if za.profile_for(StringName(z)) == null:
		return "No profile for %s" % z
	za.forced_zone = StringName(z)
	za.snap_to(StringName(z))
	return "atmosphere pinned to %s" % z


static func _cmd_gust(_args: Array) -> String:
	var s: StormSystem = _find("StormSystem") as StormSystem
	if s == null:
		return "No StormSystem on this map"
	s.force_gust()
	return "gust (gusts so far: %d)" % s.gusts


static func _cmd_pulse(_args: Array) -> String:
	var arts: Array[Node] = _tree().get_nodes_in_group(&"map_art")
	if arts.is_empty() or not arts[0].has_method(&"energy_pulse"):
		return "This map has no energy pulse"
	arts[0].call(&"energy_pulse")
	return "energy pulse"


static func _cmd_markers(args: Array) -> String:
	var n: int = MapMarker.set_all_visuals(_tree().root, bool(args[0]))
	return "%d marker visuals %s" % [n, "shown" if bool(args[0]) else "hidden"]


static func _cmd_stats(_args: Array) -> String:
	var root: Node = _tree().root
	var lights: int = 0
	var shadowed: int = 0
	for l: Node in root.find_children("*", "Light3D", true, false):
		lights += 1
		if (l as Light3D).shadow_enabled and not l is DirectionalLight3D:
			shadowed += 1
	var props: int = root.find_children("Prop_*", "", true, false).size()
	return (
		"vignettes %d | props %d | decals %d | fx %d | fog volumes %d | reverb zones %d | lights %d (shadowed %d)"
		% [
			_tree().get_nodes_in_group(&"vignette").size(),
			props,
			root.find_children("*", "Decal", true, false).size(),
			_tree().get_nodes_in_group(&"atmos_fx").size(),
			root.find_children("*", "FogVolume", true, false).size(),
			_tree().get_nodes_in_group(&"reverb_zone").size(),
			lights,
			shadowed,
		]
	)
