# PowerSwitch — the main power lever bank (VESPER_PEAK §3 Z09): free, single use, turns a circuit
# on map-wide. The cascade (lights by zone, klaxon, machines waking) is driven by listeners of the
# circuit flag on every peer, so late joiners just see the final state.
# Authority: HOST executes; the prompt is evaluated locally.
class_name PowerSwitch
extends Interactable

@export var circuit: StringName = Power.MAIN


func _ready() -> void:
	super()
	hold_time = 0.8
	ping_kind = &"machine"
	if prompt == "use":
		prompt = "turn on the power"


func is_available(_player: PlayerCharacter) -> bool:
	return not Power.is_on(circuit)


func host_execute(_peer_id: int, _player: PlayerCharacter) -> bool:
	Power.host_set(circuit, true)
	return true
