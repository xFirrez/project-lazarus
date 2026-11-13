# PoweredLight — a light (or light group) that wakes when its circuit turns on: dark (or a dim
# emergency level) before, then ramps up after `delay` seconds — maps stagger the delay by zone to
# cascade the power-on sequence across the map. Already-on circuits (late join) apply instantly.
# Step 13: an optional animation `pattern` (flicker / strobe / blink / buzz / swing / pulse) is
# multiplied on top of the power level every frame, and `always_on` lights (circuit-free: moon
# shafts, flares, beacons) use the same animation path. Animated lights join `light_animated` so
# other presenters (SpecialRoundDirector) leave their energy alone.
# Authority: cosmetic, local on every peer (reads the replicated power flag).
class_name PoweredLight
extends Node3D

enum Pattern { NONE, FLICKER, STROBE, BLINK, BUZZ, SWING, PULSE }

@export var circuit: StringName = Power.MAIN
@export var delay: float = 0.0
@export var off_fraction: float = 0.0  # energy share before power (emergency lighting)
@export var ramp_time: float = 0.6
@export var always_on: bool = false
@export var pattern: Pattern = Pattern.NONE
@export var rate: float = 1.0  # pattern speed multiplier
@export var depth: float = 0.6  # how far the pattern dips (0..1)

var lights: Array[Light3D] = []
var energies: Array[float] = []
var powered: bool = false
var level: float = 0.0  # current power level (0..1) before the pattern

var _t: float = 0.0
var _seed: float = 0.0
var _swing_base: Basis = Basis.IDENTITY


func _ready() -> void:
	add_to_group(&"powered_light")
	for n: Node in find_children("*", "Light3D", true, false):
		lights.append(n as Light3D)
		energies.append((n as Light3D).light_energy)
	_seed = float(get_instance_id() % 997) * 0.37
	_swing_base = basis
	if pattern != Pattern.NONE:
		for l: Light3D in lights:
			l.add_to_group(&"light_animated")
	else:
		set_process(false)
	if always_on:
		powered = true
		_apply(1.0)
	else:
		_apply(off_fraction)


# Called by Match.setup once the MatchSession exists (map _ready runs before it).
func _on_match_setup(m: Match) -> void:
	if always_on:
		return
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
	level = f
	_write(f * pattern_value(pattern, _t * rate + _seed, depth))


func _write(f: float) -> void:
	for i: int in lights.size():
		lights[i].light_energy = energies[i] * f
		lights[i].visible = f > 0.001


func _process(delta: float) -> void:
	_t += delta
	if pattern == Pattern.SWING:
		var a: float = sin(_t * rate * 1.3 + _seed) * 0.12 * depth
		basis = _swing_base * Basis(Vector3.FORWARD, a) * Basis(Vector3.RIGHT, a * 0.4)
	if level > 0.001:
		_write(level * pattern_value(pattern, _t * rate + _seed, depth))


# Deterministic multiplier in [1 - depth, 1] for time t (seconds × rate).
static func pattern_value(p: Pattern, t: float, d: float) -> float:
	match p:
		Pattern.FLICKER:
			# mostly steady, with bursts of fast dips every few seconds
			var burst: float = sin(t * 0.9) * sin(t * 0.37 + 1.7)
			if burst > 0.55:
				return 1.0 - d * (0.5 + 0.5 * signf(sin(t * 47.0) + sin(t * 31.0)))
			return 1.0 - d * 0.05 * (0.5 + 0.5 * sin(t * 13.0))
		Pattern.STROBE:
			return 1.0 if fmod(t, 1.0) < 0.12 else 1.0 - d
		Pattern.BLINK:
			return 1.0 if fmod(t, 1.6) < 0.5 else 1.0 - d
		Pattern.BUZZ:
			return 1.0 - d * 0.25 * (0.5 + 0.5 * sin(t * 120.0)) - (d * 0.6 if sin(t * 2.3) > 0.97 else 0.0)
		Pattern.SWING:
			return 1.0 - d * 0.1 * (0.5 + 0.5 * sin(t * 1.3))
		Pattern.PULSE:
			return 1.0 - d * (0.5 + 0.5 * sin(t * TAU * 0.8))
	return 1.0
