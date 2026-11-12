# ZoneDef — one node of a map's zone graph (ARCHITECTURE §8, VESPER_PEAK §2): canonical id,
# adjacency (spawners of adjacent *unlocked* zones are active while a player is in this zone) and
# whether the zone starts unlocked (the starting zone).
# Authority: read-only map data.
class_name ZoneDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var adjacent: Array[StringName] = []
@export var start_unlocked: bool = false
