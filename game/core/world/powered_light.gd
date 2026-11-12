# PoweredLight — a light (or light group) that wakes when its circuit turns on: dark (or a dim
# emergency level) before, then ramps up after `delay` seconds — maps stagger the delay by zone to
# cascade the power-on sequence across the map. Already-on circuits (late join) apply instantly.
# Authority: cosmetic, local on every peer (reads the replicated power flag).
class_name PoweredLight
extends Node3D

@export var circuit: StringName = Power.MAIN
@export var delay: float = 0.0
@export var off_fraction: float = 0.0  # energy share before power (emergency lighting)
@export var ramp_time: float = 0.6

var lights: Array[Light3D] = []
var energies: Array[float] = []
var powered: bool = false


func _ready() -> void:
	add_to_group(&"powered_light")
	for n: Node in find_children("*", "Light3D", true, false):
		lights.append(n as Light3D)
		energies.append((n as Light3D).light_energy)
	_apply(off_fraction)


# Called by Match.setup once the MatchSession exists (map _ready runs before it).
func _on_match_setup(m: Match) -> void:
	if m.session != null and not m.session.flag_changed.is_connected(_on_flag):
		m.session.flag_changed.connect(_on_flag)
	if Power.is_on(circuit):
		powered = true
		_apply(1.0)


func _on_flag(key: String, value: Variant) -> void:
	if Power.circuit_of(key) != circuit or powered or not bool(value):
		return
	powered = true
	if not is_inside_tree():
		_apply(1.0)
		return
	var tw: Tween = create_tween()
	tw.tween_interval(delay)
	# A short flicker, then full.
	tw.tween_callback(_apply.bind(0.6))
	tw.tween_interval(0.08)
	tw.tween_callback(_apply.bind(0.1))
	tw.tween_interval(0.1)
	tw.tween_method(_apply, 0.3, 1.0, ramp_time)


func _apply(f: float) -> void:
	for i: int in lights.size():
		lights[i].light_energy = energies[i] * f
		lights[i].visible = f > 0.001
