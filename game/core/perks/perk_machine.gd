# PerkMachine — a Vigor Tonic vending machine (GAME_DESIGN §8, VESPER_PEAK §5.2; DEVELOPMENT_PLAN
# Step 10 scope 2). Interactable: price from PerkSystem (Second Wind 500 solo / 1500 co-op), needs
# power except Second Wind, refused when owned / at the cap / drinking. Built procedurally (the
# "greybox+" art path, like the Step 9 weapons; authored GLBs replace `_build_visual` in Step 13):
# a cabinet in the perk's accent colour, an outline of neon in the perk colour, a lit sign with the
# name, a bottle window with an idle bob, a unique silhouette piece per perk (keg, lightning bolts,
# double barrels, runner, medical cross, target dial, mule head) and a ground glow light. Power off
# = neon / sign / light dark. Purchase = a bottle drops into the tray. The idle jingle plays by
# chance while a player looks at the machine. Second Wind vanishes after its 3rd solo self-revive.
# The machine turns to face the most open side of its marker on the first physics frame.
# Authority: HOST executes through PerkSystem; visuals read replicated state on every peer.
class_name PerkMachine
extends Interactable

const JINGLE_COOLDOWN: float = 25.0

var perk_id: StringName = &""
var system: PerkSystem = null
var powered_visual: bool = true
var vends: int = 0  # bottles dropped (presentation)

var _neon: StandardMaterial3D = null
var _glass: StandardMaterial3D = null
var _light: OmniLight3D = null
var _sign: Label3D = null
var _bottles: Array[Node3D] = []
var _spinner: Node3D = null
var _tray_bottle: Node3D = null
var _t: float = 0.0
var _jingle_wait: float = 6.0
var _vanished: bool = false


func definition() -> PerkDefinition:
	return PerkCatalog.get_def(perk_id)


func _ready() -> void:
	super()
	var d: PerkDefinition = definition()
	requires_power = d.requires_power if d != null else true
	hold_time = 0.4
	use_radius = 2.0
	ping_kind = &"machine"
	ping_label = d.display_name if d != null else String(perk_id)
	prompt = "drink"
	_build_visual()
	_apply_power(_power_on())
	if system != null:
		system.drink_started.connect(_on_drink_started)
	_face_open_side.call_deferred()


func _power_on() -> bool:
	return not requires_power or Power.is_on()


func focus_point() -> Vector3:
	return global_position + global_transform.basis.z * 0.45 + Vector3.UP * 1.1


# --- Interactable -------------------------------------------------------------------------------


func is_available(_player: PlayerCharacter) -> bool:
	return not _vanished


func get_cost(_player: PlayerCharacter) -> int:
	var d: PerkDefinition = definition()
	if d == null:
		return 0
	return system.price_of(d) if system != null else d.cost


func get_prompt(player: PlayerCharacter) -> String:
	var d: PerkDefinition = definition()
	var label: String = d.display_name if d != null else String(perk_id)
	if requires_power and not Power.is_on():
		return "%s — requires power" % label
	if system != null and system.has_perk(player.peer_id, perk_id):
		return "%s owned" % label
	return "Hold [F] to drink %s [%d]" % [label, get_cost(player)]


func host_check(peer_id: int, _player: PlayerCharacter) -> String:
	return system.host_check(peer_id, perk_id) if system != null else "invalid"


func host_execute(peer_id: int, _player: PlayerCharacter) -> bool:
	return system != null and system.host_begin_purchase(peer_id, perk_id)


# --- presentation -------------------------------------------------------------------------------


func _process(delta: float) -> void:
	_t += delta
	var on: bool = _power_on()
	if on != powered_visual:
		_apply_power(on)
	var gone: bool = (
		perk_id == PerkSystem.SECOND_WIND and system != null and system.is_solo() and not system.second_wind_available()
	)
	if gone != _vanished:
		_vanished = gone
		visible = not gone
		if gone:
			Audio.play_event_3d(&"perk_vanish", global_position)
	if not visible:
		return
	for i: int in _bottles.size():
		_bottles[i].position.y = 1.18 + sin(_t * 1.6 + i * 1.3) * 0.015
	if _spinner != null:
		_spinner.rotation.z = sin(_t * 0.9) * 0.8 if on else 0.0
	if on and _neon != null:
		var flick: float = 1.0 if fmod(_t * 0.37 + float(perk_id.hash() % 7), 6.0) > 0.08 else 0.25
		_neon.emission_energy_multiplier = (2.4 + sin(_t * 3.0) * 0.25) * flick
	_idle_jingle(delta, on)


