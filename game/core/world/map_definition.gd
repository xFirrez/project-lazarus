# MapDefinition — data describing a playable map. Maps plug into core only through this
# resource and a MapRules script (ARCHITECTURE §9). Discovered by the Content registry.
class_name MapDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_file("*.tscn") var scene_path: String = ""
@export var is_test_map: bool = false
@export var max_players: int = 4
# Weapons every player spawns with (GAME_DESIGN §4.1: M1911; test maps may add more).
@export var starting_weapons: Array[StringName] = [&"m1911"]
@export var starting_points: int = 500
# Survival maps run the RoundDirector / SpawnDirector (test arenas leave it off).
@export var survival: bool = false
@export var round_curve: RoundCurve = null
@export var zones: Array[ZoneDef] = []
@export var starting_zone: StringName = &""
# Script extending MapRules (maps/<id>/scripts/<id>_rules.gd); null = default rules.
@export var rules_script: Script = null
# Relic Box (Step 9): the MapMarker (kind &"box") id of the start location; "" = first by id.
@export var box_start: StringName = &""
@export var box_pool: RelicBoxPool = null  # null -> res://content/box/relic_box_pool.tres
# Buildables (Step 12): parts + workbench (Vesper Peak: the Lazarus Conduit).
@export var buildables: Array[BuildableDef] = []


func zone_def(zone_id: StringName) -> ZoneDef:
	for z: ZoneDef in zones:
		if z.id == zone_id:
			return z
	return null
