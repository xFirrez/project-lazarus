# LabBreaker — H3 (VESPER_PEAK §5): a free breaker box (power required) that electrifies the
# Containment Labs' water puddles for ACTIVE_TIME: zombies in a puddle are stunned and take damage,
# players in one take light damage; RECHARGE seconds before it can be flipped again.
# Shared state: MatchSession flags "hazard.H3.until" / ".ready" (host times).
# Authority: HOST flips it through HazardSystem; puddles light up from the flags on every peer.
class_name LabBreaker
extends Interactable

const ACTIVE_TIME: float = 10.0
const RECHARGE: float = 90.0
const PUDDLE_RADIUS: float = 1.5

var system: HazardSystem = null
var puddles: PackedVector3Array = []  # world centres

var _puddle_mats: Array[StandardMaterial3D] = []
var _lamp: StandardMaterial3D = null
var _handle: Node3D = null
var _t: float = 0.0
var _zap_t: float = 0.0
var _was_on: bool = false


func _ready() -> void:
	super()
	requires_power = true
	hold_time = 0.3
	use_radius = 1.8
	ping_label = "Lab breaker"
	prompt = "flip the breaker"
	_build()


func is_available(_player: PlayerCharacter) -> bool:
	return system != null


func get_prompt(player: PlayerCharacter) -> String:
	if not Power.is_on():
		return "Breaker — requires power"
	if system.breaker_active():
		return "Puddles electrified"
	if system.breaker_cooling():
		return "Breaker recharging (%d s)" % int(ceil(system.breaker_ready_at() - Net.host_time()))
	return super(player)


func host_check(_peer_id: int, _player: PlayerCharacter) -> String:
	return "Recharging" if system.breaker_active() or system.breaker_cooling() else ""


func host_execute(peer_id: int, _player: PlayerCharacter) -> bool:
	return system.host_flip_breaker(peer_id)


func _process(delta: float) -> void:
	_t += delta
	if system == null:
		return
	var on: bool = system.breaker_active()
	if on != _was_on:
		_was_on = on
		Audio.play_event_3d(&"breaker_thunk", global_position)
	var flick: float = (0.5 + 0.5 * absf(sin(_t * 37.0))) if on else 0.0
	for m: StandardMaterial3D in _puddle_mats:
		m.emission_energy_multiplier = 2.5 * flick
	_handle.rotation.z = lerpf(_handle.rotation.z, -0.8 if on else 0.8, clampf(delta * 10.0, 0.0, 1.0))
	var cool: bool = system.breaker_cooling()
	_lamp.emission = Color(1.0, 0.2, 0.1) if on else (Color(1.0, 0.6, 0.1) if cool else Color(0.2, 1.0, 0.3))
	_lamp.emission_energy_multiplier = 2.0 if Power.is_on() else 0.0
	if on:
		_zap_t -= delta
		if _zap_t <= 0.0 and not puddles.is_empty():
			_zap_t = 0.7
			Audio.play_event_3d(&"puddle_zap", puddles[randi() % puddles.size()])


func _build() -> void:
	var box: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.45, 0.6, 0.18)
	box.mesh = bm
	var grey: StandardMaterial3D = StandardMaterial3D.new()
	grey.albedo_color = Color(0.42, 0.44, 0.42)
	grey.metallic = 0.5
	box.material_override = grey
	add_child(box)
	_handle = Node3D.new()
	_handle.position = Vector3(0, 0, 0.12)
	add_child(_handle)
	var h: MeshInstance3D = MeshInstance3D.new()
	var hm: BoxMesh = BoxMesh.new()
	hm.size = Vector3(0.05, 0.28, 0.05)
	h.mesh = hm
	h.position.y = 0.12
	var black: StandardMaterial3D = StandardMaterial3D.new()
	black.albedo_color = Color(0.05, 0.05, 0.05)
	h.material_override = black
	_handle.add_child(h)
	_lamp = StandardMaterial3D.new()
	_lamp.emission_enabled = true
	var lamp: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	lamp.mesh = sm
	lamp.position = Vector3(0.15, 0.22, 0.1)
	lamp.material_override = _lamp
	add_child(lamp)
	var lab: Label3D = Label3D.new()
	lab.text = "DANGER\nHIGH VOLTAGE"
	lab.position = Vector3(0, -0.2, 0.1)
	lab.pixel_size = 0.002
	lab.modulate = Color(1.0, 0.85, 0.1)
	add_child(lab)
	_build_puddles.call_deferred()
	_face_puddles.call_deferred()


# Turn the breaker box (yaw only) to face its puddles, i.e. into the room.
func _face_puddles() -> void:
	if puddles.is_empty() or not is_inside_tree():
		return
	var c: Vector3 = Vector3.ZERO
	for p: Vector3 in puddles:
		c += p
	c /= float(puddles.size())
	var d: Vector3 = c - global_position
	d.y = 0.0
	if d.length() > 0.1:
		global_rotation.y = atan2(d.x, d.z)


func _build_puddles() -> void:
	for c: Vector3 in puddles:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = PUDDLE_RADIUS
		cm.bottom_radius = PUDDLE_RADIUS
		cm.height = 0.02
		mi.mesh = cm
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(0.25, 0.32, 0.35, 0.7)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.02
		m.metallic_specular = 1.0
		m.emission_enabled = true
		m.emission = Color(0.5, 0.8, 1.0)
		m.emission_energy_multiplier = 0.0
		mi.material_override = m
		mi.top_level = true
		add_child(mi)
		mi.global_position = c + Vector3.UP * 0.02
		_puddle_mats.append(m)