func _idle_jingle(delta: float, on: bool) -> void:
	var m: Match = Match.current
	if m == null or m.interaction == null or m.interaction.focus != self or not on:
		return
	_jingle_wait -= delta
	if _jingle_wait > 0.0:
		return
	_jingle_wait = 5.0
	if randf() < 0.35:
		_jingle_wait = JINGLE_COOLDOWN
		var d: PerkDefinition = definition()
		if d != null:
			Audio.play_event_3d(d.jingle_event(), global_position)


func _on_drink_started(_peer: int, pid: StringName) -> void:
	if pid != perk_id or _tray_bottle == null:
		return
	# Only the nearest machine of that perk vends (there is one per map, but stay generic).
	vends += 1
	_tray_bottle.visible = true
	_tray_bottle.position = Vector3(0.0, 1.05, 0.33)
	var tw: Tween = create_tween()
	tw.tween_property(_tray_bottle, "position", Vector3(0.0, 0.38, 0.36), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	tw.tween_interval(PerkSystem.DRINK_TIME)
	tw.tween_callback(func() -> void: _tray_bottle.visible = false)
	Audio.play_event_3d(&"perk_vend", global_position)


func _apply_power(on: bool) -> void:
	powered_visual = on
	if _neon != null:
		_neon.emission_enabled = on
		_neon.albedo_color = (definition().color if definition() != null else Color.WHITE) * (1.0 if on else 0.25)
	if _glass != null:
		_glass.emission_enabled = on
	if _light != null:
		_light.visible = on
	if _sign != null:
		_sign.modulate = (definition().color if definition() != null else Color.WHITE) if on else Color(0.2, 0.2, 0.2)
	if on and is_inside_tree() and visible and Match.current != null:
		Audio.play_event_3d(&"perk_power_on", global_position)


# Faces the side with the most clearance (markers carry no facing), ignoring players / zombies.
func _face_open_side() -> void:
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var best_yaw: float = 0.0
	var best_d: float = -1.0
	var origin: Vector3 = get_parent_node_3d().global_position + Vector3.UP * 1.0
	for k: int in 4:
		var yaw: float = k * PI * 0.5
		var dir: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + dir * 6.0, 1)
		var hit: Dictionary = space.intersect_ray(q)
		var d: float = 6.0 if hit.is_empty() else origin.distance_to(hit["position"] as Vector3)
		if d > best_d + 0.05:
			best_d = d
			best_yaw = yaw
	global_rotation.y = best_yaw
	# Solid cabinet (added after the clearance probe so it doesn't block its own rays).
	var sb: StaticBody3D = StaticBody3D.new()
	sb.name = "Collider"
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.2, 2.2, 0.9)
	cs.shape = shape
	cs.position = Vector3(0, 1.1, 0)
	sb.add_child(cs)
	sb.set_meta(&"surface", &"metal")
	add_child(sb)


