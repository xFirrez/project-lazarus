# Trap — the activation lever of one map trap (GAME_DESIGN §12) plus its area presentation. The lever
# console carries a status lamp: green READY, red ACTIVE, amber COOLING (and dark without power).
# The area shows the effect preset of its TrapDefinition while active: &"electric" floor plates that
# flicker blue with arcs, &"steam" jets venting from the walls, &"freeze" liquid-nitrogen mist and a
# frosted floor. Built procedurally (map art may add to it in Step 13; the markers stay put).
# Authority: HOST executes through TrapSystem; every peer presents from the replicated phase.
class_name Trap
extends Interactable

const SPACING: float = 2.5

var trap_id: StringName = &""
var def: TrapDefinition = null
var system: TrapSystem = null
var area_marker: MapMarker = null

var _lamp_mat: StandardMaterial3D = null
var _lamp_light: OmniLight3D = null
var _lever: Node3D = null
var _fx_root: Node3D = null
var _plates: Array[MeshInstance3D] = []
var _plate_mat: StandardMaterial3D = null
var _emitters: Array[CPUParticles3D] = []
var _area_light: OmniLight3D = null
var _was_phase: int = -1
var _t: float = 0.0
var _sound_t: float = 0.0


func _ready() -> void:
	super()
	cost = def.cost if def != null else 1000
	requires_power = def.requires_power if def != null else true
	hold_time = 0.4
	use_radius = 2.0
	ping_label = def.display_name if def != null else String(trap_id)
	prompt = "activate %s" % (def.display_name if def != null else "the trap")
	_build_console()
	_build_area.call_deferred()


func focus_point() -> Vector3:
	return global_position


func is_available(_player: PlayerCharacter) -> bool:
	return system != null and def != null


func get_cost(_player: PlayerCharacter) -> int:
	return cost if system != null and system.phase(self) == TrapSystem.Phase.READY else 0


func get_prompt(player: PlayerCharacter) -> String:
	if system == null:
		return ""
	if not Power.is_on() and requires_power:
		return "%s — requires power" % def.display_name
	match system.phase(self):
		TrapSystem.Phase.ACTIVE:
			return "%s active" % def.display_name
		TrapSystem.Phase.COOLING:
			return "%s cooling down (%d s)" % [def.display_name, int(ceil(system.time_left(self)))]
	return super(player)


func host_check(_peer_id: int, _player: PlayerCharacter) -> String:
	return system.host_check(self) if system != null else "invalid"


func host_execute(peer_id: int, _player: PlayerCharacter) -> bool:
	return system != null and system.host_activate(self, peer_id)


func _process(delta: float) -> void:
	_t += delta
	if system == null or def == null:
		return
	var ph: int = system.phase(self)
	var col: Color = Color(0.1, 0.1, 0.1)
	if Power.is_on() or not requires_power:
		col = [Color(0.2, 1.0, 0.3), Color(1.0, 0.15, 0.1), Color(1.0, 0.6, 0.1)][ph]
	_lamp_mat.emission = col
	_lamp_mat.emission_energy_multiplier = 2.5 if col != Color(0.1, 0.1, 0.1) else 0.0
	_lamp_light.light_color = col
	_lamp_light.light_energy = 0.6 if _lamp_mat.emission_energy_multiplier > 0.0 else 0.0
	if ph != _was_phase:
		_on_phase(ph)
		_was_phase = ph
	_lever.rotation.x = lerpf(
		_lever.rotation.x, -0.9 if ph == TrapSystem.Phase.ACTIVE else 0.6, clampf(delta * 8.0, 0.0, 1.0)
	)
	if ph == TrapSystem.Phase.ACTIVE:
		_animate_active(delta)


func _on_phase(ph: int) -> void:
	var active: bool = ph == TrapSystem.Phase.ACTIVE
	if _was_phase >= 0:
		if active:
			Audio.play_event_3d(&"trap_lever", global_position)
		elif ph == TrapSystem.Phase.READY:
			Audio.play_event_3d(&"trap_ready", global_position)
	if _fx_root == null:
		return
	_fx_root.visible = active
	for e: CPUParticles3D in _emitters:
		e.emitting = active
	if def.effect == &"freeze" and _plate_mat != null:
		_plate_mat.albedo_color = Color(0.85, 0.95, 1.0, 0.55 if active else 0.0)


