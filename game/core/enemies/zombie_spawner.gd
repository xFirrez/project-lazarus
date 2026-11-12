# ZombieSpawner — a spawn point placed by maps (ARCHITECTURE §7.3). `kind` selects the entry
# behavior: WINDOW spawns outside a barricade (the brain tears in through its TraversalLink),
# RISER rises from the ground, VENT drops in, DOOR_BURST bursts out of a closet, CLIMB vaults a
# wall / cliff / pit edge through a JUMP link; SPECIAL is used by later steps.
# `zone` is the canonical zone id the SpawnDirector filters on (active zones only).
# Authority: map data, read by the host.
class_name ZombieSpawner
extends Marker3D

enum Kind { WINDOW, RISER, VENT, DOOR_BURST, SPECIAL, CLIMB }

@export var kind: Kind = Kind.RISER
@export var zone: StringName = &""
@export var barricade_path: NodePath = ^""
@export var min_round: int = 1  # first round this spawner is used (e.g. vents from round 3)

var barricade: Barricade = null


func _ready() -> void:
	add_to_group(&"zombie_spawner")
	if barricade_path != ^"":
		barricade = get_node_or_null(barricade_path) as Barricade
