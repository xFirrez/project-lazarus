# RelicBoxPool — the Relic Box's weighted item pool and rules (GAME_DESIGN §10). Data only; the
# roll logic is RelicBoxRoller. Entries whose WeaponDefinition doesn't exist yet (wonder weapons
# before Step 12) or whose condition flag is unset (Conduit before its first build) are ineligible.
# Authority: read-only data.
class_name RelicBoxPool
extends Resource

@export var item_ids: Array[StringName] = []
@export var weights: PackedFloat32Array = []
@export var wonder_ids: Array[StringName] = []  # get the bad-luck bonus (§10.3)
# item id -> MatchSession flag that must be truthy (e.g. &"lazarus_conduit": "conduit_built").
@export var conditions: Dictionary = {}

@export_group("Rules")
@export var cost: int = 950
@export var fire_sale_cost: int = 10
@export var spin_time: float = 4.5
@export var offer_time: float = 12.0
@export var doll_free_uses: int = 4  # never a doll on the first N spins at a location
@export var doll_base: float = 0.15
@export var doll_step: float = 0.15
@export var doll_max: float = 0.75
@export var move_time: float = 4.0  # doll -> box reappears elsewhere after this
@export var bad_luck_step: float = 0.1  # wonder weight added per spin without one (per player)
@export var fire_sale_time: float = 30.0


func weight_of(item_id: StringName) -> float:
	var i: int = item_ids.find(item_id)
	return weights[i] if i >= 0 and i < weights.size() else 0.0
