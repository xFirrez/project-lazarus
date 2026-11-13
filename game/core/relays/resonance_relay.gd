# ResonanceRelay — one relay apparatus (VESPER_PEAK §5 R1-R3; DEVELOPMENT_PLAN Step 11A scope 1):
# a vesperite-cell pylon wrapped in three resonator rings. Hold [F] 3 s (power) to start it; while
# CHARGING the rings spin up with progress, arcs crackle, a pulse sounds every second and a ring of
# lamps fills; PAUSED (no player in the zone) dims to amber and the rings coast; DONE locks a
# steady green beam into the sky. A floating progress label shows % and "PAUSED". Greybox+
# procedural model (Step 13 dresses each relay to its room: radar tower, operating table, chamber).
# Authority: HOST starts it through RelaySystem; presentation reads the replicated flags.
class_name ResonanceRelay
extends Interactable

const LAMPS: int = 10

var system: RelaySystem = null
var index: int = 0
var relay_id: StringName = &""
var zone: StringName = &""

var _rings: Array[Node3D] = []
var _ring_speed: float = 0.0
var _core_mat: StandardMaterial3D = null
var _lamp_mats: Array[StandardMaterial3D] = []
var _arcs: Array[MeshInstance3D] = []
var _beam: MeshInstance3D = null
var _light: OmniLight3D = null
var _label: Label3D = null
var _t: float = 0.0
var _pulse_t: float = 0.0
var _was_paused: bool = false


func _ready() -> void:
	super()
	hold_time = RelaySystem.HOLD_TIME
	use_radius = 2.8
	requires_power = true
	ping_kind = &"machine"
	ping_label = "Resonance Relay %s" % relay_id
	prompt = "activate Resonance Relay %s" % relay_id
	_build_visual()


func focus_point() -> Vector3:
	return global_position + Vector3.UP * 1.1


func is_available(_player: PlayerCharacter) -> bool:
	return system != null and system.state(index) == RelaySystem.State.IDLE


func get_prompt(player: PlayerCharacter) -> String:
	if not Power.is_on():
		return "Resonance Relay %s — requires power" % relay_id
	return super(player)


func host_check(_peer_id: int, _player: PlayerCharacter) -> String:
	return system.host_check(index) if system != null else "invalid"


func host_execute(_peer_id: int, _player: PlayerCharacter) -> bool:
	return system != null and system.host_activate(index)


# Flag change (every peer): one-shot audio for the transitions.
func on_state(s: int) -> void:
	match s:
		RelaySystem.State.CHARGING:
			Audio.play_event_3d(&"relay_start", global_position + Vector3.UP)
		RelaySystem.State.DONE:
			Audio.play_event_3d(&"relay_done", global_position + Vector3.UP)


func _process(delta: float) -> void:
	_t += delta
	if system == null:
		return
	var st: int = system.state(index)
	var frac: float = clampf(system.progress_of(index) / RelaySystem.DEFEND_TIME, 0.0, 1.0)
	var paused: bool = st == RelaySystem.State.CHARGING and system.is_paused(index)
	if paused and not _was_paused:
		Audio.play_event_3d(&"relay_pause", global_position + Vector3.UP)
	_was_paused = paused
	var target_speed: float = 0.0
	var core_e: float = 0.3 if Power.is_on() else 0.05
	var col: Color = Color(0.35, 1.0, 0.55)
	match st:
		RelaySystem.State.CHARGING:
			target_speed = 0.5 if paused else lerpf(1.5, 9.0, frac)
			core_e = 0.8 if paused else 1.0 + frac * 3.0 + 0.5 * sin(_t * 9.0)
			col = Color(1.0, 0.65, 0.2) if paused else col
			if not paused:
				_pulse_t -= delta
				if _pulse_t <= 0.0:
					_pulse_t = lerpf(1.0, 0.35, frac)
					Audio.play_event_3d(&"relay_pulse", global_position + Vector3.UP, 0.8 + frac * 0.6)
		RelaySystem.State.DONE:
			target_speed = 4.0
			core_e = 3.5 + 0.5 * sin(_t * 3.0)
	_ring_speed = lerpf(_ring_speed, target_speed, clampf(delta * 1.5, 0.0, 1.0))
	for i: int in _rings.size():
		_rings[i].rotate_object_local(
			Vector3.UP, _ring_speed * delta * (1.0 + i * 0.35) * (1.0 if i % 2 == 0 else -1.0)
		)
	_core_mat.emission = col
	_core_mat.emission_energy_multiplier = core_e
	_light.light_color = col
	_light.light_energy = core_e * 0.8
	var lit: int = int(round(frac * LAMPS)) if st != RelaySystem.State.IDLE else 0
	for i: int in _lamp_mats.size():
		_lamp_mats[i].emission_energy_multiplier = 2.0 if i < lit else 0.0
		_lamp_mats[i].emission = col
	for i: int in _arcs.size():
		_arcs[i].visible = st == RelaySystem.State.CHARGING and not paused and fmod(_t * 11.0 + i * 0.41, 1.0) < 0.5
		_arcs[i].rotation.y = _t * 4.0 + i * 1.7
	_beam.visible = st == RelaySystem.State.DONE
	if st == RelaySystem.State.CHARGING:
		_label.visible = true
		_label.text = (
			"RELAY %s  %d%%%s" % [relay_id, int(frac * 100.0), "\nPAUSED — return to the zone" if paused else ""]
		)
		_label.modulate = col
	elif st == RelaySystem.State.DONE:
		_label.visible = true
		_label.text = "RELAY %s ACTIVE" % relay_id
		_label.modulate = col
	else:
		_label.visible = false