func _build_visual() -> void:
	var d: PerkDefinition = definition()
	if d == null:
		return
	var body: StandardMaterial3D = _mat(d.accent, 0.55, 0.35)
	var trim: StandardMaterial3D = _mat(d.accent.darkened(0.55), 0.4, 0.6)
	_neon = _mat(d.color, 0.3, 0.0)
	_neon.emission_enabled = true
	_neon.emission = d.color
	_neon.emission_energy_multiplier = 2.4
	_glass = _mat(Color(d.color.r * 0.3, d.color.g * 0.3, d.color.b * 0.3, 0.55), 0.05, 0.0)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.emission_enabled = true
	_glass.emission = d.color * 0.35
	# Cabinet, plinth, crown.
	_box(Vector3(0, 0.06, 0), Vector3(1.2, 0.12, 0.9), trim)
	_box(Vector3(0, 1.08, 0), Vector3(1.1, 1.95, 0.8), body)
	_box(Vector3(0, 2.12, 0.02), Vector3(1.22, 0.16, 0.88), trim)
	# Neon outline on the front.
	for e: Array in [
		[Vector3(-0.53, 1.08, 0.41), Vector3(0.04, 1.9, 0.02)],
		[Vector3(0.53, 1.08, 0.41), Vector3(0.04, 1.9, 0.02)],
		[Vector3(0, 2.02, 0.41), Vector3(1.08, 0.04, 0.02)],
		[Vector3(0, 0.15, 0.41), Vector3(1.08, 0.04, 0.02)]
	]:
		_box(e[0], e[1], _neon)
	# Sign + name.
	_box(Vector3(0, 1.78, 0.405), Vector3(0.94, 0.36, 0.02), trim)
	_sign = Label3D.new()
	_sign.text = d.display_name.to_upper()
	_sign.font_size = 40
	_sign.outline_size = 6
	_sign.pixel_size = 0.0025
	_sign.width = 340.0
	_sign.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sign.position = Vector3(0, 1.78, 0.42)
	_sign.modulate = d.color
	add_child(_sign)
	# Bottle window with three bottles (idle bob) and the vending tray.
	_box(Vector3(0, 1.2, 0.41), Vector3(0.8, 0.42, 0.02), _glass)
	for i: int in 3:
		var b: Node3D = PerkBottle.build(d)
		b.position = Vector3(-0.25 + 0.25 * i, 1.18, 0.33)
		b.scale = Vector3.ONE * 0.9
		add_child(b)
		_bottles.append(b)
	_box(Vector3(0, 0.36, 0.42), Vector3(0.5, 0.06, 0.14), trim)
	_tray_bottle = PerkBottle.build(d)
	_tray_bottle.visible = false
	add_child(_tray_bottle)
	_box(Vector3(0, 0.75, 0.415), Vector3(0.3, 0.12, 0.02), _neon)  # coin slot glow
	_build_silhouette(d, body, trim)
	_light = OmniLight3D.new()
	_light.light_color = d.color
	_light.light_energy = 1.4
	_light.omni_range = 4.5
	_light.position = Vector3(0, 1.2, 0.9)
	_light.shadow_enabled = false
	add_child(_light)


