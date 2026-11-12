# PerkDefinition — one Vigor Tonic (GAME_DESIGN §8): price (solo / co-op), power requirement,
# stat modifiers, machine identity (neon colour, silhouette, sign) and its original jingle
# (semitone offsets from `jingle_root_hz` with beat lengths; placeholder synthesis until Step 15).
# `marker_id` names the map MapMarker (kind &"perk") the machine stands on.
# Authority: read-only data, identical on every peer.
class_name PerkDefinition
extends Resource

enum Silhouette { KEG, BOLTS, DOUBLE_TAP, RUNNER, CROSS, DIAL, MULE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var tagline: String = ""
@export var cost: int = 2000
@export var cost_coop: int = -1  # -1 = same as cost
@export var requires_power: bool = true
@export var marker_id: StringName = &""
@export var modifiers: Array[StatModifier] = []
@export var sort_order: int = 0

@export_group("Identity")
@export var color: Color = Color(1, 0.2, 0.2)  # neon / cap colour
@export var accent: Color = Color(0.2, 0.2, 0.2)  # cabinet body
@export var silhouette: Silhouette = Silhouette.KEG
@export var cap_letter: String = "?"

@export_group("Jingle")
@export var jingle_root_hz: float = 220.0
@export var jingle_notes: PackedInt32Array = []
@export var jingle_beats: PackedFloat32Array = []
@export var jingle_beat_seconds: float = 0.22
@export var jingle_wave: int = 0  # 0 square-ish organ, 1 saw brass, 2 sine bell, 3 pluck


func price(coop: bool) -> int:
	return cost_coop if coop and cost_coop >= 0 else cost


func jingle_event() -> StringName:
	return StringName("perk_jingle_%s" % id)


func sting_event() -> StringName:
	return StringName("perk_sting_%s" % id)
