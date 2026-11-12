# MachineConsole — the call / ride panel of a TraversalMachine (gondola console, freight lift
# controls; VESPER_PEAK §5 GND / LFT). At a station (`station` 0 / 1): rides when the machine is
# docked there (paying `ride_cost`), otherwise calls it over for free. `station = -1` is the
# in-cabin panel (rides from wherever it is docked).
# Authority: HOST executes (TraversalMachine.host_request); prompts are local.
class_name MachineConsole
extends Interactable

@export var machine_path: NodePath = ^""
@export var station: int = -1

var machine: TraversalMachine = null


func _ready() -> void:
	super()
	hold_time = 0.3
	ping_kind = &"machine"
	machine = get_node_or_null(machine_path) as TraversalMachine


func _here(t: float) -> bool:
	return station < 0 or machine.docked_at(t) == station


func get_cost(_player: PlayerCharacter) -> int:
	if machine == null:
		return 0
	return machine.ride_cost if _here(Net.host_time()) else 0


func get_prompt(player: PlayerCharacter) -> String:
	if machine == null:
		return ""
	var t: float = Net.host_time()
	var label: String = machine.display_name
	if machine.requires_power and not Power.is_on():
		return "The %s needs power" % label
	if machine.docked_at(t) < 0 or t < machine.depart_time:
		return "The %s is moving" % label
	if not machine.ready_at(t):
		return "The %s is cooling down (%.0f s)" % [label, machine.cooldown_left(t)]
	var c: int = get_cost(player)
	if _here(t):
		return "Hold [F] to ride the %s%s" % [label, " [%d]" % c if c > 0 else ""]
	return "Hold [F] to call the %s" % label


func host_check(_peer_id: int, _player: PlayerCharacter) -> String:
	if machine == null:
		return "broken"
	var t: float = Net.host_time()
	if machine.requires_power and not Power.is_on():
		return "Requires power"
	if not machine.ready_at(t):
		return "Not ready"
	return ""


func host_execute(_peer_id: int, _player: PlayerCharacter) -> bool:
	return machine != null and machine.host_request() == ""
