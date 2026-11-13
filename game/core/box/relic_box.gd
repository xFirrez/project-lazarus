# RelicBox — one Relic Box location (GAME_DESIGN §10.1): an iron-banded steamer trunk with occult /
# military stamps, a green light pillar while it is here, a lid that opens with a bell chime and the
# music-box melody, the decelerating weapon carousel above it (seeded, ends on the true result on
# every peer), the floating weapon (sinks back over the offer time), the porcelain doll (laugh, lid
# slam, the box rises into the light and vanishes) and the teleport-in flash. All presentation is
# derived from RelicBoxSystem's replicated state every frame.
# Authority: HOST executes purchases / takes through RelicBoxSystem; visuals are local.
class_name RelicBox
extends Interactable

const PILLAR_HEIGHT: float = 40.0
const ITEM_HEIGHT: float = 1.05
const RISE_HEIGHT: float = 7.0

var system: RelicBoxSystem = null
var index: int = 0
var location_id: StringName = &""
var shown_item: StringName = &""

var _root: Node3D = null
var _lid: Node3D = null
var _pillar: MeshInstance3D = null
var _pillar_mat: StandardMaterial3D = null
var _item_holder: Node3D = null
var _item_node: Node3D = null
var _collider: StaticBody3D = null
var _was_present: bool = false
var _was_phase: int = -1
var _flash: float = 0.0
var _laughed: bool = false


func _ready() -> void:
	super()
	hold_time = 0.3
	use_radius = 2.2
	ping_kind = &"machine"
	ping_label = "Relic Box"
	RelicBoxAudio.ensure()
	_build()
	_update_visual(0.0)


func focus_point() -> Vector3:
	return global_position + Vector3.UP * 0.6


# --- Interactable -------------------------------------------------------------------------------


func is_available(player: PlayerCharacter) -> bool:
	if system == null or not system.is_present(index):
		return false
	match system.phase(index):
		RelicBoxSystem.Phase.IDLE:
			return true
		RelicBoxSystem.Phase.OFFER:
			return int(system.spin_of(index)[0]) == player.peer_id
	return false


func get_cost(_player: PlayerCharacter) -> int:
	if system == null or system.phase(index) != RelicBoxSystem.Phase.IDLE:
		return 0
	return system.cost()


func get_prompt(player: PlayerCharacter) -> String:
	if system != null and system.phase(index) == RelicBoxSystem.Phase.OFFER:
		var def: WeaponDefinition = WeaponCatalog.get_def(StringName(system.spin_of(index)[1]))
		return "Hold [F] to take %s" % (def.display_name if def != null else "weapon")
	return "Hold [F] for the Relic Box [%d]" % get_cost(player)


func host_check(peer_id: int, _player: PlayerCharacter) -> String:
	return system.host_check(index, peer_id) if system != null else "invalid"


func host_execute(peer_id: int, player: PlayerCharacter) -> bool:
	return system != null and system.host_use(index, peer_id, get_cost(player))


# --- presentation -------------------------------------------------------------------------------


func _process(delta: float) -> void:
	_update_visual(delta)


