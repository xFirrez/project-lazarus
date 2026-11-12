# BuildableDef — one buildable of a map (DEVELOPMENT_PLAN Step 12A scope 3, VESPER_PEAK §5): its
# parts, the MapMarker ids each part may spawn at (one option is chosen per match), the workbench
# marker, the build rule and the reward. Referenced by MapDefinition.buildables (map data).
# Authority: read-only data.
class_name BuildableDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var parts: Array[StringName] = []  # e.g. coil, lens, stock
@export var part_names: Dictionary = {}  # part -> display name
# part -> Array of MapMarker ids (kind &"part"); one is picked per match.
@export var part_markers: Dictionary = {}
@export var workbench_marker: StringName = &""
@export var requires_power: bool = true
@export var build_time: float = 3.0
@export var reward_weapon: StringName = &""  # first claim after the build (one per player)
@export var unlock_flag: String = ""  # MatchSession flag set at the first build (box pool condition)


func part_name(part: StringName) -> String:
	return String(part_names.get(part, String(part).capitalize()))


func options_of(part: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for m: Variant in part_markers.get(part, []):
		out.append(StringName(m))
	return out