func _animate_active(delta: float) -> void:
	_sound_t -= delta
	if _sound_t <= 0.0 and area_marker != null:
		_sound_t = 0.9
		var ev: StringName = {&"electric": &"trap_electric", &"steam": &"trap_steam", &"freeze": &"trap_coolant"}.get(
			def.effect, &"trap_electric"
		)
		Audio.play_event_3d(ev, area_marker.global_position + Vector3.UP)
	if def.effect == &"electric":
		for i: int in _plates.size():
			_plates[i].visible = fmod(_t * 9.0 + i * 0.29, 1.0) < 0.7
		if _area_light != null:
			_area_light.light_energy = 2.0 + 2.0 * absf(sin(_t * 31.0))


func _build_console() -> void:
	var box: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.5, 0.7, 0.25)
	box.mesh = bm
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.22, 0.2)
	dark.metallic = 0.6
	box.material_override = dark
	add_child(box)
	_lever = Node3D.new()
	_lever.position = Vector3(0.1, 0.0, 0.14)
	add_child(_lever)
	var arm: MeshInstance3D = MeshInstance3D.new()
	var am: BoxMesh = BoxMesh.new()
	am.size = Vector3(0.05, 0.35, 0.05)
	arm.mesh = am
	arm.position = Vector3(0, 0.17, 0)
	var red: StandardMaterial3D = StandardMaterial3D.new()
	red.albedo_color = Color(0.6, 0.1, 0.08)
	arm.material_override = red
	_lever.add_child(arm)
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(0.1, 0.1, 0.1)
	_lamp_mat.emission_enabled = true
	var lamp: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	lamp.mesh = sm
	lamp.position = Vector3(-0.12, 0.25, 0.14)
	lamp.material_override = _lamp_mat
	add_child(lamp)
	_lamp_light = OmniLight3D.new()
	_lamp_light.position = Vector3(-0.12, 0.25, 0.3)
	_lamp_light.omni_range = 2.0
	add_child(_lamp_light)
	var label: Label3D = Label3D.new()
	label.text = "%s\n%d" % [def.display_name.to_upper() if def != null else String(trap_id), cost]
	label.position = Vector3(0, 0.55, 0.13)
	label.pixel_size = 0.0025
	label.modulate = Color(0.9, 0.85, 0.6)
	add_child(label)


# Area presentation, at the area marker (built once the tree is ready, hidden until active).
func _build_area() -> void:
	if area_marker == null or def == null:
		return
	_fx_root = Node3D.new()
	_fx_root.name = "TrapFx_%s" % trap_id
	_fx_root.top_level = true
	area_marker.add_child(_fx_root)
	_fx_root.global_transform = Transform3D.IDENTITY
	var pts: PackedVector3Array = def.sample_points(area_marker.global_transform, SPACING)
	_plate_mat = StandardMaterial3D.new()
	_plate_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_plate_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_plate_mat.albedo_color = Color(def.color.r, def.color.g, def.color.b, 0.55)
	_plate_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if def.effect != &"freeze" else BaseMaterial3D.BLEND_MODE_MIX
	for p: Vector3 in pts:
		if def.effect != &"steam":
			var plate: MeshInstance3D = MeshInstance3D.new()
			var pm: PlaneMesh = PlaneMesh.new()
			pm.size = Vector2(SPACING * 0.85, SPACING * 0.85)
			plate.mesh = pm
			plate.material_override = _plate_mat
			plate.position = p + Vector3.UP * 0.04
			plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_fx_root.add_child(plate)
			_plates.append(plate)
		if def.effect != &"electric" or _emitters.size() < 6:
			_emitters.append(_emitter(p))
	_area_light = OmniLight3D.new()
	_area_light.light_color = def.color
	_area_light.omni_range = 12.0
	_area_light.light_energy = 2.0
	_area_light.position = area_marker.global_position + Vector3.UP * 2.0
	_fx_root.add_child(_area_light)
	_fx_root.visible = false


func _emitter(p: Vector3) -> CPUParticles3D:
	var e: CPUParticles3D = CPUParticles3D.new()
	e.emitting = false
	e.amount = 10 if def.effect == &"electric" else 24
	e.lifetime = 0.35 if def.effect == &"electric" else 1.1
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.05, 0.4) if def.effect == &"electric" else Vector2(0.6, 0.6)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(def.color.r, def.color.g, def.color.b, 0.5)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	e.mesh = q
	e.direction = Vector3.UP
	e.spread = 25.0 if def.effect == &"steam" else 60.0
	e.initial_velocity_min = 1.5
	e.initial_velocity_max = 4.0 if def.effect == &"steam" else 2.5
	e.gravity = Vector3(0, 0.6, 0) if def.effect == &"steam" else Vector3(0, -1.0, 0)
	e.scale_amount_min = 0.6
	e.scale_amount_max = 1.6
	e.position = p + Vector3.UP * 0.1
	_fx_root.add_child(e)
	return e
