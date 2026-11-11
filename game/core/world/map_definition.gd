# MapDefinition — data describing a playable map. Maps plug into core only through this
# resource and (later) a MapRules script (ARCHITECTURE §9). Discovered by the Content registry.
class_name MapDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_file("*.tscn") var scene_path: String = ""
@export var is_test_map: bool = false
@export var max_players: int = 4