func _update_visual(delta: float) -> void:
	if system == null or _root == null:
		return
	var present: bool = system.is_present(index)
	var ph: int = system.phase(index)
	var s: Array = system.spin_of(index)
	var t: float = system.now() - float(s[3]) if not s.is_empty() else 0.0
	if present and not _was_present:
		_flash = 1.0  # teleport-in
		Audio.play_event_3d(&"box_land", global_position)
	_was_present = present
	if ph != _was_phase:
		_on_phase_changed(ph)
		_was_phase = ph
	_flash = maxf(_flash - delta * 1.2, 0.0)
	_root.visible = present
	_collider.process_mode = Node.PROCESS_MODE_INHERIT if present else Node.PROCESS_MODE_DISABLED
	_collider.collision_layer = 1 if present else 0
	_pillar.visible = present
	var pillar_w: float = 1.0 + _flash * 2.5
	_pillar.scale = Vector3(pillar_w, 1.0, pillar_w)
	_pillar_mat.albedo_color.a = 0.22 + 0.5 * _flash
	_root.position = Vector3.ZERO
	var lid_open: float = 0.0
	var item: StringName = &""
	var item_y: float = ITEM_HEIGHT
	match ph:
		RelicBoxSystem.Phase.SPINNING:
			lid_open = clampf(t / 0.35, 0.0, 1.0)
			item = system.carousel_item(index, t)
			item_y = ITEM_HEIGHT * clampf(t / 0.6, 0.3, 1.0)
		RelicBoxSystem.Phase.OFFER:
			lid_open = 1.0
			item = StringName(s[1])
			var left: float = system.pool.spin_time + system.pool.offer_time - t
			item_y = ITEM_HEIGHT * clampf(left / 3.0, 0.15, 1.0)  # sinks back in the last 3 s
		RelicBoxSystem.Phase.LEAVING:
			var lt: float = t - system.pool.spin_time
			item = RelicBoxRoller.DOLL if lt < 1.2 else &""
			lid_open = 0.0 if lt > 0.5 else 1.0  # lid slams
			_root.position = (
				Vector3.UP * RISE_HEIGHT * clampf((lt - 0.8) / maxf(system.pool.move_time - 0.8, 0.1), 0.0, 1.0)
			)
			_pillar_mat.albedo_color.a = 0.22 + 0.4 * clampf(lt / 2.0, 0.0, 1.0)
	_lid.rotation.x = -deg_to_rad(105.0) * lid_open
	_set_item(item)
	if _item_node != null:
		_item_holder.position = Vector3(0, item_y, 0)
		_item_holder.rotation.y += delta * 1.2


func _on_phase_changed(ph: int) -> void:
	match ph:
		RelicBoxSystem.Phase.SPINNING:
			_laughed = false
			Audio.play_event_3d(&"box_open", global_position)
			Audio.play_event_3d(&"box_music", global_position)
		RelicBoxSystem.Phase.OFFER:
			Audio.play_event_3d(&"box_chime", global_position)
		RelicBoxSystem.Phase.LEAVING:
			if not _laughed:
				_laughed = true
				Audio.play_event_3d(&"box_doll_laugh", global_position)
				Audio.play_event_3d(&"box_lid_slam", global_position)


func _set_item(item: StringName) -> void:
	if item == shown_item:
		return
	shown_item = item
	if _item_node != null:
		_item_node.queue_free()
		_item_node = null
	if item == &"":
		return
	_item_node = _build_item(item)
	_item_holder.add_child(_item_node)


static func _build_item(item: StringName) -> Node3D:
	if item == RelicBoxRoller.DOLL:
		return _build_doll()
	var def: WeaponDefinition = WeaponCatalog.get_def(item)
	if def == null:
		return Node3D.new()
	if def.world_scene != null:
		var n: Node3D = def.world_scene.instantiate() as Node3D
		n.scale = Vector3.ONE * 1.4
		return n
	var g: Node3D = GreyboxGun.build(def, 1)
	g.scale = Vector3.ONE * 1.6
	var holder: Node3D = Node3D.new()
	holder.add_child(g)
	g.rotation.y = PI * 0.5  # broadside to the players
	_glow(g)
	return holder


static func _glow(n: Node) -> void:
	for c: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c as MeshInstance3D
		var m: StandardMaterial3D = mi.material_override as StandardMaterial3D
		if m != null:
			m = m.duplicate() as StandardMaterial3D
			m.emission_enabled = true
			m.emission = Color(0.25, 0.9, 0.4)
			m.emission_energy_multiplier = 0.35
			mi.material_override = m