func _build_visual() -> void:
	var dark: StandardMaterial3D = _mat(Color(0.12, 0.12, 0.14), 0.7)
	var brass: StandardMaterial3D = _mat(Color(0.55, 0.42, 0.2), 0.9)
	_core_mat = _mat(Color(0.2, 0.8, 0.45), 0.0)
	_core_mat.emission_enabled = true
	_add_mesh(_cyl_mesh(0.9, 1.0, 0.3), Vector3(0, 0.15, 0), dark)
	_add_mesh(_cyl_mesh(0.22, 0.3, 2.4), Vector3(0, 1.4, 0), dark)
	_add_mesh(_cyl_mesh(0.16, 0.16, 1.6), Vector3(0, 1.5, 0), _core_mat)
	for i: int in 3:
		var pivot: Node3D = Node3D.new()
		pivot.position = Vector3(0, 0.9 + i * 0.55, 0)
		pivot.rotation = Vector3(0.25 * (i - 1), 0, 0.2 * i)
		add_child(pivot)
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = 0.55 + i * 0.12
		tm.outer_radius = 0.63 + i * 0.12
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = tm
		mi.material_override = brass
		pivot.add_child(mi)
		var nub: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.12, 0.12, 0.12)
		nub.mesh = bm
		nub.position = Vector3(tm.outer_radius, 0, 0)
		nub.material_override = _core_mat
		pivot.add_child(nub)
		_rings.append(pivot)
	for i: int in LAMPS:
		var a: float = TAU * float(i) / float(LAMPS)
		var lm: StandardMaterial3D = _mat(Color(0.1, 0.1, 0.1), 0.0)
		lm.emission_enabled = true
		_lamp_mats.append(lm)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.12
		mi.mesh = sm
		mi.position = Vector3(cos(a) * 0.85, 0.32, sin(a) * 0.85)
		mi.material_override = lm
		add_child(mi)
	var arc_mat: StandardMaterial3D = StandardMaterial3D.new()
	arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc_mat.albedo_color = Color(0.6, 1.0, 0.75)
	arc_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	arc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i: int in 3:
		var arc: MeshInstance3D = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(0.03, 1.1)
		arc.mesh = q
		arc.material_override = arc_mat
		arc.position = Vector3(0, 1.5, 0)
		arc.rotation.z = 0.8 + i * 0.6
		arc.visible = false
		add_child(arc)
		_arcs.append(arc)
	_beam = MeshInstance3D.new()
	_beam.mesh = _cyl_mesh(0.12, 0.12, 30.0)
	_beam.position = Vector3(0, 17.0, 0)
	var bmat: StandardMaterial3D = StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(0.4, 1.0, 0.6, 0.45)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam.material_override = bmat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.6, 0)
	_light.omni_range = 7.0
	add_child(_light)
	_label = Label3D.new()
	_label.position = Vector3(0, 3.0, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.005
	_label.no_depth_test = true
	_label.visible = false
	add_child(_label)


func _add_mesh(m: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi


static func _cyl_mesh(top: float, bottom: float, h: float) -> CylinderMesh:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	return cm


static func _mat(c: Color, metal: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.5
	return m