func _build_silhouette(d: PerkDefinition, body: StandardMaterial3D, trim: StandardMaterial3D) -> void:
	match d.silhouette:
		PerkDefinition.Silhouette.KEG:  # Ironhide: iron keg + tap on the crown, rivet rows
			var keg: MeshInstance3D = _cyl(Vector3(0, 2.48, 0), 0.32, 0.7, _mat(Color(0.35, 0.33, 0.32), 0.7, 0.8))
			keg.rotation.z = PI * 0.5
			for x: float in [-0.25, 0.25]:
				var band: MeshInstance3D = _cyl(Vector3(x, 2.48, 0), 0.335, 0.05, trim)
				band.rotation.z = PI * 0.5
			_box(Vector3(0, 2.5, 0.36), Vector3(0.08, 0.08, 0.14), _neon)
			for i: int in 6:
				for side: float in [-0.52, 0.52]:
					_sphere(Vector3(side, 0.35 + i * 0.32, 0.41), 0.022, trim)
		PerkDefinition.Silhouette.BOLTS:  # Quickdraw: art-deco lightning bolts flanking the cabinet
			for side: float in [-1.0, 1.0]:
				for k: int in 3:
					var seg: MeshInstance3D = _box(
						Vector3(side * 0.64, 0.6 + k * 0.5, 0.2), Vector3(0.06, 0.42, 0.06), _neon
					)
					seg.rotation.z = side * (0.5 if k % 2 == 0 else -0.5)
			_box(Vector3(0, 2.3, 0.0), Vector3(0.9, 0.2, 0.5), body)
			for k: int in 5:
				_box(Vector3(-0.36 + k * 0.18, 2.42, 0.0), Vector3(0.05, 0.08 + k % 3 * 0.06, 0.4), trim)
		PerkDefinition.Silhouette.DOUBLE_TAP:  # Twin-Fire: double barrel tap over the sign
			for x: float in [-0.13, 0.13]:
				var bar: MeshInstance3D = _cyl(
					Vector3(x, 2.36, 0.15), 0.085, 0.95, _mat(Color(0.2, 0.18, 0.16), 0.5, 0.9)
				)
				bar.rotation.x = PI * 0.5
				var bore: MeshInstance3D = _cyl(Vector3(x, 2.36, 0.63), 0.05, 0.02, _neon)
				bore.rotation.x = PI * 0.5
			_box(Vector3(0, 2.3, -0.2), Vector3(0.5, 0.22, 0.4), trim)
		PerkDefinition.Silhouette.RUNNER:  # Marathon: a running figure in neon on the crown
			var fig: Node3D = Node3D.new()
			fig.position = Vector3(0, 2.55, 0.0)
			add_child(fig)
			_part(fig, Vector3(0, 0.12, 0), Vector3(0.07, 0.3, 0.05), 0.35)
			_sphere_on(fig, Vector3(0.06, 0.33, 0), 0.07, _neon)
			_part(fig, Vector3(-0.1, -0.13, 0), Vector3(0.05, 0.28, 0.05), 0.8)
			_part(fig, Vector3(0.1, -0.12, 0), Vector3(0.05, 0.28, 0.05), -0.6)
			_part(fig, Vector3(-0.12, 0.17, 0), Vector3(0.04, 0.22, 0.05), -1.1)
			_part(fig, Vector3(0.14, 0.12, 0), Vector3(0.04, 0.22, 0.05), 1.0)
			_box(Vector3(0, 2.25, 0), Vector3(0.8, 0.1, 0.4), trim)
		PerkDefinition.Silhouette.CROSS:  # Second Wind: medical cross, white enamel
			_box(Vector3(0, 2.5, 0.05), Vector3(0.16, 0.5, 0.1), _neon)
			_box(Vector3(0, 2.5, 0.05), Vector3(0.5, 0.16, 0.1), _neon)
			_box(Vector3(0, 0.55, 0.42), Vector3(0.7, 0.18, 0.02), _mat(Color(0.9, 0.12, 0.1), 0.6, 0.0))
		PerkDefinition.Silhouette.DIAL:  # Bullseye: target dial with a sweeping needle
			for r: float in [0.34, 0.24, 0.13]:
				var ring: MeshInstance3D = _cyl(Vector3(0, 2.52, 0.0), r, 0.04, _neon if r != 0.24 else trim)
				ring.rotation.x = PI * 0.5
				ring.position.z += (0.34 - r) * 0.1
			_spinner = Node3D.new()
			_spinner.position = Vector3(0, 2.52, 0.06)
			add_child(_spinner)
			var needle: MeshInstance3D = MeshInstance3D.new()
			var nm: BoxMesh = BoxMesh.new()
			nm.size = Vector3(0.03, 0.3, 0.02)
			needle.mesh = nm
			needle.position = Vector3(0, 0.13, 0)
			needle.material_override = trim
			_spinner.add_child(needle)
		PerkDefinition.Silhouette.MULE:  # Pack Mule: mule head mascot with long ears
			var head: Node3D = Node3D.new()
			head.position = Vector3(0, 2.5, 0.05)
			add_child(head)
			var fur: StandardMaterial3D = _mat(Color(0.45, 0.36, 0.26), 0.9, 0.0)
			_part(head, Vector3(0, 0, 0), Vector3(0.3, 0.32, 0.3), 0.0, fur)
			_part(head, Vector3(0, -0.12, 0.2), Vector3(0.22, 0.18, 0.22), 0.0, _mat(Color(0.7, 0.6, 0.5), 0.9, 0.0))
			_part(head, Vector3(-0.1, 0.3, 0), Vector3(0.07, 0.34, 0.05), 0.25, fur)
			_part(head, Vector3(0.1, 0.3, 0), Vector3(0.07, 0.34, 0.05), -0.25, fur)
			_sphere_on(head, Vector3(-0.08, 0.05, 0.16), 0.03, _neon)
			_sphere_on(head, Vector3(0.08, 0.05, 0.16), 0.03, _neon)
			_box(Vector3(0, 2.25, 0), Vector3(0.9, 0.12, 0.6), trim)


# --- mesh helpers -------------------------------------------------------------------------------


func _box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi


func _cyl(pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 16
	mi.mesh = cm
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi


func _sphere(pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	return _sphere_on(self, pos, radius, mat)


func _sphere_on(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _part(parent: Node3D, pos: Vector3, size: Vector3, roll: float, mat: Material = null) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation.z = roll
	mi.material_override = mat if mat != null else _neon
	parent.add_child(mi)
	return mi


static func _mat(c: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	m.metallic = metallic
	return m