static func _build_doll() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "PorcelainDoll"
	var porcelain: StandardMaterial3D = StandardMaterial3D.new()
	porcelain.albedo_color = Color(0.93, 0.9, 0.86)
	porcelain.roughness = 0.25
	var dress: StandardMaterial3D = StandardMaterial3D.new()
	dress.albedo_color = Color(0.35, 0.12, 0.16)
	var head: MeshInstance3D = MeshInstance3D.new()
	var hs: SphereMesh = SphereMesh.new()
	hs.radius = 0.09
	hs.height = 0.18
	head.mesh = hs
	head.position = Vector3(0, 0.3, 0)
	head.material_override = porcelain
	root.add_child(head)
	var body: MeshInstance3D = MeshInstance3D.new()
	var bc: CylinderMesh = CylinderMesh.new()
	bc.top_radius = 0.05
	bc.bottom_radius = 0.12
	bc.height = 0.26
	body.mesh = bc
	body.position = Vector3(0, 0.1, 0)
	body.material_override = dress
	root.add_child(body)
	for i: int in 2:  # black glass eyes
		var eye: MeshInstance3D = MeshInstance3D.new()
		var es: SphereMesh = SphereMesh.new()
		es.radius = 0.014
		es.height = 0.028
		eye.mesh = es
		eye.position = Vector3(-0.03 + 0.06 * i, 0.32, 0.08)
		var em: StandardMaterial3D = StandardMaterial3D.new()
		em.albedo_color = Color(0.02, 0.02, 0.02)
		eye.material_override = em
		root.add_child(eye)
	return root


func _build() -> void:
	_root = Node3D.new()
	_root.name = "Trunk"
	add_child(_root)
	var wood: StandardMaterial3D = _mat(Color(0.3, 0.2, 0.12), 0.85)
	var iron: StandardMaterial3D = _mat(Color(0.16, 0.16, 0.17), 0.5)
	iron.metallic = 0.7
	var stamp: StandardMaterial3D = _mat(Color(0.55, 0.12, 0.08), 0.9)
	_box(_root, Vector3(1.6, 0.55, 0.75), Vector3(0, 0.275, 0), wood)
	for x: float in [-0.65, 0.0, 0.65]:  # iron bands
		_box(_root, Vector3(0.06, 0.57, 0.77), Vector3(x, 0.275, 0), iron)
	_box(_root, Vector3(0.5, 0.22, 0.01), Vector3(-0.32, 0.3, 0.38), stamp)  # stencilled crate number
	var sigil: MeshInstance3D = _box(_root, Vector3(0.16, 0.16, 0.01), Vector3(0.33, 0.3, 0.38), stamp)
	sigil.rotation.z = PI * 0.25  # occult diamond stamp
	_lid = Node3D.new()
	_lid.name = "Lid"
	_lid.position = Vector3(0, 0.55, -0.375)  # hinge along the back edge
	_root.add_child(_lid)
	_box(_lid, Vector3(1.6, 0.14, 0.75), Vector3(0, 0.07, 0.375), wood)
	for x: float in [-0.65, 0.0, 0.65]:
		_box(_lid, Vector3(0.06, 0.16, 0.77), Vector3(x, 0.07, 0.375), iron)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(0.35, 1.0, 0.45)
	glow.light_energy = 0.8
	glow.omni_range = 4.0
	glow.position = Vector3(0, 0.9, 0)
	_root.add_child(glow)
	_item_holder = Node3D.new()
	_item_holder.name = "Item"
	_root.add_child(_item_holder)
	_pillar = MeshInstance3D.new()
	_pillar.name = "LightPillar"
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.6
	cyl.height = PILLAR_HEIGHT
	cyl.cap_top = false
	cyl.cap_bottom = false
	_pillar.mesh = cyl
	_pillar.position = Vector3(0, PILLAR_HEIGHT * 0.5, 0)
	_pillar_mat = StandardMaterial3D.new()
	_pillar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pillar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pillar_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_pillar_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pillar_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.22)
	_pillar.material_override = _pillar_mat
	_pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pillar)
	_collider = StaticBody3D.new()
	_collider.name = "Collider"
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.6, 0.7, 0.75)
	cs.shape = shape
	cs.position = Vector3(0, 0.35, 0)
	_collider.add_child(cs)
	add_child(_collider)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m
